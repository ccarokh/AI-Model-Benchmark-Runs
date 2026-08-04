# Multi-GPU: is a second, slower card worth buying?

**Short answer: PCIe is never the bottleneck. Layer split costs ~38 % of generation
speed and buys capacity. Tensor split is unusable. The only thing that matters when
buying a second card is its memory bandwidth.**

The question was concrete: would adding a slower 16 GB card to a 24 GB card be worth
the money, to run models that do not fit in 24 GB?

Test pair: RX 7900 XTX (24 GB, 960 GB/s) + RTX 2070 (8 GB, 448 GB/s), Vulkan,
mixed vendors, on a PCIe Gen 3 board.

---

## The two split modes are completely different things

- **Layer split** (`-sm layer`, the default) puts different layers on different
  cards. The cards run **sequentially** — card B waits for card A. Times add.
  There is no speedup available, only capacity.
- **Tensor split** (`-sm tensor`) splits each layer across both cards, so they work
  **concurrently**. Theoretically up to 2×, but it requires constant synchronization
  at every layer boundary.

A note on flags: `-sm row` is **deprecated**; `-sm tensor` is its successor. And
only the SYCL backend implements `ggml_backend_split_buffer_type` — everything else
throws `does not support split buffers`.

---

## Finding 1 — PCIe carries almost nothing

Measured with `nvidia-smi` PCIe counters during full load:

| Mode | PCIe utilization |
|---|---:|
| Single card | 0.0 % |
| Layer split | **0.0–0.9 %** |
| Tensor split | 4.4–4.9 % |

Even tensor split, which synchronizes at every layer, uses under 5 % of the
available bus.

**Why:** weights cross PCIe exactly once, at load time. After that only the
activation vector at the handover crosses — hidden size × 2 bytes, roughly **10 KB
per token**. The ratio of VRAM traffic to PCIe traffic is on the order of
**800 000 : 1**.

This kills the most common piece of advice in multi-GPU blog posts. "You are
bottlenecked by PCIe" was not true here in any configuration.

### The x8/x8 rebuild proves it

The second card was originally in a chipset slot (PCIe Gen 3 ×4, 3.94 GB/s through
DMI). It was physically moved so both cards ran at **CPU-direct ×8** — genuinely
doubling the available bandwidth to the second card.

| Configuration | Before (×16 + ×4) | After (×8 + ×8) |
|---|---:|---:|
| A — XTX alone | 38.97 t/s | 38.68 t/s |
| B — layer split 3:1 | 24.52 t/s | 24.61 t/s |
| D — tensor split 3:1 | 19.45 t/s | 19.58 t/s |

**Nothing changed.** All three differences are inside the noise. Doubling PCIe
bandwidth to the second card bought exactly zero, which is what the 0 % utilization
figure predicted.

---

## Finding 2 — layer split costs ~38 % of generation, consistently

27B model, sustained load (2048-token prefill, 3000-token generation):

| Configuration | Prefill (t/s) | Generation (t/s) | vs single card |
|---|---:|---:|---:|
| XTX alone | 819.2 | **38.67** | 100 % |
| Layer split 3:1 | 825.8 | **24.10** | **62.3 %** |
| Tensor split 3:1 | 286.9 | 20.09 | 51.9 % |

An 8B model that fits on either card alone gives the same picture:

| Configuration | Prefill (t/s) | Generation (t/s) |
|---|---:|---:|
| XTX alone | 2768.5 | 128.73 |
| 2070 alone | 1686.1 | 52.48 |
| Layer split 1:1 | 3009.5 | 67.19 |
| Layer split 3:1 | 2730.5 | **79.27** (61.6 % of XTX alone) |
| Tensor split 1:1 | 826.3 | 42.25 |
| Tensor split 3:1 | 762.5 | 43.12 |

**62.3 % at 27B and 61.6 % at 8B.** The penalty is stable across model sizes, which
means it is structural, not a memory-pressure artifact.

### Prefill is free

At a realistic prompt length the layer split costs **nothing** on prefill: 825.8
against 819.2 t/s, i.e. inside the noise. That is because prefill processes many
tokens per handover, so the sequential penalty amortizes. Generation hands over once
per token and cannot amortize anything.

Note this only shows up at realistic lengths. At `pp512` the same configuration
looked like a 17 % loss (536 vs 647) — a short prompt is dominated by the fixed
handover cost. **Benchmark at the prompt length you actually use.**

### The split ratio does not rescue it

| Ratio (XTX : 2070) | Generation | Share held by the slow card |
|---|---:|---:|
| 1 : 0 (second card empty) | **38.94** | none |
| 7 : 1 | 25.84 | 1/8 |
| 3 : 1 | 24.52 | 1/4 |

**Halving the slow card's share recovered 1.3 t/s of the 14.4 lost — 9 %.** The
penalty is not proportional to how much work the slow card does. Almost all of it
appears as soon as the second card participates at all, and the `1:0` row is the
control: with the card configured but holding nothing, speed is exactly single-card
speed.

**What that rules out and what it does not.** It rules out the simple story that the
cost is just "the slow card's layers run at the slow card's speed" — under that story,
1/8 of the work should cost roughly half of what 1/4 costs, and it does not. What
remains is a cost tied to the handover itself.

### ~8 ms per token that nothing accounts for

The arithmetic, at 27B in the 3:1 layer split:

| | |
|---|---:|
| Measured, per token | **41.5 ms** |
| Explained by compute — XTX, 12.6 GB at 670 GB/s | 18.8 ms |
| Explained by compute — 2070, 4.2 GB at 283 GB/s | 14.8 ms |
| **Accounted for** | **33.6 ms** |
| **Unaccounted for** | **≈ 8 ms** |

PCIe is not the gap — it was measured at 2.5 % utilization. And **two independent
signals say both cards are idle during those 8 ms**: the 2070 sits at 43 %
utilization, and the XTX draws 120 W instead of its usual 262 W under load. A card
computing at full tilt does not draw 120 W.

**The attempt to locate it failed.** The hypothesis was host-side: llama.cpp splits
the graph per device and synchronizes between the segments through CPU and driver —
submit a command buffer, wait for completion, build the next — with no card computing
in between. `GGML_VK_PERF_LOGGER=1` was used to sum per-operation times and compare
against wall clock; if operations summed to ~33 ms against 41.5 ms wall clock, the gap
would sit between the operations and the hypothesis would hold.

**The logger produced no output for the split configuration.** The single-card
reference profiled fine; the split case came back empty. So the hypothesis is neither
confirmed nor refuted, and the 8 ms is recorded as an unexplained residual rather than
attributed to anything.

Separating it properly would need a second card that is not slow — two comparable
cards would isolate a fixed synchronization cost from compute time in one run.

---

## Finding 3 — tensor split is unusable here

Tensor split was the mode that could theoretically double throughput. It does the
opposite: 20.09 t/s against 38.67 single-card, and prefill collapses from 819 to 287.

**It is slow even with the second card empty** — a 56 % penalty on a configuration
where the second card has nothing to do. Whatever the cost is, it is paid for
entering the mode, not for the work distributed.

The obvious suspicion was the mismatched pairing — RDNA3 against Turing, different
wave sizes, different vendors. **That was never tested**, and it cannot be from this
hardware; it needs two comparable cards. It is a guess, and it is recorded as one.

---

## What this means for a purchase

Stated only as far as the measurements reach — one card pairing, one board, single-
stream inference.

**Measured, and directly usable:**

- A second card is a **capacity mechanism, not a speed mechanism.** Layer split — the
  only mode that worked here — ran at ~62 % of the speed of the card that would have
  fitted the model alone, at both 27B and 8B.
- **PCIe link width did not matter.** Moving the second card from ×4 through the
  chipset to CPU-direct ×8 changed nothing measurable, which the 0–5 % bus utilization
  had predicted. A cheap slot is fine.
- **Tensor split was not usable** on this pairing, in any ratio.

**Not measured, and therefore not advice:**

- **Which property of a second card to buy for.** Memory bandwidth is the obvious
  candidate, but we have exactly one second card and never varied it — that hypothesis
  is untested here.
- **Whether a matched pair behaves differently.** The unresolved handover cost above
  would have to be settled first.
- **NVLink or any faster interconnect.** What can be said is narrow: **in this test no
  bottleneck appeared that a faster link would have relieved** — the bus sat at 0–5 %
  and doubling its width changed nothing. That is not the same as "NVLink is
  pointless". It is one pairing, single-stream, on one board.

**And we could not rule out a fault in our own setup.** The tensor-split result is the
reason to say so plainly: a 56 % penalty with the second card *empty* does not look
like a property of the hardware, it looks like something wrong — a configuration, a
driver path, a backend limitation. We never found out which. An unexplained loss of
that size means the surrounding measurements deserve the same suspicion, and
conclusions drawn from them should carry it.

---

## Measurement notes

- **Load time roughly doubles** on the split, from ~25 s to ~30 s. On this host that
  is disk-bound rather than bus-bound — a 15.65 GiB model cannot be cached in 16 GB
  of RAM, so it is read from NVMe either way. This is inside the 5 s polling
  resolution and should not be read as a bus effect.
- `-ts 3,1` is **not** a 3:1 split. The separator is `/`. A comma is parsed as two
  separate runs. See [METHODOLOGY.md](../METHODOLOGY.md#read-the-separator-syntax-of-your-own-flags).
- Short bursts do not register on a wall-socket meter. All power figures here come
  from sustained-load runs.

## Scripts

- [`scripts/hardware/multigpu_sustained.sh`](../scripts/hardware/multigpu_sustained.sh) — the sustained-load comparison
- [`scripts/hardware/multigpu_ratios.sh`](../scripts/hardware/multigpu_ratios.sh) — split-ratio sweep including the `1:0` control

# Where the time goes in Vulkan tensor split

**It is latency, not bandwidth, and it is not the slow card — and the draft AllReduce in PR #25051 removes two thirds of it on this pair.** With `-sm tensor` on
Vulkan every layer boundary runs a generic AllReduce in `ggml-backend-meta.cpp` that
drains both GPUs to the host, copies 16 KB through a staging buffer with a fenced
submit, and re-submits — **64 times per token** for a 32-layer model. Each round costs
~330 µs of which ~130 µs is the card actually computing. With the second card
configured but holding *nothing* (`-ts 1/0`) the rate is already 38 t/s against 112
single-card; giving it a quarter of the work makes it *faster* (43 t/s). Prefill is
worse: there the same path moves 16 MB per AllReduce at 2.8 GB/s and spends 99 % of the
graph in the reduction.

Measured 2026-09-11 on [System A](../systems/system-a.md): RX 7900 XTX + RTX 2070, both
on CPU PCIe lanes, Vulkan (RADV 26.1.5 / NVIDIA 610.43), llama.cpp master `df03399b8`.
Raw `llama-bench` JSON, the instrumented-build patch and the run scripts are in
[`data/vulkan_tensor_split/`](../data/vulkan_tensor_split/); the summary table is
[`data/vulkan_tensor_split.tsv`](../data/vulkan_tensor_split.tsv). Reading notes with
line numbers live in the [contribution repository](../../llama.cpp-vulkan-multigpu/notes/).

Every number below is measured unless marked *inferred*. `llama-bench -fa 1 -r 3`,
card pinned (`-sm none -mg 0`) wherever a single card is meant.

## The controls, qwen3.5-9b Q4_K_M

| | configuration | tg128 t/s | of XTX | pp512 t/s |
|---|---|---:|---:|---:|
| A0 | XTX alone | **111.9** | 100 % | 2868 |
| A1 | 2070 alone | 49.8 | 45 % | 1398 |
| B | `-sm tensor -dev Vulkan0` — Meta device with one card, no AllReduce | 93.8 | 84 % | 2720 |
| C | `-sm tensor -ts 1/0` — 2070 joins every AllReduce, computes nothing | 38.3 | 34 % | 680 |
| D | `-sm tensor -ts 3/1` | 43.2 | 39 % | 828 |
| D | `-sm tensor -ts 1/1` | 41.6 | 37 % | 855 |
| D | `-sm tensor -ts 1/3` | 34.6 | 31 % | 748 |
| E | `-ts 3/1` + `GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1` | 34.8 | 31 % | 761 |
| F | `-sm layer -ts 3/1` | 69.9 | 62 % | 2063 |
| F | `-sm layer -ts 1/0` | 110.0 | 98 % | 2845 |

Three things fall out before any instrumentation:

- **B − A0: cutting the graph into 64 pieces costs 16 % on its own.** The Meta device
  with a single card does no AllReduce at all, it only submits the per-layer subgraphs
  one by one. (3B: −27 %, 27B: −11 % — the smaller the compute per piece, the larger the
  share.)
- **C is the whole loss.** The 2070 holds zero-sized slices, computes nothing, and the
  rate is 38.3 — the same 34 % the nightly `mgpu-tensor` row has been reporting. The
  ~66 % is paid for *participating*, not for work.
- **C → D 3/1 goes up, not down.** Giving the slow card a quarter of the work adds
  5 t/s, because its share runs concurrently and shortens the wait for the XTX. Only at
  1/3 does the 2070 become the bottleneck. The "slow card holds things up" story is
  wrong for this pairing at every ratio ≥ 1/1.

## Inside one AllReduce

An instrumented `libggml-base` (patch in `data/`, env `GGML_META_AR_TIMING`) timestamps
the fallback on the calling thread. Per token during generation, qwen3.5-9b:

| per token, tg | B (1 card) | C 1/0 | D 3/1 |
|---|---:|---:|---:|
| AllReduces | 0 | 64 | 64 |
| bytes per AllReduce (both directions) | — | 32 KB | 32 KB |
| whole Meta graph | 8.35 ms | 24.5 ms | 21.9 ms |
| … subgraph submits | 8.35 ms | 3.5 ms | 4.3 ms |
| … AllReduce total | — | **21.0 ms** | **17.6 ms** |

Per AllReduce, µs, averaged over 2 048 calls:

| step | C 1/0 | D 3/1 | what it is |
|---|---:|---:|---|
| `synchronize(src)` first push | 164 | 138 | wait for the XTX to finish its subgraph — the only place genuine compute hides |
| `synchronize(dst)` first push | 35 | 37 | the 2070 is already done; this is one submit-fence round trip on NVIDIA |
| `synchronize` ×2, second push | 0.5 | 0.5 | both queues empty: a sync on a drained device is free |
| blocking copy (D2H fenced + memcpy) | 94 | 74 | 16 KB each way |
| ADD graph submit ×2 | 27 | 25 | one-node graph per device |
| zeroing graph | 6 | 0 | only when a slice is zero-sized |
| **total** | **328** | **275** | |

*Inferred:* the XTX needs ~130 µs of GPU time per subgraph (8.35 ms ÷ 64 from run B).
Subtracting that from the 164 µs first sync leaves ~35 µs — the same fence round trip
the idle 2070 shows. So of the 328 µs, ~130 are compute and **~200 µs are overhead per
AllReduce: 12.8 ms per token**, plus the 16 % fragmentation from B. That reproduces the
measured 26.1 ms per token (38.3 t/s) against 8.9 ms (111.9 t/s).

### The split the task asked for, per token at 9B (1/0)

| | ms | share of the 17.2 ms lost | how established |
|---|---:|---:|---|
| Transfer — the blocking copy | 6.0 | 35 % | measured (64 × 94 µs) |
| Synchronisation — fence round trips, ADD submits, zeroing | 4.4 | 26 % | measured (64 × (35 + 27 + 6) µs) |
| Fragmentation — subgraph-by-subgraph submission | 1.7–3.5 | 10–20 % | measured in B (1.7 ms); the rest of the first sync beyond compute is *inferred* |
| Compute on the slower card | **0** | 0 % | measured: C = 1/0 has none and is the slowest ratio ≥ 1/1 |
| residual | ~2 | ~12 % | sampling, host-side graph build outside the Meta timer |

**The "transfer" is not bandwidth.** 32 KB in 94 µs is 0.35 GB/s on a link that
carries 7.9 GB/s. Across models the copy cost barely moves with size — 3B: 24 KB in
84 µs, 9B: 32 KB in 94 µs, 27B: 40 KB in 105 µs — it is the fenced D2H submit plus a
CPU `memcpy` into ReBAR memory, i.e. two more round trips. Run E confirms the shape:
with host-visible VRAM disabled the H2D leg becomes a fenced submit too and the copy
rises from 74 to 134 µs (+58 µs), taking 8 t/s off the total.

### Prefill: here it *is* bandwidth

| pp512, 9B | B (1 card) | C 1/0 | D 3/1 |
|---|---:|---:|---:|
| Meta graph | 165 ms | 853 ms | 608 ms |
| AllReduce total | — | 850 ms | 603 ms |
| per AllReduce: sync / copy | — | 4.5 / 8.7 ms | 3.4 / 6.0 ms |
| bytes per AllReduce | — | 16 MB | 16 MB |

Sixty-four times 16 MB through a staging buffer and a CPU `memcpy` at **2.8 GB/s**:
384 ms of copying per 512-token prompt, against 178 ms of single-card compute. That is
why prefill collapses from 2 868 to 830 t/s, and why the 27B numbers in
[`hardware/multi-gpu.md`](../hardware/multi-gpu.md) showed the same 3.5× on prefill.

## It scales with the number of layers, not the model

| model | layers | AllReduces/token | XTX alone | tensor 1/0 | tensor 3/1 | overhead per AllReduce* |
|---|---:|---:|---:|---:|---:|---:|
| Llama-3.2-3B | 28 | 56 | 253.8 | 56.3 | 56.8 | 143 µs |
| Qwen3.5-9B | 32 | 64 | 111.9 | 38.3 | 43.2 | 156 µs |
| Qwen3.6-27B | 64 | 128 | 39.0 | 16.4 | 19.2 | 164 µs |

\* copy + ADD + idle-card fence, i.e. everything except the wait for genuine compute.
Nearly constant; the small rise tracks bytes (12 → 20 KB). The loss per token is
therefore ~2 × n_layer × 150 µs plus fragmentation, whatever the model weighs. For the
27B that is 128 × 164 µs = 21 ms per token on a 25.6 ms baseline — and 27B layer split
(24.7 t/s) beats 27B tensor split (19.2) as before.

## Why CUDA does not pay this

`ggml-cuda/allreduce.cu` (971 lines) does, for the decode case, one kernel launch per
AllReduce: each GPU writes its half into *mapped pinned host memory*, sets an arrival
flag in host memory, spins on the peer's flag **inside the kernel**, reads the peer's
half and adds. No host round trip, no stream drain, no staging copy. For prefill it
switches to chunked copy-engine transfers ordered by events, so compute continues while
data moves. Three differences, stated as hypotheses about what the Vulkan path would
need — the numbers above say which matters how much:

1. **No host-side blocking.** The generic path performs ≥ 2 fence waits and 2 blocking
   copies per AllReduce on the calling thread; CUDA performs none. On our numbers this
   is the 35 µs idle-card round trip, the ~35 µs beyond compute in the first sync, and
   most of the 94 µs copy — roughly **10 ms of the 17 per token**.
2. **One transfer, not two.** Generic: D2H into a staging buffer on device A, then the
   CPU copies into device B. CUDA: each GPU DMA-writes once to host memory the peer
   reads directly. For decode this is the difference between three round trips and
   one; for prefill it is what turns 2.8 GB/s into the link's 7.9.
3. **No pipeline drain per layer.** CUDA enqueues the reduction on the stream and the
   next subgraph follows; Vulkan currently rebuilds and resubmits per subgraph — the
   16 % seen in run B even with one card.

## What netrunnereve meant by "the reason"

Not this. The sentence in
[#22463](https://github.com/ggml-org/llama.cpp/discussions/22463) — *"I've figured out
the reason but someone needs to go work on it"* — replies to d-shehu about the
**segfault at large context**, [#22197](https://github.com/ggml-org/llama.cpp/issues/22197).
The reason is stated there (netrunnereve, 2026-06-15): above ~1 GB the Vulkan backend
splits the KV cache into several buffers wrapped in a ggml `multi_buffer` that has no
Vulkan context, and `ggml_vk_tensors_overlap` dereferences it. It is a crash cause, not
a performance cause, and says nothing about where the time goes.

## What exists upstream already

[PR #25051](https://github.com/ggml-org/llama.cpp/pull/25051) (pwilkin, draft, open,
conflicting with master, quiet since 2026-08-16) implements a Vulkan `comm_allreduce`:
pinned host memory imported into every device via `VK_EXT_external_memory_host`, ring
reduction, F16 on the wire, timeline-semaphore ordering with a CPU-proxy thread when the
devices do not share a driver. Reported on same-vendor pairs: Qwen3.5-9B tg 44 → 61 t/s
(CUDA/NCCL: 73). Nobody has measured its proxy path on a mixed-vendor pair — which is
this machine. It is blocked on the crash-fix part of the same PR (maintainer objection),
not explicitly on the AllReduce. Its Vulkan part, rebased here, is measured in the next
section.

## The draft AllReduce, measured on the mixed-vendor pair

The Vulkan part of PR #25051 — `ggml-vulkan.cpp` only, without the multi-buffer
workaround in `ggml-backend*` — applied on the same `df03399b8` (one API fix: the
queue objects became `unique_ptr`s since the PR was written; patch in
[`data/vulkan_tensor_split/pr25051-vulkan-only-on-df03399b8.patch`](../data/vulkan_tensor_split/pr25051-vulkan-only-on-df03399b8.patch)).
The log confirms the path nobody had measured: *"cross-device OPAQUE_FD timeline import
unsupported; using portable CPU-proxy sync"* — RADV and NVIDIA do not share a driver
UUID, so a host thread bridges the timeline semaphores.

| tg128 t/s | XTX alone | layer 3/1 | tensor, fallback | **tensor, PR** | PR of XTX |
|---|---:|---:|---:|---:|---:|
| Qwen3.5-9B, 3/1 | 111.9 | 69.9 | 43.2 | **71.5** | 64 % |
| Qwen3.5-9B, 1/1 | | | 41.6 | 59.5 | 53 % |
| Qwen3.5-9B, 1/0 | | 110.0 | 38.3 | 70.4 | 63 % |
| Qwen3.5-9B, 3/1, `GGML_VK_COMM_TREE=1` | | | | 73.7 | 66 % |
| Qwen3.5-9B, 3/1, depth 4096 | | | | 71.5 | |
| Qwen3.6-27B, 3/1 | 39.0 | 24.7 | 19.2 | **30.0** | 77 % |

| pp512 t/s | XTX alone | layer 3/1 | tensor, fallback | **tensor, PR** |
|---|---:|---:|---:|---:|
| Qwen3.5-9B, 3/1 | 2868 | 2063 | 828 | **2108** |
| Qwen3.5-9B, 1/1 | | | 855 | 1548 |
| Qwen3.5-9B, 3/1, depth 4096 | | | | 1846 |
| Qwen3.6-27B, 3/1 | — | — | — | 612 |

- **Generation: +66 % at 9B, +56 % at 27B over the fallback.** At 9B tensor split now
  equals layer split; at 27B it beats it (30.0 against 24.7) — the first configuration
  on this machine where the second card makes generation *faster* than layer split.
- **Prefill recovers 2.5×** (828 → 2108) and lands above layer split. The 2.8 GB/s
  staging path is gone; what remains is F16 over the same link, DMA'd once.
- **Same tokens.** Greedy 48-token completions from the PR (ring, 3/1, 1/1, forced
  proxy) are byte-identical to each other and to the fallback tensor split; both differ
  from the single card in two words, as any change of reduction order does. One sample,
  not a perplexity run.
- **The remaining cost.** 1/0 with the PR is 70.4 t/s: 14.2 ms per token against 8.9,
  i.e. *inferred* ~83 µs per AllReduce where the fallback paid ~250. Per token that is
  still 5.3 ms of pure synchronisation for 64 × 16 KB. The proxy thread hop (poll a
  semaphore on device A, signal on device B, twice per ring step) is the obvious
  candidate; the native path on a same-driver pair would show how much of the 83 µs it
  is. CUDA's in-kernel flag spin pays none of it.
- **The crash is untouched.** `llama-completion` with the model's default context
  aborts in `ggml_backend_meta_buffer_init_tensor` ("multi buffers are not supported by
  the meta backend") — #22197, exactly the part of the PR left out here. `-c 2048` and
  `llama-bench` are unaffected.

## Method notes

- `GGML_VK_PERF_LOGGER` is unusable for this question: it fences every graph (which is
  also why it produced nothing for the split case last month). The timer here sits in
  `ggml-backend-meta.cpp` on the calling thread and costs < 1 µs per call; the
  instrumented and plain builds agree within noise (C: 38.25 plain, 38.96 instrumented).
- `-ts` takes a slash. `3,1` is two runs.
- `-sm tensor -dev Vulkan0` is a valid control: llama.cpp builds a Meta device from one
  device, the subgraph split happens, the AllReduce does not (`ar=0` in the log).
- Run B's 8.35 ms "submit" time per token is the GPU time: with one card each
  subgraph submit ends up waiting for the previous one. The 3.5 ms in run C is the
  same work with the waiting moved into the AllReduce's first sync.

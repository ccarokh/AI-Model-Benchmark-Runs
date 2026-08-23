# Bandwidth against generation rate

`bandbreite_vs_erzeugung.tsv` — the same file, the same command, the same llama.cpp build
on four cards. The card is the variable; the driver is a second one and is named per row.

```
llama-bench -m Llama-3.2-3B-Instruct-Q4_K_M.gguf -n 128 -p 512,4096 -pg 4096,128 -ngl 99 -r 20
build 70adb1b · Vulkan
```

## The four cards

| Card | Bandwidth | Generation `tg128` | Prefill `pp4096` | Driver |
|---|---:|---:|---:|---|
| RX 7900 XTX | 960 GB/s | **251.23** ± 1.89 | 6 081 ± 11 | Mesa 26.1.5 (RADV) |
| RTX 3080 | 760 GB/s | **218.90** ± 0.77 | 7 631 ± 54 | NVIDIA 610.57.04 |
| RTX 4070 Super | 504 GB/s | **201.80** ± 0.25 | 10 723 ± 57 | NVIDIA 610.57.04 |
| RTX 2070 | 448 GB/s | **126.29** ± 0.08 | 3 286 ± 11 | NVIDIA 610.43.03 |

## Bandwidth explains generation — except for Ada

Generation per GB/s of bandwidth:

| Card | Architecture | `tg128` per GB/s |
|---|---|---:|
| RX 7900 XTX | RDNA 3 | 0.262 |
| RTX 2070 | Turing | 0.282 |
| RTX 3080 | Ampere | 0.288 |
| **RTX 4070 Super** | **Ada** | **0.400** |

**Three architectures across two vendors land within 10 % of each other. Ada extracts
39 % more generation per unit of bandwidth than any of them.** That is the sharper version
of what the 3080-vs-4070-Super pair showed on its own: the rule of thumb "generation
scales with memory bandwidth" is not wrong in general — it holds across RDNA 3, Turing and
Ampere — it breaks on the newest NVIDIA generation, which is exactly the one a buyer would
be choosing.

Prefill is the same story only louder: per GB/s the 4070 Super does **21.3** tokens where
the 3080 does 10.0, the 2070 7.3 and the XTX 6.3. On absolute prefill the 4070 Super beats
a card with nearly twice its bandwidth by 76 %.

The consequence for a purchase is unchanged and now rests on four points instead of two:
**do not buy generation rate by the bandwidth figure across architectures.**

## The build is not a confounder

The 7900 XTX and the 2070 had already been measured on build `b10098` (22.07.2026), and
`70adb1b` is **490 commits and one month later**. Re-measuring the same two cards is a
control for the whole table:

| Card | Test | b10098 | 70adb1b | Difference |
|---|---|---:|---:|---:|
| RX 7900 XTX | tg128 | 251.33 | 251.23 | −0.04 % |
| RX 7900 XTX | pp4096 | 6 136.92 | 6 081.11 | −0.9 % |
| RTX 2070 | tg128 | 125.74 | 126.29 | +0.44 % |
| RTX 2070 | pp4096 | 3 284.46 | 3 286.34 | +0.06 % |

**Nothing moved.** Whatever else changed in llama.cpp over those 490 commits, it did not
change what these two cards do with this model. The older per-card numbers elsewhere in
this repository can therefore be read next to these, and the drift check's premise — that
a build has to be proven not to move the numbers before it is trusted — holds up when it
is actually measured.

## What is *not* identical, and matters

**The driver.** The 3080 and the 4070 Super ran NVIDIA 610.57.04, the 2070 runs 610.43.03,
and the 7900 XTX runs RADV/Mesa — a different driver stack altogether. The Vulkan backend
is the same for all four; the implementation underneath it is not. For the NVIDIA cards
the difference is one minor driver release; for the AMD card the comparison is
card-plus-driver, and no measurement here separates the two.

**The machine.** The 4070 Super sat in a Ryzen 5 5600X, the 3080 in a Ryzen 9 5950X, and
the two cards above in the measuring host. For a 3B model fully resident in VRAM this is
not expected to matter — [PCIe carries almost nothing](../../hardware/multi-gpu.md#finding-1--pcie-carries-almost-nothing)
— but it was not held constant and is therefore listed.

**Both cards in the measuring host sit in the same machine.** Each run pinned one device
(`-dev Vulkan0` / `-dev Vulkan1`) and the other card stayed idle. The GPU lease was held
for the whole run, so the on-demand model service could not take memory mid-measurement,
and the kernel log was clean before and after.

## Two measurements of the same card, and why both are here

The RTX 3080 sits in the development machine, and the first run had the desktop session on
the card: 2 620 MiB held, 22 % baseline load. The second ran after closing most
applications, 1 405 MiB.

| | with desktop | cleaned up |
|---|---|---|
| tg128 | 203.20 ± **15.55** | 218.90 ± **0.77** |
| pp512 | 8 734 ± **1 244** | 8 269 ± **143** |

**The spread drops twentyfold and the value rises 7.7 %.** That is the price of a busy
card, quantified — and the reason the cleaned-up run is the valid one.

It remains a **lower bound**: 1 405 MiB of desktop still sat on the card. That does not
weaken the finding, it strengthens it — the 3080 loses despite the handicap being on the
other side.

⚠️ **No raw data survives from the first measurement.** It was deleted on a "discard"
before it was decided that it should stay as a comparison point; only the averages from
the run's output remain. **Discarded measurements belong marked, not removed** — otherwise
exactly the evidence one later needs is the one that is gone.

## One wide spread that is real

The 7900 XTX reports `pp512` as 5 796 ± **682** — a 12 % spread where every other figure in
the table sits under 3 %. It is not noise from a busy card: the b10098 run showed the same
shape (5 711 ± 349) on a different build weeks earlier, and `pp4096` on the same run is
tight at ± 11. It is a property of the first, short prefill test on this driver, and it is
the reason `pp4096` rather than `pp512` is used for the comparisons above.

## Files

| File | Card |
|---|---|
| `rohdaten_3080.json` | RTX 3080, cleaned-up run |
| `rohdaten_4070super.json` | RTX 4070 Super |
| `rohdaten_7900xtx.json` | RX 7900 XTX |
| `rohdaten_2070.json` | RTX 2070 |

The raw files are `llama-bench -o json` output, including the per-repetition samples.
Collected by [`bandwidth_vs_generation.sh`](../../scripts/hardware/bandwidth_vs_generation.sh)
for the two cards in the measuring host.

# geerlingguy/ai-benchmarks

A benchmark written by someone else, run here so this machine can be placed next to
hardware we do not own. Everything else in this repository is self-designed and
therefore comparable with nothing.

Upstream: [geerlingguy/ai-benchmarks](https://github.com/geerlingguy/ai-benchmarks).
Its table is `System | CPU/GPU | Eval Rate | Power (Peak)`, sorted by eval rate, one
row per contributed machine.

Measured on **[System A](../systems/system-a.md) v1.3**, quiet BIOS, llama.cpp b10098,
kernel 7.1.5-arch1-2, Mesa 26.1.5. Model supervisor stopped, card verified empty
beforehand, no downloads running.

## Results

```
llama-bench -m <model> -n 128 -p 512,4096 -pg 4096,128 -ngl 99 -r 20 -sm none -mg <0|1>
```

| Model | Size | GPU | pp512 | pp4096 | **tg128** | pp4096+tg128 |
|---|---:|---|---:|---:|---:|---:|
| Llama-3.2-3B-Instruct Q4_K_M | 1.87 GiB | RX 7900 XTX | 5711.19 ± 348.68 | 6136.92 ± 63.47 | **251.33 ± 2.14** | 3360.32 ± 19.86 |
| gpt-oss-20B MXFP4 (MoE) | 11.27 GiB | RX 7900 XTX | 3625.51 ± 85.75 | 3689.26 ± 23.51 | **212.61 ± 1.71** | 2422.26 ± 5.65 |
| DeepSeek-R1-Distill-Qwen-14B Q4_K_M | 8.37 GiB | RX 7900 XTX | 1664.64 ± 3.65 | 1498.47 ± 4.01 | **77.85 ± 0.39** | 929.03 ± 3.07 |
| Llama-3.2-3B-Instruct Q4_K_M | 1.87 GiB | RTX 2070 | 3410.84 ± 75.64 | 3284.46 ± 11.06 | **125.74 ± 0.46** | 1596.88 ± 22.06 |

`tg128` corresponds to the upstream table's "eval rate". Only the 3B fits in the
2070's 8 GB.

**Reproducibility:** the 2070 figure was measured twice in separate runs — 126.02 and
125.74 t/s, 0.2 % apart.

### Power, at the wall socket

Idle 59.0 W for the whole machine. SONOFF Matter smart switch via Home Assistant, 5 s
polling.

| Model | GPU | Mean | Median | Peak | Over idle |
|---|---|---:|---:|---:|---:|
| Llama-3.2-3B | XTX | 385.4 W | 408.5 W | 418.9 W | +326.4 W |
| DeepSeek-R1-14B | XTX | 408.5 W | 409.6 W | 420.2 W | +349.6 W |
| gpt-oss-20B | XTX | 348.5 W | 401.2 W | 422.4 W | +289.5 W |
| Llama-3.2-3B | 2070 | 251.5 W | 260.7 W | 303.5 W | +192.6 W |

### Our row in their format

Both cards, measured separately on the same machine and the same day:

| System | CPU/GPU | Eval Rate | Power (Peak) |
| :--- | :--- | :--- | :--- |
| Intel i9-9900K (AMD RX 7900 XTX, Vulkan) | GPU | 251.33 Tokens/s | 418.9W |
| Intel i9-9900K (NVIDIA RTX 2070, Vulkan) | GPU | 125.74 Tokens/s | 303.5W |

Watts are **wall-socket peaks for the whole machine**, so the idle floor of 59 W and
the CPU are included in both rows. The upstream table does not state what its power
column measures, so that column is not comparable across tables — only within this one.

**Only our own rows are reproduced here.** Their measurements belong in
[their table](https://github.com/geerlingguy/ai-benchmarks) — copied into ours they
would read as if we had made them, and they change as machines are submitted.

---

## What we ran, and how it differs

### We did not run their scripts

| | What it is | Used here |
|---|---|---|
| `obench.sh` | Ollama benchmark script | **no** — but see [the Ollama comparison](#ollama-against-llamacpp) |
| `ai-benchmarks.py` | pyinfra automation for remote hosts | **no** |
| the `llama-bench` line in the README | direct llama.cpp invocation | **yes** |

**Why not `ai-benchmarks.py`:** we already have that layer, and ours does what this
measurement needs — acquiring the GPU against an on-demand model supervisor, sampling
two power instruments at once, and stamping each model's start and end so an external
power log can be matched to it afterwards.

**Why not `obench.sh`:** it drives Ollama, which was not installed here. That was an
omission, not a justification — so it has since been installed and measured
separately, [below](#ollama-against-llamacpp).

### Two deviations from their command

Upstream: `-n 128 -p 512,4096 -pg 4096,128 -ngl 99 -r 2`.
Ours adds `-r 20` and `-sm none -mg <n>`.

**`-r 20` instead of `-r 2`** does not change *what* is measured — `-n`, `-p` and `-pg`
are untouched — only how many repetitions the mean covers. A socket meter polling every
5 s cannot see an 11-second run.

**`-sm none -mg <n>` is the fix for a trap that cost us a whole run.**

> **The same command means different things on different machines.** On a single-GPU
> host the upstream line implicitly measures one card. On this host it silently spreads
> the model across **both** GPUs, because that is llama.cpp's default when several
> Vulkan devices are present. Reproducing *their* measurement requires adding flags
> that are redundant on their hardware.
>
> **Identical flags do not guarantee an identical measurement.**

Our first attempt was published, then withdrawn, for exactly this. The measured cost of
the default: the split delivered **61.9 %** (3B) and **64.1 %** (14B) of single-card
generation — independently reproducing the 61.6–62.3 % measured in the
[multi-GPU work](../hardware/multi-gpu.md).

---

## Ollama against llama.cpp

Installed afterwards to close the gap above. The comparison turned out to be cleaner
than expected, for a reason worth knowing:

**Ollama *is* llama.cpp.** It ships its own copy — `libllama.so`, `libggml.so`, and a
child process literally named `llama-server`. On this card it uses the **Vulkan**
backend, the same one our own build uses. So this is not two inference engines. It is
the same engine with a different supervisor and different defaults.

Same model, same card, same context (32768), same backend:

| | Ollama 0.32.5 | llama.cpp b10098 | Difference |
|---|---:|---:|---:|
| **Generation** | 167.9–176.8 t/s | **220.4–222.0 t/s** | llama.cpp **25–32 % faster** |
| **VRAM** | 5737 MiB | 5651 MiB | +86 MiB = **+1.5 %** |
| **RSS, total** | **571 MiB** | 524 MiB | +47 MiB = **+9 %** |
| — supervisor | 68 MiB | — | |
| — model runner | 503 MiB | 524 MiB | |

**The memory overhead is small.** +9 % RAM and +1.5 % VRAM, and the RAM difference is
the supervisor process. On a 16 GB host that decides nothing.

**The throughput gap is not small.** A quarter, on identical engine and hardware —
which means it comes from defaults and orchestration. Ollama's own startup log shows
some of them: flash attention off, KV cache unquantised, context derived from total
VRAM rather than set.

**This matters for reading their table.** Rows produced through Ollama sit roughly a
quarter below what llama.cpp delivers on the same machine, and the table does not
record which runtime produced which row.

### A measurement trap, avoided this time

`ps -C ollama` reports **73 MiB** — it misses the model runner entirely, because that
child process is named `llama-server`. The honest figure needs every Ollama-owned
process summed. Reporting the first number would have made the memory overhead look
like a 90 % *saving*.

### What this does not settle

The claim that prompted this — that Ollama once caused out-of-memory failures on our
other machine — is **not** refuted by the numbers above. That was a 10 GB card with
models far larger than its VRAM, where the problem was the inability to tune `-ngl` and
unified-memory spillover by hand. That is a different failure mode from "uses more
memory", and only the second one was tested here.

---

## Two findings from the run itself

### Generation scales with memory bandwidth, almost exactly

| Card | Bandwidth | tg128 (3B) | Ratio |
|---|---:|---:|---:|
| RX 7900 XTX | 960 GB/s | 251.33 | 2.14 × |
| RTX 2070 | 448 GB/s | 125.74 | 2.00 × |

Generation is bandwidth-bound, and here the two cards land within 7 % of their
bandwidth ratio. This is the most direct confirmation of that principle anywhere in
this repository — and it is why a core-clock cap costs
[almost nothing on generation](../hardware/power.md).

### The MoE model beats a smaller dense one on every axis

| | Params | tg128 | Power over idle |
|---|---:|---:|---:|
| gpt-oss-20B (MoE) | 20.9 B | **212.61** | +289.5 W |
| DeepSeek-R1-14B (dense) | 14.8 B | 77.85 | +349.6 W |

**2.7× the generation rate, at 17 % less power, with 41 % more parameters.** Active
parameters, not total size, are what throughput and the electricity bill respond to.

## Scripts

[`scripts/hardware/reference_bench.sh`](../scripts/hardware/reference_bench.sh)

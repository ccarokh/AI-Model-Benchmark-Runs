# ROCm or Vulkan on RDNA3?

**Vulkan stays. ROCm gives +11 % prefill and −11 % generation. Break-even needs a
prompt-to-answer ratio of about 266 : 1, which no real workload has.**

This is not an exotic edge case like multi-GPU — it affects every model, every day.
The card had been running everything through Vulkan without the alternative ever
being measured.

## Setup

Same host, same model (27B Q4_K_M), same parameters, **both backends measured in the
same run** so that day-to-day variation is not a free variable. The HIP build lives
in its own prefix; the production Vulkan install was left untouched, so the rollback
is deleting a directory.

## Result

| Backend | Prefill pp2048 | Generation tg3000 | Power mean / peak |
|---|---:|---:|---:|
| Vulkan | 840.57 ± 16.03 | **37.67 ± 1.36** | 292 / 339 W |
| ROCm / HIP | **938.52 ± 19.81** | 35.21 ± 0.07 | 264 / 339 W |
| | **+11.7 %** | **−6.5 %** | −9.6 % |

Effective memory bandwidth: **578 GB/s under ROCm against 650 GB/s under Vulkan**,
of 960 GB/s on the datasheet. Neither backend gets close to the paper figure —
Vulkan reaches about 70 %, ROCm about 60 %.

## Why Vulkan wins anyway

Prefill processes the prompt; generation writes the answer. A RAG turn here is
roughly 4000 prompt tokens and 500 answer tokens — a ratio of 8 : 1.

For ROCm's prefill advantage to pay for its generation deficit, the ratio would have
to be around **266 : 1**. Retrieval-augmented generation is nowhere near that, and
interactive chat is further away still.

There is a secondary argument in the same direction: **the number users perceive is
generation speed.** Prefill happens before the first token appears; generation is
the speed at which text arrives. Trading the visible one for the invisible one is a
bad deal even where the arithmetic is closer.

ROCm's lower power draw (264 vs 292 W mean) is real but does not change the
conclusion — it is proportional to doing less generation work.

## One difference that is not a confounder

Under ROCm the card reports **wave size 32**; under Vulkan **64**. RDNA3 supports
both, and which is better is decided by the individual kernel.

This is not noise to be controlled away — it is part of what is being compared. The
two backends are genuinely differently built, and the comparison is between the two
stacks as they ship, not between two paths to identical code.

## The measurement error that nearly published a wrong result

The first run reported **ROCm for both lines.** `LD_LIBRARY_PATH` had been set for
both invocations, so the Vulkan binary loaded the ROCm build's ggml libraries.

The tell appeared before the backend column did: variance jumped to **±6.53** where
this measurement normally sits at **±0.12**. A sudden change in spread is a defect
signal.

Fix — scope the environment to the HIP build only:

```bash
case "$bin" in
  *llama-cpp-rocm*) env="LD_LIBRARY_PATH=/opt/llama-cpp-rocm/lib:/opt/rocm/lib" ;;
esac
```

## The other pair: CUDA against Vulkan on one NVIDIA card

The ROCm question above has an NVIDIA counterpart, and it took a borrowed RTX 4070 Super
to answer it: both backends built from the same commit, run on the same card, in the same
session. Five models, `llama-bench -p 2048 -n 128 -r 5`, one card at a time.

| Model | Prefill V / C | Generation V / C |
|---|---|---|
| Llama-3.2-3B | 11 413 / **11 842** | **201.89** / 196.03 |
| Qwen3.5-9B | 3 607 / **4 506** (+25 %) | 80.04 / 80.35 |
| ornith-9b | 3 652 / **4 499** (+23 %) | 80.80 / 80.99 |
| Qwen2.5-Coder-14B | 2 521 / **2 871** (+14 %) | 51.36 / 51.05 |

**CUDA buys prefill and nothing else.** Generation is a tie on every model — within half a
percent — because generation is bandwidth-bound and the backend cannot change how much
memory a token has to touch. Prefill is compute-bound, and there CUDA is 14–25 % ahead.

### And it pays for that prefill with context

The same comparison, but asking how much context still allocates
([how the ceiling is found](../findings/context-ceiling.md)):

| Model | f16 C / V | q8_0 C / V |
|---|---|---|
| Qwen3.5-9B | 196 608 / **204 800** | 311 296 / **385 024** (+24 %) |
| ornith-9b | 200 704 / **204 800** | 311 296 / **389 120** (+25 %) |
| Llama-3.2-3B | 86 016 / 86 016 | 151 552 / **163 840** (+8 %) |
| Qwen2.5-Coder-14B | 16 384 / 16 384 | 28 672 / **32 768** (+14 %) |
| **gpt-oss-20B** | 12 288 / **16 384** | 20 480 / **36 864** (+80 %) |

With an f16 cache the two are equal or within 4 %. With a quantised one Vulkan fits a
quarter more — **and the tighter the card, the wider the gap**: on the 20B MoE, which
leaves 479 MiB free after loading, Vulkan holds 80 % more context than CUDA.

**So the choice is not "which is faster" but which half of the workload matters.** A
summarisation service that reads far more than it writes should take CUDA; a RAG system
that needs the retrieved passages to fit should take Vulkan.

### They do not always produce the same text

The completion hash, same prompt, temperature 0, fixed seed:

| Model | Vulkan | CUDA | |
|---|---|---|---|
| Qwen3.5-9B | `11cc155c5d27275f` | `11cc155c5d27275f` | identical |
| Llama-3.2-3B | `ef10d86d5ff9c12d` | `ef10d86d5ff9c12d` | identical |
| ornith-9b | `f516155b7c91c724` | `8936df579ec8b54f` | **differs** |
| Qwen2.5-Coder-14B | `48df76cde437b45e` | `6cf5b882d938174a` | **differs** |
| bge-m3 | `3f2a4b2921807edb` | `fa178badef9221a7` | **differs** |

**Three of five.** Not empty outputs — different text. Different kernels sum in a different
order, a near-tie in the logits flips, and at temperature 0 one flipped token changes
everything after it. It does not invalidate the throughput figures above: `llama-bench`
works on synthetic tokens and does not depend on content. What it does invalidate is the
sentence "the two backends do the same work".

The first version of this comparison ran on two models — and both of them were among the
two that agree. It reported byte-identical output between backends, which is what
[measuring a corner of the matrix](../scripts/testbench/README.md) buys you.

## What the matrix path is worth, and only where

Vulkan reaches the matrix hardware through `coopmat2`; switching it off is the closest
thing to measuring what tensor cores contribute:

| Model | Vulkan default → without coopmat2 | CUDA default → force-cublas |
|---|---|---|
| Llama-3.2-3B | 11 343 → **8 483** (−25 %) | 11 796 → 11 785 (±0) |
| Qwen3.5-9B | 3 587 → **2 862** (−20 %) | 4 488 → 4 487 (±0) |
| ornith-9b | 3 342 → **2 875** (−14 %) | 4 496 → 4 480 (±0) |
| Qwen2.5-Coder-14B | 2 517 → **1 899** (−25 %) | 2 865 → 2 857 (±0) |

**Generation does not move at all** — under a tenth of a percent on every model. The matrix
path is a prefill mechanism, and this is what closes a question the four-card comparison
opened: the RTX 4070 Super extracts 39 % more generation per GB/s of bandwidth than three
other architectures, and it is **not** because of its tensor cores. That remains
unexplained; the L2 cache is the next suspect and this hardware cannot isolate it.

`GGML_CUDA_FORCE_MMQ` and `GGML_CUDA_FORCE_CUBLAS` change nothing on any model — the two
switches do not separate anything on this card, which is itself the result.

## At context depth, after the head-size-256 fix (15.09.2026)

The comparison above was taken at depth 0. Upstream PR #28102 (pwilkin, merged 11.09.: flash-attention tuning for AMD WMMA in the CUDA/HIP backend, and a fix that let head-size-256 kernels be selected at all) reported prefill at d40000 going from 426 to 639 t/s under ROCm on a card with WMMA — which RDNA3 has. That is the workload of the coding slot: Qwen3.8-27B (head_dim 256), 32k context, every round re-reads the whole prompt. So the question was measured again, at depth, on the same commit for both backends.

Master `7cf1c54a9` (14.09.), HIP built the same night beside the Vulkan prefix, Qwen3.8-27B Q4_K_M, `pp512`/`tg128`, q8_0 KV cache, `-fa on`, `-r 3`, one session, card pinned. Data: [`data/hip_vs_vulkan_depth.tsv`](../data/hip_vs_vulkan_depth.tsv), script [`scripts/hardware/hip_tiefe.sh`](../scripts/hardware/hip_tiefe.sh).

| depth | Vulkan pp512 | HIP pp512 | HIP vs Vulkan | Vulkan tg128 | HIP tg128 | HIP vs Vulkan |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 754 | 815 | +8 % | 38.0 | 35.2 | −7 % |
| 8 192 | 683 | 778 | +14 % | 36.9 | 33.3 | −10 % |
| 32 768 | 528 | 654 | **+24 %** | 34.3 | 28.0 | **−18 %** |

**The fix is real and it does not change the answer.** HIP's prefill advantage grows with depth, from +8 % to +24 % — and its generation deficit grows just as fast, from −7 % to −18 %. For a coding round of roughly 30 000 prompt tokens and 1 500 answer tokens at d32768 that is 57 + 44 = 101 s on Vulkan against 46 + 54 = 100 s on HIP. A wash on the one workload where ROCm was supposed to pull ahead, and the visible half — the answer arriving — is the half HIP loses. Vulkan stays, for the coding slot too.

Repeated two nights later on master `fb27a525d` (16.09.): HIP 816 / 790 / 641 prefill and 35.3 / 33.5 / 28.1 generation, Vulkan 762 / 697 / 537 and 38.0 / 36.9 / 34.1 — every cell within 2 % of the first night. The pair is stable.

Production v0.2.0 on Vulkan, measured in the same session: 736 / 670 / 518 prefill and 37.8 / 36.9 / 33.8 generation — master is 2–3 % ahead across the board, nothing more.

## Installation note

ROCm 7.2.4 installed as `rocm-hip-runtime hipblas rocm-llvm rocm-cmake` — 31
packages, ~9 GB, **without dkms**: the in-kernel amdgpu driver already provides
`/dev/kfd`.

Both measurement runs here were on the performance BIOS, so they are internally
consistent but not directly comparable with figures elsewhere in this repository
that were taken on the quiet BIOS. See [power.md](power.md).

## Scripts

- [`scripts/hardware/rocm_vs_vulkan.sh`](../scripts/hardware/rocm_vs_vulkan.sh)

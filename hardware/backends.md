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

## Installation note

ROCm 7.2.4 installed as `rocm-hip-runtime hipblas rocm-llvm rocm-cmake` — 31
packages, ~9 GB, **without dkms**: the in-kernel amdgpu driver already provides
`/dev/kfd`.

Both measurement runs here were on the performance BIOS, so they are internally
consistent but not directly comparable with figures elsewhere in this repository
that were taken on the quiet BIOS. See [power.md](power.md).

## Scripts

- [`scripts/hardware/rocm_vs_vulkan.sh`](../scripts/hardware/rocm_vs_vulkan.sh)

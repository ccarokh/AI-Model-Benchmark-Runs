# Which system produced which number

Anything measured on System B is marked as such. The place it matters most is the
chat ranking, which is a **hardware mix** — see the
[provenance caveat](../use-cases/language-understanding.md#provenance-caveat).

Rule of thumb: **chat and embedding evaluations are System B, everything from the
coding series onwards is System A.** All hardware and operations measurements are
System A by definition.

## By system version

| Measurement | System | GPU BIOS |
|---|---|---|
| [Chat](../use-cases/language-understanding.md), [embedding](../use-cases/embedding.md), [ASR](../use-cases/transcription.md) | **B v1.0** | — |
| [Coding, aider-polyglot](../use-cases/coding.md#part-1--aider-polyglot) | **A v1.0** | quiet |
| [Vision](../use-cases/vision.md) | **A v1.0** | quiet |
| [Power](../hardware/power.md), overclocking, determinism | **A v1.0** | quiet |
| [Coding, SWE-bench](../use-cases/coding.md#part-2--swe-bench) | **A v1.1 → v1.2** | quiet |
| [Multi-GPU](../hardware/multi-gpu.md), before the slot change | **A v1.1** | quiet |
| [Multi-GPU](../hardware/multi-gpu.md), after the slot change | **A v1.2** | quiet |
| [ROCm vs Vulkan](../hardware/backends.md) | **A v1.3** | **performance** |
| [`faster-whisper` on the RTX 2070](../use-cases/transcription.md#part-3--faster-whisper-on-the-second-card) | **A v1.3** | quiet |
| [Nanbeige4.2-3B](../use-cases/language-understanding.md#a-looped-model-measured-twice--nanbeige42-3b), and the Qwen3.5-9B run beside it | **A v1.4** | quiet |
| [Image generation](../use-cases/image-generation.md), five models | **A v1.5** | quiet |
| GPU BIOS comparison ([power.md](../hardware/power.md#the-cards-dual-bios-quiet-wins)) | **A v1.3** | both |
| [Fine-tuning](../use-cases/finetuning.md) | **A v1.3** | quiet |

**The GPU BIOS is part of the state too.** Everything except the ROCm run was
measured on the quiet BIOS. The ROCm comparison ran on the performance BIOS — both
sides of it, so it is internally consistent, but its absolute figures are not
comparable with the rest.

# Versions, as read from the running systems

Both machines are rolling-release and both gained hardware during the measurement
period. **A result is therefore attributed to a system *version*, not to a machine.**
When anything in the stack or the hardware changes, the version increments and older
results stay attached to the state that produced them.

### System A

| Version | Period | Change | Stack |
|---|---|---|---|
| **A v1.0** | 2026-07-24 → 07-28 | single GPU (7900 XTX only) | kernel 7.1.4-arch1-1, llama.cpp b10098, Mesa 26.1.5 |
| **A v1.1** | 2026-07-29 → 08-02 | **+ RTX 2070**, chipset slot at Gen 3 ×4 | kernel 7.1.5-arch1-2, otherwise unchanged |
| **A v1.2** | 2026-08-03 | 2070 **moved to a CPU-direct slot**, both cards ×8 | unchanged |
| **A v1.3** | 2026-08-04 | **+ ROCm 7.2.4** in a separate prefix | unchanged; `/opt/llama-cpp` untouched |
| **A v1.4** | 2026-08-05 → 08-06 | **+ llama.cpp b10273** in `/opt/llama-cpp-nb`, for architectures the production build predates | `/opt/llama-cpp` still b10098 and still the production runtime |
| **A v1.5** | from 2026-08-07 | **+ stable-diffusion.cpp** `master-813-bfbef5b` in `/opt/sd-cpp`, Vulkan | both llama.cpp prefixes untouched |

The kernel step from v1.0 to v1.1 is the only stack change inside the series, and its
effect was **measured rather than assumed**: 78.47 against 78.18 on the same
workload. No effect.

Mesa **26.1.5** held constant across all five versions, and llama.cpp **b10098**
across the first four.

**The v1.4 build was measured against the one it sits beside rather than assumed
equivalent:** Llama-3.2-3B gives 250.65 t/s on b10273 against 251.33 on b10098, 0.27 %
apart. No earlier figure is invalidated by the new prefix.

**A second prefix needs `LD_LIBRARY_PATH`, not just a path.** The `ld.so` cache
resolves every `libllama`/`libggml` to `/opt/llama-cpp/lib`, so the new binary runs on
the old libraries otherwise — all eight of them, silently. Here it failed loudly
(`unknown model architecture: 'nanbeige'`); with an architecture both builds know, it
would not have.

### System B

| Version | Stack |
|---|---|
| **B v1.0** | llama.cpp build 9614, CUDA |

The chat, embedding and speech evaluations all ran on B v1.0. **Its full package
state was not captured to the depth System A's was** — the llama.cpp build is
recorded, the surrounding stack is not.

### Model files

Pinned by **SHA256 against a manifest**, with the upstream repository commit recorded
alongside. "Same model" means the same bytes, not the same name — two files carrying
the same model name were found to be a duplicate pair this way, and two others have
lost their upstream repository and are marked as such.

### Which version produced which result

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

### Test bench condition

System A runs as an **open bench, no case**. All temperature and fan figures apply
only to that. Putting it in a case is treated as a version increment like any other,
and invalidates the thermal statements.

`/opt/llama-cpp` is the Vulkan build and the one the production service uses.
The HIP build lives separately in `/opt/llama-cpp-rocm` so the rollback is deleting a
directory and no prior measurement is invalidated.


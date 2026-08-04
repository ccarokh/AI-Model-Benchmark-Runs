# Systems

Two desktop machines. **The one with the bigger GPU has less system RAM** — that
inversion explains several results that otherwise look arbitrary.

| | System A — GPU host | System B — dev machine |
|---|---|---|
| **GPU** | ASRock Radeon RX 7900 XTX Taichi 24 GB OC (Navi 31, RDNA3) | NVIDIA RTX 3080, 10 GB (GA102) |
| **2nd GPU** | NVIDIA RTX 2070 8 GB (Turing) | — |
| **CPU** | Intel i9-9900K, 8C/16T | AMD Ryzen 9 5950X, 16C/32T |
| **Board** | MSI MEG Z390 GODLIKE (MS-7B10) | MSI MAG X570S TORPEDO MAX (MS-7D54) |
| **RAM** | **16 GB** DDR4 dual channel | **31 GB** |
| **PCIe** | **Gen 3** — CPU root port at 8 GT/s | **Gen 4** — GPU link at 16 GT/s ×16 |

## Software stack

| | System A | System B |
|---|---|---|
| **OS** | Arch Linux | Garuda Linux (Arch-based) |
| **Kernel** | 7.1.5-arch1-2 | 7.1.5-zen1-2-zen |
| **AMD stack** | Mesa/RADV **26.1.5-arch1.1**, `vulkan-radeon 1:26.1.5-1`, Vulkan API 1.4.354 — carries all inference | — |
| **NVIDIA stack** | `nvidia-utils` 610.43.03 for the RTX 2070 — **no CUDA toolkit installed**; CUDA compute works anyway, with cuBLAS/cuDNN as pip wheels inside a venv ([measured](models/transcription.md#part-3--faster-whisper-on-the-second-card)) | `nvidia-open-dkms` 610.43.03 + CUDA 13.3.1 |
| **Compute** | ROCm 7.2.4 (`rocm-hip-runtime`), in a separate prefix | CUDA 13.3.1 |
| **Inference** | llama.cpp **b10098** | llama.cpp **build 9614** |
| **Python** | 3.14.6 | 3.14.6 |

**Read `b10098` from `/opt/llama-cpp/.built-version`, not from `--version`** — the
binary reports `version: 1 (0278d83)`, which is a build-metadata artifact and not a
usable identifier.

## System versions

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
| **A v1.3** | from 2026-08-04 | **+ ROCm 7.2.4** in a separate prefix | unchanged; `/opt/llama-cpp` untouched |

The kernel step from v1.0 to v1.1 is the only stack change inside the series, and its
effect was **measured rather than assumed**: 78.47 against 78.18 on the same
workload. No effect.

llama.cpp **b10098** and Mesa **26.1.5** held constant across all four versions.

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
| [Chat](models/language-understanding.md), [embedding](models/embedding.md), [ASR](models/transcription.md) | **B v1.0** | — |
| [Coding, aider-polyglot](models/coding.md#part-1--aider-polyglot) | **A v1.0** | quiet |
| [Vision](models/vision.md) | **A v1.0** | quiet |
| [Power](hardware/power.md), overclocking, determinism | **A v1.0** | quiet |
| [Coding, SWE-bench](models/coding.md#part-2--swe-bench) | **A v1.1 → v1.2** | quiet |
| [Multi-GPU](hardware/multi-gpu.md), before the slot change | **A v1.1** | quiet |
| [Multi-GPU](hardware/multi-gpu.md), after the slot change | **A v1.2** | quiet |
| [ROCm vs Vulkan](hardware/backends.md) | **A v1.3** | **performance** |
| [`faster-whisper` on the RTX 2070](models/transcription.md#part-3--faster-whisper-on-the-second-card) | **A v1.3** | quiet |
| GPU BIOS comparison ([power.md](hardware/power.md#the-cards-dual-bios-quiet-wins)) | **A v1.3** | both |
| [Fine-tuning](models/finetuning.md) | **A v1.3** | quiet |

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

## System A — the primary test bench

Everything from the coding series onwards ran here.

**16 GB of system RAM is the constraint that matters, not the 24 GB of VRAM.** CPU
offload is the only way past the VRAM budget, and with ~14.5 GB usable there is not
much of it to go around.

How far offload actually gets you here **has never been measured cleanly.** The only
figures come from a run that was aborted at 9 of 150 examples, on a machine that was
simultaneously out of RAM — usable as a warning, not as a number. In practice the
budget has been treated as the VRAM, and offload as an emergency measure.

### The graphics card

Factory-overclocked, with a **physical dual-BIOS switch** (P = performance,
Q = quiet). The two differ almost only in the power limit — `power1_cap_default`
339 W against 291 W, core clock 2990 against 2945 MHz. **Memory clock is 1250 MHz in
both**, which is why generation speed does not move between them.

**Quiet is the correct setting and all measurement series were taken on it.** The
exception is the [ROCm comparison](hardware/backends.md), where both runs were taken
on the performance BIOS — internally consistent, but not directly comparable to
figures elsewhere. Measurements in [power.md](hardware/power.md).

Datasheet: boost to 2680 MHz, 24 GB GDDR6 at 20 Gbps on 384 bit = **960 GB/s**.
Measured effective bandwidth is ~650–670 GB/s under Vulkan, about 70 % of that.

### The second card

An RTX 2070 was added for the [multi-GPU measurements](hardware/multi-gpu.md). It
started in a chipset slot (Gen 3 ×4 through DMI, 3.94 GB/s) and was physically moved
so both cards run **CPU-direct at ×8**. That doubling changed nothing measurable,
which is itself the result.

**The driver on that card changed during the series.** It ran under `nouveau` when it
was first installed — that is the state the idle-power figures in
[power.md](hardware/power.md#it-cannot-be-powered-down-when-idle) were taken in — and
runs the proprietary NVIDIA driver now, with `nvidia_uvm` loaded. Any power figure for
the 2070 belongs to the driver it was measured under.

Both GPU stacks are live on System A simultaneously: Mesa/radv drives the 7900 XTX and
carries every inference measurement in this repository, while the NVIDIA driver serves
the 2070 and supplies the `nvidia-smi` PCIe counters used in the
[multi-GPU work](hardware/multi-gpu.md) — the AMD side offers no equivalent counter.

### PCIe generation

The CPU root port runs at 8 GT/s ×16, i.e. **Gen 3**. The 16 GT/s figures visible on
some devices are card-internal, behind the GPU's own switch, not the path to the CPU.
Gen 4 and Gen 5 SSDs bring nothing here.

## System B — the development machine

Carried the 9B-class chat evaluations before System A existed.

Note the inversion: **twice the system RAM, less than half the VRAM.** It can offload
models System A cannot hold, and it cannot hold models System A runs entirely in
VRAM.

It also produced a result that is purely a property of the machine: a
sliding-window-attention model **never completed an evaluation there**, breaking off
twice with `forcing full prompt re-processing due to lack of cache data`, then ran
straight through on System A fully resident. See
[METHODOLOGY.md](METHODOLOGY.md#do-not-evaluate-swa-or-hybrid-models-partially-offloaded).

Unlike System A this board is PCIe Gen 4 and AM4 — it would support a 2×8 split as
well, so a multi-GPU repeat on a newer bus is possible here in principle. Not done.

## Which system produced which number

Anything measured on System B is marked as such. The place it matters most is the
chat ranking, which is a **hardware mix** — see the
[provenance caveat](models/language-understanding.md#provenance-caveat).

Rule of thumb: **chat and embedding evaluations are System B, everything from the
coding series onwards is System A.** All hardware and operations measurements are
System A by definition.

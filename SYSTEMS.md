# Systems

Two permanent desktop machines, plus a third available for a two-day window. **The one with the bigger GPU has
less system RAM** — that inversion explains several results that otherwise look
arbitrary.

| | System A — GPU host | System B — dev machine | System C — RTX 4070 SUPER, 2-day window |
|---|---|---|---|
| **GPU** | ASRock Radeon RX 7900 XTX Taichi 24 GB OC (Navi 31, RDNA3) | NVIDIA RTX 3080, 10 GB (GA102) | NVIDIA RTX 4070 SUPER **12 GB** (AD104, Ada) |
| **2nd GPU** | NVIDIA RTX 2070 8 GB (Turing) | — | — |
| **CPU** | Intel i9-9900K, 8C/16T | AMD Ryzen 9 5950X, 16C/32T | AMD Ryzen 5 5600X, 6C/12T |
| **Board** | MSI MEG Z390 GODLIKE (MS-7B10) | MSI MAG X570S TORPEDO MAX (MS-7D54) | MSI MPG X570 GAMING PLUS (MS-7C37), BIOS A.D0 of 05/2021 |
| **RAM** | **16 GB** DDR4 dual channel | **31 GB** | **15 GB** — same as System A, which removes one variable from the comparison |
| **PCIe** | **Gen 3, and the width changed over time**: ×16 while the 7900 XTX was alone, ×8 since the RTX 2070 moved into a CPU-direct slot on 2026-08-03 ([versions](systems/versions.md)). Anything measured before that date ran at twice the width. The Gen 4 ×16 link `lspci` also reports is *inside the card*, behind the switch Navi 31 carries on board — it says nothing about the connection to the machine | **Gen 4** — GPU link at 16 GT/s ×16 | **Gen 4** — 16 GT/s ×16 **under load**; reads 2.5 GT/s at idle, which is link power saving and not a downgrade |
| **Disk** | NVMe | NVMe | **SATA SSD** (SanDisk 256 GB) — slower model loading, which lies outside every measurement window |

## Software stack

| | System A | System B | System C |
|---|---|---|---|
| **OS** | Arch Linux | Garuda Linux (Arch-based) | Arch Linux, installed for this purpose |
| **Kernel** | 7.1.5-arch1-2 | 7.1.5-zen1-2-zen | 7.1.9-arch1-2 |
| **AMD stack** | Mesa/RADV **26.1.5-arch1.1**, `vulkan-radeon 1:26.1.5-1`, Vulkan API 1.4.354 — carries all inference | — | — |
| **NVIDIA stack** | `nvidia-utils` 610.43.03 for the RTX 2070 — **no CUDA toolkit installed**; CUDA compute works anyway, with cuBLAS/cuDNN as pip wheels inside a venv ([measured](use-cases/transcription.md#part-3--faster-whisper-on-the-second-card)) | `nvidia-open-dkms` 610.43.03 + CUDA 13.3.1 | `nvidia-open` 610.57.04-8 + `nvidia-utils` 610.57.04-1, Vulkan API 1.4.341 — **Vulkan, not CUDA**, so the comparison against System A varies the card and nothing else |
| **Compute** | ROCm 7.2.4 (`rocm-hip-runtime`), in a separate prefix | CUDA 13.3.1 | none installed — a CUDA build is planned as a *second*, separate measurement |
| **Inference** | llama.cpp **b10098** in `/opt/llama-cpp` (production), **b10273** in `/opt/llama-cpp-nb` alongside it; stable-diffusion.cpp `master-813-bfbef5b` in `/opt/sd-cpp` | llama.cpp **build 9614** | llama.cpp built from source in `/opt/mess/llama.cpp`, Vulkan |
| **Python** | 3.14.6 | 3.14.6 | 3.14.7 |

**Read `b10098` from `/opt/llama-cpp/.built-version`, not from `--version`** — the
binary reports `version: 1 (0278d83)`, which is a build-metadata artifact and not a
usable identifier.

## Per system, in detail

The comparison table above is the overview. Everything that belongs to **one** machine
lives in its own file — a machine changes without the others changing, and a single
document made that hard to see.

| | |
|---|---|
| [System A](systems/system-a.md) | the primary test bench — almost every number here comes from it |
| [System B](systems/system-b.md) | the development machine |
| [System C](systems/system-c.md) | the RTX 4070 SUPER, and what a short window costs in comparability |
| [Which number came from where](systems/which-system.md) | per result series |
| [llama.cpp builds](systems/llama-cpp-builds.md) | two builds run here, plus the standing drift check |
| [Versions](systems/versions.md) | as read from the running systems, not from memory |

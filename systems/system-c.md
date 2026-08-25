# System C — RTX 4070 SUPER, two-day window

<!-- CAPTURED:BEGIN -->
| | |
|---|---|
| **CPU** | AMD Ryzen 5 5600X 6-Core Processor |
| **Threads** | 12 |
| **System RAM (GB)** | 15 |
| **Board — vendor** | Micro-Star International Co., Ltd. |
| **Board — model** | MPG X570 GAMING PLUS (MS-7C37) |
| **BIOS** | A.D0 |
| **BIOS date** | 05/20/2021 |
| **Microcode (running)** | 0xa20102e |
| **Microcode replaced at boot, from** | 0x0a201009 |
| **OS** | Arch Linux |
| **Kernel** | 7.1.9-arch1-2 |
| **Python** | Python 3.14.7 |
| **Root filesystem** | /dev/sdc2 |
| **Root device** | SanDisk SD6SB1M256G1002 238.5G sata |
| **Vulkan reports** | NVIDIA GeForce RTX 4070 SUPER |
| **Vulkan API** | 1.4.341 |
| **VRAM in use at capture** | 17 MiB |

**GPUs**

| GPU | VRAM | Driver | Power limit |
|---|---|---|---|
| NVIDIA GeForce RTX 4070 SUPER | 12282 MiB | 610.57.04 | 220.00 W |

**PCIe**

| Device | Card to switch | Switch to CPU |
|---|---|---|
| NVIDIA Corporation AD104 [GeForce RTX 4070 SUPER | Speed 16GT/s, Width x16 | no switch |

**llama.cpp**

| Path | Build | Backend |
|---|---|---|
| `/opt/mess/llama.cpp/build` | 70adb1b | vulkan |

*Captured 2026-08-23T04:51:40+02:00 by [`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) — read off the machine, not written by hand. `VRAM in use` and the PCIe link are momentary values: link speed drops at idle, and on a desktop machine the session holds VRAM.*
<!-- CAPTURED:END -->

An RTX 4070 SUPER, available for two days. It exists in this repository for one question,
not as another data point: **does generation really scale with memory bandwidth?** The
[foreign benchmark page](../foreign/geerlingguy-ai-benchmarks.md#generation-scales-with-memory-bandwidth-almost-exactly)
claims it does, on the strength of two cards. 504 GB/s against the 7900 XTX's 960
predicts **around 52 %** of its generation rate — written down before measuring.

Deliberate choices, each removing a variable:

- **Arch, not something easier.** Every number here comes from Arch. A different
  distribution would change card *and* driver stack *and* libraries at once, and the
  comparison would measure setups instead of hardware.
- **llama.cpp built from source**, with the same flags as on the measuring host, rather
  than a release binary. For Linux upstream publishes no CUDA binaries anyway — only
  Windows gets those.
- **Vulkan first, CUDA second.** Vulkan is the backend behind every number in this
  repository. A CUDA build afterwards then measures the *backend* difference on NVIDIA,
  cleanly separated — the counterpart to our AMD Vulkan-versus-ROCm comparison.

Two conditions on this machine do not transfer, and both are written into the table above
rather than left implicit: it boots from a **SATA SSD** (slower model loading, which lies
outside every measurement window), and its **BIOS is from May 2021** — old enough that the
CPU came up with microcode `0x0a201009` and Linux replaced it with `0x0a20102e` at boot.
The same box under Windows would run the older one, because Microsoft ships AMD microcode
only rarely and leaves it to the board vendor. Any Windows-versus-Linux comparison on this
hardware would therefore carry a second variable.


## BIOS: five years behind, and deliberately left alone

| | |
|---|---|
| installed | `A.D0` (= `vAD`), AGESA 1.2.0.2, **May 2021** |
| current | `7C37vAR3`, AGESA ComboAm4v2PI **1.2.0.12**, 22 July 2026 |

Roughly ten AGESA revisions apart. It stays as it is, for three reasons:

**The one thing an update would fix is already fixed.** The CPU came up with microcode
`0x0a201009` and Linux replaced it with `0x0a20102e` during boot, independent of the
board firmware.

**Flashing mid-series changes a variable.** Numbers taken before and after would not be
comparable, and there are only two days.

**A flash can fail.** With a two-day window and no measurement that needs it, the
downside is a dead board and the upside is nothing.

What follows from it is written down rather than assumed: the same box under Windows
would run the *older* microcode, because Microsoft ships AMD microcode only rarely and
leaves it to the board vendor. A Windows-versus-Linux comparison on this machine would
therefore carry a second variable.

## History

| Version | Period | State |
|---|---|---|
| **C v1.0** | from 2026-08-23 | Arch freshly installed, llama.cpp `70adb1b` on Vulkan, driver 610.57.04, BIOS A.D0 (05/2021) |

Planned and not yet done: a CUDA build as a **second, separate** measurement, and a BIOS
update **after** the series rather than in the middle of it.

## What it measured while it was here

Borrowed for four days, and it carries the best-covered card in this repository:
**1 058 result rows**, seven models, two backends, eight test types
([raw data](../data/testbench/system-c-rtx4070-super.tsv)).

| Finding | Where |
|---|---|
| CUDA buys 14–25 % prefill and pays with up to 80 % of the context | [backends](../hardware/backends.md#the-other-pair-cuda-against-vulkan-on-one-nvidia-card) |
| The matrix path is prefill only — generation does not move at all | [backends](../hardware/backends.md#what-the-matrix-path-is-worth-and-only-where) |
| Every model peaks at 140–160 W, none at stock | [power](../hardware/power.md#the-rtx-4070-super-has-its-own-optimum-and-it-is-the-same-for-every-model) |
| A 14B holds 16 384 tokens of context here, a 9B holds 204 800 | [context ceiling](../findings/context-ceiling.md) |
| Bandwidth predicts generation across three architectures — and not for Ada | [card comparison](../data/karten/README.md) |

It is also the only card here in the **12 GB class**, which is where most consumer
purchases actually happen: 24 GB, 10 GB and 8 GB were represented, 12 GB was not.

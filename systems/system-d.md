# System D — RTX 2080 Ti, borrowed

<!-- CAPTURED:BEGIN -->
| | |
|---|---|
| **CPU** | Intel(R) Core(TM) i7-8700 CPU @ 3.20GHz |
| **Threads** | 12 |
| **System RAM (GB)** | 31 |
| **Board — vendor** | Micro-Star International Co., Ltd. |
| **Board — model** | Z370 PC PRO (MS-7B49) |
| **BIOS** | 1.51 |
| **BIOS date** | 09/27/2018 |
| **Microcode (running)** | 0x9a |
| **Microcode replaced at boot, from** | *not determined* |
| **OS** | Arch Linux |
| **Kernel** | 7.2.10-arch1-1 |
| **Python** | Python 3.14.8 |
| **Root filesystem** | /dev/sdb2 |
| **Root device** | Samsung SSD 860 EVO 500GB 465.8G sata |
| **Vulkan reports** | NVIDIA GeForce RTX 2080 Ti |
| **Vulkan API** | 1.4.351 |
| **VRAM in use at capture** | 11 MiB |

**Memory modules** (SMBIOS type 17)

| Slot | Size | Part | Rated | Configured |
|---|---:|---|---:|---:|
| ChannelA-DIMM1 | 16384 MB | CMK32GX4M2A2666C16 | 2667 MT/s | 2667 MT/s |
| ChannelB-DIMM1 | 16384 MB | CMK32GX4M2A2666C16 | 2667 MT/s | 2667 MT/s |

**GPUs**

| GPU | VRAM | Driver | Power limit |
|---|---|---|---|
| NVIDIA GeForce RTX 2080 Ti | 11264 MiB | 615.78.08 | 260.00 W |

**PCIe**

| Device | Card to switch | Switch to CPU |
|---|---|---|
| NVIDIA Corporation TU102 [GeForce RTX 2080 Ti Re | Speed 8GT/s, Width x16 | no switch |

**llama.cpp**

| Path | Build | Backend |
|---|---|---|
| `/opt/llama-cpp` | b10273 | vulkan |

*Captured 2026-10-18T01:57:59+00:00 by [`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) — read off the machine, not written by hand. `VRAM in use` and the PCIe link are momentary values: link speed drops at idle, and on a desktop machine the session holds VRAM.*
<!-- CAPTURED:END -->

Not covered by the capture script, read separately:

| | |
|---|---|
| **GPU** | 11 GB GDDR6 at 14 Gbit/s on 352 bit: 616 GB/s (TU102, Turing); NVIDIA open kernel module |
| **Power limit** | 260 W default, 325 W maximum |
| **System RAM** | 2 × 16 GB DDR4 (Corsair CMK32GX4M2A2666C16), one module per channel, rated and configured at 2667 MT/s — read from the raw SMBIOS table (`/sys/firmware/dmi/tables/DMI`, type 17), since dmidecode is not installed there |
| **OS** | installed from the benchmark stick onto a disk the owner set aside |

A borrowed machine: the card sits in its owner's own desktop, and it is reached over a tunnel the machine itself dials out to — nothing on its network was opened. The installer image that put this system on its spare disk carries no secret and is reusable for the next borrowed card.

## Why this card

It is the point the [card comparison](../data/karten/README.md) was missing: **more bandwidth than the RTX 4070 Super, an older architecture.** If generation followed bandwidth alone, it would beat the 4070 Super by 22 %.

## What it measured

The full test suite in three passes: the first with three models, the second with the RTX 4070 SUPER's model set, so both cards compare across every test, the third with a CUDA build next to the Vulkan one (v1.1). 3 414 result rows, nine models measured (Ling-3.0-tiny does not load on `b10273`; gpt-oss-20b does not fit) — [raw data](../data/testbench/system-d-rtx2080ti.tsv).

| Finding | Value |
|---|---|
| **Generation does not follow bandwidth across architectures — the 4070 Super is the outlier, not this card** | `tg128` 191.3 t/s on the 3B model: **0.311 t/s per GB/s**, level with RDNA 3, Turing and Ampere (0.26–0.29); the 4070 Super does 0.400 and beats this card with 18 % less bandwidth — [card comparison](../data/karten/README.md) |
| **Same generation as the 4070 Super on all nine shared models** | ratio 0.93 to 1.03 (2080 Ti / 4070 Super): 3B 191 / 199, Llama-3.1-8B 96 / 93, Qwen3.5-9B 80 / 80, Gemma-4-12B 56 / 54, DeepSeek-R1-14B 48 / 51, Qwen2.5-Coder-14B 48 / 51 t/s |
| **Prefill at half to two thirds of the 4070 Super's** | ratio 0.48 to 0.65 on the same nine models; the 14B models lowest (1 302–1 312 against 2 617–2 696 t/s) |
| Most efficient at 160 W, for all eight models with a power curve, against 260 W stock | +21 % to +34 % tokens per watt-hour, for 16–21 % less generation |
| 11 GB against 12 GB: one model class lower | gpt-oss-20b (12.1 GB file) does not load at all; DeepSeek-R1-14B holds 12 288 tokens of context at f16 here against 16 384 on the 4070 Super |
| Every other model fits fully on the card | peak VRAM 2.3 GB (3B) to 8.6 GB (the 14B models) |
| **CUDA against Vulkan: on Turing CUDA buys generation, not prefill** (v1.1) | generation +5 to +14 % from 9B upwards, prefill up to −20 % on the smaller models; CUDA sees 680 MiB less memory and holds up to 19 % less context — [backends](../hardware/backends.md#on-turing-it-is-the-other-way-round-rtx-2080-ti-2026-10-18) |

The power optimum lands where the [4070 Super's did](../hardware/power.md#the-rtx-4070-super-has-its-own-optimum-and-it-is-the-same-for-every-model) — 140–160 W there, 160 W here — on a card with a 40 W higher default limit.

## What differs from the other systems

The build: `b10273` here, `70adb1b` for the other cards in the comparison; the comparison page shows why that does not move these figures. The machine: an i7-8700 instead of the Ryzens and the measuring host — irrelevant for models resident in VRAM, listed because it was not held constant.

## History

| Version | Period | State |
|---|---|---|
| **D v1.0** | from 2026-10-16 | Arch installed from the benchmark stick, llama.cpp `b10273` on Vulkan, driver 615.78.08; suite run 2026-10-17 with three models, 2026-10-18 with the RTX 4070 SUPER's model set |
| **D v1.1** | from 2026-10-18 | system update (kernel 7.2.10 → 7.2.11, driver unchanged 615.78.08), CUDA 13.4 toolkit, llama.cpp `b10273` built with CUDA for sm_75 in `/opt/llama-cpp-cuda`; Vulkan control after the update unchanged (`tg128` 191.5 against 191.3) |

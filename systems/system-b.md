# System B — the development machine

<!-- CAPTURED:BEGIN -->
| | |
|---|---|
| **CPU** | AMD Ryzen 9 5950X 16-Core Processor |
| **Threads** | 32 |
| **System RAM (GB)** | 31 |
| **Board — vendor** | Micro-Star International Co., Ltd. |
| **Board — model** | MAG X570S TORPEDO MAX (MS-7D54) |
| **BIOS** | A.D1 |
| **BIOS date** | 09/19/2025 |
| **Microcode (running)** | 0xa201213 |
| **Microcode replaced at boot, from** | *not determined* |
| **OS** | Garuda Linux |
| **Kernel** | 7.1.8-zen1-3-zen |
| **Python** | Python 3.14.7 |
| **Root filesystem** | /dev/nvme1n1p2 |
| **Root device** | Seagate FireCuda 530 ZP2000GM30013  1,8T nvme |
| **Vulkan reports** | NVIDIA GeForce RTX 3080 |
| **Vulkan API** | 1.4.341 |
| **VRAM in use at capture** | 2332 MiB |

**GPUs**

| GPU | VRAM | Driver | Power limit |
|---|---|---|---|
| NVIDIA GeForce RTX 3080 | 10240 MiB | 610.57.04 | 370.00 W |

**PCIe**

| Device | Card to switch | Switch to CPU |
|---|---|---|
| NVIDIA Corporation GA102 [GeForce RTX 3080 Lite  | Speed 16GT/s, Width x16 | no switch |

**llama.cpp**

| Path | Build | Backend |
|---|---|---|
| `/opt/llama-cpp` | 9614 (ebc10770ac) | vulkan+cuda |

*Captured 2026-08-23T02:51:41+02:00 by [`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) — read off the machine, not written by hand. `VRAM in use` and the PCIe link are momentary values: link speed drops at idle, and on a desktop machine the session holds VRAM.*
<!-- CAPTURED:END -->

Carried the 9B-class chat evaluations before System A existed.

Note the inversion: **twice the system RAM, less than half the VRAM.** It can offload
models System A cannot hold, and it cannot hold models System A runs entirely in
VRAM.

It also produced a result that is purely a property of the machine: a
sliding-window-attention model **never completed an evaluation there**, breaking off
twice with `forcing full prompt re-processing due to lack of cache data`, then ran
straight through on System A fully resident. See
[METHODOLOGY.md](../METHODOLOGY.md#do-not-evaluate-swa-or-hybrid-models-partially-offloaded).

Unlike System A this board is PCIe Gen 4 and AM4 — it would support a 2×8 split as
well, so a multi-GPU repeat on a newer bus is possible here in principle. Not done.

## History

A result belongs to a system *version*, not to a machine. When hardware or stack
changes, the version increments and older results stay attached to the state that
produced them.

| Version | Stack |
|---|---|
| **B v1.0** | llama.cpp build 9614, CUDA |

The chat, embedding and speech evaluations all ran on B v1.0. **Its full package
state was not captured to the depth System A's was** — the llama.cpp build is
recorded, the surrounding stack is not.

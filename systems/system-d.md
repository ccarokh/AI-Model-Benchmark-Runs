# System D — RTX 2080 Ti, borrowed

| | |
|---|---|
| **GPU** | NVIDIA GeForce RTX 2080 Ti, 11 GB GDDR6, 616 GB/s (TU102, Turing) |
| **Driver** | NVIDIA 615.78.08 (open kernel module) |
| **Power limit** | 260 W default, 325 W maximum |
| **PCIe** | Gen 3 ×16 |
| **CPU** | Intel Core i7-8700, 12 threads |
| **System RAM** | 32 GB DDR4-2666 |
| **Board** | MSI Z370 PC PRO (MS-7B49) |
| **OS** | Arch Linux, kernel 7.2.10 — installed from the benchmark stick onto a disk the owner set aside |
| **llama.cpp** | `b10273` (`a6aa6f545`), Vulkan |

A borrowed machine: the card sits in its owner's own desktop, and it is reached over a tunnel the machine itself dials out to — nothing on its network was opened. The installer image that put this system on its spare disk carries no secret and is reusable for the next borrowed card.

## Why this card

It is the point the [card comparison](../data/karten/README.md) was missing: **more bandwidth than the RTX 4070 Super, an older architecture.** If generation followed bandwidth alone, it would beat the 4070 Super by 22 %.

## What it measured

The full test suite, 756 result rows, three models (the fourth, Ling-3.0-tiny, does not load on `b10273`) — [raw data](../data/testbench/system-d-rtx2080ti.tsv).

| Finding | Value |
|---|---|
| **Generation does not follow bandwidth across architectures — the 4070 Super is the outlier, not this card** | `tg128` 191.3 t/s on the 3B model: **0.311 t/s per GB/s**, level with RDNA 3, Turing and Ampere (0.26–0.29); the 4070 Super does 0.400 and beats this card with 18 % less bandwidth — [card comparison](../data/karten/README.md) |
| Same generation as the 4070 Super on every shared model | 3B 191 / 202, Qwen3.5-9B 80 / 80, Gemma-4-12B 56 / 54 t/s (2080 Ti / 4070 Super) |
| Prefill at about half the 4070 Super's | Qwen3.5-9B 2 559 against 3 607–4 506 t/s, the 3B model 6 397 against 11 413–11 842 |
| Most efficient at 160 W, for every model, against 260 W stock | +22 % to +34 % tokens per watt-hour, for 16–20 % less generation (Qwen3.5-9B: 1 515 against 1 248 tok/Wh, 63 against 78 t/s) |
| All three loadable models fit fully on the card | peak VRAM 2.3 GB (3B), 5.5 GB (9B), 7.6 GB (Gemma-4-12B) |

The power optimum lands where the [4070 Super's did](../hardware/power.md#the-rtx-4070-super-has-its-own-optimum-and-it-is-the-same-for-every-model) — 140–160 W there, 160 W here — on a card with a 40 W higher default limit.

## What differs from the other systems

The build: `b10273` here, `70adb1b` for the other cards in the comparison; the comparison page shows why that does not move these figures. The machine: an i7-8700 instead of the Ryzens and the measuring host — irrelevant for models resident in VRAM, listed because it was not held constant.

## History

| Version | Period | State |
|---|---|---|
| **D v1.0** | from 2026-10-16 | Arch installed from the benchmark stick, llama.cpp `b10273` on Vulkan, driver 615.78.08; first suite run 2026-10-17 |

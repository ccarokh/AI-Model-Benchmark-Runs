# System B — the development machine

<!-- ERFASST:ANFANG -->
| | |
|---|---|
| **CPU** | AMD Ryzen 9 5950X 16-Core Processor |
| **Fäden** | 32 |
| **Arbeitsspeicher (GB)** | 31 |
| **Board — Hersteller** | Micro-Star International Co., Ltd. |
| **Board — Modell** | MAG X570S TORPEDO MAX (MS-7D54) |
| **BIOS** | A.D1 |
| **BIOS-Datum** | 09/19/2025 |
| **Mikrocode (laufend)** | 0xa201213 |
| **Mikrocode beim Start ersetzt von** | *nicht ermittelt* |
| **Betriebssystem** | Garuda Linux |
| **Kernel** | 7.1.8-zen1-3-zen |
| **Python** | Python 3.14.7 |
| **Wurzel-Dateisystem** | /dev/nvme1n1p2 |
| **Datenträger** | Seagate FireCuda 530 ZP2000GM30013  1,8T nvme |
| **Vulkan meldet** | NVIDIA GeForce RTX 3080 |
| **Vulkan-API** | 1.4.341 |
| **VRAM belegt (Leerlauf)** | 2450 MiB |

**Karten**

| Karte | VRAM | Treiber | Leistungsgrenze |
|---|---|---|---|
| NVIDIA GeForce RTX 3080 | 10240 MiB | 610.57.04 | 370.00 W |

**PCIe**

| Gerät | Karte zur Brücke | Brücke zur CPU |
|---|---|---|
| NVIDIA Corporation GA102 [GeForce RTX 3080 Lite  | Speed 16GT/s, Width x16 | keine Bruecke |

**llama.cpp**

| Pfad | Stand |
|---|---|
| `/opt/llama-cpp` | unbekannt |

*Erfasst 2026-08-23T02:29:53+02:00 mit [`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) — nicht von Hand geschrieben.*
<!-- ERFASST:ENDE -->

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

## Verlauf

Ein Ergebnis gehoert zu einer System-*Version*, nicht zu einer Maschine.
Aendert sich Hardware oder Stapel, zaehlt die Version hoch, und aeltere Ergebnisse
bleiben an dem Zustand haengen, der sie erzeugt hat.

| Version | Stack |
|---|---|
| **B v1.0** | llama.cpp build 9614, CUDA |

The chat, embedding and speech evaluations all ran on B v1.0. **Its full package
state was not captured to the depth System A's was** — the llama.cpp build is
recorded, the surrounding stack is not.

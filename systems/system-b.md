# System B — the development machine

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


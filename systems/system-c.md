# System C — RTX 4070 SUPER, two-day window

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

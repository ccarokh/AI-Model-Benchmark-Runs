# System A — the primary test bench

<!-- CAPTURED:BEGIN -->
| | |
|---|---|
| **CPU** | Intel(R) Core(TM) i9-9900K CPU @ 3.60GHz |
| **Threads** | 16 |
| **System RAM (GB)** | 15 |
| **Board — vendor** | Micro-Star International Co., Ltd. |
| **Board — model** | MEG Z390 GODLIKE (MS-7B10) |
| **BIOS** | 1.D0 |
| **BIOS date** | 11/01/2022 |
| **Microcode (running)** | 0xf8 |
| **Microcode replaced at boot, from** | 0x000000f0 |
| **OS** | Arch Linux |
| **Kernel** | 7.1.5-arch1-2 |
| **Python** | Python 3.14.6 |
| **Root filesystem** | /dev/nvme1n1p2 |
| **Root device** | CT1000P1SSD8 931.5G nvme |
| **Vulkan reports** | AMD Radeon RX 7900 XTX (RADV NAVI31) |
| **Vulkan API** | 1.4.354 |
| **VRAM in use at capture** | 1 MiB |

**GPUs**

| GPU | VRAM | Driver | Power limit |
|---|---|---|---|
| NVIDIA GeForce RTX 2070 | 8192 MiB | 610.43.03 | 225.00 W |
|  Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 [Radeon RX 7900 XT/7900 XTX/7900 GRE/7900M] (rev c8) | 24560 MiB | *not determined* | *not determined* |

**PCIe**

| Device | Card to switch | Switch to CPU |
|---|---|---|
| Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 [ | Speed 16GT/s, Width x16 | Speed 8GT/s (downgraded), Width x8 (downgraded) |
| NVIDIA Corporation TU106 [GeForce RTX 2070 Rev.  | Speed 8GT/s, Width x8 (downgraded) | no switch |

**llama.cpp**

| Path | Build | Backend |
|---|---|---|
| `/opt/llama-cpp` | b10098 | vulkan |
| `/opt/llama-cpp-nb` | b10273 | vulkan |
| `/opt/llama-cpp-rocm` | unknown | rocm |

*Captured 2026-08-23T02:51:38+02:00 by [`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) — read off the machine, not written by hand. `VRAM in use` and the PCIe link are momentary values: link speed drops at idle, and on a desktop machine the session holds VRAM.*
<!-- CAPTURED:END -->

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
exception is the [ROCm comparison](../hardware/backends.md), where both runs were taken
on the performance BIOS — internally consistent, but not directly comparable to
figures elsewhere. Measurements in [power.md](../hardware/power.md).

Datasheet: boost to 2680 MHz, 24 GB GDDR6 at 20 Gbps on 384 bit = **960 GB/s**.
Measured effective bandwidth is ~650–670 GB/s under Vulkan, about 70 % of that.

### The second card

An RTX 2070 was added for the [multi-GPU measurements](../hardware/multi-gpu.md). It
started in a chipset slot (Gen 3 ×4 through DMI, 3.94 GB/s) and was physically moved
so both cards run **CPU-direct at ×8**. That doubling changed nothing measurable,
which is itself the result.

**The driver on that card changed during the series.** It ran under `nouveau` when it
was first installed — that is the state the idle-power figures in
[power.md](../hardware/power.md#it-cannot-be-powered-down-when-idle) were taken in — and
runs the proprietary NVIDIA driver now, with `nvidia_uvm` loaded. Any power figure for
the 2070 belongs to the driver it was measured under.

Both GPU stacks are live on System A simultaneously: Mesa/radv drives the 7900 XTX and
carries every inference measurement in this repository, while the NVIDIA driver serves
the 2070 and supplies the `nvidia-smi` PCIe counters used in the
[multi-GPU work](../hardware/multi-gpu.md) — the AMD side offers no equivalent counter.

### PCIe generation

The CPU root port runs at 8 GT/s ×16, i.e. **Gen 3**. The 16 GT/s figures visible on
some devices are card-internal, behind the GPU's own switch, not the path to the CPU.
Gen 4 and Gen 5 SSDs bring nothing here.

## History

A result belongs to a system *version*, not to a machine. When hardware or stack
changes, the version increments and older results stay attached to the state that
produced them.

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

## Bench setup and prefixes

System A runs as an **open bench, no case**. All temperature and fan figures apply
only to that. Putting it in a case is treated as a version increment like any other,
and invalidates the thermal statements.

`/opt/llama-cpp` is the Vulkan build and the one the production service uses.
The HIP build lives separately in `/opt/llama-cpp-rocm` so the rollback is deleting a
directory and no prior measurement is invalidated.

# System A — the primary test bench

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


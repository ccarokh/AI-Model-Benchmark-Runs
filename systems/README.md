# Systems

One file per machine, and in each of them **the same fields in the same order**.

The facts table at the top of every page is **generated, not written**:
[`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) reads it off the machine
itself, the results land as JSON in [`data/systems/`](../data/systems/), and
[`scripts/systems/gensystems.py`](../scripts/systems/gensystems.py) writes the block
between the markers. The prose below it stays hand-written.

## Why this was necessary

Each description used to have its own shape. One talked about system RAM, the next about
the BIOS, the third about the driver — and **whether something was missing was invisible.**
A gap looked like a topic that simply had not come up.

The first pass with a shared field set found four things immediately:

**The PCIe entry for System A was incomplete.** It said "Gen 3, 8 GT/s"; the **width was
missing**. It is **×8**, because the RTX 2070 takes the other eight lanes.

Reading it also nearly walked into the opposite trap. `lspci` reports a **Gen 4 ×16** link
for the 7900 XTX as well — but that one is *inside the card*, behind the PCIe switch Navi
31 carries on board:

```
CPU root port 00:01.0    Gen 3 ×8    ← the CPU offers no more
  └─ 01:00.0  Navi 10 XL Upstream Port of PCI Express Switch   ← on the card
       └─ 02:00.0  downstream port
            └─ 03:00.0  Navi 31 [Radeon RX 7900 XTX]
```

Query only the card and you read the internal branch and take it for the connection to the
machine. **So the collector records both ends** — which is why the table says "card to
switch" next to "switch to CPU" instead of one number that can be mistaken for the other.

**And the width is not a property, it is a state.** Until 3 August the 7900 XTX ran alone
at ×16. The version history had it right all along; the summary table stated today's value
as if it had always held. **A captured snapshot is not a history** — where something
changed, the table has to point at the version list.

**The GPU name came from the wrong device.** A card behind a switch has its PCI path point
at the switch's downstream port, so the entry read "Navi 10 XL Downstream Port of PCI
Express Switch" instead of the card.

**System B returned no PCIe data**, because `lspci -vv` needs root for it. Without root
that now shows as *not readable* rather than as an empty field — a missing permission
otherwise looks like a missing capability. B's page carries a link value because that
capture was run with root.

Two more surfaced while fixing the collector itself:

**The ROCm build was reported as CUDA.** llama.cpp's HIP path uses the CUDA names
internally and prints `ggml_cuda_init`, so reading the output misclassifies it. `ldd` does
not help either — ggml loads its backends at runtime, so they are not linked into the
binary. The backend is now read from the `libggml-*.so` files that exist in the prefix.

**`llama-bench` has no `--version`.** System B's build showed as "unknown" while the
history two lines below recorded "build 9614" — a gap that did not exist. `llama-server`
answers with `version: 9614 (ebc10770ac)`.

## Re-capturing

```
bash scripts/systems/erfassen.sh > data/systems/system-x.json   # on the machine itself
python3 scripts/systems/gensystems.py                            # regenerate the pages
```

Run it with `sudo` where PCIe details matter — without root, `lspci -vv` omits them.

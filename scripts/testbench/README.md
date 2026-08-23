# testbench — one command, every measurement, any machine

```
run_all.py                  everything that applies on this machine
run_all.py --list           what exists and what it does
run_all.py matrix_path      only tests whose name contains this
run_all.py --budget 4       stop starting tests after four hours
run_all.py --lease          hold the GPU lease for the whole run
run_all.py --window 23-11   only work inside that hour window
```

Python 3, standard library only. No packages to install — the machines this runs on are
sometimes borrowed for two days, and a toolchain setup is a reason not to measure.

## What it needs

**A configured llama.cpp** — at least one directory holding `bin/llama-bench` — and at
least one model. Cards and backends are not configured: they are read off the build
itself, because the device id `llama-bench` uses is the only one that can be handed back
to it, and a backend is identified by the `libggml-*.so` files present rather than by the
directory's name.

Everything else is optional. No power sensor, one card, one backend — each of those turns
a test into a **recorded skip**, not a crash.

## It resumes

Every measurement carries a key: `test|card|backend|build|parameter`. A key already in
`results.tsv` is not measured again. Interrupt the run, restart it, it continues where it
stopped.

- repeat one measurement → delete its row
- repeat everything → delete the file

There is no state file to fall out of sync, because **the results are the state**.

Two kinds of not-running exist, and the difference is what a restart does:

| | meaning | written to results | restart |
|---|---|---|---|
| **skipped** | permanent: one card, no power sensor, one backend | yes | does not ask again |
| **deferred** | transient: card busy, build failed, model missing | no | tries again |

Writing both as "skipped" would make a machine without a power sensor retry that test on
every run, forever.

## Adding a test

Drop a file in `tests/`. It is discovered at startup, in filename order — nothing is
registered anywhere.

```python
NAME = "my_test"
DESCRIPTION = "one line, shown by --list"

def run(ctx):
    key = ctx.results.key(NAME, card="", backend="", build="", parameter="x")
    if ctx.results.has(key) or ctx.out_of_budget():
        return
    ...
    ctx.results.add(NAME, parameter="x", value="1.23", unit="t/s")
```

`ctx` carries the machine (`builds`, `cards`, `models`, `power`), the results store, the
log (`ctx.say`), the budget (`ctx.out_of_budget()`) and the two skip forms
(`ctx.skip_permanently`, `ctx.defer`).

**A test may also be any executable file** in `tests/`. It receives the context as JSON on
stdin and writes finished result rows to stdout — so a test can be written in any
language without touching the runner.

## The tests that ship with it

| Test | What it answers |
|---|---|
| `10_reference` | the comparable number: fixed flags, one card at a time |
| `20_output_equivalence` | do two builds still give the same answer, or only a faster one |
| `30_matrix_path` | what the matrix hardware is worth, with each backend's own switches |
| `40_power_curve` | tokens per watt-hour against the power limit |
| `50_context_depth` | how far the context goes, f16 against a quantised KV cache |
| `60_multi_gpu` | split modes and ratios across two or more cards |

## What it guards against

Each of these cost this repository a measurement before it became a rule:

- **a fresh process per measurement** — `llama-bench` and `llama-server` carry state
- **the card must be idle first** — a leftover server makes the next number look normal
- **the kernel log is read before and after** — a throughput test runs through on a card
  that has already reset itself
- **power is integrated over the compute window only** — a sampler that includes model
  loading once turned into a published claim about MoE architectures
- **the flags are read from the build's own `--help`** — `-no-cnv` was valid in v0.2.0 and
  gone two days later, which turned every comparison against a newer build into "produced
  no output"
- **`llama-completion` before `llama-cli`** — the latter now defaults to conversation mode
  and hangs waiting for input that never comes
- **an empty result is recorded as empty** — the checksum of an empty stream
  (`e3b0c442…`) once passed for two builds agreeing

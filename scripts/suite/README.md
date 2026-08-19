# The measurement suite

**One command per build. Everything else happens inside.**

```
suite.sh b10488                    # a nightly tag
suite.sh v0.1.2                    # a pre-release
suite.sh master                    # current upstream
suite.sh installed:/opt/llama-cpp  # measure a prefix that is already built
```

It builds the version if it is not built yet, **verifies that the binary actually uses
that build**, runs four measurement axes, and writes `ergebnis.tsv` under a directory
named for build and model. Re-running is cheap: an existing build is not rebuilt.

```
compare.py <baseline-run> <candidate-run>
```

## Why four axes and not one

| Axis | Answers |
|---|---|
| `synth` | the number everyone quotes — `llama-bench` at depth 0, no KV quantisation |
| `prod` | the number that decides anything — q8_0 cache, filled context |
| `depth_*` | 0 / 8 192 / 32 768, because [the ranking inverts with a full cache](../../findings/context-depth.md) |
| `output_hash` | whether the answers are still the same ones |

On the first run these differed by 19 % between `synth` and `prod` on the same build. A
recommendation resting on `synth` alone is optimistic by that much.

## The checks are built in, not bolted on

Each one exists because it was missed once here.

| Check | The incident |
|---|---|
| `ldd` count per prefix | a second install resolved **all eight** of its libraries to the *first* prefix; only an unsupported architecture gave it away |
| card guard before every step | a health probe landed mid-series and took the GPU down three times |
| skips are logged | an `if free; then … fi` with no `else` made a vision step vanish silently for three nights |
| power integrated over the compute window only | model load time in the mean produced a false architecture finding |
| `dmesg` per step | [a throughput test will pass a card that has already reset itself](../../METHODOLOGY.md#a-throughput-test-will-pass-a-broken-card) |
| output hash | a build that got faster and answers differently did not get faster at the same thing |

## What `compare.py` does and does not do

It reports three gates — output identical, kernel clean, production-shaped numbers not
worse — and a 3 % threshold below which a difference is called *unchanged* rather than
sold as an improvement. **An unmeasured hash counts as not satisfied**, not as probably
fine.

It prints, verbatim:

> This is the basis, not the decision. A "yes" means nothing speaks against it — not that
> a change is needed.

**These measurements are the grounds on which a build is chosen for production.** That is
why the production build is in the comparison and not only the benchmark build, and why
the production flags are measured and not only the synthetic ones.

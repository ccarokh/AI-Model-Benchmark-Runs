# testbench results

One row per measurement, long format, so files from different machines concatenate.

`system-c-rtx4070-super.tsv` — RTX 4070 Super, 12 282 MiB, llama.cpp `70adb1b` built twice
from the same commit (Vulkan and CUDA 13.3), NVIDIA 610.57.04. Twelve models, twelve test types, 4 379 rows -- the complete series; the card was
returned on 2026-08-27.

A `parameter` may carry two suffixes. `@r2`, `@r3` are repeat runs of the same cell — the
speculative test measures three times wherever speculation actually happened, because the
first run of a cell can be an outlier by a factor of three. `@p0.9` and its siblings are
threshold settings within one variant.

| Column | |
|---|---|
| `key` | `test\|card\|backend\|build\|parameter` — unique per measurement; a key already present is never measured again |
| `card` | the device id the backend itself uses (`Vulkan0`, `CUDA0`). **Empty means the device was not pinned** -- the backend chose, and on a host with two cards it spreads the model across both. Rows written before 2026-08-31 are empty for every test except `reference`, and on the two-card host those figures are 35 to 65 percent below the same model on its fast card alone. They are not wrong; they measure a different thing, and they must not be compared with pinned rows |
| `note` | how the figure was taken, or why there is none |

Rows whose `note` starts with `skipped:` are **permanent** skips — one card, no power
sensor — recorded so a rerun does not ask again. A row with an empty `value` is a
measurement that failed, which for the ceiling tests is the result.

`system-a-7900xtx.tsv` — the machine that serves: a 24 560 MiB Radeon RX 7900 XTX beside
an 8 438 MiB RTX 2070, llama.cpp v0.2.0 on Vulkan, 3672 rows. It measures under a GPU
lease, at night, in whatever time the service leaves it.

**Read the `card` column first on this file.** Rows measured before 2026-08-31 leave it
empty, which means the backend chose — and with two cards present it spread each model
across both. Those figures are one to two times below the same model pinned to the fast
card. They are measurements of a machine, not of a card.

Produced by [`run_all.py`](../../scripts/testbench/run_all.py).

## `versionswacht.tsv` — nightly version watch

One row per night × build × model: prompt and generation rate from `llama-bench -p 512 -n 128`, and a hash of a fixed greedy completion (seed 1234, `temp 0`, 96 tokens, "List the first ten prime numbers.") meant to show a change in behaviour that the speed does not. Produced by [`scripts/versionswacht.sh`](../../scripts/versionswacht.sh).

**The `hash` column is only a behaviour fingerprint from 2026-09-30 on.** Before that the completion was taken with `llama-cli`, which in current builds waits in conversation mode for input and was ended by the timeout; the hash covered whatever had been printed by then and differed from night to night on the same build. The speed columns are unaffected. From 2026-09-30 the completion uses `llama-completion`, as the drift check always did, and the hash is stable across runs and — where the builds agree — across builds.

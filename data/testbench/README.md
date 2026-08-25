# testbench results

One row per measurement, long format, so files from different machines concatenate.

`system-c-rtx4070-super.tsv` — RTX 4070 Super, 12 282 MiB, llama.cpp `70adb1b` built twice
from the same commit (Vulkan and CUDA 13.3), NVIDIA 610.57.04. Seven models, eight test
types, 1 058 rows.

| Column | |
|---|---|
| `key` | `test\|card\|backend\|build\|parameter` — unique per measurement; a key already present is never measured again |
| `card` | the device id the backend itself uses (`Vulkan0`, `CUDA0`) |
| `note` | how the figure was taken, or why there is none |

Rows whose `note` starts with `skipped:` are **permanent** skips — one card, no power
sensor — recorded so a rerun does not ask again. A row with an empty `value` is a
measurement that failed, which for the ceiling tests is the result.

Produced by [`run_all.py`](../../scripts/testbench/run_all.py).

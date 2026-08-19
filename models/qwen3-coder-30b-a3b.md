# qwen3-coder-30b-a3b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3-coder-30b-a3b | diff | 12.9 | 22.7 | 98.7 | 4 | 40.5 | 225 |
| qwen3-coder-30b-a3b-slot32k | diff | 12.9 | 32.0 | 95.6 | 17 | 94.0 | 225 |

## one 299-line project spec

Source: [`coding_real_task.tsv`](../data/coding_real_task.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| qwen3-coder-30b-a3b | 3 | 17 | 1272 | 375 | 32 | 9m | delivered |

## SWE-bench Verified

Source: [`coding_swebench.tsv`](../data/coding_swebench.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| qwen3-coder-30b-a3b | oracle | pylint-dev-pylint | f16 | 1 | 7 | 2 | 10 |
| qwen3-coder-30b-a3b | oracle | pytest-dev-pytest | f16 | 7 | 10 | 2 | 19 |
| qwen3-coder-30b-a3b | repomap | astropy-astropy | q8_0 | 4 | 11 | 7 | 22 |
| qwen3-coder-30b-a3b | repomap | psf-requests | q8_0 | 3 | 3 | 1 | 8 |
| qwen3-coder-30b-a3b | repomap | pydata-xarray | q8_0 | 2 | 3 | 17 | 22 |
| qwen3-coder-30b-a3b | repomap | pylint-dev-pylint | f16 | 0 | 3 | 7 | 10 |
| qwen3-coder-30b-a3b | repomap | pytest-dev-pytest | f16 | 2 | 9 | 8 | 19 |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3-coder-30b-a3b | generation | 17.28 | 2560 | 5 | 183.2 | 14.1 | 255.5 | 1024.7 | 2498 | 15 |
| qwen3-coder-30b-a3b | prefill | 17.28 | 20480 | 5 | 2609.6 | 7.8 | 272.2 | 548.3 | 37349 | 8 |

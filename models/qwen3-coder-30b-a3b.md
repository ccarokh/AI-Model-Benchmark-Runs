# qwen3-coder-30b-a3b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 2 of 10 topics.**

## Language understanding — German chat

Not measured. Interpreted in [language-understanding](../use-cases/language-understanding.md) where it is.

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_polyglot.tsv`](../data/coding_polyglot.tsv)** — aider-polyglot, 225 tasks

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3-coder-30b-a3b | diff | 12.9 | 22.7 | 98.7 | 4 | 40.5 | 225 |
| qwen3-coder-30b-a3b-slot32k | diff | 12.9 | 32.0 | 95.6 | 17 | 94.0 | 225 |

**[`coding_swebench.tsv`](../data/coding_swebench.tsv)** — SWE-bench Verified

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| qwen3-coder-30b-a3b | oracle | pylint-dev-pylint | f16 | 1 | 7 | 2 | 10 |
| qwen3-coder-30b-a3b | oracle | pytest-dev-pytest | f16 | 7 | 10 | 2 | 19 |
| qwen3-coder-30b-a3b | repomap | astropy-astropy | q8_0 | 4 | 11 | 7 | 22 |
| qwen3-coder-30b-a3b | repomap | psf-requests | q8_0 | 3 | 3 | 1 | 8 |
| qwen3-coder-30b-a3b | repomap | pydata-xarray | q8_0 | 2 | 3 | 17 | 22 |
| qwen3-coder-30b-a3b | repomap | pylint-dev-pylint | f16 | 0 | 3 | 7 | 10 |
| qwen3-coder-30b-a3b | repomap | pytest-dev-pytest | f16 | 2 | 9 | 8 | 19 |

**[`coding_real_task.tsv`](../data/coding_real_task.tsv)** — one 299-line project spec ⚠️ only `status` is fully trustworthy

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| qwen3-coder-30b-a3b | 3 | 17 | 1272 | 375 | 32 | 9m | delivered |

## Long context — cost against cache depth

Not measured. Interpreted in [context-depth](../findings/context-depth.md) where it is.

## Retrieval — embedding and reranking

Not measured. Interpreted in [embedding](../use-cases/embedding.md) where it is.

## Vision — image input

Not measured. Interpreted in [vision](../use-cases/vision.md) where it is.

## Speech to text

Not measured. Interpreted in [transcription](../use-cases/transcription.md) where it is.

## Image generation

Not measured. Interpreted in [image-generation](../use-cases/image-generation.md) where it is.

## Power and energy

Interpreted in [power](../hardware/power.md).

**[`energy_tokens.tsv`](../data/energy_tokens.tsv)** — tokens per watt-hour, prefill and generation separately

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3-coder-30b-a3b | generation | 17.28 | 2560 | 5 | 183.2 | 14.1 | 255.5 | 1024.7 | 2498 | 15 |
| qwen3-coder-30b-a3b | prefill | 17.28 | 20480 | 5 | 2609.6 | 7.8 | 272.2 | 548.3 | 37349 | 8 |

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

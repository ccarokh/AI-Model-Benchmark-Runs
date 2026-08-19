# qwen3.6-27b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 3 of 10 topics.**

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele.tsv`](../data/chat_belebele.tsv)** — answer read from the first token's probability

| model | correct | n | accuracy |
|---|---|---|---|
| qwen3.6-27b | 140 | 150 | 0.9333 |

**[`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv)** — three harnesses, one variable between each pair

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.6-27b | logprob | off | 140 | 150 | 0.9333 | 150 | 1 | 1.0 | 0 | 0 | 0 | accepted | 8192 | 90.7 |
| qwen3.6-27b | generate | off | 141 | 150 | 0.94 | 1621 | 4 | 10.8 | 0 | 0 | 0 | accepted | 1024 | 130.8 |
| qwen3.6-27b | generate | on | 143 | 150 | 0.9533 | 214064 | 1387 | 1427.1 | 0 | 0 | 0 | accepted | 8192 | 5817.6 |

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_polyglot.tsv`](../data/coding_polyglot.tsv)** — aider-polyglot, 225 tasks

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3.6-27b | diff | 15.1 | 23.6 | 100.0 | 0 | 374.5 | 225 |
| qwen3.6-27b-slot32k | diff | 38.2 | 74.2 | 100.0 | 0 | 797.5 | 225 |
| qwen3.6-27b-slot32k-q8 | diff | 34.2 | 72.9 | 100.0 | 0 | 806.9 | 225 |

**[`coding_swebench.tsv`](../data/coding_swebench.tsv)** — SWE-bench Verified

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| qwen3.6-27b | oracle | pylint-dev-pylint | f16 | 2 | 6 | 2 | 10 |
| qwen3.6-27b | oracle | pytest-dev-pytest | f16 | 9 | 8 | 2 | 19 |
| qwen3.6-27b | repomap | astropy-astropy | q8_0 | 8 | 12 | 2 | 22 |
| qwen3.6-27b | repomap | psf-requests | q8_0 | 2 | 3 | 2 | 8 |
| qwen3.6-27b | repomap | pydata-xarray | q8_0 | 10 | 5 | 7 | 22 |
| qwen3.6-27b | repomap | pylint-dev-pylint | f16 | 1 | 7 | 2 | 10 |
| qwen3.6-27b-x8 | repomap | pytest-dev-pytest | q8_0 | 8 | 7 | 4 | 19 |
| qwen3.6-27b | repomap | pytest-dev-pytest | f16 | 10 | 6 | 3 | 19 |
| qwen3.6-27b | repomap | pytest-dev-pytest | q8_0 | 10 | 6 | 3 | 19 |

**[`coding_real_task.tsv`](../data/coding_real_task.tsv)** — one 299-line project spec ⚠️ only `status` is fully trustworthy

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| qwen3.6-27b | 3 | 21 | 662 | 147 | 33 | 36m | delivered |

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
| qwen3.6-27b | generation | 15.65 | 2560 | 5 | 38.3 | 66.9 | 288.7 | 5327.1 | 481 | 67 |
| qwen3.6-27b | prefill | 15.65 | 20480 | 5 | 815.0 | 25.1 | 287.9 | 1938.7 | 10564 | 25 |

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

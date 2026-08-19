# qwen3.6-27b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## German comprehension (belebele, logprob harness)

Source: [`chat_belebele.tsv`](../data/chat_belebele.tsv) · interpreted in [language-understanding](../use-cases/language-understanding.md)

| model | correct | n | accuracy |
|---|---|---|---|
| qwen3.6-27b | 140 | 150 | 0.9333 |

## German comprehension across three harnesses

Source: [`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.6-27b | logprob | off | 140 | 150 | 0.9333 | 150 | 1 | 1.0 | 0 | 0 | 0 | angenommen | 8192 | 90.7 |
| qwen3.6-27b | generate | off | 141 | 150 | 0.94 | 1621 | 4 | 10.8 | 0 | 0 | 0 | angenommen | 1024 | 130.8 |
| qwen3.6-27b | generate | on | 143 | 150 | 0.9533 | 214064 | 1387 | 1427.1 | 0 | 0 | 0 | angenommen | 8192 | 5817.6 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3.6-27b | diff | 15.1 | 23.6 | 100.0 | 0 | 374.5 | 225 |
| qwen3.6-27b-slot32k | diff | 38.2 | 74.2 | 100.0 | 0 | 797.5 | 225 |
| qwen3.6-27b-slot32k-q8 | diff | 34.2 | 72.9 | 100.0 | 0 | 806.9 | 225 |

## one 299-line project spec

Source: [`coding_real_task.tsv`](../data/coding_real_task.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| qwen3.6-27b | 3 | 21 | 662 | 147 | 33 | 36m | delivered |

## SWE-bench Verified

Source: [`coding_swebench.tsv`](../data/coding_swebench.tsv) · interpreted in [coding](../use-cases/coding.md)

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

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.6-27b | erzeugung | 15.65 | 2560 | 5 | 38.3 | 66.9 | 288.7 | 5327.1 | 481 | 67 |
| qwen3.6-27b | prefill | 15.65 | 20480 | 5 | 815.0 | 25.1 | 287.9 | 1938.7 | 10564 | 25 |

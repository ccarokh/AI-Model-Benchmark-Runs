# gemma-4-12b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

Holds the **vision slot** at 8 837 MiB solo, which is what lets four models share one
card. Failed the coding benchmark outright (11.6 min per task). Calibration model for the
chat-template harness, where it reproduced its published figure to within 0.7 points.

## German comprehension (belebele, logprob harness)

Source: [`chat_belebele.tsv`](../data/chat_belebele.tsv) · interpreted in [language-understanding](../use-cases/language-understanding.md)

| model | correct | n | accuracy |
|---|---|---|---|
| gemma4-12b | 139 | 150 | 0.9267 |

## German comprehension, chat template from the GGUF

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gemma-4-12b | eichung | logprob | off | 138 | 150 | 0.92 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 48.1 |
| gemma-4-12b | eichung | generate | off | 140 | 150 | 0.9333 | 10223 | 48 | 68.2 | 0 | 0 | 0 | 0 | 1024 | 184.8 |
| gemma-4-12b | eichung | generate | on | 135 | 150 | 0.9 | 377808 | 535 | 2518.7 | 0 | 0 | 0 | 0 | 16384 | 5528.9 |

## German comprehension across three harnesses

Source: [`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gemma-4-12b | logprob | off | 139 | 150 | 0.9267 | 150 | 1 | 1.0 | 0 | 0 | 0 | angenommen | 8192 | 44.3 |
| gemma-4-12b | generate | off | 141 | 150 | 0.94 | 10028 | 46 | 66.9 | 0 | 0 | 0 | angenommen | 1024 | 182.6 |
| gemma-4-12b | generate | on | 140 | 150 | 0.9333 | 232092 | 569 | 1547.3 | 17 | 0 | 0 | angenommen | 8192 | 3360.3 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| gemma-4-12b | diff | DURCHGEFALLEN | DURCHGEFALLEN | - | - | >1740 | 0_von_225 |

## one 299-line project spec

Source: [`coding_real_task.tsv`](../data/coding_real_task.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| gemma-4-12b | 2 | 6 | 77 | 25 | — | 13m | delivered |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| gemma-4-12b | erzeugung | 6.62 | 2560 | 5 | 76.9 | 33.3 | 284.8 | 2641.3 | 969 | 34 |
| gemma-4-12b | prefill | 6.62 | 20480 | 5 | 1666.0 | 12.3 | 290.3 | 974.2 | 21023 | 13 |

## what it took to get it running

Source: [`integration_cost.tsv`](../data/integration_cost.tsv) · interpreted in [METHODOLOGY §record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored)

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| gemma-4-12b | GGUF + mmproj | download, copy, --mmproj flag | 1 | vision needs runtime v1.4.0 for --mmproj |

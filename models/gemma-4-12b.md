# gemma-4-12b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 5 of 10 topics.**

Holds the **vision slot** at 8 837 MiB solo, which is what lets four models share one
card. Failed the coding benchmark outright (11.6 min per task). Calibration model for the
chat-template harness, where it reproduced its published figure to within 0.7 points.

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele.tsv`](../data/chat_belebele.tsv)** — answer read from the first token's probability

| model | correct | n | accuracy |
|---|---|---|---|
| gemma4-12b | 139 | 150 | 0.9267 |

**[`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv)** — three harnesses, one variable between each pair

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gemma-4-12b | logprob | off | 139 | 150 | 0.9267 | 150 | 1 | 1.0 | 0 | 0 | 0 | accepted | 8192 | 44.3 |
| gemma-4-12b | generate | off | 141 | 150 | 0.94 | 10028 | 46 | 66.9 | 0 | 0 | 0 | accepted | 1024 | 182.6 |
| gemma-4-12b | generate | on | 140 | 150 | 0.9333 | 232092 | 569 | 1547.3 | 17 | 0 | 0 | accepted | 8192 | 3360.3 |

**[`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv)** — prompt formatted by the chat template inside the GGUF

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gemma-4-12b | calibration | logprob | off | 138 | 150 | 0.92 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 48.1 |
| gemma-4-12b | calibration | generate | off | 140 | 150 | 0.9333 | 10223 | 48 | 68.2 | 0 | 0 | 0 | 0 | 1024 | 184.8 |
| gemma-4-12b | calibration | generate | on | 135 | 150 | 0.9 | 377808 | 535 | 2518.7 | 0 | 0 | 0 | 0 | 16384 | 5528.9 |

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_polyglot.tsv`](../data/coding_polyglot.tsv)** — aider-polyglot, 225 tasks

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| gemma-4-12b | diff | FAILED | FAILED | - | - | >1740 | 0_of_225 |

**[`coding_real_task.tsv`](../data/coding_real_task.tsv)** — one 299-line project spec ⚠️ only `status` is fully trustworthy

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| gemma-4-12b | 2 | 6 | 77 | 25 | — | 13m | delivered |

## Long context — cost against cache depth

Not measured. Interpreted in [context-depth](../findings/context-depth.md) where it is.

## Retrieval — embedding and reranking

Not measured. Interpreted in [embedding](../use-cases/embedding.md) where it is.

## Vision — image input

Interpreted in [vision](../use-cases/vision.md).

**[`vision.tsv`](../data/vision.tsv)** — memory and behaviour with a vision projector loaded

| model | projector | vram_mib_solo | image_tokens | answer_tokens | note |
|---|---|---|---|---|---|
| gemma-4-12b | mmproj-F16 | 8837 | 284 | - | holds the vision slot; four models share one card |

## Speech to text

Not measured. Interpreted in [transcription](../use-cases/transcription.md) where it is.

## Image generation

Not measured. Interpreted in [image-generation](../use-cases/image-generation.md) where it is.

## Power and energy

Interpreted in [power](../hardware/power.md).

**[`energy_tokens.tsv`](../data/energy_tokens.tsv)** — tokens per watt-hour, prefill and generation separately

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| gemma-4-12b | generation | 6.62 | 2560 | 5 | 76.9 | 33.3 | 284.8 | 2641.3 | 969 | 34 |
| gemma-4-12b | prefill | 6.62 | 20480 | 5 | 1666.0 | 12.3 | 290.3 | 974.2 | 21023 | 13 |

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored).

**[`integration_cost.tsv`](../data/integration_cost.tsv)** — shipped format, steps needed, blockers hit

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| gemma-4-12b | GGUF + mmproj | download, copy, --mmproj flag | 1 | vision needs runtime v1.4.0 for --mmproj |

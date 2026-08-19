# mistral-small-3.2-24b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 2 of 10 topics.**

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv)** — prompt formatted by the chat template inside the GGUF

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| mistral-small-3.2-24b | new | logprob | off | 136 | 150 | 0.9067 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 40.0 |
| mistral-small-3.2-24b | new | generate | off | 140 | 150 | 0.9333 | 1092 | 5 | 7.3 | 0 | 0 | 0 | 0 | 1024 | 55.9 |
| mistral-small-3.2-24b | new | generate | on | 140 | 150 | 0.9333 | 1092 | 5 | 7.3 | 0 | 0 | 0 | 0 | 16384 | 56.1 |

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_polyglot.tsv`](../data/coding_polyglot.tsv)** — aider-polyglot, 225 tasks

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| mistral-small-3.2-24b | diff | 1.8 | 4.0 | 86.2 | 54 | 79.7 | 225 |

**[`coding_real_task.tsv`](../data/coding_real_task.tsv)** — one 299-line project spec ⚠️ only `status` is fully trustworthy

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| mistral-small-3.2-24b | 3 | 2 | 105 | 83 | — | 11m | delivered |

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

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

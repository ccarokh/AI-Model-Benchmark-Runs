# qwen3.5-27b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 3 of 10 topics.**

Dense, and it pays for that in prefill — 837 t/s against 2 626 for a *larger* MoE. What it
buys is **the flattest generation curve in the whole depth file, −11.8 %** from an empty
cache to 32 768 tokens.

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv)** — prompt formatted by the chat template inside the GGUF

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-27b | new | logprob | off | 143 | 150 | 0.9533 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 92.2 |
| qwen3.5-27b | new | generate | off | 143 | 150 | 0.9533 | 600 | 4 | 4.0 | 0 | 0 | 0 | 0 | 1024 | 106.4 |
| qwen3.5-27b | new | generate | on | 141 | 150 | 0.94 | 638225 | 2276 | 4254.8 | 0 | 0 | 0 | 0 | 16384 | 17370.9 |

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_polyglot.tsv`](../data/coding_polyglot.tsv)** — aider-polyglot, 225 tasks

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3.5-27b | diff | 25.3 | 49.3 | 98.2 | 4 | 287.5 | 225 |

## Long context — cost against cache depth

Interpreted in [context-depth](../findings/context-depth.md).

**[`context_depth.tsv`](../data/context_depth.tsv)** — throughput and energy at four cache depths

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.5-27b | 0 | on | 837.0 | 39.09 | 289.6 | 1374.5 | 18 |
| qwen3.5-27b | 4096 | on | 779.3 | 38.23 | 279.9 | 1330.0 | 18 |
| qwen3.5-27b | 16384 | on | 681.8 | 36.66 | 271.4 | 1434.4 | 20 |
| qwen3.5-27b | 32768 | on | 560.9 | 34.46 | 254.4 | 1491.9 | 22 |

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

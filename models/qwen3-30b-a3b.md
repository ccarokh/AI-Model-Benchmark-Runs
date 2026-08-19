# qwen3-30b-a3b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 3 of 10 topics.**

⚠️ **Its thinking switch does nothing.** 878 tokens with reasoning off, 879 with it on,
identical accuracy — the template accepts `enable_thinking` and the model, an Instruct
build, ignores it. Without the token counts this would have been published as "reasoning
does not help this model" when no reasoning took place.

At depth it loses 74.5 % of prefill, which
[reverses its apparent advantage over a 9B](../findings/context-depth.md).

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele.tsv`](../data/chat_belebele.tsv)** — answer read from the first token's probability

| model | correct | n | accuracy |
|---|---|---|---|
| qwen3-30b-a3b | 136 | 150 | 0.9067 |

**[`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv)** — three harnesses, one variable between each pair

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3-30b-a3b | logprob | off | 136 | 150 | 0.9067 | 150 | 1 | 1.0 | 0 | 0 | 0 | accepted | 8192 | 22.7 |
| qwen3-30b-a3b | generate | off | 140 | 150 | 0.9333 | 878 | 5 | 5.9 | 0 | 0 | 0 | accepted | 1024 | 29.9 |
| qwen3-30b-a3b | generate | on | 140 | 150 | 0.9333 | 879 | 5 | 5.9 | 0 | 0 | 0 | accepted | 8192 | 23.2 |

## Coding

Not measured. Interpreted in [coding](../use-cases/coding.md) where it is.

## Long context — cost against cache depth

Interpreted in [context-depth](../findings/context-depth.md).

**[`context_depth.tsv`](../data/context_depth.tsv)** — throughput and energy at four cache depths

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3-30b-a3b | 0 | on | 2825.5 | 196.46 | 272.8 | 308.8 | 5 |
| qwen3-30b-a3b | 4096 | on | 2089.3 | 170.16 | 247.3 | 349.2 | 6 |
| qwen3-30b-a3b | 16384 | on | 1154.5 | 131.99 | 222.3 | 509.5 | 9 |
| qwen3-30b-a3b | 32768 | on | 721.3 | 107.29 | 211.0 | 725.3 | 13 |

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
| qwen3-30b-a3b | generation | 17.28 | 2560 | 5 | 190.2 | 13.5 | 278.1 | 1023.7 | 2501 | 14 |
| qwen3-30b-a3b | prefill | 17.28 | 20480 | 5 | 2691.5 | 7.6 | 287.9 | 566.7 | 36138 | 8 |

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

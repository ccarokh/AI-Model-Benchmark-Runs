# qwen3.5-9b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 3 of 10 topics.**

The production chat default. **Unusually robust to context depth** — it loses 36 % of
prefill and 15 % of generation across the full range where a 3B and a 30B lose 45–75 %,
which is attention geometry rather than size: [context depth](../findings/context-depth.md).

Reasoning makes it measurably **worse** (−2.7 points) while generating 160× the text.

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele.tsv`](../data/chat_belebele.tsv)** — answer read from the first token's probability

| model | correct | n | accuracy |
|---|---|---|---|
| qwen3.5-9b | 140 | 150 | 0.9333 |

**[`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv)** — three harnesses, one variable between each pair

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | logprob | off | 136 | 150 | 0.9067 | 150 | 1 | 1.0 | 0 | 0 | 0 | accepted | 8192 | 31.0 |
| qwen3.5-9b | generate | off | 136 | 150 | 0.9067 | 2458 | 4 | 16.4 | 1 | 0 | 0 | accepted | 1024 | 54.5 |
| qwen3.5-9b | generate | on | 132 | 150 | 0.88 | 393474 | 1124 | 2623.2 | 25 | 0 | 0 | accepted | 8192 | 4064.2 |

**[`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv)** — prompt formatted by the chat template inside the GGUF

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | calibration | logprob | off | 136 | 150 | 0.9067 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 34.4 |
| qwen3.5-9b | calibration | generate | off | 136 | 150 | 0.9067 | 2458 | 4 | 16.4 | 1 | 0 | 0 | 0 | 1024 | 54.9 |
| qwen3.5-9b | calibration | generate | on | 137 | 150 | 0.9133 | 519169 | 1119 | 3461.1 | 0 | 0 | 0 | 0 | 16384 | 5460.7 |

**[`chat_belebele_reasoning.tsv`](../data/chat_belebele_reasoning.tsv)** — model answers freely, the letter extracted from the text

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated_at_8192 | no_answer |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | generate | on | 135 | 150 | 0.900 | 395466 | 1131 | 2636 | 28 | 0 |

**[`chat_belebele_n900.tsv`](../data/chat_belebele_n900.tsv)** — n=900 instead of 150, prompt built from the template inside the GGUF

| model | harness | n | correct | accuracy | tokens_mean | no_letter_in_top20 | seconds | thinking |
|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | generate | 900 | 811 | 0.9011 | 7.2 | 0 | 190 | off |
| qwen3.5-9b | logprob | 900 | 811 | 0.9011 | 1.0 | 0 | 117 | off |

## Coding

Not measured. Interpreted in [coding](../use-cases/coding.md) where it is.

## Long context — cost against cache depth

Interpreted in [context-depth](../findings/context-depth.md).

**[`context_depth.tsv`](../data/context_depth.tsv)** — throughput and energy at four cache depths

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.5-9b | 0 | on | 2712.4 | 107.94 | 289.7 | 403.2 | 6 |
| qwen3.5-9b | 4096 | on | 2511.1 | 104.74 | 274.6 | 456.2 | 7 |
| qwen3.5-9b | 16384 | on | 2110.4 | 98.41 | 260.0 | 434.7 | 7 |
| qwen3.5-9b | 32768 | on | 1734.3 | 91.96 | 243.6 | 471.4 | 8 |
| qwen3.5-9b | 0 | off | 2671.7 | 106.73 | 279.5 | 394.0 | 6 |
| qwen3.5-9b | 32768 | off | 1567.3 | 77.64 | 248.9 | 556.1 | 9 |

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
| qwen3.5-9b | generation | 5.28 | 2560 | 5 | 108.1 | 23.7 | 280.2 | 1827.1 | 1401 | 24 |
| qwen3.5-9b | prefill | 5.28 | 20480 | 5 | 2680.4 | 7.6 | 290.2 | 568.4 | 36031 | 8 |

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

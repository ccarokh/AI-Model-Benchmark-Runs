# qwen3.5-9b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

The production chat default. **Unusually robust to context depth** — it loses 36 % of
prefill and 15 % of generation across the full range where a 3B and a 30B lose 45–75 %,
which is attention geometry rather than size: [context depth](../findings/context-depth.md).

Reasoning makes it measurably **worse** (−2.7 points) while generating 160× the text.

## German comprehension (belebele, logprob harness)

Source: [`chat_belebele.tsv`](../data/chat_belebele.tsv) · interpreted in [language-understanding](../use-cases/language-understanding.md)

| model | correct | n | accuracy |
|---|---|---|---|
| qwen3.5-9b | 140 | 150 | 0.9333 |

## German comprehension, chat template from the GGUF

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | eichung | logprob | off | 136 | 150 | 0.9067 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 34.4 |
| qwen3.5-9b | eichung | generate | off | 136 | 150 | 0.9067 | 2458 | 4 | 16.4 | 1 | 0 | 0 | 0 | 1024 | 54.9 |
| qwen3.5-9b | eichung | generate | on | 137 | 150 | 0.9133 | 519169 | 1119 | 3461.1 | 0 | 0 | 0 | 0 | 16384 | 5460.7 |

## German comprehension across three harnesses

Source: [`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | logprob | off | 136 | 150 | 0.9067 | 150 | 1 | 1.0 | 0 | 0 | 0 | angenommen | 8192 | 31.0 |
| qwen3.5-9b | generate | off | 136 | 150 | 0.9067 | 2458 | 4 | 16.4 | 1 | 0 | 0 | angenommen | 1024 | 54.5 |
| qwen3.5-9b | generate | on | 132 | 150 | 0.88 | 393474 | 1124 | 2623.2 | 25 | 0 | 0 | angenommen | 8192 | 4064.2 |

## German comprehension, generate-and-extract

Source: [`chat_belebele_reasoning.tsv`](../data/chat_belebele_reasoning.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated_at_8192 | no_answer |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | generate | on | 135 | 150 | 0.900 | 395466 | 1131 | 2636 | 28 | 0 |

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.5-9b | 0 | on | 2712.4 | 107.94 | 289.7 | 403.2 | 6 |
| qwen3.5-9b | 4096 | on | 2511.1 | 104.74 | 274.6 | 456.2 | 7 |
| qwen3.5-9b | 16384 | on | 2110.4 | 98.41 | 260.0 | 434.7 | 7 |
| qwen3.5-9b | 32768 | on | 1734.3 | 91.96 | 243.6 | 471.4 | 8 |
| qwen3.5-9b | 0 | off | 2671.7 | 106.73 | 279.5 | 394.0 | 6 |
| qwen3.5-9b | 32768 | off | 1567.3 | 77.64 | 248.9 | 556.1 | 9 |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | erzeugung | 5.28 | 2560 | 5 | 108.1 | 23.7 | 280.2 | 1827.1 | 1401 | 24 |
| qwen3.5-9b | prefill | 5.28 | 20480 | 5 | 2680.4 | 7.6 | 290.2 | 568.4 | 36031 | 8 |

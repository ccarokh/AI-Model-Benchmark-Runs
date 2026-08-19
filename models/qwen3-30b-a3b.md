# qwen3-30b-a3b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

⚠️ **Its thinking switch does nothing.** 878 tokens with reasoning off, 879 with it on,
identical accuracy — the template accepts `enable_thinking` and the model, an Instruct
build, ignores it. Without the token counts this would have been published as "reasoning
does not help this model" when no reasoning took place.

At depth it loses 74.5 % of prefill, which
[reverses its apparent advantage over a 9B](../findings/context-depth.md).

## German comprehension — belebele, answer read from the first token's probability

Source: [`chat_belebele.tsv`](../data/chat_belebele.tsv) · interpreted in [language-understanding](../use-cases/language-understanding.md)

| model | correct | n | accuracy |
|---|---|---|---|
| qwen3-30b-a3b | 136 | 150 | 0.9067 |

## German comprehension across three harnesses — one variable between each pair

Source: [`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3-30b-a3b | logprob | off | 136 | 150 | 0.9067 | 150 | 1 | 1.0 | 0 | 0 | 0 | accepted | 8192 | 22.7 |
| qwen3-30b-a3b | generate | off | 140 | 150 | 0.9333 | 878 | 5 | 5.9 | 0 | 0 | 0 | accepted | 1024 | 29.9 |
| qwen3-30b-a3b | generate | on | 140 | 150 | 0.9333 | 879 | 5 | 5.9 | 0 | 0 | 0 | accepted | 8192 | 23.2 |

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3-30b-a3b | 0 | on | 2825.5 | 196.46 | 272.8 | 308.8 | 5 |
| qwen3-30b-a3b | 4096 | on | 2089.3 | 170.16 | 247.3 | 349.2 | 6 |
| qwen3-30b-a3b | 16384 | on | 1154.5 | 131.99 | 222.3 | 509.5 | 9 |
| qwen3-30b-a3b | 32768 | on | 721.3 | 107.29 | 211.0 | 725.3 | 13 |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3-30b-a3b | generation | 17.28 | 2560 | 5 | 190.2 | 13.5 | 278.1 | 1023.7 | 2501 | 14 |
| qwen3-30b-a3b | prefill | 17.28 | 20480 | 5 | 2691.5 | 7.6 | 287.9 | 566.7 | 36138 | 8 |

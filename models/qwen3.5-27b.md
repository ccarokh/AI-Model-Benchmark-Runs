# qwen3.5-27b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

Dense, and it pays for that in prefill — 837 t/s against 2 626 for a *larger* MoE. What it
buys is **the flattest generation curve in the whole depth file, −11.8 %** from an empty
cache to 32 768 tokens.

## German comprehension, chat template from the GGUF

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-27b | neu | logprob | off | 143 | 150 | 0.9533 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 92.2 |
| qwen3.5-27b | neu | generate | off | 143 | 150 | 0.9533 | 600 | 4 | 4.0 | 0 | 0 | 0 | 0 | 1024 | 106.4 |
| qwen3.5-27b | neu | generate | on | 141 | 150 | 0.94 | 638225 | 2276 | 4254.8 | 0 | 0 | 0 | 0 | 16384 | 17370.9 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3.5-27b | diff | 25.3 | 49.3 | 98.2 | 4 | 287.5 | 225 |

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.5-27b | 0 | on | 837.0 | 39.09 | 289.6 | 1374.5 | 18 |
| qwen3.5-27b | 4096 | on | 779.3 | 38.23 | 279.9 | 1330.0 | 18 |
| qwen3.5-27b | 16384 | on | 681.8 | 36.66 | 271.4 | 1434.4 | 20 |
| qwen3.5-27b | 32768 | on | 560.9 | 34.46 | 254.4 | 1491.9 | 22 |

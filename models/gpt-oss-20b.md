# gpt-oss-20b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

⚠️ **Its 0.2133 on the logprob harness is a measurement artefact, not a result.** In 90
of 150 questions no A/B/C/D appeared among the twenty most likely first tokens, because
the model opens with reasoning. On the generate harness it scores **0.9267**. Together
with DeepSeek-R1-14B this makes the failure
[a class rather than a curiosity](../findings/harness-effect.md#gpt-oss-20b-makes-the-harness-failure-a-class-not-a-curiosity).

## German comprehension — prompt formatted by the chat template inside the GGUF, not by a HuggingFace tokenizer

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gpt-oss-20b | new | logprob | off | 32 | 150 | 0.2133 | 150 | 1 | 1.0 | 0 | 0 | 90 | 0 | 1 | 22.0 |
| gpt-oss-20b | new | generate | off | 139 | 150 | 0.9267 | 47336 | 241 | 315.6 | 8 | 0 | 0 | 0 | 1024 | 273.2 |
| gpt-oss-20b | new | generate | on | 139 | 150 | 0.9267 | 96512 | 237 | 643.4 | 0 | 0 | 0 | 0 | 16384 | 550.4 |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| gpt-oss-20b | generation | 11.27 | 2560 | 5 | 210.8 | 12.1 | 272.2 | 938.2 | 2729 | 13 |
| gpt-oss-20b | prefill | 11.27 | 20480 | 5 | 3658.9 | 5.6 | 285.7 | 399.7 | 51235 | 6 |

## foreign benchmark, upstream flags

Source: [`reference_bench.tsv`](../data/reference_bench.tsv) · interpreted in [](../foreign/)

| model | gpu | test | t_per_s | stddev |
|---|---|---|---|---|
| gpt-oss-20b | rx-7900-xtx | pp512 | 3625.51 | 85.75 |
| gpt-oss-20b | rx-7900-xtx | pp4096 | 3689.26 | 23.51 |
| gpt-oss-20b | rx-7900-xtx | tg128 | 212.61 | 1.71 |
| gpt-oss-20b | rx-7900-xtx | pp4096+tg128 | 2422.26 | 5.65 |

## wall-socket power

Source: [`reference_power_socket.tsv`](../data/reference_power_socket.tsv) · interpreted in [power](../hardware/power.md)

| model | gpu | samples | mean_w | median_w | peak_w | over_idle_w |
|---|---|---|---|---|---|---|
| gpt-oss-20b | rx-7900-xtx | 17 | 348.5 | 401.2 | 422.4 | 289.5 |

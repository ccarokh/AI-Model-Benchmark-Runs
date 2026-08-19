# deepseek-r1-14b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

⚠️ **0.2133 on the logprob harness against 0.9133 with reasoning — a 70-point spread
from the harness alone.** `no_letter_in_top20` is **147 of 150**: the harness reads a
position at which this model never puts its answer. See
[harness effect](../findings/harness-effect.md#why-deepseek-r1-collapses).

## German comprehension across three harnesses — one variable between each pair

Source: [`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| deepseek-r1-14b | logprob | off | 32 | 150 | 0.2133 | 150 | 1 | 1.0 | 0 | 0 | 147 | accepted | 8192 | 31.6 |
| deepseek-r1-14b | generate | off | 132 | 150 | 0.88 | 71141 | 397 | 474.3 | 19 | 1 | 0 | accepted | 1024 | 1023.6 |
| deepseek-r1-14b | generate | on | 137 | 150 | 0.9133 | 144935 | 397 | 966.2 | 9 | 0 | 0 | accepted | 8192 | 2083.8 |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| deepseek-r1-14b | generation | 8.37 | 2560 | 5 | 77.3 | 33.1 | 290.5 | 2592.7 | 987 | 33 |
| deepseek-r1-14b | prefill | 8.37 | 20480 | 5 | 1493.1 | 13.7 | 290.4 | 1055.9 | 19395 | 14 |

## foreign benchmark, upstream flags

Source: [`reference_bench.tsv`](../data/reference_bench.tsv) · interpreted in [](../foreign/)

| model | gpu | test | t_per_s | stddev |
|---|---|---|---|---|
| deepseek-r1-14b | rx-7900-xtx | pp512 | 1664.64 | 3.65 |
| deepseek-r1-14b | rx-7900-xtx | pp4096 | 1498.47 | 4.01 |
| deepseek-r1-14b | rx-7900-xtx | tg128 | 77.85 | 0.39 |
| deepseek-r1-14b | rx-7900-xtx | pp4096+tg128 | 929.03 | 3.07 |

## wall-socket power

Source: [`reference_power_socket.tsv`](../data/reference_power_socket.tsv) · interpreted in [power](../hardware/power.md)

| model | gpu | samples | mean_w | median_w | peak_w | over_idle_w |
|---|---|---|---|---|---|---|
| deepseek-r1-14b | rx-7900-xtx | 38 | 408.5 | 409.6 | 420.2 | 349.6 |

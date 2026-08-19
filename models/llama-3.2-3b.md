# llama-3.2-3b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

The dense control at 3B scale, not a competitor. **The most energy-efficient model
measured here** — 3 304 tokens per watt-hour generating, 99 668 reading — and the least
robust to depth, losing 72.9 % of prefill by 32 768 tokens.

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| llama-3.2-3b | 0 | on | 6400.5 | 252.22 | 186.7 | 114.6 | 3 |
| llama-3.2-3b | 4096 | on | 4833.0 | 212.07 | 235.0 | 188.8 | 4 |
| llama-3.2-3b | 16384 | on | 2731.5 | 158.13 | 204.2 | 227.6 | 5 |
| llama-3.2-3b | 32768 | on | 1732.7 | 112.66 | 174.6 | 298.9 | 7 |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| llama-3.2-3b | generation | 1.87 | 2560 | 5 | 251.5 | 10.2 | 267.3 | 774.9 | 3304 | 11 |
| llama-3.2-3b | prefill | 1.87 | 20480 | 5 | 6126.5 | 3.3 | 227.8 | 205.5 | 99668 | 4 |

## foreign benchmark, upstream flags

Source: [`reference_bench.tsv`](../data/reference_bench.tsv) · interpreted in [](../foreign/)

| model | gpu | test | t_per_s | stddev |
|---|---|---|---|---|
| llama-3.2-3b | rx-7900-xtx | pp512 | 5711.19 | 348.68 |
| llama-3.2-3b | rx-7900-xtx | pp4096 | 6136.92 | 63.47 |
| llama-3.2-3b | rx-7900-xtx | tg128 | 251.33 | 2.14 |
| llama-3.2-3b | rx-7900-xtx | pp4096+tg128 | 3360.32 | 19.86 |
| llama-3.2-3b | rtx-2070 | pp512 | 3410.84 | 75.64 |
| llama-3.2-3b | rtx-2070 | pp4096 | 3284.46 | 11.06 |
| llama-3.2-3b | rtx-2070 | tg128 | 125.74 | 0.46 |
| llama-3.2-3b | rtx-2070 | pp4096+tg128 | 1596.88 | 22.06 |

## wall-socket power

Source: [`reference_power_socket.tsv`](../data/reference_power_socket.tsv) · interpreted in [power](../hardware/power.md)

| model | gpu | samples | mean_w | median_w | peak_w | over_idle_w |
|---|---|---|---|---|---|---|
| llama-3.2-3b | rx-7900-xtx | 11 | 385.4 | 408.5 | 418.9 | 326.4 |
| llama-3.2-3b | rtx-2070 | 21 | 251.5 | 260.7 | 303.5 | 192.6 |

## llama-bench, looped vs dense

Source: [`throughput_looped_transformer.tsv`](../data/throughput_looped_transformer.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | size_gib | params_b | backend | gpu | test | t_per_s | stddev |
|---|---|---|---|---|---|---|---|
| llama-3.2-3b-instruct-q4_k_m | 1.87 | 3.21 | Vulkan | RX 7900 XTX | pp512 | 5623.05 | 429.49 |
| llama-3.2-3b-instruct-q4_k_m | 1.87 | 3.21 | Vulkan | RX 7900 XTX | pp4096 | 6031.38 | 55.13 |
| llama-3.2-3b-instruct-q4_k_m | 1.87 | 3.21 | Vulkan | RX 7900 XTX | tg128 | 250.65 | 2.12 |
| llama-3.2-3b-instruct-q4_k_m | 1.87 | 3.21 | Vulkan | RX 7900 XTX | pp4096+tg128 | 3331.42 | 15.85 |

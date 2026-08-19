# llama-3.2-3b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 3 of 10 topics.**

The dense control at 3B scale, not a competitor. **The most energy-efficient model
measured here** — 3 304 tokens per watt-hour generating, 99 668 reading — and the least
robust to depth, losing 72.9 % of prefill by 32 768 tokens.

## Language understanding — German chat

Not measured. Interpreted in [language-understanding](../use-cases/language-understanding.md) where it is.

## Coding

Not measured. Interpreted in [coding](../use-cases/coding.md) where it is.

## Long context — cost against cache depth

Interpreted in [context-depth](../findings/context-depth.md).

**[`context_depth.tsv`](../data/context_depth.tsv)** — throughput and energy at four cache depths

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| llama-3.2-3b | 0 | on | 6400.5 | 252.22 | 186.7 | 114.6 | 3 |
| llama-3.2-3b | 4096 | on | 4833.0 | 212.07 | 235.0 | 188.8 | 4 |
| llama-3.2-3b | 16384 | on | 2731.5 | 158.13 | 204.2 | 227.6 | 5 |
| llama-3.2-3b | 32768 | on | 1732.7 | 112.66 | 174.6 | 298.9 | 7 |

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
| llama-3.2-3b | generation | 1.87 | 2560 | 5 | 251.5 | 10.2 | 267.3 | 774.9 | 3304 | 11 |
| llama-3.2-3b | prefill | 1.87 | 20480 | 5 | 6126.5 | 3.3 | 227.8 | 205.5 | 99668 | 4 |

**[`reference_power_socket.tsv`](../data/reference_power_socket.tsv)** — wall-socket power

| model | gpu | samples | mean_w | median_w | peak_w | over_idle_w |
|---|---|---|---|---|---|---|
| llama-3.2-3b | rx-7900-xtx | 11 | 385.4 | 408.5 | 418.9 | 326.4 |
| llama-3.2-3b | rtx-2070 | 21 | 251.5 | 260.7 | 303.5 | 192.6 |

## Throughput and runtime

Interpreted in [foreign](../foreign/).

**[`reference_bench.tsv`](../data/reference_bench.tsv)** — foreign benchmark, upstream flags

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

**[`throughput_looped_transformer.tsv`](../data/throughput_looped_transformer.tsv)** — llama-bench, looped against dense

| model | size_gib | params_b | backend | gpu | test | t_per_s | stddev |
|---|---|---|---|---|---|---|---|
| llama-3.2-3b-instruct-q4_k_m | 1.87 | 3.21 | Vulkan | RX 7900 XTX | pp512 | 5623.05 | 429.49 |
| llama-3.2-3b-instruct-q4_k_m | 1.87 | 3.21 | Vulkan | RX 7900 XTX | pp4096 | 6031.38 | 55.13 |
| llama-3.2-3b-instruct-q4_k_m | 1.87 | 3.21 | Vulkan | RX 7900 XTX | tg128 | 250.65 | 2.12 |
| llama-3.2-3b-instruct-q4_k_m | 1.87 | 3.21 | Vulkan | RX 7900 XTX | pp4096+tg128 | 3331.42 | 15.85 |

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

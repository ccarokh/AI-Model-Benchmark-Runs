# deepseek-r1-14b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 3 of 10 topics.**

⚠️ **0.2133 on the logprob harness against 0.9133 with reasoning — a 70-point spread
from the harness alone.** `no_letter_in_top20` is **147 of 150**: the harness reads a
position at which this model never puts its answer. See
[harness effect](../findings/harness-effect.md#why-deepseek-r1-collapses).

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv)** — three harnesses, one variable between each pair

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| deepseek-r1-14b | logprob | off | 32 | 150 | 0.2133 | 150 | 1 | 1.0 | 0 | 0 | 147 | accepted | 8192 | 31.6 |
| deepseek-r1-14b | generate | off | 132 | 150 | 0.88 | 71141 | 397 | 474.3 | 19 | 1 | 0 | accepted | 1024 | 1023.6 |
| deepseek-r1-14b | generate | on | 137 | 150 | 0.9133 | 144935 | 397 | 966.2 | 9 | 0 | 0 | accepted | 8192 | 2083.8 |

**[`chat_belebele_n900.tsv`](../data/chat_belebele_n900.tsv)** — n=900 instead of 150, prompt built from the template inside the GGUF

| model | harness | n | correct | accuracy | tokens_mean | no_letter_in_top20 | seconds | thinking |
|---|---|---|---|---|---|---|---|---|
| deepseek-r1-14b | generate | 900 | 834 | 0.9267 | 695.5 | 0 | 12939 | off |
| deepseek-r1-14b | logprob | 900 | 207 | 0.23 | 1.0 | 873 | 101 | off |

## Coding

Not measured. Interpreted in [coding](../use-cases/coding.md) where it is.

## Long context — cost against cache depth

Not measured. Interpreted in [context-depth](../findings/context-depth.md) where it is.

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
| deepseek-r1-14b | generation | 8.37 | 2560 | 5 | 77.3 | 33.1 | 290.5 | 2592.7 | 987 | 33 |
| deepseek-r1-14b | prefill | 8.37 | 20480 | 5 | 1493.1 | 13.7 | 290.4 | 1055.9 | 19395 | 14 |

**[`reference_power_socket.tsv`](../data/reference_power_socket.tsv)** — wall-socket power

| model | gpu | samples | mean_w | median_w | peak_w | over_idle_w |
|---|---|---|---|---|---|---|
| deepseek-r1-14b | rx-7900-xtx | 38 | 408.5 | 409.6 | 420.2 | 349.6 |

## Throughput and runtime

Interpreted in [foreign](../foreign/).

**[`reference_bench.tsv`](../data/reference_bench.tsv)** — foreign benchmark, upstream flags

| model | gpu | test | t_per_s | stddev |
|---|---|---|---|---|
| deepseek-r1-14b | rx-7900-xtx | pp512 | 1664.64 | 3.65 |
| deepseek-r1-14b | rx-7900-xtx | pp4096 | 1498.47 | 4.01 |
| deepseek-r1-14b | rx-7900-xtx | tg128 | 77.85 | 0.39 |
| deepseek-r1-14b | rx-7900-xtx | pp4096+tg128 | 929.03 | 3.07 |

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

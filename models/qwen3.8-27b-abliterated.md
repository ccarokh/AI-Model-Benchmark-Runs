# qwen3.8-27b-abliterated

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 4 of 10 topics.**

**A weight-level de-refusal that costs nothing measurable on eight axes** — one to two
questions on German comprehension at n = 150, where a question is 0.67 points, and
differences under 2 % on depth and energy. The only real difference is **37 % fewer
tokens for the same answers**. Full comparison in
[abliteration](../findings/abliteration.md).

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`abliteration.tsv`](../data/abliteration.tsv)** — de-refused variant against its own base

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | truncated |
|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b-abliterated | logprob | off | 142 | 150 | 0.9467 | 150 | 1 | 0 |
| qwen3.8-27b-abliterated | generate | off | 143 | 150 | 0.9533 | 18310 | 68 | 2 |
| qwen3.8-27b-abliterated | generate | on | 142 | 150 | 0.9467 | 51816 | 264 | 0 |

## Coding

Not measured. Interpreted in [coding](../use-cases/coding.md) where it is.

## Long context — cost against cache depth

Interpreted in [context-depth](../findings/context-depth.md).

**[`context_depth.tsv`](../data/context_depth.tsv)** — throughput and energy at four cache depths

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.8-27b-abl | 0 | on | 803.8 | 39.47 | 283.7 | 1354.8 | 18 |
| qwen3.8-27b-abl | 4096 | on | 773.4 | 38.63 | 276.5 | 1321.7 | 18 |
| qwen3.8-27b-abl | 16384 | on | 689.0 | 37.14 | 268.5 | 1427.0 | 20 |
| qwen3.8-27b-abl | 32768 | on | 577.1 | 34.97 | 258.5 | 1505.1 | 22 |

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
| qwen3.8-27b-abl | prefill | 15.60 | 20480 | 5 | 817.7 | - | 285.4 | 1931.3 | 10605 | 25 |
| qwen3.8-27b-abl | generation | 15.60 | 2560 | 5 | 38.9 | - | 288.3 | 5240.8 | 488 | 66 |

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored).

**[`integration_cost.tsv`](../data/integration_cost.tsv)** — shipped format, steps needed, blockers hit

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| qwen3.8-27b-abliterated | GGUF Q4_K_M | download, copy to host | 0 | same quant as base, deliberately |

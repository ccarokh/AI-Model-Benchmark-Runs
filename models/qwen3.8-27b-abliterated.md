# qwen3.8-27b-abliterated

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

**A weight-level de-refusal that costs nothing measurable on eight axes** — one to two
questions on German comprehension at n = 150, where a question is 0.67 points, and
differences under 2 % on depth and energy. The only real difference is **37 % fewer
tokens for the same answers**. Full comparison in
[abliteration](../findings/abliteration.md).

## de-refused variant against its base

Source: [`abliteration.tsv`](../data/abliteration.tsv) · interpreted in [abliteration](../findings/abliteration.md)

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | truncated |
|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b-abliterated | logprob | off | 142 | 150 | 0.9467 | 150 | 1 | 0 |
| qwen3.8-27b-abliterated | generate | off | 143 | 150 | 0.9533 | 18310 | 68 | 2 |
| qwen3.8-27b-abliterated | generate | on | 142 | 150 | 0.9467 | 51816 | 264 | 0 |

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.8-27b-abl | 0 | on | 803.8 | 39.47 | 283.7 | 1354.8 | 18 |
| qwen3.8-27b-abl | 4096 | on | 773.4 | 38.63 | 276.5 | 1321.7 | 18 |
| qwen3.8-27b-abl | 16384 | on | 689.0 | 37.14 | 268.5 | 1427.0 | 20 |
| qwen3.8-27b-abl | 32768 | on | 577.1 | 34.97 | 258.5 | 1505.1 | 22 |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b-abl | prefill | 15.60 | 20480 | 5 | 817.7 | - | 285.4 | 1931.3 | 10605 | 25 |
| qwen3.8-27b-abl | erzeugung | 15.60 | 2560 | 5 | 38.9 | - | 288.3 | 5240.8 | 488 | 66 |

## what it took to get it running

Source: [`integration_cost.tsv`](../data/integration_cost.tsv) · interpreted in [METHODOLOGY §record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored)

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| qwen3.8-27b-abliterated | GGUF Q4_K_M | download, copy to host | 0 | same quant as base, deliberately |

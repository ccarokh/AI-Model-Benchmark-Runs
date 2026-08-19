# qwen3.8-27b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

**Reads German best of anything measured here on the `generate` harness (0.9667), and is
unusable for agentic coding on this hardware.** 19 minutes per aider task against 1.5 for
a 35B MoE — because it is dense (821 t/s prefill, 39 t/s generation against 2 631 and
138), not because it reasons: the thinking switch was
[verified to work](../use-cases/coding.md) and changed nothing.

⚠️ The latency rules out interactive use. **Batch use is untested.**

Its hybrid Gated DeltaNet attention produces a depth curve
[indistinguishable from the dense 27B it succeeds](../findings/context-depth.md), and
llama.cpp discards its MTP head as `unused tensor`. As a vision model it costs 1.96× the
memory of the incumbent and [invents label text](../use-cases/vision.md).

## de-refused variant against its base

Source: [`abliteration.tsv`](../data/abliteration.tsv) · interpreted in [abliteration](../findings/abliteration.md)

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | truncated |
|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b | logprob | off | 143 | 150 | 0.9533 | 150 | 1 | 0 |
| qwen3.8-27b | generate | off | 145 | 150 | 0.9667 | 28884 | 109 | 4 |
| qwen3.8-27b | generate | on | 137 | 150 | 0.9133 | 59044 | 176 | 0 |

## German comprehension, chat template from the GGUF

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b | neu | logprob | off | 143 | 150 | 0.9533 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 95.7 |
| qwen3.8-27b | neu | generate | off | 145 | 150 | 0.9667 | 28884 | 109 | 192.6 | 4 | 0 | 0 | 0 | 1024 | 897.6 |
| qwen3.8-27b | neu | generate | on | 137 | 150 | 0.9133 | 59044 | 176 | 393.6 | 0 | 0 | 0 | 0 | 16384 | 1718.2 |
| qwen3.8-27b | effort-low | generate | on | 138 | 150 | 0.92 | 46187 | - | - | - | 0 | - | - | 16384 | 1364.6 |
| qwen3.8-27b | effort-medium | generate | on | 138 | 150 | 0.92 | 53626 | - | - | - | 0 | - | - | 16384 | 1571.3 |
| qwen3.8-27b | effort-xhigh | generate | on | 139 | 150 | 0.9267 | 45637 | - | - | - | 0 | - | - | 16384 | 1343.2 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3.8-27b-slot32k | diff | TEILLAUF | TEILLAUF | - | - | 1110 | 61_von_225 |

## SWE-bench Verified

Source: [`coding_swebench.tsv`](../data/coding_swebench.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| qwen3.8-27b | repomap | pytest-dev-pytest | q8_0 | 6 | 10 | 3 | 19 |
| qwen3.8-27b | repomap | pylint-dev-pylint | q8_0 | 3 | 3 | 4 | 10 |

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.8-27b | 0 | on | 821.7 | 39.07 | 282.3 | 1352.1 | 18 |
| qwen3.8-27b | 4096 | on | 785.7 | 38.34 | 281.2 | 1334.3 | 18 |
| qwen3.8-27b | 16384 | on | 681.4 | 36.51 | 272.0 | 1437.1 | 20 |
| qwen3.8-27b | 32768 | on | 572.9 | 34.43 | 259.1 | 1510.2 | 22 |

## tokens per watt-hour

Source: [`energy_tokens.tsv`](../data/energy_tokens.tsv) · interpreted in [power](../hardware/power.md)

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b | prefill | 15.60 | 20480 | 5 | 821.7 | - | 287.7 | 1938.3 | 10566 | 25 |
| qwen3.8-27b | erzeugung | 15.60 | 2560 | 5 | 38.4 | - | 288.9 | 5328.8 | 480 | 67 |

## what it took to get it running

Source: [`integration_cost.tsv`](../data/integration_cost.tsv) · interpreted in [METHODOLOGY §record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored)

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| qwen3.8-27b | GGUF Q4_K_M + mmproj | download, copy to host | 0 | ran on first attempt |

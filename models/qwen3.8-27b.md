# qwen3.8-27b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 6 of 10 topics.**

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

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv)** — prompt formatted by the chat template inside the GGUF

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b | new | logprob | off | 143 | 150 | 0.9533 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 95.7 |
| qwen3.8-27b | new | generate | off | 145 | 150 | 0.9667 | 28884 | 109 | 192.6 | 4 | 0 | 0 | 0 | 1024 | 897.6 |
| qwen3.8-27b | new | generate | on | 137 | 150 | 0.9133 | 59044 | 176 | 393.6 | 0 | 0 | 0 | 0 | 16384 | 1718.2 |
| qwen3.8-27b | effort-low | generate | on | 138 | 150 | 0.92 | 46187 | - | - | - | 0 | - | - | 16384 | 1364.6 |
| qwen3.8-27b | effort-medium | generate | on | 138 | 150 | 0.92 | 53626 | - | - | - | 0 | - | - | 16384 | 1571.3 |
| qwen3.8-27b | effort-xhigh | generate | on | 139 | 150 | 0.9267 | 45637 | - | - | - | 0 | - | - | 16384 | 1343.2 |

**[`abliteration.tsv`](../data/abliteration.tsv)** — de-refused variant against its own base

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | truncated |
|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b | logprob | off | 143 | 150 | 0.9533 | 150 | 1 | 0 |
| qwen3.8-27b | generate | off | 145 | 150 | 0.9667 | 28884 | 109 | 4 |
| qwen3.8-27b | generate | on | 137 | 150 | 0.9133 | 59044 | 176 | 0 |

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_polyglot.tsv`](../data/coding_polyglot.tsv)** — aider-polyglot, 225 tasks

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3.8-27b-slot32k | diff | PARTIAL | PARTIAL | - | - | 1110 | 61_of_225 |
| qwen3.8-27b-nothink-slot32k | diff | PARTIAL | PARTIAL | - | - | 1140 | 38_of_225 |

**[`coding_swebench.tsv`](../data/coding_swebench.tsv)** — SWE-bench Verified

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| qwen3.8-27b | repomap | pytest-dev-pytest | q8_0 | 6 | 10 | 3 | 19 |
| qwen3.8-27b | repomap | pylint-dev-pylint | q8_0 | 3 | 3 | 4 | 10 |

## Long context — cost against cache depth

Interpreted in [context-depth](../findings/context-depth.md).

**[`context_depth.tsv`](../data/context_depth.tsv)** — throughput and energy at four cache depths

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.8-27b | 0 | on | 821.7 | 39.07 | 282.3 | 1352.1 | 18 |
| qwen3.8-27b | 4096 | on | 785.7 | 38.34 | 281.2 | 1334.3 | 18 |
| qwen3.8-27b | 16384 | on | 681.4 | 36.51 | 272.0 | 1437.1 | 20 |
| qwen3.8-27b | 32768 | on | 572.9 | 34.43 | 259.1 | 1510.2 | 22 |

## Retrieval — embedding and reranking

Not measured. Interpreted in [embedding](../use-cases/embedding.md) where it is.

## Vision — image input

Interpreted in [vision](../use-cases/vision.md).

**[`vision.tsv`](../data/vision.tsv)** — memory and behaviour with a vision projector loaded

| model | projector | vram_mib_solo | image_tokens | answer_tokens | note |
|---|---|---|---|---|---|
| qwen3.8-27b | mmproj-F16 | 17329 | - | 700 | 1.96x the memory; fabricated label text while reporting itself certain |

## Speech to text

Not measured. Interpreted in [transcription](../use-cases/transcription.md) where it is.

## Image generation

Not measured. Interpreted in [image-generation](../use-cases/image-generation.md) where it is.

## Power and energy

Interpreted in [power](../hardware/power.md).

**[`energy_tokens.tsv`](../data/energy_tokens.tsv)** — tokens per watt-hour, prefill and generation separately

| model | phase | size_gib | tokens | reps | t_per_s | compute_s | mean_watt_chip | mwh | tokens_per_wh | samples |
|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b | prefill | 15.60 | 20480 | 5 | 821.7 | - | 287.7 | 1938.3 | 10566 | 25 |
| qwen3.8-27b | generation | 15.60 | 2560 | 5 | 38.4 | - | 288.9 | 5328.8 | 480 | 67 |

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored).

**[`integration_cost.tsv`](../data/integration_cost.tsv)** — shipped format, steps needed, blockers hit

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| qwen3.8-27b | GGUF Q4_K_M + mmproj | download, copy to host | 0 | ran on first attempt |

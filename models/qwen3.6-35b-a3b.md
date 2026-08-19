# qwen3.6-35b-a3b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 3 of 10 topics.**

Same `qwen35moe` architecture as Ornith-35B and within 0.2 % of it on every depth
measurement — see
[context depth](../findings/context-depth.md#the-two-best-german-readers-are-one-model).
Fastest agentic model measured here at 1.5 min per aider task.

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv)** — prompt formatted by the chat template inside the GGUF

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | new | logprob | off | 145 | 150 | 0.9667 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 41.3 |
| qwen3.6-35b-a3b | new | generate | off | 144 | 150 | 0.96 | 29585 | 123 | 197.2 | 6 | 0 | 0 | 0 | 1024 | 272.6 |
| qwen3.6-35b-a3b | new | generate | on | 132 | 150 | 0.88 | 232101 | 1463 | 1547.3 | 0 | 0 | 0 | 0 | 16384 | 1853.1 |

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_polyglot.tsv`](../data/coding_polyglot.tsv)** — aider-polyglot, 225 tasks

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | diff | 14.7 | 22.7 | 100.0 | 0 | 142.3 | 225 |
| qwen3.6-35b-a3b-slot32k | diff | 28.9 | 62.7 | 98.7 | 3 | 311.3 | 225 |

**[`coding_swebench.tsv`](../data/coding_swebench.tsv)** — SWE-bench Verified

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | oracle | pytest-dev-pytest | q8_0 | 9 | 7 | 3 | 19 |
| qwen3.6-35b-a3b | repomap | pylint-dev-pylint | q8_0 | 1 | 5 | 4 | 10 |
| qwen3.6-35b-a3b | repomap | pytest-dev-pytest | q8_0 | 7 | 5 | 7 | 19 |

**[`coding_real_task.tsv`](../data/coding_real_task.tsv)** — one 299-line project spec ⚠️ only `status` is fully trustworthy

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | 3 | 3 | 63 | 42 | 42 | 7m | delivered |

## Long context — cost against cache depth

Interpreted in [context-depth](../findings/context-depth.md).

**[`context_depth.tsv`](../data/context_depth.tsv)** — throughput and energy at four cache depths

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | 0 | on | 2631.3 | 138.46 | 257.8 | 372.2 | 6 |
| qwen3.6-35b-a3b | 4096 | on | 2470.3 | 132.87 | 241.3 | 353.1 | 6 |
| qwen3.6-35b-a3b | 16384 | on | 1994.7 | 123.81 | 253.1 | 426.4 | 7 |
| qwen3.6-35b-a3b | 32768 | on | 1577.9 | 115.92 | 253.4 | 486.4 | 8 |

## Retrieval — embedding and reranking

Not measured. Interpreted in [embedding](../use-cases/embedding.md) where it is.

## Vision — image input

Not measured. Interpreted in [vision](../use-cases/vision.md) where it is.

## Speech to text

Not measured. Interpreted in [transcription](../use-cases/transcription.md) where it is.

## Image generation

Not measured. Interpreted in [image-generation](../use-cases/image-generation.md) where it is.

## Power and energy

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

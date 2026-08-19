# qwen3.6-35b-a3b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

Same `qwen35moe` architecture as Ornith-35B and within 0.2 % of it on every depth
measurement — see
[context depth](../findings/context-depth.md#the-two-best-german-readers-are-one-model).
Fastest agentic model measured here at 1.5 min per aider task.

## German comprehension — prompt formatted by the chat template inside the GGUF, not by a HuggingFace tokenizer

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | new | logprob | off | 145 | 150 | 0.9667 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 41.3 |
| qwen3.6-35b-a3b | new | generate | off | 144 | 150 | 0.96 | 29585 | 123 | 197.2 | 6 | 0 | 0 | 0 | 1024 | 272.6 |
| qwen3.6-35b-a3b | new | generate | on | 132 | 150 | 0.88 | 232101 | 1463 | 1547.3 | 0 | 0 | 0 | 0 | 16384 | 1853.1 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | diff | 14.7 | 22.7 | 100.0 | 0 | 142.3 | 225 |
| qwen3.6-35b-a3b-slot32k | diff | 28.9 | 62.7 | 98.7 | 3 | 311.3 | 225 |

## one 299-line project spec

Source: [`coding_real_task.tsv`](../data/coding_real_task.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | 3 | 3 | 63 | 42 | 42 | 7m | delivered |

## SWE-bench Verified

Source: [`coding_swebench.tsv`](../data/coding_swebench.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | oracle | pytest-dev-pytest | q8_0 | 9 | 7 | 3 | 19 |
| qwen3.6-35b-a3b | repomap | pylint-dev-pylint | q8_0 | 1 | 5 | 4 | 10 |
| qwen3.6-35b-a3b | repomap | pytest-dev-pytest | q8_0 | 7 | 5 | 7 | 19 |

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | 0 | on | 2631.3 | 138.46 | 257.8 | 372.2 | 6 |
| qwen3.6-35b-a3b | 4096 | on | 2470.3 | 132.87 | 241.3 | 353.1 | 6 |
| qwen3.6-35b-a3b | 16384 | on | 1994.7 | 123.81 | 253.1 | 426.4 | 7 |
| qwen3.6-35b-a3b | 32768 | on | 1577.9 | 115.92 | 253.4 | 486.4 | 8 |

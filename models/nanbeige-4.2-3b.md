# nanbeige-4.2-3b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 5 of 10 topics.**

A **looped transformer**: 2.50 GiB, ties a 9B on German comprehension, and pays for it in
throughput — prefill 46 % and generation 52 % of a dense 3B at the same scale. The
harness matters unusually much here, 0.760 against 0.900.

Its tokenizer demands `trust_remote_code` and writes that prompt **to stdout**, which
corrupted the collector and threw away three complete 150-question runs — see
[integration cost](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored).

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv)** — three harnesses, one variable between each pair

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | thinking_switch | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| nanbeige-4.2-3b | logprob | off | 114 | 150 | 0.760 | 150 | 1 | 1.0 | 0 | 0 | 0 | accepted | 8192 | - |
| nanbeige-4.2-3b | generate | off | 125 | 150 | 0.833 | - | - | - | - | - | - | accepted | 1024 | - |
| nanbeige-4.2-3b | generate | on | 135 | 150 | 0.900 | - | - | - | - | - | - | accepted | 8192 | - |

**[`chat_belebele_reasoning.tsv`](../data/chat_belebele_reasoning.tsv)** — model answers freely, the letter extracted from the text

| model | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated_at_8192 | no_answer |
|---|---|---|---|---|---|---|---|---|---|---|
| nanbeige-4.2-3b | logprob | off | 114 | 150 | 0.760 | 150 | 1 | 1 | 0 | 0 |
| nanbeige-4.2-3b | generate | on | 133 | 150 | 0.887 | 543490 | 2796 | 3623 | 18 | 0 |

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_swebench.tsv`](../data/coding_swebench.tsv)** — SWE-bench Verified

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| nanbeige-4.2-3b | repomap | pytest-dev-pytest | q8_0 | 4 | 6 | 9 | 19 |
| nanbeige-4.2-3b | repomap | pylint-dev-pylint | q8_0 | 0 | 3 | 7 | 10 |

**[`coding_swebench_empty_causes.tsv`](../data/coding_swebench_empty_causes.tsv)** — why each empty patch was empty

| model | repo | mode | cache | instance | cause | attribution |
|---|---|---|---|---|---|---|
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-5631 | edit_format_missing_filename | model |
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-5787 | edit_format_missing_filename | model |
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-7571 | edit_format_missing_filename | model |
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-10081 | edit_format_missing_filename | model |
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-6197 | aider_input_token_limit | harness |
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-7324 | aider_input_token_limit | harness |
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-10051 | numpy_char_import_error | harness |
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-6202 | aider_scraped_model_emitted_urls | model_via_harness |
| nanbeige-4.2-3b | pytest-dev-pytest | repomap | q8_0 | pytest-dev__pytest-7982 | asked_for_file_instead_of_editing | model |
| nanbeige-4.2-3b | pylint-dev-pylint | repomap | q8_0 | pylint-dev__pylint-4551 | numpy_strings_import_error | harness |
| nanbeige-4.2-3b | pylint-dev-pylint | repomap | q8_0 | pylint-dev__pylint-6528 | edit_format_missing_filename | model |
| nanbeige-4.2-3b | pylint-dev-pylint | repomap | q8_0 | pylint-dev__pylint-6386 | aider_input_token_limit | harness |
| nanbeige-4.2-3b | pylint-dev-pylint | repomap | q8_0 | pylint-dev__pylint-6903 | aider_scraped_model_emitted_urls | model_via_harness |
| nanbeige-4.2-3b | pylint-dev-pylint | repomap | q8_0 | pylint-dev__pylint-4604 | asked_for_file_instead_of_editing | model |
| nanbeige-4.2-3b | pylint-dev-pylint | repomap | q8_0 | pylint-dev__pylint-4970 | asked_for_file_instead_of_editing | model |
| nanbeige-4.2-3b | pylint-dev-pylint | repomap | q8_0 | pylint-dev__pylint-7080 | asked_for_file_instead_of_editing | model |

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
| nanbeige-4.2-3b | generation | 2.50 | 2560 | 5 | 130.0 | 19.7 | 277.1 | 1502.3 | 1704 | 20 |
| nanbeige-4.2-3b | prefill | 2.50 | 20480 | 5 | 2783.1 | 7.4 | 289.9 | 568.0 | 36056 | 8 |

## Throughput and runtime

Interpreted in [foreign](../foreign/).

**[`throughput_looped_transformer.tsv`](../data/throughput_looped_transformer.tsv)** — llama-bench, looped against dense

| model | size_gib | params_b | backend | gpu | test | t_per_s | stddev |
|---|---|---|---|---|---|---|---|
| nanbeige-4.2-3b-q4_k_m | 2.50 | 4.17 | Vulkan | RX 7900 XTX | pp512 | 3384.40 | 29.36 |
| nanbeige-4.2-3b-q4_k_m | 2.50 | 4.17 | Vulkan | RX 7900 XTX | pp4096 | 2793.68 | 4.47 |
| nanbeige-4.2-3b-q4_k_m | 2.50 | 4.17 | Vulkan | RX 7900 XTX | tg128 | 131.15 | 0.74 |
| nanbeige-4.2-3b-q4_k_m | 2.50 | 4.17 | Vulkan | RX 7900 XTX | pp4096+tg128 | 1629.18 | 6.57 |

## What it took to run it

Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored).

**[`integration_cost.tsv`](../data/integration_cost.tsv)** — shipped format, steps needed, blockers hit

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| nanbeige-4.2-3b | GGUF | download, copy | 2 | tokenizer demands trust_remote_code and writes the prompt to stdout, corrupting captured JSON; second llama.cpp prefix needed explicit LD_LIBRARY_PATH |

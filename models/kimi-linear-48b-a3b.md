# kimi-linear-48b-a3b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

**Linear attention, and the worst model here at depth — the opposite of what the
architecture promises.** Prefill falls 332 → 40 t/s from an empty cache to 32 768 tokens,
**39× slower than a 35B MoE at the same depth**, with 4.7× the energy. Detail and the
caveat that this measures one model in llama.cpp on Vulkan rather than the architecture
in principle: [context depth](../findings/context-depth.md).

## German comprehension — prompt formatted by the chat template inside the GGUF, not by a HuggingFace tokenizer

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kimi-linear-48b-a3b | new | logprob | off | 134 | 150 | 0.8933 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 234.6 |
| kimi-linear-48b-a3b | new | generate | off | 133 | 150 | 0.8867 | 20825 | 98 | 138.8 | 1 | 1 | 0 | 0 | 1024 | 1242.7 |
| kimi-linear-48b-a3b | new | generate | on | 133 | 150 | 0.8867 | 35893 | 98 | 239.3 | 0 | 1 | 0 | 0 | 16384 | 1969.0 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| kimi-linear-48b-a3b | diff | 4.9 | 12.0 | 90.7 | 38 | 72.7 | 225 |

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| kimi-linear-48b-a3b | 0 | on | 332.1 | 20.69 | 149.8 | 1507.0 | 37 |
| kimi-linear-48b-a3b | 4096 | on | 328.1 | 20.67 | 156.3 | 1610.3 | 38 |
| kimi-linear-48b-a3b | 16384 | on | 303.0 | 14.61 | 156.7 | 2022.3 | 47 |
| kimi-linear-48b-a3b | 32768 | on | 40.3 | 12.31 | 138.8 | 7059.0 | 183 |

## what it took to get it running

Source: [`integration_cost.tsv`](../data/integration_cost.tsv) · interpreted in [METHODOLOGY §record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored)

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| kimi-linear-48b-a3b | GGUF | download, copy | 0 | linear attention served without special flags |

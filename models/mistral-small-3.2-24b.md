# mistral-small-3.2-24b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## German comprehension — prompt formatted by the chat template inside the GGUF, not by a HuggingFace tokenizer

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| mistral-small-3.2-24b | new | logprob | off | 136 | 150 | 0.9067 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 40.0 |
| mistral-small-3.2-24b | new | generate | off | 140 | 150 | 0.9333 | 1092 | 5 | 7.3 | 0 | 0 | 0 | 0 | 1024 | 55.9 |
| mistral-small-3.2-24b | new | generate | on | 140 | 150 | 0.9333 | 1092 | 5 | 7.3 | 0 | 0 | 0 | 0 | 16384 | 56.1 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| mistral-small-3.2-24b | diff | 1.8 | 4.0 | 86.2 | 54 | 79.7 | 225 |

## one 299-line project spec

Source: [`coding_real_task.tsv`](../data/coding_real_task.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| mistral-small-3.2-24b | 3 | 2 | 105 | 83 | — | 11m | delivered |

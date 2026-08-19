# gemma-4-26b-a4b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

**The only model measured here that gains from reasoning** (0.94 → 0.9533). Failed the
coding benchmark: >29 min per task, answers up to 26 085 tokens.

## German comprehension — prompt formatted by the chat template inside the GGUF, not by a HuggingFace tokenizer

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gemma-4-26b-a4b | new | logprob | off | 140 | 150 | 0.9333 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 42.0 |
| gemma-4-26b-a4b | new | generate | off | 141 | 150 | 0.94 | 12652 | 59 | 84.3 | 0 | 0 | 0 | 0 | 1024 | 139.6 |
| gemma-4-26b-a4b | new | generate | on | 143 | 150 | 0.9533 | 273733 | 653 | 1824.9 | 0 | 0 | 0 | 0 | 16384 | 2378.2 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| gemma-4-26b-a4b | diff | FAILED | FAILED | - | - | 696 | 7_of_225 |

## one 299-line project spec

Source: [`coding_real_task.tsv`](../data/coding_real_task.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| gemma-4-26b-a4b | 0 | — | — | — | — | 49m | nothing |

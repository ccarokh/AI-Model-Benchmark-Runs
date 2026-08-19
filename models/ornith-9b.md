# ornith-9b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## German comprehension, chat template from the GGUF

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ornith-9b | neu | logprob | off | 131 | 150 | 0.8733 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 32.5 |
| ornith-9b | neu | generate | off | 136 | 150 | 0.9067 | 16218 | 73 | 108.1 | 3 | 0 | 0 | 0 | 1024 | 195.5 |
| ornith-9b | neu | generate | on | 127 | 150 | 0.8467 | 87586 | 343 | 583.9 | 0 | 0 | 0 | 0 | 16384 | 923.4 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| ornith-9b | diff | 7.6 | 20.4 | 96.0 | 9 | 74.9 | 225 |

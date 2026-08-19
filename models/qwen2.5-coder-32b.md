# qwen2.5-coder-32b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwen2.5-coder-32b | diff | 4.0 | 8.4 | 80.9 | 75 | 881.8 | 225 |

## one 299-line project spec

Source: [`coding_real_task.tsv`](../data/coding_real_task.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | commits | files | lines | longest_file | entry_point | runtime | status |
|---|---|---|---|---|---|---|---|
| qwen2.5-coder-32b | 0 | — | — | — | — | 107m | aborted |

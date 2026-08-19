# qwopus3.6-35b-a3b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| qwopus3.6-35b-a3b-slot32k | diff | 10.2 | 36.0 | 97.8 | 5 | 630.5 | 225 |

## SWE-bench Verified

Source: [`coding_swebench.tsv`](../data/coding_swebench.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| qwopus3.6-35b-a3b | repomap | pylint-dev-pylint | q8_0 | 1 | 0 | 9 | 10 |
| qwopus3.6-35b-a3b | repomap | pytest-dev-pytest | q8_0 | 7 | 3 | 9 | 19 |

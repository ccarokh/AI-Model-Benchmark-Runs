# mankei-1b-chat

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

**At chance on German comprehension (0.2267 against 0.25 for guessing)** — and the
publisher says so itself. More informative is the generate harness: **0.0067, with 142 of
150 answers containing no parseable letter.** It writes German, it does not follow an
output instruction. Useful here as the lower anchor the table lacked.

## what it took to get it running

Source: [`integration_cost.tsv`](../data/integration_cost.tsv) · interpreted in [METHODOLOGY §record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored)

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| mankei-1b-chat | GGUF ladder f16..q3 | download, copy to host | 0 | publisher ships six quants |

# Document reconciliation — a fictional archive, answers computed

Can a local model work through a pile of private paperwork? Looking up one fact in one document is the easy half. The hard half is **reconciling**: which subscriptions still run, which invoices are still open after partial payments, which doctor's bills never went to the insurer, which of three quotes is the cheapest one still valid. The facts for that are spread over many documents, and the answer has to be computed from them.

The test design follows Peter Quiel's local-against-cloud comparison (fictional archive, answers checked by computation, lookup against reconciliation questions). What it adds is the variable his single number hides: **how the model reaches the documents.**

## The archive

[`generate.py`](generate.py) builds one persona's paperwork for 2024–2025: Katrin Brandt, freelance designer in Leverkusen, landlady of a four-flat house, two children. Everything is fictional — people, companies, insurers, addresses. 243 documents in German, ~122 000 characters (~41 000 tokens): sign-up and cancellation emails, price-change letters, outgoing and incoming invoices, credit notes, 24 monthly bank statements, insurers' reimbursement statements, quotes, tenancy contracts, handover protocols, service-charge statements, and 25 documents that matter to no question. Same seed, same archive.

The facts are fixed first and the documents rendered from them, so every answer is known. [`verify.py`](verify.py) then throws those facts away and derives every answer again **from the document text alone**, the way a careful reader would; it must agree on every item and every cent, or the archive is not published.

Data: [`data/docarchive/archive.jsonl`](../../data/docarchive/archive.jsonl), [`questions.jsonl`](../../data/docarchive/questions.jsonl).

## The questions — 50

| Kind | n | What it takes |
|---|---:|---|
| reconcile | 25 | four families of facts spread over many documents, combined and computed |
| lookup | 19 | one value from one document |
| absent | 6 | the answer is not in the archive; the model has to say so instead of inventing one |

The reconcile questions, and the trap built into each family:

- **Subscriptions running on a key date** (4): sign-ups, price changes taking effect later, cancellations confirmed before the key date but effective after it.
- **Open outgoing invoices** (4): partial payments, payments after the key date, reminders that state the amount open at *their* date. Only the bank statements say what arrived when.
- **Doctor's bills not yet submitted** (6): bills against the insurers' quarterly statements; one question's right answer is "none".
- **Cheapest valid quote** (4): the naive cheapest is always wrong — it has expired by the decision date, or the firm replaced it with a dearer revision; half the quotes state only the net amount.
- **Deposit owed to a tenant who moved out** (3): deposit minus damages from the handover protocol, minus back payments, plus credits from service-charge statements.
- **Contractor costs per flat and year** (4): invoices for other flats, the common areas and the owner's own house mixed in; two credit notes reduce two invoices.

## Three ways to the documents

| Path | What the model gets |
|---|---|
| `context` | every document in the prompt |
| `retrieval` | the 8 documents most similar to the question (bge-m3), the way a RAG chat hands over excerpts |
| `agent` | three tools — `suche` (semantic search), `liste` (filter by type and date), `lies` (read) — and up to 25 rounds to fetch what it needs; after the last round it is told to answer with what it has |

Thinking on and off is the second variable. Greedy, one answer per question, a fresh server per model.

## Scoring — computed, never judged

Every answer ends in a block `ERGEBNIS:` with one line per item and `SUMME:`, or `ERGEBNIS: NICHT IM ARCHIV`. [`score.py`](score.py) reads it two ways: **strict** (only the block counts; no block is a format failure) and **lenient** (the whole answer is searched) — so "could not follow the format" stays apart from "did not find it", the lesson of the aider runs. A reconcile question is solved when exactly the expected items are named and the total is right to the cent; item recall and precision are reported alongside. Scorer self-test: perfect answers 50/50, wrong answers 0/50.

Results: [`use-cases/document-reconciliation.md`](../../use-cases/document-reconciliation.md).

## Running it

```
generate.py data/docarchive && verify.py data/docarchive
lauf.sh <model-dir> <label> "retrieval context agent" off      # on the measuring host
score.py data/docarchive/questions.jsonl answers.jsonl --tsv-runs runs.tsv --tsv-questions per_question.tsv
```

[`run.py`](run.py) talks to any OpenAI-compatible endpoint; [`lauf.sh`](lauf.sh) starts llama-server for the model and for bge-m3, runs the chosen paths and stops both.

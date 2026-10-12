# Document reconciliation — can a local model work through private paperwork?

**First result, one model: how the model reaches the documents decides more than the model.** Qwen3.8-27B (Q4_K_M, thinking off, one RX 7900 XTX) solves **23 of 25** reconciliation questions with the whole archive in its context, **19** when it fetches documents itself with search and read tools, and **6** when a retrieval step hands it the 8 most similar documents. Same model, same questions, same card.

The test: a fictional household archive of 243 German documents (~41 000 tokens) and 50 questions whose answers are computed, not judged — design, traps and scoring in [`scripts/docarchive/`](../scripts/docarchive/README.md). It follows the design of a local-against-cloud comparison posted by Peter Quiel (fictional archive, lookup against reconciliation), and adds the variable a single score hides: the way to the documents.

## Qwen3.8-27B, thinking off (2026-10-12)

| Path | Reconcile (25) | Item recall | Lookup (19) | Absent (6) | Median per question |
|---|---:|---:|---:|---:|---:|
| `context` — every document in the prompt | **23** | 0.98 | 19 | 6 | 6 s |
| `agent` — search, list and read tools, up to 25 rounds | **19** | 0.87 | 19 | 6 | 24 s |
| `retrieval` — the 8 most similar documents (bge-m3) | **6** | 0.47 | 17 | 6 | 6 s |

"Solved" means exactly the expected items and the total right to the cent. "Absent" questions ask for something that is not in the archive; the model never invented an answer on any path. Per path by family:

| Family | context | agent | retrieval |
|---|---:|---:|---:|
| Subscriptions running on a key date (4) | 4 | 3 | 0 |
| Open outgoing invoices after partial payments (4) | 4 | 2 | 0 |
| Doctor's bills not yet submitted (6) | 6 | 4 | 0 |
| Cheapest still-valid quote (4) | 4 | 4 | 4 |
| Deposit owed to a tenant who moved out (3) | 3 | 3 | 2 |
| Contractor costs per flat and year (4) | 2 | 3 | 0 |

**Retrieval fails exactly where the answer needs more documents than it hands over.** The quotes and the deposits need three or four documents each and survive; subscriptions, open invoices, doctor's bills and contractor costs need a whole document type surveyed — every subscription, every bill, every bank statement — and score 0 of 18. The answers show the model working with what it was handed: in the first subscription question it names the prices it could not find instead of guessing them. The limit is the path. A larger *k* moves the line; it does not remove it.

**With everything in context the model is close to perfect.** Both misses are contractor-cost questions, each one invoice short. The archive fits easily (41k tokens); the first question pays for reading it (~60 s), every later one reuses the cached prompt, which is why the median is 6 s.

**The agent path costs about four times the time and loses four questions to context.** Of its six misses: two are server errors (llama-server could not parse the tool-call arguments the model wrote — counted as failures), one ran out of its 25 rounds, one is an arithmetic slip with every item right (99.99 € instead of 100.08 €), one listed a bill too many, one missed an invoice. 464 tool calls for 50 questions; six questions used all 25 rounds.

## What this does and does not say

It says, for one model: on this archive, a local 27B model on one consumer card can do the reconciliation half of private paperwork — if it gets to see the documents. A RAG setup with a fixed number of excerpts cannot, by construction, for any question whose answer is spread over more documents than it retrieves.

It does not say how other models do, whether thinking helps, or how the result scales to an archive that no longer fits the context. Next: thinking on, Gemma-4-31B (the other local model of the comparison this test follows), smaller models, and a larger archive for the context path.

Data: [`answers.jsonl`](../data/docarchive/answers.jsonl) (every answer in full), [`runs.tsv`](../data/docarchive/runs.tsv), [`per_question.tsv`](../data/docarchive/per_question.tsv). Setup: llama.cpp v0.2.0 (Vulkan), 96k context for the agent path, 64k for the others, greedy decoding, one answer per question.

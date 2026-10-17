# Document reconciliation — can a local model work through private paperwork?

**How the model reaches the documents decides more than thinking does — and the model still matters.** Qwen3.8-27B (Q4_K_M, one RX 7900 XTX) solves **23 of 25** reconciliation questions with the whole archive in its context, **19** when it fetches documents itself with search and read tools (**23** with thinking on), and **6** when a retrieval step hands it the 8 most similar documents. Gemma-4-31B, the other local model of the comparison this test follows, solves **8** with the whole archive in context — fifteen questions fewer than Qwen, and not one more.

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

## Thinking, and a second model (2026-10-16)

| Model | Path | Thinking | Reconcile (25) | Item recall | Lookup (19) | Absent (6) | Median per question |
|---|---|---|---:|---:|---:|---:|---:|
| Qwen3.8-27B | `context` | off | **23** | 0.98 | 19 | 6 | 6 s |
| Qwen3.8-27B | `context` | on | 20 | 0.88 | 19 | 6 | 40 s |
| Qwen3.8-27B | `agent` | off | 19 | 0.87 | 19 | 6 | 24 s |
| Qwen3.8-27B | `agent` | on | **23** | 0.92 | 19 | 6 | 45 s |
| Qwen3.8-27B | `retrieval` | off | 6 | 0.47 | 17 | 6 | 6 s |
| Qwen3.8-27B | `retrieval` | on | 6 | 0.41 | 17 | 6 | 23 s |
| Gemma-4-31B ¹ | `context` | off | 8 | 0.70 | 19 | 6 | 5 s |
| Gemma-4-31B ¹ | `agent` | off | 13 | 0.76 | 19 | 6 | 18 s |
| Gemma-4-31B | `retrieval` | off | 7 | 0.43 | 17 | 6 | 8 s |

¹ With a q8_0 KV cache: Gemma's tokenizer makes the archive 57 700 tokens (Qwen's: 41 000), and 64k of context fits the card next to the 31B model only with the cache at q8_0. Every other row uses the default f16 cache.

**Thinking moves Qwen in both directions, and neither move is established.** With tools it solves four more (5 questions only with thinking, 1 only without; exact paired test p = 0.22); with the archive in context three fewer (2 against 5, p = 0.45); with retrieval nothing. It costs four to seven times the time per question every time. Twenty-five questions cannot tell a four-question difference from chance; what they do say is that thinking does not rescue retrieval, because what retrieval lacks is documents, not reasoning.

**Gemma-4-31B is clearly weaker at reconciliation than Qwen3.8-27B.** With the whole archive in context Qwen solves 15 questions Gemma misses and Gemma none that Qwen misses (p < 0.001); with tools 8 against 2 (p = 0.11). Both read single facts equally well (19 of 19 lookups) and neither invents an answer to an absent question — the gap is in combining many documents, not in reading one. The q8 cache on Gemma's two paths is a difference in setup, and its share in the gap was not measured here; Gemma's retrieval row, which runs at f16 like Qwen's, is level with Qwen's (7 against 6) — the gap opens only where many documents have to be combined.

The order matches the comparison this test follows (Qwen 5 of 12, Gemma 3 of 12 there, on four questions); the distance does not, because there the way to the documents was not held fixed.

## What this does and does not say

It says, for one model: on this archive, a local 27B model on one consumer card can do the reconciliation half of private paperwork — if it gets to see the documents. A RAG setup with a fixed number of excerpts cannot, by construction, for any question whose answer is spread over more documents than it retrieves.

It does not say how the result scales to an archive that no longer fits the context, or how smaller models and other families do. Next: smaller models, and a larger archive for the context path.

Data: [`answers.jsonl`](../data/docarchive/answers.jsonl) (every answer in full), [`runs.tsv`](../data/docarchive/runs.tsv), [`per_question.tsv`](../data/docarchive/per_question.tsv). Setup: llama.cpp v0.2.0 (Vulkan), greedy decoding, one answer per question; Qwen3.8-27B with 96k context for the agent path and 64k for the others, Gemma-4-31B with 48k for retrieval and 64k (q8 cache) for context, 96k (q8 cache) for the agent path.

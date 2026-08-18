# Where the answer sits in the chunk decides whether it is found

**The same embedding model finds 60 % of answers when the relevant sentence is at the
start of a 3 000-character chunk and 5 % when it is at the end.** Twelve-fold, from
position alone. Nothing about the model, the query or the corpus changed.

This is not a benchmark result. It is a defect in a running RAG system, found while
measuring something else.

Measured on [System A](../SYSTEMS.md#system-a), belebele `deu_Latn`, n = 80 passages,
cosine nearest-neighbour retrieval — the same harness behind
[`embedding_retrieval.tsv`](../data/embedding_retrieval.tsv). Full table in
[`data/embedding_chunk_position.tsv`](../data/embedding_chunk_position.tsv).

## The measurement

Each target passage is embedded inside a chunk of ~3 000 characters — **our production
chunk size**, from `ingestion-docx/chunking.py` (3 000 target, 6 000 maximum). The rest
of the chunk is filler drawn from other passages. Only the **position** of the target
inside the chunk varies.

| Position | BGE-M3 (CLS) | BGE-M3 (mean) | Mankei-326M (last) |
|---|---:|---:|---:|
| **Start** | **0.600** | 0.300 | 0.125 |
| Middle | 0.0625 | 0.125 | 0.1625 |
| **End** | 0.050 | 0.1125 | **0.2875** |
| Spread | **12.0×** | 2.7× | 2.3× |
| Mean | **0.2375** | 0.179 | 0.192 |

For reference, the same models on **short** passages — one passage per chunk, roughly
135 tokens:

| | Short passage | Best long-chunk case | Worst |
|---|---:|---:|---:|
| BGE-M3 | **0.9625** | 0.600 | 0.050 |
| Mankei-326M | 0.8750 | 0.2875 | 0.125 |

**BGE-M3 goes from 0.9625 to 0.05 without becoming a worse model.** The only change is
that the answer is now surrounded by 2 500 characters of other text.

## The bias follows the pooling, exactly

Each model peaks where its pooling strategy looks:

| Pooling | Reads | Peaks at |
|---|---|---|
| CLS | the first token | **start** — 0.600 |
| last-token | the final token | **end** — 0.2875 |
| mean | the whole sequence | flattest — 2.7× instead of 12× |

This also corrects a claim made earlier in this work. With the target fixed at the end
of the chunk, Mankei-326M appeared to beat BGE-M3 on long chunks — 0.2875 against 0.050.
**That was the test design, not the model.** Placing the target at the start reverses it
to 0.600 against 0.125. Position had to become a variable before either number meant
anything.

## Changing the pooling does not fix it

Mean pooling is the obvious remedy for a positional bias, and it does flatten the curve.
It does not rescue retrieval:

| | Best case | Worst case | Mean |
|---|---:|---:|---:|
| CLS | 0.600 | 0.050 | **0.2375** |
| mean | 0.300 | **0.1125** | 0.179 |

**Mean pooling halves the best case to double the worst**, and comes out lower overall.
It changes the *shape* of the failure, not the failure.

**The problem is the chunk, not the pooling.** At 3 000 characters the relevant passage
is roughly one sixth of the text, and the embedding is dominated by the other five
sixths regardless of how it is computed.

## What this means for a RAG system

**A chunk size chosen for readability is not automatically a chunk size that can be
retrieved.** Ours was chosen to keep paragraphs intact. Nobody measured what it costs
retrieval, and it costs almost everything.

Three consequences, in order of how cheaply they can be tested:

1. **Smaller chunks.** The short-passage rows (~135 tokens, 0.9625) and the long ones
   (~760 tokens, 0.05–0.60) bracket a range nobody has swept. The chunk size at which
   retrieval falls off is a single measurement away.
2. **Position within a chunk is a hidden variable in every retrieval benchmark.**
   Standard sets use short passages, where it cannot appear. Ours is the operating
   condition; theirs is not.
3. **Pooling is a per-deployment choice with a measurable cost**, and llama.cpp's
   default for a given model is not necessarily the one you want.

## The chunk size at which it breaks

The 12× swing above is measured at one size. Sweeping it gives the number a RAG system
is actually built on — BGE-M3, CLS pooling, answer at the start against the end:

| Chunk characters | Answer at start | Answer at end | Ratio |
|---:|---:|---:|---:|
| **400** | **0.9500** | **0.8625** | **1.1×** |
| 800 | 0.8750 | 0.4875 | 1.8× |
| 1 200 | 0.7875 | 0.2875 | 2.7× |
| 1 600 | 0.7000 | 0.1875 | 3.7× |
| 2 000 | 0.6500 | 0.1500 | 4.3× |
| **3 000** ← our production size | 0.6000 | **0.0500** | **12.0×** |
| 4 500 | 0.5125 | 0.0125 | 41.0× |
| **6 000** ← our configured maximum | 0.5000 | 0.0250 | 20.0× |

**At 400 characters position stops mattering** — 0.95 against 0.86, and both ends are
usable. **The cliff is between 800 and 1 200**, where the end position falls below 0.50
and a chunk becomes findable only by its opening.

Our production chunks sit far past it. **Practically, only the first part of any
production chunk is reliably searchable**; the rest dilutes the embedding without
contributing to retrieval.

Cost of moving: at 400 instead of 3 000 characters there are roughly seven and a half
times as many chunks — more embeddings and more vector storage. Against that, the worst
case rises from 0.05 to 0.86.

### The same curve for last-token pooling is the mirror image

Mankei-326M, which pools the final token, at the same sizes:

| Chunk characters | Answer at start | Answer at end |
|---:|---:|---:|
| 400 | 0.8125 | 0.7250 |
| 800 | 0.6375 | 0.2750 |
| 1 600 | 0.2625 | 0.2000 |
| 3 000 | 0.1250 | 0.2875 |
| 6 000 | **0.0125** | **0.4375** |

**It fails at the opposite end.** By 6 000 characters an answer at the start is found
once in eighty, while an answer at the end is found more often than at 1 600 — the last
token stays the last token however long the chunk grows.

**Two architectures, opposite failure modes, and the same verdict at 400 characters**
where both positions work. That is the part of this that does not depend on which
embedder you picked.

## A reranker recovers most of it

If the answer is still *in* the chunk, retrieval failing is a sorting problem rather than
a data-loss problem — and sorting is what a reranker does. Mankei-326M-Reranker on the
worst case, 3 000 characters with the answer at the end:

| | Accuracy | Truncated |
|---|---:|---:|
| BGE-M3 embedder alone | 0.050 | — |
| Reranker at its documented 192 tokens | **0.000** | 40 / 40 |
| **Reranker at 1 024 tokens** | **0.525** | 0 / 40 |

**The zero is the truncation, not the model.** At 192 tokens — the length the publisher
specifies — a 3 000-character chunk is cut long before its end, so the answer is never
seen. Given the whole chunk, the same model finds 21 of 40.

**0.05 to 0.525 is tenfold, exactly where the embedder is weakest.** For a running system
that is cheaper than re-chunking a corpus.

⚠️ Three limits on that number. The reranker here scores **all** candidates, where in
production it only sees the embedder's top-k — **it can only rescue what retrieval already
surfaced.** It runs at n = 40 against the embedder's n = 80. And 1 024 tokens is **five
times its documented length**; that it works at all there is itself unverified territory.

⚠️ An earlier version of this measurement used `AutoModelForSequenceClassification`,
which silently initialises a **random** scoring head — the real one ships separately as
`head.pt`. Those numbers (0.35 / 0.025 / 0.0) were noise and are not in the data file.

## What this does not settle

- **One corpus, one language, n = 80.** The effect is far larger than the sampling
  noise, but the exact figures are not precise.
- **Filler is other belebele passages** — topically unrelated. Real chunks are internally
  coherent, which may dilute less. **This is the most likely way these numbers are too
  pessimistic**, and it is untested.
- **No chunk-size sweep yet.** The 12× swing is measured at exactly one size.
- **Reranking is not in the loop.** A reranker over a wider candidate set may recover
  much of this, and ours is unmeasured on long chunks.

## Scripts

- [`scripts/chat/eval_embed_chunks.py`](../scripts/chat/eval_embed_chunks.py) — via an
  embedding server
- [`scripts/chat/eval_embed_hf.py`](../scripts/chat/eval_embed_hf.py) — direct
  `transformers`, for models llama.cpp cannot convert

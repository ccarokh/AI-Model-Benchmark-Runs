# mankei-326m-reranker

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

**Recovers the worst case of our chunking from 0.05 to 0.525** — but only when allowed
1 024 tokens instead of its documented 192. At 192 it scores exactly zero, because a
3 000-character chunk is cut long before its end. That zero is truncation, not
capability: [chunk position](../findings/chunk-position.md#a-reranker-recovers-most-of-it).

⚠️ Its scoring head ships separately as `head.pt`. `AutoModelForSequenceClassification`
initialises a **random** head instead and produces plausible noise.

## retrieval against chunk size

Source: [`embedding_chunk_size.tsv`](../data/embedding_chunk_size.tsv) · interpreted in [chunk-position](../findings/chunk-position.md)

| model | pooling | chunk_chars | position | correct | n | accuracy | max_len | truncated |
|---|---|---|---|---|---|---|---|---|
| mankei-326m-reranker | last | 0 | end | 28 | 40 | 0.7000 | 192 | 1 |
| mankei-326m-reranker | last | 3000 | start | 20 | 40 | 0.5000 | 192 | 40 |
| mankei-326m-reranker | last | 3000 | end | 0 | 40 | 0.0000 | 192 | 40 |
| mankei-326m-reranker | last | 3000 | end | 21 | 40 | 0.5250 | 1024 | 0 |

## what it took to get it running

Source: [`integration_cost.tsv`](../data/integration_cost.tsv) · interpreted in [METHODOLOGY §record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored)

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| mankei-326m-reranker | safetensors only | download, convert needed | 1 | not yet run |

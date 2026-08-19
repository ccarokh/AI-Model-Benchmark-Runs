# mankei-326m-embedder

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

A German embedder, 326M, Apache-2.0, trained from scratch in Germany. **0.875 retrieval
against BGE-M3's 0.9625 at a third the size.**

It uses last-token pooling and therefore fails at the **opposite end** from BGE-M3: on a
6 000-character chunk it finds an answer at the start once in eighty, and one at the end
more often than at 1 600 — [chunk position](../findings/chunk-position.md).

⚠️ Its card names 256 tokens; the config allows 2 048, and at 2 048 it scores 0.2875 where
the 256 cap gives 0.0. **Reading the card instead of measuring would have removed it.**

## retrieval against answer position

Source: [`embedding_chunk_position.tsv`](../data/embedding_chunk_position.tsv) · interpreted in [chunk-position](../findings/chunk-position.md)

| model | pooling | variant | position | correct | n | accuracy | chunk_tokens_mean | truncated |
|---|---|---|---|---|---|---|---|---|
| mankei-326m-embedder | last | short | - | 70 | 80 | 0.8750 | 120 | 0 |
| mankei-326m-embedder | last | long3000 | start | 10 | 80 | 0.1250 | 694 | 0 |
| mankei-326m-embedder | last | long3000 | middle | 13 | 80 | 0.1625 | 697 | 0 |
| mankei-326m-embedder | last | long3000 | end | 23 | 80 | 0.2875 | 692 | 0 |
| mankei-326m-embedder | last | long3000_trunc256 | end | 0 | 80 | 0.0000 | 692 | 80 |

## retrieval against chunk size

Source: [`embedding_chunk_size.tsv`](../data/embedding_chunk_size.tsv) · interpreted in [chunk-position](../findings/chunk-position.md)

| model | pooling | chunk_chars | position | correct | n | accuracy | max_len | truncated |
|---|---|---|---|---|---|---|---|---|
| mankei-326m-embedder | last | 400 | start | - | 80 | 0.8125 | 2048 | 0 |
| mankei-326m-embedder | last | 400 | end | - | 80 | 0.725 | 2048 | 0 |
| mankei-326m-embedder | last | 800 | start | - | 80 | 0.6375 | 2048 | 0 |
| mankei-326m-embedder | last | 800 | end | - | 80 | 0.275 | 2048 | 0 |
| mankei-326m-embedder | last | 1600 | start | - | 80 | 0.2625 | 2048 | 0 |
| mankei-326m-embedder | last | 1600 | end | - | 80 | 0.200 | 2048 | 0 |
| mankei-326m-embedder | last | 3000 | start | - | 80 | 0.125 | 2048 | 0 |
| mankei-326m-embedder | last | 3000 | end | - | 80 | 0.2875 | 2048 | 0 |
| mankei-326m-embedder | last | 6000 | start | - | 80 | 0.0125 | 2048 | 0 |
| mankei-326m-embedder | last | 6000 | end | - | 80 | 0.4375 | 2048 | 0 |

## what it took to get it running

Source: [`integration_cost.tsv`](../data/integration_cost.tsv) · interpreted in [METHODOLOGY §record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored)

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| mankei-326m-embedder | safetensors only | download, convert_hf_to_gguf.py, copy | 1 | no GGUF published; LlamaModel arch converts cleanly |

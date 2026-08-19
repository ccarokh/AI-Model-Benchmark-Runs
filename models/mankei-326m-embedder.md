# mankei-326m-embedder

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 2 of 10 topics.**

A German embedder, 326M, Apache-2.0, trained from scratch in Germany. **0.875 retrieval
against BGE-M3's 0.9625 at a third the size.**

It uses last-token pooling and therefore fails at the **opposite end** from BGE-M3: on a
6 000-character chunk it finds an answer at the start once in eighty, and one at the end
more often than at 1 600 — [chunk position](../findings/chunk-position.md).

⚠️ Its card names 256 tokens; the config allows 2 048, and at 2 048 it scores 0.2875 where
the 256 cap gives 0.0. **Reading the card instead of measuring would have removed it.**

## Language understanding — German chat

Not measured. Interpreted in [language-understanding](../use-cases/language-understanding.md) where it is.

## Coding

Not measured. Interpreted in [coding](../use-cases/coding.md) where it is.

## Long context — cost against cache depth

Not measured. Interpreted in [context-depth](../findings/context-depth.md) where it is.

## Retrieval — embedding and reranking

Interpreted in [embedding](../use-cases/embedding.md).

**[`embedding_chunk_position.tsv`](../data/embedding_chunk_position.tsv)** — retrieval against where the answer sits in the chunk

| model | pooling | variant | position | correct | n | accuracy | chunk_tokens_mean | truncated |
|---|---|---|---|---|---|---|---|---|
| mankei-326m-embedder | last | short | - | 70 | 80 | 0.8750 | 120 | 0 |
| mankei-326m-embedder | last | long3000 | start | 10 | 80 | 0.1250 | 694 | 0 |
| mankei-326m-embedder | last | long3000 | middle | 13 | 80 | 0.1625 | 697 | 0 |
| mankei-326m-embedder | last | long3000 | end | 23 | 80 | 0.2875 | 692 | 0 |
| mankei-326m-embedder | last | long3000_trunc256 | end | 0 | 80 | 0.0000 | 692 | 80 |

**[`embedding_chunk_size.tsv`](../data/embedding_chunk_size.tsv)** — retrieval against chunk size

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

## Vision — image input

Not measured. Interpreted in [vision](../use-cases/vision.md) where it is.

## Speech to text

Not measured. Interpreted in [transcription](../use-cases/transcription.md) where it is.

## Image generation

Not measured. Interpreted in [image-generation](../use-cases/image-generation.md) where it is.

## Power and energy

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored).

**[`integration_cost.tsv`](../data/integration_cost.tsv)** — shipped format, steps needed, blockers hit

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| mankei-326m-embedder | safetensors only | download, convert_hf_to_gguf.py, copy | 1 | no GGUF published; LlamaModel arch converts cleanly |

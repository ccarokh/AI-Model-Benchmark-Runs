# mankei-326m-reranker

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 2 of 10 topics.**

**Recovers the worst case of our chunking from 0.05 to 0.525** — but only when allowed
1 024 tokens instead of its documented 192. At 192 it scores exactly zero, because a
3 000-character chunk is cut long before its end. That zero is truncation, not
capability: [chunk position](../findings/chunk-position.md#a-reranker-recovers-most-of-it).

⚠️ Its scoring head ships separately as `head.pt`. `AutoModelForSequenceClassification`
initialises a **random** head instead and produces plausible noise.

## Language understanding — German chat

Not measured. Interpreted in [language-understanding](../use-cases/language-understanding.md) where it is.

## Coding

Not measured. Interpreted in [coding](../use-cases/coding.md) where it is.

## Long context — cost against cache depth

Not measured. Interpreted in [context-depth](../findings/context-depth.md) where it is.

## Retrieval — embedding and reranking

Interpreted in [embedding](../use-cases/embedding.md).

**[`embedding_chunk_size.tsv`](../data/embedding_chunk_size.tsv)** — retrieval against chunk size

| model | pooling | chunk_chars | position | correct | n | accuracy | max_len | truncated |
|---|---|---|---|---|---|---|---|---|
| mankei-326m-reranker | last | 0 | end | 28 | 40 | 0.7000 | 192 | 1 |
| mankei-326m-reranker | last | 3000 | start | 20 | 40 | 0.5000 | 192 | 40 |
| mankei-326m-reranker | last | 3000 | end | 0 | 40 | 0.0000 | 192 | 40 |
| mankei-326m-reranker | last | 3000 | end | 21 | 40 | 0.5250 | 1024 | 0 |

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
| mankei-326m-reranker | safetensors only | download, convert needed | 1 | not yet run |

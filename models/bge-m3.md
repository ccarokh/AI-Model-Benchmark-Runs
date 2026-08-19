# bge-m3

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 1 of 10 topics.**

## Language understanding — German chat

Not measured. Interpreted in [language-understanding](../use-cases/language-understanding.md) where it is.

## Coding

Not measured. Interpreted in [coding](../use-cases/coding.md) where it is.

## Long context — cost against cache depth

Not measured. Interpreted in [context-depth](../findings/context-depth.md) where it is.

## Retrieval — embedding and reranking

Interpreted in [embedding](../use-cases/embedding.md).

**[`embedding_retrieval.tsv`](../data/embedding_retrieval.tsv)** — retrieval accuracy, cosine nearest neighbour

| model | correct | n | accuracy |
|---|---|---|---|
| bgem3_baseline | 77 | 80 | 0.9625 |

**[`embedding_chunk_position.tsv`](../data/embedding_chunk_position.tsv)** — retrieval against where the answer sits in the chunk

| model | pooling | variant | position | correct | n | accuracy | chunk_tokens_mean | truncated |
|---|---|---|---|---|---|---|---|---|
| bge-m3 | cls | short | - | 77 | 80 | 0.9625 | ~135 | 0 |
| bge-m3 | cls | long3000 | start | 48 | 80 | 0.6000 | ~760 | 0 |
| bge-m3 | cls | long3000 | middle | 5 | 80 | 0.0625 | ~760 | 0 |
| bge-m3 | cls | long3000 | end | 4 | 80 | 0.0500 | ~760 | 0 |
| bge-m3 | mean | long3000 | start | 24 | 80 | 0.3000 | ~760 | 0 |
| bge-m3 | mean | long3000 | middle | 10 | 80 | 0.1250 | ~760 | 0 |
| bge-m3 | mean | long3000 | end | 9 | 80 | 0.1125 | ~760 | 0 |

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

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

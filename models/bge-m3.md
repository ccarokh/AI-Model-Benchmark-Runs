# bge-m3

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## retrieval against answer position

Source: [`embedding_chunk_position.tsv`](../data/embedding_chunk_position.tsv) · interpreted in [chunk-position](../findings/chunk-position.md)

| model | pooling | variant | position | correct | n | accuracy | chunk_tokens_mean | truncated |
|---|---|---|---|---|---|---|---|---|
| bge-m3 | cls | short | - | 77 | 80 | 0.9625 | ~135 | 0 |
| bge-m3 | cls | long3000 | start | 48 | 80 | 0.6000 | ~760 | 0 |
| bge-m3 | cls | long3000 | middle | 5 | 80 | 0.0625 | ~760 | 0 |
| bge-m3 | cls | long3000 | end | 4 | 80 | 0.0500 | ~760 | 0 |
| bge-m3 | mean | long3000 | start | 24 | 80 | 0.3000 | ~760 | 0 |
| bge-m3 | mean | long3000 | middle | 10 | 80 | 0.1250 | ~760 | 0 |
| bge-m3 | mean | long3000 | end | 9 | 80 | 0.1125 | ~760 | 0 |

## retrieval accuracy

Source: [`embedding_retrieval.tsv`](../data/embedding_retrieval.tsv) · interpreted in [embedding](../use-cases/embedding.md)

| model | correct | n | accuracy |
|---|---|---|---|
| bgem3_baseline | 77 | 80 | 0.9625 |

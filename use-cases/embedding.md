# Embedding

> Measured on **[System B](../SYSTEMS.md#system-b) v1.0**. Both models ran **in the
> same session on the same harness**, including a fresh re-run of the incumbent
> rather than a quoted older figure — so the comparison holds regardless of what the
> surrounding stack was.

**A 9× larger model tied the incumbent exactly. It was not adopted.**

## Result

Retrieval over belebele_deu_Latn, n = 80, same harness that selected the incumbent
in the first place. The baseline was re-run fresh in the same session rather than
quoted from an older note.

| Model | Dimensions | Size | Retrieval accuracy |
|---|---:|---:|---:|
| **BGE-M3** *(incumbent)* | 1024 | 0.9 GB | **96.25 %** (77/80) |
| Qwen3-VL-Embedding-8B | 4096 | 8.05 GB | **96.25 %** (77/80) |

A dead tie — the same 77 of 80.

## Why the tie still loses

At equal accuracy every practical axis favours the smaller model:

- **4× the vector size** means 4× the Qdrant storage and bandwidth for zero gain.
- **9× the model size**: 0.9 GB fully on GPU against 8 GB needing CPU offload on a
  10 GB card — and the embedding slot is meant to run on a separate CPU server,
  where an 8B would be slower still.
- **A swap forces a full re-index** of the corpus at 4096 dimensions, for nothing.

## The one reason to revisit

The VL model's actual differentiator was never tested here: **embedding PDF page
images, diagrams and tables into the same space as text queries.** That is
potentially relevant for layout and tables that text extraction loses — but it is a
different architecture step, not an embedding-slot swap, and evaluating it needs a
real multimodal retrieval metric rather than this text-only test.

## Practical note

A Q8_0 8B model does not fit in ~7 GB of free VRAM with an explicit `-ngl 99` —
`-ngl` disables `--fit` and the load OOMs. Launch embedding servers with
`--embedding --pooling last` and **no** explicit `-ngl`, letting `--fit` offload a
few layers; it loaded at 8.67 GB that way.

The evaluation harness was reused unchanged between the two models — it POSTs to
`/v1/embeddings` and does cosine nearest-neighbour retrieval, so it is
model-agnostic. That is worth designing for: it made the comparison a one-line
change instead of a porting exercise.

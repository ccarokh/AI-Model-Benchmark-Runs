# qwen-image-2.1

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

Not measured. Interpreted in [embedding](../use-cases/embedding.md) where it is.

## Vision — image input

Not measured. Interpreted in [vision](../use-cases/vision.md) where it is.

## Speech to text

Not measured. Interpreted in [transcription](../use-cases/transcription.md) where it is.

## Image generation

Interpreted in [image-generation](../use-cases/image-generation.md).

**[`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv)** — the OCR measures across five seeds

| model | task | seed | metric | value | denominator |
|---|---|---|---|---|---|
| qwen-image-2.1 | 02_sign_text | 7 | edit_distance | 1 | — |
| qwen-image-2.1 | 02_sign_text | 13 | edit_distance | 9 | — |
| qwen-image-2.1 | 02_sign_text | 42 | edit_distance | 11 | — |
| qwen-image-2.1 | 02_sign_text | 55 | edit_distance | 2 | — |
| qwen-image-2.1 | 02_sign_text | 99 | edit_distance | 2 | — |
| qwen-image-2.1 | 02_sign_text | 101 | edit_distance | 2 | — |
| qwen-image-2.1 | 02_sign_text | 314 | edit_distance | 0 | — |
| qwen-image-2.1 | 02_sign_text | 512 | edit_distance | 2 | — |
| qwen-image-2.1 | 02_sign_text | 777 | edit_distance | 1 | — |
| qwen-image-2.1 | 02_sign_text | 1001 | edit_distance | 0 | — |
| qwen-image-2.1 | 02_sign_text | 1234 | edit_distance | 0 | — |
| qwen-image-2.1 | 02_sign_text | 1618 | edit_distance | 5 | — |
| qwen-image-2.1 | 02_sign_text | 2026 | edit_distance | 6 | — |
| qwen-image-2.1 | 02_sign_text | 3141 | edit_distance | 2 | — |
| qwen-image-2.1 | 02_sign_text | 8888 | edit_distance | 1 | — |

## Power and energy

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

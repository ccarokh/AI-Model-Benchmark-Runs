# sd3.5-medium

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

**[`image_generation.tsv`](../data/image_generation.tsv)** — time, VRAM and licence

| model | quant | licence | commercial | steps | cfg | seconds_per_image | n_runs | params_mb | peak_vram_mib | card_share_pct |
|---|---|---|---|---|---|---|---|---|---|---|
| sd3.5-medium | Q4_K_M-allinone | Stability Community | under 1M revenue | 28 | 4.5 | 69.5 | 8 | 15980.96 | 18878 | 77 |

**[`image_generation_ocr.tsv`](../data/image_generation_ocr.tsv)** — text rendered into the image

| model | task | metric | value | detail |
|---|---|---|---|---|
| sd3.5-medium | 02_sign_text | edit_distance_to_target | 10 | AG EN E TZER |
| sd3.5-medium | 05_schematic | real_word_share | 0.39 | 28 of 72 tokens |

**[`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv)** — the OCR measures across five seeds

| model | task | seed | metric | value | denominator |
|---|---|---|---|---|---|
| sd3.5-medium | 02_sign_text | 1001 | edit_distance | 7 | — |
| sd3.5-medium | 02_sign_text | 101 | edit_distance | 4 | — |
| sd3.5-medium | 02_sign_text | 1234 | edit_distance | 4 | — |
| sd3.5-medium | 02_sign_text | 13 | edit_distance | 13 | — |
| sd3.5-medium | 02_sign_text | 1618 | edit_distance | 9 | — |
| sd3.5-medium | 02_sign_text | 2026 | edit_distance | 3 | — |
| sd3.5-medium | 02_sign_text | 314 | edit_distance | 7 | — |
| sd3.5-medium | 02_sign_text | 3141 | edit_distance | 11 | — |
| sd3.5-medium | 02_sign_text | 42 | edit_distance | 4 | — |
| sd3.5-medium | 02_sign_text | 512 | edit_distance | 3 | — |
| sd3.5-medium | 02_sign_text | 55 | edit_distance | 3 | — |
| sd3.5-medium | 02_sign_text | 7 | edit_distance | 6 | — |
| sd3.5-medium | 02_sign_text | 777 | edit_distance | 8 | — |
| sd3.5-medium | 02_sign_text | 8888 | edit_distance | 7 | — |
| sd3.5-medium | 02_sign_text | 99 | edit_distance | 3 | — |
| sd3.5-medium | 05_schematic | 42 | real_words | 9 | 37 |
| sd3.5-medium | 05_schematic | 101 | real_words | 2 | 7 |
| sd3.5-medium | 05_schematic | 777 | real_words | 6 | 49 |
| sd3.5-medium | 05_schematic | 1234 | real_words | 8 | 53 |
| sd3.5-medium | 05_schematic | 2026 | real_words | 3 | 34 |

**[`image_generation_energy.tsv`](../data/image_generation_energy.tsv)** — energy per image

| model | seconds | mean_watt_chip | peak_watt_chip | wh_per_image | samples |
|---|---|---|---|---|---|
| sd3.5-medium | 74.3 | 188.6 | 294.0 | 3.896 | 74 |

**[`image_generation_verdicts.tsv`](../data/image_generation_verdicts.tsv)** — ⚠️ operator judgements, not measurements

| model | task | verdict | operator_note |
|---|---|---|---|
| sd3.5-medium | 01_work_scene | pass | — |
| sd3.5-medium | 02_sign_text | fail | — |
| sd3.5-medium | 03_flat_icon | pass | — |
| sd3.5-medium | 04_hands_tool | fail | da sind 2 Hände ineinander verschmolzen |
| sd3.5-medium | 05_schematic | fail | Text ist teilweise nonsense, Diagram beschreibt nicht das was gefordert wurde |
| sd3.5-medium | 06_dog | fail | all four legs visible, <-- wurde nicht eingehalten |

## Power and energy

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

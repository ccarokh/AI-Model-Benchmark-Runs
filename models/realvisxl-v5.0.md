# realvisxl-v5.0

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
| realvisxl-v5.0 | fp16 | OpenRAIL++ | with conditions | 25 | 7.0 | 37.4 | 8 | 6624.11 | 12503 | 51 |

**[`image_generation_ocr.tsv`](../data/image_generation_ocr.tsv)** — text rendered into the image

| model | task | metric | value | detail |
|---|---|---|---|---|
| realvisxl-v5.0 | 02_sign_text | edit_distance_to_target | 12 | E B N E A E |
| realvisxl-v5.0 | 05_schematic | real_word_share | 0.09 | 1 of 11 tokens |

**[`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv)** — the OCR measures across five seeds

| model | task | seed | metric | value | denominator |
|---|---|---|---|---|---|
| realvisxl-v5.0 | 02_sign_text | 1001 | edit_distance | 6 | — |
| realvisxl-v5.0 | 02_sign_text | 101 | edit_distance | 12 | — |
| realvisxl-v5.0 | 02_sign_text | 1234 | edit_distance | 12 | — |
| realvisxl-v5.0 | 02_sign_text | 13 | edit_distance | 15 | — |
| realvisxl-v5.0 | 02_sign_text | 1618 | edit_distance | 12 | — |
| realvisxl-v5.0 | 02_sign_text | 2026 | edit_distance | 8 | — |
| realvisxl-v5.0 | 02_sign_text | 314 | edit_distance | 5 | — |
| realvisxl-v5.0 | 02_sign_text | 3141 | edit_distance | 5 | — |
| realvisxl-v5.0 | 02_sign_text | 42 | edit_distance | 12 | — |
| realvisxl-v5.0 | 02_sign_text | 512 | edit_distance | 5 | — |
| realvisxl-v5.0 | 02_sign_text | 55 | edit_distance | 12 | — |
| realvisxl-v5.0 | 02_sign_text | 7 | edit_distance | 12 | — |
| realvisxl-v5.0 | 02_sign_text | 777 | edit_distance | 7 | — |
| realvisxl-v5.0 | 02_sign_text | 8888 | edit_distance | 7 | — |
| realvisxl-v5.0 | 02_sign_text | 99 | edit_distance | 6 | — |
| realvisxl-v5.0 | 05_schematic | 42 | real_words | 1 | 11 |
| realvisxl-v5.0 | 05_schematic | 101 | real_words | 1 | 12 |
| realvisxl-v5.0 | 05_schematic | 777 | real_words | 1 | 3 |
| realvisxl-v5.0 | 05_schematic | 1234 | real_words | 2 | 11 |
| realvisxl-v5.0 | 05_schematic | 2026 | real_words | 2 | 7 |

**[`image_generation_energy.tsv`](../data/image_generation_energy.tsv)** — energy per image

| model | seconds | mean_watt_chip | peak_watt_chip | wh_per_image | samples |
|---|---|---|---|---|---|
| realvisxl-v5.0 | 38.4 | 139.0 | 285.0 | 1.501 | 39 |

**[`image_generation_verdicts.tsv`](../data/image_generation_verdicts.tsv)** — ⚠️ operator judgements, not measurements

| model | task | verdict | operator_note |
|---|---|---|---|
| realvisxl-v5.0 | 01_work_scene | pass | sieht am besten aus, aber inhaltlich vieles ohne Sinn: Seil haengt an nichts, Schacht ohne Boden, Scheibe mit Lochbild einer Malerpalette |
| realvisxl-v5.0 | 02_sign_text | fail | — |
| realvisxl-v5.0 | 03_flat_icon | pass | — |
| realvisxl-v5.0 | 04_hands_tool | fail | merkwuerdige Haende, sehen aus als sollte ein Handschuh drueber, ist aber keiner |
| realvisxl-v5.0 | 05_schematic | fail | kein Fluss von Filter A nach Filter B -- die Aussage des Schemas fehlt bei allen; Beschriftung nicht lesbar, Wortanteil 9 % |
| realvisxl-v5.0 | 06_dog | pass | — |
| realvisxl-v5.0 | 07_cat | pass | — |
| realvisxl-v5.0 | 08_horse | pass | — |

## Power and energy

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

# flux.1-schnell

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
| flux.1-schnell | Q4_K | Apache-2.0 | yes | 4 | 1.0 | 33.5 | 8 | 15948.45 | 21894 | 89 |

**[`image_generation_ocr.tsv`](../data/image_generation_ocr.tsv)** — text rendered into the image

| model | task | metric | value | detail |
|---|---|---|---|---|
| flux.1-schnell | 02_sign_text | edit_distance_to_target | 1 | ACHITUNG BEHAELTER |
| flux.1-schnell | 05_schematic | real_word_share | 0.50 | 3 of 6 tokens |

**[`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv)** — the OCR measures across five seeds

| model | task | seed | metric | value | denominator |
|---|---|---|---|---|---|
| flux.1-schnell | 02_sign_text | 1001 | edit_distance | 5 | — |
| flux.1-schnell | 02_sign_text | 101 | edit_distance | 1 | — |
| flux.1-schnell | 02_sign_text | 1234 | edit_distance | 6 | — |
| flux.1-schnell | 02_sign_text | 13 | edit_distance | 4 | — |
| flux.1-schnell | 02_sign_text | 1618 | edit_distance | 12 | — |
| flux.1-schnell | 02_sign_text | 2026 | edit_distance | 2 | — |
| flux.1-schnell | 02_sign_text | 314 | edit_distance | 0 | — |
| flux.1-schnell | 02_sign_text | 3141 | edit_distance | 15 | — |
| flux.1-schnell | 02_sign_text | 42 | edit_distance | 1 | — |
| flux.1-schnell | 02_sign_text | 512 | edit_distance | 3 | — |
| flux.1-schnell | 02_sign_text | 55 | edit_distance | 2 | — |
| flux.1-schnell | 02_sign_text | 7 | edit_distance | 2 | — |
| flux.1-schnell | 02_sign_text | 777 | edit_distance | 0 | — |
| flux.1-schnell | 02_sign_text | 8888 | edit_distance | 12 | — |
| flux.1-schnell | 02_sign_text | 99 | edit_distance | 6 | — |
| flux.1-schnell | 05_schematic | 42 | real_words | 3 | 6 |
| flux.1-schnell | 05_schematic | 101 | real_words | 2 | 5 |
| flux.1-schnell | 05_schematic | 777 | real_words | 2 | 3 |
| flux.1-schnell | 05_schematic | 1234 | real_words | 0 | 0 |
| flux.1-schnell | 05_schematic | 2026 | real_words | 0 | 0 |

**[`image_generation_energy.tsv`](../data/image_generation_energy.tsv)** — energy per image

| model | seconds | mean_watt_chip | peak_watt_chip | wh_per_image | samples |
|---|---|---|---|---|---|
| flux.1-schnell | 36.8 | 88.1 | 290.0 | 0.905 | 37 |

**[`image_generation_verdicts.tsv`](../data/image_generation_verdicts.tsv)** — ⚠️ operator judgements, not measurements

| model | task | verdict | operator_note |
|---|---|---|---|
| flux.1-schnell | 01_work_scene | pass | — |
| flux.1-schnell | 02_sign_text | fail | ACHITUNG statt ACHTUNG |
| flux.1-schnell | 03_flat_icon | pass | — |
| flux.1-schnell | 04_hands_tool | fail | Werkzeug gibt es nicht: Drehmomentschluessel-Griff mit flacher Klinge vorn |
| flux.1-schnell | 05_schematic | fail | kein Fluss von Filter A nach Filter B -- die Aussage des Schemas fehlt bei allen |
| flux.1-schnell | 06_dog | pass | — |
| flux.1-schnell | 07_cat | fail | haelt das Prompt nicht ein: Katze schaut nicht aus dem Fenster |
| flux.1-schnell | 08_horse | pass | — |

## Power and energy

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

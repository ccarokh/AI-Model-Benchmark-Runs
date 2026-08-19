# chroma1-hd

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
| chroma1-hd | Q4_0 | Apache-2.0 | yes | 20 | 4.0 | 147.7 | 8 | 14424.14 | 20389 | 83 |

**[`image_generation_ocr.tsv`](../data/image_generation_ocr.tsv)** — text rendered into the image

| model | task | metric | value | detail |
|---|---|---|---|---|
| chroma1-hd | 02_sign_text | edit_distance_to_target | 0 | ACHTUNG BEHAELTER |
| chroma1-hd | 05_schematic | real_word_share | 0.00 | 0 of 1 tokens |

**[`image_generation_ab.tsv`](../data/image_generation_ab.tsv)** — one variable at a time

| model | variable | value | seconds_per_image | grid_texture_present |
|---|---|---|---|---|
| chroma1-hd | quantisation | Q4_0 | 147.7 | yes |
| chroma1-hd | quantisation | Q8_0 | 154.8 | yes |
| chroma1-hd | steps | 8 | 75.0 | yes |
| chroma1-hd | steps | 14 | 112.2 | yes |
| chroma1-hd | steps | 20 | 147.7 | yes |
| chroma1-hd | steps | 28 | 199.6 | yes |
| chroma1-hd | cfg | 2.5 | 149.4 | yes |
| chroma1-hd | cfg | 4.0 | 147.7 | yes |
| chroma1-hd | cfg | 5.5 | 149.2 | yes |
| chroma1-hd | vae | flux-ae | 147.7 | yes |
| chroma1-hd | vae | chroma-own | 147.9 | yes |

**[`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv)** — the OCR measures across five seeds

| model | task | seed | metric | value | denominator |
|---|---|---|---|---|---|
| chroma1-hd | 02_sign_text | 1001 | edit_distance | 0 | — |
| chroma1-hd | 02_sign_text | 101 | edit_distance | 8 | — |
| chroma1-hd | 02_sign_text | 1234 | edit_distance | 2 | — |
| chroma1-hd | 02_sign_text | 13 | edit_distance | 1 | — |
| chroma1-hd | 02_sign_text | 1618 | edit_distance | 0 | — |
| chroma1-hd | 02_sign_text | 2026 | edit_distance | 8 | — |
| chroma1-hd | 02_sign_text | 314 | edit_distance | 0 | — |
| chroma1-hd | 02_sign_text | 3141 | edit_distance | 1 | — |
| chroma1-hd | 02_sign_text | 42 | edit_distance | 0 | — |
| chroma1-hd | 02_sign_text | 512 | edit_distance | 8 | — |
| chroma1-hd | 02_sign_text | 55 | edit_distance | 1 | — |
| chroma1-hd | 02_sign_text | 7 | edit_distance | 8 | — |
| chroma1-hd | 02_sign_text | 777 | edit_distance | 0 | — |
| chroma1-hd | 02_sign_text | 8888 | edit_distance | 0 | — |
| chroma1-hd | 02_sign_text | 99 | edit_distance | 1 | — |
| chroma1-hd | 05_schematic | 42 | real_words | 0 | 0 |
| chroma1-hd | 05_schematic | 101 | real_words | 1 | 1 |
| chroma1-hd | 05_schematic | 777 | real_words | 0 | 0 |
| chroma1-hd | 05_schematic | 1234 | real_words | 0 | 0 |
| chroma1-hd | 05_schematic | 2026 | real_words | 0 | 0 |

**[`image_generation_energy.tsv`](../data/image_generation_energy.tsv)** — energy per image

| model | seconds | mean_watt_chip | peak_watt_chip | wh_per_image | samples |
|---|---|---|---|---|---|
| chroma1-hd | 149.9 | 243.2 | 295.0 | 10.133 | 149 |

**[`image_generation_verdicts.tsv`](../data/image_generation_verdicts.tsv)** — ⚠️ operator judgements, not measurements

| model | task | verdict | operator_note |
|---|---|---|---|
| chroma1-hd | 01_work_scene | pass | — |
| chroma1-hd | 02_sign_text | pass | einziges Modell, das ACHTUNG BEHAELTER exakt trifft (OCR-Editabstand 0) |
| chroma1-hd | 03_flat_icon | pass | — |
| chroma1-hd | 04_hands_tool | fail | sieht sehr plastikhaft aus |
| chroma1-hd | 05_schematic | fail | kein Fluss von Filter A nach Filter B -- die Aussage des Schemas fehlt bei allen; zusaetzlich ausradierte Objekte, Rohre enden im Nichts |
| chroma1-hd | 06_dog | fail | der Hund wird ueber seine eigenen Beine stolpern, Laeufe gekreuzt |
| chroma1-hd | 07_cat | fail | Punkte-Fell statt Linien; in Q8_0 identisch, also nicht die Quantisierung |
| chroma1-hd | 08_horse | fail | zu shiny / plastikhaft |

## Power and energy

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Not measured. Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored) where it is.

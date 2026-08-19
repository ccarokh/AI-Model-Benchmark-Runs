# chroma1-hd

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## time, VRAM and licence

Source: [`image_generation.tsv`](../data/image_generation.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | quant | licence | commercial | steps | cfg | seconds_per_image | n_runs | params_mb | peak_vram_mib | card_share_pct |
|---|---|---|---|---|---|---|---|---|---|---|
| chroma1-hd | Q4_0 | Apache-2.0 | yes | 20 | 4.0 | 147.7 | 8 | 14424.14 | 20389 | 83 |

## one variable at a time

Source: [`image_generation_ab.tsv`](../data/image_generation_ab.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

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

## energy per image

Source: [`image_generation_energy.tsv`](../data/image_generation_energy.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | seconds | mean_watt_chip | peak_watt_chip | wh_per_image | samples |
|---|---|---|---|---|---|
| chroma1-hd | 149.9 | 243.2 | 295.0 | 10.133 | 149 |

## text rendered into the image

Source: [`image_generation_ocr.tsv`](../data/image_generation_ocr.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | task | metric | value | detail |
|---|---|---|---|---|
| chroma1-hd | 02_sign_text | edit_distance_to_target | 0 | ACHTUNG BEHAELTER |
| chroma1-hd | 05_schematic | real_word_share | 0.00 | 0 of 1 tokens |

## the OCR measures across five seeds

Source: [`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

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

## operator judgements, not measurements

Source: [`image_generation_verdicts.tsv`](../data/image_generation_verdicts.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

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

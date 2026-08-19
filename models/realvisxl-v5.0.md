# realvisxl-v5.0

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## time, VRAM and licence

Source: [`image_generation.tsv`](../data/image_generation.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | quant | licence | commercial | steps | cfg | seconds_per_image | n_runs | params_mb | peak_vram_mib | card_share_pct |
|---|---|---|---|---|---|---|---|---|---|---|
| realvisxl-v5.0 | fp16 | OpenRAIL++ | with conditions | 25 | 7.0 | 37.4 | 8 | 6624.11 | 12503 | 51 |

## energy per image

Source: [`image_generation_energy.tsv`](../data/image_generation_energy.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | seconds | mean_watt_chip | peak_watt_chip | wh_per_image | samples |
|---|---|---|---|---|---|
| realvisxl-v5.0 | 38.4 | 139.0 | 285.0 | 1.501 | 39 |

## text rendered into the image

Source: [`image_generation_ocr.tsv`](../data/image_generation_ocr.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | task | metric | value | detail |
|---|---|---|---|---|
| realvisxl-v5.0 | 02_sign_text | edit_distance_to_target | 12 | E B N E A E |
| realvisxl-v5.0 | 05_schematic | real_word_share | 0.09 | 1 of 11 tokens |

## the OCR measures across five seeds

Source: [`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

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

## operator judgements, not measurements

Source: [`image_generation_verdicts.tsv`](../data/image_generation_verdicts.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

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

# sdxl-1.0-base

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## time, VRAM and licence

Source: [`image_generation.tsv`](../data/image_generation.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | quant | licence | commercial | steps | cfg | seconds_per_image | n_runs | params_mb | peak_vram_mib | card_share_pct |
|---|---|---|---|---|---|---|---|---|---|---|
| sdxl-1.0-base | fp16 | CreativeML OpenRAIL++-M | with conditions | 25 | 7.0 | 37.0 | 8 | 6624.11 | 12503 | 51 |

## energy per image

Source: [`image_generation_energy.tsv`](../data/image_generation_energy.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | seconds | mean_watt_chip | peak_watt_chip | wh_per_image | samples |
|---|---|---|---|---|---|
| sdxl-1.0-base | 39.4 | 137.2 | 285.0 | 1.515 | 40 |

## text rendered into the image

Source: [`image_generation_ocr.tsv`](../data/image_generation_ocr.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | task | metric | value | detail |
|---|---|---|---|---|
| sdxl-1.0-base | 02_sign_text | edit_distance_to_target | 6 | ACHUTING BELLER |
| sdxl-1.0-base | 05_schematic | real_word_share | 0.25 | 3 of 12 tokens |

## the OCR measures across five seeds

Source: [`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | task | seed | metric | value | denominator |
|---|---|---|---|---|---|
| sdxl-1.0-base | 02_sign_text | 1001 | edit_distance | 14 | — |
| sdxl-1.0-base | 02_sign_text | 101 | edit_distance | 7 | — |
| sdxl-1.0-base | 02_sign_text | 1234 | edit_distance | 17 | — |
| sdxl-1.0-base | 02_sign_text | 13 | edit_distance | 8 | — |
| sdxl-1.0-base | 02_sign_text | 1618 | edit_distance | 6 | — |
| sdxl-1.0-base | 02_sign_text | 2026 | edit_distance | 6 | — |
| sdxl-1.0-base | 02_sign_text | 314 | edit_distance | 17 | — |
| sdxl-1.0-base | 02_sign_text | 3141 | edit_distance | 13 | — |
| sdxl-1.0-base | 02_sign_text | 42 | edit_distance | 6 | — |
| sdxl-1.0-base | 02_sign_text | 512 | edit_distance | 5 | — |
| sdxl-1.0-base | 02_sign_text | 55 | edit_distance | 6 | — |
| sdxl-1.0-base | 02_sign_text | 7 | edit_distance | 6 | — |
| sdxl-1.0-base | 02_sign_text | 777 | edit_distance | 7 | — |
| sdxl-1.0-base | 02_sign_text | 8888 | edit_distance | 13 | — |
| sdxl-1.0-base | 02_sign_text | 99 | edit_distance | 16 | — |
| sdxl-1.0-base | 05_schematic | 42 | real_words | 3 | 12 |
| sdxl-1.0-base | 05_schematic | 101 | real_words | 2 | 2 |
| sdxl-1.0-base | 05_schematic | 777 | real_words | 0 | 0 |
| sdxl-1.0-base | 05_schematic | 1234 | real_words | 0 | 0 |
| sdxl-1.0-base | 05_schematic | 2026 | real_words | 1 | 3 |

## operator judgements, not measurements

Source: [`image_generation_verdicts.tsv`](../data/image_generation_verdicts.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | task | verdict | operator_note |
|---|---|---|---|
| sdxl-1.0-base | 01_work_scene | fail | — |
| sdxl-1.0-base | 02_sign_text | fail | Buchstabenfolgen ohne Wortcharakter |
| sdxl-1.0-base | 03_flat_icon | fail | Hintergrund nicht einheitlich weiss, war ausdrueckliche Vorgabe |
| sdxl-1.0-base | 04_hands_tool | fail | Hand ohne aufloesbare Finger, Welle statt Schluessel |
| sdxl-1.0-base | 05_schematic | fail | kein Fluss von Filter A nach Filter B -- die Aussage des Schemas fehlt bei allen; Rohre enden im Nichts |
| sdxl-1.0-base | 06_dog | fail | vierte Pfote ohne Verbindung zum Koerper, dazu fellfreie Schaedeldecke |
| sdxl-1.0-base | 07_cat | pass | — |
| sdxl-1.0-base | 08_horse | fail | fuenf Beine |

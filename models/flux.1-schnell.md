# flux.1-schnell

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

## time, VRAM and licence

Source: [`image_generation.tsv`](../data/image_generation.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | quant | licence | commercial | steps | cfg | seconds_per_image | n_runs | params_mb | peak_vram_mib | card_share_pct |
|---|---|---|---|---|---|---|---|---|---|---|
| flux.1-schnell | Q4_K | Apache-2.0 | yes | 4 | 1.0 | 33.5 | 8 | 15948.45 | 21894 | 89 |

## energy per image

Source: [`image_generation_energy.tsv`](../data/image_generation_energy.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | seconds | mean_watt_chip | peak_watt_chip | wh_per_image | samples |
|---|---|---|---|---|---|
| flux.1-schnell | 36.8 | 88.1 | 290.0 | 0.905 | 37 |

## text rendered into the image

Source: [`image_generation_ocr.tsv`](../data/image_generation_ocr.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

| model | task | metric | value | detail |
|---|---|---|---|---|
| flux.1-schnell | 02_sign_text | edit_distance_to_target | 1 | ACHITUNG BEHAELTER |
| flux.1-schnell | 05_schematic | real_word_share | 0.50 | 3 of 6 tokens |

## the OCR measures across five seeds

Source: [`image_generation_seeds.tsv`](../data/image_generation_seeds.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

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

## operator judgements, not measurements

Source: [`image_generation_verdicts.tsv`](../data/image_generation_verdicts.tsv) · interpreted in [image-generation](../use-cases/image-generation.md)

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

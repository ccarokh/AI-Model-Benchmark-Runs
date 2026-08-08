# Image generation

> Measured on **[System A](../SYSTEMS.md#system-a) v1.5**,
> stable-diffusion.cpp `master-813-bfbef5b`, Vulkan, single card, fresh process per
> image, card verified empty before **each** image. Raw data:
> [`image_generation.tsv`](../data/image_generation.tsv),
> [`_ocr.tsv`](../data/image_generation_ocr.tsv),
> [`_ab.tsv`](../data/image_generation_ab.tsv),
> [`_verdicts.tsv`](../data/image_generation_verdicts.tsv).

**Five models, eight tasks. The three tasks that carry a statement rather than a
motif fail on every model.**

This is the first use case here where the deciding metric could not be automated.
What follows separates the two kinds of result strictly: what a machine measured, and
what the operator judged by looking.

## What a machine measured

| Model | Licence | Commercial | Steps | Time / image | Peak VRAM | of 24560 MiB |
|---|---|---|---:|---:|---:|---:|
| **FLUX.1-schnell** Q4_K | Apache-2.0 | **yes** | 4 | **33.5 s** | 21894 | **89 %** |
| **Chroma1-HD** Q4_0 | Apache-2.0 | **yes** | 20 | 147.7 s | 20389 | 83 % |
| SD 3.5 Medium | Stability Community | under $1M revenue | 28 | 69.5 s | 18878 | 77 % |
| SDXL 1.0 base | CreativeML OpenRAIL++-M | with conditions | 25 | 37.0 s | 12503 | 51 % |
| RealVisXL V5.0 | OpenRAIL++ | with conditions | 25 | 37.4 s | 12503 | 51 % |

Times are the mean over the eight tasks; they vary by under a second.

**None of the five fits alongside the four resident production models.** That budget
is 9409 MiB free; the smallest model here needs 12503. Every one requires a swap-in.

**Each model runs on its own usual settings**, 4 to 28 steps. That is defensible per
model and makes the *time* column a comparison of configurations as much as of
models — see [the A/B section](#the-parameter-ab-and-what-it-settled).

## Text in the image, measured two ways

Two tasks demand text, and both can be checked instead of judged. **The metric has to
follow the prompt:** a required string is an edit-distance question, a free label is a
vocabulary question.

| Model | 02 · distance to `ACHTUNG BEHAELTER` | what OCR read | 05 · real words |
|---|---:|---|---:|
| **Chroma1-HD** | **0** | `ACHTUNG BEHAELTER` | 0 % (0 of 1) |
| FLUX.1-schnell | 1 | `ACHITUNG BEHAELTER` | **50 %** (3 of 6) |
| SDXL 1.0 base | 6 | `ACHUTING BELLER` | 25 % (3 of 12) |
| SD 3.5 Medium | 10 | `AG EN E TZER` | 39 % (28 of 72) |
| RealVisXL V5.0 | 12 | `E B N E A E` | 9 % (1 of 11) |

**Exactly one model renders a required German string correctly**, and it is one of the
two under Apache-2.0. Verified by OCR and then by eye — clean typography on a bolted
warning sign.

**Labelled diagrams fail on all five.** The best label vocabulary is half real words.

⚠️ **The word-share metric is wrong for task 02** — `BEHAELTER` is the requested
string but not a dictionary entry, so it scores as a non-word. Each task needs the
measure its own prompt implies.

⚠️ **One OCR setting decided a result.** With `--psm 11` fixed, Tesseract found *zero*
tokens in FLUX's schematic; `--psm 6` reads six from the same file. The tool now tries
five segmentation modes and keeps the best — otherwise the table would have reported
"no text present" for an image that has text.

## What the operator judged

The rest cannot be automated. Each image was rated pass/fail by the operator, with a
note. Full list in [`_verdicts.tsv`](../data/image_generation_verdicts.tsv).

| Model | Passed |
|---|---:|
| RealVisXL V5.0 | **5 / 8** |
| FLUX.1-schnell | 4 / 8 |
| Chroma1-HD | 3 / 8 |
| SD 3.5 Medium | 2 / 6 |
| SDXL 1.0 base | 1 / 8 |

### Three tasks nobody passed

| Task | Why it failed, on every model |
|---|---|
| **02 · sign with German text** | four of five produce non-words; the fifth is the exception above |
| **04 · hands on a torque wrench** | no model produced a tool that exists — invented hybrids, or a shaft where a wrench belongs |
| **05 · two-stage filter schematic** | **no image shows water flowing from A to B** |

**Task 05 is the sharpest result in the series.** A two-stage filter is a statement
about order. Every model drew vessels, pipes and labels — the *components* of a
diagram — and none drew the relationship the diagram exists to express. Labels can be
fixed with a better model; this cannot, because it is not a rendering problem.

**For explanatory diagrams, image generation is the wrong tool** — independently of
the model.

### Half the verdicts turned on a checkable condition, not on taste

| Task | Explicit instruction in the prompt | Missed by |
|---|---|---|
| 03 | `plain white background` | SDXL |
| 04 | `torque wrench` | all |
| 06 | `all four legs visible` | SDXL, SD 3.5 |
| 07 | `looking outside` | FLUX |
| 08 | `all four legs visible` | SDXL (five legs) |

None of these is a matter of preference — legs can be counted, a background checked,
a gaze direction read. **On task 07 the better-looking image lost:** FLUX rendered
higher quality past the instruction. Fidelity to the brief beats image quality, the
same way a correct fix in the wrong edit format scores zero in
[the coding series](coding.md#a-4b-model-that-fails-on-format-not-on-diagnosis).

### The most convincing image in the series is the one to distrust

RealVisXL's work-scene is photographically the strongest thing here and physically
impossible: **the safety harness is anchored to nothing**, the shaft has no floor, a
hose ends in mid-air, and the disc in the worker's hand carries the hole pattern of a
painter's palette.

For safety-training material that is the dangerous failure class — not the visibly
broken image, but the convincing one showing wrong technique. Five legs on a horse
catch every reader; a harness attached to nothing catches only someone who knows the
work. It is the visual counterpart to the **fluent-nonsense transcriptions** in
[the ASR series](transcription.md#part-1--the-configuration-was-the-problem-not-the-model).

## The parameter A/B, and what it settled

One model's texture defect was chased through four variables, one at a time, same seed
and prompt throughout. Chroma renders fur as a **regular orthogonal grid** independent
of fur direction.

| Variable | Compared | Grid still there |
|---|---|---|
| Quantisation | Q4_0 ↔ Q8_0 | yes |
| Steps | 8 ↔ 14 ↔ 20 ↔ 28 | yes |
| cfg | 2.5 ↔ 4.0 ↔ 5.5 | yes |
| VAE | FLUX's ↔ Chroma's own | yes |

**Four suspects, four acquittals — so the defect belongs to the model.** That is worth
as much as the opposite result would have been: on this same host, three other
"model failures" turned out to be configuration, and only an A/B could tell them
apart. See [METHODOLOGY](../METHODOLOGY.md#vary-one-thing-or-you-are-comparing-setups-not-models).

**The step sweep also corrected a headline number.** Chroma's "4.4× slower than FLUX"
was the choice of 20 steps, not a property of the model:

| Steps | Time | vs FLUX |
|---:|---:|---:|
| 8 | 75.0 s | 2.2 × |
| 14 | 112.2 s | 3.3 × |
| 20 | 147.7 s | 4.4 × |
| 28 | 199.6 s | 5.9 × |

Strictly linear; cfg costs nothing. Whether 8 steps still produce usable images was
rated separately — they carry the same grid.

## Not measured

- **One seed per task.** Diffusion models scatter across seeds; a single sample is not
  a property. This is the largest open gap in the series, and it applies to every
  number above, including the one exact text hit.
- **Steps and cfg are not equalised across models**, so the time column compares
  operating points, not architectures.
- **English prompts only.** All five expect English; whether German prompts carry was
  not tested.
- **1536 × 1536 is not usable on this card.** One FLUX image took **2090 s** against
  33.5 s at 1024 — factor 62 for 2.25× the area, with no error message. Same silent
  host-memory fallback documented for
  [the KV cache](../METHODOLOGY.md#a-context-size-without-a-cache-type-is-not-a-specification).
  The run was stopped; the finding stands.
- **FLUX.1-dev** — explicitly non-commercial, measurable as a reference, not run.
- **Swap-in time** between models, at 6.9 to 12 GB of weights.

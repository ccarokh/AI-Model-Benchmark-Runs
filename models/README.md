# One file per model

Each file collects **everything measured about that model**, on two levels at once:

- **by topic** — the heading, linking to the use-case or findings document that
  interprets it
- **by data file** — inside each topic, every source table named and linked
  separately, with a line saying what it measures

Several data files can belong to one topic. `chat_belebele.tsv`,
`chat_belebele_harness.tsv` and `chat_belebele_chattemplate.tsv` all sit under
*Language understanding*, because they answer the same question through different
harnesses — and [that difference is worth up to 70
points](../findings/harness-effect.md), so they stay visible as separate tables rather
than being averaged into one.

## Every topic appears in every file

Including the ones with nothing in them, marked *Not measured*, and a count at the top:
**Measured in 5 of 10 topics.**

**A gap you cannot see looks like an answer.** The whole point of the per-model view is
noticing what has *not* been measured — a model with an excellent chat score and no
coding row should say so on its face.

## These files are generated

By [`scripts/genmodels.py`](../scripts/genmodels.py) from [`data/`](../data/). Every
number traces to a row there. **Only the opening paragraph is written by hand**, and only
for models that have a finding worth stating — currently 18 of 50. It lives in
[`scripts/model_notes.json`](../scripts/model_notes.json), not in the generated file, so
regenerating never loses it.

Models that ran and failed are in the [Failed table](../README.md#failed).

## Where the other documents live

| | |
|---|---|
| [`use-cases/`](../use-cases/) | one document per slot — chat, coding, vision, ASR, image generation, embedding, fine-tuning |
| [`findings/`](../findings/) | results belonging to no single model: the harness, context depth, chunk position, abliteration |
| [`hardware/`](../hardware/) | power, multi-GPU, backends |

A model file links out to all three and does not repeat their reasoning.

## A caution about the names

The same model appears under different spellings across data files — `gemma-4-12b` and
`gemma4-12b`, `qwen3.5-2b` and `qwen35-2b`, `qwen3.8-27b-abliterated` and
`qwen3.8-27b-abl`. The generator merges them through an alias table, and `-slot32k`,
`-nothink` and `-x8` fold into the base model because they are run configurations rather
than different models.

**That merging is a judgement, and it sits in one place** — the `ALIAS` map at the top of
the generator — instead of scattered through prose.

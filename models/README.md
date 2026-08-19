# One file per model

Each file collects **everything measured about that model** across every topic, with
each table naming the data file it came from and the document that interprets it.

**These files are generated** by [`scripts/genmodels.py`](../scripts/genmodels.py) from
[`data/`](../data/). A number here always traces to a row there; nothing is typed in by
hand except the opening paragraph on models that have a finding worth stating.

**Blank means never measured, not "failed".** Models that ran and failed are in the
[Failed table](../README.md#failed).

## Where the other documents went

| | |
|---|---|
| [`use-cases/`](../use-cases/) | one document per slot — chat, coding, vision, ASR, image generation, embedding |
| [`findings/`](../findings/) | results that belong to no single model: the harness, context depth, chunk position, abliteration |
| [`hardware/`](../hardware/) | power, multi-GPU, backends |

A model file links out to all three. It does not repeat their reasoning.

## A caution about the names

The same model appears under different spellings across the data files —
`gemma-4-12b` and `gemma4-12b`, `qwen3.5-2b` and `qwen35-2b`,
`qwen3.8-27b-abliterated` and `qwen3.8-27b-abl`. The generator merges them through an
alias table, and `-slot32k` and `-x8` suffixes fold into the base model since they are
run configurations rather than different models.

**That merging is a judgement, and it is in one place** — the `ALIAS` map at the top of
the generator — rather than scattered through prose.

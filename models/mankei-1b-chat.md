# mankei-1b-chat

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 1 of 10 topics.**

**At chance on German comprehension (0.2267 against 0.25 for guessing)** — and the
publisher says so itself. More informative is the generate harness: **0.0067, with 142 of
150 answers containing no parseable letter.** It writes German, it does not follow an
output instruction. Useful here as the lower anchor the table lacked.

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

Not measured. Interpreted in [image-generation](../use-cases/image-generation.md) where it is.

## Power and energy

Not measured. Interpreted in [power](../hardware/power.md) where it is.

## Throughput and runtime

Not measured. Interpreted in [foreign](../foreign/) where it is.

## What it took to run it

Interpreted in [METHODOLOGY#record-what-it-cost-to-run-the-model-not-only-how-it-scored](../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored).

**[`integration_cost.tsv`](../data/integration_cost.tsv)** — shipped format, steps needed, blockers hit

| model | shipped_as | steps_to_run | blockers_hit | notes |
|---|---|---|---|---|
| mankei-1b-chat | GGUF ladder f16..q3 | download, copy to host | 0 | publisher ships six quants |

# kimi-linear-48b-a3b

Everything measured about this model, by topic. **Every topic is listed, including the ones with no measurement** — a gap you cannot see looks like an answer.

Generated from [`data/`](../data/) by [`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a row there.

**Measured in 4 of 10 topics.**

**Linear attention, and the worst model here at depth — the opposite of what the
architecture promises.** Prefill falls 332 → 40 t/s from an empty cache to 32 768 tokens,
**39× slower than a 35B MoE at the same depth**, with 4.7× the energy. Detail and the
caveat that this measures one model in llama.cpp on Vulkan rather than the architecture
in principle: [context depth](../findings/context-depth.md).

## Language understanding — German chat

Interpreted in [language-understanding](../use-cases/language-understanding.md).

**[`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv)** — prompt formatted by the chat template inside the GGUF

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kimi-linear-48b-a3b | new | logprob | off | 134 | 150 | 0.8933 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 234.6 |
| kimi-linear-48b-a3b | new | generate | off | 133 | 150 | 0.8867 | 20825 | 98 | 138.8 | 1 | 1 | 0 | 0 | 1024 | 1242.7 |
| kimi-linear-48b-a3b | new | generate | on | 133 | 150 | 0.8867 | 35893 | 98 | 239.3 | 0 | 1 | 0 | 0 | 16384 | 1969.0 |

## Coding

Interpreted in [coding](../use-cases/coding.md).

**[`coding_polyglot.tsv`](../data/coding_polyglot.tsv)** — aider-polyglot, 225 tasks

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| kimi-linear-48b-a3b | diff | 4.9 | 12.0 | 90.7 | 38 | 72.7 | 225 |

## Long context — cost against cache depth

Interpreted in [context-depth](../findings/context-depth.md).

**[`context_depth.tsv`](../data/context_depth.tsv)** — throughput and energy at four cache depths

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| kimi-linear-48b-a3b | 0 | on | 332.1 | 20.69 | 149.8 | 1507.0 | 37 |
| kimi-linear-48b-a3b | 4096 | on | 328.1 | 20.67 | 156.3 | 1610.3 | 38 |
| kimi-linear-48b-a3b | 16384 | on | 303.0 | 14.61 | 156.7 | 2022.3 | 47 |
| kimi-linear-48b-a3b | 32768 | on | 40.3 | 12.31 | 138.8 | 7059.0 | 183 |

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
| kimi-linear-48b-a3b | GGUF | download, copy | 0 | linear attention served without special flags |

# Artificial Analysis

**Cited, not run.** Their numbers come from their site; ours come from this repository. Nothing below is a claim that the two are equivalent — the column headers say who measured what.

| | Artificial Analysis | Here |
|---|---|---|
| Object measured | a hosted **endpoint** | a **file on a card we own** |
| Hardware | not stated | documented down to the kernel version |
| Quantisation | not disclosed | every number is Q4_K_M/Q4_0, pinned by SHA256 |
| Language | "primarily text-based, English-language evaluation suite" (their wording) | belebele `deu_Latn`, n up to 900 |
| Verdict source | 10 benchmarks, pass@1 | ground truth, mechanical |
| Embedding / reranker / power | no | yes |

## Why the numbers do not transfer

**The endpoint is not the model.** [Ollama against llama.cpp](../data/ollama_vs_llamacpp.tsv) on the same card, same model, same context: **220 against 168 t/s**. If the runtime alone is worth 25 %, a speed figure from an unnamed provider stack predicts nothing about ours.

**Quantisation is invisible on their side and decisive on ours.** In [QAT against ordinary weights](../findings/qat-vs-ptq.md) every axis moves with file size: +5.7 % bytes cost 5.1 % generation and 9.2 % context ceiling. A provider switching to a smaller variant moves their intelligence figure with no column to show it.

**Their prompt, not the model.** Zero-shot instruction prompting, pass@1, a single repeat on five of the ten evaluations. [The harness](../findings/harness-effect.md) is worth 1.3–2.7 points for ordinary models here and up to 70 for reasoning models. Their published ±1 % interval comes from ">10 repeats on certain models" and therefore does not apply to the single-repeat rows.

## The one model both sides measured

They list **Qwen3.8 27B (xhigh)**; we ran `effort-xhigh` on the same model. Same reasoning setting, different world.

| | Artificial Analysis | Here |
|---|---|---|
| Generation | **44 t/s** (DeepInfra) | **38.4–39.1 t/s** — RX 7900 XTX, Q4_K_M, Vulkan, single stream |
| Quality | Intelligence Index **42** (English, 10 evaluations) | **0.9267** belebele `deu_Latn`, xhigh |
| Price per 1M tokens | **$0.40** net → **~44 ct** gross | **16.9 ct** blended · **59.8 ct** generation only |

**A consumer card at Q4_K_M reaches 87–89 % of a hosted datacenter endpoint** for a single user with no batching. That comparison exists nowhere else, because nobody measures both sides.

Sources: [`data/energy_tokens.tsv`](../data/energy_tokens.tsv), [`data/energy_cost_1m.tsv`](../data/energy_cost_1m.tsv), [`data/context_depth.tsv`](../data/context_depth.tsv), [`data/chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv).

## The price comparison flips on the blend

This is the finding, not the price itself.

| Basis (both gross) | Local | DeepInfra | |
|---|---:|---:|---|
| **3:1 input to output** | 14.4 / **16.9** / 21.5 ct | 44 ct | local **2.6× cheaper** |
| **generation only** | 50.6 / **59.8** / 75.7 ct | 44 ct | local **1.36× more expensive** |

Prefill runs at **10 566 tokens/Wh** against **480** in generation — **22× cheaper per token**. So the mix between the two decides the direction of the answer, and a cost claim without a stated mix is not a result.

**The ratio is invariant to the tax basis as long as both sides share one.** A business deducts input tax on both, so net against net gives the same 2.6× and 1.36×. Only mixing the bases breaks it — a net API price against a gross household tariff understates the API by 19 %.

### Recorded assumptions

These are variables, not constants. They belong in the document rather than inside a rounded number.

| Assumption | Value | Confidence |
|---|---|---|
| Their price column is a 3:1 input/output blend | assumed | **not confirmed** on their methodology page for this version. If it is an output-only price, the blended row above is wrong |
| VAT on the API invoice | 19 % | German household basis, to match our gross tariffs. Reverse charge for a business nets both sides out to the same ratio |
| USD/EUR | ~1.08 | 43–45 ct across 1.05–1.12 |
| Electricity | 7 German household tariffs, 23.08.2026, gross | [`data/strompreise.tsv`](../data/strompreise.tsv) |

## What it is good for

**A candidate filter.** The size ceiling here is ~24 GB. This is the cheapest way to see whether a new open-weights release is worth the download at all.

**A registry of what is hosted anywhere.** Several entries on the [open list](../README.md#open) wait on exactly that condition — a model that cannot run on this hardware becomes reachable the moment somebody serves it.

**Not usable for:** German quality, quantisation, embedding, reranking, energy, or any speed figure meant to predict this hardware.

## Does their index predict our ranking?

For one model, across three points, it does not.

Their open-weights chart carries **Qwen3.8 27B at three reasoning-effort settings**, and we ran all three. Same model, same settings, different task.

| Setting | Their index | belebele `deu_Latn`, n=150 | Tokens | Seconds |
|---|---:|---:|---:|---:|
| low | 34 | 0.9200 | 46 187 | 1 365 |
| medium | 35 | 0.9200 | 53 626 | 1 571 |
| xhigh | 41 | 0.9267 | 45 637 | 1 343 |
| **thinking off** | *not on their chart* | **0.9667** | **28 884** | **898** |

**Their index rises 21 % across the three settings. German reading moves 0.67 points** — at n=150 the noise band is about ±4, so it is flat.

**And the setting they do not carry wins outright.** Switching thinking off is 4 points better than the best effort level, at **37 % fewer tokens and a third less time**. The axis their index rewards most is, for this task, the most expensive one and not the best one.

That is one model at three points, not a correlation. It is enough to say their composite does not transfer to this slot, and not enough to say how it fails in general.

## Coverage

Their open-weights chart, read in full on 05.09.2026. Sizes looked up the same day.

**Already measured here — six of them:** Qwen3.6-27B, Qwen3.5-27B, Qwen3.8-27B, Qwen3.6-35B-A3B, Gemma-4-26B-A4B, Gemma-4-12B.

**Might run, not yet proven — six.** All have finished GGUFs, and all fit the 24 GB card:

| Model | Their index | Size | Q4_K_M |
|---|---:|---|---:|
| Ling 3.0 Tiny | 16 | 7.9B / 1.3B active | **~4.5 GB** |
| Apriel-v1.5-15B Thinker | 15 | 15B dense | ~9 GB |
| Gemma 4 31B | 22 | 31B dense | **~16 GB** |
| Granite 4.2 30B | 16 | 29.3B dense | ~17 GB |
| Nemotron 3.5 Lightning | 16 | 31.6B / 3.6B | ~18 GB |
| Qwen3.5-35B-A3B | 22 | 35B / 3B | **23 GB** — tight |

Two are worth a slot on their own terms rather than for the chart: **Ling 3.0 Tiny at 4.5 GB would run on the [fallback node](../data/fallback_node_cpu_vs_gpu.tsv)**, and **Qwen3.5-35B-A3B is the generation-to-generation comparison** to the Qwen3.6-35B-A3B already measured.

**K-EXAONE 2.0** could not be sized — unresolved, not excluded.

**Out of reach.** The size ceiling, not an omission; sizes are published figures where bold, otherwise scaled from the parameter count:

| Model | Total / active | Q4_K_M |
|---|---|---:|
| Qwen3.8-Flash-Next | 177B | **119.6 GB** |
| Step 3.5 Flash | 196B / 11B | ~110 GB |
| MiniMax-M2.7 | 229B / 10B | ~126 GB |
| Inkling Small | 276B / 12B | ~150 GB |
| Hy3 | 295B / 21B | ~160 GB |
| Motif 3 | 314B / 13.2B | ~170 GB |
| GLM-5.3-Flash | 320B / 18B | **199.7 GB** |
| K2 Horizon | 375B / 23B | ~205 GB |
| Nex-N2-Pro · Agnes-2.5 Pro Alpha | 397B / 17B | ~215 GB |
| MiniMax-M3 | 428B / 23B | ~265 GB |
| MiMo-V2.5-Pro | 1.02T / 42B | — |
| LongCat 2.0 | 1.6T / 48B | — |
| Qwen3.8 2.4T A95B | 2.4T / 95B | — |

Also out: Qwen3.5-122B-A10B, gpt-oss-120b, Solar Open2 250B, Ring-2.6-1T, Command A+.

A low active-parameter count does not help: a GGUF needs **all** weights resident, not only the active ones.

## Open

**A real correlation** needs an index value for more of the models measured here. Their open-weights list carries one; the rest would have to come from the per-model pages, one slug at a time.

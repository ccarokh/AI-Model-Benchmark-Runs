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

## Open

**Does their English index predict our German ranking?** The interesting question, and not yet answerable: of the 16+ models measured here, exactly one carries an Intelligence Index value on their open-weights list. Needs the per-model pages, one slug at a time.

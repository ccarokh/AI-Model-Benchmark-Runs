# What a full context costs

**At an empty cache the 30B MoE reads prompts as fast as the 9B and generates 1.8× faster.
At 32 768 tokens of context the 9B reads 2.4× faster than the MoE and the generation gap
is nearly gone.** The model that wins a long-context RAG slot is not the model that wins
the benchmark, because the benchmark is run at depth 0.

Measured on [System A](../systems/system-a.md). `llama-bench -p 2048 -n 128 -d <depth>
-fa on -r 3`, one variable — the depth. Full table in
[`data/context_depth.tsv`](../data/context_depth.tsv).

## Prompt processing

| Depth | Llama-3.2-3B | Qwen3.5-9B | Qwen3-30B-A3B |
|---|---:|---:|---:|
| 0 | 6 400.5 | 2 712.4 | 2 825.5 |
| 4 096 | 4 833.0 | 2 511.1 | 2 089.3 |
| 16 384 | 2 731.5 | 2 110.4 | 1 154.5 |
| 32 768 | **1 732.7** | **1 734.3** | **721.3** |
| **Loss** | **−72.9 %** | **−36.1 %** | **−74.5 %** |

## Generation

| Depth | Llama-3.2-3B | Qwen3.5-9B | Qwen3-30B-A3B |
|---|---:|---:|---:|
| 0 | 252.22 | 107.94 | 196.46 |
| 4 096 | 212.07 | 104.74 | 170.16 |
| 16 384 | 158.13 | 98.41 | 131.99 |
| 32 768 | **112.66** | **91.96** | **107.29** |
| **Loss** | **−55.3 %** | **−14.8 %** | **−45.4 %** |

## The ranking inverts

| | Depth 0 | Depth 32 768 |
|---|---|---|
| Prefill | MoE ≈ 9B (2 826 vs 2 712) | **9B 2.4× the MoE** (1 734 vs 721) |
| Generation | **MoE 1.8× the 9B** (196 vs 108) | MoE 1.17× the 9B (107 vs 92) |
| Energy for the same work | **MoE cheaper** (309 vs 403 mWh) | **9B cheaper** (471 vs 725 mWh) |

**Qwen3.5-9B is the outlier, and the reason is the thing being measured.** It loses 36 %
of prefill and 15 % of generation across the whole range, where both the 3B and the 30B
lose 45–75 %. Everything about depth scaling is KV cache traffic: how much has to be read
per token, and that is set by the model's attention geometry, not by its size. The 9B is
built to carry a long context; the other two are not.

**For a RAG system this reverses a decision.** The MoE looks like the obvious pick from
the throughput table and from
[tokens per watt-hour](../hardware/power.md#tokens-per-watt-hour-per-phase) — both
measured at depth 0. Fill the context with retrieved passages, which is the entire point
of the system, and it becomes the slower and the more expensive of the two.

**Depth 0 is a benchmark condition, not an operating condition.** No RAG turn ever runs
there.

## Energy rises with depth, and power falls

| Depth | Llama-3.2-3B | Qwen3.5-9B | Qwen3-30B-A3B |
|---|---:|---:|---:|
| 0 | 114.6 mWh @ 187 W | 403.2 @ 290 W | 308.8 @ 273 W |
| 32 768 | 298.9 mWh @ 175 W | 471.4 @ 244 W | 725.3 @ 211 W |

Identical work — 2 048 prompt tokens and 128 generated — costs **2.6× / 1.2× / 2.3×**
more energy with a full context than with an empty one.

**Mean power drops while energy rises**, and the two are the same fact: deep attention is
memory-bound, the arithmetic units idle waiting on the cache, and the card draws less
per second while taking far more seconds. **A watt reading is not an efficiency reading.**

⚠️ Power is sampled at 1 Hz and the shallow runs are short — the depth-0 rows rest on
3–6 samples. The energy *trend* is large and consistent; individual shallow values are
not precise. The `samples` column travels with the data.

## Flash attention buys nothing until the context is full

Same model, same depths, `-fa off` against `-fa on`:

| | Prefill | Generation | Energy |
|---|---:|---:|---:|
| Depth 0 | 2 712 vs 2 672 (+1.5 %) | 107.9 vs 106.7 (+1.1 %) | 403 vs 394 mWh |
| **Depth 32 768** | 1 734 vs 1 567 (**+10.7 %**) | 91.96 vs 77.64 (**+18.4 %**) | 471 vs 556 mWh (**−15 %**) |

At depth 0 the difference is inside the noise, and a benchmark run there would report
flash attention as pointless. At a full context it is worth **18 % of generation and 15 %
of the energy bill.**

**This is the same trap as the model ranking above**, and it is worth stating on its own:
a feature that only acts under load looks like a no-op when measured without load.

## Part 2 — the four fastest models, and the architecture that promised the most

A second round on the models that came out on top of the
[German comprehension re-run](harness-effect.md), plus the one linear-attention model
on the box. **Linear attention is the reason this round exists**: the KV cache is
supposed not to grow with length, which is exactly the quantity that made the ranking
invert above.

| Depth | Kimi-Linear-48B-A3B | Qwen3.5-27B | Ornith-35B | Qwen3.6-35B-A3B |
|---|---:|---:|---:|---:|
| **Prefill 0** | 332.1 | 837.0 | 2 626.3 | 2 631.3 |
| 32 768 | **40.3** | 560.9 | 1 580.5 | 1 577.9 |
| **Loss** | **−87.9 %** | −33.0 % | −39.8 % | −40.0 % |
| **Generation 0** | 20.69 | 39.09 | 140.15 | 138.46 |
| 32 768 | 12.31 | 34.46 | 117.69 | 115.92 |
| **Loss** | −40.5 % | **−11.8 %** | −16.0 % | −16.3 % |
| **Energy 0 → 32k** | 1 507 → **7 059** mWh | 1 375 → 1 492 | 378 → 481 | 372 → 486 |

### The linear-attention model is the worst at depth, not the best

**Kimi-Linear collapses to 40.3 tokens per second of prompt processing at 32 768** —
**39× slower than Ornith-35B at the same depth**, and 8.2× slower than itself at depth
0. Energy for identical work rises **4.7×**.

The architectural claim is that linear attention removes the growth term. On this
hardware, through this runtime, **the opposite is measured**: it is the steepest curve
in the table by a wide margin, and it was already the slowest model at depth 0.

⚠️ **This measures a model in llama.cpp on Vulkan, not the architecture in principle.**
An implementation that has not been optimised for this path can lose everything the
design was supposed to win. What it does establish is that **the promise does not
arrive by itself** — it has to be measured on the runtime you actually use.

**Consequence for the shortlist:** hybrid and linear-attention models do not get the
benefit of the doubt on long context here. They get measured first.

### The two best German readers are one model

Ornith-35B and Qwen3.6-35B-A3B agree to within **0.2 % on every one of eight
measurements**. The GGUF metadata explains it:

| Model | `general.architecture` | `general.name` |
|---|---|---|
| ornith-1.0-35b | **`qwen35moe`** | Ornith 1.0 35B |
| Qwen3.6-35B-A3B | **`qwen35moe`** | Qwen3.6 35B A3B |
| Qwen3.5-27B | `qwen35` (dense) | Qwen3.5-27B |

**Ornith-35B is a derivative of the same Qwen MoE.** Its 0.7-point lead in German
comprehension is what a fine-tune moves, not an independent finding — and the two
should never be quoted as two results.

The same metadata explains Qwen3.5-27B: **dense**, so 837 t/s of prefill against 2 626
for a *larger* MoE. It buys something for it, though — **the flattest generation curve
in the whole file at −11.8 %.**

### Reading this against Part 1

The 30B MoE lost 74.5 % of prefill across the same range. **These 35B MoEs lose 40 %**,
and the dense 27B loses 33 %. Depth scaling is not "MoE against dense" — it is the
attention geometry of the particular model, and it has to be read per model.

### Qwen3.8-27B: a hybrid that behaves exactly like the dense model it replaces

Gated DeltaNet is the same architectural family as Kimi-Linear's, so the depth curve was
the first thing measured on it — a repeat of the 87.9 % collapse would matter more for a
RAG system than any accuracy figure.

| Depth | Qwen3.8-27B (hybrid) | Qwen3.5-27B (dense) | Kimi-Linear (linear) |
|---|---:|---:|---:|
| Prefill 0 | 821.7 | 837.0 | 332.1 |
| Prefill 32 768 | 572.9 | 560.9 | **40.3** |
| **Loss** | **−30.3 %** | −33.0 % | −87.9 % |
| Generation 0 | 39.07 | 39.09 | 20.69 |
| Generation 32 768 | 34.43 | 34.46 | 12.31 |
| **Loss** | **−11.9 %** | −11.8 % | −40.5 % |

**No collapse — and no gain either.** Against the previous dense 27B it matches to the
second decimal on generation at both ends. The same holds for energy: 10 566 against
10 564 tokens per Wh on prefill, 480 against 481 on generation.

**A hybrid attention mechanism that promises flatter cache growth produces a curve
indistinguishable from the dense model it succeeds.** Whether the design does nothing or
whether llama.cpp does not exploit it is not separable here — but the same runtime
[discards this model's MTP head](../README.md#open) as `unused tensor`, so a runtime that
declines part of an architecture is the more likely explanation.

## What this does not cover

- **One prompt size** (2 048) at every depth. How cost splits between *prompt length* and
  *cache depth* is not separated here.
- **f16 KV cache throughout.** Quantised KV changes both the memory traffic and the
  ceiling, and is
  [a documented trap of its own](../METHODOLOGY.md#a-context-size-without-a-cache-type-is-not-a-specification).
- **No accuracy.** This measures what a full context *costs*, not whether the model still
  uses what is in it. A model that stays fast at 32 k and ignores the middle of its
  context has not earned anything.

## Scripts

- [`scripts/hardware/context_depth.sh`](../scripts/hardware/context_depth.sh)

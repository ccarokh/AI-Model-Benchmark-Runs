# What a full context costs

**At an empty cache the 30B MoE reads prompts as fast as the 9B and generates 1.8× faster.
At 32 768 tokens of context the 9B reads 2.4× faster than the MoE and the generation gap
is nearly gone.** The model that wins a long-context RAG slot is not the model that wins
the benchmark, because the benchmark is run at depth 0.

Measured on [System A](../SYSTEMS.md#system-a). `llama-bench -p 2048 -n 128 -d <depth>
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

# Memory tiers: what a gigabyte costs when it is not on the card

**Measured 10.09.2026 — and both predictions were wrong.** The design below is left as written; the results follow it, so the wrongness stays visible.

## The wrong sort

This repository sorts models by size. The [size ceiling](../README.md#size-ceiling) says ~24 GB, and every model above it was set aside — including several whose *active* parameter count is a tenth of their total:

| Model | total / active | set aside because |
|---|---|---|
| MiniMax-M2.7 | 229B / **10B** | 229B |
| Inkling Small | 276B / **12B** | 276B |
| Motif 3 | 314B / **13.2B** | 314B |
| GLM-5.3-Flash | 320B / **18B** | 320B |
| Hy3 | 295B / **21B** | 295B |
| Qwen3.8-Flash-Next | 125B + 51B n-gram / **6B** | 119.6 GB — a figure that was itself wrong |

For a dense model the total size is the right sort: every parameter is read for every token. For a sparse one it is the wrong column, and this repository has been using it anyway.

The question that replaces it: **which part has to be fast, and which part only has to be present?**

## The dial

llama.cpp makes the split explicit, and for Qwen3.8-Flash-Next the flags are documented rather than improvised:

```
--override-tensor "per_layer_token_embd=CPU,ple_ngram_embd=CPU"
--n-cpu-moe N
```

The first places named tensor classes in host memory. The second moves the expert weights of the first N layers there — a dial from 0 to 48 on this model.

That dial is what makes this measurable at all. Until now the machine offered one question, *does it fit*, with two answers. A dial offers a curve, and every worthwhile result in this repository came from a curve rather than a yes.

## The questions, in the order they should be asked

**0. What is the slow tier actually worth?** Every prediction below divides by this number and it has never been measured here. The host is an i9-9900K, so DDR4 in two channels — 41.6 GB/s on the data sheet at DDR4-2666, and data sheets are not measurements. `dmidecode` returns nothing on this machine, so even the configured clock is unknown. **Measure it before predicting anything from it**, the same way the card's bandwidth was established rather than assumed.

**1. Does it load at all.** The published figure is 45.8 GB that must stay in fast memory. This machine has 24 GB on one card, 8 GB on the second and 15 GB of host memory. If this fails, questions 2 to 6 are void.

⏳ **Pending: host memory goes from 16 GB to 32 GB** (DDR4-3000 CL16, two modules replacing what is there rather than joining it — four populated slots on this platform typically cannot hold the rated clock). That moves fast memory from 39 GB to 56 GB and turns question 1 from a coin toss into a formality. It also raises the slow tier from 42.7 to 48.0 GB/s on paper — **only if XMP is enabled**, since the CPU's own specification stops at 2666 and the modules will quietly run there otherwise. Both numbers are still data sheets: question 0 stands.

**2. What does a gigabyte in slow memory cost?** Sweep `--n-cpu-moe` and record generation rate against the share of weights below the card. The answer is a number this repository does not have and could not previously obtain, and it is not specific to one model: it prices every future decision of the form *"it almost fits"*.

**3. Is the n-gram table really free to demote?** One variable: `ple_ngram_embd` on the card against in host memory, everything else identical. It is a deterministic lookup consulted once per token, so the claim is that it costs nothing. Claims of that shape are exactly what this repository exists to check.

**4. Does the bandwidth law survive a mixed tier?** [Generation scales almost exactly with memory bandwidth](../foreign/geerlingguy-ai-benchmarks.md#generation-scales-with-memory-bandwidth-almost-exactly) — measured so far only by comparing whole cards. A tier split runs one process across 960 GB/s and DDR4 in two channels — 41.6 GB/s on paper, unmeasured in practice, and realistically closer to 30 than to 40.

**Prediction: the rate follows the weighted mean of the two bandwidths, weighted by how much of the per-token read comes from each.** With DDR4 rather than DDR5 the ratio is roughly 1:27, not 1:12 — so the penalty for demoting a layer is steep, and the curve from question 2 should fall fast and early rather than gently. If it does, the law is stronger than the evidence so far justified. If it does not, this is where its boundary is, and that is the more interesting outcome.

**5. Prefill against generation.** Prefill is compute-bound, generation bandwidth-bound. **Prediction: the split costs generation several times what it costs prefill.** If both degrade equally the mechanism is not what we think it is, whatever the correlation in question 4 says.

**6. A third tier.** The model store now sits on an NVMe drive rather than the older disk. The n-gram table in host memory against `mmap` from NVMe is a third step on the same ladder — ~7 GB/s against DDR4 against 960.

## What this changes if it works

Not one model. **The sort.** Every entry on the [open list](../README.md#open) that was dismissed by total size gets re-read by active share, and the curve from question 2 predicts which of them are reachable before anybody downloads 200 GB to find out.

## What would make it a failure worth publishing

If question 1 fails, the honest result is a ceiling stated in the right units: not "24 GB" but "45.8 GB of fast memory is more than 24 + 8 + 15 provides". That is a better sentence than the one in the README today, and it costs one download to earn.


---

## Results, 10.09.2026

Three MoE models already on the machine, `--n-cpu-moe` from 0 to 48, pinned build b10273, `-p 512 -n 128 -r 2`, card pinned. Full table in [`data/testbench/tierkurve.tsv`](../data/testbench/tierkurve.tsv).

| `qwen3-30b-a3b` | layers on CPU | prefill t/s | generation t/s |
|---|---:|---:|---:|
| all on the card | 0 | 2 246 | **191.8** |
| | **4 of 48** | 858 | **94.5** |
| | 8 | 544 | 60.6 |
| | 16 | 268 | 42.5 |
| all on CPU | 48 | 104 | 19.7 |

**Four of 48 layers in host memory, and generation halves.** `gpt-oss-20b` and `qwen3.6-35b-a3b` trace the same curve. The control point holds: `gpt-oss-20b` has 24 layers and the curve goes flat from `--n-cpu-moe 24` on, because everything is already on the CPU.

### Prediction 4 was wrong: the cost adds, it does not average

The plan predicted the rate would follow the bandwidth-weighted mean of the two tiers. Moving 8 % of the weights from 960 GB/s to ~51 GB/s should then have left ~92 % of the rate. **Measured: 49 %.**

The reason is order, not bandwidth. Every token passes through every layer *in sequence*. A layer in host memory costs about **ten times** a layer on the card — 1.06 ms against 0.11 ms on this model — and those costs add up along the chain. A serial model of the same numbers predicts 111 t/s at four layers against 94.5 measured; close, and far closer than 92 %. The bandwidth law is still true per layer. It is not what a token experiences.

### Prediction 5 was wrong, and in the other direction

The plan predicted the split would cost generation several times what it costs prefill, because generation is bandwidth-bound and prefill is not. **Prefill lost more:** 21× against 10× at full offload.

Prefill is compute-bound, and the CPU is not merely slower at reading than the card — it is far slower at computing. A tier that is 19× slower on paper by bandwidth is 10× slower where bandwidth rules and 21× slower where compute does.

### What it settles

**More host memory lets a model load. It does not let it run.** Every layer that does not fit on the card costs an order of magnitude, and that cost sits in the chain of every token. The reframing that started this page — sort models by what has to be fast, not by total size — survives; the conclusion drawn from it, that the slow part can be slow, does not. **The active path is the whole chain**, and one slow link slows everything behind it.

The purchase question this was meant to inform is therefore answered before any purchase: host memory at 51 GB/s is not a tier a model can live in. It is where a model goes to be loadable, at ten times the cost. A platform with four or eight memory channels would move that to roughly three times — better, and still not a place to run from.

The second card is a different matter. It is measured in [multi-gpu.md](multi-gpu.md), and it is the only overflow on this machine that costs less than an order of magnitude.

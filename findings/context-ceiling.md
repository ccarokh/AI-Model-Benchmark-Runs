# Where the context stops — measured, not estimated

"That does not fit on 12 GB" is a sentence. This is the number it was standing in for.

Every ceiling here was found by trying: double the requested context until the allocation
fails, then halve the gap until it is under 4 096 tokens. Recorded per model are **the
largest size that still allocated and the smallest that did not**, with the error the
failing one gave. Found by
[`70_fit_ceiling`](../scripts/testbench/tests/70_fit_ceiling.py) on an RTX 4070 Super,
12 282 MiB, all weights on the GPU.

## The 12 GB class

| Model | File | f16 cache | q8_0 cache |
|---|---:|---:|---:|
| Llama-3.2-3B | 1.88 GiB | 86 016 | 163 840 |
| **Qwen3.5-9B** | 5.29 GiB | **204 800** | **385 024** |
| ornith-9b | 5.24 GiB | 204 800 | 389 120 |
| DeepSeek-R1-14B | 8.37 GiB | **16 384** | 32 768 |
| Qwen2.5-Coder-14B | 8.37 GiB | **16 384** | 32 768 |
| gpt-oss-20B (MoE) | 11.28 GiB | **16 384** | 36 864 |

## The 12B class, and what the file format is worth in context

Three quantisations of one model, plus a Llama for scale. Vulkan first, CUDA second:

| File | Size | f16 cache | q8_0 cache |
|---|---:|---:|---:|
| gemma-4-12b **QAT** Q4_0 | 6.50 GiB | **266 240** / 253 952 | **520 192** / 417 792 |
| gemma-4-12B Q4_0 | 6.72 GiB | 253 952 / 241 664 | 491 520 / 397 312 |
| gemma-4-12B Q4_K_M | 7.14 GiB | 225 280 / 212 992 | 446 464 / 360 448 |
| Meta-Llama-3.1-8B Q4_K_M | 4.58 GiB | 57 344 / 53 248 | 106 496 / 98 304 |

**Choosing the file is worth 18 % of the context.** 266 240 against 225 280 tokens is
40 960 tokens of difference on the same card, the same model and the same card memory —
decided by nothing but which quantisation was downloaded. The QAT file is the smallest of
the three and holds the most.

**The 8B holds a quarter of what the 12B holds** — 57 344 against 253 952 with 2.1 GiB
*fewer* weights. Same lesson as the 3B below, one class up: the KV cache is an architecture
property, not a size property.

**CUDA leaves less room than Vulkan for the same card.** Every ceiling above is 4–20 % lower
under CUDA — 417 792 against 520 192 tokens on the QAT file. The backend, not the card,
decides how much of the memory is reachable.

## Three things this says that arithmetic did not

**The 14B class hits a wall, and it is a property of the class.** Two unrelated 14B models
— a DeepSeek-R1 distillation and a Qwen coder — land on **exactly the same** ceiling,
16 384 tokens, with the first failure at 20 480, on both backends. That is not a quirk of
one model's attention layout; it is what 8.4 GiB of weights leaves over on a 12 GiB card.

**A 9B holds twelve times the context of a 14B.** 204 800 against 16 384, for 3.1 GiB more
weights. Anyone sizing a RAG system by parameter count is sizing the wrong number: what
decides is what is left after the weights, and the last three gigabytes of a card are worth
more than the first ten.

**The smaller model is not the roomier one.** Llama-3.2-3B tops out at 86 016 while the 9B
reaches 204 800 — less than half the context for a third of the weights. The KV cache does
not scale with parameter count but with layers × KV heads × head dimension, and the 3B pays
more per token. A rule of thumb that says "smaller model, more room for context" is wrong
here by a factor of 2.4.

## Quantising the cache buys context, not speed

The q8_0 column is roughly double the f16 one throughout — and it is not a trade against
throughput. At depth 65 536 the quantised cache is **4 % faster** in generation (60.59
against 58.18 t/s) while using 968 MiB less. What it costs is prefill: at that depth,
1 485 against 2 134 t/s, about 30 %.

**So the trade is prefill for context, not quality of service for capacity.**

## The last failure is the informative one

```
d196608  allocates
d229376  FAILS -- ggml_vulkan: Device memory allocation of size 940572672 failed.
d212992  FAILS -- ggml_vulkan: Device memory allocation of size 525336576 failed.
d204800  FAILS -- ggml_vulkan: Device memory allocation of size 12582912 failed.
d200704  allocates
```

At 204 800 tokens the card refuses **12 MB**. That is the shape of a real ceiling: it is not
approached gradually, it is a cliff where a routine allocation of a few megabytes is the one
that cannot be served. A safety margin of "a few hundred MiB" is not a margin at all.

## The same ceiling, seen as users

A context ceiling is also a user ceiling. Give each user 8 192 tokens and
DeepSeek-R1-14B serves exactly two of them before the server refuses to start —
2 × 8 192 = 16 384, the ceiling in the first table. The arithmetic holds across the
models measured, with one correction: **cutting the same total into more slots costs
extra memory**, so the division is a starting point and not a result. Measured in
[serving many users](serving-many-users.md).

## What is not measured here

**Only one card.** Every figure is the 12 GB class. The same test on the 24 GB machine has
not been run — the ceilings there will be different and the *shape* of the finding is what
transfers, not the numbers.

**Allocation, not throughput.** The probe asks for a context and generates one token; it
answers "does this fit", not "what does it cost at that depth". The cost curve is
[context depth](context-depth.md), and it is a different and much more expensive
measurement. An earlier version of this test filled every depth before judging it and took
**seven minutes per probe** at 327 680 tokens, which is why it covered two models instead of
seven.

The two probes agree within one bisection step: filling the depth put the 9B/f16 ceiling at
200 704, allocating alone puts it at 204 800. The allocation probe is **4 096 tokens
optimistic**, because the compute buffers a real prefill needs are not reserved. That is a
known, bounded difference, not an unknown one.

## Scripts

- [`70_fit_ceiling.py`](../scripts/testbench/tests/70_fit_ceiling.py) — the bisection
- [`80_model_ceiling.py`](../scripts/testbench/tests/80_model_ceiling.py) — does the model fit at all, and what does it really occupy
- Raw data: [`data/testbench/system-c-rtx4070-super.tsv`](../data/testbench/system-c-rtx4070-super.tsv)

# Speed that changes the answer

Every generation figure in this repository is bandwidth-bound: one token, one pass over the weights, and the card's memory bandwidth sets the ceiling. **Speculative decoding is the one lever that beats that ceiling without changing the hardware** — several tokens are guessed and then checked in a single pass. Current llama.cpp offers eleven variants of it, and none of them appeared in any measurement here until now.

Measured on an RTX 4070 Super, 12 282 MiB, two builds from the same commit `70adb1b` (Vulkan and CUDA 13.3), nine models, two prompts, **three runs per cell that actually drafted**, by [`90_speculative`](../scripts/testbench/tests/90_speculative.py). Every run is a fresh `llama-server` process answering exactly one request at temperature 0. Rows in [`system-c-rtx4070-super.tsv`](../data/testbench/system-c-rtx4070-super.tsv).

Two numbers per run, never one: **tokens per second, and whether the answer is still the same answer.** The wording is compared against this machine's own unspeculated run of the same model and the same prompt.

## What it is worth

| Model | Best variant | Three runs | Wording |
|---|---|---|---|
| gemma-4-12b QAT Q4_0 | `ngram-mod`, CUDA, prose | **5.22 · 5.16 · 5.23×** | identical |
| gemma-4-12B Q4_0 | `ngram-mod`, Vulkan, prose | **4.02 · 4.00 · 4.02×** | identical |
| gemma-4-12B Q4_K_M | `draft-mtp`, CUDA, code | 2.26 · 2.26 · 2.26× | identical |
| gpt-oss-20B | `ngram-map-k`, Vulkan, prose | 1.65 · 1.63 · 1.65× | identical |
| Meta-Llama-3.1-8B | `draft-simple` + Llama-3.2-3B, CUDA, code | 1.16 · 1.16 · 1.16× | identical |
| Qwen2.5-Coder-14B | `ngram-simple`, Vulkan, prose | 1.01 · 1.01 · 1.01× | identical |
| DeepSeek-R1-14B | — | never drafted | — |
| Qwen3.5-9B | — | never drafted | — |
| ornith-9b | — | never drafted | — |

**A factor of five, for free, on a file that was already the smallest and fastest of its family.** No draft model, no additional VRAM: `ngram-mod` drafts from the text the model has already produced.

## More than half of all runs drafted nothing at all

| Variant | Drafted nothing |
|---|---|
| `draft-simple` + an embedding model | 36 of 36 |
| `ngram-simple` | 29 of 38 |
| `ngram-mod` | 26 of 36 |
| `ngram-map-k` | 23 of 36 |
| `draft-simple` + Llama-3.2-3B | 16 of 22 |
| `draft-mtp` + the matching MTP head | **0 of 12** |

This is the finding, not a defect. The ngram variants need repetition in the output to draft from; where there is none, the server accepts the flag and speculates nothing. **That failure is silent** — the run comes back at exactly baseline speed with the baseline answer, and reads like a measurement that the method does not pay. It has to be recorded as "nothing was drafted", which is what the acceptance line in the server log proves. The first version of this test paired an embedding model as a drafter with a 12B target and filed the result as `1.00×, wording identical`.

The one pairing that never failed is the purpose-built one: **the MTP head shipped for this model drafted in every single run.**

## The prompt decides whether the answer survives

Same model, same variant, same card:

| | Prose prompt | Code prompt |
|---|---|---|
| gemma-4-12B Q4_0, `ngram-mod`, Vulkan | 4.02× — **identical** | 3.13× — **differs** |
| gemma-4-12b QAT, `ngram-mod`, CUDA | 5.22× — identical | 3.36× — differs |
| gemma-4-12B Q4_K_M, `draft-mtp`, Vulkan | 1.56× — differs | 1.86× — identical |

Whether the wording survives is **deterministic per configuration** — three runs of a cell always agree with each other — and not predictable from the method, the model or the card. It has to be measured per case.

## The threshold does not buy exactness

`--spec-draft-p-min` decides how much of a draft is taken on trust, and looks like the knob for this. It is not:

| gemma-4-12B Q4_0, `draft-mtp`, Vulkan, prose | | |
|---|---|---|
| `p-min 0.00` | 2.90× | identical |
| `p-min 0.50` | 2.97× | identical |
| `p-min 0.90` | 2.91× | **differs** |
| `p-min 0.99` | 2.90× | **differs** |

and on the same model with the code prompt the flip runs the other way, `0.90` being the only exact one. Each of those settings is reproducible on its own — the pair `0.90` and `0.99` was run three times each and agreed with itself every time. **As a control for exactness the threshold is useless: it flips in both directions and costs speed monotonically.**

## What repeats changed, and why they exist now

The first pass measured every cell once. Two cells then disagreed with themselves across backends by a factor of four, which read as a spectacular backend difference. Repeated, most of that vanished:

```
qat, prose, ngram-mod, Vulkan      first pass 1.26x    three runs 1.26 · 3.98 · 4.00x
gpt-oss, prose, ngram-mod, Vulkan  first pass 1.01x    three runs 1.01 · 1.57 · 1.60x
```

**The first run of a cell can be an outlier; the following ones are stable to ±0.03.** Everything above therefore rests on three runs, and a single-run figure for this quantity should not be believed.

What did *not* vanish is a genuine, reproducible backend split: `ngram-mod` on the prose prompt gives **4.02× under Vulkan and 1.84× under CUDA** on one model, and **3.98× under Vulkan against 5.22× under CUDA** on its sibling. Both are stable across three runs. The two backends produce different text for the same prompt — their output hashes differ — and how draftable that text is differs with it.

## What this does not say

- **256 tokens per run, two prompts.** Long answers and other kinds of work are untested, and the ngram variants live or die on exactly that.
- **A different wording is not a worse wording.** Nothing here measures whether the speculated answer is better or worse — only whether it is the same. The quality half would need a scored benchmark per variant.
- **One card.** Whether the factors hold on a different architecture is queued on the 7900 XTX.

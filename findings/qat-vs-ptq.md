# Does quantisation-aware training pay? Four axes, one answer

Google ships Gemma 4 twice: as ordinary weights, and as **QAT** weights — trained with the quantisation in the loop instead of being squeezed into it afterwards. The claim attached to that is better quality at the same size. This is what it is worth on one card.

Three files of the same model, measured against each other on an RTX 4070 Super: the QAT weights in Q4_0, ordinary weights in Q4_0, ordinary weights in Q4_K_M. **The middle arm is the one that makes the comparison work** — without it the QAT file carries both a different recipe *and* a different format, and its advantage cannot be attributed to either.

| | QAT Q4_0 | Q4_0 | Q4_K_M |
|---|---:|---:|---:|
| File | **6.50 GB** | 6.72 GB | 7.14 GB |
| VRAM, loaded | **7 456 MiB** | 7 688 MiB | 8 117 MiB |
| Prefill, Vulkan / CUDA | 2 607 / 3 560 | 2 624 / 3 574 | 2 558 / 3 269 |
| **Generation, Vulkan / CUDA** | **59.53 / 59.89** | 57.95 / 58.07 | 53.79 / 55.03 |
| Context ceiling, f16 | **266 240** | 253 952 | 225 280 |
| **belebele deu_Latn, n=900** | **94.11 %** | 94.00 % | 93.78 % |

## The quality claim does not survive n=900

| Harness | QAT Q4_0 | Q4_0 | Q4_K_M |
|---|---:|---:|---:|
| letter probability | 94.11 % | 94.00 % | 93.78 % |
| free generation | 93.78 % | 93.78 % | 94.22 % |

900 questions puts the 95 % interval at about **±1.6 points**. The whole spread across three files and two harnesses is **0.44 points**, and the two harnesses do not even rank the arms the same way. **There is no measurable quality difference** — not between QAT and ordinary weights, and not between the two formats.

That is not a refutation of the recipe. It is the statement that at this size, on this benchmark, in German, the difference is smaller than what 900 questions can see.

## The speed advantage is real and is not the recipe

QAT generates **2.7 % faster than ordinary weights in the same format**. That is not a better kernel or better weights: the QAT file is **3.3 % smaller**, generation is bandwidth-bound, and 1/1.033 predicts 3.2 % where 2.7 % was measured. The gain is fewer bytes to read.

The format is worth considerably more: **Q4_0 generates 7.7 % faster than Q4_K_M**, the simpler dequantisation path doing what its reputation says it does.

## So the recommendation is a file, not a recipe

**The QAT file is smaller, faster, holds 18 % more context, and answers the same.** There is no axis measured here on which it loses. Anyone who has the choice should take it — but should take it because it is the smallest Q4_0 available, not because of the training recipe, which this measurement cannot see.

## What this does not say

- **One model, one language, one benchmark.** belebele German at n=900 says nothing about code, reasoning or long-context behaviour, where a quantisation difference could well show up.
- **The fourth cell is missing.** QAT weights in Q4_K_M would separate recipe from format completely. Requantising the existing file cannot supply it honestly — the source is already quantised, so the result carries a second loss that a Q4_K_M built from the original weights would not have.
- **Thinking is off for every arm.** Gemma 4 opens with reasoning; with it on, the letter-probability harness reads thought text instead of the answer and scores the model at 35 % against its true 94 %. Both harnesses are run precisely because one of them can fail that way, and both were run with reasoning off.

Rows: [`chat_belebele_quantisation.tsv`](../data/chat_belebele_quantisation.tsv), [`system-c-rtx4070-super.tsv`](../data/testbench/system-c-rtx4070-super.tsv).

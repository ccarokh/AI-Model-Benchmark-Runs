# Does quantisation-aware training pay? Four axes, one answer

Google ships Gemma 4 twice: as ordinary weights, and as **QAT** weights — trained with the quantisation in the loop instead of being squeezed into it afterwards. The claim attached to that is better quality at the same size. This is what it is worth on one card.

Four files of the same model, measured against each other on an RTX 4070 Super. **The two middle arms are what make the comparison work** — with only the QAT Q4_0 file and an ordinary Q4_K_M one, the difference carries a different recipe *and* a different format, and cannot be attributed to either.

| | QAT Q4_0 | Q4_0 | Q4_K_M | QAT → Q4_K_M |
|---|---:|---:|---:|---:|
| File | **6.50 GiB** | 6.72 GiB | 7.14 GiB | 6.87 GiB |
| VRAM, loaded | **7 456 MiB** | 7 688 MiB | 8 117 MiB | 7 845 MiB |
| Prefill, Vulkan / CUDA | 2 607 / 3 560 | 2 624 / 3 574 | 2 558 / 3 269 | 2 670 / 3 322 |
| **Generation, Vulkan / CUDA** | **59.53 / 59.89** | 57.95 / 58.07 | 53.79 / 55.03 | 56.48 / 56.87 |
| Context ceiling, f16, Vulkan | **266 240** | 253 952 | 225 280 | 241 664 |
| **belebele deu_Latn, n=900** | **94.11 %** | 94.00 % | 93.78 % | 93.67 % |

The fourth column is the same weights as the first, repacked into the other format. **Every axis moves with the file size and nothing else:** +5.7 % bytes, −5.1 % generation, −9.2 % context ceiling, and a quality difference of 0.11 points, which is a seventh of what 900 questions can resolve.

## The quality claim does not survive n=900

| Harness | QAT Q4_0 | Q4_0 | Q4_K_M | QAT → Q4_K_M |
|---|---:|---:|---:|---:|
| letter probability | 94.11 % | 94.00 % | 93.78 % | 93.67 % |
| free generation | 93.78 % | 93.78 % | 94.22 % | 93.56 % |

900 questions puts the 95 % interval at about **±1.6 points**. The whole spread across four files and two harnesses is **0.66 points**, and the two harnesses do not even rank the arms the same way. **There is no measurable quality difference** — not between QAT and ordinary weights, and not between the two formats.

The fourth arm was measured twice, by two different paths through the same script, and returned **843 and 843 correct on one harness, 842 and 842 on the other**. The instrument repeats to the question; the spread above is the models, not the measurement.

That is not a refutation of the recipe. It is the statement that at this size, on this benchmark, in German, the difference is smaller than what 900 questions can see.

## The speed advantage is real and is not the recipe

QAT generates **2.7 % faster than ordinary weights in the same format**. That is not a better kernel or better weights: the QAT file is **3.3 % smaller**, generation is bandwidth-bound, and 1/1.033 predicts 3.2 % where 2.7 % was measured. The gain is fewer bytes to read.

The format is worth considerably more: **Q4_0 generates 7.7 % faster than Q4_K_M**, the simpler dequantisation path doing what its reputation says it does.

## So the recommendation is a file, not a recipe

**The QAT file is smaller, faster, holds 18 % more context, and answers the same.** There is no axis measured here on which it loses. Anyone who has the choice should take it — but should take it because it is the smallest Q4_0 available, not because of the training recipe, which this measurement cannot see.

## What this does not say

- **One model, one language, one benchmark.** belebele German at n=900 says nothing about code, reasoning or long-context behaviour, where a quantisation difference could well show up.
- **The fourth cell is an approximation.** The QAT → Q4_K_M arm was made by requantising the existing Q4_0 file, so it carries a second loss that a Q4_K_M built from the original weights would not have. It lands 0.11 and 0.22 points below its source — inside the noise, and in the direction that second loss predicts. It bounds the question rather than answering it: **if the recipe survived the format change it would show here, and nothing shows.**
- **Thinking is off for every arm.** Gemma 4 opens with reasoning; with it on, the letter-probability harness reads thought text instead of the answer and scores the model at 35 % against its true 94 %. Both harnesses are run precisely because one of them can fail that way, and both were run with reasoning off.

Rows: [`chat_belebele_quantisation.tsv`](../data/chat_belebele_quantisation.tsv), [`system-c-rtx4070-super.tsv`](../data/testbench/system-c-rtx4070-super.tsv).

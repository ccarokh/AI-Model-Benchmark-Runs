# Language understanding (German)

> ⚠️ Measured on **[System B](../SYSTEMS.md#system-b) v1.0** (llama.cpp build 9614),
> except Qwen3.6-27B which ran on **System A v1.0**. Two caveats follow from that:
> the ranking is a **hardware mix** (see [below](#provenance-caveat)), and B v1.0's
> surrounding stack was not captured to the depth System A's was — only the
> llama.cpp build is on record.

**16 models measured on belebele_deu_Latn. The incumbent 9B was never beaten —
including by models three times its size.**

This slot serves the German-language chat, of which RAG is the main application.
The metric is extractive reading comprehension in German — which is what the model
actually does in that role: read a retrieved passage, answer from it.

## Results

n = 150 unless noted, same harness throughout, single-token logprob evaluation.
Raw data: [`data/chat_belebele.tsv`](../data/chat_belebele.tsv).

| Model | Correct | n | Accuracy | Note |
|---|---:|---:|---:|---|
| **Qwen3.5-9B** *(incumbent)* | 140 | 150 | **93.3 %** | stays |
| Qwen3.6-27B | 140 | 150 | 93.3 % | no upgrade — level at 3× the size |
| Gemma-4-12B | 139 | 150 | 92.7 % | later chosen for [vision](vision.md) instead |
| Gemma-4-E4B | 137 | 150 | 91.3 % | |
| Qwen3-14B | 137 | 150 | 91.3 % | |
| Qwen3-30B-A3B-Instruct-2507 | 136 | 150 | 90.7 % * | best MoE candidate |
| Qwen2.5-Coder-32B | 134 | 150 | 89.3 % | a **coding** model; belebele is the wrong metric for it |
| Qwen3.5-4B | 134 | 150 | 89.3 % | |
| Nemotron-Nano-9B-v2 | 133 | 150 | 88.7 % | lateral move, not adopted |
| Qwen3-8B *(previous default)* | 133 | 150 | 88.7 % | |
| Qwen3-4B-Instruct | 132 | 150 | 88.0 % | |
| ERNIE-4.5-21B-A3B | 128 | 150 | 85.3 % | not adopted |
| Granite-4.1-8B | 127 | 150 | 84.7 % | not adopted |
| Qwen3.5-2B | 110 | 150 | 73.3 % | reference point |
| EuroLLM-9B-Instruct | 100 | 150 | 66.7 % | not adopted |
| DeepSeek-R1-7B | 32 | **50** | 64.0 % | ⚠️ partial run, not comparable |
| OLMoE | 50 | 150 | 33.3 % | |

\* Provenance caveat below.

One further result file (`commandr`) exists but is unreadable and is excluded rather
than guessed at.

**The 4B class is the surprise in this table.** Qwen3.5-4B at 89.3 % sits within four
points of the 27B model, at roughly a tenth of the memory. For a metric this
saturated, "which model" matters far less than the table's spread suggests.

## What the table shows

**Size did not buy accuracy.** Qwen3.6-27B at 15.7 GB scored exactly what the 5.3 GB
incumbent scored — 140 of 150, the same number. Three times the memory, zero gain.

**Marketing claims did not transfer.** EuroLLM-9B is built and promoted for EU
language coverage and beats Gemma-2-9B on translation benchmarks. On German reading
comprehension it came last, below a 2B model. Translation quality between EU
languages and German extractive reading comprehension are different skills, and the
second one is what a RAG chat needs. Granite-4.1 showed the same pattern from the
other direction: IBM promotes it for tool calling and instruction following, not
German comprehension, and the measured gap matches.

**The benchmark is exhausted.** Four models inside four percentage points is not
enough resolution to decide anything. Continuing to run belebele would not have
produced another decision. The follow-up is a grounded end-to-end RAG benchmark on
the real corpus, not more of this one.

## Provenance caveat

**The table is a hardware mix and was not measured uniformly.**

- Qwen3.6-27B: measured on the 24 GB card, fully VRAM-resident.
- Qwen3.5-9B and Gemma-4-12B: measured on a 10 GB card, fully resident — clean
  regime, different card.
- **Qwen3-30B-A3B, 90.7 %, is the asterisk**: measured on the 10 GB card under CPU
  MoE offload and never re-measured on the target hardware.

The 30B number is probably still valid — offload changes speed, not arithmetic; the
model has no SWA or hybrid memory; and the full n = 150 ran through rather than
breaking off. But it is not cleanly comparable, and it is labelled as such rather
than quietly ranked.

## Two traps worth carrying forward

**A reasoning toggle can break the eval, or not, and you have to check which.**
Nemotron-Nano-9B-v2 enables thinking by default, which breaks single-token-logprob
evaluation. It accepts a `/no_think` system message that collapses the think block
inside the chat template, so the fast eval stays usable. The 30B model of the *same
family* ignores `/no_think` entirely — verified empirically after 300 reasoning
tokens were not enough for a trivial question. **Same family is not the same
behaviour.**

**A gated base repo does not block the evaluation.** EuroLLM's base repository is
gated and blocks the tokenizer download, but the community GGUF requant is not —
and the GGUF carries its own `tokenizer.chat_template` in its metadata, which was
byte-verified to match. Read the chat template straight out of the GGUF instead of
requesting access just to run an eval.

## Not measured

- **GLM-4.5-Air** — ~73 GB at Q4_K_M. Excluded on arithmetic against the budget of the
  time, when System A was still a single 24 GB card.
- **Hunyuan-A13B** — download aborted at 38 of 48.8 GB when system load became a
  problem. With 13B *active* parameters it would have been heavier under offload
  than the A3B models, which was the deciding factor for not retrying.
- **Nemotron-3-Nano-30B-A3B** — aborted at 9/150. Forced reasoning that `/no_think`
  could not suppress, no KV cache reuse across requests (`forcing full prompt
  re-processing`), and very slow CPU-offloaded decode combined to ~39 s per example.
  **Structurally unusable on this hardware regardless of accuracy.**

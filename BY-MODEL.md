# By model

The same results as the [use-case documents](README.md#measured), indexed the other
way round: pick a model, see everything measured about it.

**Blank means never measured, not "failed".**

## Matrix

| Model | Chat (belebele) | Coding (polyglot pass2) | Coding (SWE-bench repomap) | Other |
|---|---:|---:|---:|---|
| [Qwen3.5-9B](#chat--language-understandingmd) | **93.3 %** | | | production chat default |
| [Qwen3.6-27B](#qwen36-27b) | **93.3 %** | 23.6 % · 74.2 % @32k | **38.3 %** (31/81) | |
| [Gemma-4-12B](#gemma-4-12b) | 92.7 % | **failed** | | **vision slot** |
| Gemma-4-E4B | 91.3 % | | | |
| Qwen3-14B | 91.3 % | | | |
| Qwen3-30B-A3B-2507 | 90.7 % * | | | |
| [**Qwen2.5-Coder-32B**](#qwen25-coder-32b) | **89.3 %** | **8.4 %** | | previous coding incumbent |
| Qwen3.5-4B | 89.3 % | | | |
| [**Nanbeige4.2-3B**](#nanbeige42-3b) | **76.0 %** ‡ | | **13.8 %** (4/29) | looped transformer; 88.7 % on a different harness |
| Nemotron-Nano-9B-v2 | 88.7 % | | | |
| Qwen3-8B | 88.7 % | | | previous chat default |
| Qwen3-4B-Instruct | 88.0 % | | | |
| ERNIE-4.5-21B-A3B | 85.3 % | | | |
| Granite-4.1-8B | 84.7 % | | | |
| Qwen3.5-2B | 73.3 % | | | reference point |
| EuroLLM-9B-Instruct | 66.7 % | | | |
| DeepSeek-R1-7B | 64.0 % ⚠️ | | | partial run, n=50 |
| OLMoE | 33.3 % | | | |
| [Nemotron-3-Nano-30B-A3B](#the-nemotron-pair) | **aborted** | | | |
| Qwen3.5-27B | | **49.3 %** | | |
| ornith-35b | | 43.1 % · 61.8 % @32k | 31.0 % (9/29) | |
| Qwen3-Coder-30B-A3B | | 22.7 % | 13.6 % (11/81) | 40.5 s/case — fastest |
| [Qwen3.6-35B-A3B](#qwen36-35b-a3b-and-qwopus36-35b-a3b-v1) | | 22.7 % · 62.7 % @32k | 27.6 % (8/29) | base for Qwopus |
| [Qwopus3.6-35B-A3B-v1](#qwen36-35b-a3b-and-qwopus36-35b-a3b-v1) | | **36.0 %** @32k | 27.6 % (8/29) | fine-tune — 26.7 pts below its base |
| ornith-9b | | 20.4 % | | |
| Kimi-Linear-48B-A3B | | 12.0 % | | |
| Devstral-Small-2507 | | 6.7 % | | |
| Qwen2.5-Coder-14B | | 5.8 % | | |
| Yi-Coder-9B | | 4.0 % | | |
| Mistral-Small-3.2-24B | | 4.0 % | | |
| DeepCoder-14B | | 2.7 % | | |
| Codestral-22B | | 2.2 % | | |
| DeepSeek-Coder-V2-Lite | | 1.8 % | | 633 malformed diffs |
| Gemma-4-26B-A4B | | **failed** | | |
| OlympicCoder-32B | | **aborted** | | |
| BGE-M3 | | | | **embedding slot**, 96.25 % |
| Qwen3-VL-Embedding-8B | | | | 96.25 % — exact tie |
| Whisper large-v3 | | | | **ASR production**, 19.6 % WER |
| Qwen3-ASR-1.7B | | | | 20.3 % WER |

\* measured on System B under CPU offload — see the [provenance caveat](models/language-understanding.md#provenance-caveat).

‡ the only System A v1.4 row, and the only one where the harness changes the answer —
[below](#nanbeige42-3b).

---

## Models in more than one use case

These are the only rows where the cross-view says something the topic documents
cannot.

### Gemma-4-12B

| Use case | Result |
|---|---|
| [Chat](models/language-understanding.md) | 92.7 % — third of sixteen |
| [Coding](models/coding.md) | **failed**: >29 min per task, answers up to 26 085 tokens |
| [Vision](models/vision.md) | **chosen for the slot** — 8433 MiB, encoder confirmed on GPU under Vulkan |

Strong in two roles, unusable in the third. This single row is the evidence for the
repository's most-repeated claim: **models are good at roles, not in general.**

### Qwen3.6-27B

| Use case | Result |
|---|---|
| [Chat](models/language-understanding.md) | 93.3 % — ties the 5.3 GB default at 3× the size, so no upgrade |
| [Coding, polyglot](models/coding.md#part-1--aider-polyglot) | 23.6 %, 0 malformed diffs of 225; 74.2 % with 32k slots |
| [Coding, SWE-bench](models/coding.md#part-2--swe-bench) | **38.3 % — best measured**, and unaffected by whether the file is named |

Rejected for chat and best-in-class for coding, on the same measurements. Also the
model that exposed the SWA-offload trap: it never completed an evaluation on System B
and ran straight through on System A.

### Qwen3.6-35B-A3B and Qwopus3.6-35B-A3B-v1

| | polyglot pass2 | SWE-bench | empty patches |
|---|---:|---:|---:|
| Base | 62.7 % @32k | 8/29 | 11/29 = 37.9 % |
| Fine-tune | **36.0 %** | 8/29 | **18/29 = 62.1 %** |

Identical SWE-bench counts, 26.7 points lost on polyglot, and twice the non-answers.
See [fine-tuning](models/finetuning.md).

### Qwen2.5-Coder-32B

| Use case | Result |
|---|---|
| [Chat](models/language-understanding.md) | 89.3 % — mid-table, ahead of several general-purpose models |
| [Coding](models/coding.md) | **8.4 %**, 75 malformed diffs, 881.8 s per case |

A **coding** model that does respectably at German reading comprehension and badly at
the benchmark it was bought for. It was the production coding slot before this series
and lost it by a factor of 2.7 in quality and 22 in speed.

The chat score is included because it was measured, not because it means much:
belebele is the wrong metric for a coding model, and the number should not be read as
a recommendation.

### The Nemotron pair

| Model | Result |
|---|---|
| Nemotron-Nano-9B-v2 | 88.7 %, `/no_think` works, eval usable |
| Nemotron-3-Nano-30B-A3B | **aborted** — `/no_think` ignored, no KV cache reuse, ~39 s/example |

Same family, same vendor, opposite behaviour. **Family is not a predictor.**

### Nanbeige4.2-3B

The one model here whose score depends on which harness asks the question.

| | |
|---|---:|
| belebele, thinking **off** (the table's harness) | **76.0 %** |
| belebele, thinking **on** | **88.7 %** |
| Qwen3.5-9B, same harness, same session | 90.0 % |
| Generation, `tg128` | 131.15 t/s |
| Llama-3.2-3B for scale, `tg128` | 250.65 t/s |

**A tie with a 9B at 2.50 GiB, paid for in throughput.** 22 layers run twice: prefill
drops to 46 % of a comparable dense 3B, generation to 52 %, and it emits 2.5× the
tokens per answer. Not adopted; kept in view for a memory-constrained host.

On coding it is the opposite of a tie — **4 of 19 on pytest against 10 of 19** for
Qwen3.6-27B, and 0 of 10 on pylint where the whole field scores 0 or 1. But five of
its sixteen non-answers were the scaffold's, not the model's, and several more were
fixes rejected for
[edit-format errors](models/coding.md#a-4b-model-that-fails-on-format-not-on-diagnosis),
so that number describes the model *in our scaffold*.

Details in [language-understanding.md](models/language-understanding.md#a-looped-model-measured-twice--nanbeige42-3b)
and [coding.md](models/coding.md#a-4b-model-that-fails-on-format-not-on-diagnosis).

---

## Single-use-case models

Everything below was measured once, in one role. The number links to the document
that produced it.

### Chat — [language-understanding.md](models/language-understanding.md)

Full table there, raw data in [`data/chat_belebele.tsv`](data/chat_belebele.tsv).
Sixteen models between 33.3 % and 93.3 %, with the top seven inside four points.

### Coding — [coding.md](models/coding.md)

| Model | pass2 | malformed | s/case |
|---|---:|---:|---:|
| Qwen3.5-27B | 49.3 % | 4 | 287.5 |
| ornith-35b | 43.1 % | 5 | 91.9 |
| Qwen3-Coder-30B-A3B | 22.7 % | 4 | **40.5** |
| ornith-9b | 20.4 % | 9 | 74.9 |
| Kimi-Linear-48B-A3B | 12.0 % | 38 | 72.7 |
| Qwen2.5-Coder-32B | 8.4 % | 75 | 881.8 |
| Devstral-Small-2507 | 6.7 % | 21 | 98.7 |
| Qwen2.5-Coder-14B | 5.8 % | 108 | 62.9 |
| Yi-Coder-9B | 4.0 % | 171 | 34.0 |
| Mistral-Small-3.2-24B | 4.0 % | 54 | 79.7 |
| DeepCoder-14B | 2.7 % | 54 | 188.8 |
| Codestral-22B | 2.2 % | 43 | 140.2 |
| DeepSeek-Coder-V2-Lite | 1.8 % | **633** | 221.9 |
| Gemma-4-26B-A4B | failed | | 696 |
| OlympicCoder-32B | aborted | | 2298 |

### Embedding — [embedding.md](models/embedding.md)

| Model | Retrieval (n=80) | Dim | Size |
|---|---:|---:|---:|
| BGE-M3 | 96.25 % | 1024 | 0.9 GB |
| Qwen3-VL-Embedding-8B | 96.25 % | 4096 | 8.05 GB |

### ASR — [transcription.md](models/transcription.md)

| Model | Micro-WER | Note |
|---|---:|---|
| Whisper large-v3 | 19.6 % | production; CUDA-only — 27 × real time on the RTX 2070, 3 × on the i9-9900K |
| Qwen3-ASR-1.7B | 20.3 % | runs on llama.cpp/Vulkan; three operational blockers |

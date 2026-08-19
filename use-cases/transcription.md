# Transcription

> Parts 1 and 2 measured on **[System B](../SYSTEMS.md#system-b) v1.0**, Part 3 on
> **[System A](../SYSTEMS.md#system-a) v1.3**. ⚠️ The word error rates carry a known
> bias described below: the ground truth itself has omissions baked in, which inflates
> both models' scores by roughly the same amount.

**Three separate results: a configuration fix worth 30 points of word error rate, an
open model that matches Whisper large-v3 on the same stack as everything else, and
Whisper's own throughput on the second card.**

## Part 1 — the configuration was the problem, not the model

The corpus had been transcribed with hard-wired `beam_size=1`, model `large`, no
language hint, and no VAD setting. Measured word error rate on difficult live
audio: **37–45 %**.

That is not "some words wrong". Technical terms and proper names were hallucinated
into **fluent nonsense** — one German compound noun came out as an unrelated phrase
that reads perfectly well and means something else entirely. The RAG chat was
answering from invented text.

Validated configuration, measured as an A/B against corrected ground truth on real
clips:

```
large-v3 · beam_size=5 · language="de" · vad_filter=OFF · initial_prompt(domain terms + names)
```

**Result: ~6–14 % WER.** The single largest lever was `beam_size=5`, which halved
the error rate on its own. Model size and the language hint barely moved clean
clips but helped on hard audio.

### VAD must be off

Voice activity filtering was demonstrated to **cut real content** — whole sentences
disappeared. This matters more than it sounds, because **omissions are invisible in
spot checks.** You notice wrong words; you do not notice absent ones. For a RAG
corpus, losing content is worse than the occasional hallucination during silence.

This is also where the ground-truth lesson came from: the first A/B was biased
because the ground truth had itself been produced with VAD on, baking the omissions
in as correct. See
[METHODOLOGY.md](../METHODOLOGY.md#measure-the-ground-truth-before-you-trust-it).

### Scope

Studio-recorded material was already close to clean at `beam=1` and did **not** need
re-transcription. Only live recordings — webinars, group sessions, talks — were
worth re-running. Roughly 600 of 1300 files.

## Part 2 — Qwen3-ASR-1.7B matches Whisper

The first open ASR model that reaches Whisper large-v3 on our own domain audio.

| Model | Micro-WER |
|---|---:|
| Whisper large-v3 | 19.6 % |
| **Qwen3-ASR-1.7B (Q8_0, 2.17 GB)** | **20.3 %** |

Measured over three live clips against **Whisper-seeded ground truth** — a home
advantage for Whisper — and Qwen still won 2 of the 3 clips.

**Both numbers look worse than they are.** They sit at ~20 % rather than the 6–14 %
above because this particular ground truth was generated with VAD on and has
omissions baked in; correctly transcribed passages count as insertions. Qwen catches
sentences the VAD ground truth dropped entirely and corrects Whisper
hallucinations. Qualitatively it is production-ready.

### Why it matters beyond the score

**It runs on llama.cpp**, through `llama-mtmd-cli` under Vulkan at ~4–6 s per
63-second clip (10–15× real time) in 2.5 GB of VRAM — the same stack as chat and
embeddings. `faster-whisper`/CTranslate2 is CUDA-only and cannot use the AMD card
at all.

The stack argument stands regardless of speed: Qwen3-ASR runs on the same runtime as
everything else, on the fast card, while Whisper needs a second toolchain pinned to
the slower one. What that costs is now measured — [Part 3](#part-3--faster-whisper-on-the-second-card).

### Three operational blockers — none of them quality

1. **Long-audio bug** (llama.cpp issue #21847): audio beyond ~3–4 minutes returns an
   empty result. Needs chunking into ≤2-minute segments.
2. **No timestamps** through the mtmd CLI. Ingestion needs them for RAG chunking.
3. **No domain prompt / context biasing.** Whisper's `initial_prompt` with technical
   terms and names is a demonstrated lever — worth 30 points of WER above — and
   there is no equivalent here.

**Status: watch item with real build potential.** The next step would be a chunking
wrapper measured against *independent* ground truth rather than Whisper-seeded.
Until then Whisper stays in production.

## Part 3 — `faster-whisper` on the second card

> Measured on **[System A](../SYSTEMS.md#system-a) v1.3**, RTX 2070, 2026-08-04.

This card was called untested here for weeks. It is now measured.

`large-v3`, one 63.72 s German domain clip, `beam_size=5`, `language="de"`, no VAD:

| Device | `compute_type` | Transcribe | × real time | VRAM |
|---|---|---|---:|---:|
| **RTX 2070** | float16 | 2.29 / 2.29 / 2.42 / 2.42 s | **26.3 – 27.9 ×** | 4114 MiB |
| RTX 2070 | int8_float16 | 2.36 s | 27.0 × | — |
| i9-9900K, 16 threads | int8 | 20.15 / 20.28 / 21.32 s | 2.99 – 3.16 × | — |

**The GPU is 8.8× the CPU.** Quantising to int8 on the GPU gained nothing —
`float16` was equal or faster in every run, and loaded faster. Card at 94–96 %
utilisation, 152–169 W on the card sensor. Model load: 1.4–1.8 s.

The CPU rows were re-measured on a **verified idle machine** — no model resident on
either card — and agreed with the first run to within 5 %, so the chat model that
was live during the earlier runs did not distort them.

**No CUDA toolkit is installed on this machine**, and none was needed. CTranslate2
links against the driver; `nvidia-cublas-cu12` and `nvidia-cudnn-cu12` as pip wheels
in the venv are enough.

### What this does not say

The 8 GB card is the *slow* one here. This measures Whisper where it can run, not
Whisper against the alternatives — the Qwen3-ASR figures in Part 2 were taken under
different conditions and are **not compared** with these.

## Gotcha

**Without cuBLAS on the `LD_LIBRARY_PATH` there is no fallback and no warning.** The
model loads, decoding starts, and the first encoder call raises:

```
RuntimeError: Library libcublas.so.12 is not found or cannot be loaded
```

It fails at the encode step, not at construction — so a smoke test that only builds
the model passes.

**A hang here is more likely the model hub than the GPU.** With the weights already
cached, a run sat still for 10 minutes at 0.2 % CPU and 0 % GPU. The cause was a
revision check against the hub over IPv6, stuck in `SYN-SENT` with no timeout —
see [METHODOLOGY](../METHODOLOGY.md#a-hang-is-not-evidence-about-the-thing-you-changed).
`HF_HUB_OFFLINE=1` removes it.

## Scripts

[`scripts/asr/faster_whisper_bench.py`](../scripts/asr/faster_whisper_bench.py)

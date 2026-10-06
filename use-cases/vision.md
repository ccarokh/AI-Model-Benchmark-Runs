# Vision

**Question: can a vision model live permanently alongside the production models on
one 24 GB card, or does every image turn cost a model swap?**

**Answer: it can. Four models resident use 15.1 of 24.5 GB.**

Measured with Gemma-4-12B-it (Q4_K_M 7.12 GB + mmproj F16 0.18 GB) under Vulkan.

## Why this model

It was the only candidate with a **measured German score in our own harness** —
92.7 % on belebele_deu_Latn. The alternatives (Gemma-3-12B, Qwen3-VL-8B,
Qwen2.5-VL-7B) all fit in VRAM, so memory did not separate them, and German did.

## The vision encoder runs on the GPU under Vulkan

This was the actual gate — a vision encoder silently falling back to CPU would make
the whole thing pointless. Two independent pieces of evidence:

- Startup log: `[mtmd] adding 344.89 MiB to fit_params_target for device Vulkan0`.
  With `--no-mmproj-offload` the same line reads `for device CPU`.
- CPU time per image: **0.43 s** with offload against **0.80 s** without, while the
  text-generation control measurement stayed identical at 0.75 s in both runs.

**Wall-clock barely differs** (1.51 vs 1.42 s) — not because the encoder is running
on the CPU, but because it is cheap. The cost of an image is dominated by pushing
~284 image tokens through the 12B language model, not by encoding it.

## Memory and timing

| | |
|---|---|
| VLM alone | 8433 MiB |
| VLM + chat + embedding + reranker | **15 151 MiB of 24 560** (9409 MiB free) |
| VLM load time | 4.6 s (a 30B model: 47.7 s) |
| Image overhead on time-to-first-token | ~1.3 s |

Two images per request work, and an image stays in context across turns.

## Resolution saturates at 284 tokens

| Longest edge | Image tokens | Time |
|---|---:|---:|
| 512 px | 86 | 0.68 s |
| 1024 px | 272 | 1.54 s |
| 2048 px | 284 | 1.56 s |
| 4000 px | 284 | 1.56 s |

**Downscale to 1024 px in the frontend.** Above that there is no additional
information reaching the model — only upload cost.

## Reasoning is a trade-off, not a requirement

An empty `content` from this model is **not** caused by thinking. It is caused by
too small a `max_tokens`, which shows up as `finish_reason: length`.

With a 4000-token budget: reasoning on = 20.3 s / 1161 tokens, off = 7.8 s / 372
tokens. **Both answers were verified against the image and both were factually
correct** — the reasoning variant was more precise about colour detail. The only
hard rule is: **reasoning on requires a generous budget.**

## Two measurement traps

1. **Set `cache_prompt: false`.** llama.cpp caches the prompt *including image
   embeddings*. Without this you measure the cache: 0.17 s instead of 1.42 s.
2. **`ps pcpu` is the average since process start** and is useless as an
   instantaneous load reading. Use `/proc/<pid>/task/*/stat` deltas with a control
   measurement.

## An unplanned finding

The test frame was a screen capture of a video conference with a participant's real
name visible on screen. **No configuration — reasoning on or off, any resolution —
noticed or mentioned it.**

For a corpus of recorded webinars this cuts both ways: it is a gap in context
understanding, and it is a data protection consideration for user uploads. A model
that does not see the name will not redact it either.

## A second model in the slot: Qwen3.8-27B

The 27B dense model measured for [chat](../findings/harness-effect.md) and
[coding](coding.md) is also a vision-language model, and its projector shipped with
it. Same image, same prompt, same card.

| | Gemma-4-12B | Qwen3.8-27B |
|---|---:|---:|
| VRAM, model plus projector | **8 837 MiB** | 17 329 MiB |
| Answer length | — | 700 tokens (ceiling) |

**It costs 1.96× the memory of the incumbent** and does not free the slot for anything
else — the point of
[running four models on one card](#why-this-model) was that the vision model is small.

### It describes structure well and then invents text

Asked to describe a spice rack **and to state explicitly what it could not make out**,
it produced an accurate structural account: four wire shelves, the container shapes per
shelf, the colours, the general condition. Then the list of readable labels ran on into

> „… Öl, Essig, Senf, Ketchup, Mayonnaise, Joghurt, Quark, Frischkäse, Butter, Margarine,
> Öl, Essig, Senf, Ketchup, Mayonnaise, Joghurt, Quark, Frischkäse, Butter, Margarine"

— **the same ten generic groceries twice**, on a spice rack, none of them plausible
labels for the jars described a paragraph earlier.

**The part that matters is what its own uncertainty section said.** It listed one
limitation: that it could not be sure which spice was actually *inside* each container.
**It did not mention the labels it had just invented.** A model asked to mark its own
uncertainty marked the wrong thing — the honest-sounding caveat covered the part it got
right.

⚠️ **This is one image and one prompt, and correctness here is a judgement rather than a
measurement.** It is recorded because the failure is specific and repeatable to look at,
not because one description settles the slot.

**It mirrors the [image-generation finding](image-generation.md) from the other
direction**: generating legible text in an image failed on every model tested, and
reading text out of one produces confident fabrication. Text in images is the weak axis
in both directions.

## Video (2026-10-06)

Eight short dog clips from Wikimedia Commons, all public domain or CC BY / CC BY-SA, so clips, prompts and answers are published: [`data/video/clips.tsv`](../data/video/clips.tsv) (source, author, licence, SHA1 and the three key facts each answer is judged against), answers in [`understanding_answers.jsonl`](../data/video/understanding_answers.jsonl), timings in [`understanding_runs.tsv`](../data/video/understanding_runs.tsv), scores in [`understanding_scores.tsv`](../data/video/understanding_scores.tsv). Two ways in, same German prompt ("describe what happens, step by step"): the clip itself as a `video_url` part (llama.cpp master; it samples the frames), or eight frames sampled evenly by us. Greedy, thinking off, RX 7900 XTX.

| | Score (24 = all key facts) | Answers with an error | Time, all 8 clips | Prompt tokens, median |
|---|---:|---:|---:|---:|
| Gemma-4-12B, 8 frames | 18 | 6 | 66 s | 2 100 |
| Gemma-4-12B, video | 17 | 6 | 446 s | 27 377 |
| Qwen3.8-27B, 8 frames | 21 | 4 | 189 s | 4 689 |
| **Qwen3.8-27B, video** | **23.5** | 4 | 1 180 s | 31 453 |

**The model matters more than the way in.** Qwen3.8-27B is ahead in both modes; Gemma-4-12B misses the frisbee in both, sees one dog where the slalom has four, and reads the first-aid exercise as bite work.

**Video helps the larger model only, and where motion is the point.** Qwen with the whole clip recognises that the camera is mounted on the stick and goes underwater with it, and that the military clip is about first aid — both missed from eight frames. Gemma gains nothing from the clip and invents more (a banner text that is not there, a tunnel in the slalom).

**Video is expensive and grows with the clip.** About 1 900 prompt tokens per second of footage: the 60-second clip needs 112k tokens and 7.6 minutes on Qwen against 35 seconds from frames, and anything past ~17 seconds does not fit a 32k context at all — the first run failed there with HTTP 400 on three clips. Eight frames cost a fixed 2–5k tokens.

**Read the scores as one rater's.** All 32 answers were judged by one rater (an AI assistant, not one of the two models tested) against the key facts written before the run, not blind to model or mode; the per-answer verdicts and named errors are in the scores file so they can be checked. One prompt, eight clips, one run each.

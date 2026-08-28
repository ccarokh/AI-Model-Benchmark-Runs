# Scripts

## One way in

```
bench status                       what this machine is, measuring nothing
bench list                         the tests this checkout has
bench run                          every test, resuming where it stopped
bench run concurrency speculative  only those two
bench run --window 0-8 --memory-limit 10G --lease
                                   the way an unattended night should be run
bench build v0.2.0                 build that version and measure it
bench drift                        upstream master against the pinned build
bench capture                      record what this machine is
bench docs                         regenerate the model and system pages
```

Everything below existed before [`bench`](bench) did, and every command above hands
off to one of them — nothing is reimplemented. What the front door adds is the part
that was missing: **named options instead of remembered environment variables**, a
refusal that names the missing piece instead of an exit code from three layers down,
and `--dry-run`, so the command can be read before it runs.

**Start with `bench status`.** Every failed night in this repository began with an
assumption about the machine — that a build was the one intended, that the power
reading belonged to the card being measured, that a model was present. It prints all
of that and measures nothing:

```
machine   LLMWorkerHost
build     /opt/llama-cpp [vulkan] v0.2.0  (llama-bench, llama-server, llama-completion)
  card    Vulkan0  AMD Radeon RX 7900 XTX  24560 MiB
  card    Vulkan1  NVIDIA GeForce RTX 2070  8438 MiB
models    40
power     amd
results   .../results.tsv -- 1816 measurements on file
```

A machine only needs [`bench`](bench) and [`testbench/`](testbench/) for `status`,
`list` and `run`; the other commands say which piece is missing if it is not there.

## The harnesses themselves

These are the measurement harnesses in the form they actually ran, with host
addresses and local paths pulled up into a configuration block at the top of each
file. They are published so the numbers can be checked — not as a polished tool.

## What you need

- `llama-bench` and `llama-server` from llama.cpp on a reachable host
- passwordless SSH to that host (the scripts drive it remotely)
- for the SWE-bench runs: Docker, and the official SWE-bench harness image
- for `asr/faster_whisper_bench.py`: a Python venv with `faster-whisper`, plus
  `nvidia-cublas-cu12` and `nvidia-cudnn-cu12` if you want the GPU. See the docstring
  for the two environment variables it will not run without.
- for the `image/` scripts: `stable-diffusion.cpp`, and for the two OCR measures
  `tesseract` with `deu`+`eng` data and `hunspell` with `en_US`+`de_DE`

## What was removed

Every script originally called into a **GPU lease helper** — a small mutex that
kept unattended benchmark runs from colliding with a production service on the same
card. Those calls are commented out and marked. If you run benchmarks on a machine
that does nothing else, you do not need it. If you do not, write one before running
anything unattended.

Two related habits are worth keeping from the originals:

- **Kill processes by a PID you obtained earlier, never by pattern.** `pkill -f
  something` matches the invocation doing the killing. Every sampler in here reports
  its PID back and is stopped by that PID.
- **A step that fails does not abort the chain.** One broken repository should not
  cost the remaining hours of GPU time.
- **The card guard runs before every item, not once per run.** A model occupying 89 %
  of the card met the host's hourly health probe mid-series and took the GPU down three
  times. Even per-item checking left one gap — a check is not a lock.
- **A failed item writes no measurement.** The first version of the image runner
  recorded the crash durations as if they were timings; 13.8 s looked like a
  particularly fast run.

## Files

| Script | What it measures |
|---|---|
| `hardware/rag_turn.sh` | one real RAG turn under production flags, with power sampled during the request |
| `hardware/multigpu_sustained.sh` | layer vs tensor split under sustained load, with temperature and fan proof |
| `hardware/multigpu_ratios.sh` | split-ratio sweep separating fixed overhead from slow-card drag |
| `hardware/rocm_vs_vulkan.sh` | both backends measured in the same run |
| `hardware/reference_bench.sh` | the portable reference point, upstream flags, with guards and a power trace |
| `hardware/tokens_per_wh.sh` | tokens per watt-hour, prefill and generation priced separately, integrating over the compute window only |
| `hardware/throttle_curve_low.sh` | the throttle curve below 159 W, with interleaved stock controls and a trap that un-throttles the card on any exit |
| `hardware/context_depth.sh` | throughput and energy against cache depth, with an out-of-VRAM step reported as a result rather than swallowed |
| `coding/swebench_run.sh` | one repository × model × mode × cache type, agent run plus evaluation |
| `coding/night_chain.sh` | chains runs unattended with a deadline and a disk guard |
| `coding/abend_polyglot.sh` | one evening window of polyglot; **gives up immediately if the card is busy** rather than waiting, and resumes instead of restarting |
| `coding/orchestrate_resume.sh` | server plus one resumed session, with the card lease returned afterwards |
| `coding/run-bench-resume.sh` | the aider invocation **without** `--new`, so an existing run directory is continued |
| `chat/eval_embed_chunks.py` | retrieval against answer position inside a chunk, via an embedding server |
| `chat/eval_embed_hf.py` | the same, direct `transformers` — for models llama.cpp cannot convert |
| `chat/eval_belebele_harness.py` | belebele across three harnesses — letter logprob, free generation, and generation with reasoning |
| `asr/faster_whisper_bench.py` | one `faster-whisper` run, one device, one precision |
| `image/sd_bench.sh` | the eight image tasks across models, card guard before **each** image |
| `image/ab_one_variable.sh` | one model, one variable at a time — quantisation, steps, cfg, autoencoder |
| `image/ocr_edit_distance.py` | did the image render the *required* string? |
| `image/ocr_word_share.py` | of the text it did render, how much are real words? |

## A warning that applies to all of them

`rag_turn.sh` **terminates every `llama-server` on the host** before it starts its
own. It has a guard against doing that while a model supervisor is running, but if
you have a production service on that card, read the script before you run it.

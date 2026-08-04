# Methodology

This document exists because most of what we learned was not about models. It was
about how easy it is to produce a confident number that is wrong.

Every item below is something that actually happened here, was caught later, and
invalidated work. They are written as rules with the evidence attached.

---

## How much is noise

**A 19-instance SWE-bench run varies by at least ±2.** Same model, same mode, same
repository, three runs:

| Run | Resolved |
|---|---|
| pytest / repomap / f16 cache | 10 / 19 |
| pytest / repomap / q8_0 cache | 10 / 19 |
| pytest / repomap / q8_0, after a hardware change | 8 / 19 |

That is a spread of 10.5 percentage points from a benchmark that was not supposed
to move at all. **Differences of two or three instances mean nothing.** We only
claim a result when the gap is large (13.6 % vs 38.3 %) or when the sample is the
full 225-task polyglot set.

The same applies to intermediate results. One model sat at 95.0 % after 40 of 150
belebele examples and finished at exactly 93.3 % — dead level with the model it
was supposed to beat. **Below roughly n = 100 an intermediate score is noise, not
a preview.**

## Version the machine, not just the measurement

Both machines here run rolling-release distributions, and both gained hardware
mid-series. A result therefore belongs to a **system version** — see
[SYSTEMS.md](SYSTEMS.md#system-versions) — which increments whenever the stack or the
hardware changes. Anything else silently compares across package updates.

Three practices make that work:

- **Read the build identifier from the build, not from `--version`.** Our llama.cpp
  binary reports `version: 1 (0278d83)`, which is a build-metadata artifact. The real
  identifier, `b10098`, lives in a `.built-version` file next to it. A number that
  looks like a version is not automatically one.
- **Pin model files by hash, not by name.** Every file is recorded with its SHA256
  and its upstream repository commit. That is how a duplicate pair carrying different
  names was caught, and how two files with a lost upstream are honestly marked as
  such rather than assumed.
- **Measure the effect of a change instead of arguing about it.** The kernel moved
  from 7.1.4 to 7.1.5 mid-series. Rather than declaring it irrelevant, the same
  workload was re-run: 78.47 against 78.18. Now it is documented as irrelevant.

And where a comparison depends on the stack at all, **measure both sides in the same
session** rather than against last week's number — see the
[backend comparison](hardware/backends.md).

## Start a fresh process for every measurement

`llama-server` returns something different for each request, even with
`temperature 0`, `top_k 1`, a fixed seed, `cache_prompt: false` and a single slot.

Three identical requests, checksums of the reply:

| Configuration | Request 1 | Request 2 | Request 3 |
|---|---|---|---|
| Flash attention off, KV unquantized | `66f2e039` | `9457f796` | `0e6a8d74` |
| Flash attention on, KV unquantized | `66f2e039` | `9457f796` | `27b58080` |
| Flash attention on, KV `q8_0` | `66f2e039` | `9457f796` | `27b58080` |

**The columns are constant, the rows are not.** If the GPU computed
non-deterministically, values would scatter across the whole table. They do not —
so the cause is state carried between requests inside the server, not the hardware.

The forward pass itself is reproducible: `llama-perplexity` over a fixed text gives
`PPL = 51.1141 +/- 2.34803` in run after run, identical to the last digit.

**Rule: one fresh process per measurement.** And when hashing output, strip the
lines the tool itself appends (timing summary, loading spinner) — their length
varies with load and looks like non-determinism.

## A context size without a cache type is not a specification

On a 24 GB card, one model had a **context ceiling of 65 536 with f16 and 131 072
with q8_0**. A recommendation naming `--ctx-size 131072` without the cache type was
written down, followed three times, and produced three invalid runs.

Above the ceiling, generation collapses while prefill stays normal:

```
eval time   = 102876 ms / 1046 tokens  ->  10.17 t/s   (expected 44 t/s)
prompt eval                            ->  1200-1670 t/s (normal)
W common_fit_params: failed to fit params to free device memory
VRAM 23879 of 24560 MiB
```

**Only generation breaking is the signature of a KV cache that no longer fits and
is being read over PCIe from host RAM.** One run would have needed 17.7 hours
instead of one.

The two ceilings fail differently, and that matters:

- Above the **q8_0** ceiling the card **degrades** — 3.2 instead of 44 tok/s.
- Above the **f16** ceiling the card **dies** — `vk::Queue::submit: ErrorDeviceLost`.

So q8_0 is not merely the larger cache, it is the safer one: a misconfiguration
degrades the service instead of taking it down.

**Also: `--ctx-size` is the total across all slots.** With `--parallel 4`, a
declared 32k gives each request 8192 tokens. This silently truncated every model in
an entire benchmark series — between 15 and 292 overflows per model. The most
verbose model was cut off in 65 % of its attempts and still posted the highest
score, which means its true score is unknown and higher.

## Put every varying parameter into the output filename

A run named `<repo>_<model>_<mode>.json` overwrote its own predecessor when only
the cache type changed. The earlier result was gone, and the comparison it was
supposed to serve had to be re-run overnight.

**Every parameter that varies between runs belongs in the filename**, including
the ones you think are incidental.

## Check that the backend you measured is the one you meant

Comparing a Vulkan build against a ROCm build, both binaries were invoked with the
same `LD_LIBRARY_PATH`. The Vulkan binary loaded the ROCm build's ggml libraries.
**Both lines reported `ROCm` as their backend** and the comparison was worthless.

The tell was in the noise, before it was in the backend column: variance jumped to
±6.53 where the same measurement normally sits at ±0.12.

**Rule: read the backend column of every run, and treat a sudden change in
variance as a defect signal, not as a bad day.**

## Read the separator syntax of your own flags

`llama-bench -ts 3,1` does not mean "split 3:1". The tensor-split separator is `/`;
a comma is read as **two separate runs**, each on a single card. An entire
multi-GPU measurement was run, logged and interpreted before anyone noticed that
both rows were single-card numbers.

The file was kept, renamed to mark it invalid rather than deleted — a wrong
measurement you can point at is worth more than a gap.

## A throughput test will pass a broken card

During overclocking, at memory clock 1450 MHz the card had already reset itself
(`VRAM is lost` in the kernel log) — and prefill and generation rates still looked
completely normal.

**Instability shows up in inference as wrong tokens, not as a crash.** A test that
only reads tok/s cannot see it. The overclocking harness therefore also compares
generated text exactly and reads the kernel log after each step.

For the text comparison to be sensitive, the probe text has to be hard. The first
one was ten sentences repeated in a loop; the model memorized it after two lines,
perplexity sat at 1.006, and there was no room left for a corruption to show. It
was replaced with a 6000-word pseudo-random sequence from a fixed-seed generator —
unpredictable, but bit-identical on any host, and sitting at PPL ≈ 51 with room to
move in both directions.

## Do not evaluate SWA or hybrid models partially offloaded

Two attempts to evaluate a 27B model on a 10 GB card broke off at 20/150 and
40/150. The server log was full of:

```
forcing full prompt re-processing due to lack of cache data
(likely due to SWA or hybrid/recurrent memory)
```

Fully VRAM-resident on the 24 GB card: not a single such warning, run went straight
through. **For sliding-window-attention and Mamba-hybrid architectures, partial
offload does not just cost speed — the result never materializes.**

Related: some hybrid models cannot reuse the KV cache across requests at all. For a
benchmark loop of similarly shaped prompts, that alone can make a model
impractical regardless of its accuracy.

## Let the runtime fit the model, or fit it yourself — not both

Passing `-ngl` explicitly **disables** llama.cpp's `--fit` auto-balancing. On a
CPU-offloaded MoE this meant 3.7 GB of a 10 GB card in use instead of 8.7 GB.
`--cpu-moe` is worse: it dumps *all* experts to CPU even when most would fit.

Two more offload lessons from the same series:

- **Batch size dominates CPU-offloaded MoE prefill.** The convention inherited from
  small dense models (`--batch-size 32 --ubatch-size 16`) throttled prefill to
  7–13 tok/s. At `512/512` the same hardware did ~226 tok/s. An 18× difference,
  reproduced on two models.
- **`--no-mmap` matters when anything else is touching the disk.** Concurrent
  downloads evict mmap'd model pages from the page cache and every token hits the
  disk. The effect was large enough to be unmistakable — roughly 1.8 to 10 tok/s on
  one model from this flag alone — but it was observed during a run that was later
  aborted, on a machine simultaneously out of RAM. **Treat the direction as solid
  and the numbers as anecdote.**

## Reasoning models need to be handled explicitly

Two distinct traps:

- **Thinking breaks single-token-logprob evaluation.** Some models accept a
  `/no_think` system message that collapses the think block inside the chat
  template, keeping the fast eval usable. Others ignore it — verify empirically
  rather than assuming, because a model that silently keeps reasoning will look
  catastrophically slow for the wrong reason.
- **An empty reply is usually a budget problem, not a thinking problem.** Empty
  `content` with `finish_reason: length` means the reasoning consumed the token
  budget. Reasoning on requires a generous `max_tokens`, not a different model.

## Measure the ground truth before you trust it

The first transcription A/B was biased because the ground truth had been produced
with a voice-activity filter that silently dropped whole sentences. Those omissions
were baked in as "correct", so a configuration that transcribed the missing
sentences correctly was penalized for "insertions".

**Build ground truth with the configuration that drops the least, and check for
what is missing, not only for what is wrong.** Omissions are invisible in spot
checks — you see wrong words, you do not see absent ones.

## Measure the whole machine when comparing operating modes

GPU sensors are not comparable across vendors (`power1_average` against
`nvidia-smi`), and `power1_average` only reads the graphics chip — not the board,
not power supply losses. A wall socket meter measured a 46 W saving where the card
sensor showed 28 W.

The socket meter is slow, so it is only meaningful under sustained load. Short
benchmark bursts do not register.

One more, from profiling a vision encoder: **`ps pcpu` is the average since process
start**, useless as an instantaneous load reading. Use `/proc/<pid>/task/*/stat`
deltas, and always run a control measurement alongside.

## A hang is not evidence about the thing you changed

A `faster-whisper` run on a freshly added GPU sat still for ten minutes. The obvious
reading — a card, a driver or a CUDA library problem — was wrong twice, and the
second time cost a round of package installs that changed nothing.

What the process actually looked like:

```
State: S (sleeping)          0.2 % CPU, 85 MiB RSS
GPU:   1 MiB, 0 %
ss:    SYN-SENT  [2003:...]:45662 -> [2600:9000:...]:443
```

**85 MiB of RSS means the model was never loaded.** It had not reached the GPU at
all. The socket was an outbound revision check to the model hub over IPv6, on a host
where that route is black-holed — a TCP handshake with no timeout behind it. The
weights were already cached; the network call was pure overhead. One environment
variable removed it.

Three things worth taking from it:

- **Read the process state before changing anything.** `/proc/<pid>/status`, the open
  sockets, the resident size and the GPU counters together said "network, before the
  model" in under a minute. Two installs were done before anyone looked.
- **Resident size tells you how far it got.** A stalled run holding tens of megabytes
  has not touched the model; one holding gigabytes has.
- **Cached weights do not mean offline.** Libraries that resolve a model by name will
  still call home to check a revision unless told not to.

## Watch load outside the target GPU

An evaluation was aborted with load average at 45 and RAM plus swap nearly
exhausted — caused by parallel model downloads running alongside a CPU-heavy
evaluation, not by the evaluation itself. Downloads coexist fine with a light dense
model, and not at all with a CPU-offloaded MoE.

**No downloads, hashing or builds on a benchmark host while a run is in progress.**

**If the host also serves something, stop that service and verify the card is empty
before you measure** — not "should be idle", but VRAM and utilisation read back at
zero. This matters most for reference runs and anything drawing from a socket meter,
where another process on the same card contaminates the number without changing
anything you would notice in the output.

## Count the non-answers separately

In agentic coding benchmarks, "did not solve it" and "produced no patch at all" are
different failure modes with different causes. One model produced **no patch in
49.4 % of 81 runs** — a number that is invisible if you only report the resolved
count, and which turned out to point at file localization rather than at code
quality. See [coding.md](models/coding.md).

## Prove the harness can succeed before blaming the model

Every SWE-bench repository here was first run with the **gold patch** — the known
correct fix — to establish what the harness can resolve at all:

| Repository | Gold patch resolves |
|---|---|
| pytest | 19 / 19 |
| pylint | 10 / 10 |
| requests | 5 / 8 |

Three instances in `requests` are unwinnable in this setup regardless of model.
Without that calibration run, they would have been counted against every candidate.

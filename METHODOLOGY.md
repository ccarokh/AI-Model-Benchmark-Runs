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

The same failure returned in a second form when a newer llama.cpp was installed into
its own prefix to run an architecture the production build predates. The new binary
resolved **all eight** of its `libllama`/`libggml` libraries to the *old* prefix,
because the `ld.so` cache points there. It was only caught because the old libraries
did not know the architecture and said so. **With an architecture both builds
support, the run would have completed and reported the wrong build's numbers.**

**A second install prefix is not selected by calling its binary.** Set
`LD_LIBRARY_PATH` and count how many libraries actually resolve into it before
trusting a single measurement from it.

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

## Vary one thing, or you are comparing setups, not models

Five image models were run, each assembled from its own parts — its own autoencoder,
its own text encoders, its own quantisation. **Every difference in that assembly came
out looking like a difference between models.** Three separate "model failures" here
were the harness:

| Reported as | Actually |
|---|---|
| "this model is unusable, every image is a dot grid" | it was decoded with **another model's autoencoder** |
| "this model crashes on every task" | a 15-byte HTML error page downloaded as a text encoder |
| "this model renders fur as a grid" | **survived the A/B** — genuinely the model |

The last row is the point. An A/B is not only for catching your own mistakes; it is
what lets a real defect be *asserted*. Four variables were changed one at a time —
quantisation, step count, guidance scale, autoencoder — and the defect stayed. Without
that, the claim would have been the same sentence with nothing behind it.

**Two habits follow.** Where a project ships an all-in-one checkpoint, use it rather
than assembling the parts yourself — that alone fixed one of the three above. And
before attributing anything to a model, change one variable and look again.

**Also: a per-model operating point is not a comparison.** Those five ran at 4 to 28
steps, each on its usual setting. Defensible per model, but it makes the timing column
a comparison of configurations. One sweep showed the "4.4× slower" headline was the
choice of 20 steps: at 8 steps the same model is 2.2× slower.

## One sample is not a rate

An image model was reported here as the only one able to render a required German
string — measured once, on one seed. Repeated across five seeds:

| | Exact hits at n = 1 | at n = 5 | at n = 15 |
|---|---|---|---|
| the "only" model | 1 / 1 | 2 / 5 | **6 / 15 = 40 %** |
| the one said to fail | 0 / 1 | 1 / 5 | **2 / 15 = 13 %** |

**The claim was rewritten twice, and the error pointed a different way each time.** At
n = 1 one model looked capable and the other incapable. At n = 5 they looked close. At
n = 15 the gap is threefold and neither is reliable. Three of the five models never hit
the string in fifteen attempts — *that* floor held from the first measurement on.

**Watch which direction more data moves a number.** A result that keeps moving has not
converged; a result that holds while n grows is the one worth quoting.

The same sweep exposed a broken metric. "Share of rendered text that is a real word"
was reported as 50 % and 39 % for two models — resting on 6 and 72 tokens. Across seeds
the same measure returns 100 % from a *single* recognised token. **A ratio without its
denominator is not a measurement**, and one that can be computed from n = 1 needs a
floor before it is quoted.

Where output is sampled rather than computed, **n = 1 is an anecdote wearing a number**.

## Guard the harness as well as the card

Every measurement script here waits for the GPU to be empty before it starts, so a
foreign process cannot land in the middle of a run. **None of them guarded against their
own child hanging.**

A determinism check invoked `llama-cli` in a background run. Without a terminal it fell
into conversation mode and waited for input that was never going to arrive. It held the
card for **seven hours** before anyone looked. The card guard was working perfectly the
whole time — it protects against other people's load, not against yours.

Three cheap habits, all of which this cost:

- **`< /dev/null` on every child that can read stdin.** An interactive prompt in a
  background job is an indefinite hang, not an error.
- **`timeout` on every child.** Pick a number a few times the expected runtime. It costs
  nothing when the run is healthy.
- **Check for output, not just for a live process.** `ps` showed the script running and
  the GPU busy, which is exactly what a healthy run looks like. What distinguished it was
  that the results file had not grown.

**A hang and a long run are indistinguishable from the outside.** Make the harness prove
it is progressing.

## Some settings can only be undone with a screwdriver

Scripts here restore whatever they changed, with the reset wired to a `trap` so it fires
on a crash or a kill as well as a clean exit. That is enough for anything the kernel
survives. **It is not enough for everything.**

Lowering the memory clock on an RX 7900 XTX took the card off the PCIe bus. The kernel
went down with it, so the trap never ran — and it would not have helped, because after
the reboot there was no card left to write the reset to. A PCI rescan and a second warm
reboot both failed. Only cutting mains power brought it back.

**Before changing a setting, ask what undoes it if the machine stops responding
mid-change.** If the honest answer is "physical access", that experiment needs someone in
the room, or it does not run. The same knob in the other direction — memory clock *up* —
was recoverable and had already been measured safely, which is exactly what made the
downward step look routine.

**Symmetry of a parameter is not symmetry of its failure mode.**

## The measurement window must contain only the work you are counting

A power sampler was started before `llama-bench` and stopped after it, and mean watts
were divided into the token count. The result looked like a discovery: two
mixture-of-experts models drew **112–116 W** where every dense model drew 250–265 W.
An architecture that runs cool — plausible, quotable, and wrong.

The sampler was also running while the model loaded. Restricting the integration to the
compute window alone:

| | Whole window | Compute only | Share of window that was compute |
|---|---:|---:|---:|
| Qwen3-30B-A3B (17 GiB) | 116 W | **278 W** | 40 % |
| Llama-3.2-3B (1.9 GiB) | 250 W | **267 W** | 92 % |

**Under load every model draws 255–290 W.** The apparent effect was ~28 s of loading a
17 GB file with the card idle, averaged into the mean — and because load time scales
with model size, the artifact was *systematically* biased toward exactly the models the
conclusion was about. It did not look like noise. It looked like a trend.

Two rules come out of this:

- **Integrate over the work, not over the wrapper.** Any setup, load, warmup or teardown
  inside the window silently rewrites the result.
- **A per-model artifact will impersonate a per-model finding.** Ask what else varies
  with the axis you are plotting against. Here, file size drove both the conclusion and
  the error.

The same run carried a second, duller error: the token count read a `reps` key that
`llama-bench` does not emit, so five repetitions were counted as one. That one was
harmless — it hit every row by the same factor and cancelled in every comparison.
**The dangerous mistake is not the one that scales everything; it is the one that scales
with the variable under test.**

## A single run is not a duration

Forty images from one model, one after another, same size and settings. **One took
809.6 s where its neighbour took 75.8 s** — the same script, the same card, minutes
apart. The GPU sat at 4 % utilisation throughout the slow one. No error, no log entry,
cause never identified.

A mean over that set would have been wrong by a third, and nothing in the output would
have shown it. **Report the spread, or report n.** The outlier was only noticed
because someone was watching the run rather than collecting the total afterwards.

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

**Check before every item, not once per run — and know that a check is not a lock.**
A model occupying 89 % of the card was measured while the host's hourly health probe
took 6100 MiB; the card went to `ErrorOutOfDeviceMemory` three times in a row
(`ring comp_1.1.0 timeout` in the kernel log). The guard was then moved to run before
each individual image, which caught the next collision — but one image still started
in the gap between the check passing and the probe arriving. **Where a lease mechanism
exists, take the lease; polling only narrows the window.**

## Do not judge from a stale copy

Two images were regenerated and replaced under the same filenames. The rating tool
served them with `Cache-Control: max-age=86400`, so the browser kept handing back the
old ones — and both were rated a second time as broken, hours after the fix had
landed. Two verdicts about files that no longer existed.

**Anything a human judges from must be validated, not cached by name.** An ETag from
the file's own modification time costs nothing and makes the failure impossible. The
same applies to any artefact reviewed after being regenerated: the version under
review has to be the version on disk.

## Count the non-answers separately

In agentic coding benchmarks, "did not solve it" and "produced no patch at all" are
different failure modes with different causes. One model produced **no patch in
49.4 % of 81 runs** — a number that is invisible if you only report the resolved
count, and which turned out to point at file localization rather than at code
quality. See [coding.md](use-cases/coding.md).

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

**But a gold-patch run validates the evaluator, not the agent.** It applies a known
patch and runs the tests — it never starts the agent, so nothing that breaks *inside*
the agent can show up in it. One `pylint` instance produced an empty patch in **all
six runs ever made here**, across every model and cache type, because the agent
crashes during its repository scan on a dependency conflict. Gold-patch calibration
scored that same instance as winnable, and did so correctly:
[the details](use-cases/coding.md#-one-pylint-instance-is-broken-for-every-model).

**Two calibrations are needed, not one.** The gold patch proves the evaluation can
pass. Only a per-instance look at the agent logs proves the agent can *run* — and
"empty patch" is the symptom that should trigger it, which is one more reason to
[count non-answers separately](#count-the-non-answers-separately).

## Record what it cost to run the model, not only how it scored

Every table here reports what a model achieved. None of them reported what it took to
get it running — and for someone reproducing this, that is often the part that decides
whether they try at all.

The friction is real and uneven:

| Model | Shipped as | Blockers |
|---|---|---|
| Qwen3.8-27B | GGUF plus vision projector | none — ran first attempt |
| Mankei-1B-Chat | GGUF, six quantisation levels | none |
| Mankei-326M-Embedder | **safetensors only** | no GGUF published; had to be converted |
| Nanbeige-4.2-3B | GGUF | **two** — see below |
| Gemma-4-12B | GGUF plus projector | runtime had to be new enough for `--mmproj` |

Nanbeige is the cautionary case. Its tokenizer demands `trust_remote_code` and writes
that prompt **to stdout**, where it corrupted the JSON line the harness was parsing —
three complete 150-question runs produced correct results that were then thrown away by
the collector. Separately, a second llama.cpp install resolved its libraries to the
*first* prefix until `LD_LIBRARY_PATH` was set explicitly.

**Two models with identical scores are not equally usable.** A publisher who ships a
GGUF ladder has done work that a publisher shipping raw safetensors has left to you, and
that difference belongs next to the score rather than in someone's memory.

Recorded per model in [`data/integration_cost.tsv`](data/integration_cost.tsv).

## A benchmark that blocks the card for three days is not a benchmark you can afford

A dense 27B needed 19 minutes per aider-polyglot task against 1.5 for a 35B MoE —
70 hours for the full 225. Run in one block it held the only GPU the whole time, and
**three other measurements were skipped three nights in a row**: a vision test, a
throttle curve, and a chunk-size sweep. Each of those was worth more than the second
decimal place of one pass rate.

Two things came out of it.

**Report the partial result immediately, labelled as partial.** `61_of_225` with a
measured 18.5 min/task is an honest row. Waiting for completeness meant publishing
nothing for three days while the conclusion — *too slow for anyone waiting on it, and
here is the throughput arithmetic that explains it* — was already supported.

**But state which use the number rules out, and which it does not.** 19 minutes per task
disqualifies interactive and agentic work, where a person or a loop waits on each turn.
It says nothing about batch use — hand over a task list, collect results in the morning —
where 225 tasks over a weekend is unremarkable. **A latency measurement is not a verdict
on a model, only on a mode of use**, and this repository organises everything by slot
precisely so that distinction survives.

**A long run should yield the card, not wait for it.** The chains that failed here
waited politely for hours and then skipped their own steps — and worse, **the skip wrote
nothing to the log.** The vision step vanished silently because the guard was
`if free; then ... fi` with no `else`. The replacement runs in an evening window, checks
once whether the card is free, and **gives up immediately if it is not.** It resumes
where it stopped rather than restarting, which meant removing a hardcoded `--new` from
the harness — with it, every window would have begun again at zero.

**A guard that skips must say so.** Silence from a guard is indistinguishable from
success.

## Ruling something out is a claim, and needs the same evidence as ruling it in

Three times in one week, work here was nearly closed off by a sentence that sounded
like a finding and rested on nothing:

| Claim written | What it rested on | What measurement showed |
|---|---|---|
| "256-token embedder, unusable for our 3 000-char chunks" | the model card | the config allows 2 048; at that length it scores 0.2875 instead of 0.0 |
| "the thinking switch only dampens, it does not disable" | a token median of 109 | 3 completion tokens and an empty reasoning field — it disables completely |
| "vLLM is not an option for us" | a check run days earlier whose result was never written down | the whole investigation was repeated from scratch — see the next entry |

Each was caught by someone asking *why not*, and each would have removed a real avenue.
The second one had already been adopted as shared knowledge before it was tested.

**The tell is the sentence shape, not the topic.** "That is settled", "not available to
us", "no point measuring" — a negative conclusion feels like caution, so it gets waved
through where a positive claim would be challenged. It is the same claim with a minus
sign, and it costs more, because a wrong positive gets corrected by the next measurement
while a wrong negative deletes the measurement that would have corrected it.

**Rule: before writing a sentence that closes an option, name the measurement behind
it.** If there is none, the honest sentence is *unmeasured* — and unmeasured things go
on the open list, not into the bin.

## A negative result that is not written down will be re-derived, badly

The vLLM row above is not quite an example of the rule above it. That option **had** been
examined, days earlier, and the result went nowhere: not into this repository, not into
its open list, not into any note. So the same ground was covered a second time — and the
second pass reached the opposite conclusion by assumption, which is worse than either
answer alone.

**Negative results are the ones most likely to go unrecorded**, because there is no
artefact at the end: nothing was installed, no number was produced, and it feels like
the afternoon simply did not happen. But *"we looked at this and here is why it was set
aside"* is exactly what stops the next person — or the same person a week later — from
spending the afternoon again.

This repository has an [open list](README.md#open) and a
[Failed table](README.md#failed) for that purpose. **The rule is that an evaluation ends
in a written line, whichever way it went**, and the line names what was checked, what
was found, and what would change the answer.

## A benchmark that decides a deployment has to test the deployed configuration

These measurements are not an exercise. **They are the basis on which a build is chosen
for production**, and that raises two requirements a throughput comparison does not meet
on its own.

**Measure the build production actually runs.** Two llama.cpp builds live on this host —
`b10098` behind the production supervisor and `b10273` behind every benchmark here, 175
apart. A comparison between the benchmark build and current upstream answers a question
nobody asked; the decision is *should the production build be replaced*, and the
production build has to be in the table.

**Measure the flags production actually uses.** `llama-bench` runs without KV
quantisation, without `--parallel` and at depth 0. Under production flags one 9B model
[collapsed by a factor of 6.8](hardware/power.md#the-load-case-that-counts--under-production-flags),
and [depth alone](findings/context-depth.md) moves prefill by 30–75 %. A recommendation
resting on synthetic flags is a recommendation about a configuration nobody runs.

Three things gate a promotion, and all three are cheap:

| | Why it is not optional |
|---|---|
| **Output hash unchanged** | a build that got faster and answers differently did not get faster at the same thing |
| **No kernel messages** | [a throughput test will pass a card that has already reset itself](#a-throughput-test-will-pass-a-broken-card) |
| **Production-shaped numbers no worse** | the synthetic ones can improve while the real case regresses |

**The measurement produces the grounds; the operator makes the call.** What the harness
must not do is present a single throughput figure as though it settled the question.

## Suspect your own setup before you blame the tool

vLLM served a GGUF file on ROCm and answered. Asked for a tool call, it returned

```
content:    "[TOOL_CALLS]read_file[ARGS]{\"pfad\": \"/etc/hostname\"}"
tool_calls: []
```

The call is there, in the response text, and the structured field is empty. The
tempting conclusion — *vLLM cannot do tool calls with this model* — would have been
published as a property of the runtime.

It is a property of our command line. vLLM requires the call style to be **named**
(`--tool-call-parser`), one parser per model family, and ships 29 of them. llama.cpp
derives the same thing from the template inside the GGUF, so the flag never came up.
We had picked one parser, on one attempt, and it did not match this model's format.

**The rule: a negative result about someone else's tool is only a result once our own
side is cleanly excluded.** Everything we control — flags, parser, template, weights,
version — has to be ruled out first. Until then the finding is "we could not get it to
work", which is a statement about us, and it belongs in the log rather than in a table.

The cost of getting this wrong is asymmetric. A wrong positive gets corrected the next
time someone runs the thing. A wrong negative closes a door: nobody re-tests what the
table already says is impossible.

## A measurement that does not check its own preconditions silently agrees

The drift check compares a fresh llama.cpp build against the pinned one and only
recommends a switch if the numbers hold up. On the night of 21.08. it ran for 122
minutes and reported all three criteria met: output hash identical, no kernel messages,
production-shaped numbers not worse.

Both builds had measured **3.3 tokens/s where the established figure is 103**.

The card was contended the whole time. The production chat supervisor tried to load a
model every hour and was refused — *"needs ~7150MiB, only ~3776MiB free"* — which is the
only reason the run got any GPU at all. And because **both** sides were crippled equally,
"not worse" was true. A wrong build would have been waved through on numbers that were
off by a factor of thirty.

The host had a coordination mechanism for exactly this: the runtime exposes a GPU lease
(`POST /_manager/lease`), refuses interactive requests while it is held, and was
configured with its own secret. **Nothing ever requested it.** What looked like
cooperation was the accident of a full card.

Two rules follow, and the second is the general one:

**A benchmark takes the lease, or it does not run.** Not "waits politely", not "checks
VRAM first" — those are workarounds for a mechanism that already exists. The window is
re-checked before every step, and losing the lease ends the chain instead of continuing.

**Comparing two runs to each other is not a check that either is valid.** A regression
test that only asks "is B worse than A" passes when A and B are equally broken. Some
absolute anchor has to be in the comparison — here, the recorded reference figure from a
healthy session — or the test can only detect *differences*, never *breakage*.

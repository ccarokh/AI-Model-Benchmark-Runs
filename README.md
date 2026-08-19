# AI Model Benchmark Runs

**What can you actually run on local consumer hardware, and what can't you?**
Measured, not estimated. Two desktop machines, no cloud.

Each use case is a **slot** a model has to earn. RAG is one of them, not the subject.

---

Three ways in:

- **[by use case](#measured)** below — each is a slot a model has to earn
- **[by model](BY-MODEL.md)** — 51 files under [`models/`](models/), one per model,
  generated from [`data/`](data/)
- **[findings/](findings/)** — the cross-cutting results that belong to no single model:
  [the harness](findings/harness-effect.md), [context depth](findings/context-depth.md),
  [chunk position](findings/chunk-position.md),
  [abliteration](findings/abliteration.md)

## Measured

| Use case | Document | Result |
|---|---|---|
| RAG — German chat | [Language understanding](use-cases/language-understanding.md) | 16 models; the 5.3 GB default was never beaten, not even by a model 3× its size — **now beaten by 4 points by [a model measured only for code](findings/harness-effect.md#part-2--eight-models-that-had-never-been-measured-on-german)** |
| **RAG — long context** | **[Context depth](findings/context-depth.md)** | **The ranking inverts with a full cache. The linear-attention model, whose whole promise is long context, is the worst of all at 32k — 39× slower than a 35B MoE** |
| **RAG — the harness itself** | **[Harness effect](findings/harness-effect.md)** | **How you ask is worth 1.3–2.7 points for ordinary models and 70 for two reasoning models. 8 more models measured; new best German reader at 0.9733** |
| RAG — retrieval | [Embedding](use-cases/embedding.md) | A 9× larger model tied BGE-M3 exactly |
| **RAG — chunk position and size** | **[Chunk position](findings/chunk-position.md)** | **60 % when the answer is at the start of a 3 000-char chunk, 5 % at the end. At 400 chars the effect is gone; a reranker recovers 0.05 → 0.53. A defect in our own running system** |
| Coding | [Coding](use-cases/coding.md) | 18 models; the ranking inverted once the harness stopped naming the file |
| ASR — speech to text | [Transcription](use-cases/transcription.md) | Qwen3-ASR-1.7B matches Whisper large-v3; a config fix was worth 30 points of WER; Whisper runs at 27× real time on an 8 GB card with no CUDA toolkit installed |
| VLM — image input | [Vision](use-cases/vision.md) | Runs permanently alongside three other models: 15.1 of 24.5 GB. A 27B alternative costs 1.96× the memory and **invents label text while reporting itself as certain** |
| Image generation | [Image generation](use-cases/image-generation.md) | 5 models; the three tasks that carry a statement rather than a motif fail on every one |
| Fine-tuning | [Fine-tuning](use-cases/finetuning.md) | A third-party fine-tune lost 26.7 points against its own base and doubled the non-answers |
| **Abliteration** | **[Abliteration](findings/abliteration.md)** | **Costs nothing measurable on eight axes — but generates 37 % fewer tokens for the same answers** |
| Power draw | [Power](hardware/power.md) | 7-point curve from 276 W down to 159 W — at half the core clock, generation still delivers 85 %. Idle costs more per year than throttling saves |
| Second GPU | [Multi-GPU](hardware/multi-gpu.md) | Capacity, not speed: ~62 % of single-card generation. The bus sat at 0–5 % and doubling its width changed nothing |
| Backend | [Backends](hardware/backends.md) | Vulkan stays: ROCm is +11 % prefill, −11 % generation |
| **Foreign benchmarks** | **[foreign/](foreign/)** | Generation scales almost exactly with memory bandwidth. Ollama is llama.cpp underneath — and 25 % slower on identical hardware |
| **Method** | **[METHODOLOGY.md](METHODOLOGY.md)** | **The measurement mistakes, with the evidence that exposed each one** |

## Failed

Ran, and did not work. Never-attempted models are under [open](#open) instead.

| Model | Where | Reason |
|---|---|---|
| Nemotron-3-Nano-30B-A3B | chat, aborted 9/150 | forced reasoning `/no_think` could not suppress, no KV cache reuse across requests, and very slow offloaded decode — ~39 s per example |
| OlympicCoder-32B | coding, aborted 2/225 | ~38 min per task; 6 days extrapolated |
| Gemma-4-26B-A4B / 12B | coding | 11.6 and >29 min per task; answers up to 26 085 tokens — [one harness only](use-cases/coding.md#three-findings-that-outlive-the-model-list) |
| Qwen3.8-27B | coding, **partial — 61 and 38 of 225** | **18.5 and 19.0 min per task against 1.5 for a 35B MoE** — dense, not reasoning: the thinking switch demonstrably works and changed nothing. ⚠️ **This rules out interactive and agentic use, where someone waits. It says nothing about batch use** — hand it a task, collect the result in the morning — which is untested. Remaining tasks run in idle evening windows |

## Size ceiling

**Measured: ~24 GB, fully resident on the fast card, at reference speed.** That is
the largest model actually run here.

Everything above that is untested — see [open](#open).

## Open

| Item | Status |
|---|---|
| Models above ~24 GB — incl. GLM-4.5-Air, Hunyuan-A13B | never run |
| Image generation across several seeds — every figure there is one sample | planned |
| TTS | planned |
| Home Assistant voice pipeline | planned |
| Energy efficiency — Wh per completed task (tokens per Wh is [done](hardware/power.md#tokens-per-watt-hour-per-phase)) | planned |
| Varying the harness — remaining 10 models of the chat table ([6 done](findings/harness-effect.md)) | running |
| Re-running the System B results on System A | planned |
| Below 84.5 W on the throttle curve — [down to 84.5 W is done](hardware/power.md#there-is-an-optimum-and-it-sits-at-1200-mhz), efficiency worsens monotonically past the 1 200 MHz optimum | low priority |
| **Batch coding: a slow model given a task list overnight** — the latency numbers rule out interactive use and say nothing about this | planned |
| **Three-way runtime comparison: Ollama vs llama.cpp vs vLLM** on one card and one model — [two of the three are done](models/../data/ollama_vs_llamacpp.tsv) | planned |
| **DSpark speculative decoding** — merged into llama.cpp, MIT, with draft checkpoints for Qwen and Gemma; reported 1.6–2.7× decode with unchanged output. Untested here | planned |
| **Plain speculative decoding** (`--model-draft`) — supported by our runtime today and never measured | planned |
| MTP: llama.cpp discards Qwen's `nextn` tensors (`unused tensor blk.64.nextn.*`); vLLM on ROCm needs a container runtime on the GPU host | blocked |
| Lowering the memory clock | [abandoned](hardware/power.md#the-memory-clock-is-not-a-knob-you-can-turn-down) — took the card off the bus |

## Data and scripts

**[`data/`](data/)** — the cleaned result tables as TSV, aborted and failed runs
included. Every number in the documents traces back here.

**[`scripts/`](scripts/)** — the harnesses as they ran, hosts and paths lifted into a
config block. Bash, driving `llama-bench`/`llama-server` over SSH.

**Licences are recorded per model where they constrain use** — see
[image generation](use-cases/image-generation.md#what-a-machine-measured), the first
series here where a model's licence, not its score, decides whether it can be used.

## Authorship

**Most of this was done by Claude (Anthropic)** — designing the measurements, writing
the harness scripts, running them, aggregating the results, and writing every word
here. The operator supplied the hardware and the direction, and made the decisions.

**No full human review has happened yet.** Corrections so far came from the operator
spot-checking during the work — and there were several, including one result that was
published and then withdrawn.

Numbers are traceable to [`data/`](data/). The reasoning around them is not yet
audited. Where something was not measured, it says so.

## Not a leaderboard

Every number answers one question on one set of hardware. Models rejected here may be
excellent elsewhere — several lost on speed or memory fit, not quality.

**Almost nothing here is comparable with anyone else's numbers.** The exception is
[foreign benchmarks](foreign/) — other people's benchmarks, run with their model and
flags, so this machine can sit in a shared table.

That directory also documents what we did *not* run of theirs, and why. A first
attempt was published and withdrawn: the same command that measures one GPU on a
single-GPU host silently spread the model across both of ours. **Identical flags do
not guarantee an identical measurement.**

## What should we measure next?

**The hardware is here, it is idle a lot, and the runs are cheap.** If there is a
question you have wanted answered on real consumer hardware and never had a box to
answer it on — open an issue.

Things that would genuinely help:

- **A model you think should have been in one of these tables.** If it fits in 24 GB
  and runs on llama.cpp, it can go in a night chain.
- **A benchmark or harness we are not using.** The
  [harness variable](use-cases/coding.md) is the biggest unmeasured thing here — a
  second harness on the same models would be worth more than another model on the
  same harness.
- **A configuration claim you want tested.** Half the useful findings in here started
  as "everyone says X" and turned out to be wrong on this hardware — PCIe bottlenecks,
  NVLink, core clocks, tensor split.
- **A contradiction.** If a number here disagrees with your machine, that is
  interesting on its own. The [raw data](data/) and [scripts](scripts/) are published
  so it can be checked rather than argued about.

The [open list](#open) is what is already queued. Anything else is fair game.

## License

Text and measurements CC BY 4.0 · scripts MIT · see [LICENSE](LICENSE)

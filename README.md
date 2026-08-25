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
| **Drift against current upstream llama.cpp** — the measurement build is 215 behind master, and there is no distribution package to carry updates in. [Standing check](systems/llama-cpp-builds.md#checking-for-drift-against-current-upstream): build current alongside the pinned one, run the reference workload on both in the same session | **recurring** |
| **Agility game — one task, every coding model, human-judged** — graphics are drawn in code, the harness is agentic, and a person plays every result. [How the task got there](use-cases/agility-game.md) | **built, not yet run** |
| **The same task with one repair turn** — the model sees its own console errors and may fix them. The difference is what a second turn is worth | planned |
| **A second agent harness on the same task** — the harness is the biggest unmeasured variable here, and OpenCode is currently the only one measured | planned |
| **LM Studio Bionic as that second harness** — an agent app for open models, released 16.07.2026. It would be the ideal comparison: same model, same task, different agent | **cannot be tested here** — preview is macOS (Apple Silicon) and Windows only, no Linux build, and it is a GUI app with no scriptable interface for unattended night runs. Our harness host is Linux |
| **Context ceilings on the 24 GB card** — [measured on 12 GB](findings/context-ceiling.md), where a 14B holds 16 384 tokens and a 9B holds 204 800. The same bisection has never been run on System A | **next** |
| **GPQA Diamond** — 198 hard science questions, multiple choice. Runs on the belebele machinery we already have, and the numbers sit next to published ones | **next** |
| **IFBench** (Allen AI) — ~300 single-turn and 1 300 multi-turn prompts over 58 constraints, each with a verification function. Scored automatically, no human in the loop | **next** |
| **JobBench** — real tasks from 13 professions, chosen by 1 500+ practitioners as the work they would hand off. Weighted binary rubrics, one working directory per task, and **it drives OpenCode** — the same agent this repository already runs. Agent side is fully local; the judge is any OpenAI-compatible endpoint (grok-4.3 by default), so the judge becomes a recorded column like `quant`. The `easy` split run twice, local judge against a foreign one, prices what the judge is worth | **next — best fit on the list** |
| **Cloud models against local ones in the same harness** — the obvious comparison, and it cannot be built here. Putting a cloud model into OpenCode needs an API key; putting a local model into Claude Code is [explicitly unsupported](https://code.claude.com/docs/en/llm-gateway) ("doesn't support routing Claude Code to non-Claude models through any gateway"). A translating proxy would work technically and defeat the purpose: a layer that reshapes requests makes the harness *less* identical, not more | **not possible here** — cloud runs are kept as their own class (Claude Code), local runs as another (OpenCode), and the two are never placed in one table |
| **openbench** — same model, different wrapper: codex, opencode, cursor, devin. Literally the harness axis this repository calls its biggest unmeasured variable, already built by someone else | planned |
| **LiveCodeBench v6** — coding problems in time windows against contamination. Needs an execution sandbox, which now exists | planned |
| **Terminal-Bench** — agentic terminal tasks in containers. Setup failed here once, before there was a container runtime on the harness host | **retry** |
| **SWE-bench Verified**, then **Pro** — the SWE-Agent scaffold, one container image per instance. Qwen3-Coder-Next reports 70.6 % Verified and 44.3 % Pro with it. Expensive in disk and hours; Verified first | planned |
| **DeepSWE-Preview** — not a benchmark but a **model**: Qwen3-32B post-trained with RL for coding agents, 42.2 % pass@1 on SWE-bench-Verified. Fits 24 GB at Q4, but a 32B here already produced 38 min per task once | planned |
| **CoWorkBench** — long-horizon office agent tasks | **not runnable here** — described as Qwen-internal, public leaderboard only, no harness to run |
| **Dynamic quantisation** — `unsloth`'s `UD-Q4_K_XL` and similar claim to sit closer to the original at the same file size by quantising tensors unevenly. Every GGUF here is a plain `Q4_K_M`; the claim is untested on this hardware | planned |
| **The chat template as a variable in coding** — every coding run here used whatever template shipped inside the GGUF. The harness was worth up to 70 points on chat; the template has never been varied at all | planned |
| MTP: llama.cpp discards Qwen's `nextn` tensors (`unused tensor blk.64.nextn.*`); vLLM on ROCm needs a container runtime on the GPU host | blocked |
| Lowering the memory clock | [abandoned](hardware/power.md#the-memory-clock-is-not-a-knob-you-can-turn-down) — took the card off the bus |

## Data and scripts

**[`data/`](data/)** — the cleaned result tables as TSV, aborted and failed runs
included. Every number in the documents traces back here.

**[`scripts/`](scripts/)** — the harnesses as they ran, hosts and paths lifted into a
config block. Bash, driving `llama-bench`/`llama-server` over SSH.

**[`scripts/suite/`](scripts/suite/)** — the parameterised suite: name a llama.cpp
version, get 30 measurements and a promotion verdict. One command per build.

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

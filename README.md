# AI Model Benchmark Runs

**What can you actually run on local consumer hardware, and what can't you?**
Measured, not estimated. Two desktop machines, no cloud.

Each use case is a **slot** a model has to earn. RAG is one of them, not the subject.

---

Two ways in: **[by use case](#measured)** below, or **[by model](BY-MODEL.md)** for
everything measured about one model across all topics.

## Measured

| Use case | Document | Result |
|---|---|---|
| RAG — German chat | [Language understanding](models/language-understanding.md) | 16 models; the 5.3 GB default was never beaten, not even by a model 3× its size |
| RAG — retrieval | [Embedding](models/embedding.md) | A 9× larger model tied BGE-M3 exactly |
| Coding | [Coding](models/coding.md) | 18 models; the ranking inverted once the harness stopped naming the file |
| ASR — speech to text | [Transcription](models/transcription.md) | Qwen3-ASR-1.7B matches Whisper large-v3; a config fix was worth 30 points of WER |
| VLM — image input | [Vision](models/vision.md) | Runs permanently alongside three other models: 15.1 of 24.5 GB |
| Fine-tuning | [Fine-tuning](models/finetuning.md) | A third-party fine-tune lost 26.7 points against its own base and doubled the non-answers |
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
| Gemma-4-26B-A4B / 12B | coding | 11.6 and >29 min per task; answers up to 26 085 tokens — [one harness only](models/coding.md#three-findings-that-outlive-the-model-list) |

## Size ceiling

**Measured: ~24 GB, fully resident on the fast card, at reference speed.** That is
the largest model actually run here.

Everything above that is untested — see [open](#open).

## Open

| Item | Status |
|---|---|
| Models above ~24 GB — incl. GLM-4.5-Air, Hunyuan-A13B | never run; excluded on arithmetic before the second GPU existed |
| `faster-whisper` on the RTX 2070 | planned — and now unblocked: Ollama ships a CUDA runtime that works here, so the missing toolkit was never the barrier |
| TTS | planned |
| Home Assistant voice pipeline | planned |
| Energy efficiency **per phase** — prefill and generation draw differently, so a whole-run figure blurs both. Tokens per Wh **and** Wh per completed task | planned |
| Varying the harness instead of the model | planned |
| Re-running the System B results on System A | planned |
| Below 159 W on the throttle curve | planned |

## Data and scripts

**[`data/`](data/)** — the cleaned result tables as TSV, aborted and failed runs
included. Every number in the documents traces back here.

**[`scripts/`](scripts/)** — the harnesses as they ran, hosts and paths lifted into a
config block. Bash, driving `llama-bench`/`llama-server` over SSH.

## Authorship

Measurements run on the operator's hardware, under the operator's direction.
**Analysis, aggregation and all prose written by Claude (Anthropic). No full human
review has happened yet** — corrections so far came from spot-checks during writing.

An AI writing up its own analysis produces confident prose whether or not the claim
holds. It happened here: a mechanism was invented to explain a model's failure, and
the source data said the opposite. Caught by the operator asking for the evidence.
Hence: sample sizes named, measured facts kept separate from inference, and
"not measured" written where that is the case.

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
  [harness variable](models/coding.md) is the biggest unmeasured thing here — a
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

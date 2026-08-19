# Foreign benchmarks

Benchmarks written by other people, run here.

**Say exactly what was run.** "We ran their benchmark" can mean their script, their
harness, or only the command from their README — and those are different claims with
different comparability. Each document here states which, in a table, near the top.
Where we used the invocation but not the harness, that is written down as a limitation
rather than smoothed over.

Everything else in this repository is self-designed: models, flags and prompt shapes
picked to answer a question about this system. That makes those numbers precise and
comparable with nothing. These runs exist for the opposite reason — to place this
machine next to hardware we do not own.

## The rule for this directory

**Do not "improve" a foreign benchmark.** Its value is entirely that it matches what
other people ran. A better prompt, a fairer quantization or a more sensible flag makes
the result worthless for the one job it has.

Where a deviation is unavoidable, it gets stated at the top of the document with the
reason, and it must not change *what* is measured — only how precisely. There is
exactly one so far: `-r 20` instead of `-r 2`, because a wall-socket meter cannot see
an 11-second run.

## Runs

| Benchmark | Document | What it gave us |
|---|---|---|
| [geerlingguy/ai-benchmarks](https://github.com/geerlingguy/ai-benchmarks) | [geerlingguy-ai-benchmarks.md](geerlingguy-ai-benchmarks.md) | Comparable token rates per card, plus an Ollama-vs-llama.cpp comparison on one machine |

## Considered, not run

| Benchmark | Why not |
|---|---|
| [lpalbou/llm-basic-benchmark](https://github.com/lpalbou/llm-basic-benchmark) | 44 models over four hand-judged tasks, measured on Apple Silicon via Ollama. The task scoring is qualitative, so the results are not mechanically comparable — but its central claim, *token generation speed ≠ task completion speed*, matches what we measured on [verbose coding models](../use-cases/coding.md) |
| [open-compass/VLMEvalKit](https://github.com/open-compass/VLMEvalKit) | 220+ vision-language models over 80+ benchmarks, and the obvious next step for [vision](../use-cases/vision.md), which currently rests on a single German score plus VRAM measurements. Needs a custom model class to reach a local OpenAI-compatible endpoint, and LLM-based answer extraction — a judge model we would have to pick and document |

Suggestions for others worth running are welcome — see the
[call at the end of the main README](../README.md#what-should-we-measure-next).

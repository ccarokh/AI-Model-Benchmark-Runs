# Coding models

> Measured on **[System A](../SYSTEMS.md#system-a) v1.0** (aider-polyglot) and
> **v1.1 → v1.2** (SWE-bench), quiet BIOS. The inference stack — llama.cpp b10098,
> Mesa 26.1.5 — was constant throughout; the hardware changed between the two parts,
> which is why they carry different version numbers.

**18 models on aider-polyglot, 5 on SWE-bench. The answer flipped when the harness got
harder — and the most interesting finding is not about code quality at all.**

## Summary

| Benchmark | Winner | Runner-up |
|---|---|---|
| aider-polyglot, 225 tasks, `diff` format | Qwen3-Coder-30B-A3B (speed) / Qwen3.6-27B (quality) | statistically tied |
| SWE-bench, 81 instances, realistic mode | **Qwen3.6-27B, 38.3 %** | Qwen3-Coder-30B-A3B, 13.6 % |

The first benchmark said the two were level and speed should decide. The second
said they are not remotely level. **The difference between the two benchmarks is
whether the model is told which file to edit.**

---

## Part 1 — aider-polyglot

225 tasks, 6 languages, run in the **`diff` format** on purpose: it requires exactly
matching SEARCH/REPLACE blocks and therefore measures whether a model can actually
be driven by an agent. The `whole` format is forgiving and does not measure it.

| Model | pass1 | pass2 | well-formed | malformed | s/case |
|---|---:|---:|---:|---:|---:|
| Qwen3.5-27B | 25.3 | 49.3 | 98.2 | 4 | 287.5 |
| ornith-35b | 24.9 | 43.1 | 97.8 | 5 | 91.9 |
| Qwen3.6-27B | 15.1 | 23.6 | **100.0** | **0** | 374.5 |
| **Qwen3-Coder-30B-A3B** | 12.9 | 22.7 | 98.7 | 4 | **40.5** |
| Qwen3.6-35B-A3B | 14.7 | 22.7 | **100.0** | **0** | 142.3 |
| ornith-9b | 7.6 | 20.4 | 96.0 | 9 | 74.9 |
| Kimi-Linear-48B-A3B | 4.9 | 12.0 | 90.7 | 38 | 72.7 |
| Qwen2.5-Coder-32B *(incumbent)* | 4.0 | 8.4 | 80.9 | 75 | 881.8 |
| Devstral-Small-2507 | 1.8 | 6.7 | 93.3 | 21 | 98.7 |
| Qwen2.5-Coder-14B | 2.2 | 5.8 | 85.3 | 108 | 62.9 |
| Yi-Coder-9B | 3.6 | 4.0 | 69.8 | 171 | 34.0 |
| Mistral-Small-3.2-24B | 1.8 | 4.0 | 86.2 | 54 | 79.7 |
| DeepCoder-14B | 0.9 | 2.7 | 88.4 | 54 | 188.8 |
| Codestral-22B | 1.8 | 2.2 | 83.6 | 43 | 140.2 |
| DeepSeek-Coder-V2-Lite | 1.3 | 1.8 | 20.9 | **633** | 221.9 |
| OlympicCoder-32B | *aborted* | | | | 2298 |
| Gemma-4-26B-A4B | *failed* | | | | 696 |
| Gemma-4-12B | *failed* | | | | >1740 |

### Three findings that outlive the model list

**Generation beats size.** Qwen3-Coder-30B-A3B (MoE, 3B active) takes apart
Qwen2.5-Coder-32B (dense) by a factor of 2.7 in quality and 22 in speed, in a
smaller memory footprint. The incumbent was two generations old and it showed.

**The edit format is the filter, not the intelligence.** DeepSeek-Coder-V2-Lite
fails on 79 % malformed diffs — 633 of them. Yi-Coder on 30 %. Inside a real
agent harness they are unusable no matter how good the code inside the broken
block might be.

**Reasoning models are the wrong class here.** OlympicCoder-32B needed ~38 minutes
per task; a single answer took 1172 s for 2405 tokens. Extrapolated to 6 days for
one model. Aborted.

**Both Gemma-4 variants failed this benchmark** on speed: 11.6 min (26B-A4B) and
>29 min (12B) per task against 40.5 s for the winner. The cause is verbosity —
single answers of 11 746 and **26 085 tokens** where other models write a few
hundred.

**This was measured under a clean configuration**: 49 152 tokens per slot, **zero
context overflows**, VRAM uncritical. It is not a truncation artifact, and it is not
the 8192-token problem described in the caveat below — the Gemma runs were given
room and used it.

**What that supports and what it does not:** on this benchmark, in this harness, both
models are unusable — measured, not in doubt. Whether a different harness, prompt or
sampling configuration would tame the verbosity, and what the underlying coding
ability looks like if it did, **was never measured**. So "Gemma-4 does not work in
this harness" is supported; "the Gemma-4 family is unsuitable for agentic coding" is
not.

Worth stating carefully because Gemma-4-12B is a strong chat and vision candidate on
the same hardware — which is the general rule again: **models are good at roles, not
in general.**

### Caveat that applies to the whole table

The default configuration `--ctx-size 32768 --parallel 4` gives each slot only
**8192 tokens**. Every model in the table had context overflows — from 15
(Mistral-Small) to **292 for Qwen3.6-27B**, which was truncated in 65 % of its
attempts and still posted the highest well-formed rate. Its true score is unknown
and higher. **Verbose models were systematically penalized**; read the mid-field
ordering with that in mind.

The three `-slot32k` rows below were re-runs with a larger context. Their pass
rates are valid; their `s/case` values are **not** — they were run above the f16
cache ceiling and measure PCIe latency, not the model. See
[METHODOLOGY.md](../METHODOLOGY.md#a-context-size-without-a-cache-type-is-not-a-specification).

| Model, 32k slots | pass1 | pass2 | s/case |
|---|---:|---:|---:|
| Qwen3.6-27B | 38.2 | 74.2 | 797.5 ⚠️ |
| Qwen3.6-35B-A3B | 28.9 | 62.7 | 311.3 ⚠️ |
| ornith-35b | 28.4 | 61.8 | 220.2 ⚠️ |
| Qwen3-Coder-30B-A3B | 12.9 | 32.0 | 94.0 |

Giving the models room to write triples the pass rate across the board. Whatever
else these numbers say, **the 8192-token slot was the dominant limitation of the
original run.**

**And it distorted the speed column in the opposite direction.** Re-run without the
cap, Qwen3.6-27B extrapolates to **~713 s per case against the 374.5 in the table** —
the truncation was not only costing it accuracy, it was **making it look twice as
fast as it is**. Anyone judging from the first run had it at half its real cost.

---

## Part 2 — SWE-bench

Real issues from real repositories. Run in two modes:

- **oracle** — the model is told which file contains the bug.
- **repomap** — the model gets a repository map and has to find it itself.

`repomap` is the realistic one. Both were measured because the difference between
them turned out to be the actual result.

### repomap, all repositories

| Model | pytest | pylint | astropy | requests | xarray | **Total** | Empty patches |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Qwen3.6-27B** | 10/19 | 1/10 | 8/22 | 2/8 | 10/22 | **31/81 = 38.3 %** | 16/81 = 19.8 % |
| Qwen3-Coder-30B-A3B | 2/19 | 0/10 | 4/22 | 3/8 | 2/22 | **11/81 = 13.6 %** | **40/81 = 49.4 %** |
| ornith-35b | 8/19 | 1/10 | — | — | — | 9/29 | 14/29 |
| Qwen3.6-35B-A3B | 7/19 | 1/10 | — | — | — | 8/29 | 11/29 |

### The finding

**Qwen3-Coder produced no patch at all in 49.4 % of its runs.** Half of its
failures were not wrong answers — they were non-answers.

The oracle mode explains why:

| Model | pytest oracle | pytest repomap |
|---|---:|---:|
| Qwen3-Coder-30B-A3B | **7/19** | **2/19** |
| Qwen3.6-27B | 9/19 | 10/19 |

**Tell Qwen3-Coder which file to edit and it triples its score. Qwen3.6-27B does
not care either way.**

So the gap is not code quality. It is the ability to navigate a repository it has
not been handed on a plate — to read a repo map, form a hypothesis about where the
bug lives, and go there. On the polyglot benchmark, where every task is a single
known file, that skill is never tested, and the two models look level.

This is the single most useful thing this series produced: **a benchmark that hands
the model its context measures a different capability than an agent working in a
real repository, and the ranking between the two is not stable.**

### What that means for the production choice

The original decision — Qwen3-Coder for its 9.2× speed advantage at equal quality —
was correct **for the benchmark it was based on**. Under the harder harness the
quality is not equal, and the choice is a genuine trade-off between a model that is
fast and one that finds its own way around a codebase.

### One caveat on these numbers

Per-repository differences of two or three instances sit **inside the noise band**
(see [METHODOLOGY.md](../METHODOLOGY.md#how-much-is-noise)). Only the totals carry
weight, and only where the gap is large. The 31 vs 11 is large. The 9 vs 8 between
ornith-35b and Qwen3.6-35B-A3B is not a result.

---

---

## Part 3 — a real multi-file project

14 models, one 299-line specification, free choice of technology with a justification
requirement. Built with aider in `diff` format, `--auto-test`, in a container. This
was the attempt to measure what polyglot cannot: a whole project rather than
single-file puzzles.

### ⚠️ Read the caveat before the table

**Two setup errors invalidated the iteration phase:**

1. **`python` did not exist in the container** — only `python3`. Every Makefile
   calling `python` died with error 127, regardless of the code's quality.
2. **The reflection limit did not apply.** `max_reflections = 3` is a hard class
   attribute in aider; the environment variable set to raise it does nothing. Models
   got three attempts instead of the intended fifteen.

Both fixed and verified — **after** the series.

**What survives:** the six models that delivered nothing failed *before* the first
test run. That failure is real and not the setup's fault.
**What is compromised:** the achievable quality of the eight that did deliver.
**None of them got their tests green**, and with a broken test command that number
means nothing.

### Results

| Model | Commits | Files | Lines | Longest file | Entry point | Runtime | Status |
|---|---:|---:|---:|---:|---:|---:|---|
| Qwen3-Coder-30B-A3B | 3 | 17 | 1272 | **375** ❌ | 32 | 9m | delivered |
| Qwen3.6-27B | 3 | 21 | 662 | **147** ✅ | 33 | 36m | delivered |
| OlympicCoder-32B | 1 | 5 | 190 | 99 | **99** ❌ | 99m | delivered |
| DeepCoder-14B | 3 | 5 | 120 | 34 | 20 | 3m | delivered |
| Mistral-Small-3.2-24B | 3 | 2 | 105 | 83 | – | 11m | delivered |
| Gemma-4-12B | 2 | 6 | 77 | 25 | – | 13m | delivered |
| Qwen3.6-35B-A3B | 3 | 3 | 63 | 42 | 42 | 7m | delivered |
| DeepSeek-Coder-V2-Lite | 1 | 3 | **0** | 0 | 0 | 9m | **empty files** |
| Codestral-22B | 0 | – | – | – | – | 22m | **nothing** |
| Devstral-Small-2507 | 0 | – | – | – | – | 3m | **nothing** |
| Gemma-4-26B-A4B | 0 | – | – | – | – | 49m | **nothing** |
| Qwen2.5-Coder-14B | 0 | – | – | – | – | 1m | **nothing** |
| Qwen2.5-Coder-32B | 0 | – | – | – | – | 107m | **aborted** |
| Yi-Coder-9B | 0 | – | – | – | – | 32m | **nothing** |

**Six of fourteen produced nothing at all.** That is the finding that survives the
broken setup, and it is a large number for models that all score somewhere on
polyglot.

### Modularity: the prolific writer does not win

The specification required an entry point under 50 lines without business logic, and
no file over 300 lines (hard limit), target 150.

- **Qwen3.6-27B meets it**: longest file 147 lines, 21 files, entry point 33 lines.
  Price: 36 minutes instead of 9.
- **Qwen3-Coder-30B-A3B breaks the hard limit** with a 375-line handler — while
  producing by far the most code (1272 lines) four times faster.
- **OlympicCoder-32B put the entire business logic in a 99-line entry point.** The
  separation was not understood.

**This measurement needs repeating** with the container fixed. As it stands it
supports one claim — that six models delivered nothing — and nothing about the
quality of the rest.

---

## Operating parameters

Measured separately across 10 configurations for the production slot:

```
--ctx-size 131072 --cache-type-k q8_0 --cache-type-v q8_0 --parallel 1 \
--batch-size 512 --ubatch-size 512 -ngl 99 -fa auto --jinja
```

- **Context ceiling: 65 536 with f16, 131 072 with q8_0.** At 131k/q8_0 there are
  284 MiB of VRAM left, with 307 tok/s prefill and 44 tok/s decode.
- **`--parallel 1` is mandatory** — `--ctx-size` is the sum across all slots.

**Tool-call format holds up.**

| Sampling | Well-formed |
|---|---|
| temp 0.2 | **100.0 %** (80/80) |
| temp 0.7 / top_p 0.8 / top_k 20 (the model's own chat recommendation) | 98.8 % (79/80) |

The single failure was a **text fallback** — `tool_calls` came back `None` with the
call sitting in `content` as text. That is the same failure mode seen constantly on an
older coder model; here it occurred **once in 160 attempts, and never at temp 0.2**.

A control scenario — a pure knowledge question with tools registered — returned
**40/40** text answers with no tool call, so the model does not reach for a tool
reflexively.

**Run tool calls at temp 0.2.** It costs nothing and removes the fallback entirely.

## Scripts

- [`scripts/coding/swebench_run.sh`](../scripts/coding/swebench_run.sh) — one
  repository × model × mode × cache type
- [`scripts/coding/night_chain.sh`](../scripts/coding/night_chain.sh) — chains runs
  unattended with a deadline and a disk guard

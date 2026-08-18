# What abliteration costs

**Nothing measurable on any axis we test.** A weight-level de-refusal of Qwen3.8-27B
scores within one to two questions of its own base on German comprehension, is
indistinguishable on context depth, and identical on energy. It also generates **37 %
fewer tokens** for the same task.

That is worth stating plainly because this repository's only other third-party
derivative [lost 26.7 points against its own base](finetuning.md).

Measured on [System A](../SYSTEMS.md#system-a). Same quantisation as the base
(Q4_K_M), same card, base measured the day before. Full tables in
[`data/abliteration.tsv`](../data/abliteration.tsv) and
[`data/context_depth.tsv`](../data/context_depth.tsv).

## German comprehension

| Harness | Base | Abliterated | Δ |
|---|---:|---:|---:|
| `logprob` | 0.9533 | 0.9467 | −0.7 |
| `generate` | **0.9667** | 0.9533 | −1.3 |
| `generate` + thinking | 0.9133 | **0.9467** | +3.3 |

**At n = 150 one question is 0.67 points.** The first two rows differ by one and two
questions — inside the noise this repository already documents. The third moves five
questions the other way.

**Conclusion: no measurable loss, and no measurable gain.** Not "slightly worse" — the
measurement cannot separate them.

## Context depth and energy

| | Base | Abliterated |
|---|---:|---:|
| Prefill, depth 0 | 821.7 | 803.8 |
| Prefill, depth 32 768 | 572.9 | **577.1** |
| Generation, depth 0 | 39.07 | 39.47 |
| Generation, depth 32 768 | 34.43 | 34.97 |
| Tokens per Wh, prefill | 10 566 | 10 605 |
| Tokens per Wh, generation | 480 | 488 |

Eight measurements, none differing by more than 2 %. Removing the refusal direction from
the weights **does not touch throughput or energy**, which is what the method's own
description would predict — it is a projection, not a retrain.

## The one real difference is verbosity

| | Tokens for 150 answers | Median |
|---|---:|---:|
| Base | 28 884 | 109 |
| **Abliterated** | **18 310** | **68** |

**37 % fewer tokens for the same task, at the same accuracy.** That is the largest effect
in this comparison by a wide margin, and it is not an accuracy effect at all.

⚠️ **The obvious explanation — that removing refusal behaviour also removes hedging — is
a guess.** Nothing here measures *what* the extra 10 000 tokens were. It could as easily
be a shift in output style with no relation to refusals.

## What this does not measure

**Everything the publisher's own card names as untested**, and it names them honestly:
*"These results do not yet establish coding, vision, tool-use, long-context, or
multi-turn retention."* Long context is now covered above. **Coding, vision, tool use and
multi-turn are not**, and those are where a weight edit is most likely to show.

- **Refusal behaviour itself is not measured here.** The publisher reports 11 residual
  refusals from 450 cases. This work neither confirms nor contradicts that; it only asks
  what the edit cost elsewhere.
- **One task for quality.** Belebele is multiple-choice reading comprehension.
- **Perplexity is not measured here either.** The card reports WikiText-2 rising from
  8.48 to 9.37 — a 10.5 % degradation that our task-level measurements do not see. **When
  a proxy metric moves and the task metric does not, the task metric is the one that
  answers "can I use this".**

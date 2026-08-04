# Fine-tuning

**Question behind this: before considering training our own specialization, does
somebody else's serious fine-tune beat its base model on our metrics?**

If a well-executed community fine-tune with 20 000 downloads does not move our
numbers, the expected value of a home-grown one should be adjusted accordingly.

## The comparison

`Jackrong/Qwopus3.6-35B-A3B-v1` — a LoRA fine-tune of Qwen3.6-35B-A3B with roughly
9 % trainable parameters, three-stage distributed SFT, aimed at reasoning. 20 000
downloads, 222 likes; not a throwaway upload.

**The comparison is unusually clean**: the base model was measured here the same
week, on the same card, with the same parameters, in the same harness.

## SWE-bench — identical

| | Base Qwen3.6-35B-A3B | Qwopus3.6-35B-A3B-v1 |
|---|---:|---:|
| pytest, repomap | **7 / 19** | **7 / 19** |
| pylint, repomap | **1 / 10** | **1 / 10** |
| Total | 8 / 29 | 8 / 29 |

Not one instance apart. Given the measured ±2 spread on a 19-instance run, landing
on exactly the same number twice is as close to "no effect" as this benchmark can
express.

## The one thing that did move — and it moved the wrong way

| Empty patches | Base | Qwopus |
|---|---:|---:|
| pytest | 7 / 19 | **9 / 19** |
| pylint | 4 / 10 | **9 / 10** |
| Total | 11 / 29 = 37.9 % | **18 / 29 = 62.1 %** |

**The fine-tune produces markedly more non-answers.** On pylint it failed to produce
a patch in 9 of 10 attempts, against 4 of 10 for the base — the single resolved
instance is all that is left.

The resolved count is unchanged, so this is not a straightforward regression in
capability. It looks like a shift in behaviour: the reasoning-oriented tuning makes
the model more likely to deliberate and less likely to emit a concrete edit within
the harness's constraints. That is exactly the failure mode we saw with reasoning
models in the [coding evaluation](coding.md).

## aider-polyglot — a large regression

225 tasks, same harness, same card.

| | pass2 | well-formed | s/case |
|---|---:|---:|---:|
| Base Qwen3.6-35B-A3B | **62.7 %** | 98.7 | 311.3 |
| Qwopus3.6-35B-A3B-v1 | **36.0 %** | 97.8 | 630.5 |

**26.7 points lost, and twice the time per task.** At n=225 that is far outside any
noise band this repository has measured.

⚠️ One qualification on the time column: the base run was taken above the f16 cache
ceiling and its `s/case` is [not a clean number](../METHODOLOGY.md#a-context-size-without-a-cache-type-is-not-a-specification).
The pass rates are directly comparable; the 311.3 against 630.5 is not.

## Conclusion

A competent third-party fine-tune, aimed at a capability adjacent to ours, produced
**no improvement on any metric we measured, a large regression on one, and twice the
non-answers.**

That does not prove fine-tuning cannot help. It says that generic capability tuning
by someone else, on someone else's data, does not transfer to a specific task — and
that if specialization is worth doing here, it would have to be on our own domain
data with our own evaluation as the target, not adopted off the shelf.

## Hardware note for anyone considering the training side

MoE fine-tuning memory is driven by **total** parameters, not active ones. All
experts have to be resident. A 36B-total / 3B-active model needs the memory of a
36B model to train, not of a 3B one — which is why this remained an evaluation of
someone else's fine-tune rather than an attempt at our own.

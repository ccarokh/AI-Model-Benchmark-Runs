# Somebody else's hardware

Everything else in this repository measures a card that can be looked at. These scripts
talk to a service, and the difference is not a detail: **behind an endpoint are their
hardware, their batching, their precision and their load, none of it visible from here.**

So an endpoint can answer *is this model any good* and can never answer *what does this
model cost to run*. Throughput, context ceilings, power draw, concurrency, slot
eviction — not one of those is measurable through a service, and nothing in here tries.

## hetzner_inference.py

A **one-off**. Hetzner's experimental Inference API happens to serve exactly the two
models this repository got stuck on:

| Model | where it stands here |
|---|---|
| Qwen3.8-27B | coding abandoned at 61 and 38 of 225 tasks — 18.5 minutes each. That rules out interactive use and says nothing about the model |
| Qwen3.6-35B-A3B | 225 of 225, the fastest agent measured here |

Two questions it can settle:

1. **What our quantisation costs.** Everything local is Q4_K_M on llama.cpp; this is FP8.
   The [QAT comparison](../../findings/qat-vs-ptq.md) showed two Q4 variants scoring the
   same — Q4 against FP8 is the question that had no reference.
2. **What the endpoint supports**, asked first and separately. This repository's own
   finding is that [how you ask is worth up to seventy points](../../findings/harness-effect.md);
   without knowing whether temperature 0 is honoured, whether logprobs exist and whether
   two identical requests return the same text, a score from here is a number without a
   stand.

```
HETZNER_TOKEN=... python3 hetzner_inference.py probe
HETZNER_TOKEN=... python3 hetzner_inference.py belebele 900
```

**The token goes in the environment.** Not in this file, not in this repository — five
scripts in here carried a hard-coded address until somebody went looking for it, and a
token is worse than an address.

The published rate limit is ten requests per sixty seconds, so the script waits 6.5
seconds **before** each request rather than reacting to refusals: a 429 is not a
measurement, and a run that collects them is measuring its own impatience.

## Reading whatever comes out of it

Results carry a provider, a precision and a date, and belong in their own file. **They
are not a check on the local figures** — different precision, different runtime,
different hardware. They measure the same weights in another configuration, which is a
finding, not a confirmation. And the service is experimental and free, which means it can
be withdrawn between one measurement and the next.

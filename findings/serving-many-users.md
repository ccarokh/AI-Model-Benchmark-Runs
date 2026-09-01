# How many people can one card serve?

Every other figure in this repository is one request on an empty card — the number a person sees when nobody else is using the machine. **That is not the number a service delivers.** This is the same hardware asked the question a deployment actually has.

Two cards: an RTX 4070 Super with 12 282 MiB, Vulkan and CUDA from the same commit, and the 24 560 MiB 7900 XTX that serves. Measured by [`95_concurrency`](../scripts/testbench/tests/95_concurrency.py), [`96_context_split`](../scripts/testbench/tests/96_context_split.py) and [`97_slot_restore`](../scripts/testbench/tests/97_slot_restore.py). Each user is a retrieval turn: a passage, a question, a 200-token answer, **8 192 tokens of context per user**.

## One slot per user on 12 GB: the wall is memory, and it arrives early

| Model | 1 | 2 | 4 | 8 | 16 | Wall |
|---|---:|---:|---:|---:|---:|---:|
| Llama-3.2-3B | 187 | 332 | 466 | 427 | | 32 |
| ornith-9b | 76 | 116 | 213 | 252 | **267** | 64 |
| Qwen3.5-9B | 75 | 112 | 211 | 165 | 229 | 64 |
| Meta-Llama-3.1-8B | 89 | 166 | 279 | | | 16 |
| gemma-4-12b QAT Q4_0 | 56 | 102 | 174 | 202 | | 32 |
| gemma-4-12B Q4_0 | 54 | 100 | 171 | | | 16 |
| gemma-4-12b QAT → Q4_K_M | 53 | 97 | 131 | | | 16 |
| gemma-4-12B Q4_K_M | 51 | 50 | 127 | | | 16 |
| gpt-oss-20B | 138 | 124 | | | | **8** |
| DeepSeek-R1-14B | 48 | 88 | | | | 8 |
| Qwen2.5-Coder-14B | 50 | 92 | | | | 8 |

*Aggregate tokens per second across all users, Vulkan. "Wall" is the first user
count at which the server refuses to start.*

**The user ceiling is the context ceiling divided by the per-user budget.** DeepSeek-R1-14B stops at two users, and 2 × 8 192 = 16 384 is exactly [its measured context ceiling](context-ceiling.md) on this card. The two numbers are one number seen from different sides — which also names the lever: **halve the per-user context and the user count doubles.**

**gpt-oss-20B is the exception and fails differently.** Not the KV cache but the compute buffers, and its aggregate rate *falls* from one user to two — 138 to 124 t/s. The MoE takes parallelism badly.

## On a 24 GB card the memory stops mattering, and something else stops you

The same test on the card that serves, one slot per user, 8 192 tokens each — **aggregate tokens per second, and what one user gets:**

| Model | 1 | 2 | 4 | 8 | 16 | 32 | 64 |
|---|---|---|---|---|---|---|---|
| ornith-35b | 108 / 108 | 139 / 76 | 220 / 57 | 217 / 26 | **246 / 16** | | |
| Qwen3.5-9B | 93 / 93 | 152 / 76 | 210 / 59 | 245 / 33 | **237 / 16** | 284 / 9 | **22 / 0.35** |
| gemma-4-12b | 68 / 68 | 111 / 55 | 142 / 41 | 202 / 25 | **170 / 11** | 152 / 5 | ✗ |

**Twice the memory did not buy twice the users. It bought a different limit.**

On the 12 GB card the server refused to start and that was the answer. Here the memory holds — 64 × 8 192 is half a million tokens of cache and it allocates — and **the card gives up anyway**:

```
Qwen3.5-9B, 32 users   284.42 t/s total     9.33 each    13.2 s     0 failed
Qwen3.5-9B, 64 users    22.49 t/s total     0.35 each   329.8 s     0 failed
```

**Not one request failed.** The aggregate collapsed by a factor of 12.6 and the slowest answer took five and a half minutes. This is the soft ceiling the test was built to separate from the hard one, and it is the first time it arrived first — on the smaller card the allocator always spoke before the throughput did.

**So the usable number is sixteen, not sixty-four.** Taking ten tokens a second per user as the floor — below it an answer arrives slower than it is read — every model on this card seats **16 users**, and the next step down is already under the floor.

## Splitting the same context is not free

The obvious arithmetic — ten users at 32k needs 320k of cache — assumes that cutting a total into slots costs nothing. It does not:

Extra memory per slot, against the same model held in one slot:

| Model | 2 slots | 4 | 8 | 16 |
|---|---:|---:|---:|---:|
| ornith-9b | +0 | **+75** | +265 | +681 |
| Qwen3.5-9B | +0 | **+75** | +265 | +680 |
| gemma-4-12b QAT Q4_0 | +416 | **+1 344** | ✗ | ✗ |
| gemma-4-12B Q4_0 | +418 | +1 347 | ✗ | ✗ |
| gemma-4-12b QAT → Q4_K_M | +422 | +1 353 | ✗ | ✗ |
| gemma-4-12B Q4_K_M | +425 | +1 358 | ✗ | ✗ |

*MiB above the same total context in a single slot.*

**The price of a slot is set by the architecture, and by nothing else.** Two unrelated 9B models pay +75, +265, +681 — the same numbers to within one mebibyte. All four quantisations of the 12B pay +416 to +425 and +1 344 to +1 358: **the format the weights are in does not change what a slot costs.**

And the two classes are nowhere near each other. **At four slots the 12B pays eighteen times what the 9B pays** — 1 344 MiB against 75 — and it will not start at eight, with a total it holds comfortably as one. Budget slots, not just tokens, and do not carry a per-slot figure from one model family to another.

## More users than slots: the queue is real, and it is cheap

Slots are a memory question. **Users are a latency question**, because llama.cpp parks an idle slot in a host-RAM prompt cache and fetches it back. Four slots, gemma-4-12b, everybody arriving at once:

| Users | Slots | Aggregate | Each | Slowest answer | Failed |
|---:|---:|---:|---:|---:|---:|
| 4 | 4 | 188.6 t/s | 47.1 | 4.2 s | 0 |
| 8 | 4 | 187.4 | 35.2 | 8.5 s | 0 |
| 16 | 4 | 188.3 | 19.6 | 17.0 s | 0 |
| 32 | 4 | **188.3** | 10.6 | **34.0 s** | **0** |
| 16 | 2 | 106.6 | 12.0 | 30.0 s | 0 |

**Thirty-two people on four slots, nobody refused.** The card has a fixed aggregate rate; the queue divides it. Waiting grows linearly, failures do not appear at all.

The last row is the warning in the other direction: **too few slots wastes the card.** Two slots deliver 107 t/s where four deliver 188 — batching needs something to batch.

Across every model that fits four slots, the same load taken up to sixty-four people — **slowest answer, in seconds, and not one failure anywhere in the table:**

| Model | 4 users | 8 | 16 | 32 | 64 |
|---|---:|---:|---:|---:|---:|
| Llama-3.2-3B | 2 | 4 | 7 | 14 | **28** |
| ornith-9b | 4 | 8 | 16 | 31 | 62 |
| Meta-Llama-3.1-8B | 3 | 6 | 11 | 23 | 46 |
| Qwen3.5-9B | 4 | 6 | 11 | 27 | 53 |
| gemma-4-12b QAT Q4_0 | 5 | 9 | 19 | 37 | 75 |
| gemma-4-12B Q4_0 | 5 | 9 | 19 | 37 | 74 |
| gemma-4-12B Q4_K_M | 6 | 11 | 22 | 44 | 90 |
| gemma-4-12b QAT → Q4_K_M | 6 | 12 | 25 | 49 | **99** |

**Every row doubles when the user count doubles.** There is no knee, no collapse and no error — the queue is exactly as fair and exactly as slow as arithmetic says it should be. Sizing for a wait is therefore a division, and the only thing that has to be measured is the aggregate rate.

It also puts a price on a decision made two documents ago. The QAT Q4_0 file and the requantised Q4_K_M one differ by [0.11 points of quality](qat-vs-ptq.md) — and by **24 seconds of worst-case wait at sixty-four users**, 75 against 99.

## What a slot eviction costs, and the flag that decides it

Three users, two slots, ~6 800 tokens of prompt each. The first user comes back after the others have taken the slots:

| | Cold | Returning after eviction | Never left |
|---|---:|---:|---:|
| Llama-3.2-3B, `--cache-ram 8192` | 732 ms | **8 ms — 1 %** | 8 ms |
| Llama-3.2-3B, `--cache-ram 0` | 743 ms | **723 ms — 97 %** | 8 ms |
| gemma-4-12b, `--cache-ram 8192` | 2 431 ms | **412 ms — 17 %** | 218 ms |
| gemma-4-12b, `--cache-ram 0` | 2 422 ms | **2 461 ms — 102 %** | 212 ms |

**With the RAM cache off, coming back costs a full re-prefill.** With it on — and it is on by default, 8 GiB — it costs between a hundredth and a fifth of that. This is the mechanism that makes "more users than slots" a real arrangement instead of a way to hide a stall.

## So: ten users at 32 768 tokens each

**Not 320k of VRAM.** Enough slots for the users who are *generating at the same instant*, each with 32 768 tokens, plus what the split itself costs on top. The others park in host RAM and come back for a fraction of a cold start.

What to size, in order:

1. **Slots × per-user context** must fit in VRAM alongside the weights — measure it, do not multiply it.
2. **Slots** decide the aggregate rate. Too few wastes the card.
3. **Users** divide that rate. Their number is bounded by patience, not memory — **and on a large card, by a collapse that arrives before the memory does.**
4. **`--cache-ram`** must be large enough for the parked conversations, or every return is a cold start.
5. **Name the card.** On a host with more than one, everything above is measured on a machine instead of a card, and comes out one to two times too slow.

## The number this whole page nearly got wrong

Every figure above for the 24 GB card is from a run that **named the card**. The first
attempt did not, and on a host that also holds an RTX 2070 llama.cpp spread each model
across both:

| | pinned | backend's choice |
|---|---|---|
| Qwen3.5-9B, 4 users | 210 t/s | 76 |
| gemma-4-12b, 8 users | 202 t/s | 59 |
| gemma-4-12b, 64 queued on 4 slots | 54 s | 117 s |

Between one and two times too slow, in a table that looked perfectly plausible — the
figures rose with the user count, the walls were where memory said they should be, and
nothing in the file said which hardware had produced them. It was caught because one
number disagreed with a *different* test on the same model, and only 10_reference had
been pinning its card all along. Details in
[METHODOLOGY](../METHODOLOGY.md#name-the-card-or-the-backend-names-it-for-you).

**In the data, an empty `card` column means the backend chose.** Those rows are not
wrong; they measure a machine rather than a card, and they must not be read beside
pinned ones.

## What this does not say

- **Two cards, one prompt shape.** A 200-token answer to a retrieval question. Longer answers hold slots longer and change every number above.
- **Why the 24 GB card collapses at 64 users is not established.** The memory allocates and no request fails, so it is not the cache running out. Whether it is the unified KV buffer, the compute buffers, or scheduling across sixty-four slots would need a test that varies one of those.
- **The RAM cache was measured at ~6 800 tokens per conversation, not 32 768.** The restore cost of a full 32k context is untested, and it is a copy whose size grows with the context.
- **All users arrive at the same instant here.** Real traffic does not, and a queue that never empties behaves differently from one that does.
- **`--cache-ram` was measured at its default and at zero**, not swept. How many parked conversations fit before the oldest is dropped is untested.

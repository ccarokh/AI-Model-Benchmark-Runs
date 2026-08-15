# The harness, not the model

**For ordinary models, how you ask is worth 1.3 to 2.7 points. For models that reason
before answering, it is worth up to 70.** The published
[German comprehension table](language-understanding.md) reads the probability of a
single letter — a position where a reasoning model never puts its answer.

Six models, three harnesses, same 150 belebele questions, same card, one variable
between each pair. Full table in
[`data/chat_belebele_harness.tsv`](../data/chat_belebele_harness.tsv).

| Harness | Extraction | Thinking | Prompt |
|---|---|---|---|
| `logprob` | probability of the first token | off | "answer with ONLY the letter" |
| `generate` | last standalone A/B/C/D in the text | off | "end with 'Antwort: X'" |
| `thinking` | same as generate | **on** | same as generate |

`generate` against `logprob` isolates extraction and prompt. `thinking` against
`generate` isolates the reasoning.

## Result

| Model | `logprob` | `generate` | `+thinking` | Spread |
|---|---:|---:|---:|---:|
| Qwen3.6-27B | 0.9333 | 0.940 | **0.9533** | 2.0 |
| Gemma-4-12B | 0.9267 | **0.940** | 0.9333 | 1.3 |
| Qwen3-30B-A3B | 0.9067 | **0.9333** | 0.9333 | 2.7 |
| Qwen3.5-9B | 0.9067 | 0.9067 | 0.880 | 2.7 |
| Nanbeige-4.2-3B | 0.760 | 0.833 | **0.900** | 14.0 |
| **DeepSeek-R1-14B** | **0.2133** | 0.880 | **0.9133** | **70.0** |

**Three of the four ordinary models reproduce their published `logprob` figure
exactly** — Gemma-4-12B 0.9267, Qwen3-30B-A3B 0.9067, Qwen3.6-27B 0.9333. The harness
is a real but small effect there, and **the published ranking survives it.**

## Why DeepSeek-R1 collapses

The diagnostic column, not the accuracy column, carries the explanation:

| | `no_letter_in_top20` |
|---|---:|
| DeepSeek-R1-14B | **147 of 150** |
| every other model | 0 |

**In 147 of 150 questions, none of A, B, C or D appeared among the twenty most likely
first tokens.** The model opens with its reasoning, so the harness reads a position at
which the answer is never present, finds nothing, and takes the best of four
essentially arbitrary values. 0.2133 is close to the 0.25 that guessing would give.

**This is not a hard model. It is a measurement pointed at the wrong token.**

⚠️ **Consequence for the published table:** the row `deepseek-r1-7b 0.64 (n=50)` in
[`chat_belebele.tsv`](../data/chat_belebele.tsv) is not a statement about that model.
It is a statement about the harness. The same applies to any always-reasoning model
measured that way.

## Thinking costs 20–250× the tokens for ±2 points

| Model | Tokens, `generate` | Tokens, `+thinking` | Accuracy change |
|---|---:|---:|---:|
| Qwen3.6-27B | 1 621 | 214 064 | **+2.0** |
| Gemma-4-12B | 10 028 | 232 092 | −0.7 |
| Qwen3.5-9B | 2 458 | 393 474 | **−2.7** |
| DeepSeek-R1-14B | 71 141 | 144 935 | +3.3 |
| Nanbeige-4.2-3B | — | — | +6.7 |

**Only two of five gain anything, and Qwen3.5-9B gets measurably worse** while
generating 160× the text. On this task, reasoning is not free accuracy — it is a
trade, and mostly a bad one.

⚠️ Read `truncated` alongside these. Qwen3.5-9B hit the 8 192-token ceiling on **25 of
150** questions: those answers were extracted from reasoning that never finished.

## The switch that did nothing

Qwen3-30B-A3B, `generate` against `+thinking`:

| | Tokens | Accuracy |
|---|---:|---:|
| thinking off | 878 | 0.9333 |
| thinking on | **879** | 0.9333 |

One token apart. **The tokenizer accepted `enable_thinking=True` and the model ignored
it** — it is an Instruct build with no reasoning mode. The `thinking_switch` column
reads `angenommen` (accepted) for every row in this file, because that column records
only that the template took the argument, not that anything happened.

**Without the token counts this would have been written up as "reasoning does not help
this model", when in fact no reasoning took place.** An accepted parameter is not an
applied one.

## What this does not settle

- **Six models, not sixteen.** The rest of the published table has not been re-measured
  on a working harness.
- **One task.** Belebele is multiple-choice reading comprehension. A harness effect
  here does not predict one on open generation.
- **`thinking` figures are not comparable to the later
  [chat-template run](../data/chat_belebele_neu.tsv)**, which allows 16 384 tokens and
  reads the reasoning field separately. The `logprob` and `generate` columns are.

## Scripts

- [`scripts/chat/eval_belebele_harness.py`](../scripts/chat/eval_belebele_harness.py)

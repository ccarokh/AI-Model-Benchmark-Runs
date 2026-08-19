# The harness, not the model

**For ordinary models, how you ask is worth 1.3 to 2.7 points. For models that reason
before answering, it is worth up to 70.** The published
[German comprehension table](../use-cases/language-understanding.md) reads the probability of a
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

## Part 2 — eight models that had never been measured on German

Eight models sat on the measurement host with coding numbers and **no German
comprehension figure at all**. They were judged for one slot and never for the other.
Re-measured through the chat-template harness, with two already-known models as
calibration. Full table in
[`data/chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv).

| Model | `logprob` | `generate` | `+thinking` |
|---|---:|---:|---:|
| **Ornith-35B** | **0.9733** | 0.9467 | 0.76 |
| **Qwen3.6-35B-A3B** | **0.9667** | 0.96 | 0.88 |
| Qwen3.5-27B | 0.9533 | 0.9533 | 0.94 |
| Gemma-4-26B-A4B | 0.9333 | 0.94 | **0.9533** |
| Mistral-Small-3.2-24B | 0.9067 | 0.9333 | 0.9333 |
| **gpt-oss-20B** | **0.2133** | 0.9267 | 0.9267 |
| Kimi-Linear-48B-A3B | 0.8933 | 0.8867 | 0.8867 |
| Ornith-9B | 0.8733 | 0.9067 | 0.8467 |

**The published table's best was 0.9333. Ornith-35B reads German at 0.9733** — four
points clear, on a model that had been on the disk for months and was only ever
measured for code.

⚠️ **Ornith-35B and Qwen3.6-35B-A3B are the same architecture** (`qwen35moe`), and
Ornith is a derivative — see
[context depth](context-depth.md#the-two-best-german-readers-are-one-model). Their
0.7-point difference is a fine-tune's worth, and they are **one finding, not two.**

### Calibration, and where it holds

| | `logprob` | `generate` | `+thinking` |
|---|---|---|---|
| Qwen3.5-9B, expected / measured | 0.907 / **0.9067** | 0.907 / **0.9067** | 0.880 / 0.9133 |
| Gemma-4-12B, expected / measured | 0.927 / **0.92** | 0.940 / **0.9333** | 0.933 / 0.90 |

**`logprob` and `generate` reproduce to within 0.7 points**, so those columns join the
published table. **The `thinking` column does not** — it allows 16 384 tokens instead of
8 192 and reads the reasoning field separately, and it lands 3.3 points off. Thinking
figures from the two rounds must not be placed side by side.

### gpt-oss-20B makes the harness failure a class, not a curiosity

| | `no_letter_in_top20` | `logprob` | `generate` |
|---|---:|---:|---:|
| DeepSeek-R1-14B | 147 / 150 | 0.2133 | 0.880 |
| **gpt-oss-20B** | **90 / 150** | **0.2133** | **0.9267** |

Two models, same signature, same collapse. **Reading the first token is not a harness
that occasionally misfires — it is a harness that cannot measure a model which reasons
before it answers.** Both land at 0.2133, below the 0.25 that guessing gives.

### Reasoning damages the strongest models

| Model | `generate` | `+thinking` | Change |
|---|---:|---:|---:|
| **Ornith-35B** | 0.9467 | **0.76** | **−18.7** |
| Qwen3.6-35B-A3B | 0.96 | 0.88 | **−8.0** |
| Ornith-9B | 0.9067 | 0.8467 | −6.0 |
| Qwen3.5-27B | 0.9533 | 0.94 | −1.3 |
| Gemma-4-26B-A4B | 0.94 | **0.9533** | +1.3 |

**Ornith-35B loses nearly 19 points by thinking**, and `truncated` is **0** on that row
— nothing was cut off. It reasons itself away from answers it gets right when asked
directly. Only one of eight models gains anything.

**On a reading-comprehension task, the answer is already in the passage.** Reasoning
adds a step that can only introduce error, and on this evidence it usually does.

## What this does not settle

- **Fourteen models across the two rounds**, but the ten remaining rows of the published
  table have still not been re-measured on a working harness.
- **One task.** Belebele is multiple-choice reading comprehension. A harness effect
  here does not predict one on open generation.
- **`thinking` figures are not comparable to the later
  [chat-template run](../data/chat_belebele_chattemplate.tsv)**, which allows 16 384 tokens and
  reads the reasoning field separately. The `logprob` and `generate` columns are.

## Scripts

- [`scripts/chat/eval_belebele_harness.py`](../scripts/chat/eval_belebele_harness.py)

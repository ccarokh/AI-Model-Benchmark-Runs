# Every model here reads German worse than English, and the gap is not the dataset's

**Ten models, four languages, the same 150 questions.** Belebele ships each language as its own file in its own row order, so the set is sorted by `(link, question_number)` — a key present in all 900 items of every language — and verified to select an identical question sequence in all four. What moves between columns is the language, nothing else.

| Model | DE | EN | FR | ES | EN − DE |
|---|---:|---:|---:|---:|---:|
| gemma-4-31b | 0.9600 | **0.9667** | 0.9533 | 0.9533 | 0.7 |
| ornith-35b | 0.9533 | **0.9600** | 0.9533 | 0.9533 | 0.7 |
| qwen3.5-35b-a3b | 0.9467 | **0.9533** | 0.9533 | 0.9400 | 0.7 |
| ornith-1.5-9b | 0.9400 | 0.9533 | **0.9600** | 0.9133 | 1.3 |
| nemotron-3.5-lightning-30b-a3b | 0.9267 | **0.9400** | 0.9133 | 0.9067 | 1.3 |
| ornith-1.5-35b | 0.9133 | **0.9600** | 0.9533 | 0.9333 | 4.7 |
| ornith-9b | 0.9133 | **0.9533** | 0.9333 | 0.9067 | 4.0 |
| granite-4.2-30b | 0.9067 | **0.9600** | 0.9333 | 0.9133 | **5.3** |
| qwen3.5-9b | 0.8933 | **0.9467** | 0.8800 | 0.9000 | **5.3** |
| ling-3.0-tiny | 0.8333 | **0.9133** | 0.8533 | 0.8667 | **8.0** |

Free generation, thinking off, card pinned. Full table in [`data/chat_belebele_multilingual.tsv`](../data/chat_belebele_multilingual.tsv).

## German is never the best column, and that part is unsurprising

Nine of the ten are best in English. The tenth, Ornith-1.5-9B (added 04.10.2026 with its predecessor and the 35B), is best in French by one question of 150 — inside the noise, and its English is still above its German.

What is worth the measurement is the second column from the right. **The penalty for German ranges from 0.7 points to 8.0** — on identical questions, identical prompts, identical hardware.

**That rules out the obvious objection.** Belebele's German passages are translations of the same English originals; if the German column were simply harder — a clumsy translation, a shifted register — every model would lose about the same amount. They do not. A spread of 0.7 to 8.0 on the same sentences is a property of the models.

## The ranking is not the same ranking

The seven measured first (September 2026):

| | by English | by German |
|---|---|---|
| 1 | gemma-4-31b | gemma-4-31b |
| 2 | **granite-4.2-30b** | ornith-35b |
| 3 | ornith-35b | qwen3.5-35b-a3b |
| 4 | qwen3.5-35b-a3b | nemotron-3.5-lightning |
| 5 | qwen3.5-9b | **granite-4.2-30b** |

**Granite is second in English and fifth in German.** Choosing a model for a German system from an English leaderboard picks it two places too high — and the published leaderboards are, by their own description, "primarily text-based, English-language evaluation suites".

## It is the passage, not the question

The obvious confound: maybe the models are not worse at German, only worse at following a German instruction. Both are language, and only one of them is the thing being measured.

Pulled apart on two models, passage language and prompt language varied independently:

| qwen3.5-9b | accuracy |
|---|---:|
| German passage, asked in German | 0.8933 |
| German passage, **asked in English** | 0.8933 |
| English passage, **asked in German** | **0.9667** |
| English passage, asked in English | 0.9467 |

**Asking in English does not rescue a German passage — the value is identical to four decimal places.** And an English passage scores 0.9667 even when the question arrives in German, which is *higher* than asking in English. Ornith-35B repeats the pattern: 0.9600 for German asked in English, 0.9733 for English asked in German.

So the harness is measuring reading, not instruction-following. That matters beyond this table: it is the assumption every German figure in this repository has rested on, and it had never been checked.

## What it costs here

The chat slot serves German. Its incumbent, `qwen3.5-9b`, is **5.3 points worse in the language it is deployed in** than in the language it is usually benchmarked in. That is not a defect to fix — it is the price of the slot, and it is now a number rather than a suspicion.

# Cleaned raw data

The result tables behind the documents, as machine-readable TSV. Cleaned, not
processed: aggregated from the harness output, with nothing dropped for looking
inconvenient.

Run logs and per-instance traces are not published — they are large, contain local
paths, and add nothing a reader can check.

| File | Rows | Source |
|---|---|---|
| [`chat_belebele.tsv`](chat_belebele.tsv) | 16 models | belebele_deu_Latn, single-token logprob, n=150 |
| [`embedding_retrieval.tsv`](embedding_retrieval.tsv) | 2 models | belebele retrieval, cosine NN, n=80 |
| [`coding_polyglot.tsv`](coding_polyglot.tsv) | 23 runs | aider-polyglot, 225 tasks, `diff` format |
| [`coding_swebench.tsv`](coding_swebench.tsv) | 27 runs | SWE-bench Verified, official harness |
| [`coding_real_task.tsv`](coding_real_task.tsv) | 14 models | one 299-line project spec, aider + auto-test ⚠️ |
| [`reference_bench.tsv`](reference_bench.tsv) | 4 runs | foreign benchmark, upstream flags, per card |
| [`reference_power_socket.tsv`](reference_power_socket.tsv) | 4 runs | wall-socket power for the same runs |
| [`ollama_vs_llamacpp.tsv`](ollama_vs_llamacpp.tsv) | 2 runtimes | same model, card, context and backend |
| [`transcription_fasterwhisper.tsv`](transcription_fasterwhisper.tsv) | 8 runs | `large-v3` on one 63.72 s clip, GPU and CPU |
| [`chat_belebele_reasoning.tsv`](chat_belebele_reasoning.tsv) | 3 runs | belebele with the generate-and-extract harness, thinking on |
| [`throughput_looped_transformer.tsv`](throughput_looped_transformer.tsv) | 8 rows | `llama-bench`, looped vs dense at the same scale |
| [`coding_swebench_empty_causes.tsv`](coding_swebench_empty_causes.tsv) | 16 instances | why each empty patch was empty, two runs |
| [`image_generation.tsv`](image_generation.tsv) | 5 models | time, VRAM, licence per image model |
| [`image_generation_ocr.tsv`](image_generation_ocr.tsv) | 10 rows | the two machine measures for text in images |
| [`image_generation_ab.tsv`](image_generation_ab.tsv) | 11 runs | one variable at a time on a single model |
| [`image_generation_seeds.tsv`](image_generation_seeds.tsv) | 50 runs | the two OCR measures repeated across five seeds |
| [`image_generation_energy.tsv`](image_generation_energy.tsv) | 5 models | card power integrated over one full image each |
| [`image_generation_verdicts.tsv`](image_generation_verdicts.tsv) | 38 verdicts | **operator judgements, not measurements** |
| [`energy_tokens.tsv`](energy_tokens.tsv) | 18 runs | tokens per Wh, prefill and generation separately |
| [`power_throttle_low.tsv`](power_throttle_low.tsv) | 8 runs | the throttle curve below 159 W, with interleaved stock controls |
| [`context_depth.tsv`](context_depth.tsv) | 14 runs | throughput and energy at four cache depths, three models |
| [`chat_belebele_harness.tsv`](chat_belebele_harness.tsv) | 18 runs | six models × three harnesses, one variable between each pair |
| [`chat_belebele_chattemplate.tsv`](chat_belebele_chattemplate.tsv) | 30 runs | ten models × three harnesses, chat template taken from the GGUF |

## Columns

**`chat_belebele.tsv`, `embedding_retrieval.tsv`** — `model`, `correct`, `n`,
`accuracy`.

⚠️ `deepseek-r1-7b` has **n=50**, not 150. It is a partial run and is not comparable
with the rest.

**`coding_polyglot.tsv`** — `slug`, `format`, `pass1`, `pass2`, `wellformed`,
`malformed`, `sec_per_case`, `total_cases`.

⚠️ Rows ending `-slot32k` were run **above the f16 KV cache ceiling**. Their pass rates
are valid; their `sec_per_case` measures PCIe latency rather than the model. See
[METHODOLOGY](../METHODOLOGY.md#a-context-size-without-a-cache-type-is-not-a-specification).

⚠️ `ABGEBROCHEN` = aborted, `DURCHGEFALLEN` = failed. Both kept in place rather than
deleted, with the partial case count in `total_cases`.

**`coding_swebench.tsv`** — `model`, `mode`, `repo`, `cache`, `resolved`,
`unresolved`, `empty`, `submitted`.

- `mode` is `oracle` (the target file is named) or `repomap` (the model must find it).
- **`empty` counts runs that produced no patch at all** — a distinct failure mode from
  producing a wrong one, and the most informative column in the file.
- Rows with `model = GOLD-PATCH` are **calibration**: the known-correct patch run
  through the same harness. `requests` resolves only 5 of 8 even with the gold patch,
  so three of its instances are unwinnable in this setup regardless of model.

**`coding_swebench_empty_causes.tsv`** — `model`, `repo`, `mode`, `cache`,
`instance`, `cause`, `attribution`.

The `empty` column of `coding_swebench.tsv` counts non-answers but says nothing about
why. This file opens one such run instance by instance, read out of the agent logs.
`attribution` separates what the model did from what the scaffold did — **six of nine
were the model's, three were not.** Only one run is broken down this way; the other
`empty` counts in the repository are not.

**`coding_real_task.tsv`** — `model`, `commits`, `files`, `lines`, `longest_file`,
`entry_point`, `runtime`, `status`.

⚠️ **Only the `status` column is fully trustworthy.** Two container errors broke the
iteration phase after the models' first delivery, so no model got its tests green and
the code quality of the eight that delivered is compromised. The six that produced
nothing failed *before* the first test run — that part stands. Empty cells mean the
model produced nothing to measure.

**`transcription_fasterwhisper.tsv`** — `device`, `compute_type`, `model`, `run`,
`load_s`, `transcribe_s`, `audio_s`, `realtime_factor`, `segments`, `chars`,
`host_idle`.

- Rows are in **execution order**, one fresh process each.
- `host_idle` is `verified` only where both cards were confirmed empty beforehand.
  `not_verified` means exactly that — a chat model may have been resident on the
  *other* card. The CPU rows exist in both states and agree to within 5 %.
- `segments` and `chars` are there so a silent change in output can be spotted; they
  are not a quality measure.

**`chat_belebele_reasoning.tsv`** — `model`, `harness`, `thinking`, `correct`, `n`,
`accuracy`, `tokens_total`, `tokens_median`, `tokens_mean`, `truncated_at_8192`,
`no_answer`.

- `harness` is `logprob` (one token, read the letter's probability) or `generate`
  (generate freely, extract the last standalone letter). **They are not
  interchangeable** — the same model scores 76.0 % and 88.7 %.
- The `logprob` row has token columns of 1 by construction, not by measurement.
- ⚠️ **`truncated_at_8192` is the column to read before the accuracy column.** Those
  answers were extracted from reasoning that never finished. 18 of 150 and 28 of 150.

**`throughput_looped_transformer.tsv`** — `model`, `size_gib`, `params_b`, `backend`,
`gpu`, `test`, `t_per_s`, `stddev`. `llama-bench -n 128 -p 512,4096 -pg 4096,128
-ngl 99 -r 20 -sm none -mg 0`, llama.cpp b10273. Llama-3.2-3B is the dense control at
the same scale, not a competitor.

**`image_generation*.tsv`** — four files, and the split between them is the point.

- `image_generation.tsv` and `_ab.tsv` are **measured**: seconds, MiB, and whether a
  texture defect survived a controlled change.
- `_ocr.tsv` is **measured but metric-dependent**: two different measures, because a
  required string and a free label are different questions. Read the task column
  before comparing values.
- `_verdicts.tsv` is **not a measurement.** It is one person looking at each image and
  saying pass or fail, with a note. It is in `data/` because it is the deciding result
  for this use case and hiding it in prose would be worse — but it carries no more
  authority than one careful pair of eyes.

⚠️ **Everything except `_seeds.tsv` rests on a single seed** (42). `_seeds.tsv` repeats
the two machine-measurable tasks across five, and **both headline numbers moved**: the
model reported as the only one able to render the required string hits it in 2 of 5
seeds, and the model reported as unable to hits it in 1 of 5.

⚠️ In `_seeds.tsv` the `05_schematic` rows carry a `denominator` column on purpose. The
share alone is meaningless where only one or two tokens were recognised at all — read
`value` and `denominator` together or not at all.

**`image_generation_energy.tsv`** — `model`, `seconds`, `mean_watt_chip`,
`peak_watt_chip`, `wh_per_image`, `samples`.

⚠️ The column names say `chip` on purpose. `power1_average` reads the graphics
processor, not the board and not power-supply losses; the wall-socket figure is higher
by an amount that is itself not constant. **Use these to compare models with each
other, never as an electricity bill.**

⚠️ One image per model. The spread across repeats is not measured.

**`energy_tokens.tsv`** — `model`, `phase`, `size_gib`, `tokens`, `reps`, `t_per_s`,
`compute_s`, `mean_watt_chip`, `mwh`, `tokens_per_wh`, `samples`.

`llama-bench -p 4096 -n 0` and `-p 0 -n 512`, `-r 5`, `-ngl 99 -sm none -mg 0`, fresh
process per row, card verified empty first. `phase` is `prefill` (reading) or
`erzeugung` (generating) — **they differ by a factor of 19–30 and must never be
averaged together.**

⚠️ **`mwh` covers the compute window only, not model loading.** The first version of this
file integrated across the whole wrapper, which understated the two 17 GiB MoE models by
a factor of 2.4–3.8 and produced a false architecture finding. See
[METHODOLOGY](../METHODOLOGY.md#the-measurement-window-must-contain-only-the-work-you-are-counting).

⚠️ **Read `samples` before `tokens_per_wh`.** Power is sampled at 1 Hz, so a 3.3 s
compute window yields 4 points. The `llama-3.2-3b / prefill` row is the weakest in the
file on exactly this ground — its 227.8 W sits well below the 285–290 W every longer row
reports, which makes its token figure optimistic.

⚠️ `mean_watt_chip` is `power1_average` — the graphics processor, not the board and not
power-supply losses. A floor, not an electricity bill.

**`power_throttle_low.tsv`** — `step`, `clock_ceiling_mhz`, `sclk_reached`, `pp2048`,
`tg128`, `mean_watt_chip`, `peak_watt_chip`, `watt_per_tok_s`, `samples`,
`kernel_msgs`.

Rows are in **execution order**. `step = stock` rows are the drift control, interleaved
deliberately rather than run as a block — they span the whole session and agree to
within 0.9 %, so nothing in the throttled rows is warming or driver drift.

`kernel_msgs` counts `ring`/`reset`/`VRAM is lost`/`timeout` lines appearing in `dmesg`
during that step. It is 0 everywhere here, which is the point of recording it:
[a throughput test alone will pass a card that has already reset itself](../METHODOLOGY.md#a-throughput-test-will-pass-a-broken-card).

⚠️ `mean_watt_chip` integrates over the compute window only. The earlier steps of this
curve, published in [power.md](../hardware/power.md#the-curve), were measured before that
distinction was made and are not in this file.

**`context_depth.tsv`** — `model`, `depth`, `flash_attn`, `pp2048`, `tg128`,
`mean_watt_chip`, `mwh`, `samples`.

`llama-bench -p 2048 -n 128 -d <depth> -r 3`, f16 KV cache throughout. `depth` is how
full the cache is before the measured work starts — **the axis every other table in this
repository holds at 0.**

The `flash_attn = off` rows are a deliberate second variable and are **not part of the
depth curve**; they exist to show that flash attention is worth ~1 % at depth 0 and 18 %
of generation at 32 768.

⚠️ `mwh` covers the compute window only, and power is sampled at 1 Hz — the depth-0 rows
rest on 3–6 samples. Read `samples` before quoting an energy value.

**`chat_belebele_harness.tsv`** — `model`, `harness`, `thinking`, `correct`, `n`,
`accuracy`, `tokens_total`, `tokens_median`, `tokens_mean`, `truncated`, `no_answer`,
`no_letter_in_top20`, `thinking_switch`, `max_tokens`, `seconds`.

- **`no_letter_in_top20` is the column that explains this file.** It counts questions
  where none of A/B/C/D appeared among the twenty most likely first tokens. It is 0
  everywhere except DeepSeek-R1-14B, where it is **147 of 150** — that row measures the
  harness, not the model.
- ⚠️ **`thinking_switch` says only that the chat template accepted the argument**, not
  that the model reasoned. Qwen3-30B-A3B reads `angenommen` and generated 878 against
  879 tokens with the switch off and on. **Read the token columns to see whether
  anything happened.**
- ⚠️ The three `nanbeige-4.2-3b` rows carry `-` in the token columns. Their accuracies
  were recovered from the progress log after the tokenizer wrote a `trust_remote_code`
  prompt onto stdout and corrupted the JSON line. Accuracy is sound; the counts are lost.
- ⚠️ `truncated` before `accuracy`: Qwen3.5-9B hit the 8 192-token ceiling on 25 of 150
  thinking answers.

**`chat_belebele_chattemplate.tsv`** — as `chat_belebele_harness.tsv`, plus `role` and
`request_errors`, minus `thinking_switch`.

Uses `/v1/chat/completions`, so **the chat template comes from the GGUF** rather than
from an HF tokenizer repo — half these models have no tokenizer in the local cache, and
it is the template that actually runs in production.

- `role = eichung` are calibration rows with a known expected value; `role = neu` is the
  measurement. **Read the calibration before the results.**
- ⚠️ **The `thinking` rows are not comparable with `chat_belebele_harness.tsv`** (16 384
  tokens instead of 8 192, and the reasoning field read separately — 3.3 points apart on
  calibration). The `logprob` and `generate` rows are.
- `request_errors` counts failed HTTP calls separately so they cannot pass as wrong
  answers. It is 0 in every row here.

## A note on one filename

The `qwen3-coder-30b-a3b / oracle / pytest` row was reconstructed by hand. Its source
file predates the fix that put the repository name into output filenames, and an
earlier run of the same model and mode had already been overwritten and lost. The
repository was recovered from the instance count.

That is the incident behind
[the naming rule in METHODOLOGY](../METHODOLOGY.md#put-every-varying-parameter-into-the-output-filename).

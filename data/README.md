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

**`coding_real_task.tsv`** — `model`, `commits`, `files`, `lines`, `longest_file`,
`entry_point`, `runtime`, `status`.

⚠️ **Only the `status` column is fully trustworthy.** Two container errors broke the
iteration phase after the models' first delivery, so no model got its tests green and
the code quality of the eight that delivered is compromised. The six that produced
nothing failed *before* the first test run — that part stands. Empty cells mean the
model produced nothing to measure.

## A note on one filename

The `qwen3-coder-30b-a3b / oracle / pytest` row was reconstructed by hand. Its source
file predates the fix that put the repository name into output filenames, and an
earlier run of the same model and mode had already been overwritten and lost. The
repository was recovered from the instance count.

That is the incident behind
[the naming rule in METHODOLOGY](../METHODOLOGY.md#put-every-varying-parameter-into-the-output-filename).

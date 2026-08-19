# ornith-35b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

**The best German reader measured here, 0.9733** — on a model that sat on the disk for
months measured only for code. It is a `qwen35moe` derivative and agrees with
[Qwen3.6-35B-A3B to within 0.2 % on eight depth measurements](../findings/context-depth.md#the-two-best-german-readers-are-one-model),
so the two are **one finding, not two**.

**Reasoning costs it 18.7 points** (0.9467 → 0.76) with nothing truncated — it reasons
itself away from answers it gets right when asked directly.

## German comprehension — prompt formatted by the chat template inside the GGUF, not by a HuggingFace tokenizer

Source: [`chat_belebele_chattemplate.tsv`](../data/chat_belebele_chattemplate.tsv) · interpreted in [harness-effect](../findings/harness-effect.md)

| model | role | harness | thinking | correct | n | accuracy | tokens_total | tokens_median | tokens_mean | truncated | no_answer | no_letter_in_top20 | request_errors | max_tokens | seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ornith-35b | new | logprob | off | 146 | 150 | 0.9733 | 150 | 1 | 1.0 | 0 | 0 | 0 | 0 | 1 | 39.2 |
| ornith-35b | new | generate | off | 142 | 150 | 0.9467 | 32472 | 150 | 216.5 | 3 | 0 | 0 | 0 | 1024 | 290.8 |
| ornith-35b | new | generate | on | 114 | 150 | 0.76 | 194493 | 1264 | 1296.6 | 0 | 0 | 0 | 0 | 16384 | 1539.2 |

## aider-polyglot, 225 tasks

Source: [`coding_polyglot.tsv`](../data/coding_polyglot.tsv) · interpreted in [coding](../use-cases/coding.md)

| slug | format | pass1 | pass2 | wellformed | malformed | sec_per_case | total_cases |
|---|---|---|---|---|---|---|---|
| ornith-35b | diff | 24.9 | 43.1 | 97.8 | 5 | 91.9 | 225 |
| ornith-35b-slot32k | diff | 28.4 | 61.8 | 96.9 | 7 | 220.2 | 225 |

## SWE-bench Verified

Source: [`coding_swebench.tsv`](../data/coding_swebench.tsv) · interpreted in [coding](../use-cases/coding.md)

| model | mode | repo | cache | resolved | unresolved | empty | submitted |
|---|---|---|---|---|---|---|---|
| ornith-35b | oracle | pytest-dev-pytest | q8_0 | 8 | 6 | 5 | 19 |
| ornith-35b | repomap | pylint-dev-pylint | q8_0 | 1 | 3 | 6 | 10 |
| ornith-35b | repomap | pytest-dev-pytest | q8_0 | 8 | 3 | 8 | 19 |

## throughput and energy against cache depth

Source: [`context_depth.tsv`](../data/context_depth.tsv) · interpreted in [context-depth](../findings/context-depth.md)

| model | depth | flash_attn | pp2048 | tg128 | mean_watt_chip | mwh | samples |
|---|---|---|---|---|---|---|---|
| ornith-35b | 0 | on | 2626.3 | 140.15 | 266.2 | 377.6 | 6 |
| ornith-35b | 4096 | on | 2466.7 | 134.58 | 265.2 | 371.9 | 6 |
| ornith-35b | 16384 | on | 1998.1 | 126.45 | 250.3 | 420.7 | 7 |
| ornith-35b | 32768 | on | 1580.5 | 117.69 | 249.9 | 481.3 | 8 |

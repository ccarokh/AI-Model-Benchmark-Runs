# Hetzner Inference API: the same two models, served by somebody else, in FP8

**Cited and run.** Their endpoint answered our questions; the numbers are theirs and ours side by side, with the column headers saying which is which.

| | Hetzner | Here |
|---|---|---|
| Object measured | a hosted endpoint, experimental, free | a file on a card we own |
| Precision | **FP8** | Q4_K_M |
| Hardware | not stated | RX 7900 XTX, documented |
| Reasoning | not controllable | switchable |

## What the endpoint supports — asked first, separately

Because [how you ask is worth up to 70 points here](../findings/harness-effect.md), the endpoint's behaviour was probed before anything was scored on it. Script: [`scripts/foreign/hetzner_inference.py probe`](../scripts/foreign/hetzner_inference.py).

| | |
|---|---|
| Models | `Qwen3.8-27B`, `Qwen/Qwen3.6-35B-A3B-FP8` — both text and image, 262 144 context |
| `temperature 0` | **not honoured** — two identical requests, two different texts |
| Logprobs | **none** — `/v1/completions` returns 400, only chat exists |
| Rate limit | **10 requests per 60 s**, 4 M input / 100 k output tokens per 60 s |
| Content | "We do not store the content of request and response" — their FAQ |

**No logprobs means no letter-probability harness.** Only free generation is possible there, and the comparison has to be against our free-generation figures.

## The comparison

Same 150 questions, same prompt template, same item order as the local runs. 900 questions in total, resumable, one request every 6.5 s to stay under their limit. Run 07.–08.09.2026 on a machine that does not reboot. Data in [`data/foreign_hetzner_belebele.tsv`](../data/foreign_hetzner_belebele.tsv), raw per-question in [`data/foreign_hetzner_belebele_raw.jsonl`](../data/foreign_hetzner_belebele_raw.jsonl).

| belebele `deu_Latn`, first 150 | Hetzner **FP8** | here Q4_K_M, thinking **on** | here Q4_K_M, thinking **off** |
|---|---:|---:|---:|
| Qwen3.6-35B-A3B | **0.9467** | 0.8800 | 0.9600 |
| Qwen3.8-27B | **0.9600** | 0.9133 | 0.9667 |

**FP8 does not beat Q4_K_M.** Both endpoint figures sit within 1.3 points of our thinking-off arm, inside the ±3.5-point band that n=150 resolves. Over all 900 questions: 0.9511 and 0.9533, band ±1.4.

This extends [the QAT finding](../findings/qat-vs-ptq.md), where two Q4 variants of one model scored the same at n=900. Now the step up to FP8 adds nothing measurable either.

## The caveat that stays

**The endpoint's reasoning cannot be switched off**, and the two models use it very differently there: a median of **122 characters** per answer from the 35B, **12 characters** from the 27B — the 27B replies with little more than the letter. So the comparison is not controlled on that axis. Both local arms are shown for that reason; the endpoint lands near the thinking-off one for both models.

## What it cost to get here

One nine-hour attempt was lost to a workstation reboot before this one ran — the script wrote only to stdout, and the log in `/tmp` was swept. The rule that came out of it is in [METHODOLOGY.md](../METHODOLOGY.md): a benchmark writes every partial result to a durable place, immediately, and resumes from it. This run was interrupted once by a host reboot and continued from answer 153 without losing one.

It also ran, for its first hours, on the measuring host itself — against the rule that nothing without a card belongs there. Moved to the scratch machine; the [night window](../scripts/nachtfenster.sh) was rebuilt so that a queue line has to say where it runs.

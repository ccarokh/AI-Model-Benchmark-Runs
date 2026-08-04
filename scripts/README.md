# Scripts

These are the measurement harnesses in the form they actually ran, with host
addresses and local paths pulled up into a configuration block at the top of each
file. They are published so the numbers can be checked — not as a polished tool.

## What you need

- `llama-bench` and `llama-server` from llama.cpp on a reachable host
- passwordless SSH to that host (the scripts drive it remotely)
- for the SWE-bench runs: Docker, and the official SWE-bench harness image
- for `asr/faster_whisper_bench.py`: a Python venv with `faster-whisper`, plus
  `nvidia-cublas-cu12` and `nvidia-cudnn-cu12` if you want the GPU. See the docstring
  for the two environment variables it will not run without.

## What was removed

Every script originally called into a **GPU lease helper** — a small mutex that
kept unattended benchmark runs from colliding with a production service on the same
card. Those calls are commented out and marked. If you run benchmarks on a machine
that does nothing else, you do not need it. If you do not, write one before running
anything unattended.

Two related habits are worth keeping from the originals:

- **Kill processes by a PID you obtained earlier, never by pattern.** `pkill -f
  something` matches the invocation doing the killing. Every sampler in here reports
  its PID back and is stopped by that PID.
- **A step that fails does not abort the chain.** One broken repository should not
  cost the remaining hours of GPU time.

## Files

| Script | What it measures |
|---|---|
| `hardware/rag_turn.sh` | one real RAG turn under production flags, with power sampled during the request |
| `hardware/multigpu_sustained.sh` | layer vs tensor split under sustained load, with temperature and fan proof |
| `hardware/multigpu_ratios.sh` | split-ratio sweep separating fixed overhead from slow-card drag |
| `hardware/rocm_vs_vulkan.sh` | both backends measured in the same run |
| `hardware/reference_bench.sh` | the portable reference point, upstream flags, with guards and a power trace |
| `coding/swebench_run.sh` | one repository × model × mode × cache type, agent run plus evaluation |
| `coding/night_chain.sh` | chains runs unattended with a deadline and a disk guard |
| `asr/faster_whisper_bench.py` | one `faster-whisper` run, one device, one precision |

## A warning that applies to all of them

`rag_turn.sh` **terminates every `llama-server` on the host** before it starts its
own. It has a guard against doing that while a model supervisor is running, but if
you have a production service on that card, read the script before you run it.

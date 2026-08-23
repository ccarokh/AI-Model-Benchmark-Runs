# Harnesses

One file per agent. It is everything a new harness needs — `game_run.sh` does not know a
single agent by name.

Each file provides two functions and may rely on these variables:

| Variable | Meaning |
|---|---|
| `$ziel` | the run directory on the harness host |
| `$model` | model name as the model server serves it |
| `$MESS`, `$PORT` | address of the model server on the measuring machine |
| `$ctx`, `$maxtok`, `$temp` | limits and temperature from the config |
| `$zeitlimit` | seconds after which the run is aborted |

**`agent_vorbereiten`** writes the agent's config under `$ziel` and sets ownership to
`1000:1000` — nothing inside the container runs as root.

**`agent_ausfuehren`** starts the container, mounts `$ziel/arbeit` as `/arbeit`, and writes
to `$ziel/agent.log`. Its return value is the agent's.

## What every agent needs on top

The limits belong in every config. Without them the agents guess — OpenCode fetches them
from `models.dev` and, with no network, falls back to `max_tokens=32000`. llama.cpp
silently truncates that and carries on; vLLM rejects every request. It looked like model
failure and was a harness default.

## attrappe.py

An OpenAI-compatible stub that logs every request and always answers the same. It needs no
GPU and no model, and it answers one question per agent: **does it reach our endpoint at
all** — separately from whether a model can solve the task. Four of five agents failed that
first, every time for a reason on our side.

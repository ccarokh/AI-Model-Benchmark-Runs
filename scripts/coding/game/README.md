# Agility game: the harness

What lives here is executable. **Why the task looks the way it does is not here** but in
[use-cases/agility-game.md](../../../use-cases/agility-game.md) — that is documentation for
people and reaches neither a model nor a script.

| File | Role |
|---|---|
| `aufgabe.md` | **the task, and nothing else.** Goes to the model unchanged; its fingerprint appears in every result row. German, because the models are asked in German |
| `game_run.sh` | one call, one run. Model, runtime, harness and parameters all come from a config file |
| `alle_laeufe.sh` | plays every config in turn, checking the time window before each run |
| `config/*.conf` | one file per run, named `model-description-harness.conf` |
| `harness/*.sh` | one file per agent. `game_run.sh` knows no agent by name |
| `game_messen.py` | counts what ended up in the working directory. No judgement |
| `pruefen/` | the pre-check: script syntax, then the page in a headless browser |
| `container/Dockerfile` | the sandboxed harness: five agents, no root, no GPU |
| `spiel_bewerter.py` | local server that serves each game as a real page to play |
| `referenz/` | a reference implementation, explicitly not a measuring point |

## Layout

The harness runs **sandboxed on .201**, the model server on the GPU host **.192**. Separate,
because an agent that writes files and runs commands must not be foreign load on the
measuring machine during a measurement — and because code written by a model is not run as
root on it.

```
game_run.sh config/qwen3-coder-30b-a3b-llamacpp-opencode.conf
alle_laeufe.sh llamacpp        # every matching config
python3 spiel_bewerter.py      # http://127.0.0.1:8109
```

## The pre-check answers what comes before rating

A run that produces nothing, fails to parse, throws on load or paints an empty canvas does
not need nineteen questions from a person. It is decided, and the reason is in the table.
The browser runs in a **separate container after the agent has exited** — inside the agent
image it would be a tool the model could use to open and fix its own game, which would be a
different harness than the one being measured.

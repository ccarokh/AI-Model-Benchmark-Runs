# Agility game: raw data

`urteile.tsv` — the human rating, one row per run, nineteen columns of
`ja` / `nein` / `untestbar` / empty. Empty means **not answered** and is a different thing
from `nein`.

`baseline/` — the blind run that validated the task. Not a competitor and not a measuring
point against the local models: foreign hardware, a different harness, unknown
quantisation. It answers one question — **are the nineteen criteria satisfiable at the
same time** — and the answer is yes.

Without that point a table full of "no" cannot be read: weak models and a task that is too
hard or too vague look identical in it.

| | |
|---|---|
| Model | claude-opus-5 via Claude Code |
| Conditions | empty directory outside the project, one single message, no history |
| Task | `aufgabe.md`, fingerprint `897f85484354`, verified character-identical |
| Duration | 1 658 s · 57 tool calls · 292 690 output tokens |
| Result | **19 of 19 met** |

Getting there took two attempts. The first blind run failed on two points: the tunnel
looked like a circus tent, and the dog visibly ran *past* it rather than through. Both were
**gaps in the task text**, not limits of the model — the text only demanded that hurdle and
tunnel be distinguishable, and a tent satisfies that. Since then it says what makes a
tunnel recognisable, and that the dog has to disappear inside it.

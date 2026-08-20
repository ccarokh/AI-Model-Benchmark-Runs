# The agility game: one task, every coding model, judged by a human

**This page is for people.** It explains where the task came from, what it demands and
what the harness contributes to the result. Nothing here reaches a model or a script.

**The prompt itself is [`aufgabe.md`](../scripts/coding/game/aufgabe.md).** That file
contains the task and nothing else: the harness sends it verbatim, byte for byte, and every
result row carries a fingerprint of its content.

Splitting the two was itself a correction. The prompt used to live inside this document
between two `---` lines, and the harness cut it out with `awk`. A horizontal rule inside
the prompt would have silently truncated the task, and nobody would have seen it in the
results — only that every model suddenly got worse.

## The reference run, and why it needs an empty room

A reference exists for one question: are the criteria simultaneously satisfiable? Without
it, a table full of "no" cannot be read — weak models and an over-hard or under-specified
task look identical.

**The first reference was written inside the session that also wrote the task.** Its author
knew twenty rounds of feedback — the stuck duck key, the legs at the wrong end, the tunnel
mouth on the wrong side — and knew the 19 rating questions. That measures the
conversation, not the task.

**A blind reference has to run in an empty directory outside the project.** A fresh window
in the project folder is not enough: it loads the project instructions, the memory index
and, at first glance, the repository files — in which the task, the rating questions and
every correction are written down. Both runs are kept, labelled, and the difference between
them is itself a measurement: what prior knowledge is worth.

## Where the requirements come from

The reference point is the Chrome dinosaur game, and several requirements were added
after looking at it rather than at our own draft: **groups of up to three obstacles**, a
**high score that survives a restart**, a **day/night switch**, and the restart control
sitting **inside the play field**. Each is countable, and each demands something the
minimum viable jump loop does not have — state that outlives a run, a second visual mode,
and a jump whose *length* is sized against a group rather than a single obstacle.

## Why the task is shaped this way

**Two obstacles requiring two different actions** is the point. One obstacle type is a
jump loop any model can produce from memory of the Chrome dinosaur game; the second
forces state the first does not — a duck pose with different collision geometry, and an
input that must *not* solve the other obstacle.

**"Jumping does not help at the tunnel"** is stated explicitly because it is the rule most
likely to be omitted, and its absence is countable rather than a matter of taste.

**What a tunnel looks like is spelled out, and that was a correction too.** Two
independent runs — one with the full conversation behind it, one blind — both drew
something arch-shaped that read as a circus tent. The text at the time only demanded that
hurdle and tunnel be *distinguishable*, and a tent satisfies that: it is clearly not a
hurdle. When two attempts fail the same way, the text permits it.

**The keys are named in the task, and that was a correction.** The first version left the
choice to the model. Every model then picked its own — space, arrow keys, W and S — and a
rater who pressed the wrong one would record "the hurdle cannot be jumped" for a game that
jumps perfectly well. **The measurement would have been of the rater's guess.** Naming the
keys also makes a wrong binding countable instead of invisible.

**Every key in the table is mandatory, and that is deliberate.** An earlier version made
space and control mandatory and the rest optional — which puts the rater back where they
started: pressing W, getting nothing, and not knowing whether the game is broken or merely
minimal. With the whole list mandatory, a key that does nothing is a failed requirement,
countable, and the same for every model.

**Graphics are drawn in code, and that is not a simplification.** An earlier version let
the model delegate the artwork to an image model by writing its own prompts. It was
dropped after one run: the image stack has no alpha channel, the model never sees what
came back, and one prompt yields one picture rather than an animation strip. The rated
result was then half ours — opaque beige boxes on a blue field — and the one line in the
rating that belonged to the model alone ("the hurdle cannot be jumped") drowned in it.
**A test whose outcome is half the harness's artwork does not measure the model.**

## Every row is a combination, not a model

A result here is never "what this model can do". It is **model × harness × runtime ×
parameters**, and a comparison is only valid where exactly **one** of those differs. That
is not a caveat bolted on afterwards — it decides which questions this series can answer
at all:

| Comparison | Available here |
|---|---|
| Model vs model, same harness and runtime | **yes** — the local field, OpenCode on llama.cpp |
| Runtime vs runtime, same model and harness | **one model only** — mistral-small-3.2-24b is the only one vLLM loads from our GGUF weights |
| Harness vs harness, same model and runtime | **no** — OpenCode is the only agent running locally |
| Cloud model vs cloud model, same harness | **yes** — Claude Code, one generation against another |
| Cloud vs local, any configuration | **no** — see the [limitation in the README](../README.md#open) |

The third row is the expensive gap. The harness is the largest unmeasured variable in this
repository — on belebele it was worth [up to 70 points](../findings/harness-effect.md) —
and it is exactly the axis where we have a single data point. A second agent on the same
seven models would be worth more than seven more models on the same agent.

## What is measured here besides the model

Not a caveat added afterwards — it is why every harness parameter travels in every result
row. On belebele the harness was worth
[up to 70 points](../findings/harness-effect.md), and there is no reason to assume
it is worth less here.

| Decision | What it does to the result |
|---|---|
| **the agent** | OpenCode drives the model: it may write files, run commands and read their output. A model that recovers from its own error scores where a single call could not show it |
| **the runtime** | llama.cpp and vLLM both serve every model. Tool calls travel through the runtime's template and parser, so a model can pass on one and fail on the other |
| **`max_tokens`** | whoever writes at length gets cut off — recorded, because half a game otherwise reads as a bad game |
| **`temperature = 0.2`** | a choice, not a constant |
| **chat template** | the model is addressed the way its own file says, which differs per model |

**Both runtimes are always measured, and a failure is a result.** If a model's tool calls
do not survive one runtime's parser, that is recorded as the outcome for that runtime —
not routed around by quietly using the other one.

**The rating is human.** Whether the dog is a dog, whether the hurdle can actually be
jumped, whether the game is playable at all — no script decides that. **19 yes / no /
untestable questions per run**, and the count is not decoration: every question asks exactly
one thing, so a "no" points at what failed instead of at a bundle. "Hurdle and tunnel both
look right" was one question once, and a "no" left nobody able to say which of the two was
wrong.

*Untestable* is a real answer, not an escape. If the game never starts, nobody saw whether
it speeds up over time — forcing a "no" there would record an observation that was never
made.

**This is why none of these numbers belong on a leaderboard.** Everything else in this
repository is machine-measured and can be recomputed from the raw data. Here a person
played each game and decided. That is the only way to answer "is the dog a dog", and it is
also the reason the results are not comparable with anyone else's.

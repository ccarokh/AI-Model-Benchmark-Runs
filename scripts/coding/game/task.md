# The task, identical for every model

The model works in an empty directory with a full agentic harness: it may create
files, run commands, and see the output of what it ran. What it leaves behind is
the result.

---

Schreibe ein vollständiges Browser-Spiel in dieses Verzeichnis. Es muss sich mit
`index.html` im Browser öffnen lassen.

Das Spiel ist ein Agility-Parcours mit einem **Hund**, der von links nach rechts läuft
(Seitenansicht, der Hund bleibt an derselben Stelle, die Welt scrollt).

**Zwei Hindernisarten, die zwei verschiedene Aktionen verlangen:**

1. **Hürden** — der Hund muss darüber **springen**
2. **Tunnel** — der Hund muss sich **ducken** und hindurchlaufen

**Spielanforderungen:**

- **Tastenbelegung. Jede einzelne dieser Tasten muss funktionieren:**

  | Aktion | Tasten |
  |---|---|
  | Springen | **Leertaste**, **W** |
  | Ducken (gedrückt halten) | **Strg**, **S** |
  | Neustart | **R**, **Enter** |

  Das ist keine Auswahl, sondern eine Liste: alle genannten Tasten sind Pflicht.
  Andere Tasten für diese Aktionen sind nicht erlaubt. **Schreibe die Belegung
  sichtbar auf die Seite.**
- Springen hilft beim Tunnel **nicht**, Ducken hilft bei der Hürde **nicht**
- Punktestand, der mit der Zeit steigt
- **Highscore neben dem laufenden Stand.** Er überlebt den Neustart: wer 40 Punkte
  schafft, neu startet und bei 12 stirbt, sieht weiterhin 40 als besten Wert.
- Die Geschwindigkeit nimmt im Laufe des Spiels zu
- **Tag- und Nachtwechsel:** im Verlauf schlägt die Darstellung von hell nach dunkel
  um und wieder zurück
- Kollision beendet das Spiel und zeigt das Ergebnis an
- **Neustart, erst nach dem Spielende:** die Tasten **R** und **Enter** *und* eine
  anklickbare Schaltfläche **im Spielfeld**, nicht darunter. Mit der Maus allein muss
  ein neuer Lauf möglich sein. Während gespielt wird, ist die Schaltfläche nicht da —
  sie zieht sonst nur den Tastaturfokus vom Spiel weg.

**Die Grafik gehört zur Aufgabe.** Hund, Hürden und Tunnel entstehen im Code — Canvas,
SVG oder CSS.

- Der **Hund** muss als Hund erkennbar sein und beim Ducken anders aussehen als beim Laufen.
- **Hürde und Tunnel** müssen als das erkennbar sein, was sie sind, und voneinander
  unterscheidbar. Zwei gleich aussehende Rechtecke erfüllen das nicht — man muss auf einen
  Blick wissen, ob zu springen oder zu ducken ist.

**Das Spiel muss spielbar sein.** Die Sprunghöhe muss zur Hürdenhöhe passen und die
Tunnelöffnung zur geduckten Haltung, mit genug Spielraum, dass ein Mensch es zur richtigen
Zeit schafft — nicht nur rechnerisch in einem Zeitfenster von Millisekunden.

**Bis zu drei Hürden können direkt hintereinander stehen, und eine Gruppe muss mit einem
Sprung zu schaffen sein.** Das gilt auch bei der höchsten Geschwindigkeit, die im Spiel
vorkommt. Rechne die Sprungweite gegen die Gruppenbreite, statt es zu schätzen.

**Technische Vorgaben:**

- Einstiegspunkt ist `index.html`. Wie du den Rest aufteilst, entscheidest du.
- Keine externen Dateien aus dem Netz: kein CDN, keine Schriftarten von außen, keine
  Bibliothek, die beim Öffnen nachgeladen wird. Das Spiel muss ohne Internet laufen.
- Kein Build-Schritt. Die Datei im Browser öffnen muss reichen.

---

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

## What is measured here besides the model

Not a caveat added afterwards — it is why every harness parameter travels in every result
row. On belebele the harness was worth
[up to 70 points](../../../findings/harness-effect.md), and there is no reason to assume
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
jumped, whether the game is playable at all — no script decides that. Eight yes/no/untestable
questions per run, and *untestable* is a real answer: if the game never starts, nobody saw
whether it speeds up over time.

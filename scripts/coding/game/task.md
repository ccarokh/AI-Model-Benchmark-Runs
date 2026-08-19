# The task, identical for every model

One prompt, no follow-up turns. The model sees exactly this and nothing else.

---

Schreibe ein vollständiges Browser-Spiel. Das Spiel ist ein Agility-Parcours mit einem
**Hund**, der von links nach rechts läuft (Seitenansicht, der Hund bleibt an derselben
Stelle, die Welt scrollt).

**Zwei Hindernisarten, die zwei verschiedene Aktionen verlangen:**

1. **Hürden** — der Hund muss darüber **springen**
2. **Tunnel** — der Hund muss sich **ducken** und hindurchlaufen

**Spielanforderungen:**

- Steuerung über Tastatur: eine Taste zum Springen, eine zum Ducken
- Springen hilft beim Tunnel **nicht**, Ducken hilft bei der Hürde **nicht**
- Punktestand, der mit der Zeit steigt
- Die Geschwindigkeit nimmt im Laufe des Spiels zu
- Kollision beendet das Spiel, mit Anzeige des Ergebnisses und Neustart-Möglichkeit

**Die Grafik gehört zur Aufgabe.** Du hast zwei Möglichkeiten, und du entscheidest:

**Weg A — selbst zeichnen.** Hund, Hürden und Tunnel mit Canvas, SVG oder CSS im Code
erzeugen. Keine externen Dateien.

**Weg B — von einem Bildmodell erzeugen lassen.** Dann musst du die Prompts selbst
liefern. Gib am Ende deiner Antwort einen Block genau in dieser Form aus:

```
=== BILDER ===
dateiname.png | breite x hoehe | prompt auf Englisch
=== ENDE BILDER ===
```

Beispielzeile: `hund_lauf.png | 256x256 | a side view of a running dog, flat vector style`

Die Bilder werden erzeugt und **neben die HTML-Datei gelegt**; dein Code muss sie unter
genau diesen Dateinamen laden. Denk daran, was ein Spiel braucht: mehrere Laufphasen für
eine Animation, eine Duckhaltung, die Hindernisse, gegebenenfalls Hintergrund.

**Technische Vorgaben:**

- Eine HTML-Datei plus die Bilddateien, die du selbst angefordert hast. Sonst nichts.
- Kein externes CSS oder JavaScript, keine CDN-Einbindung, keine Schriftarten von außen.
  Das Spiel muss offline laufen.
- Kein Build-Schritt. Im Browser öffnen muss reichen.
- Gib zuerst **nur** den Dateiinhalt aus, beginnend mit `<!DOCTYPE html>`, ohne
  Erklärung. Der Bilderblock, falls du Weg B wählst, kommt danach.

---

## Why the task is shaped this way

**Two obstacles requiring two different actions** is the point. One obstacle type is a
jump loop any model can produce from memory of the Chrome dinosaur game; the second
forces state the first does not — a duck pose with different collision geometry, and an
input that must *not* solve the other obstacle.

**"Jumping does not help at the tunnel"** is stated explicitly because it is the rule most
likely to be omitted, and its absence is countable rather than a matter of taste.

**Graphics are part of the deliverable, and the route is the model's choice.** That turns
one task into two measurements at once:

- a model that draws in code is judged on whether the dog looks like a dog
- a model that delegates is judged on **whether its prompts are usable** — the right
  assets for a game, at sizes that fit, described well enough that the image model
  produces something loadable

**The second route is the harder one and nobody is forced into it.** Choosing it badly —
asking for one image where an animation needs several, forgetting the duck pose, naming
files the code never loads — is a decomposition failure, and it is visible without
judging any pixel.

⚠️ **The image model is a second variable.** A game can fail because its prompts were
poor or because the image model could not render them; the two are separated by keeping
the prompts, the generated images and the running game side by side in the rating tool.
Our image models already have
[measured limits](../../../use-cases/image-generation.md) — three tasks nobody passed —
so a bad asset is not automatically the coder's fault.

**Output the file first** so the harness does not have to guess where code starts. Models
that ignore that are informative in themselves — a countable failure, like an empty patch.

## This measures the harness as well as the model

Not a caveat added afterwards — it is why the harness parameters travel in every result
row. On belebele the harness was worth
[up to 70 points](../../../findings/harness-effect.md), and there is no reason to assume
it is worth less here.

Five decisions in this harness carry the result and are not properties of any model:

| Decision | What it does to the result |
|---|---|
| **`turns = 1`** | a model that would fix its own bug given a second turn is penalised for not getting one |
| **`max_tokens = 16384`** | whoever writes at length gets cut off — `truncated` is recorded, because half a game otherwise reads as a bad game |
| **`temperature = 0.2`** | a choice, not a constant |
| **chat template from the GGUF** (`--jinja`) | the model is addressed the way its own file says, which differs per model |
| **HTML extracted by regex** | a model that formats its answer differently loses to our parser, not on ability |

**The first one is the largest.** An agentic harness — aider, or any loop that shows the
model its own console errors — is a different measurement of the same models, and our
coding ranking [has already inverted once](../../../use-cases/coding.md) when the harness
changed from naming the target file to making the model find it.

**Planned second harness, same task, one variable:** one repair turn, in which the model
receives the browser console output from its own file and may correct it. The difference
between the two runs is what a second turn is worth — which is a statement about the
harness, and it belongs next to any statement about the models.

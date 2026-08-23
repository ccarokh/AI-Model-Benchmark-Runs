# Versionen

**Die Versionsgeschichte steht bei der jeweiligen Maschine**, nicht hier. Genau dafuer
sind die Systeme in eigene Dateien getrennt: eine Maschine aendert sich, ohne dass die
anderen sich aendern, und wer ihre Zahlen liest, braucht ihren Verlauf daneben — nicht
drei Verzeichnisse weiter.

| | |
|---|---|
| [System A](system-a.md#verlauf) | v1.0 bis v1.5 — zweite Karte, ROCm, zweiter llama.cpp-Baum, stable-diffusion.cpp |
| [System B](system-b.md#verlauf) | v1.0 |
| [System C](system-c.md#verlauf) | v1.0 — frisch aufgesetzt |

## Warum ueberhaupt Versionen

Beide Dauerrechner sind Rolling-Release, und beide haben waehrend der Messzeit Hardware
bekommen. **Ein Ergebnis gehoert deshalb zu einer System-*Version*, nicht zu einer
Maschine.** Aendert sich etwas am Stapel oder an der Hardware, zaehlt die Version hoch,
und aeltere Ergebnisse bleiben an dem Zustand haengen, der sie erzeugt hat.

Das ist kein Formalismus. Die PCIe-Breite von System A war bis zum 3. August ×16 und ist
seitdem ×8 — wer die heutige Momentaufnahme fuer eine Systemeigenschaft haelt, ordnet
jede aeltere Messung falsch ein.

## Modelldateien

Pinned by **SHA256 against a manifest**, with the upstream repository commit recorded
alongside. "Same model" means the same bytes, not the same name — two files carrying
the same model name were found to be a duplicate pair this way, and two others have
lost their upstream repository and are marked as such.

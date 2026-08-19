# Agility-Spiel: Prüfstand

Was hier liegt, ist ausführbar. **Warum die Aufgabe so aussieht, steht nicht hier,
sondern in [use-cases/agility-game.md](../../../use-cases/agility-game.md)** — das ist
Dokumentation für Menschen und erreicht weder ein Modell noch ein Skript.

| Datei | Rolle |
|---|---|
| `aufgabe.md` | **die Aufgabe, sonst nichts.** Geht unverändert an das Modell; ihr Fingerabdruck steht in jeder Ergebniszeile |
| `game_run.sh` | ein Aufruf, ein Lauf. Modell, Laufzeit, Prüfstand und Parameter kommen aus einer Konfiguration |
| `alle_laeufe.sh` | spielt alle Konfigurationen ab, mit Zeitfensterprüfung vor jedem Lauf |
| `config/*.conf` | eine Datei je Lauf, Name = `modell-beschreibung-prüfstand.conf` |
| `game_messen.py` | zählt aus, was im Arbeitsverzeichnis liegt. Kein Urteil |
| `container/Dockerfile` | der gekapselte Prüfstand: OpenCode, kein root, keine GPU |
| `spiel_bewerter.py` | lokaler Server, der jedes Spiel als echte Seite zum Spielen ausliefert |
| `referenz/` | ein von Hand nachgebauter Vergleichslauf, ausdrücklich kein Messpunkt |

## Aufbau

Der Prüfstand läuft **gekapselt auf .201**, der Modellserver an der Karte auf **.192**.
Getrennt, weil ein Agent, der Dateien schreibt und Befehle ausführt, während einer Messung
keine Fremdlast auf dem Messrechner sein darf — und weil fremd erzeugter Code nicht als
root auf dem Messrechner ausgeführt wird.

```
game_run.sh config/qwen3-coder-30b-a3b-llamacpp-opencode.conf
alle_laeufe.sh llamacpp        # alle passenden Konfigurationen
python3 spiel_bewerter.py      # http://127.0.0.1:8109
```

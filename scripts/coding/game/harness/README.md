# Prüfstände

Eine Datei je Agent. Sie ist alles, was ein neuer Prüfstand braucht — `game_run.sh`
kennt keinen einzigen Agentennamen.

Jede Datei liefert zwei Funktionen und darf sich auf diese Variablen verlassen:

| Variable | Bedeutung |
|---|---|
| `$ziel` | Laufverzeichnis auf dem Prüfstandsrechner |
| `$model` | Modellname, wie ihn der Modellserver ausliefert |
| `$MESS`, `$PORT` | Adresse des Modellservers auf dem Messrechner |
| `$ctx`, `$maxtok`, `$temp` | Grenzen und Temperatur aus der Konfiguration |
| `$zeitlimit` | Sekunden, nach denen abgebrochen wird |

**`agent_vorbereiten`** legt die Konfiguration des Agenten unter `$ziel` an und setzt
die Rechte auf `1000:1000` — im Behälter arbeitet niemand als root.

**`agent_ausfuehren`** startet den Behälter, hängt `$ziel/arbeit` als `/arbeit` ein und
schreibt nach `$ziel/agent.log`. Rückgabewert ist der des Agenten.

## Was jeder Agent zusätzlich braucht

Die Grenzen gehören in jede Konfiguration. Ohne sie raten die Agenten — OpenCode holt
sie von `models.dev` und fällt ohne Netz auf `max_tokens=32000` zurück. llama.cpp
beschneidet das stillschweigend, vLLM lehnt jede Anfrage ab. Das sah aus wie
Modellversagen und war eine Voreinstellung.

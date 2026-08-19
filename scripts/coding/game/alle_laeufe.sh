#!/bin/bash
# Spielt alle Konfigurationen unter config/ nacheinander ab.
#
#   alle_laeufe.sh              # alles
#   alle_laeufe.sh qwen3.8      # nur passende Dateinamen
#
# Der einzelne Lauf bleibt einzeln aufrufbar:
#   game_run.sh config/qwen3.8-27b-standard-direkt.conf
#
# Ein fehlgeschlagener Lauf beendet die Reihe NICHT -- sonst kostet ein Modell,
# dessen Server nicht hochkommt, die ganze Nacht.
set -u
HIER=$(dirname "$(readlink -f "$0")")
FILTER=${1:-}
n=0; ok=0
for c in "$HIER"/config/*.conf; do
  [ -e "$c" ] || { echo "Keine Konfigurationen unter $HIER/config/"; exit 2; }
  [ -n "$FILTER" ] && case "$(basename "$c")" in *"$FILTER"*) ;; *) continue;; esac
  n=$((n+1))
  echo "--- $(basename "$c") ---"
  if "$HIER/game_run.sh" "$c"; then ok=$((ok+1)); fi
done
echo "=== ALLE LAEUFE DURCH: $ok von $n ==="
echo FERTIG_GAME

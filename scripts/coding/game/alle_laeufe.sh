#!/bin/bash
# Spielt alle Konfigurationen unter config/ nacheinander ab.
#
#   alle_laeufe.sh              # alles
#   alle_laeufe.sh qwen3.8      # nur passende Dateinamen
#
# Der einzelne Lauf bleibt einzeln aufrufbar:
#   game_run.sh config/qwen3-coder-30b-a3b-llamacpp-opencode.conf
#
# ZEITFENSTER: die Karte wird tagsueber gebraucht, gemessen wird 23:00-11:00.
# Fuer den Zeitgeber auf dem Messrechner ist die ganze Reihe EIN Schritt, der
# ueber Stunden laufen kann -- deshalb prueft sie das Fenster selbst, vor jedem
# einzelnen Lauf, und hoert auf, wenn es zugeht. Ein angefangener Lauf laeuft
# noch zu Ende; ihn mittendrin abzuschneiden erzeugt ein halbes Ergebnis, das
# spaeter wie ein schlechtes Modell aussieht.
#
# Ein fehlgeschlagener Lauf beendet die Reihe NICHT -- sonst kostet ein Modell,
# dessen Server nicht hochkommt, die ganze Nacht.
set -u
HIER=$(dirname "$(readlink -f "$0")")
FILTER=${1:-}
VON=${FENSTER_VON:-23}; BIS=${FENSTER_BIS:-11}

im_fenster(){
  [ "${FENSTER_AUS:-0}" = 1 ] && return 0
  local h; h=$(date +%-H)
  if [ "$VON" -gt "$BIS" ]; then [ "$h" -ge "$VON" ] || [ "$h" -lt "$BIS" ]
  else [ "$h" -ge "$VON" ] && [ "$h" -lt "$BIS" ]; fi
}

n=0; ok=0; liegen=0
for c in "$HIER"/config/*.conf; do
  [ -e "$c" ] || { echo "Keine Konfigurationen unter $HIER/config/"; exit 2; }
  [ -n "$FILTER" ] && case "$(basename "$c")" in *"$FILTER"*) ;; *) continue;; esac
  if ! im_fenster; then
    liegen=$((liegen+1)); echo "--- $(basename "$c"): ausserhalb 23:00-11:00, bleibt liegen"
    continue
  fi
  n=$((n+1))
  echo "--- $(basename "$c") ---"
  if "$HIER/game_run.sh" "$c"; then ok=$((ok+1)); fi
done
echo "=== REIHE DURCH: $ok von $n gelaufen, $liegen liegengeblieben ==="
echo FERTIG_GAME

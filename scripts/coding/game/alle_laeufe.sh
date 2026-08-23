#!/bin/bash
# Plays every configuration under config/, one after the other.
#
#   alle_laeufe.sh              # everything
#   alle_laeufe.sh qwen3.8      # only matching filenames
#
# A single run stays individually callable:
#   game_run.sh config/qwen3-coder-30b-a3b-llamacpp-opencode.conf
#
# TIME WINDOW: the card is needed during the day. To the scheduler on the
# measuring machine this whole series is ONE step that can run for hours, so it
# checks the window itself before every single run and stops when the window
# closes. A run already started finishes; cutting it off mid-way produces half a
# result, which later looks like a bad model.
#
# A failed run does NOT end the series -- otherwise one model whose server fails
# to come up costs the entire night.
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

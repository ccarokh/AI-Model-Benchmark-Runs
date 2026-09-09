#!/bin/bash
# Night window -- runs on the CONTROLLER, measures on the TARGET.
#
# WHY THAT WAY ROUND. The old version lived on the measuring machine and ran
# every queue line there with `bash -c`. So anything the queue mentioned landed
# on the measured host whether it needed the card or not -- and on 07.09.2026 a
# script that only talks to a foreign HTTP endpoint sat on that machine while
# the window was measuring. The rule against extra load on the measuring host
# exists precisely so that question never has to be argued; an architecture
# where the rule can be broken by accident is the wrong architecture.
#
# `bench` already works this way and says so in its own config: only the
# measurement and its power sampler belong on the measured machine; argument
# parsing, the queue and the results stay on the controller.
#
# EVERY QUEUE LINE SAYS WHERE IT RUNS. A line beginning with `@ziel` is executed
# on the measuring host over ssh. Everything else runs here. There is no default
# that quietly puts work on the card's machine -- that default is what went
# wrong.
#
# THE LOG LIVES HERE. When the target rebooted mid-window on 08.09. its log went
# with it. The controller keeps its own record of what it asked for.
#
# THREE HARD RULES, unchanged from the version that earned them:
#   0. No measurement without a granted GPU lease. llm-runtime provides one
#      (/_manager/lease); it is preemptible, and the tenant only learns that at
#      its next heartbeat -- so the heartbeat checks the answer instead of
#      discarding it.
#   1. The window is checked before EVERY step, not only at the start.
#   2. At the closing hour everything is torn down, mid-run if necessary.
set -u
ZIEL=${ZIEL:-root@192.168.40.192}
ZIEL_HOST=${ZIEL#*@}
E=${E:-/root/nacht}
L=$E/nachtfenster.log
D=/sys/class/drm/card1/device
RUNTIME=${RUNTIME:-http://$ZIEL_HOST:8080}
PACHT_SCHLUESSEL=${PACHT_SCHLUESSEL:-/etc/bench/lease.token}
PACHT_ID=""; HERZ=""; WACHHUND=""
WARTESCHLANGE=${WARTESCHLANGE:-$E/warteschlange.txt}
START_STD=${START_STD:-23}
ENDE_STD=${ENDE_STD:-11}

mkdir -p "$E"
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }
# Everything that touches the card goes through here, so there is exactly one
# place where remote execution happens and it is visible in the log.
# -n is not optional: without it ssh reads stdin, and stdin here is the queue
# file the loop is reading from. The first remote step then swallows the rest of
# the queue and the window ends reporting one step where there were several.
auf_ziel(){ ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$ZIEL" "$@"; }

im_fenster(){
  h=$(date +%-H)
  if [ "$START_STD" -lt "$ENDE_STD" ]; then
    [ "$h" -ge "$START_STD" ] && [ "$h" -lt "$ENDE_STD" ]
  else
    [ "$h" -ge "$START_STD" ] || [ "$h" -lt "$ENDE_STD" ]
  fi
}

pacht_nehmen(){
  t=$(cat "$PACHT_SCHLUESSEL" 2>/dev/null) || { sag "kein Pacht-Token"; return 1; }
  a=$(curl -s -m 15 -X POST "$RUNTIME/_manager/lease" \
        -H "x-lease-token: $t" -H "Content-Type: application/json" \
        -d '{"holder":"nachtfenster"}' 2>/dev/null)
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  if [ -z "$PACHT_ID" ]; then
    # Only the first refusal is logged; the waiting loop calls this once a minute.
    [ "${PACHT_STILL:-}" = ja ] || sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"
    PACHT_STILL=ja
    return 1
  fi
  PACHT_STILL=""
  export PACHT_ID
  sag "Pacht $PACHT_ID gehalten"
  # The heartbeat CHECKS its answer. The old one ended in `|| true`, so when the
  # service revoked the lease -- fourteen seconds after granting it, on 07.09. --
  # nothing noticed. The service says outright that the tenant learns at its
  # next heartbeat; discarding that answer discards the only notification there is.
  ( while :; do sleep 120
      code=$(curl -s -o /dev/null -w '%{http_code}' -m 15 -X POST \
              "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" -H "x-lease-token: $t" 2>/dev/null)
      if [ "$code" != 200 ]; then
        echo "[$(date '+%d.%m. %H:%M:%S')] PACHT VERLOREN (HTTP $code) -- Messung wird abgebrochen" >> $L
        rm -f "$E/.pacht_gilt"
        kill -TERM $$ 2>/dev/null
        exit 1
      fi
    done ) & HERZ=$!
  touch "$E/.pacht_gilt"
  return 0
}

pacht_zurueck(){
  [ -n "$HERZ" ] && kill $HERZ 2>/dev/null
  [ -z "$PACHT_ID" ] && return
  curl -s -m 15 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" \
    -H "x-lease-token: $(cat "$PACHT_SCHLUESSEL" 2>/dev/null)" 2>/dev/null
  sag "Pacht $PACHT_ID zurueckgegeben"
  PACHT_ID=""
}

aufraeumen(){
  pacht_zurueck
  [ -n "$WACHHUND" ] && kill $WACHHUND 2>/dev/null
  # Reset clocks on the TARGET in case a throttling step was interrupted.
  auf_ziel "echo r > $D/pp_od_clk_voltage 2>/dev/null;
            echo c > $D/pp_od_clk_voltage 2>/dev/null;
            echo auto > $D/power_dpm_force_performance_level 2>/dev/null;
            HW=\$(echo $D/hwmon/hwmon*/|cut -d' ' -f1); echo 291000000 > \$HW/power1_cap 2>/dev/null" 2>/dev/null
  rm -f "$E/.pacht_gilt"
}
trap aufraeumen EXIT INT TERM

im_fenster || { sag "ausserhalb ${START_STD}:00-${ENDE_STD}:00 -- nichts gestartet"; exit 0; }
[ -s "$WARTESCHLANGE" ] || { sag "Warteschlange leer"; exit 0; }
auf_ziel true 2>/dev/null || { sag "Messhost $ZIEL nicht erreichbar -- Fenster endet hier"; exit 1; }
# Wait for the lease instead of giving up on it. On 08.09. this window asked at
# 23:00:16, was told the card was leased with 284 seconds left, and cancelled
# twelve hours of measurement over five minutes. Another batch job holds the
# card sometimes -- that is the lease working, not a failure.
#
# The other holder here is a cron entry on this same machine at the same minute
# (abend_polyglot). Two schedulers on one card is a thing to fix separately;
# this loop makes the collision cost nothing either way.
warte_auf_pacht(){
  for versuch in $(seq 1 240); do          # bis zu 4 Stunden, im Fenster
    im_fenster || { sag "Fenster zu, waehrend auf die Pacht gewartet wurde"; return 1; }
    pacht_nehmen && return 0
    [ $versuch = 1 ] && sag "  Karte ist gepachtet -- warte, statt das Fenster abzusagen"
    sleep 60
  done
  sag "vier Stunden keine Pacht bekommen -- Fenster endet hier"
  return 1
}
warte_auf_pacht || exit 0

sag "=== Fenster auf ($(date +%H:%M), bis ${ENDE_STD}:00), Ziel $ZIEL ==="

( while :; do
    h=$(date +%-H)
    if ! { { [ "$START_STD" -lt "$ENDE_STD" ] && [ "$h" -ge "$START_STD" ] && [ "$h" -lt "$ENDE_STD" ]; } ||
           { [ "$START_STD" -ge "$ENDE_STD" ] && { [ "$h" -ge "$START_STD" ] || [ "$h" -lt "$ENDE_STD" ]; }; }; }; then
      echo "[$(date '+%H:%M:%S')] WACHHUND: Fenster zu, breche ab" >> $L
      pkill -P $$ 2>/dev/null; kill -TERM $$ 2>/dev/null; exit 0
    fi
    sleep 60
  done ) & WACHHUND=$!

erledigt=0
while read -r zeile; do
  case "$zeile" in ""|\#*) continue ;; esac
  im_fenster || { sag "Fenster zu -- Rest der Warteschlange bleibt liegen"; break; }
  [ -f "$E/.pacht_gilt" ] || { sag "Pacht weg -- der Rest bleibt liegen"; break; }

  # Where does this line run? Explicit, never inferred.
  case "$zeile" in
    @ziel\ *) wo=ziel; befehl=${zeile#@ziel } ;;
    *)        wo=hier; befehl=$zeile ;;
  esac

  if [ $wo = ziel ]; then
    # Card free? With a lease held, llm-runtime is the authority -- it grants
    # only when the card is free enough and refuses interactive requests after.
    frei=nein
    [ -n "$PACHT_ID" ] && frei=ja
    for i in $(seq 1 30); do
      [ $frei = ja ] && break
      z=$(auf_ziel "echo \$(( \$(cat $D/mem_info_vram_used)/1048576 )) \$(pgrep -x llama-server|wc -l)" 2>/dev/null)
      set -- $z
      [ "${1:-9999}" -lt 500 ] && [ "${2:-1}" -eq 0 ] && { frei=ja; break; }
      sleep 20
    done
    [ $frei = ja ] || { sag "  Karte belegt -- uebersprungen: $befehl"; continue; }
  fi

  sag "--- [$wo] $befehl ---"
  t0=$(date +%s)
  if [ $wo = ziel ]; then auf_ziel "$befehl" >> $L 2>&1; else bash -c "$befehl" >> $L 2>&1; fi
  rc=$?
  sag "--- rc=$rc nach $(( ($(date +%s) - t0) / 60 )) min ---"
  erledigt=$((erledigt+1))
done < "$WARTESCHLANGE"

kill $WACHHUND 2>/dev/null
sag "=== Fenster-Ende, $erledigt Schritte gelaufen ==="

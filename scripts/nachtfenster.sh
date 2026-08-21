#!/bin/bash
# Nachtfenster 00:00-08:00 -- deckungsgleich mit LLM_RUNTIME_BATCH_WINDOW.
# Tagsueber gehoert die Karte dem Betreiber.
#
# Frueher stand hier 23:00-11:00, waehrend llm-runtime Pachten nur zwischen
# 00:00 und 08:00 gewaehrt. Drei der zwoelf Stunden waren damit gar nicht
# koordinierbar, und in der Nacht zum 21.08. hat genau das eine Messung
# gekostet: der Abgleich mass gegen eine umkaempfte Karte, beide Bauten kamen
# auf 3,3 statt 103 Token/s -- und der Pruefstand haette den Versionswechsel
# durchgewunken, weil beide Seiten gleich falsch gemessen waren.
#
# Ausserhalb dieses Fensters wird nur auf ausdrueckliche Ansage gearbeitet.
#
# Das ersetzt das bisherige Vorgehen, bei dem Messketten von Hand gestartet
# wurden, wann es gerade passte -- und sich dann gegenseitig und dem Betrieb
# in die Quere kamen.
#
# DREI HARTE REGELN:
#   0. Ohne gewaehrte GPU-Pacht wird NICHT gemessen. llm-runtime bringt dafuer
#      eine Verwaltung mit (/_manager/lease); solange sie gehalten wird, weist
#      der Dienst interaktive Anfragen ab, statt uns den Speicher wegzunehmen.
#      In der Nacht zum 21.08. hat gefehlt, dass sie ueberhaupt angefordert
#      wurde: der Abgleich mass gegen eine umkaempfte Karte, beide Bauten kamen
#      auf 3,3 statt 103 Token/s -- und weil BEIDE gleich falsch gemessen waren,
#      meldete der Pruefstand "Zahlen nicht schlechter" und haette den
#      Versionswechsel durchgewunken. Eine Messung, die ihre eigenen
#      Voraussetzungen nicht prueft, erzeugt stillschweigend Zustimmung.
#   1. Vor JEDEM Schritt wird das Fenster geprueft, nicht nur beim Start.
#      Ein Schritt, der um 10:55 beginnt und drei Stunden braucht, waere sonst
#      genau der Konflikt, den das Fenster verhindern soll.
#   2. Um 11:00 wird abgeraeumt, auch mitten im Lauf -- inklusive des selbst
#      gestarteten llama-server, ueber die gemerkte PID.
set -u
E=/root/eval
D=/sys/class/drm/card1/device
L=$E/nachtfenster.log
RUNTIME=${RUNTIME:-http://127.0.0.1:8080}
PACHT_SCHLUESSEL=${PACHT_SCHLUESSEL:-/etc/bench/lease.token}
PACHT_ID=""; HERZ=""
WARTESCHLANGE=${WARTESCHLANGE:-$E/warteschlange.txt}
START_STD=${START_STD:-0}
ENDE_STD=${ENDE_STD:-8}
SPID=""

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }

# Faengt das Fenster spaeter an, als es endet, laeuft es ueber Mitternacht.
im_fenster(){ local h=$(date +%-H)
  if [ "$START_STD" -gt "$ENDE_STD" ]; then [ "$h" -ge "$START_STD" ] || [ "$h" -lt "$ENDE_STD" ]
  else [ "$h" -ge "$START_STD" ] && [ "$h" -lt "$ENDE_STD" ]; fi; }

# --- GPU-Pacht ---------------------------------------------------------------
pacht_nehmen(){
  [ -r "$PACHT_SCHLUESSEL" ] || { sag "Pacht-Schluessel fehlt: $PACHT_SCHLUESSEL"; return 1; }
  local t a
  t=$(cat "$PACHT_SCHLUESSEL")
  a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" \
        -H "x-lease-token: $t" -H "Content-Type: application/json" \
        -d "{\"holder\":\"nachtfenster\"}" 2>/dev/null)
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  sag "Pacht $PACHT_ID gehalten"
  # Herzschlag deutlich unter der Laufzeit (LLM_RUNTIME_LEASE_TTL=300).
  ( while :; do sleep 120
      curl -s -m 10 -o /dev/null -X POST \
        "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" -H "x-lease-token: $t" || true
    done ) & HERZ=$!
  return 0
}

pacht_gilt(){
  [ -n "$PACHT_ID" ] || return 1
  curl -s -m 10 "$RUNTIME/_manager/status" -H "x-lease-token: $(cat "$PACHT_SCHLUESSEL")" \
    2>/dev/null | grep -q "$PACHT_ID"
}

pacht_zurueck(){
  [ -n "$HERZ" ] && kill "$HERZ" 2>/dev/null
  [ -n "$PACHT_ID" ] || return 0
  curl -s -m 10 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" \
    -H "x-lease-token: $(cat "$PACHT_SCHLUESSEL")" 2>/dev/null
  sag "Pacht $PACHT_ID zurueckgegeben"
  PACHT_ID=""
}

aufraeumen(){
  pacht_zurueck
  # Nur der selbst gestartete Server. Ein Muster traefe die Produktions-Runtime.
  [ -n "$SPID" ] && { kill $SPID 2>/dev/null; sleep 6; kill -9 $SPID 2>/dev/null; }
  # Takte zuruecksetzen, falls ein Drossel-Schritt unterbrochen wurde.
  echo r > $D/pp_od_clk_voltage 2>/dev/null
  echo c > $D/pp_od_clk_voltage 2>/dev/null
  echo auto > $D/power_dpm_force_performance_level 2>/dev/null
  HW=$(echo $D/hwmon/hwmon*/|cut -d" " -f1); echo 291000000 > $HW/power1_cap 2>/dev/null
}
trap aufraeumen EXIT INT TERM

im_fenster || { sag "ausserhalb ${START_STD}:00-${ENDE_STD}:00 -- nichts gestartet"; exit 0; }
[ -s "$WARTESCHLANGE" ] || { sag "Warteschlange leer"; exit 0; }
pacht_nehmen || { sag "ohne Pacht wird nicht gemessen -- Fenster endet hier"; exit 0; }

sag "=== Fenster auf ($(date +%H:%M), bis ${ENDE_STD}:00) ==="

# Wachhund: raeumt um 11:00 ab, auch wenn ein Schritt noch laeuft.
( while :; do
    h=$(date +%-H)
    if [ "$h" -ge "$ENDE_STD" ] && [ "$h" -lt "$START_STD" ]; then
      echo "[$(date '+%H:%M:%S')] WACHHUND: Fenster zu, breche ab" >> $L
      pkill -P $$ 2>/dev/null
      kill -TERM $$ 2>/dev/null
      exit 0
    fi
    sleep 60
  done ) & WACHHUND=$!

erledigt=0
while read -r zeile; do
  case "$zeile" in ""|\#*) continue ;; esac
  if ! im_fenster; then
    sag "Fenster zu -- Rest der Warteschlange bleibt liegen"
    break
  fi
  # Karte frei? Kurz warten, dann MIT Meldung ueberspringen. Ein stummes
  # Ueberspringen ist von Erfolg nicht zu unterscheiden.
  frei=nein
  for i in $(seq 1 30); do
    v=$(( $(cat $D/mem_info_vram_used)/1048576 )); s=$(pgrep -x llama-server|wc -l)
    [ "$v" -lt 500 ] && [ "$s" -eq 0 ] && { frei=ja; break; }
    sleep 20
  done
  [ $frei = ja ] || { sag "  Karte belegt -- uebersprungen: $zeile"; continue; }
  # Vor JEDEM Schritt: gilt die Pacht noch? Eine verlorene Pacht heisst, dass
  # jemand anders die Karte hat -- weitermessen wuerde Zahlen erzeugen, die wie
  # Ergebnisse aussehen und keine sind.
  pacht_gilt || { sag "  Pacht verloren -- Fenster wird beendet"; break; }

  sag "--- $zeile ---"
  t0=$(date +%s)
  bash -c "$zeile" >> $L 2>&1
  rc=$?
  sag "--- rc=$rc nach $(( ($(date +%s) - t0) / 60 )) min ---"
  erledigt=$((erledigt+1))
done < "$WARTESCHLANGE"

kill $WACHHUND 2>/dev/null
sag "=== Fenster-Ende, $erledigt Schritte gelaufen ==="

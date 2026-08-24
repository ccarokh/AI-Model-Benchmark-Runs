#!/bin/bash
# Night window. During the day the card belongs to the operator; outside the
# window nothing runs without an explicit instruction.
#
# The window and LLM_RUNTIME_BATCH_WINDOW have to agree. They did not once, and
# on the night of 21.08. that cost a measurement: the drift check measured
# against a contended card, both builds came out at 3.3 instead of 103 tokens/s
# -- and the check would have waved the version change through, because both
# sides were equally wrong.
#
# This replaces the previous practice of starting measurement chains by hand
# whenever it happened to suit -- and having them then get in each other's and
# in the day job's way.
#
# THREE HARD RULES:
#   0. No measurement without a granted GPU lease. llm-runtime provides one
#      (/_manager/lease); while it is held the service refuses interactive
#      requests instead of taking the memory away from us. What was missing on
#      the night of 21.08. was that anyone requested it at all. A measurement
#      that does not check its own preconditions silently produces agreement.
#   1. The window is checked before EVERY step, not only at the start. A step
#      beginning at 10:55 and taking three hours would otherwise be exactly the
#      conflict the window is meant to prevent.
#   2. At the closing hour everything is torn down, mid-run if necessary --
#      including the llama-server we started ourselves, via its remembered PID.
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

# If the window starts later than it ends, it runs across midnight.
im_fenster(){ local h=$(date +%-H)
  if [ "$START_STD" -gt "$ENDE_STD" ]; then [ "$h" -ge "$START_STD" ] || [ "$h" -lt "$ENDE_STD" ]
  else [ "$h" -ge "$START_STD" ] && [ "$h" -lt "$ENDE_STD" ]; fi; }

# --- GPU lease ---------------------------------------------------------------
pacht_nehmen(){
  [ -r "$PACHT_SCHLUESSEL" ] || { sag "Pacht-Schluessel fehlt: $PACHT_SCHLUESSEL"; return 1; }
  local t a
  t=$(cat "$PACHT_SCHLUESSEL")
  a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" \
        -H "x-lease-token: $t" -H "Content-Type: application/json" \
        -d "{\"holder\":\"nachtfenster\"}" 2>/dev/null)
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  # Exported, so a queue step can inherit it. llm-runtime grants exactly one
  # lease; a step that asks for its own gets refused and dies before it
  # measures. On 23.08. at 04:58 that took out both validation steps while the
  # long series ran on unaffected -- two rc=1 lines in a log full of successes.
  export PACHT_ID
  sag "Pacht $PACHT_ID gehalten"
  # Heartbeat well below the lease TTL (LLM_RUNTIME_LEASE_TTL=300).
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

# Hold the lease, do not merely check it. Returns 1 only when the window closes
# before it can be had again -- that is the one case where stopping is right.
pacht_sichern(){
  pacht_gilt && return 0
  sag "  Pacht verloren -- wird neu geholt, bis sie wieder gilt oder das Fenster zugeht"
  local versuche=0
  while im_fenster; do
    versuche=$((versuche+1))
    # Kill the old heartbeat first: otherwise, from the second round on, two
    # loops beat against a lease id that no longer exists.
    [ -n "$HERZ" ] && { kill "$HERZ" 2>/dev/null; HERZ=""; }
    PACHT_ID=""
    if pacht_nehmen; then
      sag "  Pacht nach $versuche Versuch(en) wieder da"
      return 0
    fi
    # Not the same line every minute: once at the start, then every ten. A log
    # that says the same thing for an hour does not get read.
    [ $((versuche % 10)) -eq 1 ] && sag "  ... Pacht weiterhin nicht zu bekommen (Versuch $versuche)"
    sleep 60
  done
  return 1
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
  # Only the server we started ourselves. A pattern match would hit the
  # production runtime as well.
  [ -n "$SPID" ] && { kill $SPID 2>/dev/null; sleep 6; kill -9 $SPID 2>/dev/null; }
  # Reset clocks in case a throttling step was interrupted.
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

# Watchdog: clears the field at 11:00, even if a step is still running.
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
  # Card free? Wait briefly, then skip WITH a message. A silent skip cannot be
  # told apart from success.
  # With a lease the memory guard drops away: llm-runtime is then the
  # authority. It grants the lease only when the card is free enough (threshold
  # 1024 MiB) and refuses interactive requests afterwards.
  #
  # A second, stricter threshold beside it locked out ALL four steps on the
  # night of 22.08.: it demanded under 500 MiB while this machine idles at
  # around 700 -- a permanently loaded detection model. The condition could
  # never become true. The lease was taken, held, and returned unused.
  frei=nein
  [ -n "$PACHT_ID" ] && frei=ja
  for i in $(seq 1 30); do
    [ $frei = ja ] && break
    v=$(( $(cat $D/mem_info_vram_used)/1048576 )); s=$(pgrep -x llama-server|wc -l)
    [ "$v" -lt 500 ] && [ "$s" -eq 0 ] && { frei=ja; break; }
    sleep 20
  done

  [ $frei = ja ] || { sag "  Karte belegt -- uebersprungen: $zeile"; continue; }
  # Before EVERY step: is the lease still valid? A lost lease means someone
  # else has the card -- measuring on would produce numbers that look like
  # results and are not.
  #
  # But a lost lease is no reason to end the night. On the night of 24.08.
  # llm-runtime was restarted at 23:19, and a restart drops the lease because it
  # lives in memory. At 00:53 this check noticed and closed the window: four of
  # seven steps were lost to a restart that had happened ninety minutes earlier
  # and had nothing to do with the measurement. The lease is now re-acquired for
  # as long as the window is open.
  pacht_sichern || { sag "  Fenster zu und keine Pacht -- der Rest bleibt liegen"; break; }

  sag "--- $zeile ---"
  t0=$(date +%s)
  bash -c "$zeile" >> $L 2>&1
  rc=$?
  sag "--- rc=$rc nach $(( ($(date +%s) - t0) / 60 )) min ---"
  erledigt=$((erledigt+1))
done < "$WARTESCHLANGE"

kill $WACHHUND 2>/dev/null
sag "=== Fenster-Ende, $erledigt Schritte gelaufen ==="

#!/bin/bash
# The day queue for System C -- the borrowed 4070 Super.
#
# WHY A SEPARATE RUNNER AND NOT nachtfenster.sh:
# That one exists to stay out of the way of a production service and a person
# who needs the card during the day. Here neither applies: this machine has no
# service on the card and it is available around the clock. What it has instead
# is a DEADLINE -- the card goes back in two days. So this runner is built
# around a time budget, not around a window: it works the list until the budget
# is spent and says what it did not get to.
#
#   tagfenster.sh [budget-hours]      default 10
set -uo pipefail

E=/root/mess
WARTESCHLANGE=${WARTESCHLANGE:-$E/warteschlange.txt}
L=${L:-$E/tagfenster.log}
BUDGET_H=${1:-10}
ENDE=$(( $(date +%s) + BUDGET_H * 3600 ))

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }

# The card must be idle before a step, and it must be left idle after one. A
# leftover llama-server from a killed step would make the next step measure a
# card that is already half full -- and the number would look fine.
karte_frei(){
  for i in $(seq 1 60); do
    local v s
    v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1)
    s=$(pgrep -x llama-server | wc -l)
    [ "${v:-9999}" -lt 500 ] && [ "$s" -eq 0 ] && return 0
    sleep 10
  done
  return 1
}

# Xid is how an NVIDIA card reports that it fell over. A throughput test runs
# through on a card that has already reset itself, and the number then looks
# like a result.
xid_zahl(){ dmesg 2>/dev/null | grep -ciE "NVRM: Xid|GPU has fallen off" || true; }

mkdir -p "$E"
[ -s "$WARTESCHLANGE" ] || { sag "Warteschlange leer"; exit 0; }
sag "=== Tagfenster auf, Budget ${BUDGET_H} h (bis $(date -d "@$ENDE" '+%H:%M')) ==="
sag "Karte: $(nvidia-smi --query-gpu=name,driver_version,power.limit --format=csv,noheader)"
xid0=$(xid_zahl)
erledigt=0; offen=0

while read -r zeile; do
  case "$zeile" in ""|\#*) continue ;; esac
  rest=$(( ENDE - $(date +%s) ))
  if [ "$rest" -le 0 ]; then
    sag "Budget aufgebraucht -- NICHT gelaufen: $zeile"; offen=$((offen+1)); continue
  fi
  if ! karte_frei; then
    sag "Karte wurde in 10 min nicht frei -- UEBERSPRUNGEN: $zeile"; offen=$((offen+1)); continue
  fi
  sag "--- $zeile   (noch $((rest/60)) min Budget) ---"
  t0=$(date +%s)
  # The step gets the remaining budget as a hard limit, so one hanging step
  # cannot eat the whole programme. It is a limit, not a schedule: a step that
  # finishes early hands the rest back.
  timeout "$rest" bash -c "$zeile" >> "$L" 2>&1
  rc=$?
  sag "--- rc=$rc nach $(( ($(date +%s) - t0) / 60 )) min ---"
  [ $rc -eq 124 ] && sag "    (Zeitlimit -- der Schritt wurde vom Budget abgeschnitten)"
  erledigt=$((erledigt+1))
done < "$WARTESCHLANGE"

xid1=$(xid_zahl)
[ "$xid0" = "$xid1" ] || sag "ACHTUNG: Kernel meldet Xid -- alle Zahlen dieses Laufs pruefen"
p=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader)
sag "Leistungsgrenze am Ende: $p (Vorgabe 220.00 W -- Abweichung heisst, ein Schritt hat nicht aufgeraeumt)"
sag "=== Tagfenster zu: $erledigt gelaufen, $offen offen ==="

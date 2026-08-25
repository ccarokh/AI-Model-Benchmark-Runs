#!/bin/bash
# Efficiency against the power limit, on Ada.
#
# The curve in hardware/power.md is the AMD card's: an optimum at 1200 MHz, and
# every figure there came off a wall-socket meter because the AMD driver would
# not give a usable board figure. This card reports board power itself, so the
# same curve can be drawn per card instead of per machine -- and per phase.
#
# THE POWER LIMIT IS RESTORED WHATEVER HAPPENS. A measurement machine left at
# 100 W after a crashed script produces "results" for weeks that are nothing but
# the leftover of a run nobody remembers.
set -uo pipefail
L=${L:-/root/mess/power_curve.log}
. "$(dirname "$0")/gemeinsam.sh"
VORGABE=${VORGABE:-220}
STUFEN=${STUFEN:-"220 200 180 160 140 120 100"}

zurueck(){ nvidia-smi -pl "$VORGABE" >/dev/null 2>&1; sag "Leistungsgrenze zurueck auf ${VORGABE} W"; }
trap zurueck EXIT INT TERM

sag "=== Effizienzkurve (Vorgabe ${VORGABE} W) ==="
for w in $STUFEN; do
  karte_leer || { sag "  Karte nicht leer -- ${w} W uebersprungen"; continue; }
  nvidia-smi -pl "$w" >>"$L" 2>&1 || { sag "  ${w} W: Grenze nicht setzbar -- uebersprungen"; continue; }
  ist=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits | head -1)
  # Sample across the whole run, not from its start: a sampler that begins with
  # the benchmark collects mostly idle and reports a mean that never happened.
  ( while :; do nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | head -1; sleep 1; done ) > /tmp/watt.$$ &
  SAMPLER=$!
  r=$(bench "$BAU/bin" -m "$M9" -p 2048 -n 256 -r 3 -ngl 99)
  kill "$SAMPLER" 2>/dev/null
  watt=$(awk '{s+=$1; n++} END{if(n) printf "%.1f", s/n; else print "?"}' /tmp/watt.$$)
  spitze=$(sort -n /tmp/watt.$$ | tail -1)
  rm -f /tmp/watt.$$
  if [ -z "$r" ]; then sag "  ${w} W (gesetzt ${ist}): LEER"; continue; fi
  pp=${r% *}; tg=${r#* }
  # Tokens per watt-hour, generation only: that is the phase a power limit
  # actually bites in, and mixing it with prefill hides the effect.
  twh=$(awk -v t="$tg" -v p="$watt" 'BEGIN{if(p>0) printf "%.0f", t*3600/p; else print "?"}')
  sag "  ${w} W (gesetzt ${ist}): pp2048=$pp tg256=$tg   ${watt} W im Mittel, Spitze ${spitze} W, ${twh} Token/Wh"
done
sag "=== EFFIZIENZKURVE DURCH ==="

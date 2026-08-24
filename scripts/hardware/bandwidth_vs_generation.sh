#!/bin/bash
# The card comparison, continued on the machine that holds two more cards.
#
# EXACTLY the command the RTX 3080 and the RTX 4070 Super were measured with, on
# the SAME llama.cpp commit (70adb1b4c). Anything else here would put a second
# variable next to the card and make the table unreadable:
#
#   llama-bench -m Llama-3.2-3B-Instruct-Q4_K_M.gguf -n 128 -p 512,4096 \
#               -pg 4096,128 -ngl 99 -r 20
#
# WHAT IS NOT IDENTICAL, and has to be written down rather than glossed over:
# the driver. The 3080 and the 4070 Super ran NVIDIA 610.57.04. The RTX 2070 here
# runs a slightly older NVIDIA build, and the 7900 XTX runs RADV/Mesa -- a
# different driver stack altogether. Both speak Vulkan, so the backend matches;
# the driver does not. The versions are recorded below so the table can say so.
#
# No lease, no measurement: llm-runtime shares this card and loads models on
# demand. While the lease is held it refuses interactive requests instead of
# taking the memory away mid-run.
set -uo pipefail

RUNTIME=${RUNTIME:-http://127.0.0.1:8080}
SCHLUESSEL=${SCHLUESSEL:-/etc/bench/lease.token}
BENCH=${BENCH:-/opt/src/llama.cpp/build-latest/bin/llama-bench}
MODELL=${MODELL:-/opt/llm-infra/models/llama-3.2-3b/Llama-3.2-3B-Instruct-Q4_K_M.gguf}
AUS=${AUS:-/root/eval/karten}
PACHT_ID=${PACHT_ID:-}; GEERBT=nein; HERZ=""

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*"; }

pacht_zurueck(){
  [ "$GEERBT" = ja ] && return 0
  [ -n "$HERZ" ] && kill "$HERZ" 2>/dev/null
  [ -n "$PACHT_ID" ] || return 0
  curl -s -m 10 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" \
       -H "x-lease-token: $(cat "$SCHLUESSEL")" || true
  sag "Pacht $PACHT_ID zurueckgegeben"; PACHT_ID=""
}
trap pacht_zurueck EXIT INT TERM

pacht_nehmen(){
  # A step started inside the night window inherits the scheduler's lease: it is
  # already held, and llm-runtime grants exactly one. Asking for a second one is
  # refused, and the step then dies before it measures anything -- which is what
  # happened at 04:58 to both validation steps while the long series ran on.
  if [ -n "$PACHT_ID" ]; then GEERBT=ja; sag "Pacht $PACHT_ID vom Aufrufer geerbt"; return 0; fi
  local t a
  t=$(cat "$SCHLUESSEL") || return 1
  a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" \
        -H "x-lease-token: $t" -H "Content-Type: application/json" \
        -d '{"holder":"bandwidth_vs_generation"}')
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  sag "Pacht $PACHT_ID gehalten"
  ( while :; do sleep 120
      curl -s -m 10 -o /dev/null -X POST \
        "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" -H "x-lease-token: $t" || true
    done ) & HERZ=$!
}

mkdir -p "$AUS"
[ -x "$BENCH" ] || { sag "kein llama-bench unter $BENCH"; exit 2; }
[ -r "$MODELL" ] || { sag "kein Modell unter $MODELL"; exit 2; }
pacht_nehmen || exit 1

sag "Build: $(git -C /opt/src/llama.cpp log --oneline -1 2>/dev/null)"
sag "Mesa/RADV: $(vulkaninfo --summary 2>/dev/null | grep -m1 -i driverinfo | sed 's/^ *//')"
sag "NVIDIA: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"

# The kernel log is read before and after. A throughput test also runs through on
# a card that has already reset itself -- the number then looks fine and is not.
vorher=$(dmesg 2>/dev/null | grep -icE "ring .* timeout|GPU reset|ErrorDeviceLost|Xid")

messen(){
  local dev="$1" name="$2"
  sag "=== $name ($dev) ==="
  # A fresh process per measurement: llama-server and llama-bench both carry
  # state between runs, and a warm process measures the previous run too.
  # One run, two formats: json to the file, the readable table to the log via
  # -oe. Running it twice would cost the card twice and produce two different
  # measurements under one heading.
  "$BENCH" -m "$MODELL" -n 128 -p 512,4096 -pg 4096,128 -ngl 99 -r 20 \
           -dev "$dev" -o json -oe md > "$AUS/rohdaten_$name.json" 2> "$AUS/lauf_$name.log"
  local rc=$?
  if [ $rc -ne 0 ] || [ ! -s "$AUS/rohdaten_$name.json" ]; then
    sag "$name: FEHLGESCHLAGEN (rc=$rc) -- siehe $AUS/lauf_$name.log"
    tail -5 "$AUS/lauf_$name.log" | sed 's/^/    /'
    return 1
  fi
  grep -E "^\|" "$AUS/lauf_$name.log" | sed 's/^/    /' | tee -a "$AUS/tabellen.md"
  sag "$name: fertig"
}

messen Vulkan0 7900xtx
messen Vulkan1 2070

nachher=$(dmesg 2>/dev/null | grep -icE "ring .* timeout|GPU reset|ErrorDeviceLost|Xid")
sag "Kernelmeldungen: vorher $vorher, nachher $nachher"
[ "$vorher" = "$nachher" ] || sag "ACHTUNG: die Karte hat sich waehrend des Laufs gemeldet -- Zahlen pruefen"
sag "=== DURCH ==="

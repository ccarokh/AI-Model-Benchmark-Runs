#!/bin/bash
# Do the multi-GPU findings still hold after a build change?
#
# hardware/multi-gpu.md rests on three numbers: layer split costs ~38 % of the
# generation rate, prefill is free, tensor split is unusable. All of them were
# measured on the build that was production until 23.08. When that build is
# replaced, those findings are claims about a state that no longer exists --
# until they are measured again.
#
# Two prefixes in the SAME session, five configurations each. Comparing today's
# number against a number from three weeks ago would mix the build change with
# everything else that drifted in between; running both now does not.
#
#   multigpu_recheck.sh [prefix ...]      default: /opt/llama-cpp /opt/llama-cpp-nb
set -uo pipefail

M=${M:-/opt/llm-infra/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf}
AUS=${AUS:-/root/eval/multigpu}
RUNTIME=${RUNTIME:-http://127.0.0.1:8080}
SCHLUESSEL=${SCHLUESSEL:-/etc/bench/lease.token}
L=${L:-/root/eval/multigpu_recheck.log}
PACHT_ID=""; HERZ=""

# -n 1000 rather than the 3000 of the original sustained run: the same document
# records that configuration A differed by 0.03 % between 3 s and 4.5 min of
# measurement, so the shorter run buys a night window without costing precision.
GEN=${GEN:-1000}
PRE=${PRE:-2048}

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }

aufraeumen(){
  [ -n "$HERZ" ] && kill "$HERZ" 2>/dev/null
  [ -n "$PACHT_ID" ] && { curl -s -m 10 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" \
      -H "x-lease-token: $(cat "$SCHLUESSEL")" || true; sag "Pacht $PACHT_ID zurueckgegeben"; }
}
trap aufraeumen EXIT INT TERM

pacht_nehmen(){
  local t a; t=$(cat "$SCHLUESSEL") || return 1
  a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" -H "x-lease-token: $t" \
        -H "Content-Type: application/json" -d '{"holder":"multigpu_recheck"}')
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  sag "Pacht $PACHT_ID gehalten"
  ( while :; do sleep 120
      curl -s -m 10 -o /dev/null -X POST "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" \
           -H "x-lease-token: $t" || true; done ) & HERZ=$!
}

# name | flags -- the separator in -ts is a SLASH. A comma is parsed as two
# separate runs, which is how "3,1" once produced numbers that looked like a
# ratio sweep and were not.
KONFIG=(
  "XTX allein            |-sm none -mg 0"
  "Layer 1:0 (2. Karte leer)|-sm layer -ts 1/0"
  "Layer 7:1             |-sm layer -ts 7/1"
  "Layer 3:1             |-sm layer -ts 3/1"
  "Tensor 3:1            |-sm row -ts 3/1"
)
# What the document says today, for the same configurations at 27B. Printed
# beside the new numbers so a change is visible without opening a second file.
declare -A ALTGEN=( ["XTX allein"]=38.67 ["Layer 1:0 (2. Karte leer)"]=38.94 \
                    ["Layer 7:1"]=25.84 ["Layer 3:1"]=24.10 ["Tensor 3:1"]=20.09 )

mkdir -p "$AUS"
[ -r "$M" ] || { sag "kein Modell unter $M"; exit 2; }
pacht_nehmen || exit 1

for pfad in "${@:-/opt/llama-cpp /opt/llama-cpp-nb}"; do
  for p in $pfad; do
    v=$(cat "$p/.built-version" 2>/dev/null || echo '?')
    [ -x "$p/bin/llama-bench" ] || { sag "kein llama-bench in $p -- uebersprungen"; continue; }
    sag "=== $p ($v) ==="
    for eintrag in "${KONFIG[@]}"; do
      name=${eintrag%%|*}; flags=${eintrag#*|}
      name=$(printf '%s' "$name" | sed 's/ *$//')
      r=$(LD_LIBRARY_PATH=$p/lib timeout 3600 "$p/bin/llama-bench" -m "$M" \
            -p "$PRE" -n "$GEN" -r 2 -ngl 99 $flags -o json 2>>"$AUS/lauf.log" \
          | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
v={}
for e in d: v['tg' if e['n_gen'] and not e['n_prompt'] else 'pp']=e['avg_ts']
if not v: sys.exit(1)
print('%.2f %.2f' % (v.get('pp',0), v.get('tg',0)))")
      if [ -z "$r" ]; then
        sag "  $name : LEER -- diese Konfiguration hat nicht gemessen"
        continue
      fi
      pp=${r% *}; tg=${r#* }
      alt=${ALTGEN[$name]:-}
      delta=""
      [ -n "$alt" ] && delta=$(awk -v a="$tg" -v b="$alt" 'BEGIN{printf "%+.1f %%", (a/b-1)*100}')
      sag "  $name : pp$PRE=$pp tg$GEN=$tg   (dokumentiert $alt${delta:+, $delta})"
    done
  done
done
sag "Ein Unterschied zwischen den beiden Praefixen ist ein Build-Effekt. Ein Unterschied"
sag "zu den dokumentierten Zahlen bei GLEICHEN Praefix-Zahlen ist keiner -- dann hat sich"
sag "seit August etwas anderes geaendert, und das ist eine eigene Frage."
sag "=== MULTI-GPU-NACHPRUEFUNG DURCH ==="

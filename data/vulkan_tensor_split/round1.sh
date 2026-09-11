#!/bin/bash
# Vulkan tensor-split, round 1: controls that separate fragmentation / sync+transfer / slow-card compute.
# Output: one llama-bench JSON per configuration under $AUS, plus a log.
set -uo pipefail
B=${B:-/opt/llama-cpp-master}
M=${M:-/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf}
AUS=${AUS:-/root/eval/vulkan-ar/round1}
RUNTIME=http://127.0.0.1:8080
SCHLUESSEL=/etc/bench/lease.token
L=$AUS/round1.log
PACHT_ID=""; HERZ=""
P=${P:-512}; N=${N:-128}; R=${R:-3}

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
        -H "Content-Type: application/json" -d '{"holder":"vulkan-ar-round1"}')
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  sag "Pacht $PACHT_ID gehalten"
  ( while :; do sleep 120
      curl -s -m 10 -o /dev/null -X POST "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" -H "x-lease-token: $t" || true
    done ) & HERZ=$!
}

mkdir -p "$AUS"
sag "=== round 1: $B ($(cat $B/.built-version)) model=$(basename $M) p=$P n=$N r=$R ==="
pacht_nehmen || exit 1
export LD_LIBRARY_PATH=$B/lib
$B/bin/llama-bench --list-devices 2>&1 | tee -a "$L"

# name | env | flags   -- -ts separator is a SLASH
KONFIG=(
  "A0_xtx_alone        | | -sm none -mg 0"
  "A1_2070_alone       | | -sm none -mg 1"
  "B_tensor_1dev       | | -sm tensor -dev Vulkan0"
  "C_tensor_1_0        | | -sm tensor -ts 1/0"
  "D_tensor_3_1        | | -sm tensor -ts 3/1"
  "D_tensor_1_1        | | -sm tensor -ts 1/1"
  "D_tensor_1_3        | | -sm tensor -ts 1/3"
  "E_tensor_3_1_novis  |GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1| -sm tensor -ts 3/1"
  "F_layer_3_1         | | -sm layer -ts 3/1"
  "F_layer_1_0         | | -sm layer -ts 1/0"
)
for k in "${KONFIG[@]}"; do
  name=$(echo "$k" | cut -d'|' -f1 | xargs); envv=$(echo "$k" | cut -d'|' -f2 | xargs); flags=$(echo "$k" | cut -d'|' -f3 | xargs)
  sag "--- $name  [$envv] $flags ---"
  vram0=$(awk '{print int($1/1048576)}' /sys/class/drm/card1/device/mem_info_vram_used 2>/dev/null)
  sag "vram0 used before: ${vram0} MB"
  env $envv timeout 900 $B/bin/llama-bench -m "$M" -ngl 99 -fa 1 -p $P -n $N -r $R $flags -o json \
      > "$AUS/$name.json" 2> "$AUS/$name.err"
  rc=$?
  sag "rc=$rc  $(python3 -c "
import json,sys
try:
  d=json.load(open('$AUS/$name.json'))
  print(' | '.join('%s %.2f±%.2f'%(x['test'] if 'test' in x else ('pp%d'%x['n_prompt'] if x['n_gen']==0 else 'tg%d'%x['n_gen']), x['avg_ts'], x['stddev_ts']) for x in d))
except Exception as e: print('no json:', e)
")"
  grep -E "error|Error|Assert|abort|Segmentation" "$AUS/$name.err" | head -3 | tee -a "$L"
  sleep 5
done
sag "=== done ==="

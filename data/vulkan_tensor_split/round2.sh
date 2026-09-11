#!/bin/bash
# Round 2: instrumented libggml-base (GGML_META_AR_TIMING) -- where inside the AllReduce the time goes.
set -uo pipefail
B=/opt/llama-cpp-master
LIBS=/opt/llama-cpp-ar-timing/lib:$B/lib
M=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
AUS=/root/eval/vulkan-ar/round2
RUNTIME=http://127.0.0.1:8080; SCHLUESSEL=/etc/bench/lease.token
L=$AUS/round2.log; PACHT_ID=""; HERZ=""
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }
aufraeumen(){ [ -n "$HERZ" ] && kill "$HERZ" 2>/dev/null
  [ -n "$PACHT_ID" ] && { curl -s -m 10 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" -H "x-lease-token: $(cat "$SCHLUESSEL")" || true; sag "Pacht $PACHT_ID zurueckgegeben"; }; }
trap aufraeumen EXIT INT TERM
pacht_nehmen(){ local t a; t=$(cat "$SCHLUESSEL") || return 1
  a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" -H "x-lease-token: $t" -H "Content-Type: application/json" -d '{"holder":"vulkan-ar-round2"}')
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  sag "Pacht $PACHT_ID gehalten"
  ( while :; do sleep 120; curl -s -m 10 -o /dev/null -X POST "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" -H "x-lease-token: $t" || true; done ) & HERZ=$!; }
mkdir -p "$AUS"
sag "=== round 2 (instrumented) $B ($(cat $B/.built-version)) + $LIBS ==="
pacht_nehmen || exit 1
# name | env | pn | flags
KONFIG=(
  "tg_B_1dev      |GGML_META_AR_TIMING=32| -p 0 -n 128 | -sm tensor -dev Vulkan0"
  "tg_C_1_0       |GGML_META_AR_TIMING=32| -p 0 -n 128 | -sm tensor -ts 1/0"
  "tg_D_3_1       |GGML_META_AR_TIMING=32| -p 0 -n 128 | -sm tensor -ts 3/1"
  "tg_D_1_1       |GGML_META_AR_TIMING=32| -p 0 -n 128 | -sm tensor -ts 1/1"
  "tg_E_3_1_novis |GGML_META_AR_TIMING=32 GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1| -p 0 -n 128 | -sm tensor -ts 3/1"
  "pp_D_3_1       |GGML_META_AR_TIMING=1 | -p 512 -n 0 | -sm tensor -ts 3/1"
  "pp_C_1_0       |GGML_META_AR_TIMING=1 | -p 512 -n 0 | -sm tensor -ts 1/0"
  "pp_B_1dev      |GGML_META_AR_TIMING=1 | -p 512 -n 0 | -sm tensor -dev Vulkan0"
)
for k in "${KONFIG[@]}"; do
  name=$(echo "$k" | cut -d'|' -f1 | xargs); envv=$(echo "$k" | cut -d'|' -f2 | xargs); pn=$(echo "$k" | cut -d'|' -f3 | xargs); flags=$(echo "$k" | cut -d'|' -f4 | xargs)
  sag "--- $name [$envv] $pn $flags ---"
  env LD_LIBRARY_PATH=$LIBS $envv timeout 900 $B/bin/llama-bench -m "$M" -ngl 99 -fa 1 $pn -r 3 $flags -o json > "$AUS/$name.json" 2> "$AUS/$name.err"
  rc=$?
  sag "rc=$rc $(python3 -c "
import json
try:
  d=json.load(open('$AUS/$name.json')); print(' | '.join('%s %.2f±%.2f'%(('pp%d'%x['n_prompt'] if x['n_gen']==0 else 'tg%d'%x['n_gen']), x['avg_ts'], x['stddev_ts']) for x in d))
except Exception as e: print('no json', e)")"
  grep -c "meta-ar" "$AUS/$name.err" | xargs -I{} sag "  {} meta-ar lines"
  grep "meta-ar" "$AUS/$name.err" | tail -3 | tee -a "$L"
  sleep 3
done
sag "=== done ==="

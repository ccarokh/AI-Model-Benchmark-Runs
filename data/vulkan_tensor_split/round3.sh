#!/bin/bash
# Round 3: v2 instrumentation (4 sync slots) + model-size scaling, tg only.
set -uo pipefail
B=/opt/llama-cpp-master
LIBS=/opt/llama-cpp-ar-timing/lib:$B/lib
M9=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
M3=/opt/llm-infra/models/llama-3.2-3b/Llama-3.2-3B-Instruct-Q4_K_M.gguf
M27=/opt/llm-infra/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
AUS=/root/eval/vulkan-ar/round3
RUNTIME=http://127.0.0.1:8080; SCHLUESSEL=/etc/bench/lease.token
L=$AUS/round3.log; PACHT_ID=""; HERZ=""
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }
aufraeumen(){ [ -n "$HERZ" ] && kill "$HERZ" 2>/dev/null
  [ -n "$PACHT_ID" ] && { curl -s -m 10 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" -H "x-lease-token: $(cat "$SCHLUESSEL")" || true; sag "Pacht $PACHT_ID zurueckgegeben"; }; }
trap aufraeumen EXIT INT TERM
pacht_nehmen(){ local t a; t=$(cat "$SCHLUESSEL") || return 1
  a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" -H "x-lease-token: $t" -H "Content-Type: application/json" -d '{"holder":"vulkan-ar-round3"}')
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  sag "Pacht $PACHT_ID gehalten"
  ( while :; do sleep 120; curl -s -m 10 -o /dev/null -X POST "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" -H "x-lease-token: $t" || true; done ) & HERZ=$!; }
mkdir -p "$AUS"
sag "=== round 3 (instrumented v2) $B ($(cat $B/.built-version)) ==="
pacht_nehmen || exit 1
# name | model | env | flags     (all: -p 0 -n 128 -r 3)
KONFIG=(
  "9b_tg_C_1_0     |$M9 |GGML_META_AR_TIMING=32| -sm tensor -ts 1/0"
  "9b_tg_D_3_1     |$M9 |GGML_META_AR_TIMING=32| -sm tensor -ts 3/1"
  "3b_tg_A0        |$M3 |GGML_META_AR_TIMING=32| -sm none -mg 0"
  "3b_tg_B_1dev    |$M3 |GGML_META_AR_TIMING=32| -sm tensor -dev Vulkan0"
  "3b_tg_C_1_0     |$M3 |GGML_META_AR_TIMING=32| -sm tensor -ts 1/0"
  "3b_tg_D_3_1     |$M3 |GGML_META_AR_TIMING=32| -sm tensor -ts 3/1"
  "27b_tg_A0       |$M27|GGML_META_AR_TIMING=32| -sm none -mg 0"
  "27b_tg_B_1dev   |$M27|GGML_META_AR_TIMING=32| -sm tensor -dev Vulkan0"
  "27b_tg_C_1_0    |$M27|GGML_META_AR_TIMING=32| -sm tensor -ts 1/0"
  "27b_tg_D_3_1    |$M27|GGML_META_AR_TIMING=32| -sm tensor -ts 3/1"
  "27b_tg_F_layer_3_1|$M27|GGML_META_AR_TIMING=32| -sm layer -ts 3/1"
)
for k in "${KONFIG[@]}"; do
  name=$(echo "$k" | cut -d'|' -f1 | xargs); M=$(echo "$k" | cut -d'|' -f2 | xargs); envv=$(echo "$k" | cut -d'|' -f3 | xargs); flags=$(echo "$k" | cut -d'|' -f4 | xargs)
  sag "--- $name $(basename $M) [$envv] $flags ---"
  env LD_LIBRARY_PATH=$LIBS $envv timeout 900 $B/bin/llama-bench -m "$M" -ngl 99 -fa 1 -p 0 -n 128 -r 3 $flags -o json > "$AUS/$name.json" 2> "$AUS/$name.err"
  rc=$?
  sag "rc=$rc $(python3 -c "
import json
try:
  d=json.load(open('$AUS/$name.json')); print(' | '.join('%s %.2f±%.2f'%(('pp%d'%x['n_prompt'] if x['n_gen']==0 else 'tg%d'%x['n_gen']), x['avg_ts'], x['stddev_ts']) for x in d))
except Exception as e: print('no json', e)")"
  grep "meta-ar" "$AUS/$name.err" | tail -2 | tee -a "$L"
  grep -E "error|Error|abort|Segmentation" "$AUS/$name.err" | head -2 | tee -a "$L"
  sleep 3
done
sag "=== done ==="

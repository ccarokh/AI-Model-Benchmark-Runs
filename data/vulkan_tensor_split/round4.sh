#!/bin/bash
# Round 4: PR #25051 Vulkan AllReduce (Vulkan part only, rebased on df03399b8) -- smoke + bench on the mixed-vendor pair.
set -uo pipefail
B=/opt/llama-cpp-master
LIBS=/opt/llama-cpp-ar/lib:$B/lib          # PR-patched libggml-vulkan, everything else master
M9=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
M27=/opt/llm-infra/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
AUS=/root/eval/vulkan-ar/round4
RUNTIME=http://127.0.0.1:8080; SCHLUESSEL=/etc/bench/lease.token
L=$AUS/round4.log; PACHT_ID=""; HERZ=""
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }
aufraeumen(){ [ -n "$HERZ" ] && kill "$HERZ" 2>/dev/null
  [ -n "$PACHT_ID" ] && { curl -s -m 10 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" -H "x-lease-token: $(cat "$SCHLUESSEL")" || true; sag "Pacht $PACHT_ID zurueckgegeben"; }; }
trap aufraeumen EXIT INT TERM
pacht_nehmen(){ local t a; t=$(cat "$SCHLUESSEL") || return 1
  a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" -H "x-lease-token: $t" -H "Content-Type: application/json" -d '{"holder":"vulkan-ar-round4"}')
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  sag "Pacht $PACHT_ID gehalten"
  ( while :; do sleep 120; curl -s -m 10 -o /dev/null -X POST "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" -H "x-lease-token: $t" || true; done ) & HERZ=$!; }
mkdir -p "$AUS"
sag "=== round 4: PR #25051 vulkan part on $(cat $B/.built-version) ==="
pacht_nehmen || exit 1

# --- smoke: greedy completion, single card (master lib) vs tensor 3/1 (PR lib) ---
PROMPT="The three most important properties of a good benchmark are"
for v in "master|$B/lib|-sm none -mg 0" "pr|$LIBS|-sm tensor -ts 3/1" "pr|$LIBS|-sm tensor -ts 1/1"; do
  tag=$(echo "$v"|cut -d'|' -f1); lib=$(echo "$v"|cut -d'|' -f2); fl=$(echo "$v"|cut -d'|' -f3)
  sag "--- smoke $tag $fl ---"
  env LD_LIBRARY_PATH=$lib timeout 300 $B/bin/llama-completion -m "$M9" -ngl 99 -fa on $fl -p "$PROMPT" -n 48 --temp 0 -no-cnv --seed 1 2> "$AUS/smoke_${tag}_$(echo $fl|tr -d ' /').err" | tee "$AUS/smoke_${tag}_$(echo $fl|tr -d ' /').txt" | tail -c 600 | tee -a "$L"
  echo | tee -a "$L"
  grep -E "comm|proxy|OPAQUE|allreduce|error|Assert" "$AUS/smoke_${tag}_$(echo $fl|tr -d ' /').err" | head -5 | tee -a "$L"
done

# --- bench ---
# name | model | env | pn | flags
KONFIG=(
  "9b_tg_pr_3_1        |$M9 || -p 0 -n 128   | -sm tensor -ts 3/1"
  "9b_tg_pr_1_1        |$M9 || -p 0 -n 128   | -sm tensor -ts 1/1"
  "9b_tg_pr_1_0        |$M9 || -p 0 -n 128   | -sm tensor -ts 1/0"
  "9b_tg_pr_3_1_tree   |$M9 |GGML_VK_COMM_TREE=1| -p 0 -n 128 | -sm tensor -ts 3/1"
  "9b_pp_pr_3_1        |$M9 || -p 512 -n 0   | -sm tensor -ts 3/1"
  "9b_pp_pr_1_1        |$M9 || -p 512 -n 0   | -sm tensor -ts 1/1"
  "9b_tgpp_pr_3_1_d4096|$M9 || -p 512 -n 128 -d 4096 | -sm tensor -ts 3/1"
  "27b_tg_pr_3_1       |$M27|| -p 0 -n 128   | -sm tensor -ts 3/1"
  "27b_pp_pr_3_1       |$M27|| -p 512 -n 0   | -sm tensor -ts 3/1"
)
for k in "${KONFIG[@]}"; do
  name=$(echo "$k" | cut -d'|' -f1 | xargs); M=$(echo "$k" | cut -d'|' -f2 | xargs); envv=$(echo "$k" | cut -d'|' -f3 | xargs); pn=$(echo "$k" | cut -d'|' -f4 | xargs); flags=$(echo "$k" | cut -d'|' -f5 | xargs)
  sag "--- $name $(basename $M) [$envv] $pn $flags ---"
  env LD_LIBRARY_PATH=$LIBS $envv timeout 900 $B/bin/llama-bench -m "$M" -ngl 99 -fa 1 $pn -r 3 $flags -o json > "$AUS/$name.json" 2> "$AUS/$name.err"
  rc=$?
  sag "rc=$rc $(python3 -c "
import json
try:
  d=json.load(open('$AUS/$name.json')); print(' | '.join('%s %.2f±%.2f'%(x['test'] if 'test' in x else ('pp%d'%x['n_prompt'] if x['n_gen']==0 else 'tg%d'%x['n_gen']), x['avg_ts'], x['stddev_ts']) for x in d))
except Exception as e: print('no json', e)")"
  grep -E "comm|proxy|OPAQUE|error|Error|abort|Segmentation" "$AUS/$name.err" | head -3 | tee -a "$L"
  sleep 3
done
sag "=== done ==="

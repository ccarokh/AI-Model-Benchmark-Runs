#!/bin/bash
set -uo pipefail
B=/opt/llama-cpp-master; LIBS=/opt/llama-cpp-ar/lib:$B/lib
M9=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
AUS=/root/eval/vulkan-ar/round4; RUNTIME=http://127.0.0.1:8080; SCHLUESSEL=/etc/bench/lease.token
L=$AUS/smoke.log; PACHT_ID=""
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }
t=$(cat "$SCHLUESSEL"); a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" -H "x-lease-token: $t" -H "Content-Type: application/json" -d '{"holder":"vulkan-ar-smoke"}')
PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p'); [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $a"; exit 1; }
trap 'curl -s -m 10 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" -H "x-lease-token: $t"; sag "Pacht zurueckgegeben"' EXIT
sag "Pacht $PACHT_ID gehalten"
PROMPT="The three most important properties of a good benchmark are"
for v in "master|$B/lib|-sm none -mg 0" "fallback|$B/lib|-sm tensor -ts 3/1" "pr|$LIBS|-sm tensor -ts 3/1" "pr|$LIBS|-sm tensor -ts 1/1" "prproxy|$LIBS|-sm tensor -ts 3/1"; do
  tag=$(echo "$v"|cut -d'|' -f1); lib=$(echo "$v"|cut -d'|' -f2); fl=$(echo "$v"|cut -d'|' -f3); envv=""; [ "$tag" = prproxy ] && envv="GGML_VK_COMM_PROXY=1"
  out=$AUS/smoke2_${tag}_$(echo $fl|tr -d ' /')
  sag "--- smoke $tag [$envv] $fl ---"
  env LD_LIBRARY_PATH=$lib $envv timeout 300 $B/bin/llama-completion -m "$M9" -ngl 99 -fa on -c 2048 $fl -p "$PROMPT" -n 48 --temp 0 -no-cnv --seed 1 > $out.txt 2> $out.err
  sag "rc=$?"; grep -E "comm|proxy|OPAQUE|Meta device|abort|error" $out.err | grep -v "^0.*fit params" | head -6 | tee -a "$L"
  grep -E "eval time" $out.err | tee -a "$L"
  echo "TEXT: $(tr '\n' ' ' < $out.txt | head -c 400)" | tee -a "$L"
done
sag "=== md5 of outputs ==="; md5sum $AUS/smoke2_*.txt | tee -a "$L"

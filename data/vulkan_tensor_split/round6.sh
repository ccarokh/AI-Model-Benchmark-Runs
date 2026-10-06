#!/bin/bash
# Round 6 (05.10.): PR #25051 at two states on the mixed-vendor pair (RX 7900 XTX RADV + RTX 2070 NVIDIA).
#   0923 = 29395e39b9 -- still falls back to the CPU proxy when shared semaphores are missing
#   1005 = 46b21b3b4f -- "require shared semaphores": proxy removed, falls back to the generic all-reduce
# Reference: master, layer split and tensor split (generic all-reduce).
# Plus the maintainer's objection to the proxy -- it spins for the life of the meta device: CPU time of
# an idle llama-server with -sm tensor, per build, over 60 s after one request.
# Runs inside the night window (lease held by the caller). Once only.
set -uo pipefail
AUS=/root/eval/vulkan-ar/round6; mkdir -p $AUS
[ -f $AUS/FERTIG ] && { echo "round6: liegt vor"; exit 0; }
M9=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
M27=/opt/llm-infra/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
T=$AUS/round6.tsv; L=$AUS/round6.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }
[ -f $T ] || echo -e "build\tmodel\tsplit\ttest\tavg_ts\tstddev_ts\tpath" > $T

pfad(){ grep -h -o -E "CPU-proxy sync|shared semaphore[^;]*; using generic all-reduce|shared semaphore all-reduce unavailable; using generic all-reduce|OPAQUE_FD[^;]*" "$1" 2>/dev/null | head -1; }

bench(){  # build-tag build-dir model-tag model split-flags
  local tag=$1 B=$2 mt=$3 M=$4 sp=$5 name="$1_$3_$(echo $5 | tr -d ' /-')"
  for pn in "-p 0 -n 128" "-p 512 -n 0"; do
    local f=$AUS/${name}_$(echo $pn | tr -d ' -').json
    LD_LIBRARY_PATH=$B/lib timeout 900 $B/bin/llama-bench -m $M -ngl 99 -fa 1 $pn -r 3 $sp -o json > $f 2> ${f%.json}.err
    local rc=$? p; p=$(pfad ${f%.json}.err)
    python3 - "$f" "$tag" "$mt" "$sp" "${p:--}" "$rc" >> $T <<'PY'
import json,sys
f,tag,mt,sp,p,rc=sys.argv[1:]
try:
    for x in json.load(open(f)):
        t=("pp%d"%x["n_prompt"]) if x["n_gen"]==0 else ("tg%d"%x["n_gen"])
        print(f"{tag}\t{mt}\t{sp}\t{t}\t{x['avg_ts']:.2f}\t{x['stddev_ts']:.2f}\t{p}")
except Exception as e:
    print(f"{tag}\t{mt}\t{sp}\t-\t-\t-\tfehler rc={rc}")
PY
    sag "$tag $mt $sp $pn: $(tail -1 $T | cut -f4-7)"
    sleep 3
  done
}

leerlauf(){  # build-tag build-dir: CPU seconds an idle -sm tensor server burns in 60 s
  local tag=$1 B=$2 log=$AUS/idle_$1.log
  LD_LIBRARY_PATH=$B/lib $B/bin/llama-server -m $M9 -ngl 99 -fa on -sm tensor -ts 3/1 -c 4096 -np 1 \
    --host 127.0.0.1 --port 18195 > $log 2>&1 &
  local P=$! i
  for i in $(seq 1 120); do curl -s -m 2 http://127.0.0.1:18195/health | grep -q ok && break; kill -0 $P 2>/dev/null || break; sleep 2; done
  curl -s -m 120 http://127.0.0.1:18195/completion -d '{"prompt":"Hello","n_predict":16}' > /dev/null
  sleep 5
  local hz; hz=$(getconf CLK_TCK)
  local a; a=$(awk '{print $14+$15}' /proc/$P/stat 2>/dev/null)
  sleep 60
  local b; b=$(awk '{print $14+$15}' /proc/$P/stat 2>/dev/null)
  local cpu; cpu=$(python3 -c "print(round(($b-$a)/$hz/60*100,1))" 2>/dev/null || echo -)
  echo -e "$tag\tqwen3.5-9b\t-sm tensor -ts 3/1\tidle_cpu_percent_60s\t$cpu\t-\t$(pfad $log)" >> $T
  sag "$tag Leerlauf: ${cpu} % CPU ueber 60 s (100 % = ein Kern)"
  kill $P; wait $P 2>/dev/null; sleep 3
}

sag "=== round 6 ==="
for v in "0923|/opt/llama-cpp-vktp-0923" "1005|/opt/llama-cpp-vktp-1005" "master|/opt/llama-cpp-master"; do
  tag=${v%%|*}; B=${v#*|}
  [ -x $B/bin/llama-bench ] || { sag "$tag: Build fehlt -- uebersprungen"; continue; }
  sag "--- $tag: $(LD_LIBRARY_PATH=$B/lib $B/bin/llama-bench --version 2>&1 | head -1) ---"
  bench $tag $B 9b $M9 "-sm tensor -ts 3/1"
  bench $tag $B 27b $M27 "-sm tensor -ts 3/1"
  [ $tag = master ] && { bench $tag $B 9b $M9 "-sm layer -ts 3/1"; bench $tag $B 27b $M27 "-sm layer -ts 3/1"; }
  [ $tag != master ] && leerlauf $tag $B
done
touch $AUS/FERTIG; sag "FERTIG_ROUND6"

#!/bin/bash
# Round 8b (26.10.): the real "before" for round 8 -- master f5027fb21, the merge base of PR #25051 at
# ecfee2ece6 (round 8's "1026base" rows were the PR head again, see round8_bauen.sh). Same measurement,
# results appended to round8.tsv.
set -uo pipefail
AUS=/root/eval/vulkan-ar/round8; mkdir -p $AUS
[ -f $AUS/FERTIG_8b ] && { echo "round8b: liegt vor"; exit 0; }
M9=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
M27=/opt/llm-infra/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
T=$AUS/round8.tsv; L=$AUS/round8.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }
[ -f $T ] || echo -e "build\tmodel\tsplit\ttest\tavg_ts\tstddev_ts\tcpu_percent\tpath" > $T

pfad(){ grep -h -o -E "CPU-proxy sync|[^:]*using generic all-reduce|all-reduce bridge failed[^\n]*" "$1" 2>/dev/null | head -1; }

bench(){  # build-tag build-dir model-tag model split-flags [env]
  local tag=$1 B=$2 mt=$3 M=$4 sp=$5 ev=${6:-} name="$1_$3_$(echo $5 | tr -d ' /-')${6:+_spin0}"
  for pn in "-p 0 -n 128" "-p 512 -n 0"; do
    local f=$AUS/${name}_$(echo $pn | tr -d ' -').json
    local TIMEFORMAT="%R %U %S"
    { time env $ev LD_LIBRARY_PATH=$B/lib timeout 900 $B/bin/llama-bench -m $M -ngl 99 -fa 1 $pn -r 3 $sp -o json > $f 2> ${f%.json}.err ; } 2> ${f%.json}.time
    local rc=$? p cpu; p=$(pfad ${f%.json}.err)
    cpu=$(awk '{ if ($1 > 0) printf "%.0f", ($2 + $3) / $1 * 100; else print "-" }' ${f%.json}.time)
    python3 - "$f" "$tag${ev:+ $ev}" "$mt" "$sp" "${p:--}" "$rc" "$cpu" >> $T <<'PY'
import json,sys
f,tag,mt,sp,p,rc,cpu=sys.argv[1:]
try:
    for x in json.load(open(f)):
        t=("pp%d"%x["n_prompt"]) if x["n_gen"]==0 else ("tg%d"%x["n_gen"])
        print(f"{tag}\t{mt}\t{sp}\t{t}\t{x['avg_ts']:.2f}\t{x['stddev_ts']:.2f}\t{cpu}\t{p}")
except Exception as e:
    print(f"{tag}\t{mt}\t{sp}\t-\t-\t-\t{cpu}\tfehler rc={rc}")
PY
    sag "$tag${ev:+ $ev} $mt $sp $pn: $(tail -1 $T | cut -f4-8)"
    sleep 3
  done
}

leerlauf(){  # build-tag build-dir [env]: CPU an idle -sm tensor server burns in 60 s
  local tag=$1 B=$2 ev=${3:-} log=$AUS/idle_$1${3:+_spin0}.log
  env $ev LD_LIBRARY_PATH=$B/lib $B/bin/llama-server -m $M9 -ngl 99 -fa on -sm tensor -ts 3/1 -c 4096 -np 1 \
    --host 127.0.0.1 --port 18195 > $log 2>&1 &
  local P=$! i
  for i in $(seq 1 120); do curl -s -m 2 http://127.0.0.1:18195/health | grep -q ok && break; kill -0 $P 2>/dev/null || break; sleep 2; done
  curl -s -m 120 http://127.0.0.1:18195/completion -d '{"prompt":"Hello","n_predict":16}' > /dev/null
  sleep 5
  local thr; thr=$(cat /proc/$P/task/*/comm 2>/dev/null | grep -c ggml-vk-comm)
  local hz; hz=$(getconf CLK_TCK)
  local a; a=$(awk '{print $14+$15}' /proc/$P/stat 2>/dev/null)
  sleep 60
  local b; b=$(awk '{print $14+$15}' /proc/$P/stat 2>/dev/null)
  local cpu; cpu=$(python3 -c "print(round(($b-$a)/$hz/60*100,1))" 2>/dev/null || echo -)
  echo -e "$tag${ev:+ $ev}\tqwen3.5-9b\t-sm tensor -ts 3/1\tidle_cpu_percent_60s\t$cpu\t-\t-\tggml-vk-comm threads: $thr; $(pfad $log)" >> $T
  sag "$tag${ev:+ $ev} Leerlauf: ${cpu} % CPU ueber 60 s (100 % = ein Kern), ggml-vk-comm-Threads: $thr"
  kill $P; wait $P 2>/dev/null; sleep 3
}

sag "=== round 8b ==="
for v in "1026master|/opt/llama-cpp-vktp-1026master"; do
  tag=${v%%|*}; B=${v#*|}
  [ -x $B/bin/llama-bench ] || { sag "$tag: Build fehlt -- uebersprungen"; continue; }
  sag "--- $tag: $(LD_LIBRARY_PATH=$B/lib $B/bin/llama-bench --version 2>&1 | head -1) ---"
  bench $tag $B 9b $M9 "-sm tensor -ts 3/1"
  bench $tag $B 27b $M27 "-sm tensor -ts 3/1"
  case $tag in
    1026)     bench $tag $B 9b $M9 "-sm tensor -ts 3/1" GGML_VK_ALLREDUCE_SPIN_US=0
              bench $tag $B 27b $M27 "-sm tensor -ts 3/1" GGML_VK_ALLREDUCE_SPIN_US=0
              leerlauf $tag $B
              leerlauf $tag $B GGML_VK_ALLREDUCE_SPIN_US=0 ;;
    1026master) bench $tag $B 9b $M9 "-sm layer -ts 3/1"
              bench $tag $B 27b $M27 "-sm layer -ts 3/1" ;;
  esac
done
touch $AUS/FERTIG_8b; sag "FERTIG_ROUND8B"

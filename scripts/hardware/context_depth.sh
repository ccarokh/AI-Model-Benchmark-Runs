#!/bin/bash
# What a filled context costs -- throughput AND energy over depth.
#
# The tokens/Wh measurement found that reading is 19-30x cheaper than writing.
# But it measured at depth 0, i.e. with an empty KV cache. Attention grows
# quadratically with depth, and generation additionally has to read the growing
# cache for every token. So "context is cheap" cannot hold over the full
# length, and exactly where it tips is the number you size a RAG system by.
#
# One variable: depth. Model, flags and card stay the same.
# The fa block at the end is deliberately separate and separately labelled --
# it changes a second variable and therefore does not belong in the same curve.
set -u
OUT=/root/kontexttiefe; mkdir -p $OUT
D=/sys/class/drm/card1/device
W=$(ls $D/hwmon/hwmon*/power1_average | head -1)
export LD_LIBRARY_PATH=/opt/llama-cpp-nb/lib
BENCH=/opt/llama-cpp-nb/bin/llama-bench
M=/opt/llm-infra/models

declare -A F
F[llama-3.2-3b]=$M/llama-3.2-3b/Llama-3.2-3B-Instruct-Q4_K_M.gguf
F[qwen3.5-9b]=$M/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
F[qwen3-30b-a3b]=$M/qwen3-30b-a3b/qwen3-30b-a3b-instruct-2507-Q4_K_M.gguf

warte(){ for i in $(seq 1 180); do
    v=$(( $(cat $D/mem_info_vram_used)/1048576 )); f=$(pgrep -x llama-server|wc -l)
    [ "$v" -lt 500 ] && [ "$f" -eq 0 ] && return 0; sleep 10
  done; return 1; }

messen(){ # $1=name $2=tiefe $3=fa $4=marke
  local n=$1 t=$2 fa=$3 marke=$4
  local d=${F[$n]}
  [ -s "$d" ] || { echo "$n: Datei fehlt"; return; }
  warte || { echo "$n/$marke: Karte belegt"; return; }
  local st=$OUT/${n}_${marke}
  : > $st.watt
  ( while true; do echo "$(date +%s.%N) $(cat $W)"; sleep 1; done ) > $st.watt &
  local sp=$!
  # timeout: at 32k depth the prefill takes long, but not arbitrarily long.
  timeout 1800 $BENCH -m "$d" -p 2048 -n 128 -d "$t" -fa "$fa" -r 3 \
      -ngl 99 -sm none -mg 0 -o json > $st.json 2> $st.log
  local rc=$?
  kill $sp 2>/dev/null
  if [ $rc -ne 0 ]; then
    # The most common real reason is too little VRAM for the KV cache at
    # large depth. That is a result, not a failure -- so name it, don't swallow it.
    local grund="rc=$rc"
    grep -qi "out of memory\|failed to allocate\|ErrorOutOfDevice" $st.log && grund="VRAM reicht nicht"
    echo "$n  tiefe=$t  fa=$fa  ENTFAELLT ($grund)"
    return
  fi
  python3 - $st.watt $st.json "$n" "$t" "$fa" <<'PY'
import sys, json
w=[(float(a),int(b)/1e6) for a,b in (l.split() for l in open(sys.argv[1]) if l.strip())]
d=json.load(open(sys.argv[2]))
c=sum(sum(e["samples_ns"]) for e in d)/1e9
r=[x for x in w if x[0]>=w[-1][0]-c] or w
wh=sum((r[i][1]+r[i-1][1])/2*(r[i][0]-r[i-1][0])/3600 for i in range(1,len(r)))
mw=sum(x[1] for x in r)/len(r)
v={}
for e in d:
    v["pp" if e["n_prompt"] else "tg"]=e["avg_ts"]
# Tokens per Wh split by phase would be misleading here, because both phases
# lie inside the same wattage window. Hence only the throughput numbers plus
# total energy.
print(f"{sys.argv[3]:<16} tiefe={int(sys.argv[4]):>6}  fa={sys.argv[5]:<4} "
      f"pp2048={v.get('pp',0):8.1f} t/s   tg128={v.get('tg',0):7.2f} t/s   "
      f"{mw:6.1f} W  {wh*1000:8.1f} mWh  n={len(r)}")
PY
  sleep 3
}

echo "Start $(date -Is)"
echo "--- Tiefenkurve, flash-attn an (wie in Produktion) ---"
for n in llama-3.2-3b qwen3.5-9b qwen3-30b-a3b; do
  for t in 0 4096 16384 32768; do messen $n $t on "d${t}_faon"; done
done
echo "--- flash-attn aus, nur zum Vergleich bei zwei Tiefen ---"
for t in 0 32768; do messen qwen3.5-9b $t off "d${t}_faoff"; done
echo FERTIG_TIEFE

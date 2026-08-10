#!/bin/bash
# Was ein gefuellter Kontext kostet -- Durchsatz UND Energie ueber die Tiefe.
#
# Die Token/Wh-Messung hat ergeben, dass Lesen 19-30x billiger ist als Schreiben.
# Sie hat aber bei Tiefe 0 gemessen, also mit leerem KV-Cache. Attention waechst
# quadratisch mit der Tiefe, Erzeugung muss ausserdem bei jedem Token den
# wachsenden Cache lesen. "Kontext ist billig" kann also nicht ueber die ganze
# Laenge gelten, und genau die Stelle, wo es kippt, ist die Zahl, nach der man
# ein RAG-System auslegt.
#
# Eine Variable: die Tiefe. Modell, Flags, Karte bleiben gleich.
# Der fa-Block am Ende ist bewusst getrennt und getrennt beschriftet -- er
# aendert eine zweite Variable und gehoert deshalb nicht in dieselbe Kurve.
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
  # timeout: bei 32k Tiefe dauert der Vorlauf lange, aber nicht beliebig.
  timeout 1800 $BENCH -m "$d" -p 2048 -n 128 -d "$t" -fa "$fa" -r 3 \
      -ngl 99 -sm none -mg 0 -o json > $st.json 2> $st.log
  local rc=$?
  kill $sp 2>/dev/null
  if [ $rc -ne 0 ]; then
    # Der haeufigste echte Grund ist zu wenig VRAM fuer den KV-Cache bei grosser
    # Tiefe. Das ist ein Ergebnis, kein Ausfall -- also benennen, nicht schlucken.
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
# Token je Wh getrennt je Phase waere hier irrefuehrend, weil beide Phasen im
# selben Wattfenster liegen. Deshalb nur die Durchsatzzahlen plus Gesamtenergie.
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

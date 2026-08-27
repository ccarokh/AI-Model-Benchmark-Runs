#!/bin/bash
# The fourth arm, and the rest of the belebele corpus.
#
# THE FOURTH ARM separates the recipe from the format. Three arms are measured:
# QAT weights in Q4_0, ordinary weights in Q4_0, ordinary weights in Q4_K_M.
# The QAT file is the smallest, the fastest and holds the most context -- but
# it is also the only one carrying BOTH the QAT recipe and the plain Q4_0
# format, so its advantage cannot be attributed. Quantising the QAT weights
# into Q4_K_M gives the missing cell: recipe without the format.
set -u
L=/root/nacht2_101.log
OUT=/root/belebele_25aug.jsonl
VENV=/root/evalenv
B=/opt/mess/llama.cpp/build/bin
QUELLE=/opt/mess/models/gemma-4-12b-qat/gemma-4-12b-it-qat-q4_0.gguf
ZIEL=/opt/mess/models/gemma-4-12b-qat-q4km/gemma-4-12b-it-qat-Q4_K_M.gguf
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }

sag "=== waiting for anything still measuring ==="
while pgrep -f "[r]un_all.py|[q]ualitaet_101.sh" >/dev/null; do sleep 60; done

# 1. The tool has to exist first -- this build was configured without it.
if [ ! -x $B/llama-quantize ]; then
  sag "=== building llama-quantize ==="
  (cd /opt/mess/llama.cpp/build && nice -n 10 cmake --build . --target llama-quantize -j 10) >>$L 2>&1 \
    && sag "  built" || { sag "  BUILD FAILED -- stopping"; exit 1; }
fi

# 2. Requantising an already-quantised file loses a little either way; what is
#    being compared is not "QAT at its best" but "the same weights in the other
#    format", and both arms of that comparison start from the same gguf.
if [ ! -s "$ZIEL" ]; then
  sag "=== quantising the QAT weights into Q4_K_M ==="
  mkdir -p "$(dirname $ZIEL)"
  LD_LIBRARY_PATH=$B $B/llama-quantize --allow-requantize "$QUELLE" "$ZIEL.teil" Q4_K_M 10 >>$L 2>&1 \
    && mv "$ZIEL.teil" "$ZIEL" && sag "  $(du -h $ZIEL | cut -f1)" \
    || { sag "  QUANTISING FAILED -- the fourth arm is not measured"; rm -f "$ZIEL.teil"; }
fi

# 3. The test bench picks the new file up by itself -- models are discovered,
#    not listed.
cd /root/testbench || exit 1
M=$(find /opt/mess/models -name "*.gguf" ! -name "*mmproj*" ! -name "*mtp-*" | sort | tr "\n" " ")
sag "=== test bench over $(echo $M | wc -w) models ==="
TESTBENCH_MODELS="$M" python3 run_all.py >> $L 2>&1

# 4. belebele for everything that has no score yet, both stands.
messen(){  # arm, model file
  local name=$1 modell=$2
  [ -s "$modell" ] || { sag "  $name: file missing"; return; }
  LD_LIBRARY_PATH=$B $B/llama-server -m "$modell" -ngl 99 -c 8192 --jinja --reasoning off \
      --host 127.0.0.1 --port 8098 > /tmp/q.$name.log 2>&1 &
  local sp=$! i=0 bereit=0
  while [ $i -lt 240 ]; do
    curl -s -m 2 http://127.0.0.1:8098/health 2>/dev/null | grep -q '"ok"' && { bereit=1; break; }
    kill -0 $sp 2>/dev/null || break
    sleep 1; i=$((i+1))
  done
  [ $bereit -eq 1 ] || { sag "  $name: server did not come up"; kill $sp 2>/dev/null; return; }
  for stand in logprob generate; do
    grep -q "\"arm\": \"$name\", \"stand\": \"$stand\"" $OUT 2>/dev/null && continue
    roh=/tmp/belebele.$name.$stand.json
    $VENV/bin/python3 /root/eval_belebele_harness.py http://127.0.0.1:8098 server "$stand" 900 \
      > $roh 2>>$L
    if [ ! -s $roh ]; then sag "  $name/$stand produced nothing"; continue; fi
    python3 -c "
import json
d=json.load(open('$roh')); d['arm']='$name'; d['stand']='$stand'; d['reasoning']='off'
print(json.dumps(d))" >> $OUT
    sag "  $(tail -1 $OUT)"
  done
  kill $sp 2>/dev/null; wait $sp 2>/dev/null; sleep 5
}

sag "=== belebele: the fourth arm first ==="
messen qat-q4_k_m "$ZIEL"

sag "=== belebele: the rest of the store ==="
for f in /opt/mess/models/*/*.gguf; do
  case "$f" in *mmproj*|*mtp-*|*bge-m3*) continue;; esac
  name=$(basename "$f" .gguf)
  grep -q "\"arm\": \"$name\"" $OUT 2>/dev/null && continue
  case "$f" in *gemma-4-12b-qat/*|*gemma-4-12b-q4_0/*|*gemma-4-12b-q4km/*|*llama-3.1-8b/*) continue;; esac
  sag "--- $name ---"
  messen "$name" "$f"
done
sag "=== done ==="

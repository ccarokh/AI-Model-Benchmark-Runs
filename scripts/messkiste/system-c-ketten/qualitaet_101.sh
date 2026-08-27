#!/bin/bash
# The other half of the QAT question.
#
# System C measured what the three Gemma arms COST: file size, VRAM, context
# ceiling, tokens per second. None of that says whether the QAT recipe answers
# better -- the output probe compares a prime-number prompt, which two similar
# models agree on by construction. This runs belebele deu_Latn against each arm
# on the same card.
#
# TWO STANDS, because one of them lied. Read as a letter probability, the QAT
# arm scored 35 % -- barely above the 25 % of guessing -- while answering freely
# it scored 90 % on the same twenty questions. The model thinks first, so the
# first token after the prompt was thought text, not a letter. With thinking
# switched off both stands scored 20 out of 20. Running both is what makes that
# visible instead of publishable.
#
# THE PROMPT COMES FROM THE MODEL FILE. No Hugging Face repository, no token on
# a machine that goes back in two days, and no mirror -- the mirror tried first
# opened a thinking channel that the model's own template does not.
set -u
L=/root/qualitaet_101.log
OUT=/root/belebele_25aug.jsonl
VENV=/root/evalenv
B=/opt/mess/llama.cpp/build/bin
N=${N:-900}
KAL=${KAL:-20}
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }

sag "=== waiting for the test bench ==="
while pgrep -f "[r]un_all.py" >/dev/null; do sleep 60; done

ARME=(
  "qat-q4_0:/opt/mess/models/gemma-4-12b-qat/gemma-4-12b-it-qat-q4_0.gguf"
  "ptq-q4_0:/opt/mess/models/gemma-4-12b-q4_0/gemma-4-12B-it-Q4_0.gguf"
  "ptq-q4_k_m:/opt/mess/models/gemma-4-12b-q4km/gemma-4-12B-it-Q4_K_M.gguf"
  "llama-3.1-8b:/opt/mess/models/llama-3.1-8b/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
)

messen(){  # $1 = arm, $2 = stand, $3 = number of questions -> one json line
  local name=$1 stand=$2 anzahl=$3 roh=/tmp/belebele.$1.$2.json
  $VENV/bin/python3 /root/eval_belebele_harness.py http://127.0.0.1:8098 server "$stand" "$anzahl" \
    > $roh 2>>$L
  [ -s $roh ] || return 1
  python3 -c "
import json
d=json.load(open('$roh')); d['arm']='$name'; d['stand']='$stand'; d['reasoning']='off'
print(json.dumps(d))
"
}

for eintrag in "${ARME[@]}"; do
  name=${eintrag%%:*}; modell=${eintrag#*:}
  [ -s "$modell" ] || { sag "$name: model file missing -- skipped"; continue; }
  sag "=== $name ==="
  LD_LIBRARY_PATH=$B $B/llama-server -m "$modell" -ngl 99 -c 8192 --jinja --reasoning off \
      --host 127.0.0.1 --port 8098 > /tmp/q.$name.log 2>&1 &
  SPID=$!
  i=0; bereit=0
  while [ $i -lt 180 ]; do
    curl -s -m 2 http://127.0.0.1:8098/health 2>/dev/null | grep -q '"ok"' && { bereit=1; break; }
    kill -0 $SPID 2>/dev/null || break
    sleep 1; i=$((i+1))
  done
  [ $bereit -eq 1 ] || { sag "  server did not come up -- skipped"; kill $SPID 2>/dev/null; continue; }

  for stand in logprob generate; do
    if grep -q "\"arm\": \"$name\", \"stand\": \"$stand\"" $OUT 2>/dev/null; then
      sag "  $stand already measured"; continue
    fi
    # A CHEAP CALIBRATION FIRST. Whether a stand can read this model at all is
    # a question of twenty questions, not nine hundred -- and a stand that
    # collapses to guessing has to be visible as such, not averaged into a
    # score. It is recorded either way.
    kal=$(messen "$name" "$stand" $KAL) || { sag "  $stand: calibration produced nothing"; continue; }
    genauigkeit=$(printf '%s' "$kal" | python3 -c "import json,sys;print(json.load(sys.stdin)['accuracy'])")
    sag "  $stand calibration on $KAL: $genauigkeit"
    if python3 -c "import sys;sys.exit(0 if float('$genauigkeit')<0.5 else 1)"; then
      sag "  $stand reads this model at chance level -- $N questions not run"
      printf '%s\n' "$kal" | python3 -c "
import json,sys
d=json.loads(sys.stdin.read()); d['note']='calibration only -- stand at chance level'
print(json.dumps(d))" >> $OUT
      continue
    fi
    voll=$(messen "$name" "$stand" $N) || { sag "  $stand: PRODUCED NOTHING at n=$N"; continue; }
    printf '%s\n' "$voll" >> $OUT
    sag "  $voll"
  done
  kill $SPID 2>/dev/null; wait $SPID 2>/dev/null
  sleep 5
done
sag "=== done ==="

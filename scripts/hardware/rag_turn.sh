#!/bin/bash
# Measures a REAL RAG turn under production flags.
#
# WHY THIS BUILDING BLOCK EXISTS: `llama-bench` measures without KV quantization
# and without --parallel. Under production flags one 9B model collapsed by a factor
# of 6.8, and the ranking BETWEEN models inverted as a result. That makes
# llama-bench unsuitable for statements about production -- it is only good as a
# constant across versions. This measures what a user actually waits for instead:
# prompt in, 400 tokens out, wall clock.
#
# Usage:  rag_turn.sh <model-file> [runs] [concurrent]
#         runs        default 3 (the first counts as warm-up and is dropped)
#         concurrent  default 1; at 2, two requests run in parallel
#
# Starts its own server on port 8199 and shuts it down again.
# Prints one line; on failure the line begins with ERROR.
set -u
MODEL="${1:?model file missing}"
N="${2:-3}"
CONCURRENT="${3:-1}"
PORT=8199

# Find the card by DRIVER NAME -- the card number is not stable with two GPUs
# installed, and picking the wrong one silently reports the idle card's power.
CARD=""
for d in /sys/class/drm/card*/device; do
  grep -q "^DRIVER=amdgpu$" "$d/uevent" 2>/dev/null || continue
  [ -r "$d/mem_info_vram_used" ] || continue
  CARD="$d"; break
done
HW=""
[ -n "$CARD" ] && HW=$(echo "$CARD"/hwmon/hwmon*/ | cut -d" " -f1)

# Fixed request body, deterministically generated so the number stays comparable
# across hosts and measurement series. Yields 6416 prompt tokens.
python3 <<'PY'
import json
t = ("The key-value cache grows linearly with context length and thereby limits the "
     "number of concurrent requests. Quantization reduces memory use but costs "
     "accuracy. Prompt processing is compute-bound, whereas token generation is "
     "bandwidth-bound. ") * 90
json.dump({"messages": [{"role": "user",
           "content": t + "\nSummarize the text above in exactly five sentences."}],
           "max_tokens": 400, "temperature": 0.7, "cache_prompt": False},
          open("/tmp/ragturn.json", "w"))
PY

# GUARD: this script clears the card indiscriminately -- it terminates EVERY
# llama-server. If an on-demand model supervisor runs on the GPU host, calling this
# standalone would kill models it has loaded for real requests.
if [ "$(systemctl is-active llm-runtime 2>/dev/null)" = "active" ] \
   && [ "${ALLOW_LLM_RUNTIME:-0}" != "1" ]; then
  echo "ERROR: the model supervisor is running. This script would kill its models." >&2
  echo "  Stop it first (that is an operator action, not this script's):" >&2
  echo "      systemctl stop llm-runtime" >&2
  exit 1
fi

cleanup() { P=$(pgrep -x llama-server); for x in $P; do kill "$x" 2>/dev/null; done; sleep 3; }
cleanup

# Production flags -- exactly those of the production chat slot.
cd /tmp || exit 1
nohup llama-server -m "$MODEL" --host 127.0.0.1 --port $PORT --device Vulkan0 \
  --ctx-size 32768 --batch-size 512 --ubatch-size 512 -ngl 99 \
  --cache-type-k q8_0 --cache-type-v q8_0 --parallel 2 > /tmp/rag_srv.log 2>&1 </dev/null &

ready=0
for _ in $(seq 1 60); do
  curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q 200 && { ready=1; break; }
  sleep 3
done
[ "$ready" -ne 1 ] && { echo "ERROR: server does not start -- $(tail -2 /tmp/rag_srv.log | tr '\n' ' ')"; cleanup; exit 1; }
sleep 5

request() {  # $1 = output file -> writes "seconds prompt_tok answer_tok"
  local t
  t=$(curl -s --max-time 300 -o "$1.json" -w "%{time_total}" \
        "http://127.0.0.1:$PORT/v1/chat/completions" \
        -H "Content-Type: application/json" -d @/tmp/ragturn.json)
  python3 -c "
import json,sys
try:
    u = json.load(open('$1.json'))['usage']
    print('$t', u['prompt_tokens'], u['completion_tokens'])
except Exception:
    print('$t', 0, 0)
"
}

# Sample power DURING the measurement. A reading taken right after the request is
# worthless -- by then the card is idle again (measured: 22 W one second after a
# turn that ran at 286 W).
: > /tmp/rag_watt
if [ -n "$HW" ]; then
  ( while :; do cat "$HW/power1_average" 2>/dev/null >> /tmp/rag_watt; sleep 1; done ) &
  SAMPLER=$!
else
  SAMPLER=""
fi

request /tmp/rag_warm >/dev/null 2>&1          # warm-up, does not count

: > /tmp/rag_times
for i in $(seq 1 "$N"); do
  if [ "$CONCURRENT" -gt 1 ]; then
    # ${i}_${j} with braces: `$i_$j` would be the variable `i_` followed by `$j`,
    # i.e. the same filename for every run -- the answers would overwrite each other.
    for j in $(seq 1 "$CONCURRENT"); do request "/tmp/rag_${i}_${j}" >> /tmp/rag_times & done
    wait
  else
    request "/tmp/rag_$i" >> /tmp/rag_times
  fi
done

[ -n "$SAMPLER" ] && kill "$SAMPLER" 2>/dev/null
cleanup

python3 <<'PY'
import statistics
rows = [r.split() for r in open("/tmp/rag_times") if r.strip()]
times = [float(r[0]) for r in rows]
if not times:
    print("ERROR: no measurements"); raise SystemExit(1)
pt = {int(r[1]) for r in rows}
at = {int(r[2]) for r in rows}
try:
    watt = [int(w) // 1000000 for w in open("/tmp/rag_watt") if w.strip()]
    watt = [w for w in watt if w > 60]          # drop idle readings between requests
except Exception:
    watt = []
med = statistics.median(times)
span = f"{min(times):.2f}-{max(times):.2f}" if len(times) > 1 else f"{times[0]:.2f}"
parts = [f"RAG turn {med:.2f} s (median of {len(times)}, range {span})"]
parts.append(f"prompt {'/'.join(map(str,sorted(pt)))} tok, answer {'/'.join(map(str,sorted(at)))} tok")
if watt:
    parts.append(f"power {sum(watt)//len(watt)} W mean / {max(watt)} W peak")
print(" | ".join(parts))
PY

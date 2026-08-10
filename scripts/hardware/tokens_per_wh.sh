#!/bin/bash
# Tokens per watt-hour, prefill and generation measured separately.
#
# Why llama-bench and not a chat request: llama-bench runs the two phases in
# isolation, so each can be priced on its own. In a normal chat turn they are
# mixed and the result is a blend whose ratio depends on the prompt.
#
# The trap this script exists to avoid: the power sampler must not run while the
# model is loading. A 17 GB model loads for ~28 s with the card idle, and that
# idle time averaged into the mean makes large models look efficient. The load
# window is therefore cut off in the analysis below, not in the sampler --
# llama-bench does not announce when loading ends, but it reports how long each
# repetition took, and the repetitions are the last thing it does before exiting.
#
# Fresh process per measurement, card verified empty beforehand.
# -sm none -mg 0: otherwise Vulkan spreads the model across both devices.
set -u
OUT=${OUT:-/root/energie_token}; mkdir -p "$OUT"
M=${MODELS:-/opt/llm-infra/models}
D=${CARD:-/sys/class/drm/card1/device}
W=$(ls "$D"/hwmon/hwmon*/power1_average | head -1)
BIN=${BENCH_BIN:-/opt/llama-cpp-nb/bin/llama-bench}
export LD_LIBRARY_PATH=${BENCH_LIBS:-/opt/llama-cpp-nb/lib}

declare -A F
F[llama-3.2-3b]=$M/llama-3.2-3b/Llama-3.2-3B-Instruct-Q4_K_M.gguf
F[qwen3.5-9b]=$M/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
F[gemma-4-12b]=$M/gemma-4-12b-it/gemma-4-12b-it-Q4_K_M.gguf
F[deepseek-r1-14b]=$M/deepseek-r1-14b/DeepSeek-R1-Distill-Qwen-14B-Q4_K_M.gguf
F[gpt-oss-20b]=$M/gpt-oss-20b/gpt-oss-20b-MXFP4.gguf
F[qwen3-30b-a3b]=$M/qwen3-30b-a3b/qwen3-30b-a3b-instruct-2507-Q4_K_M.gguf
F[qwen3.6-27b]=$M/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
F[nanbeige-4.2-3b]=$M/nanbeige-4.2-3b/Nanbeige4.2-3B-Q4_K_M.gguf
F[qwen3-coder-30b-a3b]=$M/qwen3-coder-30b-a3b/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf

# The card guard. A health probe or a chat request that lands mid-measurement
# does not produce an error -- it produces a plausible wrong number.
warte(){ for i in $(seq 1 300); do
    v=$(( $(cat "$D"/mem_info_vram_used)/1048576 )); f=$(pgrep -x llama-server|wc -l)
    [ "$v" -lt 500 ] && [ "$f" -eq 0 ] && return 0; sleep 10
  done; return 1; }

messen(){ # $1=name $2=file $3=phase $4...=flags
  local n=$1 d=$2 ph=$3; shift 3
  [ -s "$d" ] || { echo "$n: file missing"; return; }
  warte || { echo "$n/$ph: card busy"; return; }
  : > "$OUT/${n}_${ph}.watt"
  ( while true; do echo "$(date +%s.%N) $(cat "$W")"; sleep 1; done ) > "$OUT/${n}_${ph}.watt" &
  local sp=$!
  "$BIN" -m "$d" "$@" -ngl 99 -sm none -mg 0 -o json > "$OUT/${n}_${ph}.json" 2> "$OUT/${n}_${ph}.log"
  local rc=$?
  kill $sp 2>/dev/null
  # rc before writing: a crashed run still leaves a .watt file, and its duration
  # would otherwise be recorded as a fast measurement.
  [ $rc -ne 0 ] && { echo "$n/$ph: FAILED rc=$rc"; return; }
  auswerten "$OUT/${n}_${ph}" "$n" "$ph"
  sleep 3
}

auswerten(){
  python3 - "$1.watt" "$1.json" "$2" "$3" <<'PY'
import sys, json
w = [(float(a), int(b)/1e6) for a, b in (l.split() for l in open(sys.argv[1]) if l.strip())]
e = json.load(open(sys.argv[2]))[0]

# reps is NOT a key in llama-bench json output -- it has to be counted from the
# per-repetition samples. Reading e.get("reps", 1) silently divides by five.
reps    = len(e["samples_ns"])
compute = sum(e["samples_ns"]) / 1e9
tokens  = (e["n_prompt"] + e["n_gen"]) * reps

# Only the compute window. The repetitions are the last thing the process does,
# so the tail of the trace is exactly the work whose tokens are being counted.
r  = [x for x in w if x[0] >= w[-1][0] - compute]
wh = sum((r[i][1] + r[i-1][1]) / 2 * (r[i][0] - r[i-1][0]) / 3600 for i in range(1, len(r)))
mw = sum(x[1] for x in r) / len(r)

# The sample count travels with the result: at 1 Hz a 3 s window has 4 points,
# and the mean is then an artifact of where the ticks fell.
warnung = "  <-- few samples" if len(r) < 8 else ""
print(f"{sys.argv[3]:<20}{sys.argv[4]:<10}{tokens:>7} tok  {e['avg_ts']:8.1f} t/s  "
      f"{mw:6.1f} W  {wh*1000:8.1f} mWh  {tokens/wh if wh else 0:9.0f} tok/Wh  "
      f"n={len(r)}{warnung}")
PY
}

echo "idle: $(( $(cat "$W")/1000 )) mW"
for n in "${!F[@]}"; do
  messen "$n" "${F[$n]}" prefill   -p 4096 -n 0   -r 5
  messen "$n" "${F[$n]}" erzeugung -p 0    -n 512 -r 5
done
echo DONE

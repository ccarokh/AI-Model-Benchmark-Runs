#!/bin/bash
# Multi-GPU under SUSTAINED load -- layer vs tensor split, single card as reference.
#
# WHY THIS EXISTS IN THIS FORM
# Earlier runs used -n 128, i.e. about three seconds of generation per repetition.
# The fans never even spun up. Same lesson as the throttling measurement: anything
# measured in seconds runs on a boost clock the card does not hold under sustained
# load -- the absolute numbers come out too good. For a before/after comparison
# that is harmless (both sides measured the same way), but it is useless as an
# operating figure.
#
# So: -n 3000 instead of 128. Per repetition that is 78 s (XTX alone) to 153 s
# (tensor split); times three repetitions, 4 to 8 minutes of uninterrupted
# generation per configuration. Enough for the card to reach thermal steady state.
#
# BURDEN OF PROOF
# Without a recorded temperature, "sustained load" is just another claim. So a
# sampler runs alongside each configuration and the result reports power,
# temperature and fan speed. If it says 0 rpm and 40 C, it was a breeze again and
# the numbers are to be discarded.
set -uo pipefail

# ---- configure for your host -------------------------------------------------
BENCH=/opt/llama-cpp/bin/llama-bench          # llama-bench on the GPU host
MODEL=/opt/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
H=root@gpu-host                                # ssh target of the GPU host
CARD=card1                                     # which /sys/class/drm/card* is the AMD GPU
OUTDIR=./results
# ------------------------------------------------------------------------------

TAG="${1:-sustained}"
LOG=$OUTDIR/multigpu_${TAG}.log
RES=$OUTDIR/multigpu_${TAG}.txt
mkdir -p "$OUTDIR"

# If you run benchmarks alongside a production service, put a lease/mutex here so
# two runs cannot share the GPU. Ours lives elsewhere; without one, just make sure
# nothing else is using the card.
# source /path/to/gpu_lease.sh && lease_acquire "multigpu" 7200 || exit 1

say() { echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$LOG"; }

say "=== Multi-GPU under sustained load ($TAG) ==="

# Sampler on the GPU host: writes watts/degrees/rpm of the AMD card to a file.
# Terminated via the PID it reports back, NEVER via a search pattern --
# `pkill -f` would match the invocation doing the killing.
sampler_start() {
  ssh -o BatchMode=yes $H "rm -f /tmp/gpu_sample.txt; nohup sh -c 'while :; do
      P=\$(cat /sys/class/drm/$CARD/device/hwmon/hwmon*/power1_average 2>/dev/null | head -1)
      T=\$(cat /sys/class/drm/$CARD/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
      F=\$(cat /sys/class/drm/$CARD/device/hwmon/hwmon*/fan1_input 2>/dev/null | head -1)
      B=\$(cat /sys/class/drm/$CARD/device/gpu_busy_percent 2>/dev/null)
      echo \"\\\${P:-0} \\\${T:-0} \\\${F:-0} \\\${B:-0}\" >> /tmp/gpu_sample.txt
      sleep 3
    done' >/dev/null 2>&1 & echo \$!"
}
sampler_stop() {
  local pid="$1"
  [ -n "$pid" ] && ssh -o BatchMode=yes $H "kill $pid 2>/dev/null; sleep 1; kill -9 $pid 2>/dev/null; true"
}
sampler_report() {
  ssh -o BatchMode=yes $H 'awk "{p+=\$1;n++; if(\$1>pm)pm=\$1; if(\$2>tm)tm=\$2; if(\$3>fm)fm=\$3; if(\$4>bm)bm=\$4}
    END{ if(n>0) printf \"    Load: %d samples | watts mean %d / peak %d | max %d C | max %d rpm | max %d%% busy\n\",
         n, p/n/1000000, pm/1000000, tm/1000, fm, bm }" /tmp/gpu_sample.txt'
}

measure() {
  local name="$1"; shift
  say "--- $name ---"
  echo "### $name" >> "$RES"
  local spid; spid=$(sampler_start)
  ssh -o BatchMode=yes $H "$BENCH -m '$MODEL' -ngl 99 -p 2048 -n 3000 -r 3 -fa 1 $*" \
    2>&1 | tee -a "$LOG" | grep -E -e "^\|" >> "$RES"
  sampler_stop "$spid"
  sampler_report | tee -a "$LOG" >> "$RES"
  echo >> "$RES"
}

# NOTE the separator: -ts 3/1 is a 3:1 split. `-ts 3,1` is silently parsed as TWO
# SEPARATE RUNS, each on a single card. That mistake invalidated a whole evening.
measure "A  XTX alone"        -sm none   -mg 0
measure "B  layer split 3/1"  -sm layer  -ts 3/1
measure "D  tensor split 3/1" -sm tensor -ts 3/1

say "=== done ==="
cat "$RES" | tee -a "$LOG"

#!/bin/bash
# ROCm vs Vulkan on an RX 7900 XTX -- same setup, only the backend differs.
#
# WHY
# The card runs everything through Vulkan and reaches 670 of 960 GB/s of datasheet
# bandwidth, i.e. 70 %. Whether ROCm gets closer had never been measured. This is
# not an edge case like multi-GPU -- it affects every model, every day.
#
# ONE DIFFERENCE IS KNOWN AND IS NOT A CONFOUNDER: under ROCm the card reports wave
# size 32, under Vulkan 64. RDNA3 supports both; which is better is decided by the
# individual kernel. That is part of what is being compared -- the two backends are
# genuinely not built the same way.
#
# The HIP build lives in its OWN PREFIX (/opt/llama-cpp-rocm). The production
# install stays untouched: the running service and every prior measurement stay
# valid, and the rollback is `rm -rf` on the prefix.
#
# Both backends are measured in THIS run, not compared against a number from last
# night -- otherwise day-to-day variation is an uncontrolled variable.
set -uo pipefail

# ---- configure for your host -------------------------------------------------
VULKAN=/opt/llama-cpp/bin/llama-bench
ROCM=/opt/llama-cpp-rocm/bin/llama-bench
MODEL=/opt/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
H=root@gpu-host
CARD=card1
OUTDIR=./results
# ------------------------------------------------------------------------------

LOG=$OUTDIR/rocm_vs_vulkan.log
RES=$OUTDIR/rocm_vs_vulkan.txt
mkdir -p "$OUTDIR"

say() { echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$LOG"; }

say "=== ROCm vs Vulkan ==="

measure() {
  local name="$1" bin="$2"; shift 2
  # LD_LIBRARY_PATH ONLY for the HIP build. On the first attempt it was set for
  # both invocations, so the Vulkan binary picked up ggml from the ROCm prefix --
  # BOTH lines reported "ROCm" as their backend and the comparison was worthless.
  # It was also visible in the spread: +-6.53 instead of +-0.12 on generation.
  # A sudden change in variance is a defect signal.
  local env=""
  case "$bin" in
    *llama-cpp-rocm*) env="LD_LIBRARY_PATH=/opt/llama-cpp-rocm/lib:/opt/rocm/lib" ;;
  esac
  say "--- $name ---"
  echo "### $name" >> "$RES"
  local spid
  spid=$(ssh -o BatchMode=yes $H "rm -f /tmp/gpu_sample.txt; nohup sh -c 'while :; do
      P=\$(cat /sys/class/drm/$CARD/device/hwmon/hwmon*/power1_average 2>/dev/null | head -1)
      T=\$(cat /sys/class/drm/$CARD/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
      F=\$(cat /sys/class/drm/$CARD/device/hwmon/hwmon*/fan1_input 2>/dev/null | head -1)
      echo \"\\\${P:-0} \\\${T:-0} \\\${F:-0}\" >> /tmp/gpu_sample.txt; sleep 3
    done' >/dev/null 2>&1 & echo \$!")
  ssh -o BatchMode=yes $H "$env $bin \
    -m '$MODEL' -ngl 99 -p 2048 -n 3000 -r 3 -fa 1 $*" \
    2>&1 | tee -a "$LOG" | grep -E -e "^\|.*(tg3000|pp2048)" >> "$RES"
  [ -n "$spid" ] && ssh -o BatchMode=yes $H "kill $spid 2>/dev/null; sleep 1; kill -9 $spid 2>/dev/null; true"
  ssh -o BatchMode=yes $H 'awk "{p+=\$1;n++; if(\$1>pm)pm=\$1; if(\$2>tm)tm=\$2; if(\$3>fm)fm=\$3}
    END{ if(n>0) printf \"    Load: %d samples | watts mean %d / peak %d | max %d C | max %d rpm\n\",
    n, p/n/1000000, pm/1000000, tm/1000, fm }" /tmp/gpu_sample.txt' | tee -a "$LOG" >> "$RES"
  echo >> "$RES"
}

# ALWAYS read the backend column of the output. That is what caught the
# LD_LIBRARY_PATH contamination described above.
measure "V  Vulkan (reference)" "$VULKAN" -sm none -mg 0
measure "R  ROCm/HIP"           "$ROCM"   -sm none -mg 0

say "=== done ==="
cat "$RES" | tee -a "$LOG"

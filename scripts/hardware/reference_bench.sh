#!/bin/bash
# Portable reference point -- the one measurement here meant to be comparable with
# other people's hardware.
#
# WHY IT LOOKS LIKE THIS
# The first attempt was unclean in three ways, and each one is now guarded against:
#   1. Only ONE model of the upstream set was run. Now all three that fit in 24 GB.
#   2. The power sampler started with the benchmark and collected 13 points -- its
#      mean was mostly idle and worthless. Now it runs with a lead-in, across the
#      whole run, and idle is reported separately from load.
#   3. No protection. An on-demand model supervisor shares this card; that nothing
#      collided was only established afterwards, from the service log. Now the run
#      refuses to start unless the card is provably ours.
#
# FLAGS: DO NOT "IMPROVE" THEM
# -n 128 -p 512,4096 -pg 4096,128 -ngl 99 come from upstream. The entire point is that
# they match somebody else's numbers.
#
# -r 20 instead of upstream's -r 2 is the one deliberate change, and it is safe: it
# does not alter WHAT is measured, only how many repetitions the mean is taken over.
# It exists because a wall-socket meter polls every few seconds and an -r 2 run lasts
# 11-35 s -- far too short to measure. At -r 20 the same test yields both a tighter
# throughput figure and a usable power trace.
set -uo pipefail

# ---- configure for your host -------------------------------------------------
BENCH=/opt/llama-cpp/bin/llama-bench
H=root@gpu-host
CARD=card1
OUTDIR=./results
SAMPLER=/root/sampler.sh        # see the heredoc below; must exist ON the GPU host
MODELS=(
  "llama-3.2-3b|/opt/models/llama-3.2-3b/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
  "deepseek-r1-14b|/opt/models/deepseek-r1-14b/DeepSeek-R1-Distill-Qwen-14B-Q4_K_M.gguf"
  "gpt-oss-20b|/opt/models/gpt-oss-20b/gpt-oss-20b-MXFP4.gguf"
)
# ------------------------------------------------------------------------------

LOG=$OUTDIR/reference_bench.log
RES=$OUTDIR/reference_bench.txt
mkdir -p "$OUTDIR"
say() { echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$LOG"; }

say "=== reference benchmark ==="

# GUARD 1 -- no on-demand supervisor may be able to load a model mid-run.
if [ "$(ssh -o BatchMode=yes $H 'systemctl is-active llm-runtime 2>/dev/null')" = "active" ]; then
  say "ABORT: the model supervisor is running. Stop it, or run under its lease API."
  exit 1
fi
# GUARD 2 -- and the card is actually empty right now.
USED=$(ssh -o BatchMode=yes $H "awk '{printf \"%d\", \$1/1048576}' /sys/class/drm/$CARD/device/mem_info_vram_used")
[ "${USED:-9999}" -gt 500 ] && { say "ABORT: ${USED} MiB VRAM in use"; exit 1; }
# GUARD 3 -- no downloads. Concurrent disk I/O evicts mmap'd pages and distorts loads.
ssh -o BatchMode=yes $H 'pgrep -x curl >/dev/null' && { say "ABORT: a download is running"; exit 1; }
say "card free (${USED} MiB), supervisor stopped"

# Record the stack. A throughput number without it is not reproducible.
{
  echo "### environment"
  ssh -o BatchMode=yes $H 'echo "  os:     $(. /etc/os-release; echo "$PRETTY_NAME")"
    echo "  kernel: $(uname -r)"
    echo "  mesa:   $(pacman -Q mesa 2>/dev/null | cut -d" " -f2)"
    echo "  llama:  $(cat /opt/llama-cpp/.built-version 2>/dev/null || echo unknown)"'
  echo
} | tee -a "$LOG" >> "$RES"

# The sampler lives as a FILE on the GPU host, not as an inline ssh one-liner.
# In the one-liner version the hwmon glob never expanded through three levels of
# quoting and all 86 samples of the first attempt read 0 W.
#
#   cat > /root/sampler.sh <<'EOF'
#   #!/bin/bash
#   K=/sys/class/drm/card1/device
#   HW=$(echo $K/hwmon/hwmon*/ | cut -d' ' -f1)
#   : > /tmp/ref_sample.txt
#   while :; do
#     echo "$(date +%s) $(cat $HW/power1_average) $(cat $HW/temp1_input) \
#            $(cat $HW/fan1_input) $(cat $K/gpu_busy_percent)" >> /tmp/ref_sample.txt
#     sleep 2
#   done
#   EOF
say "starting sampler (30 s lead-in so idle is on record)"
SPID=$(ssh -o BatchMode=yes $H "nohup $SAMPLER >/dev/null 2>&1 & echo \$!")
sleep 30

for entry in "${MODELS[@]}"; do
  name="${entry%%|*}"; path="${entry##*|}"
  if ! ssh -o BatchMode=yes $H "[ -s '$path' ]"; then
    say "SKIPPED: $name -- file missing or empty"
    echo "### $name -- NOT MEASURED (file missing)" >> "$RES"; echo >> "$RES"
    continue
  fi
  say "--- $name ---"
  # Timestamps: they are what lets an external power log be matched to a model
  # afterwards. Without them a socket trace is one undifferentiated curve.
  echo "### $name  (start $(date +%s))" >> "$RES"
  ssh -o BatchMode=yes $H "$BENCH -m '$path' -n 128 -p 512,4096 -pg 4096,128 -ngl 99 -r 20" \
    2>&1 | tee -a "$LOG" | grep -E -e "^\|" >> "$RES"
  echo "  (end $(date +%s))" >> "$RES"; echo >> "$RES"
  sleep 20   # cool-down, and a visible gap in the power trace as a separator
done

[ -n "$SPID" ] && ssh -o BatchMode=yes $H "kill $SPID 2>/dev/null; sleep 1; kill -9 $SPID 2>/dev/null; true"

# Idle reported separately from load. Below 60 W is idle -- this card draws 7-22 W
# unloaded and never under 100 W loaded. Mixing them is what made the first attempt's
# average meaningless.
ssh -o BatchMode=yes $H 'awk "
  \$2/1000000 < 60 { il+=\$2; iln++; next }
  { p+=\$2; n++; if(\$2>pm)pm=\$2; if(\$3>tm)tm=\$3 }
  END{
    if(iln>0) printf \"    idle: %d samples | %d W mean\n\", iln, il/iln/1000000
    if(n>0)   printf \"    load: %d samples | %d W mean / %d W peak | max %d C\n\", n, p/n/1000000, pm/1000000, tm/1000
  }" /tmp/ref_sample.txt' | tee -a "$LOG" >> "$RES"

cat >> "$RES" <<'NOTE'
    NOTE: card sensor. On this AMD card it reads far below the wall socket -- a
          quarter low under generation load, more than half low under prefill.
          Log a socket meter in parallel and match it by the timestamps above.
NOTE

say "=== done ==="
cat "$RES" | tee -a "$LOG"

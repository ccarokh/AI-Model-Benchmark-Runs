#!/bin/bash
# Sweep across split ratios -- separates "fixed overhead" from "slow second card".
#
# THE OPEN QUESTION
# Layer split costs 38 % of the generation rate (38.67 -> 24.10 t/s), tensor split
# costs more. What has been ruled out: PCIe, at 2.5 % utilization (measured with
# nvidia-smi dmon), and doubling the second card's link from x4 to x8 changed
# nothing. What is also established is THAT there is waiting -- the fast card draws
# 120 W in the split instead of 262 at a nominal 100 % utilization.
#
# What is NOT established is WHY. Two candidates:
#   (a) a fixed per-token overhead from synchronizing at the handover
#   (b) the second card is simply slow and holds things up
#
# This sweep separates them. The second card's share is driven from "nothing" to
# "half":
#   * If the rate stays bad even at 15/1, where the slow card carries a sixteenth
#     -> (a), it is the mechanism
#   * If the rate falls proportionally with its share
#     -> (b)
#
# What this sweep does NOT answer: whether mismatched architectures (wave 64 vs 32,
# KHR_coopmat vs NV_coopmat2) play a role. That needs two identical cards. Until
# those exist it stays a guess and is not written down as a result.
#
# -n 1000 instead of 3000: with seven configurations it would otherwise run over an
# hour. 50 to 100 s per configuration is enough to get the card out of idle -- the
# sustained-load comparison from the same evening showed configuration A differing
# by 0.03 % between 3 s and 4.5 min of measurement.
set -uo pipefail

# ---- configure for your host -------------------------------------------------
BENCH=/opt/llama-cpp/bin/llama-bench
MODEL=/opt/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
H=root@gpu-host
LINK_MBS=7880          # theoretical link bandwidth in MB/s, for the % column
OUTDIR=./results
# ------------------------------------------------------------------------------

LOG=$OUTDIR/multigpu_ratios.log
RES=$OUTDIR/multigpu_ratios.txt
mkdir -p "$OUTDIR"

say() { echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$LOG"; }

# Wait for a previously started run to finish. Fixed PID, never a pattern:
# `pgrep -f multigpu` would match this script's own invocation.
PREDECESSOR_PID=${PREDECESSOR_PID:-0}
if [ "$PREDECESSOR_PID" -gt 1 ] && kill -0 "$PREDECESSOR_PID" 2>/dev/null; then
  say "previous run still active (PID $PREDECESSOR_PID) -- waiting"
  while kill -0 "$PREDECESSOR_PID" 2>/dev/null; do sleep 30; done
  sleep 30
fi

say "=== split-ratio sweep ==="

# Record PCIe throughput per configuration. The AMD side offers no counter
# (pcie_bw is absent), but with two cards the traffic is mirrored: what the NVIDIA
# card receives, the AMD card sent.
measure() {
  local name="$1"; shift
  say "--- $name ---"
  echo "### $name" >> "$RES"
  local dpid
  dpid=$(ssh -o BatchMode=yes $H 'rm -f /tmp/pcie.txt; nohup nvidia-smi dmon -s t -d 1 >/tmp/pcie.txt 2>&1 & echo $!')
  ssh -o BatchMode=yes $H "$BENCH -m '$MODEL' -ngl 99 -p 2048 -n 1000 -r 2 -fa 1 $*" \
    2>&1 | tee -a "$LOG" | grep -E -e "^\|.*(tg1000|pp2048)" >> "$RES"
  [ -n "$dpid" ] && ssh -o BatchMode=yes $H "kill $dpid 2>/dev/null; sleep 1; kill -9 $dpid 2>/dev/null; true"
  ssh -o BatchMode=yes $H "awk '/^ *[0-9]/ {rx+=\$2; tx+=\$3; n++} END{ if(n>0) printf \"    PCIe: RX %d MB/s | TX %d MB/s | combined %.1f %% of $LINK_MBS\n\", rx/n, tx/n, 100*(rx/n+tx/n)/$LINK_MBS }' /tmp/pcie.txt" | tee -a "$LOG" >> "$RES"
  echo >> "$RES"
}

# Tensor mode: the slow card's share drops from half to nothing.
measure "T 1/1   -- slow card carries half"      -sm tensor -ts 1/1
measure "T 7/1   -- slow card carries 1/8"       -sm tensor -ts 7/1
measure "T 15/1  -- slow card carries 1/16"      -sm tensor -ts 15/1
measure "T 1/0   -- slow card carries nothing"   -sm tensor -ts 1/0

# Layer mode for comparison, same ratios.
measure "L 1/1   -- slow card carries half"      -sm layer  -ts 1/1
measure "L 15/1  -- slow card carries 1/16"      -sm layer  -ts 15/1
measure "L 1/0   -- slow card carries nothing"   -sm layer  -ts 1/0

say "=== done ==="
cat "$RES" | tee -a "$LOG"

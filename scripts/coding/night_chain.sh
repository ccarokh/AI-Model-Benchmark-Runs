#!/bin/bash
# Unattended benchmark chain -- widening the sample across more repositories.
#
# STATE BEFORE THIS RUN (repomap mode, 29 instances from pylint and pytest):
#   Qwen3.6-27B      11/29 = 37.9 %   (5 empty patches)
#   ornith-35b        9/29 = 31.0 %   (14)
#   qwen3.6-35b-a3b   8/29 = 27.6 %   (11)
#   qwen3-coder       2/29 =  6.9 %   (15)
#
# In oracle mode all four sit between 7 and 9 of 19 -- the entire difference is in
# FINDING THE RIGHT FILE, not in writing the patch.
#
# THE PROBLEM: 29 instances from two repositories. The gap between 11 and 2 is
# unambiguous; the one between 11, 9 and 8 is not -- three instances can be chance.
# That is not enough to decide a production slot.
#
# THIS CHAIN adds three more repositories and measures the two extremes there: the
# leader and the coder model as a reference. If the gap holds on unfamiliar
# material, the decision is sound; if it collapses, it was an artifact of the first
# two repositories.
#
# ORDER: small repositories first. For every new repository the evaluation harness
# has to build Docker images first, and how long that takes is unknown. If the
# smallest one fails, ten minutes are lost rather than two hours -- and a setup
# error becomes visible early.
#
# DISK SPACE is the risk factor: each repository brings its own images. The chain
# checks before every step and aborts rather than filling the disk.
set -uo pipefail

# ---- configure ---------------------------------------------------------------
LOG=./night_chain.log
RUNNER=./swebench_run.sh
M27=/opt/models/qwen3.6-27b/Qwen3.6-27B-Q4_K_M.gguf
CODER=/opt/models/qwen3-coder-30b-a3b/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
DEADLINE_HOUR="12:00"    # nothing new starts after this
MIN_FREE_GB=8
# ------------------------------------------------------------------------------

say() { echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$LOG"; }

DEADLINE=$(date -d "today $DEADLINE_HOUR" +%s)
[ "$DEADLINE" -lt "$(date +%s)" ] && DEADLINE=$(date -d "tomorrow $DEADLINE_HOUR" +%s)

# A step never aborts the chain on failure -- one broken repository should not cost
# the remaining hours of GPU time. It returns 0 and the chain moves on.
step() {
  local name="$1" minutes="$2"; shift 2
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    say "DEADLINE: $name not started"; return 0
  fi
  local free; free=$(df --output=avail -BG . | tail -1 | tr -dc '0-9')
  if [ "${free:-0}" -lt "$MIN_FREE_GB" ]; then
    say "ABORT: only ${free} GB left -- $name not started"; return 1
  fi
  say "--- $name (~${minutes} min, ${free} GB free) ---"
  local t0 rc; t0=$(date +%s)
  "$@" >> "$LOG" 2>&1
  rc=$?
  say "$name done (rc=$rc) -- $(( ($(date +%s) - t0) / 60 )) min"
  return 0
}

say "=== night chain: widening the sample ==="

# psf/requests -- the smallest repository in SWE-bench Verified, about a dozen
# instances. Doubles as the probe for whether an unfamiliar repository runs at all.
step "1/6 requests, Qwen3.6-27B"  60 "$RUNNER" psf/requests qwen3.6-27b "$M27" repomap q8_0
step "2/6 requests, qwen3-coder"  40 "$RUNNER" psf/requests qwen3-coder-30b-a3b "$CODER" repomap q8_0

step "3/6 astropy, Qwen3.6-27B"   60 "$RUNNER" astropy/astropy qwen3.6-27b "$M27" repomap q8_0
step "4/6 astropy, qwen3-coder"   40 "$RUNNER" astropy/astropy qwen3-coder-30b-a3b "$CODER" repomap q8_0

# xarray is the largest of the three -- therefore last.
step "5/6 xarray, Qwen3.6-27B"   120 "$RUNNER" pydata/xarray qwen3.6-27b "$M27" repomap q8_0
step "6/6 xarray, qwen3-coder"    70 "$RUNNER" pydata/xarray qwen3-coder-30b-a3b "$CODER" repomap q8_0

say "=== chain complete ==="

#!/bin/bash
# SWE-bench: agent run + evaluation in one pass.
#
# SEQUENCE:
#   1. acquire the GPU (do not kill anything, do not wait blindly)
#   2. start the model server on the card
#   3. let the agent produce a patch per instance
#   4. release the card -- the agent part is done
#   5. evaluate with the official harness (no GPU needed any more)
#
# The card is therefore occupied only for steps 2-3. Step 5 runs afterwards so a
# live service does not lose it for longer than necessary.
#
# Usage:  swebench_run.sh <repo> <model-slug> <gguf-path> [oracle|repomap] [f16|q8_0]
set -uo pipefail

# ---- configure for your host -------------------------------------------------
H=root@gpu-host
GPU_IP=10.0.0.2          # address the agent container reaches the model server on
W=/root/swebench         # working directory on this machine
PORT=8181
CARD=card1
VRAM_TOTAL_MIB=24560
# ------------------------------------------------------------------------------

REPO="${1:-pylint-dev/pylint}"
SLUG="${2:-qwen3-coder-30b-a3b}"

# Repository short name goes into EVERY output name. WITHOUT IT RUNS OVERWRITE EACH
# OTHER: one night the pytest run completely replaced the pylint report for the same
# model in the same mode (both were called "qwen3-coder-30b-a3b_oracle") and the
# pylint result was lost.
REPO_SHORT=$(echo "$REPO" | tr "/" "-")

GGUF="${3:-/opt/models/qwen3-coder-30b-a3b/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf}"
MODE="${4:-oracle}"

# KV CACHE TYPE. f16 is the setup the first models were measured in; the existing
# comparisons run on it.
# q8_0 becomes necessary as soon as the weights leave no room for the cache: at
# ctx 65536 the f16 cache occupies roughly 3.8 GB (measured on the 27B: 16 GB of
# weights, 19837 MiB total). For 20 GB models that would be ~23.5 to ~24.6 GB of
# 24.56 GB -- the second one overflows for certain. q8_0 halves the cache.
#
# The type goes into ALL output names. Without that, a q8_0 run would overwrite the
# f16 reference for the same model -- the same mistake as the repo name above.
CACHE="${5:-f16}"
CACHE_ARG=""
NAME_SUFFIX=""
if [ "$CACHE" != "f16" ]; then
  CACHE_ARG="--cache-type-k $CACHE --cache-type-v $CACHE"
  NAME_SUFFIX="_$CACHE"
fi
ID="${REPO_SHORT}_${SLUG}_${MODE}${NAME_SUFFIX}"

# If you share the GPU with a production service, put your lease helper here.
# source /path/to/gpu_lease.sh

say() { echo "[$(date '+%H:%M:%S')] $*"; }

say "building instance list ($REPO)"
docker run --rm -v $W:/w -w /w swebench-harness:local \
  python prepare.py "$REPO" gold 2>&1 | grep -E "instances from" || exit 1

say "starting model server"
# --parallel 1, NOT 2: the slot size is ctx-size DIVIDED BY parallel.
# With 32768/2 the agent got 16384 tokens and the first pilot run failed on 8 of 10
# instances at exactly that boundary:
#   "request (19485 tokens) exceeds the available context size (16384)"
# The agent is sequential anyway, a second slot buys nothing.
# --jinja: the coder model needs its chat template for tool calls.
# One server log PER RUN, not a shared one -- otherwise the token rate of an
# individual run cannot be reconstructed afterwards.
start_server "-m '$GGUF' --host 0.0.0.0 --port $PORT --device Vulkan0 \
  --ctx-size 65536 --batch-size 512 --ubatch-size 512 -ngl 99 --parallel 1 $CACHE_ARG --jinja" \
  "/tmp/srv_swebench_${ID}.log" || exit 1

for i in $(seq 1 60); do
  ssh -o BatchMode=yes $H "curl -s -o /dev/null -w '%{http_code}' --max-time 6 http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q 200 && break
  sleep 5
done
say "server ready"

# VRAM CHECK -- the expensive lesson.
# A model once ran with a KV cache that no longer fit in VRAM: the cache moved to
# host RAM, generation dropped from 44 to 10 t/s, and the run would have taken 17.7
# hours instead of 1. Nobody noticed, because from the outside a slow run looks
# exactly like a large model.
# This check costs one second and catches precisely that.
VRAM_MIB=$(ssh -o BatchMode=yes $H "awk '{printf \"%d\", \$1/1048576}' /sys/class/drm/$CARD/device/mem_info_vram_used" 2>/dev/null)
say "VRAM in use: ${VRAM_MIB} MiB of $VRAM_TOTAL_MIB (KV cache $CACHE)"
if [ "${VRAM_MIB:-0}" -gt 23500 ]; then
  say "WARNING: over 23500 MiB in use -- the KV cache may be spilling to host RAM."
  say "         Check the token rate in the server log:"
  say "         below ~20 t/s with normal prefill => overflow, discard the run."
fi

say "agent run ($MODE)"
ORACLE=""; [ "$MODE" = "oracle" ] && ORACLE="--oracle"
docker run --rm \
  --cpus=4 --memory=12g --add-host=host.docker.internal:host-gateway \
  -v $W:/w -w /w aider-benchmark:fix \
  python3 /w/swebench_agent.py --repo "$REPO" $ORACLE \
    --api-base "http://$GPU_IP:$PORT/v1" \
    --output "predictions_${ID}.jsonl" 2>&1 | tee "$W/agent_${ID}.log"

say "releasing the card -- the rest does not need it"
stop_server

say "evaluation"
docker run --rm -v $W:/w -w /w -v /var/run/docker.sock:/var/run/docker.sock \
  swebench-harness:local python -m swebench.harness.run_evaluation \
  --dataset_name princeton-nlp/SWE-bench_Verified \
  --predictions_path "predictions_${ID}.jsonl" \
  --max_workers 3 --run_id "${ID}" --cache_level env --timeout 900 \
  2>&1 | tail -5

say "done"

#!/bin/bash
# One model through the archive test on the measuring host: a fresh llama-server for
# the model and one for bge-m3 (retrieval and the agent's search tool), the chosen
# paths one after the other, both servers stopped by PID at the end.
#
# Usage: lauf.sh <model-dir-name> <label> "<paths>" <on|off> [only-ids]
#   e.g. lauf.sh gemma-4-e4b gemma-4-e4b "retrieval context agent" off
# Env: BUILD (default /opt/llama-cpp), EXTRA (extra server args, e.g. -ncmoe 28),
#      CTX (default 65536 -- the whole archive is ~41k tokens), K (retrieval depth, default 8)
set -u
M=/opt/llm-infra/models; E=$(cd "$(dirname "$0")" && pwd); A=${ARCHIVE:-$E/archive}
BUILD=${BUILD:-/opt/llama-cpp}; OUT=${OUT:-/root/eval/docarchive_antworten.jsonl}
name=$1; label=$2; paths=$3; think=$4; only=${5:-}
g=$(ls $M/$name/*.gguf | grep -v -e mmproj -e "mtp-" | head -1)
[ -f "$g" ] || { echo "$name: keine Datei"; exit 1; }
export LD_LIBRARY_PATH=$BUILD/lib
$BUILD/bin/llama-server -m "$g" --host 127.0.0.1 --port 18300 --device Vulkan0 -ngl 99 -c ${CTX:-65536} -np 1 \
  --jinja ${EXTRA:-} > /root/eval/docarchive_server.log 2>&1 & S=$!
$BUILD/bin/llama-server -m $M/bge-m3/bge-m3-Q8_0.gguf --host 127.0.0.1 --port 18301 --device Vulkan0 --embedding \
  -c 8192 -b 8192 -ub 8192 > /root/eval/docarchive_embed.log 2>&1 & EM=$!
trap 'kill $S $EM 2>/dev/null; sleep 5; kill -9 $S $EM 2>/dev/null' EXIT
for i in $(seq 1 300); do
  curl -sf -m 3 http://127.0.0.1:18300/health >/dev/null && curl -sf -m 3 http://127.0.0.1:18301/health >/dev/null && break
  kill -0 $S 2>/dev/null && kill -0 $EM 2>/dev/null || { echo "Server beendet -- siehe docarchive_server.log / docarchive_embed.log"; exit 1; }
  sleep 2
done
for p in $paths; do
  python3 $E/run.py --archive $A --url http://127.0.0.1:18300 --embed-url http://127.0.0.1:18301 --model "$label" \
    --path $p --thinking $think --k ${K:-8} --out $OUT ${only:+--only $only}
done

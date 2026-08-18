#!/bin/bash
# Wie run-bench.sh, aber SETZT FORT statt neu anzufangen.
#
# Der Unterschied ist genau zwei Dinge:
#   1. der DIRNAME ist das bestehende, datierte Verzeichnis
#   2. --new wird WEGGELASSEN
# aiders benchmark.py ueberspringt dann alle Aufgaben, die schon eine
# .aider.results.json haben. Mit --new wuerde jedes Fenster von vorn beginnen.
#
# Aufruf: run-bench-resume.sh <datiertes-verzeichnis> <port> <edit-format> <tries> <threads> <num-tests|all>
set -e
cd /root/coding-eval/aider
DIR="$1"; PORT="$2"; EF="${3:-diff}"; TRIES="${4:-2}"; THREADS="${5:-4}"; NT="${6:-all}"
[ -d "tmp.benchmarks/$DIR" ] || { echo "Verzeichnis tmp.benchmarks/$DIR fehlt"; exit 1; }
NTARG=""; [ "$NT" != "all" ] && NTARG="--num-tests $NT"
docker run --rm \
  --cpus=3 --memory=12g --memory-swap=12g --pids-limit=1024 \
  --add-host=host.docker.internal:host-gateway \
  -v "$PWD":/aider -v "$PWD/tmp.benchmarks/.":/benchmarks \
  -e OPENAI_API_BASE="http://192.168.40.192:${PORT}/v1" \
  -e OPENAI_API_KEY=dummy -e AIDER_DOCKER=1 -e AIDER_BENCHMARK_DIR=/benchmarks \
  -e AIDER_MAX_REFLECTIONS=3 \
  aider-benchmark \
  bash -c "pip install -e . >/tmp/pip.log 2>&1 && \
    ./benchmark/benchmark.py '$DIR' --model openai/coder \
      --edit-format '$EF' --tries $TRIES --threads $THREADS \
      --exercises-dir polyglot-benchmark $NTARG"

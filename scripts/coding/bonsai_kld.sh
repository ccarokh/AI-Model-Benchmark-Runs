#!/bin/bash
# Entry test for Bonsai 2 27B (PrismML's ternary compression of Qwen3.8-27B,
# 1.72 bit/weight, 5.95 GB against our 16 GB Q4_K_M, Apache 2.0).
#
# THE CLAIM: 98.2 % of FP16 on their 14-benchmark average, against 98.7 % for
# UD-Q4_K_XL at three times the size. If that holds, a 27B fits on the second
# card. THE TEST: the same KL divergence we already ran for the Q-series on
# 45 000 tokens of private, never-published code (stage 0, 20.09.) --
# Q8_0 0.0013, UD-Q6_K 0.0022, Q4_K_M 0.0092 mean KLD. Land near Q4 and the
# claim is real; land at 0.03 and it is marketing, for 6 GB and one evening.
#
# WHY A FORK: the two tensor types (PQ2_0 id 142, PTQ1_0 id 143) are not in
# mainline -- PR #29077 is open with a CPU reference kernel at 0.4 t/s, too slow
# to measure with. The fork has CUDA/Metal/HIP/CPU, no Vulkan, so on this host
# it is HIP on the 7900 XTX (gfx1100), like scripts/hardware/hip_tiefe.sh.
#
# Phases: laden (daytime, ~7 GB) | bauen (CPU) | messen (night queue, leased).
set -uo pipefail
D=/opt/llm-infra/models/bonsai-2-27b-eval
SRC=/opt/src/bonsai-llama.cpp
B=/opt/llama-cpp-bonsai
TXT=${TXT:-/root/eval/kld_code_privat.txt}
BASE=${BASE:-/root/eval/kld_bf16_privat.base}
OUT=${OUT:-/root/eval/kld_qwen38.tsv}
HF=https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/resolve/main
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*"; }

case "${1:-}" in
laden)
  mkdir -p $D
  for f in Ternary-Bonsai-2-27B-PTQ1_0.gguf Ternary-Bonsai-2-27B-PQ2_0.gguf; do
    sag "lade $f"
    curl -sSL -C - --retry 5 -o "$D/$f" "$HF/$f?download=true" || { sag "  FEHLER bei $f"; exit 1; }
  done
  ls -la $D; sag "geladen"
  ;;
bauen)
  [ -d $SRC ] || git clone --depth 1 https://github.com/PrismML-Eng/llama.cpp $SRC || { sag "clone fehlgeschlagen"; exit 1; }
  cd $SRC && git fetch --depth 1 origin && git reset --hard origin/HEAD
  v=$(git rev-parse --short HEAD)
  sag "=== HIP-Bau des PrismML-Forks auf $v ==="
  export ROCM_PATH=/opt/rocm HIP_PATH=/opt/rocm HIPCXX=/opt/rocm/lib/llvm/bin/clang++
  bauen(){
    cmake -B build-rocm -DGGML_HIP=ON -DAMDGPU_TARGETS=gfx1100 -DGPU_TARGETS=gfx1100 \
          -DCMAKE_C_COMPILER=/opt/rocm/lib/llvm/bin/clang -DCMAKE_CXX_COMPILER=/opt/rocm/lib/llvm/bin/clang++ \
          -DCMAKE_HIP_COMPILER=/opt/rocm/lib/llvm/bin/clang++ -DCMAKE_HIP_COMPILER_ROCM_ROOT=/opt/rocm \
          -DCMAKE_HIP_PLATFORM=amd -DCMAKE_PREFIX_PATH=/opt/rocm -DCMAKE_INSTALL_PREFIX=$B \
          -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
          -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_SERVER=ON -DCMAKE_BUILD_TYPE=Release > /root/eval/bonsai_bau.log 2>&1 \
    && cmake --build build-rocm -j"${JOBS:-12}" >> /root/eval/bonsai_bau.log 2>&1
  }
  if ! bauen; then
    sag "  Bau fehlgeschlagen -- zweiter Versuch aus sauberem Bauverzeichnis"
    rm -rf build-rocm; bauen || { sag "  Bau fehlgeschlagen (Log /root/eval/bonsai_bau.log)"; exit 1; }
  fi
  rm -rf $B && cmake --install build-rocm >> /root/eval/bonsai_bau.log 2>&1 || { sag "  Installation fehlgeschlagen"; exit 1; }
  echo "prismml-$v" > $B/.built-version
  sag "  gebaut: $(cat $B/.built-version)"
  ;;
messen)
  [ -x $B/bin/llama-perplexity ] || { sag "kein Fork-Build -- Phase bauen zuerst"; exit 1; }
  [ -s "$BASE" ] || { sag "keine BF16-Referenz $BASE -- Stufe 0 zuerst"; exit 1; }
  export LD_LIBRARY_PATH=$B/lib
  v=$(cat $B/.built-version)
  $B/bin/llama-bench --list-devices 2>&1 | grep -iE "ROCm|HIP" | head -2 | sed 's/^/  /'
  for q in PTQ1_0 PQ2_0; do
    g=$D/Ternary-Bonsai-2-27B-$q.gguf
    [ -s "$g" ] || { sag "$q fehlt"; continue; }
    sag "=== Bonsai $q ==="
    t0=$(date +%s)
    timeout -k 30 7200 $B/bin/llama-perplexity -m "$g" -f $TXT -c 2048 -b 512 -ngl 99 \
        --kl-divergence-base "$BASE" --kl-divergence > /root/eval/kld_bonsai_$q.log 2>&1
    s=$(( $(date +%s) - t0 ))
    ppl=$(grep -oE "Mean PPL\(Q\) *: *[0-9.]+" /root/eval/kld_bonsai_$q.log | grep -oE "[0-9.]+$" | tail -1)
    kld=$(grep -oE "Mean +KLD: +[0-9.]+" /root/eval/kld_bonsai_$q.log | grep -oE "[0-9.]+$" | tail -1)
    # The reference file holds 22 of 40 chunks (the BF16 pass hit its timeout on
    # 20.09.), so llama-perplexity stops at chunk 22 with "failed reading
    # log-probs" and prints no summary. The running per-chunk line at 22 is the
    # same cumulative number the summary would show -- take it from there.
    if [ -z "$kld" ]; then
      set -- $(grep -aE "^ +22 " /root/eval/kld_bonsai_$q.log | tail -1)
      ppl=${2:-}; kld=${8:-}; top=${14:-}
      [ -n "$kld" ] && sag "  (Zusammenfassung fehlt, Werte aus Chunk 22 -- Referenz deckt nur 22 von 40)"
    fi
    k99=$(grep -oE "99\.0% +KLD: +[0-9.]+" /root/eval/kld_bonsai_$q.log | grep -oE "[0-9.]+$" | tail -1)
    top=$(grep -oE "Same top p: +[0-9.]+" /root/eval/kld_bonsai_$q.log | grep -oE "[0-9.]+$" | tail -1)
    if [ -z "$kld" ]; then
      grund=$(grep -aiE "error|failed|unknown|unsupported" /root/eval/kld_bonsai_$q.log | head -1 | cut -c1-120)
      sag "  KEINE MESSUNG -- ${grund:-ohne Meldung}"
      printf "%s\t%s\t%s\tBonsai-%s\t\t\t\t\t%s\tKEINE_MESSUNG: %s\n" "$(date +%F)" "$v" "$(basename $TXT)" "$q" "$s" "${grund:-ohne Meldung}" >> "$OUT"
      continue
    fi
    printf "%s\t%s\t%s\tBonsai-%s\t%s\t%s\t%s\t%s\t%s\n" "$(date +%F)" "$v" "$(basename $TXT)" "$q" "${ppl:-?}" "$kld" "${k99:-?}" "${top:-?}" "$s" >> "$OUT"
    sag "  $q: ppl=${ppl:-?} kld=$kld p99=${k99:-?} top1=${top:-?} (${s}s)"
    # Speed, for the same reason the version watch measures it: a model nobody
    # can serve is not a candidate, however good its divergence.
    LD_LIBRARY_PATH=$B/lib timeout -k 10 900 $B/bin/llama-bench -m "$g" -p 512 -n 128 -r 2 -ngl 99 2>/dev/null \
      | grep -E "pp512|tg128" | sed 's/^/  /'
  done
  echo FERTIG_BONSAI_KLD
  ;;
*) echo "usage: $0 laden|bauen|messen"; exit 2 ;;
esac

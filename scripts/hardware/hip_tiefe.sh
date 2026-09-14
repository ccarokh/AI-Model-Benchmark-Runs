#!/bin/bash
# HIP against Vulkan at context depth, one model, one session.
#
# WHY: PR #28102 (merged 2026-09-11) tunes flash attention in ggml-cuda for AMD
# WMMA and fixes the head-size-256 kernel selection. Qwen3.8-27B has head_dim
# 256; the author saw prefill at d40000 go from 426 to 639 t/s under ROCm. The
# gate is amd_wmma_available(), which RDNA3 (gfx1100) passes -- so our HIP path
# may have changed, while the Vulkan path is untouched. hardware/backends.md
# ("Vulkan stays") was measured at depth 0, before this. This is the depth
# measurement that finding did not have.
#
# WHAT: build HIP from the same commit the drift check installed as
# /opt/llama-cpp-master (CPU work, own prefix, production untouched), then run
# llama-bench on Qwen3.8-27B at d0 / d8192 / d32768 on three prefixes:
# Vulkan v0.2.0 (production), Vulkan master, HIP master. q8_0 cache, -fa on,
# like the coding slot. Results append to a TSV here, never to /tmp.
#
# LD_LIBRARY_PATH per prefix is the whole point (backends.md: the first run
# measured ROCm twice because the Vulkan binary loaded the ROCm libraries).
set -uo pipefail
M=${M:-/opt/llm-infra/models/qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf}
SRC=/opt/src/llama.cpp
MASTER=/opt/llama-cpp-master
HIP=/opt/llama-cpp-rocm-master
PROD=/opt/llama-cpp
OUT=${OUT:-/root/eval/hip_tiefe.tsv}
HEUTE=$(date +%Y-%m-%d)
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*"; }
[ -s "$OUT" ] || printf "datum\tbackend\tprefix\tversion\ttest\tdepth\tt_s\tsd\n" > "$OUT"

v=$(cat $MASTER/.built-version 2>/dev/null) || { sag "kein Master-Praefix -- Drift-Schritt fehlt"; exit 1; }
# NUR_VULKAN=1: skip the HIP build and the HIP row -- a daytime check of the
# Vulkan side alone (used on 14.09. to test the new Mesa at depth).
if [ "${NUR_VULKAN:-}" = 1 ]; then
  messen_vulkan_nur=1
else
sag "=== HIP-Bau auf $v (CPU) ==="
if [ "$(cat $HIP/.built-version 2>/dev/null)" = "$v" ] && [ -x $HIP/bin/llama-bench ]; then
  sag "  HIP-Praefix steht schon auf $v"
else
  cd $SRC && git checkout --quiet "$v" || { sag "checkout $v fehlgeschlagen"; exit 1; }
  # CMake's HIP language detection wants the ROCm root spelled out; without it
  # the first attempt on 14.09. died in 11 s with "Failed to find HIP root
  # directory" although hipcc and clang were right there.
  export ROCM_PATH=/opt/rocm HIP_PATH=/opt/rocm HIPCXX=/opt/rocm/lib/llvm/bin/clang++
  bauen(){
    cmake -B build-rocm -DGGML_HIP=ON -DAMDGPU_TARGETS=gfx1100 -DGPU_TARGETS=gfx1100 \
          -DCMAKE_C_COMPILER=/opt/rocm/lib/llvm/bin/clang -DCMAKE_CXX_COMPILER=/opt/rocm/lib/llvm/bin/clang++ \
          -DCMAKE_HIP_COMPILER=/opt/rocm/lib/llvm/bin/clang++ -DCMAKE_HIP_COMPILER_ROCM_ROOT=/opt/rocm \
          -DCMAKE_HIP_PLATFORM=amd -DCMAKE_PREFIX_PATH=/opt/rocm \
          -DCMAKE_INSTALL_PREFIX=$HIP -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
          -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_SERVER=ON -DCMAKE_BUILD_TYPE=Release > /root/eval/hip_bau.log 2>&1 \
    && cmake --build build-rocm -j"${JOBS:-12}" >> /root/eval/hip_bau.log 2>&1
  }
  if ! bauen; then
    sag "  Bau fehlgeschlagen -- zweiter Versuch aus sauberem Bauverzeichnis"
    rm -rf build-rocm
    bauen || { sag "  Bau fehlgeschlagen (Log /root/eval/hip_bau.log) -- keine Messung"; exit 1; }
  fi
  rm -rf $HIP && cmake --install build-rocm >> /root/eval/hip_bau.log 2>&1 || { sag "  Installation fehlgeschlagen"; exit 1; }
  echo "$v" > $HIP/.built-version
fi
n=$(LD_LIBRARY_PATH=$HIP/lib ldd $HIP/bin/llama-bench | grep -E "libllama|libggml" | grep -c "$HIP/lib")
sag "  HIP-Bibliotheken aus dem eigenen Praefix: $n"
LD_LIBRARY_PATH=$HIP/lib $HIP/bin/llama-bench --list-devices 2>&1 | grep -iE "ROCm|HIP|Vulkan" | head -3 | sed 's/^/  /'
fi

messen(){  # $1 backend-label $2 prefix $3 version $4.. extra device flags
  local be="$1" pfad="$2" ver="$3"; shift 3
  sag "=== $be $ver ==="
  local j
  j=$(LD_LIBRARY_PATH=$pfad/lib timeout -k 10 2400 $pfad/bin/llama-bench -m "$M" -p 512 -n 128 -d 0,8192,32768 \
        -fa on -ctk q8_0 -ctv q8_0 -r 3 -ngl 99 "$@" -o json 2>/dev/null)
  [ -z "$j" ] && { sag "  KEINE MESSUNG"; printf "%s\t%s\t%s\t%s\t-\t-\t\t\n" "$HEUTE" "$be" "$pfad" "$ver" >> "$OUT"; return 1; }
  printf '%s' "$j" | python3 -c '
import json,sys
d=json.load(sys.stdin); heute,be,pfad,ver,out=sys.argv[1:6]
with open(out,"a") as f:
  for e in d:
    test = "pp%d"%e["n_prompt"] if e["n_prompt"] else "tg%d"%e["n_gen"]
    f.write("%s\t%s\t%s\t%s\t%s\t%d\t%.2f\t%.2f\n"%(heute,be,pfad,ver,test,e.get("n_depth",0),e["avg_ts"],e["stddev_ts"]))
    print("  %-6s @ d%-6d %8.2f +- %.2f  [%s]"%(test,e.get("n_depth",0),e["avg_ts"],e["stddev_ts"],e.get("backends","?")))
' "$HEUTE" "$be" "$pfad" "$ver" "$OUT"
}
messen vulkan $PROD   "$(cat $PROD/.built-version)" -sm none -mg 0
messen vulkan $MASTER "$v" -sm none -mg 0
[ "${NUR_VULKAN:-}" = 1 ] || messen hip    $HIP    "$v"
echo FERTIG_HIP_TIEFE

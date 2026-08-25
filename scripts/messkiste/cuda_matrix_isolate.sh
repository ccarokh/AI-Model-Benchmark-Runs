#!/bin/bash
# The same question as coopmat2_isolate.sh, asked of the CUDA backend.
#
# The Vulkan run answered it: switching the matrix path off costs 20-25 % of
# prefill and nothing at all of generation. The queued repeat "on the CUDA
# build" was a mistake -- GGML_VK_* means nothing to CUDA, so all three rows
# came out identical and looked like a finding. They were the same measurement
# three times.
#
# CUDA has its own knobs, and they are not the same thing:
#   GGML_CUDA_FORCE_MMQ      quantised matrix kernels instead of cuBLAS
#   GGML_CUDA_FORCE_CUBLAS   always cuBLAS, never the hand-written kernels
#
# That is not "tensor cores off" -- both paths can use them. It separates which
# implementation does the work, which is the question a CUDA build can actually
# answer.
set -uo pipefail
L=${L:-/root/mess/cuda_matrix.log}
. "$(dirname "$0")/gemeinsam.sh"
# NOT ${BAU:-...}: gemeinsam.sh has already set BAU to the Vulkan tree by then,
# so the default never applies and the run silently measures the wrong build.
# That is what happened at 05:41 -- six rows of "CUDA" numbers that were Vulkan
# numbers, identifiable only because they matched the Vulkan run to two decimals.
BAU=/opt/mess/llama.cpp/build-cuda

[ -x "$BAU/bin/llama-bench" ] || { sag "kein CUDA-Bau unter $BAU"; exit 2; }
sag "=== Matrixpfad im CUDA-Bau ==="
for modell in "3b:$M3" "9b:$M9"; do
  name=${modell%%:*}; pfad=${modell#*:}
  [ -r "$pfad" ] || { sag "  $name: Modell fehlt"; continue; }
  for schalter in "vorgabe:" "force-mmq:GGML_CUDA_FORCE_MMQ=1" "force-cublas:GGML_CUDA_FORCE_CUBLAS=1"; do
    marke=${schalter%%:*}; umgebung=${schalter#*:}
    karte_leer || { sag "  Karte nicht leer -- $name/$marke uebersprungen"; continue; }
    r=$(env ${umgebung:+$umgebung} bash -c "$(declare -f bench); L='$L'; bench '$BAU/bin' -m '$pfad' -p 2048 -n 128 -r 5 -ngl 99")
    [ -z "$r" ] && { sag "  $name/$marke : LEER"; continue; }
    sag "  $name/$marke : pp2048=${r% *} tg128=${r#* }"
  done
done
sag "=== CUDA-MATRIXPFAD DURCH ==="

#!/bin/bash
# Why does Ada get 39 % more generation out of a byte of bandwidth?
#
# The four-card comparison put generation per GB/s at 0.262 (RDNA 3), 0.282
# (Turing) and 0.288 (Ampere) -- and 0.400 for this card. Three architectures
# across two vendors agree, the newest one does not. The obvious suspect is the
# matrix hardware the Vulkan backend reaches through coopmat2, which this card
# advertises (NV_coopmat2) and which the measurement never isolated.
#
# Two switches, so the two halves can be separated:
#   GGML_VK_DISABLE_COOPMAT2                 both phases lose it
#   GGML_VK_DISABLE_COOPMAT2_DECODE_VECTOR   only the generation path loses it
#
# Prediction, written down before the run: prefill collapses without coopmat2
# (that is where matrix work dominates) and generation barely moves, because
# generation is bandwidth-bound. If generation DOES move, the 0.400 has its
# explanation. If it does not, the explanation is elsewhere and this card's
# advantage is still unexplained -- which is also a result.
set -uo pipefail
L=${L:-/root/mess/coopmat2.log}
. "$(dirname "$0")/gemeinsam.sh"

sag "=== Tensor-Kerne isolieren (Vulkan, $(nvidia-smi --query-gpu=name --format=csv,noheader)) ==="
for modell in "3b:$M3" "9b:$M9"; do
  name=${modell%%:*}; pfad=${modell#*:}
  [ -r "$pfad" ] || { sag "  $name: Modell fehlt ($pfad)"; continue; }
  for schalter in "voll:" "ohne-coopmat2:GGML_VK_DISABLE_COOPMAT2=1" \
                  "ohne-decode-vector:GGML_VK_DISABLE_COOPMAT2_DECODE_VECTOR=1"; do
    marke=${schalter%%:*}; umgebung=${schalter#*:}
    karte_leer || { sag "  Karte nicht leer -- $name/$marke uebersprungen"; continue; }
    r=$(env ${umgebung:+$umgebung} bash -c "$(declare -f bench); L='$L'; bench '$BAU/bin' -m '$pfad' -p 2048 -n 128 -r 5 -ngl 99")
    [ -z "$r" ] && { sag "  $name/$marke : LEER"; continue; }
    sag "  $name/$marke : pp2048=${r% *} tg128=${r#* }"
  done
done
sag "=== TENSOR-ISOLIERUNG DURCH ==="

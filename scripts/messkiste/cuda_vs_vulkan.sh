#!/bin/bash
# CUDA against Vulkan on the same card, the same commit, the same model.
#
# This repository has ROCm against Vulkan for the AMD card and NOTHING for
# NVIDIA -- and the two machines that could answer it otherwise cannot: the 3080
# sits in a desktop that is in use, and the 2070 is night-only Turing without a
# toolkit. This card leaves in two days, so the question is answered now or not
# here.
#
# The build is made BESIDE the Vulkan one, in its own directory, and both are
# run from their build trees rather than installed. Installing a superset of
# what was built is what broke the drift check on the other machine twice.
#
# Not only throughput: the completion hash comes along. A backend that is faster
# and answers differently has not made the same work faster.
set -uo pipefail
L=${L:-/root/mess/cuda_vs_vulkan.log}
. "$(dirname "$0")/gemeinsam.sh"
SRC=${SRC:-/opt/mess/llama.cpp}
CUDA_BAU=$SRC/build-cuda

sag "=== CUDA gegen Vulkan ==="

if ! command -v nvcc >/dev/null 2>&1 && [ ! -x /opt/cuda/bin/nvcc ]; then
  # -Sy without -u is a partial upgrade and Arch warns about it. It is chosen
  # deliberately: a full upgrade would pull a new driver into the middle of a
  # measurement programme whose other numbers were taken on 610.57.04. The
  # driver packages are held back explicitly.
  sag "kein nvcc -- CUDA-Toolkit installieren (Treiberpakete ausgenommen)"
  pacman -Sy --noconfirm --needed --ignore nvidia-open,nvidia-utils,nvidia-open-dkms,linux,linux-headers cuda >>"$L" 2>&1 \
    || { sag "Installation fehlgeschlagen -- CUDA-Vergleich entfaellt"; exit 1; }
fi
export PATH=/opt/cuda/bin:$PATH
command -v nvcc >/dev/null 2>&1 || { sag "nvcc trotz Installation nicht im Pfad"; exit 1; }
sag "nvcc: $(nvcc --version | tail -2 | head -1)"

if [ ! -x "$CUDA_BAU/bin/llama-bench" ]; then
  sag "CUDA-Bau (nur die zwei Ziele, kein Install)"
  # 89 = Ada. Building for one architecture instead of all of them turns an
  # hour of nvcc into minutes, and this card is the only one that will run it.
  cmake -B "$CUDA_BAU" -S "$SRC" -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89 \
        -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
        -DCMAKE_BUILD_TYPE=Release >>"$L" 2>&1 || { sag "cmake fehlgeschlagen"; exit 1; }
  cmake --build "$CUDA_BAU" -j"$(nproc)" --target llama-bench llama-cli >>"$L" 2>&1 \
    || { sag "Bau fehlgeschlagen"; exit 1; }
fi
ls "$CUDA_BAU/bin/"libggml-cuda.so >/dev/null 2>&1 || sag "WARNUNG: keine libggml-cuda.so im Baum"

# llama-cli, not just llama-bench: without it there is no output to compare, and
# the first run of this script quietly compared nothing with nothing.
for baum in "$BAU:$SRC" "$CUDA_BAU:$SRC"; do
  b=${baum%%:*}
  [ -x "$b/bin/llama-cli" ] && continue
  sag "llama-cli fehlt in $b -- wird nachgebaut"
  cmake --build "$b" -j"$(nproc)" --target llama-cli >>"$L" 2>&1 || sag "  Nachbau fehlgeschlagen"
done

for modell in "3b:$M3" "9b:$M9"; do
  name=${modell%%:*}; pfad=${modell#*:}
  [ -r "$pfad" ] || { sag "  $name: Modell fehlt"; continue; }
  for paar in "vulkan:$BAU/bin" "cuda:$CUDA_BAU/bin"; do
    marke=${paar%%:*}; bin=${paar#*:}
    karte_leer || { sag "  Karte nicht leer -- $name/$marke uebersprungen"; continue; }
    r=$(bench "$bin" -m "$pfad" -p 2048 -n 128 -r 5 -ngl 99)
    if [ -z "$r" ]; then sag "  $name/$marke : LEER"; continue; fi
    h=$(ausgabe_hash "$bin" "$pfad") || h="$h  <-- KEIN VERGLEICH MOEGLICH"
    sag "  $name/$marke : pp2048=${r% *} tg128=${r#* }   Ausgabe $h"
  done
done
sag "Gleicher Hash heisst: derselbe Text, nur anders gerechnet. Ein anderer Hash ist ein"
sag "Befund fuer sich -- dann vergleichen die Durchsatzzahlen zwei verschiedene Arbeiten."
sag "=== CUDA-VERGLEICH DURCH ==="

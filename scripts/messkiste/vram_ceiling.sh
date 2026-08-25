#!/bin/bash
# Where does 12 GB stop being enough?
#
# The class most buyers actually choose is the one this repository had no card
# for: 24 GB, 10 GB and 8 GB were represented, 12 GB was not. The question is
# not "does the model fit" -- a 9B at Q4 fits everywhere -- but how much context
# fits BESIDE it, because that is what a RAG system is sized by.
#
# Two sweeps over the same depths, so the answer separates the two things a
# buyer can change:
#   f16 KV cache   what you get without thinking about it
#   q8_0 KV cache  what quantising the cache buys, in depth rather than percent
#
# A depth that fails is a RESULT and gets named as one. Out of memory at 32k is
# the number somebody needs; a blank line is not.
set -uo pipefail
L=${L:-/root/mess/vram_ceiling.log}
. "$(dirname "$0")/gemeinsam.sh"
TIEFEN=${TIEFEN:-"0 4096 8192 16384 32768 65536"}
MODELL=${MODELL:-$M9}
MARKE=${MARKE:-qwen3.5-9b Q4_K_M}

sag "=== 12-GB-Grenze mit $MARKE ($(basename "$BAU")) ==="
sag "Karte: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader)"
for cache in f16 q8_0; do
  sag "--- KV-Cache $cache ---"
  for d in $TIEFEN; do
    karte_leer || { sag "  Tiefe $d: Karte nicht leer -- uebersprungen"; continue; }
    r=$(bench "$BAU/bin" -m "$MODELL" -p 512 -n 128 -d "$d" -fa on -ctk "$cache" -ctv "$cache" -r 2 -ngl 99)
    if [ -z "$r" ]; then
      # The most likely reason is exactly the one being measured. Say which
      # depth failed rather than dropping the row.
      sag "  Tiefe $d: KEINE MESSUNG -- vermutlich zu wenig VRAM fuer den Cache"
      continue
    fi
    v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
    sag "  Tiefe $d: pp512=${r% *} tg128=${r#* }   (${v} MiB belegt kurz nach dem Lauf)"
  done
done
sag "=== VRAM-GRENZE DURCH ==="

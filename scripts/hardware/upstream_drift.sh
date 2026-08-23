#!/bin/bash
# Builds current llama.cpp BESIDE the pinned build and measures both in the
# same session. Recurring, not one-off.
#
# WHY BESIDE, NOT OVER: a second prefix whose binary quietly loads the first
# one's libraries is something we already had here -- all eight resolved into
# the old prefix, and it only came out because the old libraries did not know
# the architecture. That is why the number of libraries that really land in the
# new prefix is counted below, before any number counts.
#
# WHY IN THE SAME SESSION: two numbers from the same hour are a comparison, a
# number from today against one from three weeks ago is not.
set -u
PROD=/opt/llama-cpp        # was die Produktions-Runtime tatsaechlich startet
ALT=/opt/llama-cpp-nb      # womit dieses Repo misst
NEU=/opt/llama-cpp-latest  # aktuelles upstream
SRC=/opt/src/llama.cpp
M=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
L=/root/eval/upstream_drift.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }

sag "=== Quelle aktualisieren ==="
cd $SRC || { sag "kein Quellbaum unter $SRC"; exit 1; }
git fetch --tags --quiet origin 2>>$L
ALT_V=$(cat $ALT/.built-version 2>/dev/null || echo unbekannt)
NEU_V=$(git rev-parse --short origin/master)
sag "gepinnt: $ALT_V   upstream: $NEU_V"

sag "=== bauen (CPU-Arbeit, ruehrt die Karte nicht an) ==="
git checkout --quiet origin/master 2>>$L
cmake -B build-latest -DCMAKE_INSTALL_PREFIX=$NEU -DGGML_VULKAN=ON \
      -DLLAMA_CURL=OFF -DCMAKE_BUILD_TYPE=Release >>$L 2>&1 || { sag "cmake fehlgeschlagen"; exit 1; }
cmake --build build-latest -j"$(nproc)" --target llama-bench llama-cli >>$L 2>&1 || { sag "Bau fehlgeschlagen"; exit 1; }
cmake --install build-latest >>$L 2>&1
echo "$NEU_V" > $NEU/.built-version

# The probe that would have caught the old mistake.
sag "=== loesen die Bibliotheken ins NEUE Praefix auf? ==="
export LD_LIBRARY_PATH=$NEU/lib
ges=$(ldd $NEU/bin/llama-bench 2>/dev/null | grep -cE "libllama|libggml")
neu_n=$(ldd $NEU/bin/llama-bench 2>/dev/null | grep -E "libllama|libggml" | grep -c "$NEU/lib")
sag "  $neu_n von $ges im neuen Praefix"
[ "$ges" -gt 0 ] && [ "$neu_n" -ne "$ges" ] && { sag "  ABBRUCH: Bibliotheken kommen aus dem falschen Praefix"; exit 1; }

# THIS MEASUREMENT DECIDES WHICH BUILD GOES INTO PRODUCTION.
# Two things follow from that which a pure throughput measurement does not do:
#
#   1. The PRODUCTION build has to run along. It is the state a change gets
#      weighed against -- not our measurement build.
#   2. The PRODUCTION configuration has to be measured too. We documented
#      ourselves that production flags move a result by a factor of 6.8; a
#      recommendation based on synthetic flags would be worthless.
PROD_V=$(cat $PROD/.built-version 2>/dev/null || echo unbekannt)
sag "=== Referenzlauf auf ALLEN DREI, gleiche Sitzung ==="
for paar in "$PROD_V $PROD" "$ALT_V $ALT" "$NEU_V $NEU"; do
  set -- $paar; v=$1; pfad=$2
  for i in $(seq 1 90); do
    b=$(pgrep -x llama-bench|wc -l); s=$(pgrep -x llama-server|wc -l)
    vram=$(( $(cat /sys/class/drm/card1/device/mem_info_vram_used)/1048576 ))
    [ "$vram" -lt 500 ] && [ "$b" -eq 0 ] && [ "$s" -eq 0 ] && break
    sleep 20
  done
  export LD_LIBRARY_PATH=$pfad/lib
  r=$(timeout 1800 $pfad/bin/llama-bench -m $M -p 2048 -n 128 -r 3 -ngl 99 -sm none -mg 0 -o json 2>/dev/null \
      | python3 -c "import json,sys
d=json.load(sys.stdin); v={('pp' if e['n_prompt'] else 'tg'): e['avg_ts'] for e in d}
print('pp2048=%.1f tg128=%.2f' % (v.get('pp',0), v.get('tg',0)))" 2>/dev/null)
  sag "  $v : $r"
  # Same output? A build that got faster and answers differently is not
  # faster at the same thing.
  h=$(timeout 300 $pfad/bin/llama-cli -m $M -ngl 99 -sm none -mg 0 --seed 1234 --temp 0 \
        -n 96 -no-cnv -st --simple-io --no-warmup -p "List the first ten prime numbers." \
        < /dev/null 2>/dev/null | sed -n '/\[Start thinking\]/,/^\[ Prompt:/p' \
        | grep -v '^\[ Prompt:' | sha256sum | cut -c1-16)
  sag "  $v : Ausgabe-Hash $h"

  # Production-like configuration: quantised KV cache, large context,
  # parallel slots. That is the case being decided on.
  p=$(timeout 1800 $pfad/bin/llama-bench -m $M -p 4096 -n 256 -d 8192 -fa on \
        -ctk q8_0 -ctv q8_0 -r 3 -ngl 99 -sm none -mg 0 -o json 2>/dev/null \
      | python3 -c "import json,sys
d=json.load(sys.stdin); v={('pp' if e['n_prompt'] else 'tg'): e['avg_ts'] for e in d}
print('pp4096@d8192=%.1f tg256=%.2f' % (v.get('pp',0), v.get('tg',0)))" 2>/dev/null)
  sag "  $v : produktionsnah  $p"

  # A build that got faster while resetting the card is not a candidate. A
  # throughput test alone would wave that through.
  k=$(dmesg | tail -200 | grep -ciE "amdgpu.*(ring|reset|error)|GPU reset|VRAM is lost" || true)
  sag "  $v : Kernelmeldungen $k"
done

sag "=== ENTSCHEIDUNGSGRUNDLAGE ==="
sag "Ein Wechsel des Produktivstands setzt voraus:"
sag "  - Ausgabe-Hash identisch zum bisherigen Produktivstand ($PROD_V)"
sag "  - keine Kernelmeldungen"
sag "  - produktionsnahe Zahlen nicht schlechter"
sag "Die Zeilen oben liefern alle drei. Die Entscheidung trifft der Betreiber."
sag "=== DRIFT-PRUEFUNG DURCH ==="
echo FERTIG_DRIFT | tee -a $L

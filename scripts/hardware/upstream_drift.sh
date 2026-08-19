#!/bin/bash
# Baut aktuelles llama.cpp NEBEN den festgepinnten Build und misst beide in
# derselben Sitzung. Wiederkehrend, nicht einmalig.
#
# WARUM NEBEN, NICHT DARUEBER: ein zweites Praefix, dessen Binary heimlich die
# Bibliotheken des ersten laedt, hatten wir hier schon -- alle acht loesten in
# das alte Praefix auf, und nur weil die alten Bibliotheken die Architektur
# nicht kannten, ist es aufgefallen. Deshalb wird unten gezaehlt, wie viele
# Bibliotheken wirklich im neuen Praefix landen, bevor eine Zahl zaehlt.
#
# WARUM IN DERSELBEN SITZUNG: zwei Zahlen aus derselben Stunde sind ein
# Vergleich, eine Zahl von heute gegen eine von vor drei Wochen nicht.
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

# Die Probe, die den alten Fehler gefangen haette.
sag "=== loesen die Bibliotheken ins NEUE Praefix auf? ==="
export LD_LIBRARY_PATH=$NEU/lib
ges=$(ldd $NEU/bin/llama-bench 2>/dev/null | grep -cE "libllama|libggml")
neu_n=$(ldd $NEU/bin/llama-bench 2>/dev/null | grep -E "libllama|libggml" | grep -c "$NEU/lib")
sag "  $neu_n von $ges im neuen Praefix"
[ "$ges" -gt 0 ] && [ "$neu_n" -ne "$ges" ] && { sag "  ABBRUCH: Bibliotheken kommen aus dem falschen Praefix"; exit 1; }

# DIESE MESSUNG ENTSCHEIDET, WELCHER BUILD PRODUKTIV GEHT.
# Daraus folgen zwei Dinge, die eine reine Durchsatzmessung nicht leistet:
#
#   1. Der PRODUKTIONS-Build muss mitlaufen. Er ist der Stand, gegen den ein
#      Wechsel abgewogen wird -- nicht unser Mess-Build.
#   2. Es muss die PRODUKTIONS-Konfiguration mitgemessen werden. Wir haben
#      selbst dokumentiert, dass Produktionsflags ein Ergebnis um Faktor 6,8
#      verschieben; eine Empfehlung auf Basis synthetischer Flags waere wertlos.
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
  # Gleiche Ausgabe? Ein Build, der schneller wurde und anders antwortet, ist
  # nicht schneller beim Gleichen.
  h=$(timeout 300 $pfad/bin/llama-cli -m $M -ngl 99 -sm none -mg 0 --seed 1234 --temp 0 \
        -n 96 -no-cnv -st --simple-io --no-warmup -p "List the first ten prime numbers." \
        < /dev/null 2>/dev/null | sed -n '/\[Start thinking\]/,/^\[ Prompt:/p' \
        | grep -v '^\[ Prompt:' | sha256sum | cut -c1-16)
  sag "  $v : Ausgabe-Hash $h"

  # Produktionsnahe Konfiguration: gequantelter KV-Cache, grosser Kontext,
  # parallele Slots. Das ist der Fall, ueber den entschieden wird.
  p=$(timeout 1800 $pfad/bin/llama-bench -m $M -p 4096 -n 256 -d 8192 -fa on \
        -ctk q8_0 -ctv q8_0 -r 3 -ngl 99 -sm none -mg 0 -o json 2>/dev/null \
      | python3 -c "import json,sys
d=json.load(sys.stdin); v={('pp' if e['n_prompt'] else 'tg'): e['avg_ts'] for e in d}
print('pp4096@d8192=%.1f tg256=%.2f' % (v.get('pp',0), v.get('tg',0)))" 2>/dev/null)
  sag "  $v : produktionsnah  $p"

  # Ein Build, der schneller wurde und dabei die Karte zuruecksetzt, ist kein
  # Kandidat. Ein Durchsatztest allein wuerde das durchwinken.
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

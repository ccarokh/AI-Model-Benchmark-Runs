#!/bin/bash
# Frisches Arch auf einer 4070 Super (12 GB) messbereit machen.
#
# Laeuft auf der 4070-Kiste, von einer SATA-Platte, die anderswo bestueckt
# wurde (4070_platte_bestuecken.sh). Modelle, Quelltext und Skripte liegen
# bereits unter /opt/mess -- diese Kiste braucht kein Netz und keinen Zugriff
# auf andere Rechner.
#
# ARCH, NICHT DEBIAN -- keine Geschmacksfrage. Jede Zahl in diesem Repo stammt
# von Arch. Mit einer anderen Distribution waeren Karte UND Betriebssystem samt
# Treiberstand und Bibliotheken gleichzeitig anders, und der Vergleich wuerde
# Aufbauten messen statt Hardware. Eine Variable, sonst nichts.
#
# Aus demselben Grund wird llama.cpp HIER GEBAUT statt als Fertigpaket geholt:
# der Messrechner baut auch selbst, mit denselben Schaltern. (Fuer Linux gibt es
# ohnehin keine CUDA-Binaerpakete, nur fuer Windows.)
#
# VULKAN ZUERST, CUDA DANACH. Vulkan ist das Backend, mit dem hier alles
# gemessen wurde -- damit steht der erste Vergleich allein auf der Karte. Ein
# CUDA-Bau danach misst dann sauber getrennt den Backend-Unterschied auf NVIDIA,
# das Gegenstueck zu unserem AMD-Vulkan-gegen-ROCm.
#
# SATA statt NVMe aendert nichts an der Gueltigkeit: die Platte zaehlt nur beim
# Laden, und Laden liegt ausserhalb jedes Messfensters. Es kostet Wartezeit.
set -eu
Z=/opt/mess
MODELLE=${MODELLE:-$Z/models}
sag(){ echo "[$(date '+%H:%M:%S')] $*"; }

sag "1/5  Pakete"
pacman -Sy --needed --noconfirm \
  nvidia nvidia-utils vulkan-icd-loader vulkan-tools shaderc glslang \
  base-devel cmake git python jq

sag "2/5  Karte"
nvidia-smi --query-gpu=name,memory.total,power.limit --format=csv,noheader || {
  echo "Treiber nicht aktiv -- neu starten und dieses Skript erneut ausfuehren"; exit 1; }
vulkaninfo --summary 2>/dev/null | grep -iE "deviceName|driverName" | head -4 || true
[ -d "$MODELLE" ] || { echo "Modelle fehlen unter $MODELLE -- Platte bestueckt?"; exit 1; }

sag "3/5  llama.cpp bauen (Vulkan)"
cd $Z/llama.cpp && git log -1 --format="  Bau: %H  %ad" --date=short
cmake -B build -DGGML_VULKAN=ON -DLLAMA_CURL=OFF -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build build -j"$(nproc)" --target llama-bench llama-server

sag "4/5  Welche Modelle passen in 12 GB"
for m in qwen3.5-9b bge-m3 ornith-9b qwen2.5-coder-14b; do
  d="$MODELLE/$m"
  if [ -d "$d" ]; then printf "  %-20s %s\n" "$m" "$(du -sh "$d" | cut -f1)"
  else printf "  %-20s FEHLT -- liegt nur auf dem Messrechner\n" "$m"; fi
done

sag "5/5  Kontrollmessung"
B=$Z/llama.cpp/build/bin/llama-bench
G=$(ls "$MODELLE"/qwen3.5-9b/*.gguf | head -1)
"$B" -m "$G" -ngl 99 -p 2048 -n 128 -r 3 -o json > $Z/erstmessung.json
python3 - "$Z/erstmessung.json" <<'PY'
import json, sys
for e in json.load(open(sys.argv[1])):
    # llama-bench liefert KEIN "reps" -- die Wiederholungen muessen gezaehlt werden.
    n = len(e["samples_ns"])
    art = "prefill" if e["n_prompt"] else "erzeugung"
    print(f"  {art:10} {e['avg_ts']:8.2f} t/s   ({n} Wiederholungen)")
PY
cat <<'ENDE'

Vorhersage, VOR der Messung notiert:
  4070 Super: 504 GB/s.  7900 XTX: 960 GB/s.
  Skaliert die Erzeugung mit der Bandbreite, muss sie bei rund 52 % liegen.
  Trifft es zu, gilt die These auch auf fremder Hardware.
  Trifft es nicht zu, ist das der interessantere Fall -- dann gilt sie nur hier.
ENDE

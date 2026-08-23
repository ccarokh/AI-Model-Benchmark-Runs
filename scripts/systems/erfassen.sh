#!/bin/bash
# Ein Rechner, ein fester Satz Tatsachen, als JSON.
#
# Auf JEDEM Messrechner dasselbe Skript, damit dieselben Felder herauskommen.
# Vorher hatte jede Systembeschreibung ihre eigene Form: der eine Text erzaehlte
# ueber RAM, der naechste ueber das BIOS, und ob irgendwo etwas FEHLT, sah man
# gar nicht. Was hier nicht ermittelbar ist, steht als null drin -- eine Luecke
# ist eine Aussage.
#
#   erfassen.sh > /pfad/system.json
set -u
j() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n'; }
w() { local v; v=$(eval "$2" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ -n "$v" ]; then printf '  "%s": "%s",\n' "$1" "$(j "$v")"; else printf '  "%s": null,\n' "$1"; fi; }

echo "{"
w rechnername      'uname -n'
w erfasst_am       'date -Is'
w cpu              'grep -m1 "model name" /proc/cpuinfo | cut -d: -f2'
w cpu_faeden       'nproc'
w ram_gb           'free -g | awk "/^Mem|^Speicher/{print \$2}"'
w board            'cat /sys/devices/virtual/dmi/id/board_vendor; :'
w board_modell     'cat /sys/devices/virtual/dmi/id/board_name'
w bios             'cat /sys/devices/virtual/dmi/id/bios_version'
w bios_datum       'cat /sys/devices/virtual/dmi/id/bios_date'
w mikrocode        'grep -m1 -i "microcode" /proc/cpuinfo | cut -d: -f2'
w mikrocode_start  'journalctl -b -k --no-pager 2>/dev/null | grep -m1 -i "microcode.*Updated early" | sed "s/.*from: //"'
w os               '. /etc/os-release; echo "$PRETTY_NAME"'
w kernel           'uname -r'
w python           'python3 --version 2>&1 || python --version 2>&1'
# btrfs haengt an die Quelle ein "[/@]" fuer das Unterbaende -- das muss weg,
# sonst findet lsblk das Geraet nicht.
w wurzel_geraet    'findmnt -no SOURCE / | sed "s/\\[.*//"'
w wurzel_traeger   'q=$(findmnt -no SOURCE / | sed "s/\\[.*//"); lsblk -dno MODEL,SIZE,TRAN "/dev/$(lsblk -no PKNAME "$q" | head -1)"'

# --- Karten ---------------------------------------------------------------
printf '  "karten": [\n'
erste=1
if command -v nvidia-smi >/dev/null; then
  nvidia-smi --query-gpu=name,memory.total,driver_version,power.limit --format=csv,noheader | while IFS=, read -r n m d p; do
    [ $erste -eq 0 ] && printf ',\n'; erste=0
    printf '    {"name": "%s", "vram": "%s", "treiber": "%s", "leistungsgrenze": "%s", "hersteller": "NVIDIA"}' \
      "$(j "${n# }")" "$(j "${m# }")" "$(j "${d# }")" "$(j "${p# }")"
  done
fi
for d in /sys/class/drm/card*/device; do
  [ -r "$d/mem_info_vram_total" ] || continue
  v=$(( $(cat "$d/mem_info_vram_total") / 1048576 ))
  # Der PCI-Pfad zeigt bei einer Karte hinter einem Switch auf dessen
  # Downstream-Port, nicht auf die Karte -- dann steht dort "Navi 10 XL
  # Downstream Port of PCI Express Switch" statt des Kartennamens. Deshalb den
  # Namen aus der Karte selbst lesen.
  adr=$(basename "$(readlink -f "$d")")
  n=$(lspci -s "$adr" 2>/dev/null | grep -iE "vga|display|3d" | cut -d: -f3-)
  [ -z "$n" ] && n=$(lspci 2>/dev/null | grep -iE "vga.*(amd|ati)" | head -1 | cut -d: -f3-)
  printf ',\n    {"name": "%s", "vram": "%s MiB", "treiber": null, "leistungsgrenze": null, "hersteller": "AMD"}' \
    "$(j "${n:-unbekannt}")" "$v"
done
printf '\n  ],\n'

w vulkan_geraet    'vulkaninfo --summary 2>/dev/null | grep -m1 deviceName | cut -d= -f2'
w vulkan_api       'vulkaninfo --summary 2>/dev/null | grep -m1 apiVersion | cut -d= -f2'
# PCIe je Karte UND die Strecke darueber. Auf System A sitzt eine Bruecke
# dazwischen: die Karte redet mit ihr in Gen 4 x16, die Bruecke mit der CPU in
# Gen 3 x8. Wer nur die Karte abfragt, dokumentiert die falsche Haelfte -- genau
# das stand hier jahrelang drin.
#
# Braucht root: ohne Rechte laesst lspci die Verbindungsdaten weg, und ein
# fehlender Wert saehe aus wie eine fehlende Faehigkeit.
printf '  "pcie": [\n'
e=1
for s in $(lspci 2>/dev/null | grep -iE "vga|3d controller" | cut -d" " -f1); do
  karte=$(lspci -vv -s "$s" 2>/dev/null | grep -m1 "LnkSta:" | sed "s/^[ \t]*LnkSta:[ \t]*//")
  br=$(basename "$(dirname "$(readlink -f "/sys/bus/pci/devices/0000:$s/..")")" 2>/dev/null)
  oben=$(lspci -vv -s "${br#0000:}" 2>/dev/null | grep -m1 "LnkSta:" | sed "s/^[ \t]*LnkSta:[ \t]*//")
  name=$(lspci -s "$s" 2>/dev/null | cut -d: -f3- | sed "s/^ //" | cut -c1-48)
  [ $e -eq 0 ] && printf ',\n'; e=0
  printf '    {"geraet": "%s", "name": "%s", "karte_zur_bruecke": "%s", "bruecke_zur_cpu": "%s"}' \
    "$(j "$s")" "$(j "$name")" "$(j "${karte:-nicht lesbar (root noetig?)}")" "$(j "${oben:-keine Bruecke}")"
done
printf '\n  ],\n'

w vram_leerlauf    'nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null || { for f in /sys/class/drm/card*/device/mem_info_vram_used; do [ -r "$f" ] && echo "$(( $(cat $f)/1048576 )) MiB" && break; done; }'

# --- llama.cpp-Baustaende --------------------------------------------------
printf '  "llama_cpp": [\n'
e=1
for p in /opt/llama-cpp /opt/llama-cpp-nb /opt/llama-cpp-rocm /opt/mess/llama.cpp/build; do
  b="$p/bin/llama-bench"; [ -x "$b" ] || b="$p/bin/llama-server"; [ -x "$b" ] || continue
  v=$(cat "$p/.built-version" 2>/dev/null)
  [ -z "$v" ] && v=$(git -C "$(dirname "$p")" log -1 --format=%h 2>/dev/null)
  [ $e -eq 0 ] && printf ',\n'; e=0
  printf '    {"pfad": "%s", "stand": "%s"}' "$(j "$p")" "$(j "${v:-unbekannt}")"
done
printf '\n  ]\n}\n'

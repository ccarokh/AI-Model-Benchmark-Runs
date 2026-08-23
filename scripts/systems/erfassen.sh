#!/bin/bash
# One machine, one fixed set of facts, as JSON.
#
# The same script on EVERY measuring machine, so the same fields come out. Each
# system description used to have its own shape: one talked about RAM, the next
# about the BIOS, and whether something was MISSING could not be seen at all.
# Anything not readable here lands as null -- a gap is a statement.
#
#   erfassen.sh > /path/system.json
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
# btrfs appends "[/@]" for the subvolume -- strip it, or lsblk will not find
# the device.
w wurzel_geraet    'findmnt -no SOURCE / | sed "s/\\[.*//"'
w wurzel_traeger   'q=$(findmnt -no SOURCE / | sed "s/\\[.*//"); lsblk -dno MODEL,SIZE,TRAN "/dev/$(lsblk -no PKNAME "$q" | head -1)"'

# --- GPUs -----------------------------------------------------------------
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
  # For a card behind a switch the PCI path points at the switch's downstream
  # port rather than the card -- the entry then reads "Navi 10 XL Downstream
  # Port of PCI Express Switch" instead of the card's name. So read the name
  # from the card itself.
  adr=$(basename "$(readlink -f "$d")")
  n=$(lspci -s "$adr" 2>/dev/null | grep -iE "vga|display|3d" | cut -d: -f3-)
  [ -z "$n" ] && n=$(lspci 2>/dev/null | grep -iE "vga.*(amd|ati)" | head -1 | cut -d: -f3-)
  printf ',\n    {"name": "%s", "vram": "%s MiB", "treiber": null, "leistungsgrenze": null, "hersteller": "AMD"}' \
    "$(j "${n:-unknown}")" "$v"
done
printf '\n  ],\n'

w vulkan_geraet    'vulkaninfo --summary 2>/dev/null | grep -m1 deviceName | cut -d= -f2'
w vulkan_api       'vulkaninfo --summary 2>/dev/null | grep -m1 apiVersion | cut -d= -f2'
# PCIe per card AND the link above it. On System A a switch sits in between:
# the card talks to it at Gen 4 x16, the switch talks to the CPU at Gen 3 x8.
# Query only the card and you document the wrong half -- which is exactly what
# stood here for months.
#
# Needs root: without it lspci omits the link details, and a missing value would
# look like a missing capability.
printf '  "pcie": [\n'
e=1
for s in $(lspci 2>/dev/null | grep -iE "vga|3d controller" | cut -d" " -f1); do
  karte=$(lspci -vv -s "$s" 2>/dev/null | grep -m1 "LnkSta:" | sed "s/^[ \t]*LnkSta:[ \t]*//")
  br=$(basename "$(dirname "$(readlink -f "/sys/bus/pci/devices/0000:$s/..")")" 2>/dev/null)
  oben=$(lspci -vv -s "${br#0000:}" 2>/dev/null | grep -m1 "LnkSta:" | sed "s/^[ \t]*LnkSta:[ \t]*//")
  name=$(lspci -s "$s" 2>/dev/null | cut -d: -f3- | sed "s/^ //" | cut -c1-48)
  [ $e -eq 0 ] && printf ',\n'; e=0
  printf '    {"geraet": "%s", "name": "%s", "karte_zur_bruecke": "%s", "bruecke_zur_cpu": "%s"}' \
    "$(j "$s")" "$(j "$name")" "$(j "${karte:-not readable, needs root}")" "$(j "${oben:-no switch}")"
done
printf '\n  ],\n'

w vram_leerlauf    'nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null || { for f in /sys/class/drm/card*/device/mem_info_vram_used; do [ -r "$f" ] && echo "$(( $(cat $f)/1048576 )) MiB" && break; done; }'

# --- llama.cpp builds ------------------------------------------------------
printf '  "llama_cpp": [\n'
e=1
for p in /opt/llama-cpp /opt/llama-cpp-nb /opt/llama-cpp-rocm /opt/mess/llama.cpp/build; do
  b="$p/bin/llama-bench"; [ -x "$b" ] || b="$p/bin/llama-server"; [ -x "$b" ] || continue
  v=$(cat "$p/.built-version" 2>/dev/null)
  [ -z "$v" ] && v=$(git -C "$(dirname "$p")" log -1 --format=%h 2>/dev/null)
  # Last resort: ask the binary -- but NOT llama-bench, which has no --version.
  # llama-server and llama-cli answer with "version: 9614 (ebc10770ac)". System
  # B therefore read "unknown" while the history two lines below recorded that
  # very number: a gap that did not exist.
  if [ -z "$v" ]; then
    for c in llama-server llama-cli; do
      [ -x "$p/bin/$c" ] || continue
      v=$(LD_LIBRARY_PATH="$p/lib" "$p/bin/$c" --version 2>&1 | grep -m1 -oE "version: .*" | sed "s/version: //")
      # "1 (xxxxxxx)" is a build artefact, not an identifier -- written down as
      # a number it would be worse than an honest "unknown".
      case "$v" in "1 ("*) v="" ;; esac
      [ -n "$v" ] && break
    done
  fi
  # Backend from the backend libraries that exist in the prefix. Two dead ends
  # came first: reading the output misleads for ROCm (llama.cpp's HIP path
  # prints "ggml_cuda_init"), and ldd shows nothing because ggml loads its
  # backends at runtime -- they are not linked into the binary.
  # From the backend libraries present in the prefix. Two dead ends came first:
  # reading the output misleads for ROCm (the HIP path prints "ggml_cuda_init"),
  # and ldd shows nothing because ggml loads its backends at runtime -- they are
  # not linked into the binary.
  bk=""
  for k in vulkan cuda hip rocm sycl; do
    # A cmake build directory puts the libraries next to the binaries, an
    # installation puts them in lib/. Check both places SEPARATELY: "ls a* b*"
    # fails as soon as one pattern misses, and then reports neither.
    for o in "$p/lib" "$p/bin"; do
      for datei in "$o"/libggml-$k.so*; do
        [ -e "$datei" ] || continue
        case "+$bk+" in *"+$k+"*) ;; *) bk="${bk:+$bk+}$k" ;; esac
        break
      done
    done
  done
  # HIP is ROCm; name it consistently.
  bk=$(printf '%s' "$bk" | sed "s/hip/rocm/")
  [ $e -eq 0 ] && printf ',\n'; e=0
  printf '    {"pfad": "%s", "stand": "%s", "backend": "%s"}' \
    "$(j "$p")" "$(j "${v:-unknown}")" "$(j "${bk:-unknown}")"
done
printf '\n  ]\n}\n'

#!/bin/bash
# Measurement suite for llama.cpp. Usage:  suite.sh <version> [model-key]
#
#   suite.sh b10488            # a nightly tag
#   suite.sh v0.1.2            # a pre-release
#   suite.sh master            # current state
#   suite.sh installed:/opt/llama-cpp   # measure an already built prefix
#
# Everything else happens in here: build (if needed), verify that the intended
# build is really the one running, measure, store the result versioned.
#
# DESIGN RULES, all of them out of this repo's mistakes:
#   - a fresh process per measurement (llama-server carries state along)
#   - card guard before EVERY step, not once at the start
#   - whatever is skipped gets logged -- silence looks like success
#   - every varying parameter appears in the filename
#   - power is integrated over the compute window only, not over loading
#   - measure the output hash too: faster and different is not faster
set -u

VERSION="${1:?Aufruf: suite.sh <version|installed:/pfad> [modell]}"
MODELL_KEY="${2:-qwen3.5-9b}"

SRC=/opt/src/llama.cpp
BASIS=/opt/llama-suite
ERG=/root/eval/suite
M=/opt/llm-infra/models
D=/sys/class/drm/card1/device
W=$(ls $D/hwmon/hwmon*/power1_average 2>/dev/null | head -1)

declare -A MODELLE=(
  [qwen3.5-9b]=$M/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
  [qwen3.8-27b]=$M/qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf
  [llama-3.2-3b]=$M/llama-3.2-3b/Llama-3.2-3B-Instruct-Q4_K_M.gguf
)
GGUF="${MODELLE[$MODELL_KEY]:-}"
[ -s "$GGUF" ] || { echo "unbekanntes oder fehlendes Modell: $MODELL_KEY"; exit 2; }

if [[ "$VERSION" == installed:* ]]; then
  PRAEFIX="${VERSION#installed:}"
  TAG=$(cat "$PRAEFIX/.built-version" 2>/dev/null || basename "$PRAEFIX")
else
  PRAEFIX=$BASIS/$VERSION
  TAG=$VERSION
fi
LAUF=$ERG/${TAG}__${MODELL_KEY}
mkdir -p "$LAUF"
L=$LAUF/suite.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }
ZEILE(){ printf '%s\t%s\t%s\t%s\n' "$TAG" "$MODELL_KEY" "$1" "$2" >> "$LAUF/ergebnis.tsv"; }

[ -f "$LAUF/ergebnis.tsv" ] || printf 'build\tmodel\tmetric\tvalue\n' > "$LAUF/ergebnis.tsv"
sag "=== Suite $TAG / $MODELL_KEY ==="

# ---------------------------------------------------------------- build
if [ ! -x "$PRAEFIX/bin/llama-bench" ]; then
  sag "--- bauen: $VERSION ---"
  [ -d "$SRC" ] || { sag "kein Quellbaum unter $SRC"; exit 1; }
  cd "$SRC" || exit 1
  git fetch --tags --quiet origin >>"$L" 2>&1
  git checkout --quiet "$VERSION" >>"$L" 2>&1 || git checkout --quiet "origin/$VERSION" >>"$L" 2>&1 \
    || { sag "Version $VERSION nicht auffindbar"; exit 1; }
  B=$SRC/build-$VERSION
  cmake -B "$B" -DCMAKE_INSTALL_PREFIX="$PRAEFIX" -DGGML_VULKAN=ON -DLLAMA_CURL=OFF \
        -DCMAKE_BUILD_TYPE=Release >>"$L" 2>&1 || { sag "cmake fehlgeschlagen"; exit 1; }
  cmake --build "$B" -j"$(nproc)" --target llama-bench llama-cli llama-server >>"$L" 2>&1 \
        || { sag "Bau fehlgeschlagen"; exit 1; }
  cmake --install "$B" >>"$L" 2>&1
  git rev-parse --short HEAD > "$PRAEFIX/.built-version"
  sag "gebaut nach $PRAEFIX"
else
  sag "Build vorhanden: $PRAEFIX"
fi
export LD_LIBRARY_PATH="$PRAEFIX/lib"

# ------------------------------------------- is THIS build really running?
# A second prefix whose binary loads the first one's libraries is something we
# already had here: all eight resolved into the old prefix and only an
# architecture error gave it away.
ges=$(ldd "$PRAEFIX/bin/llama-bench" 2>/dev/null | grep -cE "libllama|libggml")
mein=$(ldd "$PRAEFIX/bin/llama-bench" 2>/dev/null | grep -E "libllama|libggml" | grep -c "$PRAEFIX/lib")
sag "Bibliotheken: $mein von $ges im eigenen Praefix"
ZEILE libs_own "$mein/$ges"
[ "$ges" -gt 0 ] && [ "$mein" -ne "$ges" ] && { sag "ABBRUCH: falsches Praefix"; exit 1; }

frei(){ for i in $(seq 1 45); do
    v=$(( $(cat $D/mem_info_vram_used)/1048576 )); s=$(pgrep -x llama-server|wc -l); b=$(pgrep -x llama-bench|wc -l)
    [ "$v" -lt 500 ] && [ "$s" -eq 0 ] && [ "$b" -eq 0 ] && return 0; sleep 20
  done; sag "  Karte belegt -- Schritt uebersprungen: $1"; return 1; }

bench(){ # $1=marke  $2=metrik-praefix  $3..=flags
  local marke=$1 pre=$2; shift 2
  frei "$marke" || { ZEILE "${pre}" "SKIPPED_CARD_BUSY"; return; }
  local j=$LAUF/${marke}.json w=$LAUF/${marke}.watt
  : > "$w"
  ( while true; do echo "$(date +%s.%N) $(cat $W)"; sleep 1; done ) > "$w" & local sp=$!
  local vor=$(dmesg|wc -l)
  timeout 3600 "$PRAEFIX/bin/llama-bench" -m "$GGUF" "$@" -ngl 99 -sm none -mg 0 -o json > "$j" 2>>"$L"
  local rc=$?; kill $sp 2>/dev/null
  local kern=$(dmesg|tail -n +$((vor+1))|grep -ciE "amdgpu.*(ring|reset|error)|GPU reset|VRAM is lost" || true)
  ZEILE "${pre}_kernel_msgs" "$kern"
  [ $rc -ne 0 ] && { sag "  $marke FEHLGESCHLAGEN rc=$rc"; ZEILE "${pre}" "FAILED_rc$rc"; return; }
  python3 - "$w" "$j" "$pre" "$LAUF/ergebnis.tsv" "$TAG" "$MODELL_KEY" <<'PY'
import json, sys
w=[(float(a),int(b)/1e6) for a,b in (l.split() for l in open(sys.argv[1]) if l.strip())]
d=json.load(open(sys.argv[2])); pre=sys.argv[3]
c=sum(sum(e["samples_ns"]) for e in d)/1e9
r=[x for x in w if x[0]>=w[-1][0]-c] or w
wh=sum((r[i][1]+r[i-1][1])/2*(r[i][0]-r[i-1][0])/3600 for i in range(1,len(r)))
v={("pp" if e["n_prompt"] else "tg"): e["avg_ts"] for e in d}
tok=sum((e["n_prompt"]+e["n_gen"])*len(e["samples_ns"]) for e in d)
out=open(sys.argv[4],"a")
for k,val in (("pp_t_per_s",v.get("pp",0)),("tg_t_per_s",v.get("tg",0)),
              ("mean_watt_chip",sum(x[1] for x in r)/len(r)),("mwh",wh*1000),
              ("tokens_per_wh",tok/wh if wh else 0),("power_samples",len(r))):
    out.write("%s\t%s\t%s_%s\t%.2f\n" % (sys.argv[5], sys.argv[6], pre, k, val))
print("  %-22s pp=%.1f tg=%.2f %.1f W" % (pre, v.get("pp",0), v.get("tg",0), sum(x[1] for x in r)/len(r)))
PY
  sleep 3
}

sag "--- 1/4 synthetisch (wie llama-bench ueblich laeuft) ---"
bench synth synth -p 2048 -n 128 -r 3

sag "--- 2/4 produktionsnah (q8_0-Cache, gefuellter Kontext) ---"
bench prod prod -p 4096 -n 256 -d 8192 -fa on -ctk q8_0 -ctv q8_0 -r 3

sag "--- 3/4 Kontexttiefe ---"
for t in 0 8192 32768; do bench depth_$t depth_$t -p 2048 -n 128 -d $t -fa on -r 3; done

sag "--- 4/4 Determinismus ---"
# A build that got faster and answers differently is not faster at the same
# thing. The throughput line alone would wave that through.
if frei determinism; then
  h=$(timeout 600 "$PRAEFIX/bin/llama-cli" -m "$GGUF" -ngl 99 -sm none -mg 0 \
        --seed 1234 --temp 0 -n 96 -no-cnv -st --simple-io --no-warmup \
        -p "List the first ten prime numbers." < /dev/null 2>/dev/null \
      | sed -n '/\[Start thinking\]/,/^\[ Prompt:/p' | grep -v '^\[ Prompt:' \
      | sha256sum | cut -c1-16)
  sag "  Ausgabe-Hash: $h"
  ZEILE output_hash "$h"
else ZEILE output_hash SKIPPED_CARD_BUSY; fi

sag "=== fertig: $LAUF/ergebnis.tsv ==="
echo FERTIG_SUITE_$TAG | tee -a "$L"

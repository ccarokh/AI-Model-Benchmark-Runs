#!/bin/bash
# Builds a candidate llama.cpp BESIDE the pinned build and measures both in the
# same session. Recurring, not one-off.
#
#   upstream_drift.sh              # current upstream master
#   upstream_drift.sh v0.2.0       # a specific tag -- what a release actually is
#
# WHY BESIDE, NOT OVER: a second prefix whose binary quietly loads the first
# one's libraries is something we already had here -- all eight resolved into
# the old prefix, and it only came out because the old libraries did not know
# the architecture. That is why the number of libraries that really land in the
# new prefix is counted below, before any number counts.
#
# WHY IN THE SAME SESSION: two numbers from the same hour are a comparison, a
# number from today against one from three weeks ago is not.
#
# WHY THIS SCRIPT REFUSES RATHER THAN REPORTS:
# On 23.08. it produced a full "decision basis" for a build that had never been
# installed. The install had failed, the prefix held zero libraries, every
# number was empty and the output hash was e3b0c442... -- the SHA-256 of nothing.
# All three criteria came out green, because nothing was ever checked against
# anything. A check that cannot fail is not a check. Since then:
#
#   - the build installs or the script exits
#   - a prefix with zero resolved libraries is an abort, not a pass
#   - an empty measurement, a zero throughput or the hash of nothing is an abort
#   - the verdict is COMPUTED and the exit code carries it (0 green, 3 red)
set -u

ZIEL=${1:-origin/master}
PROD=/opt/llama-cpp        # what the production runtime actually starts
ALT=/opt/llama-cpp-nb      # what this repository measures with
SRC=/opt/src/llama.cpp
M=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf
L=/root/eval/upstream_drift.log
LEER_HASH=e3b0c44298fc1c14   # sha256 of an empty stream -- the tell of a build that produced nothing
TOLERANZ=${TOLERANZ:-0.97}   # production-like throughput may not fall below this fraction

# One prefix per candidate, named after it. "latest" as a fixed name made two
# different builds share one directory and one version stamp.
NEU=${NEU:-/opt/llama-cpp-$(printf '%s' "$ZIEL" | sed 's|.*/||; s|[^A-Za-z0-9._-]|_|g')}

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }
kernel_zahl(){ dmesg 2>/dev/null | grep -ciE "amdgpu.*(ring|reset|error)|GPU reset|VRAM is lost" || true; }
KERN0=$(kernel_zahl)

zahl_ok(){ awk -v a="${1:-0}" 'BEGIN{exit !(a+0>0)}'; }

sag "=== Quelle aktualisieren ($ZIEL) ==="
cd $SRC || { sag "kein Quellbaum unter $SRC"; exit 1; }
git fetch --tags --quiet origin 2>>$L
ALT_V=$(cat $ALT/.built-version 2>/dev/null || echo unbekannt)
PROD_V=$(cat $PROD/.built-version 2>/dev/null || echo unbekannt)
# ^{commit}: on an annotated tag rev-parse returns the TAG OBJECT, not the
# commit. v0.2.0 came out as 8a35040e0 while the commit is bb4caa7 -- a version
# stamp that names nothing findable in the history.
NEU_V=$(git rev-parse --short "${ZIEL}^{commit}" 2>/dev/null)
[ -n "$NEU_V" ] || { sag "unbekannte Referenz: $ZIEL"; exit 1; }
sag "produktiv: $PROD_V   gepinnt: $ALT_V   Kandidat: $ZIEL ($NEU_V) -> $NEU"

sag "=== bauen (CPU-Arbeit, ruehrt die Karte nicht an) ==="
git checkout --quiet "$NEU_V" 2>>$L || { sag "checkout fehlgeschlagen"; exit 1; }
# BUILD WHAT IS CONFIGURED. The install step installs everything the
# configuration enabled; building three named targets and then installing the
# whole set aborts on the first binary that was never built. That is how the
# 23.08. run ended up with an empty prefix -- build fine, install not -- and it
# repeated twice while this was being fixed: first on test-tokenizer-0, then on
# llama-batched, then on batched-bench. Tests and examples are switched off
# because we do not want them; everything that stays configured gets built.
# Tools stay on: llama-server is one of them, and a candidate that cannot serve
# cannot become the production build.
# rm -rf on a variable path, one line below a variable the caller can set: the
# candidate prefix must never be able to be the production one.
case "$NEU" in
  "$PROD"|"$ALT"|/|""|/opt|/usr) sag "ABBRUCH: $NEU ist kein zulaessiges Kandidatenpraefix"; exit 1 ;;
esac
rm -rf "$NEU"
cmake -B build-latest -DCMAKE_INSTALL_PREFIX=$NEU -DGGML_VULKAN=ON \
      -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_SERVER=ON -DCMAKE_BUILD_TYPE=Release >>$L 2>&1 \
      || { sag "cmake fehlgeschlagen"; exit 1; }
cmake --build build-latest -j"${JOBS:-12}" >>$L 2>&1 \
      || { sag "Bau fehlgeschlagen"; exit 1; }
cmake --install build-latest >>$L 2>&1 \
      || { sag "Installation fehlgeschlagen -- kein Praefix, keine Messung"; exit 1; }

for b in llama-bench llama-cli llama-server; do
  [ -x "$NEU/bin/$b" ] || { sag "ABBRUCH: $b fehlt im neuen Praefix"; exit 1; }
done

# The probe that would have caught the old mistake.
sag "=== loesen die Bibliotheken ins NEUE Praefix auf? ==="
ges=$(LD_LIBRARY_PATH=$NEU/lib ldd $NEU/bin/llama-bench 2>/dev/null | grep -cE "libllama|libggml")
neu_n=$(LD_LIBRARY_PATH=$NEU/lib ldd $NEU/bin/llama-bench 2>/dev/null | grep -E "libllama|libggml" | grep -c "$NEU/lib")
sag "  $neu_n von $ges im neuen Praefix"
# Zero of zero is not agreement, it is an empty prefix. That case used to pass.
[ "$ges" -gt 0 ] || { sag "  ABBRUCH: keine Bibliotheken gefunden -- das Praefix ist leer"; exit 1; }
[ "$neu_n" -eq "$ges" ] || { sag "  ABBRUCH: Bibliotheken kommen aus dem falschen Praefix"; exit 1; }

# Only now is the stamp true. Writing it right after the build claimed a state
# the prefix did not have.
echo "$NEU_V" > $NEU/.built-version

karte_frei(){
  for i in $(seq 1 90); do
    b=$(pgrep -x llama-bench | wc -l); s=$(pgrep -x llama-server | wc -l)
    vram=$(( $(cat /sys/class/drm/card1/device/mem_info_vram_used) / 1048576 ))
    [ "$vram" -lt 500 ] && [ "$b" -eq 0 ] && [ "$s" -eq 0 ] && return 0
    sleep 20
  done
  return 1
}

bench(){   # $1 = prefix, rest = llama-bench arguments -> "pp tg", empty on failure
  local pfad="$1"; shift
  LD_LIBRARY_PATH=$pfad/lib timeout 1800 "$pfad/bin/llama-bench" -m "$M" "$@" \
      -ngl 99 -sm none -mg 0 -o json 2>/dev/null | python3 -c "
import json, sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(1)
v = {}
for e in d:
    v['tg' if e['n_gen'] and not e['n_prompt'] else 'pp'] = e['avg_ts']
if not v: sys.exit(1)
print('%.2f %.2f' % (v.get('pp', 0), v.get('tg', 0)))"
}

# THIS MEASUREMENT DECIDES WHICH BUILD GOES INTO PRODUCTION.
# Two things follow from that which a pure throughput measurement does not do:
#
#   1. The PRODUCTION build has to run along. It is the state a change gets
#      weighed against -- not our measurement build.
#   2. The PRODUCTION configuration has to be measured too. We documented
#      ourselves that production flags move a result by a factor of 6.8; a
#      recommendation based on synthetic flags would be worthless.
declare -A HASH PP TG KERN LEER
sag "=== Referenzlauf auf ALLEN DREI, gleiche Sitzung ==="
for paar in "$PROD_V $PROD" "$ALT_V $ALT" "$NEU_V $NEU"; do
  set -- $paar; v=$1; pfad=$2
  karte_frei || sag "  $v : WARNUNG Karte wurde nicht frei -- Zahlen sind verdaechtig"
  LEER[$v]=""

  r=$(bench "$pfad" -p 2048 -n 128 -r 3)
  if [ -z "$r" ]; then LEER[$v]="Referenzlauf leer"; sag "  $v : Referenzlauf LEER"
  else sag "  $v : pp2048=$(echo $r | cut -d' ' -f1) tg128=$(echo $r | cut -d' ' -f2)"; fi

  # Same output? A build that got faster and answers differently is not
  # faster at the same thing.
  h=$(LD_LIBRARY_PATH=$pfad/lib timeout 300 "$pfad/bin/llama-cli" -m "$M" -ngl 99 -sm none -mg 0 \
        --seed 1234 --temp 0 -n 96 -no-cnv -st --simple-io --no-warmup \
        -p "List the first ten prime numbers." < /dev/null 2>/dev/null \
      | sed -n '/\[Start thinking\]/,/^\[ Prompt:/p' | grep -v '^\[ Prompt:' | sha256sum | cut -c1-16)
  HASH[$v]=$h
  [ "$h" = "$LEER_HASH" ] && LEER[$v]="${LEER[$v]:+${LEER[$v]}, }Ausgabe leer"
  sag "  $v : Ausgabe-Hash $h$([ "$h" = "$LEER_HASH" ] && echo '  <-- das ist der Hash von NICHTS')"

  # Production-like configuration: quantised KV cache, large context,
  # parallel slots. That is the case being decided on.
  p=$(bench "$pfad" -p 4096 -n 256 -d 8192 -fa on -ctk q8_0 -ctv q8_0 -r 3)
  if [ -z "$p" ]; then
    LEER[$v]="${LEER[$v]:+${LEER[$v]}, }produktionsnaher Lauf leer"; sag "  $v : produktionsnah LEER"
  else
    PP[$v]=$(echo $p | cut -d' ' -f1); TG[$v]=$(echo $p | cut -d' ' -f2)
    sag "  $v : produktionsnah  pp4096@d8192=${PP[$v]} tg256=${TG[$v]}"
  fi

  # A build that got faster while resetting the card is not a candidate. A
  # throughput test alone would wave that through.
  # A DELTA against the start of the run, not the tail of dmesg. Counting the
  # last 200 lines counts what happened last night: after the card ran out of
  # VRAM at 23:23 -- two consumers on it at once, because a service restart had
  # dropped the lease -- every check afterwards reported "115 kernel messages"
  # and went red for an event it had nothing to do with, until dmesg rotated.
  KERN[$v]=$(( $(kernel_zahl) - KERN0 ))
  sag "  $v : Kernelmeldungen ${KERN[$v]}"
done

# The verdict is computed, not asserted. Every criterion prints its own answer,
# so a red one names itself instead of hiding in a sentence.
sag "=== ENTSCHEIDUNGSGRUNDLAGE ($NEU_V gegen Produktivstand $PROD_V) ==="
rot=""
pruefe(){ # $1 = criterion, $2 = ok?, $3 = detail
  if [ "$2" = "ja" ]; then sag "  JA   $1${3:+  ($3)}"
  else sag "  NEIN $1${3:+  ($3)}"; rot="${rot:+$rot; }$1"; fi
}

# A comparison needs two different states. Production was replaced by the
# candidate WHILE this check was being repaired on 23.08., and the run then
# compared v0.2.0 against v0.2.0 and reported every criterion green. Identical
# is not the same as verified.
PROD_BIN=$(md5sum "$PROD/bin/llama-server" 2>/dev/null | cut -d' ' -f1)
NEU_BIN=$(md5sum "$NEU/bin/llama-server" 2>/dev/null | cut -d' ' -f1)
if [ "$PROD_V" = "$NEU_V" ] || [ "$PROD_V" = "$ZIEL" ] || [ "$PROD_BIN" = "$NEU_BIN" ]; then
  pruefe "Produktivstand ist ein ANDERER Stand als der Kandidat" nein \
         "produktiv meldet '$PROD_V' -- gegen sich selbst geprueft heisst nichts"
else
  pruefe "Produktivstand ist ein ANDERER Stand als der Kandidat" ja "$PROD_V"
fi
if [ -n "${LEER[$NEU_V]:-}" ]; then
  pruefe "Kandidat hat ueberhaupt gemessen" nein "${LEER[$NEU_V]}"
else
  pruefe "Kandidat hat ueberhaupt gemessen" ja
fi
if [ -n "${LEER[$PROD_V]:-}" ]; then
  pruefe "Produktivstand hat gemessen (Vergleichsbasis)" nein "${LEER[$PROD_V]}"
else
  pruefe "Produktivstand hat gemessen (Vergleichsbasis)" ja
fi
# Against BOTH other builds, not only production: if production has already
# been swapped, the pinned measurement build is the only honest reference left.
for gegen in "$PROD_V" "$ALT_V"; do
  [ "$gegen" = "$NEU_V" ] && continue
  [ "${HASH[$NEU_V]}" = "${HASH[$gegen]}" ] \
    && pruefe "Ausgabe-Hash identisch zu $gegen" ja "${HASH[$NEU_V]}" \
    || pruefe "Ausgabe-Hash identisch zu $gegen" nein "${HASH[$NEU_V]} statt ${HASH[$gegen]}"
done
[ "${KERN[$NEU_V]}" -eq 0 ] \
  && pruefe "keine Kernelmeldungen" ja \
  || pruefe "keine Kernelmeldungen" nein "${KERN[$NEU_V]} Zeilen"
for feld in PP TG; do
  eval "a=\${$feld[\$NEU_V]:-}"; eval "b=\${$feld[\$PROD_V]:-}"
  if zahl_ok "$a" && zahl_ok "$b" && awk -v a="$a" -v b="$b" -v t="$TOLERANZ" 'BEGIN{exit !(a >= b*t)}'; then
    pruefe "produktionsnah $feld nicht schlechter" ja "$a gegen $b"
  else
    pruefe "produktionsnah $feld nicht schlechter" nein "$a gegen $b"
  fi
done

if [ -z "$rot" ]; then
  sag "GRUEN: der Wechsel auf $ZIEL ($NEU_V) ist belegt. Die Entscheidung trifft der Betreiber."
  sag "=== DRIFT-PRUEFUNG DURCH ==="
  echo FERTIG_DRIFT | tee -a $L
  exit 0
fi
sag "ROT: kein Wechsel. Offen: $rot"
sag "=== DRIFT-PRUEFUNG DURCH ==="
echo FERTIG_DRIFT | tee -a $L
exit 3

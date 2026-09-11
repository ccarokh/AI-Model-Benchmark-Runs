#!/bin/bash
# Does a new llama.cpp change anything? One model per architecture, every night.
#
# WHY NOT THE EXISTING DRIFT CHECK. That one measures qwen3.5-9b and nothing
# else. A commit titled "qwen4exp: reduce number of graph splits" touches an
# architecture that model does not use, so the check cannot see it however many
# nights it runs. Seventeen runs said "nothing changed" about a code path they
# never executed.
#
# So: one model per architecture family present on this machine, the smallest of
# each, on every build that knows that architecture. Short workload -- this
# answers "did it move", not "how fast is it".
#
# Every row carries the build, the architecture and an output hash. A change in
# speed shows in the numbers; a change in BEHAVIOUR shows in the hash, and that
# is the one worth waking up for.
set -u
# One instance at a time. Two runs of this on one card happened twice while it
# was being built, and the second one silently measured against the first. A
# lock is cheaper than remembering.
exec 9>/run/versionswacht.lock
flock -n 9 || { echo "  laeuft bereits -- abgebrochen"; exit 0; }

OUT=${OUT:-/root/eval/versionswacht.tsv}
M=/opt/llm-infra/models
HEUTE=$(date +%Y-%m-%d)
[ -s "$OUT" ] || printf "datum\tbuild\tversion\tarch\tmodel\tpp\ttg\thash\n" > "$OUT"

# Smallest model per architecture. Deliberately not the biggest: this runs every
# night and has to stay short.
# One model per architecture -- plus qwen3.8-27b by name: it carries a standing
# verdict (coding: 19 min per task) that a faster build would have to overturn.
KANDIDATEN=${KANDIDATEN:-"
qwen2:qwen2.5-coder-14b
qwen3:qwen3
qwen3moe:qwen3-30b-a3b
qwen35:qwen3.5-9b
qwen35:qwen3.8-27b
qwen35moe:ornith-35b
qwen3next:qwen3-coder-next
qwen4exp:qwen3.8-flash-next
gemma4:gemma-4-12b-it
granite:granite-4.2-30b
bailingmoe3:ling-3.0-tiny
nemotron_h_moe:nemotron-3.5-lightning-30b-a3b
"}

BUILDS=""
for b in /opt/llama-cpp /opt/llama-cpp-nb /opt/llama-cpp-master /opt/llama-cpp-latest; do
  [ -x "$b/bin/llama-bench" ] && BUILDS="$BUILDS $b"
done

for eintrag in $KANDIDATEN; do
  arch=${eintrag%%:*}; name=${eintrag##*:}
  g=$(ls $M/$name/*.gguf 2>/dev/null | grep -v mmproj | sort | head -1)
  [ -z "$g" ] && continue
  for b in $BUILDS; do
    v=$(cat $b/.built-version 2>/dev/null || echo unbekannt)
    # Skip builds that do not know this architecture -- an unsupported model is
    # not a regression, and recording it as one buries the real ones.
    strings $b/lib/libllama.so 2>/dev/null | grep -Fxq "$arch" || continue
    cut -f1,3,5 "$OUT" | grep -qx "$HEUTE	$v	$name" && continue
    export LD_LIBRARY_PATH=$b/lib
    j=$(timeout 900 $b/bin/llama-bench -m "$g" -p 512 -n 128 -r 2 -ngl 99 \
          -sm none -mg 0 -o json 2>/dev/null)
    if [ -z "$j" ]; then
      printf "%s\t%s\t%s\t%s\t%s\t\t\tKEINE_MESSUNG\n" "$HEUTE" "$b" "$v" "$arch" "$name" >> "$OUT"
      echo "  $name auf $v: KEINE MESSUNG"; continue
    fi
    read -r pp tg <<< "$(printf '%s' "$j" | python3 -c "
import json,sys
d=json.load(sys.stdin); w={}
for e in d: w['pp' if e['n_prompt'] else 'tg']=e['avg_ts']
print('%.2f %.2f' % (w.get('pp',0), w.get('tg',0)))")"
    # Behaviour, not just speed. Fixed seed, greedy, one fresh process.
    # Exactly the invocation the drift check has used successfully for weeks.
    # The decisive part is `< /dev/null`: without a stdin stream llama-cli waits
    # for input instead of exiting, and -no-cnv alone does not change that.
    h=$(timeout 300 $b/bin/llama-cli -m "$g" -ngl 99 -sm none -mg 0 \
          --seed 1234 --temp 0 -n 96 --ctx-size 4096 \
          -p "List the first ten prime numbers." < /dev/null 2>/dev/null \
        | sha256sum | cut -c1-16)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$HEUTE" "$b" "$v" "$arch" "$name" "$pp" "$tg" "$h" >> "$OUT"
    echo "  $name auf $v: pp=$pp tg=$tg hash=$h"
  done
done
# --- Die Karten zusammen, nicht nur einzeln ---------------------------------
# Everything above pins one card, so an improvement in splitting across both
# would never show. But "capacity, not speed -- tensor split is unusable" is one
# of this machine\'s recorded limits, and upstream fixing it is exactly the kind
# of change worth waking up for.
#
# Same model, same workload, three placements: one card, layer split, tensor
# split. The last one is expected to fail or crawl; the day it does not is the
# day something changed.
MGPU_MODELL=${MGPU_MODELL:-qwen3.5-9b}
g=$(ls $M/$MGPU_MODELL/*.gguf 2>/dev/null | grep -v mmproj | sort | head -1)
if [ -n "$g" ]; then
  for b in $BUILDS; do
    v=$(cat $b/.built-version 2>/dev/null || echo unbekannt)
    export LD_LIBRARY_PATH=$b/lib
    for split in "none:0" "layer:-" "tensor:-"; do
      art=${split%%:*}; karte=${split##*:}
      cut -f1,3,5 "$OUT" | grep -qx "$HEUTE	$v	mgpu-$art" && continue
      if [ "$karte" = 0 ]; then flags="-sm none -mg 0"; else flags="-sm $art"; fi
      j=$(timeout 900 $b/bin/llama-bench -m "$g" -p 512 -n 128 -r 2 -ngl 99 $flags -o json 2>/dev/null)
      if [ -z "$j" ]; then
        printf "%s\t%s\t%s\t%s\t%s\t\t\tKEINE_MESSUNG\n" "$HEUTE" "$b" "$v" "mgpu" "mgpu-$art" >> "$OUT"
        echo "  mgpu $art auf $v: KEINE MESSUNG"; continue
      fi
      read -r pp tg <<< "$(printf '%s' "$j" | python3 -c "
import json,sys
d=json.load(sys.stdin); w={}
for e in d: w['pp' if e['n_prompt'] else 'tg']=e['avg_ts']
print('%.2f %.2f' % (w.get('pp',0), w.get('tg',0)))")"
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t-\n" "$HEUTE" "$b" "$v" "mgpu" "mgpu-$art" "$pp" "$tg" >> "$OUT"
      echo "  mgpu $art auf $v: pp=$pp tg=$tg"
    done
  done
fi

echo FERTIG_VERSIONSWACHT

#!/bin/bash
# What does a gigabyte cost when it is not on the card?
#
# Sweeps --n-cpu-moe from 0 upwards on MoE models that already sit on this
# machine, and records generation and prefill against how many layers of expert
# weights were pushed into host memory. No purchase, no download: the question
# that decides whether more memory bandwidth is worth buying can be answered
# with what is here.
#
# WHY BOTH PHASES. Prefill is compute-bound, generation bandwidth-bound. The
# prediction on record is that the split costs generation several times what it
# costs prefill. If both fall equally, the mechanism is not what we think.
#
# The card is pinned (-sm none -mg 0) like every other measurement here -- an
# unpinned run measures whatever the backend picked.
set -u
BUILD=${BUILD:-/opt/llama-cpp-nb}
OUT=${OUT:-/root/eval/tierkurve.tsv}
M=/opt/llm-infra/models
export LD_LIBRARY_PATH=$BUILD/lib
[ -s "$OUT" ] || printf "model\tbuild\tncmoe\tpp_t_per_s\ttg_t_per_s\tvram_mib\tseconds\n" > "$OUT"

# 0 is the reference: everything on the card.
STUFEN="0 4 8 12 16 24 32 48"

for name in qwen3-30b-a3b gpt-oss-20b qwen3.6-35b-a3b; do
  g=$(ls $M/$name/*.gguf 2>/dev/null | head -1)
  [ -z "$g" ] && { echo "$name: keine Datei"; continue; }
  for n in $STUFEN; do
    cut -f1,3 "$OUT" | grep -qx "$name	$n" && { echo "  $name ncmoe=$n: liegt vor"; continue; }
    t0=$(date +%s)
    j=$(timeout 1800 $BUILD/bin/llama-bench -m "$g" -p 512 -n 128 -r 2 -ngl 99 \
          -sm none -mg 0 -ncmoe $n -o json 2>/dev/null)
    s=$(( $(date +%s) - t0 ))
    if [ -z "$j" ]; then
      printf "%s\t%s\t%s\t\t\t\t%s\n" "$name" "$(cat $BUILD/.built-version)" "$n" "$s" >> "$OUT"
      echo "  $name ncmoe=$n: KEINE MESSUNG nach ${s}s"; continue
    fi
    v=$(( $(cat /sys/class/drm/card1/device/mem_info_vram_used)/1048576 ))
    printf '%s' "$j" | python3 -c "
import json,sys
d=json.load(sys.stdin); w={}
for e in d: w['pp' if e['n_prompt'] else 'tg']=e['avg_ts']
print('%.2f\t%.2f' % (w.get('pp',0), w.get('tg',0)))
" | while IFS=$'\t' read -r pp tg; do
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$(cat $BUILD/.built-version)" "$n" "$pp" "$tg" "$v" "$s" >> "$OUT"
      echo "  $name ncmoe=$n: pp=$pp tg=$tg  (${s}s)"
    done
  done
done
echo FERTIG_TIERKURVE

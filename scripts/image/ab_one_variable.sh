#!/bin/bash
# A/B fuer Chroma: Schrittzahl und cfg, alles andere fest.
#
# Warum genau hier: Chroma ist das einzige Modell, das die Textaufgabe loest
# (Editabstand 0, Apache-2.0). Seine drei Ausfaelle -- plastikhaft bei 04 und 08,
# Rasterfell bei 07 -- koennten Parameter sein statt Modell. Die Quantisierung
# ist bereits ausgeschlossen (Q4_0 und Q8_0 identisch).
# Gleicher Seed, gleicher Prompt, eine Variable je Lauf.
set -u
OUT=/opt/out/ab; mkdir -p $OUT
B=/opt/models; F=$B/flux1-schnell; M=$B/chroma1-hd/Chroma1-HD-Q4_0.gguf
D=/sys/class/drm/card1/device
declare -A P
P[8_pferd]="A brown horse trotting in a sandy paddock, full body side view, all four legs visible, dust in the air, photograph"
P[7_katze]="A tabby cat sitting on a wooden windowsill looking outside, soft afternoon light, sharp fur detail, photograph"
warte(){ for i in $(seq 1 300); do v=$(( $(cat $D/mem_info_vram_used)/1048576 )); f=$(pgrep -x llama-server|wc -l)
  [ "$v" -lt 500 ] && [ "$f" -eq 0 ] && return 0; sleep 10; done; return 1; }
lauf(){ # $1=aufgabe $2=steps $3=cfg
  local a=$1 s=$2 c=$3 name="chroma_s${2}_c${3}_${1}"
  warte || { echo "$name: Karte belegt"; return 1; }
  local t0=$(date +%s.%N)
  /opt/sd-cpp/bin/sd-cli --diffusion-model $M --vae $F/ae.safetensors --t5xxl $F/t5xxl_fp8.safetensors \
    --cfg-scale $c --steps $s -p "${P[$a]}" -W 1024 -H 1024 --seed 42 \
    -o $OUT/$name.png > $OUT/$name.log 2>&1
  local rc=$? t1=$(date +%s.%N)
  [ $rc -eq 0 ] && printf "%-34s %6.1fs\n" "$name" "$(echo "$t1 - $t0"|bc)" \
    || { echo "$name: FEHLER rc=$rc"; grep -i -m1 -E "error|abort|DeviceLost" $OUT/$name.log; }
  sleep 2
}
for a in 8_pferd 7_katze; do
  echo "=== $a: Schrittzahl bei cfg 4.0"
  for s in 8 14 28; do lauf $a $s 4.0; done
  echo "=== $a: cfg bei 20 Schritten"
  for c in 2.5 5.5; do lauf $a 20 $c; done
done
echo FERTIG_AB

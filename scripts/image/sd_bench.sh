#!/bin/bash
# Runde 2: Chroma, SD 3.5 Medium, RealVisXL -- dieselben acht Aufgaben,
# gleicher Seed, 1024x1024. Kartenwaechter VOR JEDEM BILD (siehe 07.08.:
# drei ErrorDeviceLost, weil der stuendliche Health-Check dazwischenkam).
set -u
OUT=/opt/out
B=/opt/models
F=$B/flux1-schnell
D=/sys/class/drm/card1/device
SEED=42
GRENZE=500

declare -A P
P[1_arbeitsszene]="A worker in full protective equipment, helmet and safety harness and respirator, climbing through a manhole into a confined industrial tank, documentary photograph, natural light"
P[2_deutscher_text]="A yellow industrial warning sign mounted on a concrete wall, large bold black text reading ACHTUNG BEHAELTER, photorealistic, sharp"
P[3_piktogramm]="A flat minimalist vector icon of a lightbulb, single solid color, centered on plain white background, no shading, no gradient"
P[4_haende]="Close-up of a technician hands holding a torque wrench, tightening a bolt on a steel flange, sharp focus on the hands, workshop"
P[5_schema]="A clean technical schematic diagram of a two stage water filtration system, labeled boxes connected by arrows, line art on white background"
P[6_hund]="A German Shepherd dog running across a green meadow towards the camera, full body, all four legs visible, fur detail, natural daylight, photograph"
P[7_katze]="A tabby cat sitting on a wooden windowsill looking outside, soft afternoon light, sharp fur detail, photograph"
P[8_pferd]="A brown horse trotting in a sandy paddock, full body side view, all four legs visible, dust in the air, photograph"

warte() {
  for i in $(seq 1 300); do
    local v=$(( $(cat $D/mem_info_vram_used) / 1048576 ))
    local fremd=$(pgrep -x llama-server | wc -l)
    [ "$v" -lt "$GRENZE" ] && [ "$fremd" -eq 0 ] && return 0
    [ $((i % 18)) -eq 1 ] && echo "    warte: $v MiB, $fremd Fremdprozess(e)"
    sleep 10
  done
  return 1
}

erzeuge() {  # $1=modellname $2=aufgabe
  local n="$1" a="$2"
  case $n in
    chroma) ARGS=(--diffusion-model $B/chroma1-hd/Chroma1-HD-Q4_0.gguf
                  --vae $F/ae.safetensors --t5xxl $F/t5xxl_fp8.safetensors
                  --cfg-scale 4.0 --steps 20) ;;
    sd35)   ARGS=(--diffusion-model $B/sd3.5-medium/sd3.5_medium-Q4_K_M.gguf
                  --vae $F/ae.safetensors --clip_l $F/clip_l.safetensors
                  --clip_g $B/sd3.5-medium/clip_g.safetensors --t5xxl $F/t5xxl_fp8.safetensors
                  --cfg-scale 4.5 --steps 28) ;;
    realvis) ARGS=(-m $B/realvisxl-v5/RealVisXL_V5.0_fp16.safetensors
                  --cfg-scale 7.0 --steps 25) ;;
  esac
  /opt/sd-cpp/bin/sd-cli "${ARGS[@]}" -p "${P[$a]}" -W 1024 -H 1024 --seed $SEED \
    -o $OUT/${n}_${a}.png > $OUT/${n}_${a}.log 2>&1
}

for n in chroma sd35 realvis; do
  echo "===== $n"
  for a in 1_arbeitsszene 2_deutscher_text 3_piktogramm 4_haende 5_schema 6_hund 7_katze 8_pferd; do
    warte || { echo "  ABBRUCH: Karte bleibt belegt"; exit 1; }
    t0=$(date +%s.%N); erzeuge $n $a; rc=$?; t1=$(date +%s.%N)
    d=$(echo "$t1 - $t0" | bc)
    if [ $rc -ne 0 ] || [ ! -s $OUT/${n}_${a}.png ]; then
      echo "  $a: FEHLGESCHLAGEN rc=$rc -- kein Messwert"
      grep -i -m1 -E "DeviceLost|error|abort|unsupported|unknown" $OUT/${n}_${a}.log
    else
      vram=$(grep -oE "total params memory size = [0-9.]+" $OUT/${n}_${a}.log | grep -oE "[0-9.]+" | head -1)
      printf "%s\t%s\t%.1f\t0\t%s\t%s_%s.png\n" "$n" "$a" "$d" "${vram:-0}" "$n" "$a" >> $OUT/messung.tsv
      echo "  $a: ${d}s"
    fi
    sleep 2
  done
done
echo FERTIG_RUNDE2

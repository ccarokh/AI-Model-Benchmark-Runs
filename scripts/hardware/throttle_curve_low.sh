#!/bin/bash
# Drosselkurve unterhalb 159 W fortsetzen.
#
# Die vorhandene Kurve in hardware/power.md endet bei 1600 MHz / 159 W, weil das
# die niedrigste damals probierte Stufe war -- nicht weil dort etwas aufhoerte.
# Gleiche Last wie die vorhandene Kurve (Qwen3.5-9B, -p 2048 -n 128 -r 3), damit
# die neuen Zeilen an die alten anschliessen und nicht daneben stehen.
#
# Stock-Messungen zwischengeschoben: waermt sich die Karte oder driftet der
# Treiber ueber die Stunden, faellt das an den Stock-Zeilen auf und nicht erst
# als scheinbarer Effekt in den gedrosselten.
set -u
OUT=/root/drossel_tief; mkdir -p $OUT
D=/sys/class/drm/card1/device
HW=$(echo $D/hwmon/hwmon*/ | cut -d" " -f1)
W=$HW/power1_average
BIN=/opt/llama-cpp-nb/bin/llama-bench
export LD_LIBRARY_PATH=/opt/llama-cpp-nb/lib
MODELL=/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf

zurueck(){
  echo r > $D/pp_od_clk_voltage 2>/dev/null
  echo c > $D/pp_od_clk_voltage 2>/dev/null
  echo auto > $D/power_dpm_force_performance_level 2>/dev/null
  echo 291000000 > $HW/power1_cap 2>/dev/null
}
# Die Karte darf unter keinen Umstaenden gedrosselt zurueckbleiben, auch nicht
# wenn das Skript abgeschossen wird oder mittendrin stirbt.
trap zurueck EXIT INT TERM

warte(){ for i in $(seq 1 180); do
    v=$(( $(cat $D/mem_info_vram_used)/1048576 )); f=$(pgrep -x llama-server|wc -l)
    [ "$v" -lt 500 ] && [ "$f" -eq 0 ] && return 0; sleep 10
  done; return 1; }

setzen(){ # $1 = Taktdeckel in MHz, oder "stock"
  if [ "$1" = stock ]; then zurueck; sleep 5; return; fi
  echo 261000000 > $HW/power1_cap
  echo manual > $D/power_dpm_force_performance_level
  echo "s 1 $1" > $D/pp_od_clk_voltage
  echo c > $D/pp_od_clk_voltage
  sleep 5
}

messen(){ # $1 = Stufe
  local s=$1
  warte || { echo "$s: Karte belegt, uebersprungen"; return; }
  setzen "$s"
  local vorher=$(dmesg | wc -l)
  : > $OUT/${s}.watt
  ( while true; do echo "$(date +%s.%N) $(cat $W)"; sleep 1; done ) > $OUT/${s}.watt &
  local sp=$!
  # -r 3 und diese Flags exakt wie die vorhandene Kurve. Eine Variable aendern,
  # sonst wird ein Setup mit einem anderen verglichen statt Stufe mit Stufe.
  $BIN -m $MODELL -p 2048 -n 128 -r 3 -ngl 99 -sm none -mg 0 -o json \
       > $OUT/${s}.json 2> $OUT/${s}.log
  local rc=$?
  kill $sp 2>/dev/null
  local sclk=$(grep -oP '^\d+: \K\d+(?=Mhz \*)' $D/pp_dpm_sclk 2>/dev/null | tail -1)
  # Ein Durchsatztest laeuft auch auf einer Karte durch, die sich schon
  # zurueckgesetzt hat -- deshalb das Kernel-Log mitlesen.
  # Anchored on purpose. A bare "ring" matches Registering, buffering and
  # Keyring, and a bare "reset" matches half the boot log -- a health check that
  # cries wolf gets ignored, which is worse than not having one.
  local neu=$(dmesg | tail -n +$((vorher+1)) \
    | grep -ciE "amdgpu.*(ring|reset|error)|GPU reset|VM_L2|VRAM is lost|ring [a-z_]+ timeout" || true)
  if [ $rc -ne 0 ]; then echo "$s: FEHLER rc=$rc"; return; fi
  python3 - $OUT/${s}.watt $OUT/${s}.json "$s" "$sclk" "$neu" <<'PY'
import sys, json
w=[(float(a),int(b)/1e6) for a,b in (l.split() for l in open(sys.argv[1]) if l.strip())]
d=json.load(open(sys.argv[2]))
c=sum(sum(e["samples_ns"]) for e in d)/1e9
r=[x for x in w if x[0]>=w[-1][0]-c] or w
mw=sum(x[1] for x in r)/len(r); pk=max(x[1] for x in r)
v={ (e["n_prompt"] and "pp" or "tg"): e["avg_ts"] for e in d }
print(f"{sys.argv[3]:<8} pp2048={v.get('pp',0):8.1f}  tg128={v.get('tg',0):7.2f}  "
      f"{mw:6.1f} W mittel  {pk:6.1f} W Spitze  SCLK={sys.argv[4]}  "
      f"kernel={sys.argv[5]}  n={len(r)}")
PY
  sleep 5
}

echo "Start $(date -Is)"
for s in stock 1400 stock 1200 1000 stock 800 stock; do messen $s; done
echo FERTIG_DROSSEL

#!/bin/bash
# Runs after the belebele arms: the repeat pass over the speculative variants.
# Two things on one card measure each other, so this waits rather than starts.
set -u
L=/root/kette_101.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }
sag "=== waiting for the quality run ==="
while pgrep -f "[q]ualitaet_101.sh" >/dev/null; do sleep 60; done
sag "quality run done"
cd /root/testbench || exit 1
M=$(find /opt/mess/models -name "*.gguf" ! -name "*mmproj*" ! -name "*mtp-*" | sort | tr "\n" " ")
sag "=== repeat pass over the speculative variants ==="
TESTBENCH_MODELS="$M" python3 run_all.py speculative >> $L 2>&1
sag "=== done ==="

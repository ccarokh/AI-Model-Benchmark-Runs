#!/bin/bash
# How many users first, then the rest of the speculative matrix.
set -u
L=/root/kette_26aug.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }
cd /root/testbench || exit 1
M=$(find /opt/mess/models -name "*.gguf" ! -name "*mmproj*" ! -name "*mtp-*" | sort | tr "\n" " ")
sag "=== concurrency over $(echo $M | wc -w) models ==="
TESTBENCH_MODELS="$M" python3 run_all.py concurrency >> $L 2>&1
sag "=== speculative, continuing where it stopped ==="
TESTBENCH_MODELS="$M" python3 run_all.py speculative >> $L 2>&1
sag "=== done ==="

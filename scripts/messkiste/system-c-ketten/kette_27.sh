#!/bin/bash
# The serving questions, over everything on the card.
set -u
L=/root/kette_27aug.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }
cd /root/testbench || exit 1
M=$(find /opt/mess/models -name "*.gguf" ! -name "*mmproj*" ! -name "*mtp-*" | sort | tr "\n" " ")
for t in slot_restore concurrency context_split speculative; do
  sag "=== $t ==="
  TESTBENCH_MODELS="$M" python3 run_all.py $t >> $L 2>&1
done
sag "=== done ==="

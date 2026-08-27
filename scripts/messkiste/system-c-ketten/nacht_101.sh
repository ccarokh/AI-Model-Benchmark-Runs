#!/bin/bash
# Chain the night on System C: finish the downloads, then measure -- with no
# human step in between. Twice today this machine sat idle for hours because
# something finished and nothing followed it.
set -u
L=/root/nacht_101.log
sag(){ echo "[$(date "+%H:%M:%S")] $*" >> $L; }

sag "=== warte auf die Downloads ==="
while pgrep -f "[h]ole_modelle.sh" >/dev/null; do sleep 30; done
sag "Downloads durch:"
ls -1 /opt/mess/models/*/ -d 2>/dev/null | sed "s|^|  |" >> $L

# The Q4_K_M arm of the same model: without it the comparison has the QAT
# recipe and the Q4_0 format tangled together and cannot say which did what.
B=/opt/mess/models; G=https://huggingface.co
if [ ! -s "$B/gemma-4-12b-q4km/gemma-4-12B-it-Q4_K_M.gguf" ]; then
  sag "hole den Q4_K_M-Arm"
  mkdir -p $B/gemma-4-12b-q4km
  curl -fsL --retry 3 -o $B/gemma-4-12b-q4km/f.teil \
    $G/bartowski/gemma-4-12B-it-GGUF/resolve/main/gemma-4-12B-it-Q4_K_M.gguf \
    && head -c 4 $B/gemma-4-12b-q4km/f.teil | grep -q GGUF \
    && mv $B/gemma-4-12b-q4km/f.teil $B/gemma-4-12b-q4km/gemma-4-12B-it-Q4_K_M.gguf \
    && sag "  Q4_K_M da" || sag "  Q4_K_M FEHLGESCHLAGEN"
fi

# Every gguf in the store, so the suite decides what is new -- not me.
cd /root/testbench || exit 1
M=$(find /opt/mess/models -name "*.gguf" ! -name "*mmproj*" ! -name "*mtp-*" | sort | tr "\n" " ")
sag "=== testbench ueber $(echo $M | wc -w) Modelle ==="
TESTBENCH_MODELS="$M" python3 run_all.py >> $L 2>&1
sag "=== testbench durch ==="

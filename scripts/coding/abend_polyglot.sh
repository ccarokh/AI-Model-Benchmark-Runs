#!/bin/bash
# Polyglot in evening windows instead of in one 70-hour block.
#
# WHY PIECEWISE: Qwen3.8-27B needs 19 min per task, so the full set takes about
# 70 hours. In one piece that blocks the card for everything else -- vision,
# throttle curve, chunk curve and reranker failed on that three times over. The
# statement "too slow" already stands anyway; only the exact rate is missing.
#
# RESUMABLE: aider's benchmark.py resumes into an existing directory if you pass
# it as DIRNAME and OMIT --new. Tasks already done get skipped. --num-tests caps
# the session.
#
# Called from cron, e.g. 20:00. Runs until the window ends or until finished.
set -uo pipefail
LOG=/root/bench/abend_polyglot.log
LAUF=2026-08-17-22-45-39--qwen3.8-27b-nothink-slot32k-diff
BASIS=/root/coding-eval/aider/tmp.benchmarks
Q38=/opt/llm-infra/models/qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf
ENDE_STD=${ENDE_STD:-7}        # bis 07:00 des Folgetags
PRO_SITZUNG=${PRO_SITZUNG:-30} # Aufgaben je Fenster

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $LOG; }

fertig(){ find "$BASIS/$LAUF" -name ".aider.results.json" 2>/dev/null | wc -l; }

# Do not start if someone else needs the card. The whole point of this chain is
# NOT to be in the way -- so it gives up without a fight instead of waiting.
belegt=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${MESSRECHNER:?MESSRECHNER ist nicht gesetzt, z.B. root@10.0.0.2}" \
  'v=$(( $(cat /sys/class/drm/card1/device/mem_info_vram_used)/1048576 )); \
   b=$(pgrep -x llama-bench|wc -l); [ $v -lt 500 ] && [ $b -eq 0 ] && echo nein || echo ja' 2>/dev/null)
if [ "$belegt" != nein ]; then
  sag "Karte belegt ($belegt) -- dieses Fenster ausgelassen, kein Warten"
  exit 0
fi

n0=$(fertig)
if [ "$n0" -ge 225 ]; then sag "bereits vollstaendig ($n0/225)"; exit 0; fi
sag "Fenster auf. Stand $n0/225, hole bis zu $PRO_SITZUNG Aufgaben"

# Time limit from the end of the window: 19 min per task is measured, but the
# window is the hard boundary, not the estimate.
jetzt=$(date +%s)
ende=$(date -d "today $ENDE_STD:00" +%s)
[ "$ende" -le "$jetzt" ] && ende=$(date -d "tomorrow $ENDE_STD:00" +%s)
sek=$(( ende - jetzt - 600 ))
[ "$sek" -lt 1800 ] && { sag "Fenster zu kurz ($sek s) -- ausgelassen"; exit 0; }

/root/coding-eval/orchestrate_resume.sh "$LAUF" "$Q38" "$PRO_SITZUNG" "$sek" >> $LOG 2>&1
rc=$?
n1=$(fertig)
sag "Fenster zu. rc=$rc, Stand $n1/225 (+$(( n1 - n0 )) in dieser Sitzung)"
[ "$n1" -ge 225 ] && sag "VOLLSTAENDIG -- Auswertung faellig"

#!/bin/bash
# Polyglot in Abendfenstern statt in einem 70-Stunden-Block.
#
# WARUM STUECKWEISE: Qwen3.8-27B braucht 19 min je Aufgabe, der volle Satz also
# rund 70 Stunden. Am Stueck blockiert das die Karte fuer alles andere -- Vision,
# Drosselkurve, Chunk-Kurve und Reranker sind daran dreimal ausgefallen. Die
# Aussage "zu langsam" steht ohnehin schon; es fehlt nur die exakte Quote.
#
# FORTSETZBAR: aiders benchmark.py setzt in ein bestehendes Verzeichnis fort,
# wenn man es als DIRNAME uebergibt und --new WEGLAESST. Bereits erledigte
# Aufgaben werden uebersprungen. --num-tests deckelt die Sitzung.
#
# Aufruf per cron, z.B. 20:00. Laeuft bis zum Fensterende oder bis fertig.
set -uo pipefail
LOG=/root/bench/abend_polyglot.log
LAUF=2026-08-17-22-45-39--qwen3.8-27b-nothink-slot32k-diff
BASIS=/root/coding-eval/aider/tmp.benchmarks
Q38=/opt/llm-infra/models/qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf
ENDE_STD=${ENDE_STD:-7}        # bis 07:00 des Folgetags
PRO_SITZUNG=${PRO_SITZUNG:-30} # Aufgaben je Fenster

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $LOG; }

fertig(){ find "$BASIS/$LAUF" -name ".aider.results.json" 2>/dev/null | wc -l; }

# Nicht starten, wenn jemand anders die Karte braucht. Der Sinn dieser Kette ist
# gerade, NICHT im Weg zu stehen -- also gibt sie kampflos auf statt zu warten.
belegt=$(ssh -o BatchMode=yes -o ConnectTimeout=10 root@192.168.40.192 \
  'v=$(( $(cat /sys/class/drm/card1/device/mem_info_vram_used)/1048576 )); \
   b=$(pgrep -x llama-bench|wc -l); [ $v -lt 500 ] && [ $b -eq 0 ] && echo nein || echo ja' 2>/dev/null)
if [ "$belegt" != nein ]; then
  sag "Karte belegt ($belegt) -- dieses Fenster ausgelassen, kein Warten"
  exit 0
fi

n0=$(fertig)
if [ "$n0" -ge 225 ]; then sag "bereits vollstaendig ($n0/225)"; exit 0; fi
sag "Fenster auf. Stand $n0/225, hole bis zu $PRO_SITZUNG Aufgaben"

# Zeitlimit aus dem Fensterende: 19 min je Aufgabe sind gemessen, aber das
# Fenster ist die harte Grenze, nicht die Schaetzung.
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

#!/bin/bash
# Ein Abendfenster polyglot: Server holen, N Aufgaben fortsetzen, Server zurueck.
# Aufruf: orchestrate_resume.sh <datiertes-verzeichnis> <gguf> <num-tests> <timeout-sek>
H=root@192.168.40.192
DIR="$1"; GGUF="$2"; NT="${3:-30}"; TMO="${4:-36000}"; PORT=8181
source /root/coding-eval/kartenwacht.sh
kw_karte_sichern "abend-polyglot" 600 || { echo "[$(date +%H:%M)] Karte nicht zu bekommen"; exit 1; }
# A q8_0 cache is not optional at ctx 131072 -- see orchestrate_slot32k.sh.
kw_server_starten "-m '$GGUF' --host 0.0.0.0 --port $PORT --device Vulkan0 --ctx-size 131072 --batch-size 512 --ubatch-size 512 -ngl 99 --parallel 4 --cache-type-k q8_0 --cache-type-v q8_0 --jinja" /tmp/srv_abend.log || exit 1
kw_wache_starten 60
ok=0
for i in $(seq 1 100); do
  ssh -o BatchMode=yes $H "curl -s -o /dev/null -w '%{http_code}' --max-time 6 http://127.0.0.1:$PORT/health 2>/dev/null" | grep -q 200 && { ok=1; break; }
  sleep 5
done
[ "$ok" -ne 1 ] && { echo "SERVER-FEHLER"; kw_server_beenden; kw_pacht_zurueckgeben; exit 1; }
timeout "$TMO" /root/coding-eval/run-bench-resume.sh "$DIR" $PORT diff 2 4 "$NT"
rc=$?
kw_wache_beenden; kw_server_beenden; kw_pacht_zurueckgeben
kw_lauf_sauber || echo "[$(date +%H:%M)] ACHTUNG -- fremder Server lief mit, Messwerte verunreinigt"
exit $rc

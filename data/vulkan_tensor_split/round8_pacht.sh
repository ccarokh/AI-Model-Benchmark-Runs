#!/bin/bash
# Round 8 under the GPU lease, from the controller (lease pattern of tagesmessung.sh): waits for the
# builds on the host, takes the lease, runs round8.sh there, gives the lease back.
set -u
M=${ZIEL:?GPU host as user@host}; R=http://${M#*@}:8080
L=/root/coding-eval/vktp_round8.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" >> $L; }

BAU_PID=${BAU_PID:?PID of vktp_bauen_1026.sh on the host}
until ssh -n $M "grep -q FERTIG_BAU /root/eval/vktp_bauen_1026.log || ! kill -0 $BAU_PID 2>/dev/null"; do sleep 30; done
ssh -n $M 'grep -q FERTIG_BAU /root/eval/vktp_bauen_1026.log' || { sag "Bau fehlgeschlagen: $(ssh -n $M tail -3 /root/eval/vktp_bauen_1026.log)"; exit 1; }
sag "Bau fertig"

t=$(cat /etc/bench/lease.token) || { sag "kein Pacht-Token"; exit 1; }
a=$(curl -s -m 240 -X POST "$R/_manager/lease" -H "x-lease-token: $t" -H "Content-Type: application/json" -d '{"holder":"vktp-round8"}')
id=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
[ -z "$id" ] && { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; exit 1; }
sag "Pacht $id gehalten"
( while :; do sleep 120
    c=$(curl -s -o /dev/null -w '%{http_code}' -m 15 -X POST "$R/_manager/lease/$id/heartbeat" -H "x-lease-token: $t")
    [ "$c" != 200 ] && { sag "PACHT VERLOREN ($c) -- laufender Lauf ist ungueltig"; kill -TERM $$; exit 1; }
  done ) & H=$!
aufraeumen(){ kill $H 2>/dev/null
  curl -s -m 15 -o /dev/null -X DELETE "$R/_manager/lease/$id" -H "x-lease-token: $t"; sag "Pacht $id zurueckgegeben"; }
trap aufraeumen EXIT

ssh -n $M /root/eval/vulkan-ar/${RUNDE:-round8}.sh >> $L 2>&1
sag "round8.sh beendet rc=$?"

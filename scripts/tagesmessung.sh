#!/bin/bash
# One measurement step outside the night window, from the controller: take the
# GPU lease, run one command on the target over ssh, heartbeat meanwhile,
# return the lease. Same rules as the night window, just one step and now.
# Usage: BEFEHL="<command on the target>" tagesmessung.sh
set -u
Z=${ZIEL:-root@192.168.40.192}; R=http://${Z#*@}:8080; L=${L:-/root/nacht/tagesmessung.log}
t=$(cat /etc/bench/lease.token) || { echo "kein Pacht-Token"; exit 1; }
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" >> $L; }
a=$(curl -s -m 15 -X POST "$R/_manager/lease" -H "x-lease-token: $t" -H "Content-Type: application/json" -d '{"holder":"tagesmessung"}')
id=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
[ -z "$id" ] && { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; exit 1; }
sag "Pacht $id gehalten -- $BEFEHL"
( while :; do sleep 120
    c=$(curl -s -o /dev/null -w '%{http_code}' -m 15 -X POST "$R/_manager/lease/$id/heartbeat" -H "x-lease-token: $t")
    [ "$c" != 200 ] && { sag "PACHT VERLOREN ($c)"; pkill -TERM -P $$; kill -TERM $$; exit 1; }
  done ) & H=$!
ssh -n -o BatchMode=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=4 "$Z" "$BEFEHL" >> $L 2>&1
sag "rc=$?"
kill $H 2>/dev/null
curl -s -m 15 -o /dev/null -X DELETE "$R/_manager/lease/$id" -H "x-lease-token: $t"
sag "Pacht $id zurueckgegeben"

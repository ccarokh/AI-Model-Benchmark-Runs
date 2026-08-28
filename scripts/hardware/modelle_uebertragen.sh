#!/bin/bash
# Copy models from here into the VM that installs the target system.
#
# Runs ON THIS MACHINE. The VM has to be reachable over SSH and have the target
# disk mounted (after arch_installieren.sh it sits at /mnt).
#
# ============================== SETTINGS =====================================
VM=${VM:-}                                  # e.g. root@192.168.122.50 -- MUST be set
ZIEL=${ZIEL:-/mnt/opt/mess/models}          # path INSIDE the VM, on the target disk
LOKAL=${LOKAL:-/home/arokh/KI/Coding/models}
FERN=${FERN:?FERN ist nicht gesetzt, z.B. root@10.0.0.2:/opt/llm-infra/models}
MODELLE=${MODELLE:-qwen3.5-9b ornith-9b qwen2.5-coder-14b bge-m3}
# =============================================================================
#
# The list above is a DEFAULT, not a commitment -- it fits into 12 GB and
# covers the field this repo has already measured. Change it with
# MODELLE="..." before the call.
#
# Whatever is not local here gets fetched from .192. The detour is deliberate:
# the target box should later need neither network nor foreign machines.
set -euo pipefail
sag(){ echo "[$(date '+%H:%M:%S')] $*"; }

[ -n "$VM" ] || { echo "VM ist nicht gesetzt. Beispiel:"; echo "  VM=root@192.168.122.50 $0"; exit 2; }
ssh -n -o ConnectTimeout=8 "$VM" true || { echo "VM nicht erreichbar: $VM"; exit 2; }
ssh -n "$VM" "mountpoint -q /mnt || { echo 'Zielplatte ist nicht unter /mnt eingehaengt'; exit 1; }"
ssh -n "$VM" "mkdir -p '$ZIEL'"

echo "Platz in der VM auf der Zielplatte:"
ssh -n "$VM" "df -h /mnt | tail -1" | sed 's/^/  /'
echo "Zu uebertragen:"
gesamt=0
for m in $MODELLE; do
  if [ -d "$LOKAL/$m" ]; then g=$(du -sm "$LOKAL/$m" | cut -f1); q=lokal
  else g=$(ssh -n "${FERN%%:*}" "du -sm '${FERN#*:}/$m' 2>/dev/null | cut -f1" || echo 0); q=".192"; fi
  gesamt=$((gesamt + g)); printf "  %-22s %6s MB  (%s)\n" "$m" "$g" "$q"
done
echo "  --------------------------------------"
printf "  %-22s %6s MB\n" "gesamt" "$gesamt"
read -rp "Uebertragen? [j/N] " a; [ "$a" = j ] || { echo "abgebrochen"; exit 1; }

for m in $MODELLE; do
  if [ -d "$LOKAL/$m" ]; then
    sag "$m  <- lokal"
    rsync -a --info=progress2 -e ssh "$LOKAL/$m/" "$VM:$ZIEL/$m/"
  else
    sag "$m  <- .192 (Umweg ueber diesen Rechner)"
    rsync -a --info=progress2 "$FERN/$m/" "/tmp/modelle_zwischen/$m/"
    rsync -a --info=progress2 -e ssh "/tmp/modelle_zwischen/$m/" "$VM:$ZIEL/$m/"
    rm -rf "/tmp/modelle_zwischen/$m"
  fi
done

sag "angekommen:"
ssh -n "$VM" "du -sh '$ZIEL'/* 2>/dev/null" | sed 's/^/  /'

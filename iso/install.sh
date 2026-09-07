#!/bin/bash
# Unattended installer for a benchmark node -- with exactly one question.
#
# THE ONE QUESTION IS THE DISK. Everything else runs through without asking:
# partitioning, packages, bootloader, services, the tunnel enrolment. But an
# installer that guesses its target disk is a data shredder, and this one runs
# on somebody else's machine whose disk layout nobody here has ever seen. So it
# lists what it found, and it will not touch anything until a person has typed
# the name back.
set -u
PAYLOAD=/opt/payload
ZIEL=/mnt

echo
echo "  ================================================================"
echo "    Benchmark node installer"
echo "  ================================================================"
echo
echo "  This installs a small Arch Linux onto ONE disk of this machine."
echo "  EVERYTHING ON THAT DISK WILL BE ERASED."
echo
echo "  Disks found:"
echo
lsblk -dno NAME,SIZE,MODEL,TRAN | awk '{printf "    /dev/%-8s %8s  %s\n", $1, $2, substr($0, index($0,$3))}'
echo
echo "  Type the full device name of the disk to install onto, for example"
echo "  /dev/sdb or /dev/nvme1n1. Anything else aborts."
echo
read -rp "  Disk: " DISK

[ -b "$DISK" ] || { echo "  Not a block device: $DISK -- nothing was changed."; exit 1; }

echo
echo "  About to erase $DISK  ($(lsblk -dno SIZE "$DISK" | tr -d ' '), $(lsblk -dno MODEL "$DISK"))"
echo "  Type ERASE to continue. Anything else aborts."
read -rp "  > " OK
[ "$OK" = "ERASE" ] || { echo "  Aborted. Nothing was changed."; exit 1; }

# The second question, and the reason the stick stays useful after we are gone:
# a reinstall done by its owner alone has no use for our tunnel, and should not
# sit there waiting for somebody to unlock a peer. Default is yes, because the
# first installation is the one that does the measurements.
echo
echo "  Set up remote access for the measurements?"
echo "  Answer n if you are reinstalling this machine for yourself -- then"
echo "  nothing of ours is installed and the system is entirely your own."
echo
read -rp "  [J/n] " FERN
case "${FERN:-J}" in n|N|nein|no) FERN=nein;; *) FERN=ja;; esac

set -e
echo "  [1/8] partitioning"
wipefs -a "$DISK" >/dev/null
sgdisk -Z "$DISK" >/dev/null
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI -n2:0:0 -t2:8300 -c2:root "$DISK" >/dev/null
partprobe "$DISK"; sleep 2
# nvme0n1 -> nvme0n1p1, sda -> sda1
case "$DISK" in *nvme*|*mmcblk*) P1="${DISK}p1"; P2="${DISK}p2";; *) P1="${DISK}1"; P2="${DISK}2";; esac

echo "  [2/8] filesystems"
mkfs.fat -F32 -n EFI "$P1" >/dev/null
mkfs.ext4 -qF -L benchnode "$P2"
mount "$P2" "$ZIEL"
mkdir -p "$ZIEL/boot"
mount "$P1" "$ZIEL/boot"

echo "  [3/8] base system -- this is the long part"
pacstrap -K "$ZIEL" $(cat $PAYLOAD/packages.txt) >/dev/null

echo "  [4/8] fstab and locale"
genfstab -U "$ZIEL" >> "$ZIEL/etc/fstab"
echo benchnode > "$ZIEL/etc/hostname"
echo "en_US.UTF-8 UTF-8" >> "$ZIEL/etc/locale.gen"
echo "LANG=en_US.UTF-8" > "$ZIEL/etc/locale.conf"

echo "  [5/8] payload"
cp -a $PAYLOAD/opt/. "$ZIEL/opt/"
cp -a $PAYLOAD/usr/. "$ZIEL/usr/"
cp -a $PAYLOAD/etc/. "$ZIEL/etc/"
if [ "$FERN" = ja ]; then
  install -Dm600 $PAYLOAD/authorized_keys "$ZIEL/root/.ssh/authorized_keys"
  chmod 700 "$ZIEL/root/.ssh"
else
  # Same set the owner's own zugang-loeschen removes later. Not installing it
  # in the first place is the cleaner version of the same decision.
  rm -f  "$ZIEL/etc/systemd/system/enrol-tunnel.service"
  rm -rf "$ZIEL/etc/systemd/system/wg-quick@wg0.service.d"
  rm -f  "$ZIEL/usr/local/bin/enrol-tunnel" "$ZIEL/usr/local/bin/zugang-loeschen"
  rm -f  "$ZIEL/opt/bench/tunnel.env"
  echo "      remote access skipped -- this system is nobody's but yours"
fi

echo "  [6/8] llm-runtime and llm-gateway"
# Bundled rather than fetched: the registry sits on an internal address this
# machine will never reach. Installed but NOT enabled -- a runtime that starts
# on its own would take the card while measurements run.
install -Dm644 $PAYLOAD/llm-runtime.pkg.tar.zst "$ZIEL/var/cache/pacman/pkg/llm-runtime.pkg.tar.zst"
arch-chroot "$ZIEL" pacman -U --noconfirm --needed \
    /var/cache/pacman/pkg/llm-runtime.pkg.tar.zst >/dev/null
# The gateway ships as a Debian package: plain Python plus a prebuilt venv.
bsdtar -xf $PAYLOAD/llm-gateway.deb -O data.tar.zst | bsdtar -xf - -C "$ZIEL"
# That venv was built against Debian's Python. If Arch ships a different minor
# version its compiled modules will not load, so it gets rebuilt from the
# freeze file the package carries for exactly this case.
arch-chroot "$ZIEL" /bin/bash -s <<'GW' >/dev/null 2>&1 || echo "      (venv rebuild skipped -- check it before switching the gateway on)"
set -e
V=$(python3 -c 'import sys;print("python%d.%d"%sys.version_info[:2])')
[ -d "/opt/llm-gateway/venv/lib/$V" ] && exit 0
python3 -m venv --clear /opt/llm-gateway/venv
/opt/llm-gateway/venv/bin/pip install -q -r /opt/llm-gateway/venv-freeze.txt
GW
mkdir -p "$ZIEL/opt/llm-runtime-data" "$ZIEL/opt/llm-gateway/data"

echo "  [7/8] bootloader and services"
arch-chroot "$ZIEL" /bin/bash -s <<'CHROOT' >/dev/null
set -e
locale-gen
# The installed system keeps the same rule as everywhere else in this project:
# no password on root, keys only over the network. Its owner sets one with
# passwd whenever they feel like taking it over.
passwd -d root
bootctl install
cat > /boot/loader/loader.conf <<L
default arch
timeout 1
L
KERNEL=$(ls /boot/vmlinuz-* | head -1 | xargs basename)
UUID=$(findmnt -no UUID /)
cat > /boot/loader/entries/arch.conf <<E
title   Benchmark node
linux   /$KERNEL
initrd  /initramfs-linux.img
options root=UUID=$UUID rw
E
mkinitcpio -P
systemctl enable sshd NetworkManager fetch-models
[ -f /etc/systemd/system/enrol-tunnel.service ] && systemctl enable enrol-tunnel wg-quick@wg0
CHROOT

echo "  [8/8] done"
umount -R "$ZIEL"
echo
echo "  Installed. Remove the stick and reboot."
if [ "$FERN" = ja ]; then
  echo "  On the next start the machine shows a key to send back."
else
  echo "  No remote access was installed. This system is entirely yours."
fi
echo
echo "  llm-runtime and llm-gateway are installed but switched OFF, so they"
echo "  cannot take the card while it is being measured. Afterwards:"
echo "      systemctl enable --now llm-runtime llm-gateway"
echo

#!/bin/bash
# Install Arch onto a disk that afterwards moves into a DIFFERENT machine.
#
# To be run on a running Arch-like system that can see the target disk. The only
# requirement is the arch-install-scripts package (pacstrap, arch-chroot,
# genfstab). A VM or a live image is not needed.
#
# ============================== SETTINGS =====================================
PLATTE=${PLATTE:-}                       # z.B. /dev/sda -- MUSS gesetzt werden
RECHNERNAME=${RECHNERNAME:-messkiste}
ZEITZONE=${ZEITZONE:-Europe/Berlin}
TASTATUR=${TASTATUR:-de-latin1}
SPRACHE=${SPRACHE:-de_DE.UTF-8}
ROOT_PASSWORT=${ROOT_PASSWORT:-}         # leer = kein Passwort, nur Schluessel
SSH_SCHLUESSEL=${SSH_SCHLUESSEL:-}       # Inhalt einer .pub-Datei fuer root
SPIEGEL=${SPIEGEL:-}                     # eigene Spiegelliste, sonst siehe unten
# nvidia-open, NOT nvidia: Arch dropped the old package and ships only the open
# kernel modules. For a 4070 (Ada) that is the correct and supported choice --
# nvidia-open covers Turing and newer.
#
# vulkan-headers, shaderc and glslang are mandatory, not extras.
# vulkan-icd-loader alone brings only the library -- without the headers cmake
# aborts with "Could NOT find Vulkan (missing: Vulkan_INCLUDE_DIR)". Runtime
# installed, build time forgotten: the same mistake twice.
ZUSATZ=${ZUSATZ:-nvidia-open nvidia-utils vulkan-icd-loader vulkan-headers vulkan-tools shaderc glslang spirv-headers spirv-tools ccache base-devel cmake git python jq rsync}
# =============================================================================
#
# WHY NO autodetect IN mkinitcpio:
# The disk is written in a VM and afterwards runs on real hardware. The default
# hook "autodetect" only picks up the drivers loaded AT BUILD TIME -- i.e. the
# VM's. On the target machine the driver for its SATA or NVMe controller is then
# missing, and the system stalls at boot without a usable error. Without
# autodetect all modules come along: the boot image gets bigger and boots
# anywhere.
set -euo pipefail
sag(){ echo "[$(date '+%H:%M:%S')] $*"; }

[ -n "$PLATTE" ] || { echo "PLATTE ist nicht gesetzt. Beispiel:"; echo "  PLATTE=/dev/sda $0"; lsblk -dno NAME,SIZE,MODEL | sed 's/^/  /'; exit 2; }
[ -b "$PLATTE" ] || { echo "$PLATTE ist kein Blockgeraet"; exit 2; }
[ -d /sys/firmware/efi ] || { echo "Das Live-System laeuft nicht im UEFI-Modus -- die VM muss UEFI starten"; exit 2; }

echo
lsblk -no NAME,SIZE,MODEL "$PLATTE" | sed 's/^/  /'
echo
read -rp "ALLES auf $PLATTE wird geloescht. Zum Fortfahren 'loeschen' eingeben: " a
[ "$a" = loeschen ] || { echo "abgebrochen"; exit 1; }

# An aborted run leaves /mnt mounted. Repartitioning a mounted disk goes wrong
# -- so unmount first, from the inside out.
if mountpoint -q /mnt; then
  sag "  /mnt war noch eingehaengt -- wird geloest"
  # pacstrap -K creates a keyring in the target system and runs a gpg-agent for
  # it, which afterwards keeps a file under /mnt open. Without killing it umount
  # reports "target is busy", and the cause appears nowhere -- lsof does not even
  # show it without root.
  gpgconf --homedir /mnt/etc/pacman.d/gnupg --kill gpg-agent 2>/dev/null || true
  sleep 1
  if ! umount -R /mnt 2>/dev/null; then
    echo "  /mnt laesst sich nicht loesen. Wer es festhaelt:"
    fuser -vm /mnt 2>&1 | sed 's/^/    /'
    for pp in /proc/[0-9]*; do
      t=$(readlink "$pp/cwd" 2>/dev/null)
      case "$t" in /mnt*) echo "    PID ${pp#/proc/} arbeitet in $t ($(tr -d "\0" < "$pp/comm" 2>/dev/null))";; esac
    done
    exit 1
  fi
fi
swapoff -a 2>/dev/null || true

sag "1/8  Partitionieren (GPT, EFI + Wurzel)"
# On a disk with an old MBR/NTFS layout sgdisk reports "Invalid partition data!"
# and returns an error code -- even though the wipe worked. With "set -e" that
# ends the installation after the first step. So it is deliberately let through
# here and VERIFIED afterwards, instead of trusting the return value.
wipefs -a "$PLATTE" >/dev/null 2>&1 || true
sgdisk --zap-all "$PLATTE" || true
sgdisk --verify "$PLATTE" >/dev/null 2>&1 || sgdisk --clear "$PLATTE" >/dev/null
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI "$PLATTE"
sgdisk -n2:0:0     -t2:8300 -c2:arch "$PLATTE"
partprobe "$PLATTE"; sleep 2
# Look instead of hope: are both partitions really there?
lsblk -no NAME,SIZE,PARTLABEL "$PLATTE" | sed 's/^/  /' 
case "$PLATTE" in *nvme*|*mmcblk*) P1=${PLATTE}p1; P2=${PLATTE}p2;; *) P1=${PLATTE}1; P2=${PLATTE}2;; esac

sag "2/8  Dateisysteme"
mkfs.fat -F32 -n EFI "$P1"
mkfs.ext4 -F -L arch "$P2"
mount "$P2" /mnt
mkdir -p /mnt/boot
mount "$P1" /mnt/boot

sag "3/8  Grundsystem"
# OUR OWN pacman configuration for this run. Two reasons:
#
# 1. Otherwise pacstrap uses THIS machine's /etc/pacman.conf. This one runs
#    Garuda, and its extra repositories would travel into the new Arch -- a
#    system unlike every other one measured here.
# 2. The default mirror can collapse ("Operation too slow"), and pacstrap then
#    aborts in the middle of the base system. An own list with several servers
#    catches that.
#
# None of this changes this machine's configuration.
KONF=$(mktemp /tmp/pacstrap-pacman.XXXX.conf)
LISTE=$(mktemp /tmp/pacstrap-mirrors.XXXX)
if [ -n "$SPIEGEL" ]; then
  printf 'Server = %s\n' $SPIEGEL > "$LISTE"
elif command -v reflector >/dev/null; then
  sag "  Spiegel nach Geschwindigkeit sortieren (reflector)"
  reflector --country Germany,Netherlands,Austria --protocol https \
            --age 12 --latest 12 --sort rate --save "$LISTE"
else
  cat > "$LISTE" <<'SPIEGELENDE'
Server = https://ftp.halifax.rwth-aachen.de/archlinux/$repo/os/$arch
Server = https://mirror.moson.org/arch/$repo/os/$arch
Server = https://archlinux.thaller.ws/$repo/os/$arch
Server = https://mirror.f4st.host/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
SPIEGELENDE
fi
head -3 "$LISTE" | sed 's/^/  /'
cat > "$KONF" <<KONFENDE
[options]
Architecture = auto
SigLevel    = Required DatabaseOptional
DisableDownloadTimeout
ParallelDownloads = 5
[core]
Include = $LISTE
[extra]
Include = $LISTE
KONFENDE
# Microcode from BOTH vendors: which CPU sits in the target box is not known
# here, and the wrong one is simply ignored at boot. Without microcode real
# hardware runs without its vendor's errata fixes -- in a VM that goes unnoticed,
# on bare metal it does not.
pacstrap -K -C "$KONF" /mnt base linux linux-firmware amd-ucode intel-ucode \
  sudo openssh networkmanager $ZUSATZ
# Carry the mirror list into the new system, otherwise it stands there without one.
install -Dm644 "$LISTE" /mnt/etc/pacman.d/mirrorlist

sag "4/8  fstab (ueber UUID -- Geraetenamen aendern sich im anderen Rechner)"
genfstab -U /mnt >> /mnt/etc/fstab

sag "5/8  Grundeinstellungen"
arch-chroot /mnt /bin/bash -e <<CHROOT
ln -sf /usr/share/zoneinfo/$ZEITZONE /etc/localtime
hwclock --systohc
sed -i 's/^#\($SPRACHE\)/\1/; s/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=$SPRACHE" > /etc/locale.conf
echo "KEYMAP=$TASTATUR" > /etc/vconsole.conf
echo "$RECHNERNAME" > /etc/hostname
systemctl enable NetworkManager sshd
CHROOT

sag "6/8  Startabbild vorbereiten (ohne autodetect, ohne kms)"
# autodetect out: the disk is written HERE and runs THERE. The hook only picks
# up the drivers loaded at build time -- i.e. this machine's. On the target box
# the driver for its controller would then be missing, and the system would
# stall at boot without a usable error.
#
# kms out: the hook pulls nouveau into the boot image, and that collides with the
# NVIDIA driver -- on the very card this is all about.
# microcode IN: kernel-install writes only ONE initrd line, it does not
# additionally point at amd-ucode.img/intel-ucode.img. The hook embeds the
# microcode into the image instead -- without it the files do sit in the boot
# partition but never get loaded, and the box runs without its CPU vendor's
# errata fixes.
sed -i 's/^HOOKS=.*/HOOKS=(base udev microcode modconf keyboard keymap consolefont block filesystems fsck)/' /mnt/etc/mkinitcpio.conf
grep '^HOOKS=' /mnt/etc/mkinitcpio.conf | sed 's/^/  /'

sag "7/8  Bootloader und Kernel (systemd-boot + kernel-install)"
# NOT mkinitcpio -P and no hand-written entries: Arch has moved to
# kernel-install. The kernel package no longer ships an mkinitcpio preset
# ("No presets found in /etc/mkinitcpio.d"); instead /usr/lib/kernel/install.d
# holds the steps that produce boot image AND entry -- microcode included, in
# the right order.
UUID=$(blkid -s UUID -o value "$P2")
mkdir -p /mnt/etc/kernel
echo "root=UUID=$UUID rw" > /mnt/etc/kernel/cmdline
sed 's/^/  cmdline: /' /mnt/etc/kernel/cmdline

arch-chroot /mnt /bin/bash -e <<'CHROOT'
[ -s /etc/machine-id ] || systemd-machine-id-setup
bootctl install
KV=$(ls /usr/lib/modules | head -1)
kernel-install add "$KV" "/usr/lib/modules/$KV/vmlinuz"
CHROOT

cat > /mnt/boot/loader/loader.conf <<EOF
default *
timeout 3
console-mode max
EOF

# Look instead of hope: is there an entry, and does it find its files?
# Prove that the microcode really sits inside the image -- the mere presence of
# the files in the boot partition says nothing about that.
for i in /mnt/boot/*/*/initrd; do
  [ -e "$i" ] || continue
  if arch-chroot /mnt lsinitcpio "${i#/mnt}" 2>/dev/null | grep -qiE "AuthenticAMD|GenuineIntel|microcode"; then
    sag "  Mikrocode ist im Startabbild"
  else
    sag "  WARNUNG: kein Mikrocode im Startabbild gefunden"
  fi
done

sag "  angelegte Starteintraege:"
find /mnt/boot/loader/entries -name '*.conf' | sed 's/^/    /'
for e in /mnt/boot/loader/entries/*.conf; do
  [ -e "$e" ] || { echo "  KEIN Starteintrag angelegt"; exit 1; }
  sed 's/^/    /' "$e"
  awk '/^(linux|initrd)/{print $2}' "$e" | while read -r f; do
    [ -e "/mnt/boot$f" ] || { echo "    FEHLT: $f"; exit 1; }
  done
done

sag "8/8  Zugang"
if [ -n "$ROOT_PASSWORT" ]; then
  echo "root:$ROOT_PASSWORT" | arch-chroot /mnt chpasswd
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config
fi
if [ -n "$SSH_SCHLUESSEL" ]; then
  mkdir -p /mnt/root/.ssh && chmod 700 /mnt/root/.ssh
  echo "$SSH_SCHLUESSEL" > /mnt/root/.ssh/authorized_keys
  chmod 600 /mnt/root/.ssh/authorized_keys
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /mnt/etc/ssh/sshd_config
fi
[ -n "$ROOT_PASSWORT$SSH_SCHLUESSEL" ] || sag "WARNUNG: weder Passwort noch Schluessel gesetzt -- kein Zugang!"

mkdir -p /mnt/opt/mess/models
sync
sag "fertig."
cat <<ENDE

  Wurzel:  /mnt          (bleibt eingehaengt, damit Modelle drauf koennen)
  Modelle: /mnt/opt/mess/models

  Modelle kopieren, z.B.:
    sudo rsync -a --info=progress2 /home/arokh/KI/Coding/models/qwen3.5-9b/ \
      /mnt/opt/mess/models/qwen3.5-9b/

  VOR DEM AUSBAUEN AUSHAENGEN, sonst fehlen die zuletzt geschriebenen Daten:
    sync && sudo umount -R /mnt
ENDE

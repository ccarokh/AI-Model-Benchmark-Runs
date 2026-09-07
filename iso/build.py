#!/usr/bin/env python3
"""Build a live ISO that turns a borrowed PC into a bench target.

WHY A LIVE SYSTEM. The card sits in somebody's working machine. Nothing here may
touch their disk: this boots from a USB stick into RAM, and a reboot removes
every trace. It is also the only shape a person actually agrees to when the
machine is theirs.

WHY IT DIALS OUT. The machine is behind a router we do not control, so nothing
can reach in. On boot it builds a WireGuard tunnel outwards to the hub, and from
then on it is an ordinary bench target -- `[target] target = root@<guest_ip>` and
the whole existing toolbox applies unchanged.

WHY THE PINNED BUILD. llama.cpp is compiled here at the version behind every
llama-bench number in data/testbench/. A figure from another version compares
versions, not cards, and the entire reason for borrowing the card is the card.

NO SECRET IS BUILT INTO THE IMAGE. The guest generates its own WireGuard key on
first boot, exactly as every other host in this project does, and shows the
public half on screen -- as text and as a QR code, so reading it back is a photo
rather than twenty transcribed characters. Everything the image carries is
public: a hub address, a hub public key, an SSH public key.

That has a consequence worth having: the ISO itself is not a credential. It can
be rebuilt, copied and handed to the next person with a card, and access is
granted per machine by adding one peer -- and revoked by removing it.
"""

import argparse
import configparser
import os
import shutil
import subprocess
import sys
from pathlib import Path

HIER = Path(__file__).resolve().parent
REPO = HIER.parent
RELENG = Path("/usr/share/archiso/configs/releng")

# Vulkan, not CUDA. It is the one backend measured on all three machines here,
# so it is the only one whose numbers can be held against the existing rows.
PAKETE = """
# nvidia-open, not nvidia: the old package name is gone from the repositories,
# and for Turing and newer the open kernel modules are what NVIDIA ships. Not
# the -dkms variant -- archiso builds on the stock `linux` package, so the
# prebuilt module matches and nothing has to compile while the machine boots.
nvidia-open
nvidia-utils
vulkan-icd-loader
vulkan-tools
wireguard-tools
qrencode
openssh
python
curl
rsync
htop
"""
# Comments are stripped per LINE. Splitting on whitespace first and then dropping
# tokens that begin with "#" leaves every other word of the comment standing as a
# package name -- which pacman then dutifully fails to find.
PAKETE = [z.strip() for z in PAKETE.splitlines()
          if z.strip() and not z.lstrip().startswith("#")]


def sag(*a):
    print(" ", *a, flush=True)


def lauf(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def konfig(pfad):
    if not pfad.is_file():
        sys.exit(f"no config at {pfad} -- copy iso.conf.example and fill it in")
    c = configparser.ConfigParser()
    c.read(pfad)
    fehlend = [f"{s}.{k}" for s, k in
               [("tunnel", "hub_endpoint"), ("tunnel", "hub_public_key"),
                ("tunnel", "guest_ip"), ("access", "ssh_public_key")]
               if not c.get(s, k, fallback="").strip()]
    if fehlend:
        sys.exit("config is incomplete: " + ", ".join(fehlend))
    return c


def voraussetzungen():
    fehlt = [w for w in ("mkarchiso", "wg", "cmake", "git", "glslc")
             if not shutil.which(w)]
    if fehlt:
        sys.exit("missing tools: " + " ".join(fehlt) +
                 "\ninstall with: sudo pacman -S --needed archiso wireguard-tools "
                 "cmake git base-devel vulkan-headers shaderc")
    if not RELENG.is_dir():
        sys.exit(f"{RELENG} not found -- is archiso installed?")


def llama_bauen(c, cache):
    """Compile the pinned version once and keep it. The ISO is rebuilt often; a
    forty-minute compile per rebuild is how a build script stops being used."""
    ziel = cache / "llama-cpp"
    if (ziel / "bin" / "llama-bench").is_file():
        sag(f"llama.cpp already built at {ziel}")
        return ziel
    ref = c.get("build", "llama_cpp_ref", fallback="b10273")
    repo = c.get("build", "llama_cpp_repo",
                 fallback="https://github.com/ggml-org/llama.cpp")
    src = cache / "src"
    if not src.is_dir():
        sag(f"cloning llama.cpp ({ref})")
        lauf(["git", "clone", "--filter=blob:none", repo, str(src)])
    lauf(["git", "-C", str(src), "fetch", "--tags", "--depth", "1", "origin", ref])
    lauf(["git", "-C", str(src), "checkout", "--detach", ref])
    build = src / "build"
    sag("compiling with Vulkan -- this takes a while")
    lauf(["cmake", "-S", str(src), "-B", str(build), "-DGGML_VULKAN=ON",
          "-DCMAKE_BUILD_TYPE=Release", f"-DCMAKE_INSTALL_PREFIX={ziel}"])
    lauf(["cmake", "--build", str(build), "--config", "Release", "-j",
          str(os.cpu_count() or 4)])
    lauf(["cmake", "--install", str(build)])
    # The identifier the suite reads. `--version` reports build metadata, not
    # the build -- that mistake is written up in METHODOLOGY.md.
    (ziel / ".built-version").write_text(ref + "\n")
    return ziel


def profil_vorbereiten(arbeit):
    if arbeit.exists():
        shutil.rmtree(arbeit)
    # symlinks=True is not cosmetic: the stock profile carries links that point
    # at things which only exist inside the built image (resolv.conf, the
    # cloud-init and vmtoolsd units). Following them means copying targets that
    # are not there, and copytree fails with a dozen of them at once.
    shutil.copytree(RELENG, arbeit, symlinks=True)
    pl = arbeit / "packages.x86_64"
    vorhanden = set(pl.read_text().split())
    pl.write_text(pl.read_text().rstrip("\n") + "\n" +
                  "".join(p + "\n" for p in PAKETE if p not in vorhanden))
    # A name that says what the stick is when it turns up in a drawer next year.
    pd = arbeit / "profiledef.sh"
    pd.write_text(pd.read_text()
                  .replace('iso_name="archlinux"', 'iso_name="benchnode"')
                  .replace('iso_label="ARCH_$(date +%Y%m)"', 'iso_label="BENCHNODE"'))
    return arbeit


def datei(pfad: Path, inhalt: str, modus=0o644):
    pfad.parent.mkdir(parents=True, exist_ok=True)
    pfad.write_text(inhalt)
    pfad.chmod(modus)


def overlay_schreiben(c, arbeit, llama):
    a = arbeit / "airootfs"

    # --- tunnel ---------------------------------------------------------
    # Only public material goes into the image. The key pair is made on the
    # machine that will use it, which is the same rule every other host in this
    # project follows -- and it means this ISO is not a credential.
    t = c["tunnel"]
    datei(a / "opt/bench/tunnel.env", f"""HUB_ENDPOINT={t['hub_endpoint']}
HUB_PUBLIC_KEY={t['hub_public_key']}
HUB_IP={t.get('hub_ip', '10.10.0.1')}
GUEST_IP={t['guest_ip']}
""")
    datei(a / "usr/local/bin/enrol-tunnel", r"""#!/bin/bash
# Generates this machine's own key pair, builds the tunnel config around it and
# shows the public half. Nothing secret was shipped with the image; the private
# key is made here and never leaves.
set -u
. /opt/bench/tunnel.env
umask 077
mkdir -p /etc/wireguard && chmod 700 /etc/wireguard
if [ ! -s /etc/wireguard/privatekey ]; then
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
fi
cat > /etc/wireguard/wg0.conf <<CONF
[Interface]
PrivateKey = $(cat /etc/wireguard/privatekey)
Address = ${GUEST_IP}/32

[Peer]
PublicKey = ${HUB_PUBLIC_KEY}
Endpoint = ${HUB_ENDPOINT}
# Only the hub. A borrowed machine has no business routing anywhere else.
AllowedIPs = ${HUB_IP}/32
# Keeps the hole in their NAT open; without it the tunnel dies when idle and the
# machine goes quiet in the middle of the night.
PersistentKeepalive = 25
CONF
chmod 600 /etc/wireguard/wg0.conf

PUB=$(cat /etc/wireguard/publickey)
# Written where a person can find it again after the screen has scrolled.
{ echo; echo "  This machine's public key:"; echo "    $PUB"; echo;
  echo "  Address in the overlay: ${GUEST_IP}"; echo; } > /etc/issue.d/10-benchnode.issue
mkdir -p /opt/results
printf '%s
' "$PUB" > /opt/results/publickey

clear
echo
echo "  ================================================================"
echo "    Send this line to the person who gave you the stick."
echo "    It is a PUBLIC key -- there is nothing secret about it."
echo "  ================================================================"
echo
echo "    $PUB"
echo
qrencode -t ANSIUTF8 "$PUB" 2>/dev/null || echo "    (photograph the line above)"
echo
echo "  Nothing works until they have added it. That is normal, and it"
echo "  costs nothing to leave this machine sitting here until they do."
echo
""", 0o755)
    datei(a / "etc/systemd/system/enrol-tunnel.service", """[Unit]
Description=Generate this machine's tunnel key and show it
Before=wg-quick@wg0.service
ConditionPathExists=!/etc/wireguard/wg0.conf

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/enrol-tunnel
StandardOutput=tty
TTYPath=/dev/tty1

[Install]
WantedBy=multi-user.target
""")
    # The peer does not exist at the hub yet when this first runs, so the tunnel
    # cannot come up on the first try. Retrying forever is the correct behaviour
    # here: the machine simply waits until somebody has added its key.
    datei(a / "etc/systemd/system/wg-quick@wg0.service.d/10-retry.conf", """[Unit]
After=enrol-tunnel.service
Requires=enrol-tunnel.service

[Service]
Restart=on-failure
RestartSec=30
""")

    # --- access -------------------------------------------------------------
    datei(a / "root/.ssh/authorized_keys",
          c["access"]["ssh_public_key"].strip() + "\n", 0o600)
    (a / "root/.ssh").chmod(0o700)
    # NO sshd drop-in of our own. The stock profile already ships one that
    # enables password authentication and root login, and in sshd_config the
    # FIRST occurrence of a keyword wins -- so a file sorting after theirs is
    # dead config that reads as if it were doing something. What actually keeps
    # anybody out is PermitEmptyPasswords, sshd's own default, because the live
    # root account has no password at all. Setting one is therefore the single
    # step needed to take the machine over, and that is what the screen says.
    # --- keep nouveau off the card ---------------------------------------
    # A live image boots with whatever the kernel autoloads, and nouveau binds
    # the card first if nothing stops it. The proprietary module then cannot
    # take over, and the failure looks like "Vulkan sees no device" rather than
    # like a driver conflict.
    datei(a / "etc/modprobe.d/10-benchnode-nvidia.conf",
          "blacklist nouveau\n"
          "blacklist nvidiafb\n"
          "options nvidia_drm modeset=1\n")
    # mkinitcpio would otherwise pull nouveau in with the autodetect hook.
    datei(a / "etc/mkinitcpio.conf.d/benchnode.conf",
          'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)\n')

    # --- the suite ----------------------------------------------------------
    shutil.copytree(REPO / "scripts" / "testbench", a / "opt/testbench",
                    ignore=shutil.ignore_patterns("__pycache__", "results",
                                                  "testbench.conf"))
    datei(a / "opt/testbench/testbench.conf", """# Written by iso/build.py for this machine.
[target]
target =
[paths]
build_search_paths = /opt/llama-cpp
model_search_paths = /opt/models
[power]
card_index = 0
[output]
out_dir = /opt/results
""")
    shutil.copytree(llama, a / "opt/llama-cpp")

    # --- models, fetched on first boot --------------------------------------
    zeilen = [z.strip() for z in c["models"]["models"].splitlines() if z.strip()]
    datei(a / "opt/bench/models.txt", "\n".join(zeilen) + "\n")
    datei(a / "usr/local/bin/fetch-models", r"""#!/bin/bash
# Downloads on first boot, over the borrowed machine's own connection.
# Completeness is decided against the remote Content-Length, never against "the
# file exists" -- a half-finished GGUF is not a download that is done, and the
# service restarts until every entry checks out.
set -u
L=/opt/results/fetch-models.log
M=/opt/models
mkdir -p $M /opt/results
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }
fehlt=0
while IFS='|' read -r name repo file; do
  [ -z "${name:-}" ] && continue
  mkdir -p "$M/$name"
  url="https://huggingface.co/$repo/resolve/main/$file"
  soll=$(curl -sIL --max-time 60 "$url" | tr -d '\r' \
         | awk 'BEGIN{IGNORECASE=1}/^content-length:/{v=$2}END{print v+0}')
  ist=$(stat -c %s "$M/$name/$file" 2>/dev/null || echo 0)
  if [ "$soll" -gt 0 ] && [ "$ist" = "$soll" ]; then sag "$name: complete"; continue; fi
  sag "$name: $((ist/1048576)) of $((soll/1048576)) MiB, continuing"
  curl -sL -C - --retry 5 --retry-delay 10 -o "$M/$name/$file" "$url"
  neu=$(stat -c %s "$M/$name/$file" 2>/dev/null || echo 0)
  if [ "$neu" = "$soll" ]; then sag "$name: done"; else sag "$name: INCOMPLETE"; fehlt=1; fi
done < /opt/bench/models.txt
sag "pass finished, incomplete=$fehlt"
exit $fehlt
""", 0o755)
    datei(a / "etc/systemd/system/fetch-models.service", """[Unit]
Description=Fetch benchmark models
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fetch-models
# A dropped connection is the normal case on somebody else's line, not a fault.
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
""")

    # --- what a person sees on the screen -----------------------------------
    datei(a / "etc/motd", f"""
  Benchmark node -- live system, nothing is written to any disk in this machine.
  Pull the stick and reboot, and no trace of this remains.

  What it does by itself:
    * builds a WireGuard tunnel outwards to its operator ({t['guest_ip']})
    * downloads the model files          journalctl -fu fetch-models
    * waits. It measures nothing until somebody asks it to.

  On a cable it is already online. On Wi-Fi somebody has to say so once:

      iwctl station wlan0 connect <network>

  You are root here and there is no password. Set one and you can reach the
  machine over SSH from your own desk -- nothing else needs changing:

      passwd

  It draws real power while measuring. Shut it down when you want it to stop.
""")

    # --- services on -------------------------------------------------------
    wants = a / "etc/systemd/system/multi-user.target.wants"
    wants.mkdir(parents=True, exist_ok=True)
    for unit, ziel in (("sshd.service", "/usr/lib/systemd/system/sshd.service"),
                       ("fetch-models.service", "/etc/systemd/system/fetch-models.service"),
                       ("enrol-tunnel.service", "/etc/systemd/system/enrol-tunnel.service"),
                       ("wg-quick@wg0.service", "/usr/lib/systemd/system/wg-quick@.service")):
        link = wants / unit
        if not link.is_symlink():
            link.symlink_to(ziel)



def main():
    p = argparse.ArgumentParser(description="build the benchmark live ISO")
    p.add_argument("--config", default=str(HIER / "iso.conf"))
    p.add_argument("--out", default=str(HIER / "out"))
    # mkarchiso wants 15-20 GB and the checkout usually does not sit on the
    # roomiest disk in the machine. Keep it separable rather than hard-coded.
    p.add_argument("--work", default=str(HIER / "work"),
                   help="scratch directory for the profile and mkarchiso")
    # mkarchiso needs root. Everything before it does not, and it is also the
    # part that takes an hour -- so the split is explicit rather than a failed
    # sudo prompt at the end of a long build.
    p.add_argument("--no-iso", action="store_true",
                   help="prepare everything, print the mkarchiso command, stop")
    args = p.parse_args()

    voraussetzungen()
    c = konfig(Path(args.config))
    cache = HIER / "cache"
    cache.mkdir(exist_ok=True)

    llama = llama_bauen(c, cache)
    arbeit_wurzel = Path(args.work)
    arbeit = profil_vorbereiten(arbeit_wurzel / "profile")
    overlay_schreiben(c, arbeit, llama)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    befehl = ["sudo", "mkarchiso", "-v", "-w", str(arbeit_wurzel / "tmp"),
              "-o", str(out), str(arbeit)]
    if args.no_iso:
        print()
        print("Prepared. The remaining step needs root:")
        print()
        print("  " + " ".join(befehl))
        print()
    else:
        sag("running mkarchiso (needs root)")
        lauf(befehl)

    print()
    print("ISO:", *sorted(out.glob("*.iso")))
    print()
    print("The image carries no secret. On first boot the machine generates its")
    print("own key and shows the public half on screen, as text and as a QR code.")
    print()
    print("Add it at the hub when it arrives:")
    print()
    print(f"  AllowedIPs = {c['tunnel']['guest_ip']}/32")
    print()
    print("Removing that peer afterwards is what revokes the access.")


if __name__ == "__main__":
    main()

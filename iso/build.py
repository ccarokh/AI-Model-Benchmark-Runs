#!/usr/bin/env python3
"""Build an installer ISO that turns a borrowed PC into a bench target.

IT INSTALLS. The stick boots, asks which disk to use, and writes a small Arch
Linux onto it. After that the machine is a permanent node: it survives reboots,
it can be handed back its own LLM setup later, and its owner can keep using it.

THE ONE QUESTION IS THE DISK, and it is not negotiable. Everything else runs
through unattended -- partitioning, packages, bootloader, services, the tunnel
enrolment. But an installer that guesses its target erases whatever it guessed
at, and this one runs on somebody else's machine whose disks nobody here has
ever seen.

WHY IT DIALS OUT. The machine is behind a router we do not control, so nothing
can reach in. On first boot it builds a WireGuard tunnel outwards, and from then
on it is an ordinary bench target -- `[target] target = root@<guest_ip>` and the
whole existing toolbox applies unchanged.

WHY THE PINNED BUILD. llama.cpp is compiled here at the version behind every
llama-bench number in data/testbench/. A figure from another version compares
versions, not cards, and the entire reason for borrowing the card is the card.

NO SECRET IS BUILT INTO THE IMAGE. The installed system generates its own
WireGuard key on first boot and shows the public half on screen -- as text and
as a QR code, so reading it back is a photo. Everything the image carries is
public, which makes it reusable for the next borrowed card rather than a
credential in its own right.
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

# What the INSTALLER environment needs on top of the stock profile. Small on
# purpose: this system only lives long enough to write another one.
PAKETE_ISO = ["arch-install-scripts", "gptfdisk", "dosfstools"]

# What gets installed onto the machine. Vulkan, not CUDA: it is the one backend
# measured on all three machines here, so it is the only one whose numbers stand
# next to the existing rows.
PAKETE_ZIEL = """
base
linux
linux-firmware
nvidia-open
nvidia-utils
vulkan-icd-loader
vulkan-tools
wireguard-tools
qrencode
openssh
networkmanager
python
curl
rsync
htop
nano
sudo
""".split()


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


def dienste_holen(c, cache):
    """Fetch llm-runtime and llm-gateway once and keep them.

    They are bundled rather than fetched at install time because the registry
    lives on an internal address the borrowed machine will never reach: its
    tunnel goes to one hub and nowhere else.
    """
    reg = c["services"]
    ziel = cache / "pakete"
    ziel.mkdir(parents=True, exist_ok=True)
    holen = {
        "llm-runtime.pkg.tar.zst":
            f"{reg['registry']}/api/packages/{reg['owner']}/arch/{reg['arch_repo']}"
            f"/x86_64/llm-runtime-{reg['runtime_version']}-x86_64.pkg.tar.zst",
        "llm-gateway.deb":
            f"{reg['registry']}/api/packages/{reg['owner']}/debian"
            f"/pool/trixie/main/llm-gateway_{reg['gateway_version']}_amd64.deb",
    }
    for name, url in holen.items():
        f = ziel / name
        if f.is_file() and f.stat().st_size > 100000:
            sag(f"{name} already fetched")
            continue
        sag(f"fetching {name}")
        lauf(["curl", "-sfL", "--max-time", "180", "-o", str(f), url])
    return ziel


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
                  "".join(p + "\n" for p in PAKETE_ISO if p not in vorhanden))
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


def nutzlast_schreiben(c, arbeit, llama, dienste):
    """Stage what the installer will copy onto the machine.

    Nothing here is active in the booted stick. The stick installs; this is the
    cargo it carries.
    """
    a = arbeit / "airootfs"
    n = a / "opt/payload"

    datei(n / "packages.txt", " ".join(PAKETE_ZIEL) + "\n")

    # --- tunnel: only public material -------------------------------------
    # The key pair is made on the machine that will use it, which is the rule
    # every other host in this project follows -- and it means this ISO is not
    # a credential.
    t = c["tunnel"]
    datei(n / "opt/bench/tunnel.env", f"""HUB_ENDPOINT={t['hub_endpoint']}
HUB_PUBLIC_KEY={t['hub_public_key']}
HUB_IP={t.get('hub_ip', '10.98.0.1')}
GUEST_IP={t['guest_ip']}
""")
    datei(n / "usr/local/bin/enrol-tunnel", r"""#!/bin/bash
# Generates this machine's own key pair on first boot, builds the tunnel config
# around it and shows the public half. Nothing secret shipped with the image.
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
# Keeps the hole in their NAT open; without it the tunnel dies when idle and
# the machine goes quiet in the middle of the night.
PersistentKeepalive = 25
CONF
chmod 600 /etc/wireguard/wg0.conf

PUB=$(cat /etc/wireguard/publickey)
mkdir -p /opt/results /etc/issue.d
{ echo; echo "  This machine's public key:"; echo "    $PUB"; echo; } > /etc/issue.d/10-benchnode.issue
printf '%s\n' "$PUB" > /opt/results/publickey

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
    datei(n / "etc/systemd/system/enrol-tunnel.service", """[Unit]
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
    # The peer does not exist at the hub when this first runs, so the tunnel
    # cannot come up on the first try. Retrying forever is correct: the machine
    # waits until somebody has added its key.
    datei(n / "etc/systemd/system/wg-quick@wg0.service.d/10-retry.conf", """[Unit]
After=enrol-tunnel.service
Requires=enrol-tunnel.service

[Service]
Restart=on-failure
RestartSec=30
""")

    # --- keep nouveau off the card ----------------------------------------
    # Nouveau binds the card first if nothing stops it. The proprietary module
    # then cannot take over, and the failure looks like "Vulkan sees no device"
    # rather than like a driver conflict.
    datei(n / "etc/modprobe.d/10-benchnode-nvidia.conf",
          "blacklist nouveau\nblacklist nvidiafb\noptions nvidia_drm modeset=1\n")
    datei(n / "etc/mkinitcpio.conf.d/benchnode.conf",
          'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)\n')

    # --- access ------------------------------------------------------------
    datei(n / "authorized_keys", c["access"]["ssh_public_key"].strip() + "\n", 0o600)

    # --- the suite ---------------------------------------------------------
    shutil.copytree(REPO / "scripts" / "testbench", n / "opt/testbench",
                    ignore=shutil.ignore_patterns("__pycache__", "results",
                                                  "testbench.conf"))
    datei(n / "opt/testbench/testbench.conf", """# Written by iso/build.py for this machine.
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
    shutil.copytree(llama, n / "opt/llama-cpp")

    # --- models, fetched on first boot -------------------------------------
    zeilen = [z.strip() for z in c["models"]["models"].splitlines() if z.strip()]
    datei(n / "opt/bench/models.txt", "\n".join(zeilen) + "\n")
    datei(n / "usr/local/bin/fetch-models", r"""#!/bin/bash
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
    datei(n / "etc/systemd/system/fetch-models.service", """[Unit]
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

    # --- what the installed machine says on screen -------------------------
    datei(n / "etc/motd", f"""
  Benchmark node.

  What it does by itself:
    * builds a WireGuard tunnel outwards to its operator ({t['guest_ip']})
    * downloads the model files          journalctl -fu fetch-models
    * waits. It measures nothing until somebody asks it to.

  On a cable it is already online. On Wi-Fi, once:   nmtui

  You are root here and there is no password. Set one and you can reach the
  machine over SSH from your own desk -- nothing else needs changing:

      passwd

  It draws real power while measuring. Shut it down when you want it to stop.

  This machine is yours. To cut the remote access for good -- the tunnel, its
  keys and the SSH key, leaving your own LLM setup running:

      zugang-loeschen
""")

    # --- the owner's own off switch ----------------------------------------
    # The machine belongs to whoever lent the card, so cutting our access has to
    # be something they can do alone, at any moment, without asking. It removes
    # the tunnel, the keys, the service that would regenerate them, and our SSH
    # key -- and deliberately leaves the LLM setup alone, because that is theirs.
    datei(n / "usr/local/bin/zugang-loeschen", r"""#!/bin/bash
# Entfernt den Fernzugang vollstaendig. Das lokale KI-System bleibt unberuehrt.
set -u
echo
echo "  Das entfernt den Fernzugang zu dieser Maschine, endgueltig:"
echo
echo "    * den WireGuard-Tunnel und seine Schluessel"
echo "    * den Dienst, der ihn beim naechsten Start neu anlegen wuerde"
echo "    * den hinterlegten SSH-Schluessel"
echo
echo "  Nicht angetastet wird alles andere: llm-runtime, llm-gateway, die"
echo "  Modelle und dein System. Die laufen weiter."
echo
echo "  Rueckgaengig geht das nicht -- ein neuer Zugang braeuchte einen"
echo "  neuen Stick. Zum Bestaetigen JA tippen, alles andere bricht ab."
echo
read -rp "  > " OK
[ "$OK" = "JA" ] || { echo "  Abgebrochen. Es wurde nichts geaendert."; exit 1; }

systemctl disable --now wg-quick@wg0 enrol-tunnel 2>/dev/null
rm -rf /etc/wireguard
rm -f  /etc/systemd/system/enrol-tunnel.service
rm -rf /etc/systemd/system/wg-quick@wg0.service.d
rm -f  /usr/local/bin/enrol-tunnel
rm -f  /opt/bench/tunnel.env
rm -f  /etc/issue.d/10-benchnode.issue
rm -f  /opt/results/publickey
rm -f  /root/.ssh/authorized_keys
systemctl daemon-reload 2>/dev/null

echo
echo "  Erledigt. Von aussen kommt hier niemand mehr rein."
echo "  Deine lokale KI laeuft unveraendert weiter."
echo
""", 0o755)

    # --- the two services ---------------------------------------------------
    # Installed but NOT enabled. A runtime that starts on its own would take the
    # card while the measurements are running -- exactly the contamination that
    # cost a night on the main host. They are switched on once the numbers are in.
    for f in dienste.iterdir():
        shutil.copy2(f, n / f.name)
    datei(n / "etc/systemd/system/llm-runtime.service", """[Unit]
Description=llm-runtime -- on-demand llama-server supervisor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/llm-runtime-data
Environment=LLM_RUNTIME_CONFIG=/etc/llm-runtime/models.yaml
Environment=LLAMA_SERVER_BIN=/opt/llama-cpp/bin/llama-server
Environment=LLM_RUNTIME_PORT=8080
ExecStart=/usr/bin/llm-runtime
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
""")
    datei(n / "etc/systemd/system/llm-gateway.service", """[Unit]
Description=llm-gateway -- OpenAI-compatible routing in front of the runtime
After=network-online.target llm-runtime.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/llm-gateway
Environment=LLM_GATEWAY_BACKEND=http://127.0.0.1:8080
Environment=LLM_GATEWAY_MODELS_CONFIG=/etc/llm-gateway/models.yaml
ExecStart=/opt/llm-gateway/venv/bin/uvicorn llm_gateway.app:app --host 0.0.0.0 --port 8090
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
""")
    # One entry per downloaded model, so the runtime has something to serve the
    # moment its owner switches it on.
    eintraege = "".join(
        f"  - name: {z.split('|')[0]}\n"
        f"    path: /opt/models/{z.split('|')[0]}/{z.split('|')[2]}\n"
        f"    logical_name: {'chat' if i == 0 else z.split('|')[0]}\n"
        f"    advertise: true\n    ctx_size: 8192\n"
        for i, z in enumerate(zeilen))
    datei(n / "etc/llm-runtime/models.yaml", "models:\n" + eintraege)

    # --- the installer itself ----------------------------------------------
    shutil.copy2(HIER / "install.sh", a / "usr/local/bin/install-benchnode")
    (a / "usr/local/bin/install-benchnode").chmod(0o755)
    # Runs instead of a shell on tty1. Somebody who wants a shell instead can
    # switch to tty2 -- this is a convenience, not a cage.
    datei(a / "etc/systemd/system/getty@tty1.service.d/installer.conf",
          "[Service]\nExecStart=\n"
          "ExecStart=-/usr/bin/agetty --autologin root --login-program "
          "/usr/local/bin/install-benchnode --noclear %I $TERM\n")


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
    dienste = dienste_holen(c, cache)
    nutzlast_schreiben(c, arbeit, llama, dienste)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    # mkarchiso records a marker file per completed step and skips whatever is
    # already marked. A work directory left over from an earlier run therefore
    # makes it a no-op that exits in seconds and produces nothing -- or worse,
    # stitches an image out of the previous profile. It is root-owned, so the
    # removal has to travel with the command rather than happen here.
    tmp = arbeit_wurzel / "tmp"
    befehl = ["sudo", "mkarchiso", "-v", "-w", str(tmp), "-o", str(out), str(arbeit)]
    if tmp.exists():
        befehl = ["sudo", "rm", "-rf", str(tmp), "&&"] + befehl
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
    print("The stick INSTALLS. It boots, asks which disk to use, and writes a")
    print("small Arch Linux onto it. Afterwards the machine survives reboots.")
    print()
    print("The image carries no secret. On first boot the installed system")
    print("generates its own key and shows the public half, as text and as a QR.")
    print()
    print("Add it at the hub when it arrives:")
    print()
    print(f"  AllowedIPs = {c['tunnel']['guest_ip']}/32")
    print()
    print("Removing that peer afterwards is what revokes the access.")


if __name__ == "__main__":
    main()

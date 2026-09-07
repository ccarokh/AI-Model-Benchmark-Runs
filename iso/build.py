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

The private WireGuard key is generated here and written onto the stick. That
deviates from the project rule that a private key never leaves its host, and the
deviation is deliberate: the alternative needs the guest to read its key off the
screen and send it back before anything works. It is bounded instead -- the hub
grants that key a single /32, and removing the peer revokes it.
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
nvidia
nvidia-utils
vulkan-icd-loader
vulkan-tools
wireguard-tools
openssh
python
curl
rsync
htop
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
    shutil.copytree(RELENG, arbeit)
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

    # --- tunnel -------------------------------------------------------------
    priv = subprocess.run(["wg", "genkey"], capture_output=True, text=True,
                          check=True).stdout.strip()
    pub = subprocess.run(["wg", "pubkey"], input=priv, capture_output=True,
                         text=True, check=True).stdout.strip()
    t = c["tunnel"]
    datei(a / "etc/wireguard/wg0.conf", f"""# Built by iso/build.py. The guest dials out; nothing dials in.
[Interface]
PrivateKey = {priv}
Address = {t['guest_ip']}/32

[Peer]
PublicKey = {t['hub_public_key']}
Endpoint = {t['hub_endpoint']}
# Only the hub. A borrowed machine has no business routing anywhere else.
AllowedIPs = {t.get('hub_ip', '10.10.0.1')}/32
# Keeps the hole in their NAT open; without it the tunnel dies when idle and
# the machine goes quiet in the middle of the night.
PersistentKeepalive = 25
""", 0o600)
    (a / "etc/wireguard").chmod(0o700)

    # --- access -------------------------------------------------------------
    datei(a / "root/.ssh/authorized_keys",
          c["access"]["ssh_public_key"].strip() + "\n", 0o600)
    (a / "root/.ssh").chmod(0o700)
    datei(a / "etc/ssh/sshd_config.d/20-benchnode.conf",
          "PermitRootLogin prohibit-password\n"
          "PasswordAuthentication no\n"
          "KbdInteractiveAuthentication no\n")

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

  It draws real power while measuring. Shut it down when you want it to stop.
""")

    # --- services on -------------------------------------------------------
    wants = a / "etc/systemd/system/multi-user.target.wants"
    wants.mkdir(parents=True, exist_ok=True)
    for unit, ziel in (("sshd.service", "/usr/lib/systemd/system/sshd.service"),
                       ("fetch-models.service", "/etc/systemd/system/fetch-models.service"),
                       ("wg-quick@wg0.service", "/usr/lib/systemd/system/wg-quick@.service")):
        link = wants / unit
        if not link.is_symlink():
            link.symlink_to(ziel)
    return pub


def main():
    p = argparse.ArgumentParser(description="build the benchmark live ISO")
    p.add_argument("--config", default=str(HIER / "iso.conf"))
    p.add_argument("--out", default=str(HIER / "out"))
    args = p.parse_args()

    voraussetzungen()
    c = konfig(Path(args.config))
    cache = HIER / "cache"
    cache.mkdir(exist_ok=True)

    llama = llama_bauen(c, cache)
    arbeit = profil_vorbereiten(HIER / "work" / "profile")
    pub = overlay_schreiben(c, arbeit, llama)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    sag("running mkarchiso (needs root)")
    lauf(["sudo", "mkarchiso", "-v", "-w", str(HIER / "work" / "tmp"),
          "-o", str(out), str(arbeit)])

    print()
    print("ISO:", *sorted(out.glob("*.iso")))
    print()
    print("BEFORE handing over the stick, add this peer to the hub:")
    print()
    print(f"  PublicKey  = {pub}")
    print(f"  AllowedIPs = {c['tunnel']['guest_ip']}/32")
    print()
    print("Removing that peer afterwards is what revokes the access.")


if __name__ == "__main__":
    main()

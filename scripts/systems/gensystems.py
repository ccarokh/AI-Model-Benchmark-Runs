#!/usr/bin/env python3
"""Write the facts block of every system page from data/systems/*.json.

Generated rather than written because the three pages used to have three
different shapes. One talked about system RAM, the next about the BIOS, and
whether a field was MISSING could not be seen at all. Now every page carries the
same fields in the same order, and anything that could not be read says "not
determined" -- a gap is a statement.

The prose is left alone: only what sits between the markers is generated.
"""
import json, os, re

MARKE_AUF = "<!-- CAPTURED:BEGIN -->"
MARKE_ZU = "<!-- CAPTURED:END -->"

# Labels are English, like everything else in this repository -- documents,
# comments and commit messages alike. A generated block with German headers in
# the middle of English prose is what forced this cleanup.
FELDER = [
    ("cpu", "CPU"), ("cpu_faeden", "Threads"), ("ram_gb", "System RAM (GB)"),
    ("board", "Board — vendor"), ("board_modell", "Board — model"),
    ("bios", "BIOS"), ("bios_datum", "BIOS date"),
    ("mikrocode", "Microcode (running)"), ("mikrocode_start", "Microcode replaced at boot, from"),
    ("os", "OS"), ("kernel", "Kernel"), ("python", "Python"),
    ("wurzel_geraet", "Root filesystem"), ("wurzel_traeger", "Root device"),
    ("vulkan_geraet", "Vulkan reports"), ("vulkan_api", "Vulkan API"),
    ("vram_leerlauf", "VRAM in use at capture"),
]

def zelle(v):
    return "*not determined*" if v in (None, "", "null") else str(v)

def block(d):
    z = ["| | |", "|---|---|"]
    for schluessel, name in FELDER:
        z.append(f"| **{name}** | {zelle(d.get(schluessel))} |")
    k = d.get("karten") or []
    if k:
        z += ["", "**GPUs**", "", "| GPU | VRAM | Driver | Power limit |", "|---|---|---|---|"]
        for e in k:
            z.append(f"| {zelle(e.get('name'))} | {zelle(e.get('vram'))} | "
                     f"{zelle(e.get('treiber'))} | {zelle(e.get('leistungsgrenze'))} |")
    pc = d.get("pcie") or []
    if pc:
        z += ["", "**PCIe**", "",
              "| Device | Card to switch | Switch to CPU |", "|---|---|---|"]
        for e in pc:
            z.append(f"| {zelle(e.get('name'))} | {zelle(e.get('karte_zur_bruecke'))} | "
                     f"{zelle(e.get('bruecke_zur_cpu'))} |")
    b = d.get("llama_cpp") or []
    z += ["", "**llama.cpp**", ""]
    if b:
        z += ["| Path | Build | Backend |", "|---|---|---|"] + [
            f"| `{e['pfad']}` | {zelle(e.get('stand'))} | {zelle(e.get('backend'))} |" for e in b]
    else:
        z.append("*none installed*")
    z += ["", f"*Captured {zelle(d.get('erfasst_am'))} by "
          f"[`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) — "
          f"read off the machine, not written by hand. `VRAM in use` and the PCIe link "
          f"are momentary values: link speed drops at idle, and on a desktop machine the "
          f"session holds VRAM.*"]
    return "\n".join(z)

for name in sorted(os.listdir("data/systems")):
    if not name.endswith(".json"): continue
    d = json.load(open("data/systems/" + name, encoding="utf-8"))
    seite = "systems/" + name.replace(".json", ".md")
    if not os.path.exists(seite):
        print("  fehlt:", seite); continue
    s = open(seite, encoding="utf-8").read()
    neu = MARKE_AUF + "\n" + block(d) + "\n" + MARKE_ZU
    if MARKE_AUF in s:
        s = re.sub(re.escape(MARKE_AUF) + r".*?" + re.escape(MARKE_ZU), lambda _: neu, s, flags=re.S)
    else:
        kopf, rest = s.split("\n", 1)
        s = kopf + "\n\n" + neu + "\n" + rest
    open(seite, "w", encoding="utf-8").write(s)
    print("  erzeugt:", seite, f"({d.get('rechnername')})")

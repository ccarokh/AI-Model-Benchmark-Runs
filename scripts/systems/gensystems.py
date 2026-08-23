#!/usr/bin/env python3
"""Aus data/systems/*.json den Tatsachenblock jeder Systemseite erzeugen.

Warum erzeugt und nicht geschrieben: die drei Seiten hatten drei verschiedene
Formen. Eine erzaehlte ueber Arbeitsspeicher, die naechste ueber das BIOS, und
ob irgendwo ein Feld FEHLTE, war gar nicht zu sehen. Jetzt hat jede Seite
dieselben Felder in derselben Reihenfolge, und was nicht ermittelbar war, steht
als "nicht ermittelt" da -- eine Luecke ist eine Aussage.

Der Fliesstext bleibt unberuehrt: erzeugt wird nur, was zwischen den Marken
steht.
"""
import json, os, re

MARKE_AUF = "<!-- ERFASST:ANFANG -->"
MARKE_ZU = "<!-- ERFASST:ENDE -->"

FELDER = [
    ("cpu", "CPU"), ("cpu_faeden", "Fäden"), ("ram_gb", "Arbeitsspeicher (GB)"),
    ("board", "Board — Hersteller"), ("board_modell", "Board — Modell"),
    ("bios", "BIOS"), ("bios_datum", "BIOS-Datum"),
    ("mikrocode", "Mikrocode (laufend)"), ("mikrocode_start", "Mikrocode beim Start ersetzt von"),
    ("os", "Betriebssystem"), ("kernel", "Kernel"), ("python", "Python"),
    ("wurzel_geraet", "Wurzel-Dateisystem"), ("wurzel_traeger", "Datenträger"),
    ("vulkan_geraet", "Vulkan meldet"), ("vulkan_api", "Vulkan-API"),
    ("vram_leerlauf", "VRAM belegt (Leerlauf)"),
]

def zelle(v):
    return "*nicht ermittelt*" if v in (None, "", "null") else str(v)

def block(d):
    z = ["| | |", "|---|---|"]
    for schluessel, name in FELDER:
        z.append(f"| **{name}** | {zelle(d.get(schluessel))} |")
    k = d.get("karten") or []
    if k:
        z += ["", "**Karten**", "", "| Karte | VRAM | Treiber | Leistungsgrenze |", "|---|---|---|---|"]
        for e in k:
            z.append(f"| {zelle(e.get('name'))} | {zelle(e.get('vram'))} | "
                     f"{zelle(e.get('treiber'))} | {zelle(e.get('leistungsgrenze'))} |")
    pc = d.get("pcie") or []
    if pc:
        z += ["", "**PCIe**", "",
              "| Gerät | Karte zur Brücke | Brücke zur CPU |", "|---|---|---|"]
        for e in pc:
            z.append(f"| {zelle(e.get('name'))} | {zelle(e.get('karte_zur_bruecke'))} | "
                     f"{zelle(e.get('bruecke_zur_cpu'))} |")
    b = d.get("llama_cpp") or []
    z += ["", "**llama.cpp**", ""]
    if b:
        z += ["| Pfad | Stand |", "|---|---|"] + [f"| `{e['pfad']}` | {zelle(e['stand'])} |" for e in b]
    else:
        z.append("*keiner installiert*")
    z += ["", f"*Erfasst {zelle(d.get('erfasst_am'))} mit "
          f"[`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) — "
          f"nicht von Hand geschrieben.*"]
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

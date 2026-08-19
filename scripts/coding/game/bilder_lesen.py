#!/usr/bin/env python3
"""bilder.json -> Zeilen fuer die Bildstufe: datei, breite, hoehe, prompt.

Alles darin kommt vom gemessenen Modell und ist deshalb ungeprueft: der
Dateiname landet auf der Platte, die Groesse in der Bildberechnung.
"""
import json, re, sys

for b in json.load(open(sys.argv[1], encoding="utf-8")):
    # Groesse steht als freier Text da. Auf ein Vielfaches von 64 runden -- das
    # braucht der Bildstapel -- und begrenzen, damit ein 4096er Wunsch nicht die
    # halbe Nacht kostet.
    m = re.findall(r"\d+", b.get("groesse", ""))
    w, h = (int(m[0]), int(m[1])) if len(m) >= 2 else (256, 256)
    rund = lambda x: max(64, min(1024, round(x / 64) * 64))
    # Der Dateiname kommt ebenfalls vom Modell: nur der letzte Namensteil, kein
    # Pfad, kein Ausbruch aus dem Laufverzeichnis.
    d = b.get("datei", "").replace("\\", "/").split("/")[-1]
    if d.startswith(".") or not re.fullmatch(r"[\w.-]+\.(png|jpg|webp)", d, re.I):
        continue
    # Zeilenumbrueche im Prompt wuerden die Zeilenstruktur zerreissen.
    p = " ".join(b.get("prompt", "").split())
    if p:
        print("\t".join([d, str(rund(w)), str(rund(h)), p]))

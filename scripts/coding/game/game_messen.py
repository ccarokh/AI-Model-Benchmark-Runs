#!/usr/bin/env python3
"""Was am Ende im Arbeitsverzeichnis liegt, abzaehlbar machen.

Bewusst wenig. Ob das Spiel SPIELBAR ist, sagt kein Skript -- dafuer gibt es den
Bewertungsserver und einen Menschen. Hier steht nur, was sich ohne Urteil
feststellen laesst: liegt eine index.html da, wie gross ist das Ganze, tauchen
die Bausteine ueberhaupt auf.
"""
import json, os, re, sys

ziel, dauer, abgebrochen = sys.argv[1], sys.argv[2], sys.argv[3]
c = json.load(open(os.path.join(ziel, "lauf.json"), encoding="utf-8"))
arbeit = os.path.join(ziel, "arbeit")

dateien, groesse, text = [], 0, []
for wurzel, _, namen in os.walk(arbeit):
    for n in namen:
        p = os.path.join(wurzel, n)
        rel = os.path.relpath(p, arbeit)
        dateien.append(rel)
        try:
            groesse += os.path.getsize(p)
        except OSError:
            continue
        if os.path.splitext(n)[1].lower() in (".html", ".js", ".css", ".mjs"):
            try:
                text.append(open(p, encoding="utf-8", errors="replace").read())
            except OSError:
                pass

low = "\n".join(text).lower()
hat_index = os.path.isfile(os.path.join(arbeit, "index.html"))

# Abzaehlbar festhalten, WO geschrieben wurde. Dreimal hat ein Modell nach
# /index.html gegriffen statt ins Arbeitsverzeichnis; als blosse Null bei den
# Dateien sieht das aus wie "nichts zustande gebracht" und ist doch etwas
# anderes -- naemlich am falschen Ort abgeliefert.
protokoll = ""
for name in ("agent.log",):
    pfad = os.path.join(ziel, name)
    if os.path.exists(pfad):
        protokoll += open(pfad, encoding="utf-8", errors="replace").read()
ausserhalb = bool(re.search(r"external_directory|Write /[A-Za-z0-9_.-]+\.html", protokoll))

# Die Aufgabe schreibt die Tasten vor: Leertaste springt, Strg duckt. Geprueft
# wird deshalb genau darauf -- eine abweichende Belegung ist eine verfehlte
# Anforderung, keine Geschmacksfrage. Vorher stand die Wahl frei, und dann
# konnte "Huerde nicht ueberspringbar" schlicht heissen, dass der Bewerter die
# falsche Taste gedrueckt hat.
#
# Kein re.X: im ausfuehrlichen Modus wirft Python Leerzeichen aus dem Muster --
# ausgerechnet das Zeichen, um das es bei der Leertaste geht.
SPRUNG = r"""'space'|"space"|'keyw'|"keyw"|\[\s*' '\s*\]|==\s*' '|' '\s*==|"""  \
         r"""(?:keycode|which)\s*===?\s*(?:32|87)"""
DUCKEN = r"""'control|"control|'keys'|"keys"|\bctrlkey\b|"""  \
         r"""(?:keycode|which)\s*===?\s*(?:17|83)"""
sprung = bool(re.search(SPRUNG, low))
ducken = bool(re.search(DUCKEN, low))

# Externe Nachladeversuche sind eine Anforderungsverletzung und werden gezaehlt,
# nicht bewertet.
extern = len(re.findall(r"(?:src|href)\s*=\s*[\"']https?://", low))

spalten = [
    c["lauf"], c["model"], c["beschreibung"], c["harness"], c["runtime"], c["quant"], c.get("aufgabe_id", ""),
    c["temp"], c["maxtok"], c["ctx"], c["template"], c["zeitlimit"],
    abgebrochen, dauer, len(dateien), groesse, hat_index, ausserhalb,
    ("canvas" in low) or ("<svg" in low), sprung, ducken,
    ("score" in low) or ("punkt" in low),
    ("restart" in low) or ("neustart" in low) or ("again" in low),
    bool(re.search(r"speed\s*[+*]=|speed\s*=\s*speed|geschwindigkeit", low)),
    extern,
]
print("\t".join(str(s) for s in spalten))

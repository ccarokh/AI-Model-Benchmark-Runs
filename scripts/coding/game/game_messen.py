#!/usr/bin/env python3
"""Make countable whatever ended up in the working directory.

Deliberately little. Whether the game is PLAYABLE is not for a script to say --
that is what the rating server and a person are for. What stands here is only
what can be established without judgement: is there an index.html, how large is
the whole thing, do the building blocks appear at all.
"""
import json, os, re, sys

ziel, dauer, abgebrochen = sys.argv[1], sys.argv[2], sys.argv[3]
c = json.load(open(os.path.join(ziel, "lauf.json"), encoding="utf-8"))
arbeit = os.path.join(ziel, "arbeit")

# The agents keep their own bookkeeping in the working directory: Crush a
# .crush/ with a database and a log, Aider two .aider.* files, others nothing at
# all. Counting those measures the harness instead of the result -- and the
# table would have made Crush and Aider look systematically more productive than
# OpenCode. A run that delivered NOTHING came out as "3 files".
def eigenkram(rel):
    teile = rel.split(os.sep)
    return any(t.startswith(".") for t in teile)

dateien, groesse, text = [], 0, []
uebersprungen = 0
# Do NOT prune while descending: otherwise the contents of .crush/ are never
# seen and the count reports zero instead of three. What gets skipped should
# stand there as a number.
for wurzel, verz, namen in os.walk(arbeit):
    for n in namen:
        p = os.path.join(wurzel, n)
        rel = os.path.relpath(p, arbeit)
        if eigenkram(rel):
            uebersprungen += 1
            continue
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

# The pre-check answers mechanically what comes before any rating: does it run
# at all. Two JSON lines, one per stage. If the file is missing the columns stay
# empty -- a broken tool must not make a model look bad.
vor = {}
pfad = os.path.join(ziel, "vorpruefung.json")
if os.path.exists(pfad):
    for zeile in open(pfad, encoding="utf-8"):
        zeile = zeile.strip()
        if not zeile:
            continue
        try:
            vor.update(json.loads(zeile))
        except ValueError:
            pass

def zahl(k):
    v = vor.get(k)
    return len(v) if isinstance(v, list) else ("" if v is None else v)

low = "\n".join(text).lower()
hat_index = os.path.isfile(os.path.join(arbeit, "index.html"))

# Record WHERE it wrote, countably. Three times a model reached for
# /index.html instead of the working directory; as a plain zero in the file
# count that looks like "produced nothing" while it is something else --
# delivered to the wrong place.
protokoll = ""
for name in ("agent.log",):
    pfad = os.path.join(ziel, name)
    if os.path.exists(pfad):
        protokoll += open(pfad, encoding="utf-8", errors="replace").read()
ausserhalb = bool(re.search(r"external_directory|Write /[A-Za-z0-9_.-]+\.html", protokoll))

# The task prescribes the keys. So that is what is checked -- a different
# binding is a missed requirement, not a matter of taste. The choice used to be
# free, and then "hurdle not jumpable" could simply mean the rater pressed the
# wrong key.
#
# No re.X here: in verbose mode Python drops whitespace from the pattern -- of
# all characters, the one the space bar is about.
SPRUNG = r"""'space'|"space"|'keyw'|"keyw"|\[\s*' '\s*\]|==\s*' '|' '\s*==|"""  \
         r"""(?:keycode|which)\s*===?\s*(?:32|87)"""
DUCKEN = r"""'control|"control|'keys'|"keys"|\bctrlkey\b|"""  \
         r"""(?:keycode|which)\s*===?\s*(?:17|83)"""
sprung = bool(re.search(SPRUNG, low))
ducken = bool(re.search(DUCKEN, low))

# External loads violate a requirement and are counted, not judged.
extern = len(re.findall(r"(?:src|href)\s*=\s*[\"']https?://", low))

spalten = [
    c["lauf"], c["model"], c["beschreibung"], c["harness"], c["runtime"], c["quant"], c.get("aufgabe_id", ""),
    c["temp"], c["maxtok"], c["ctx"], c["template"], c["zeitlimit"],
    abgebrochen, dauer, len(dateien), groesse, hat_index, ausserhalb, uebersprungen,
    vor.get("syntax_ok", ""), vor.get("geoeffnet", ""),
    zahl("laufzeit_fehler"), zahl("konsole_fehler"), zahl("fehlende_dateien"),
    "" if vor.get("canvas_bemalt") is None else vor.get("canvas_bemalt"),
    ("canvas" in low) or ("<svg" in low), sprung, ducken,
    ("score" in low) or ("punkt" in low),
    ("restart" in low) or ("neustart" in low) or ("again" in low),
    bool(re.search(r"speed\s*[+*]=|speed\s*=\s*speed|geschwindigkeit", low)),
    extern,
]
print("\t".join(str(s) for s in spalten))

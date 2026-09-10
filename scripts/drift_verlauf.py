#!/usr/bin/env python3
"""Turn the drift check's log into a time series.

The check has run nightly since 23.08. and writes only prose to a log that is
now 1.1 MB. Every number it ever measured is in there, and none of it is
readable as a series -- so the question the check exists to answer, "has
anything changed", could only be answered by grepping.

This reads the log rather than changing the check. The check is careful, it has
earned its logic the hard way, and a parser cannot break it.
"""
import re, sys, pathlib

LOG = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/root/eval/upstream_drift.log")
OUT = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "/root/eval/drift_verlauf.tsv")
JAHR = 2026

kopf = re.compile(r"^\[(\d\d)\.(\d\d)\. (\d\d:\d\d:\d\d)\]\s+(\S+) : (.*)$")
zeilen = {}
for z in LOG.read_text(errors="replace").splitlines():
    m = kopf.match(z.strip())
    if not m:
        continue
    tag, monat, uhr, build, rest = m.groups()
    wann = f"{JAHR}-{monat}-{tag}T{uhr}"
    werte = {}
    for k, v in re.findall(r"([A-Za-z0-9@_]+)=([0-9.]+)", rest):
        werte[k] = v
    h = re.search(r"Ausgabe-Hash\s+(\S+)", rest)
    if h:
        werte["hash"] = h.group(1)
    if not werte:
        continue
    # One row per run and build; later lines of the same run fill in.
    schluessel = (wann[:10], build)
    zeilen.setdefault(schluessel, {"zeit": wann, "build": build}).update(werte)

spalten = ["datum", "build", "pp2048", "tg128", "pp4096@d8192", "tg256", "hash"]
with OUT.open("w") as f:
    f.write("\t".join(spalten) + "\n")
    for (datum, build), w in sorted(zeilen.items()):
        f.write("\t".join([datum, build] + [w.get(c, "") for c in spalten[2:]]) + "\n")
print(f"  {len(zeilen)} Zeilen nach {OUT}")

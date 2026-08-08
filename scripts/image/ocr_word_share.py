#!/usr/bin/env python3
"""Text im Bild messen: wie viel des erzeugten Textes sind ueberhaupt Woerter.

Zwei Faelle, zwei Metriken:
  Aufgabe 02 fordert eine bestimmte Zeichenkette -> Editabstand (ocr_test.py).
  Aufgabe 05 fordert nur "labeled boxes"        -> Wortanteil, hier.

MEHRERE SEGMENTIERUNGSMODI, und der beste zaehlt. Grund: mit fest eingestelltem
--psm 11 fand Tesseract im FLUX-Schema NULL Tokens, waehrend --psm 6 im selben
Bild "TWO STAGE WATER ... STAGIE STAGEE" liest. Ein fester Modus haette hier
"kein Text vorhanden" gemeldet, obwohl Text da ist -- das waere ein Messfehler
gewesen, kein Befund.
"""
import subprocess, re, sys

PSM = ("3", "4", "6", "11", "12")

def ocr(pfad, psm):
    r = subprocess.run(["tesseract", pfad, "stdout", "-l", "deu+eng", "--psm", psm],
                       capture_output=True, text=True)
    return r.stdout

def tokens(text):
    return [t for t in re.findall(r"[A-Za-zÄÖÜäöüß]+", text) if len(t) >= 3]

def bekannt(toks):
    """hunspell -l gibt die UNbekannten aus. Unbekannt = in KEINEM Woerterbuch."""
    if not toks:
        return [], []
    unbek = None
    for wb in ("en_US", "de_DE"):
        r = subprocess.run(["hunspell", "-d", wb, "-l"],
                           input="\n".join(toks), capture_output=True, text=True)
        u = set(w.strip() for w in r.stdout.split() if w.strip())
        unbek = u if unbek is None else (unbek & u)
    return [t for t in toks if t not in unbek], sorted(unbek)

for pfad in sys.argv[1:]:
    best = None
    for psm in PSM:
        toks = tokens(ocr(pfad, psm))
        ok, schrott = bekannt(toks)
        # bester Modus = meiste erkannte Woerter, bei Gleichstand meiste Tokens
        kennzahl = (len(ok), len(toks))
        if best is None or kennzahl > best[0]:
            best = (kennzahl, psm, toks, ok, schrott)
    (_, psm, toks, ok, schrott) = best
    quote = f"{len(ok)}/{len(toks)}"
    anteil = f"{100*len(ok)/len(toks):.0f} %" if toks else "—"
    print(f"{pfad.split('/')[-1]:<30} psm {psm:<3} Woerter {quote:>6} = {anteil:>5}   kein Wort: {', '.join(schrott[:7])}")

#!/usr/bin/env python3
"""Cross-check: derive every expected answer again from the document TEXT alone.

generate.py computes the answers from its internal facts. This script ignores
those facts, parses the rendered archive the way a careful reader would, and
must arrive at the same items and totals -- otherwise a fact the answer depends
on never made it into a document, and the question would be unanswerable.

Usage: verify.py <archive-dir>
"""
import datetime as dt, json, os, re, sys

d = sys.argv[1]
A = [json.loads(l) for l in open(os.path.join(d, "archive.jsonl"))]
Q = [json.loads(l) for l in open(os.path.join(d, "questions.jsonl"))]


def num(s):
    return float(s.replace(".", "").replace(",", ".").replace("€", "").strip())


def date(s):
    return dt.datetime.strptime(s, "%d.%m.%Y").date()


AMT = r"([\d.]+,\d\d) €"
by_title = lambda p: [x for x in A if x["title"].startswith(p)]
derived = {}

# subscriptions
start, price, changes, end = {}, {}, {}, {}
for x in by_title("Bestätigung Ihres Abonnements bei "):
    n = x["title"].split(" bei ", 1)[1]
    start[n] = date(re.search(r"beginnt am (\S+)\.", x["text"]).group(1))
    price[n] = num(re.search(r"Monatlicher Beitrag: " + AMT, x["text"]).group(1))
for x in A:
    if x["title"].endswith(": Anpassung Ihres Monatsbeitrags"):
        n = x["title"].split(":")[0]
        m = re.search(r"Ab dem (\S+) beträgt Ihr monatlicher Beitrag " + AMT, x["text"])
        changes.setdefault(n, []).append((date(m.group(1)), num(m.group(2))))
for x in by_title("Kündigungsbestätigung "):
    end[x["title"].split(" ", 1)[1]] = date(re.search(r"endet zum (\S+)\.", x["text"]).group(1))
for q in Q:
    if q["family"] == "abo":
        at = date(re.search(r"am (\S+) noch", q["question"]).group(1))
        act = {}
        for n in start:
            if start[n] <= at and (n not in end or end[n] >= at):
                p = price[n]
                for eff, newp in sorted(changes.get(n, [])):
                    if eff <= at:
                        p = newp
                act[n] = p
        derived[q["id"]] = (sorted(act), round(sum(act.values()), 2))

# outgoing invoices against incoming payments on the statements
inv = {}
for x in by_title("Ausgangsrechnung "):
    m = re.search(r"RECHNUNG Nr\. (\S+)\nRechnungsdatum: (\S+)", x["text"])
    inv[m.group(1)] = (date(m.group(2)), num(re.search(r"Rechnungsbetrag: " + AMT, x["text"]).group(1)))
pays = []
for x in by_title("Kontoauszug "):
    for line in x["text"].splitlines():
        m = re.match(r"(\d\d\.\d\d\.\d{4})\s+Gutschrift .* Verwendungszweck (RE-\S+)\s+\+([\d.]+,\d\d) €", line)
        if m:
            pays.append((date(m.group(1)), m.group(2), num(m.group(3))))
for q in Q:
    if q["family"] == "offene_rechnungen":
        half, y = re.search(r"(\d)\. Halbjahr (\d{4})", q["question"]).groups()
        at = date(re.search(r"am (\S+) noch", q["question"]).group(1))
        lo, hi = (dt.date(int(y), 1, 1), dt.date(int(y), 6, 30)) if half == "1" else (dt.date(int(y), 7, 1), dt.date(int(y), 12, 31))
        op = {}
        for n, (dte, gross) in inv.items():
            if lo <= dte <= hi:
                rest = round(gross - sum(a for p, k, a in pays if k == n and p <= at), 2)
                if rest > 0.005:
                    op[n] = rest
        derived[q["id"]] = (sorted(op), round(sum(op.values()), 2))

# medical bills against the insurers' statements
bills, submitted = {}, set()
for x in A:
    m = re.search(r"Rechnung Nr\. (\S+)  ·  Datum: (\S+)\n\nPatient/in: (\w+) Brandt", x["text"])
    if m:
        bills[m.group(1)] = (m.group(3), date(m.group(2)).year, num(re.search(r"Rechnungsbetrag: " + AMT, x["text"]).group(1)))
for x in by_title("Leistungsabrechnung "):
    submitted |= set(re.findall(r"Rechnung Nr\. (\S+) vom", x["text"]))
for q in Q:
    if q["family"] == "arztrechnungen":
        person, y = re.search(r"für (\w+) Brandt aus dem Jahr (\d{4})", q["question"]).groups()
        miss = {n: a for n, (p, yy, a) in bills.items() if p == person and yy == int(y) and n not in submitted}
        derived[q["id"]] = (sorted(miss), round(sum(miss.values()), 2))

# quotes
for q in Q:
    if q["family"] == "angebote":
        proj = re.search(r"„(.+)“", q["question"]).group(1)
        decide = date(re.search(r"am (\S+) das", q["question"]).group(1))
        offers, dead = [], set()
        for x in by_title("Angebot "):
            if not x["title"].endswith(": " + proj):
                continue
            t = x["text"]
            n, dte = re.search(r"ANGEBOT Nr\. (\S+)  ·  Datum: (\S+)", t).groups()
            valid = date(re.search(r"gültig bis zum (\S+)\.", t).group(1))
            net = num(re.search(r"(?:Summe netto: |Angebotssumme: )" + AMT, t).group(1))
            r = re.search(r"ersetzt unser Angebot Nr\. (\S+),", t)
            if r:
                dead.add(r.group(1))
            offers.append((x["title"].split(": ")[0][len("Angebot "):], n, date(dte), valid, net))
        ok = [o for o in offers if o[1] not in dead and o[2] <= decide <= o[3]]
        best = min(ok, key=lambda o: o[4])
        derived[q["id"]] = ([best[0]], round(best[4] * 1.19, 2))

# deposits
for q in Q:
    if q["family"] == "kaution":
        name = re.search(r"steht (.+) nach dem Auszug", q["question"]).group(1)
        dep = num(re.search(r"Kaution: " + AMT, [x for x in by_title("Mietvertrag ") if x["title"].endswith("– " + name)][0]["text"]).group(1))
        dmg = sum(num(a) for x in by_title("Übergabeprotokoll ") if x["title"].endswith("– " + name)
                  for a in re.findall(r"Kosten " + AMT, x["text"]))
        bk = 0.0
        for x in A:
            if x["title"].startswith("Betriebskostenabrechnung") and x["title"].endswith("– " + name):
                g = re.search(r"Guthaben zu Ihren Gunsten von " + AMT, x["text"])
                n = re.search(r"Nachzahlung von " + AMT, x["text"])
                bk += -num(g.group(1)) if g else num(n.group(1))
        derived[q["id"]] = ([], round(dep - dmg - bk, 2))

# contractor invoices and credit notes
hr, credit = {}, {}
for x in by_title("Rechnung "):
    m = re.search(r"Rechnung (HR-\S+)  ·  (\S+)\nKundin: Katrin Brandt\nEinsatzort: (.+)\n", x["text"])
    if m:
        hr[m.group(1)] = (date(m.group(2)).year, m.group(3), num(re.search(r"Rechnungsbetrag \(inkl\. MwSt\.\): " + AMT, x["text"]).group(1)))
for x in by_title("Gutschrift "):
    m = re.search(r"GUTSCHRIFT zu Rechnung (HR-\S+)", x["text"])
    credit[m.group(1)] = num(re.search(r"schreiben wir Ihnen " + AMT, x["text"]).group(1))
for q in Q:
    if q["family"] == "handwerker":
        flat, y = re.search(r"betreffen (Wohnung \d) .* im Jahr (\d{4})", q["question"]).groups()
        sel = {n: a - credit.get(n, 0.0) for n, (yy, place, a) in hr.items() if yy == int(y) and place.startswith(flat + " ")}
        derived[q["id"]] = (sorted(sel), round(sum(sel.values()), 2))

# lookups: the value has to stand in at least one document
alltext = "\n".join(x["text"] for x in A)
bad = 0
for q in Q:
    if q["kind"] == "lookup":
        v = q["value"]
        s = (f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".") + " €") if q["value_kind"] == "amount" else \
            (dt.date.fromisoformat(v).strftime("%d.%m.%Y") if q["value_kind"] == "date" else v)
        if s not in alltext:
            print(f"LOOKUP {q['id']}: '{s}' steht in keinem Dokument"); bad += 1
    elif q["kind"] == "reconcile":
        exp = (q["items"], q["total"])
        got = derived.get(q["id"])
        if got is None or got[0] != exp[0] or abs(got[1] - exp[1]) > 0.005:
            print(f"ABWEICHUNG {q['id']}: erwartet {exp}, aus dem Text {got}"); bad += 1
print(f"{sum(1 for q in Q if q['kind'] != 'absent')} questions checked against the text, {bad} mismatches")
sys.exit(1 if bad else 0)

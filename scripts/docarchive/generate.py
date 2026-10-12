#!/usr/bin/env python3
"""Fictional German household archive for the document-reconciliation test.

One persona -- Katrin Brandt, freelance designer in Leverkusen, landlady of a
four-flat house, two children -- and two years of her paperwork (2024-2025, plus
the contracts and sign-ups from before that still matter). The script fixes the
facts first and renders the documents from them, so every answer is computed,
not judged: the questions file carries the expected items and totals.

Question kinds:
  lookup     one fact from one document
  reconcile  facts spread over many documents, combined and computed
  absent     the answer is not in the archive; the model has to say so

Everything is fictional: people, companies, insurers, addresses. Same seed, same
archive.

Usage: generate.py <out-dir> [--seed N]
"""
import datetime as dt, json, os, random, sys

D = dt.date
SEED = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else 20261012
R = random.Random(SEED)

OWNER = "Katrin Brandt"
HOME = "Lindenstraße 14, 51373 Leverkusen"
HOUSE = "Bergstraße 22, 51379 Leverkusen"
FLATS = {1: "Wohnung 1 (EG links)", 2: "Wohnung 2 (EG rechts)", 3: "Wohnung 3 (OG links)", 4: "Wohnung 4 (OG rechts)"}
IBAN_OWN = "DE41 3705 0198 0012 3456 78"

docs, questions = [], []


def eur(x):
    s = f"{x:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return s + " €"


def dd(d):
    return d.strftime("%d.%m.%Y")


def add(date, typ, title, text):
    docs.append({"date": date.isoformat(), "type": typ, "title": title, "text": text.strip() + "\n"})


def month_end(y, m):
    return (D(y + (m == 12), m % 12 + 1, 1) - dt.timedelta(days=1))


def months(start, end):
    y, m = start.year, start.month
    while (y, m) <= (end.year, end.month):
        yield y, m
        y, m = (y + 1, 1) if m == 12 else (y, m + 1)


bank = []  # (date, text, amount) -> rendered into monthly statements

# ---------------------------------------------------------------- subscriptions
SUBS = [
    # name, start, price, [(effective, new price)], end (None = running), customer no
    ("Streamflix", D(2022, 3, 1), 12.99, [(D(2024, 7, 1), 13.99), (D(2025, 7, 1), 15.49)], None),
    ("Tonfabrik Music", D(2023, 5, 1), 10.99, [(D(2025, 2, 1), 11.99)], D(2025, 8, 31)),
    ("Wolkenspeicher 2 TB", D(2021, 9, 1), 9.99, [], None),
    ("Tagesbote Digital", D(2023, 1, 1), 24.90, [(D(2024, 4, 1), 26.90)], D(2024, 9, 30)),
    ("FitPlus Studio", D(2024, 2, 1), 34.90, [], D(2025, 1, 31)),
    ("Kochbox Wochenmenü", D(2024, 3, 1), 59.96, [], D(2024, 5, 31)),
    ("Hörwelt Hörbücher", D(2023, 11, 1), 9.95, [(D(2025, 4, 1), 10.95)], None),
    ("Spielzeit Kids", D(2024, 6, 1), 6.99, [], None),
    ("SicherNetz VPN", D(2024, 10, 1), 4.99, [], D(2025, 9, 30)),
    ("Fotowerk Pro", D(2022, 6, 1), 23.79, [(D(2024, 1, 1), 26.18)], None),
    ("Sprachpilot Spanisch", D(2025, 1, 1), 12.99, [], D(2025, 6, 30)),
    ("Lesezirkel Plus", D(2025, 3, 1), 7.50, [], None),
    ("Mobilfunk Zusatzkarte", D(2024, 8, 1), 9.99, [], None),
    ("Bürosoftware Office", D(2022, 1, 1), 10.00, [(D(2025, 1, 1), 12.99)], None),
]
cust = {}
for name, start, price, changes, end in SUBS:
    cust[name] = f"KD-{R.randint(100000, 999999)}"
    sign = start - dt.timedelta(days=R.randint(3, 12))
    add(sign, "email", f"Bestätigung Ihres Abonnements bei {name}",
        f"""Von: service@{name.split()[0].lower()}.example
An: k.brandt@example.de
Betreff: Willkommen bei {name} – Bestätigung Ihres Abonnements

Hallo Katrin Brandt,

vielen Dank für Ihre Bestellung. Ihr Abonnement „{name}“ beginnt am {dd(start)}.
Monatlicher Beitrag: {eur(price)} (inkl. MwSt.), Abbuchung jeweils zum Monatsanfang per Lastschrift.
Ihre Kundennummer: {cust[name]}
Mindestlaufzeit: 1 Monat, danach monatlich kündbar.

Ihr {name}-Team""")
    for eff, newp in changes:
        add(eff - dt.timedelta(days=R.randint(30, 45)), "brief", f"{name}: Anpassung Ihres Monatsbeitrags",
            f"""{name} – Kundenservice
Kundennummer {cust[name]}

Sehr geehrte Frau Brandt,

wegen gestiegener Kosten passen wir die Preise an. Ab dem {dd(eff)} beträgt Ihr monatlicher Beitrag {eur(newp)} statt bisher.
Sie haben ein Sonderkündigungsrecht bis zum Inkrafttreten der Änderung. Wenn Sie nichts unternehmen, läuft Ihr Abonnement zum neuen Preis weiter.

Mit freundlichen Grüßen
{name}""")
    if end:
        add(end - dt.timedelta(days=R.randint(10, 40)), "email", f"Kündigungsbestätigung {name}",
            f"""Von: kuendigung@{name.split()[0].lower()}.example
Betreff: Ihre Kündigung – Kundennummer {cust[name]}

Hallo Katrin Brandt,

wir bestätigen den Eingang Ihrer Kündigung. Ihr Abonnement „{name}“ endet zum {dd(end)}. Bis dahin können Sie alle Leistungen wie gewohnt nutzen; die letzte Abbuchung erfolgt für den Monat {end.strftime('%m/%Y')}.

Schade, dass Sie gehen.
Ihr {name}-Team""")
    for y, m in months(max(start, D(2024, 1, 1)), min(end or D(2025, 12, 31), D(2025, 12, 31))):
        day = D(y, m, R.randint(1, 4))
        p = price
        for eff, newp in changes:
            if eff <= D(y, m, 1):
                p = newp
        bank.append((day, f"Lastschrift {name} {cust[name]} Beitrag {m:02d}/{y}", -p))


def subs_active(at):
    out = {}
    for name, start, price, changes, end in SUBS:
        if start <= at and (end is None or end >= at):
            p = price
            for eff, newp in changes:
                if eff <= at:
                    p = newp
            out[name] = p
    return out


for at in [D(2024, 6, 30), D(2024, 12, 31), D(2025, 6, 30), D(2025, 12, 31)]:
    act = subs_active(at)
    questions.append({"id": f"abo-{at.isoformat()}", "kind": "reconcile", "family": "abo",
                      "question": f"Welche Abonnements liefen am {dd(at)} noch, und wie viel kosteten sie zusammen pro Monat (Stand {dd(at)})?",
                      "items": sorted(act), "universe": sorted(s[0] for s in SUBS), "total": round(sum(act.values()), 2)})

# ------------------------------------------------------------ outgoing invoices
CLIENTS = ["Hoffmann Feinkost GmbH", "Rheinblick Immobilien KG", "Kita Sonnenschein e.V.", "Weber & Söhne Metallbau",
           "Praxis Dr. Albers", "Buchhandlung Seitenwind", "Café Mühlenhof", "TechNova Solutions GmbH"]
JOBS = ["Logo-Überarbeitung", "Flyer A5, 2 Varianten", "Website-Grafiken", "Geschäftsausstattung", "Jahresbericht Layout",
        "Social-Media-Paket", "Messestand-Grafik", "Speisekarte Neugestaltung", "Plakatserie", "Produktfotos Retusche"]
invoices = []
n_by_year = {2024: 0, 2025: 0}
for y, m in months(D(2024, 1, 1), D(2025, 12, 31)):
    for k in range(2 if R.random() < 0.7 else 3):
        n_by_year[y] += 1
        num = f"RE-{y}-{n_by_year[y]:03d}"
        date = D(y, m, R.randint(2, 26))
        net = round(R.choice([180, 240, 320, 450, 600, 780, 950, 1200, 1450, 1800]) * R.choice([1, 1, 1.25, 0.8]), 2)
        invoices.append({"num": num, "date": date, "client": R.choice(CLIENTS), "job": R.choice(JOBS),
                         "net": net, "gross": round(net * 1.19, 2), "paid": []})
# payment behaviour, decided per invoice: most pay in full, some late, some in part, some not at all
for inv in invoices:
    r = R.random()
    due = inv["date"] + dt.timedelta(days=14)
    if r < 0.62:
        inv["paid"].append((due + dt.timedelta(days=R.randint(-8, 10)), inv["gross"]))
    elif r < 0.74:
        inv["paid"].append((due + dt.timedelta(days=R.randint(60, 140)), inv["gross"]))
    elif r < 0.86:
        part = round(inv["gross"] * R.choice([0.5, 0.4, 0.6]), 2)
        inv["paid"].append((due + dt.timedelta(days=R.randint(0, 20)), part))
        if R.random() < 0.5:
            inv["paid"].append((due + dt.timedelta(days=R.randint(90, 160)), round(inv["gross"] - part, 2)))
    # else: never paid within the archive
# every question period gets at least two invoices that are still open on its key date
for lo, hi in [(D(2024, 1, 1), D(2024, 6, 30)), (D(2024, 7, 1), D(2024, 12, 31)), (D(2025, 1, 1), D(2025, 6, 30)), (D(2025, 7, 1), D(2025, 12, 31))]:
    period = [i for i in invoices if lo <= i["date"] <= hi]
    while sum(1 for i in period if not i["paid"]) + sum(1 for i in period if i["paid"] and len(i["paid"]) == 1 and i["paid"][0][1] < i["gross"]) < 2:
        R.choice([i for i in period if i["paid"] and i["paid"][0][1] == i["gross"]])["paid"] = []
for inv in invoices:
    lines = f"""Brandt Grafikdesign · Katrin Brandt · {HOME}
Steuernummer 230/5123/4567 · IBAN {IBAN_OWN}

An: {inv['client']}

RECHNUNG Nr. {inv['num']}
Rechnungsdatum: {dd(inv['date'])}

Leistung: {inv['job']}
Nettobetrag: {eur(inv['net'])}
zzgl. 19 % USt.: {eur(round(inv['gross'] - inv['net'], 2))}
Rechnungsbetrag: {eur(inv['gross'])}

Zahlbar innerhalb von 14 Tagen ohne Abzug. Bitte geben Sie die Rechnungsnummer als Verwendungszweck an."""
    add(inv["date"], "rechnung_aus", f"Ausgangsrechnung {inv['num']} an {inv['client']}", lines)
    for pd, amt in inv["paid"]:
        if pd <= D(2025, 12, 31):
            bank.append((pd, f"Gutschrift {inv['client']} Verwendungszweck {inv['num']}", amt))
    paid_by = lambda when: sum(a for p, a in inv["paid"] if p <= when)
    # a reminder for some invoices still open six weeks on
    rem = inv["date"] + dt.timedelta(days=42)
    if rem <= D(2025, 12, 31) and paid_by(rem) < inv["gross"] - 0.005 and R.random() < 0.6:
        add(rem, "brief", f"Zahlungserinnerung zu {inv['num']}",
            f"""Brandt Grafikdesign · {HOME}

An: {inv['client']}

Zahlungserinnerung

Sehr geehrte Damen und Herren,

zu meiner Rechnung {inv['num']} vom {dd(inv['date'])} über {eur(inv['gross'])} ist bisher {'ein Betrag von ' + eur(paid_by(rem)) + ' eingegangen' if paid_by(rem) else 'keine Zahlung eingegangen'}. Ich bitte um Überweisung des offenen Betrags von {eur(round(inv['gross'] - paid_by(rem), 2))} bis zum {dd(rem + dt.timedelta(days=10))}.

Mit freundlichen Grüßen
Katrin Brandt""")

for (y, half, at) in [(2024, 1, D(2024, 9, 30)), (2024, 2, D(2025, 3, 31)), (2025, 1, D(2025, 9, 30)), (2025, 2, D(2025, 12, 31))]:
    lo, hi = (D(y, 1, 1), D(y, 6, 30)) if half == 1 else (D(y, 7, 1), D(y, 12, 31))
    open_ = {}
    for inv in invoices:
        if lo <= inv["date"] <= hi:
            rest = round(inv["gross"] - sum(a for p, a in inv["paid"] if p <= at), 2)
            if rest > 0.005:
                open_[inv["num"]] = rest
    questions.append({"id": f"offen-{y}-h{half}", "kind": "reconcile", "family": "offene_rechnungen",
                      "question": f"Welche meiner Ausgangsrechnungen aus dem {half}. Halbjahr {y} waren am {dd(at)} noch nicht (vollständig) bezahlt, und wie hoch war der insgesamt noch offene Betrag zu diesem Stichtag?",
                      "items": sorted(open_), "universe": sorted(i["num"] for i in invoices), "total": round(sum(open_.values()), 2)})

# ------------------------------------------------------------- medical bills
INSURER = {"Katrin": "Auxilia Krankenversicherung AG", "Mia": "Dentalis Zahnzusatz", "Jonas": "Dentalis Zahnzusatz"}
PRAX = {"Katrin": ["Hausarztpraxis Dr. Kessler", "Labor Rhein-Diagnostik", "Physiotherapie Bewegt", "Zahnarztpraxis Dr. Yilmaz", "Hautarztpraxis Dr. Sommer"],
        "Mia": ["Kieferorthopädie Dr. Lange", "Zahnarztpraxis Dr. Yilmaz"], "Jonas": ["Zahnarztpraxis Dr. Yilmaz", "Kieferorthopädie Dr. Lange"]}
bills = []
bn = 0
for person, per_year in [("Katrin", 7), ("Mia", 3), ("Jonas", 2)]:
    for y in (2024, 2025):
        for k in range(per_year):
            bn += 1
            date = D(y, R.randint(1, 11), R.randint(1, 28))
            bills.append({"person": person, "date": date, "praxis": R.choice(PRAX[person]), "num": f"{date.year % 100}{R.randint(1000, 9999)}-{bn:02d}",
                          "amount": round(R.uniform(38, 640), 2), "submitted": None})
# submission in quarterly batches; a fixed number per person and year is never submitted.
# Jonas 2024 has none left over -- a question whose correct answer is "none".
NOT_SUBMITTED = {("Katrin", 2024): 2, ("Katrin", 2025): 3, ("Mia", 2024): 1, ("Mia", 2025): 1, ("Jonas", 2024): 0, ("Jonas", 2025): 1}
for (person, y), k in NOT_SUBMITTED.items():
    group = [b for b in bills if b["person"] == person and b["date"].year == y]
    skip = R.sample(group, k)
    for b in group:
        if b not in skip:
            b["submitted"] = b["date"] + dt.timedelta(days=R.randint(20, 75))
for b in bills:
    full = {"Katrin": "Katrin Brandt", "Mia": "Mia Brandt", "Jonas": "Jonas Brandt"}[b["person"]]
    add(b["date"], "rechnung_ein", f"Rechnung {b['praxis']} ({full})",
        f"""{b['praxis']}
Rechnung Nr. {b['num']}  ·  Datum: {dd(b['date'])}

Patient/in: {full}, {HOME}
Behandlung gemäß GOÄ/GOZ, Einzelaufstellung anbei.

Rechnungsbetrag: {eur(b['amount'])}
Bitte überweisen Sie den Betrag innerhalb von 30 Tagen. Diese Rechnung ist zur Vorlage bei Ihrer Versicherung geeignet.""")
by_batch = {}
for b in bills:
    if b["submitted"] and b["submitted"] <= D(2025, 12, 31):
        key = (INSURER[b["person"]], b["submitted"].year, (b["submitted"].month - 1) // 3)
        by_batch.setdefault(key, []).append(b)
for (ins, y, q), bs in sorted(by_batch.items()):
    d = max(b["submitted"] for b in bs) + dt.timedelta(days=12)
    rows = "\n".join(f"- {b['praxis']}, Rechnung Nr. {b['num']} vom {dd(b['date'])}, Patient/in {b['person']} Brandt: eingereicht {eur(b['amount'])}, erstattet {eur(round(b['amount'] * (0.8 if ins.startswith('Dentalis') else 1.0), 2))}"
                     for b in sorted(bs, key=lambda b: b["date"]))
    add(d, "brief", f"Leistungsabrechnung {ins}",
        f"""{ins}
Leistungsabrechnung vom {dd(d)}
Versicherungsnehmerin: Katrin Brandt

Wir haben folgende Belege erhalten und abgerechnet:
{rows}

Der Erstattungsbetrag wird in den nächsten Tagen auf Ihr Konto überwiesen.""")
for person in ("Katrin", "Mia", "Jonas"):
    for y in (2024, 2025):
        miss = {b["num"]: b["amount"] for b in bills if b["person"] == person and b["date"].year == y
                and not (b["submitted"] and b["submitted"] <= D(2025, 12, 31))}
        questions.append({"id": f"arzt-{person.lower()}-{y}", "kind": "reconcile", "family": "arztrechnungen",
                          "question": f"Welche Arztrechnungen für {person} Brandt aus dem Jahr {y} sind bisher nicht bei der Versicherung eingereicht worden (Stand 31.12.2025), und wie hoch ist ihre Summe?",
                          "items": sorted(miss), "universe": sorted(b["num"] for b in bills), "total": round(sum(miss.values()), 2)})

# --------------------------------------------------------------------- quotes
PROJECTS = [
    ("Dachsanierung Bergstraße 22", D(2024, 4, 15), ["Dachdeckerei Krämer", "Bedachungen Özdemir & Partner", "Dach-Meister Schulte"]),
    ("Austausch der Gasheizung Bergstraße 22", D(2024, 10, 1), ["Haustechnik Neumann", "Wärme & Bad Lorenz", "SHK Brückner GmbH"]),
    ("Neue Fenster Wohnung 3", D(2025, 3, 15), ["Fensterbau Hartmann", "Glas & Rahmen Petersen", "Holzfenster Vogt"]),
    ("Anstrich Treppenhaus Bergstraße 22", D(2025, 8, 20), ["Malerbetrieb Wolff", "Farbe & Raum Keller", "Malermeister Arslan"]),
]
for pi, (proj, decide, firms) in enumerate(PROJECTS):
    base = {0: 18500, 1: 14200, 2: 6800, 3: 4300}[pi]
    offers = []  # each: firm, num, date, valid_until, net, vat_shown, superseded
    for fi, firm in enumerate(firms):
        net = round(base * R.uniform(0.85, 1.15), 2)
        date = decide - dt.timedelta(days=R.randint(20, 60))
        offers.append({"firm": firm, "num": f"AN-{decide.year}-{pi + 1}{fi + 1}1", "date": date,
                       "valid": date + dt.timedelta(days=R.choice([30, 60, 90])), "net": net, "gross_shown": R.random() < 0.5, "sup": False})
    # the traps, one per project kind, so the naive cheapest is wrong:
    cheapest = min(offers, key=lambda o: o["net"])
    if pi in (0, 2):   # the cheapest has expired by the decision date
        cheapest["date"] = decide - dt.timedelta(days=75)
        cheapest["valid"] = decide - dt.timedelta(days=15)
    if pi in (1, 3):   # one firm revised its offer upwards; the old one is superseded
        rev = cheapest
        rev["sup"] = True
        offers.append({"firm": rev["firm"], "num": rev["num"][:-1] + "2", "date": rev["date"] + dt.timedelta(days=12),
                       "valid": decide + dt.timedelta(days=30), "net": round(rev["net"] * 1.18, 2), "gross_shown": False, "sup": False, "replaces": rev["num"]})
    for o in offers:
        o["valid"] = max(o["valid"], decide + dt.timedelta(days=5)) if not (pi in (0, 2) and o is cheapest) else o["valid"]
        gross = round(o["net"] * 1.19, 2)
        price = (f"Summe netto: {eur(o['net'])}\nzzgl. 19 % MwSt.: {eur(round(gross - o['net'], 2))}\nGesamtbetrag brutto: {eur(gross)}"
                 if o["gross_shown"] else f"Angebotssumme: {eur(o['net'])} netto, zuzüglich der gesetzlichen Mehrwertsteuer (19 %).")
        repl = f"\nDieses Angebot ersetzt unser Angebot Nr. {o['replaces']}, das damit hinfällig ist. Grund: geänderte Materialpreise.\n" if o.get("replaces") else ""
        add(o["date"], "angebot", f"Angebot {o['firm']}: {proj}",
            f"""{o['firm']}
ANGEBOT Nr. {o['num']}  ·  Datum: {dd(o['date'])}
Bauvorhaben: {proj}
Auftraggeberin: Katrin Brandt, {HOME}
{repl}
Leistungen laut beiliegendem Leistungsverzeichnis, inklusive Material, Entsorgung und Baustelleneinrichtung.
{price}

Dieses Angebot ist gültig bis zum {dd(o['valid'])}.""")
    valid = [o for o in offers if not o["sup"] and o["date"] <= decide <= o["valid"]]
    best = min(valid, key=lambda o: o["net"])
    assert best is not min(offers, key=lambda o: o["net"]), proj   # the naive answer must be wrong
    questions.append({"id": f"angebot-{pi + 1}", "kind": "reconcile", "family": "angebote",
                      "question": f"Welches Angebot für „{proj}“ war am {dd(decide)} das günstigste noch gültige, und wie hoch ist es brutto (inkl. 19 % MwSt.)?",
                      "items": [best["firm"]], "universe": firms, "total": round(best["net"] * 1.19, 2)})

# ---------------------------------------------------------------- tenancies
TEN = [  # flat, name, start, end, rent, deposit
    (1, "Herbert Schwarz", D(2016, 4, 1), None, 640.0, 1800.0),
    (2, "Lena Fischer", D(2020, 9, 1), D(2024, 8, 31), 590.0, 1650.0),
    (2, "Tobias und Sarah Klein", D(2024, 10, 1), None, 640.0, 1920.0),
    (3, "Marco Rossi", D(2019, 2, 1), D(2025, 5, 31), 710.0, 2100.0),
    (3, "Aylin Demir", D(2025, 7, 1), None, 760.0, 2280.0),
    (4, "Jürgen Hahn", D(2021, 5, 1), D(2025, 11, 30), 680.0, 2040.0),
]
for flat, name, start, end, rent, dep in TEN:
    add(start - dt.timedelta(days=R.randint(25, 50)), "vertrag", f"Mietvertrag {FLATS[flat]} – {name}",
        f"""MIETVERTRAG (Kopie)
Vermieterin: Katrin Brandt, {HOME}
Mieter/in: {name}
Mietobjekt: {FLATS[flat]}, {HOUSE}

§ 1 Mietbeginn: {dd(start)}, unbefristet.
§ 2 Miete: Nettokaltmiete {eur(rent)} monatlich, zuzüglich Vorauszahlung auf die Betriebskosten von {eur(180.0 if flat != 4 else 165.0)}.
§ 3 Kaution: {eur(dep)}, zahlbar in drei Raten oder vor Einzug in einer Summe.
§ 4 Kündigung: gesetzliche Fristen.""")
    for y, m in months(max(start, D(2024, 1, 1)), min(end or D(2025, 12, 31), D(2025, 12, 31))):
        bank.append((D(y, m, R.randint(1, 5)), f"Gutschrift {name} Miete {FLATS[flat].split(' (')[0]} {m:02d}/{y}", rent + (180.0 if flat != 4 else 165.0)))
deductions = {
    "Lena Fischer": ([("Bohrlöcher und Dübel im Bad schließen, Fliesen ersetzen", 185.0), ("Zweiter Wohnungsschlüssel fehlt, Schloss getauscht", 142.5)], [("Betriebskostenabrechnung 2023", -96.4), ("Betriebskostenabrechnung 2024 (anteilig Jan–Aug)", 61.2)]),
    "Marco Rossi": ([("Laminat im Wohnzimmer zerkratzt, anteilige Erneuerung", 420.0)], [("Betriebskostenabrechnung 2024", -238.75), ("Betriebskostenabrechnung 2025 (anteilig Jan–Mai)", -54.3)]),
    "Jürgen Hahn": ([("Wände in Raucherwohnung streichen", 680.0), ("Einbauküche: Arbeitsplatte verbrannt", 315.0), ("Sperrmüll im Keller entsorgt", 95.0)], [("Betriebskostenabrechnung 2024", 112.6)]),
}
for flat, name, start, end, rent, dep in TEN:
    if not end:
        continue
    dmg, bk = deductions[name]
    add(end - dt.timedelta(days=95), "brief", f"Kündigung {FLATS[flat]} – {name}",
        f"""{name}
{HOUSE}, {FLATS[flat]}

An Frau Katrin Brandt

Kündigung des Mietverhältnisses

Sehr geehrte Frau Brandt,
hiermit kündige ich das Mietverhältnis fristgerecht zum {dd(end)}. Bitte überweisen Sie die Kaution nach Abrechnung auf mein Konto.

Mit freundlichen Grüßen
{name}""")
    rows = "\n".join(f"- {t}: Kosten {eur(c)} (vom Mieter zu tragen)" for t, c in dmg)
    add(end, "protokoll", f"Übergabeprotokoll Auszug {FLATS[flat]} – {name}",
        f"""WOHNUNGSÜBERGABEPROTOKOLL – AUSZUG
Objekt: {FLATS[flat]}, {HOUSE}
Mieter/in: {name}   Übergabe am: {dd(end)}
Zählerstände notiert, alle Schlüssel bis auf die genannten zurückgegeben.

Festgestellte Mängel, über normale Abnutzung hinaus (Kosten laut Kostenvoranschlag, von beiden Seiten anerkannt):
{rows}

Unterschrift Vermieterin: K. Brandt    Unterschrift Mieter/in: {name}""")
    for title, amount in bk:
        yr = int(title.split()[1])
        dte = D(yr + 1, R.randint(3, 6), R.randint(1, 28))
        if amount < 0:
            res = f"Ergebnis: Guthaben zu Ihren Gunsten von {eur(-amount)}. Wir verrechnen es mit der Kaution."
        else:
            res = f"Ergebnis: Nachzahlung von {eur(amount)}. Sie wird mit der Kaution verrechnet, falls Sie nicht vorher überweisen."
        add(dte, "abrechnung", f"{title} – {name}",
            f"""BETRIEBSKOSTENABRECHNUNG
Abrechnungszeitraum: {title.split(' ', 2)[2] if '(' in title else 'Kalenderjahr ' + str(yr)}
Mieter/in: {name}, {FLATS[flat]}, {HOUSE}

Umlagefähige Kosten gesamt (Anteil Ihrer Wohnung) und geleistete Vorauszahlungen siehe Anlage.
{res}""")
    owed = dep - sum(c for _, c in dmg) - sum(bk_amt for _, bk_amt in bk)
    questions.append({"id": f"kaution-{name.split()[-1].lower()}", "kind": "reconcile", "family": "kaution",
                      "question": f"Wie viel von der Kaution steht {name} nach dem Auszug noch zu, wenn alle bisher bekannten Forderungen und Guthaben verrechnet werden?",
                      "items": [], "universe": [], "total": round(owed, 2)})

# ------------------------------------------------------- contractor invoices
CONTR = ["Elektro Baumann", "Sanitär Kurz", "Schlüsseldienst Rapid", "Malerbetrieb Wolff", "Tischlerei Brandl", "Rohrreinigung Blitz"]
cinv = []
for k in range(26):
    y = 2024 if k < 13 else 2025
    target = R.choice(["W1", "W2", "W3", "W4", "W4", "W2", "Haus", "Privat"])
    date = D(y, R.randint(1, 12), R.randint(1, 28))
    amt = round(R.uniform(85, 1450), 2)
    cinv.append({"num": f"HR-{y}-{k + 1:03d}", "firm": R.choice(CONTR), "date": date, "target": target, "amount": amt, "credit": 0.0})
for c in R.sample([c for c in cinv if c["target"] in ("W2", "W4")], 2):   # credit notes reduce two invoices
    c["credit"] = round(c["amount"] * 0.25, 2)
place = {"W1": f"{FLATS[1]}, {HOUSE}", "W2": f"{FLATS[2]}, {HOUSE}", "W3": f"{FLATS[3]}, {HOUSE}", "W4": f"{FLATS[4]}, {HOUSE}",
         "Haus": f"Gemeinschaftsflächen (Treppenhaus/Keller), {HOUSE}", "Privat": f"Einfamilienhaus {HOME}"}
for c in cinv:
    add(c["date"], "rechnung_ein", f"Rechnung {c['firm']} {c['num']}",
        f"""{c['firm']}
Rechnung {c['num']}  ·  {dd(c['date'])}
Kundin: Katrin Brandt
Einsatzort: {place[c['target']]}

Arbeiten laut Arbeitsnachweis, Material und Anfahrt.
Rechnungsbetrag (inkl. MwSt.): {eur(c['amount'])}""")
    bank.append((c["date"] + dt.timedelta(days=R.randint(5, 20)), f"Überweisung {c['firm']} {c['num']}", -c["amount"]))
    if c["credit"]:
        cd = c["date"] + dt.timedelta(days=R.randint(15, 40))
        add(cd, "gutschrift", f"Gutschrift {c['firm']} zu {c['num']}",
            f"""{c['firm']}
GUTSCHRIFT zu Rechnung {c['num']} vom {dd(c['date'])}
Einsatzort: {place[c['target']]}

Wegen nicht ausgeführter Teilleistung schreiben wir Ihnen {eur(c['credit'])} gut. Der Betrag wird auf Ihr Konto erstattet.""")
        bank.append((cd + dt.timedelta(days=3), f"Gutschrift {c['firm']} Erstattung zu {c['num']}", c["credit"]))
for w, y in [("W2", 2024), ("W4", 2024), ("W2", 2025), ("W4", 2025)]:
    sel = [c for c in cinv if c["target"] == w and c["date"].year == y]
    questions.append({"id": f"handwerker-{w.lower()}-{y}", "kind": "reconcile", "family": "handwerker",
                      "question": f"Welche Handwerkerrechnungen betreffen {FLATS[int(w[1])]} in der {HOUSE.split(',')[0]} im Jahr {y}, und wie hoch sind die Kosten dafür insgesamt nach Abzug etwaiger Gutschriften?",
                      "items": sorted(c["num"] for c in sel), "universe": sorted(c["num"] for c in cinv),
                      "total": round(sum(c["amount"] - c["credit"] for c in sel), 2)})

# ------------------------------------------------------------------- noise
NOISE = [
    ("brief", "Elternbrief Gesamtschule: Klassenfahrt 7b", "Die Klassenfahrt der 7b nach Xanten findet vom 14. bis 16.05.2025 statt. Kostenbeitrag 145 €, bitte bis 31.03.2025 überweisen.", D(2025, 2, 10)),
    ("brief", "Grundschule Am Park: Einladung Elternabend", "Elternabend der Klasse 2a am 18.09.2024 um 19:30 Uhr in Raum 12.", D(2024, 9, 2)),
    ("brief", "Stadt Leverkusen: Grundsteuerbescheid 2025", f"Für das Grundstück {HOUSE} wird die Grundsteuer 2025 auf 1.248,00 € festgesetzt, fällig in vier Raten.", D(2025, 1, 20)),
    ("brief", "Stadt Leverkusen: Grundsteuerbescheid 2024", f"Für das Grundstück {HOUSE} wird die Grundsteuer 2024 auf 1.112,00 € festgesetzt, fällig in vier Raten.", D(2024, 1, 22)),
    ("email", "Newsletter Streamflix: Neu im Oktober", "Diesen Monat neu: drei Serienstaffeln und ein Dokumentarfilm über Polarfüchse. Viel Spaß beim Streamen!", D(2024, 10, 3)),
    ("email", "Newsletter Hörwelt: Sommerlese-Tipps", "Unsere Redaktion empfiehlt zehn Hörbücher für den Urlaub.", D(2025, 6, 20)),
    ("brief", "Kfz-Steuerbescheid", "Für das Fahrzeug LEV-KB 214 wird die Kraftfahrzeugsteuer ab 01.03.2024 auf jährlich 186,00 € festgesetzt.", D(2024, 2, 14)),
    ("brief", "Energieversorger: Abschlagsanpassung Strom", f"Ab 01.04.2025 beträgt Ihr monatlicher Abschlag für {HOME} 96,00 €.", D(2025, 3, 5)),
    ("email", "Tierarztpraxis Rheinauen: Impferinnerung", "Für Ihren Hund Bruno ist die jährliche Impfung fällig. Bitte vereinbaren Sie einen Termin.", D(2025, 4, 8)),
    ("brief", "Hausratversicherung: Beitragsrechnung 2025", f"Jahresbeitrag Hausratversicherung für {HOME}: 214,40 €, fällig am 01.02.2025.", D(2025, 1, 6)),
    ("brief", "Wohngebäudeversicherung: Beitragsrechnung 2025", f"Jahresbeitrag Wohngebäudeversicherung für {HOUSE}: 1.386,00 €, fällig am 01.03.2025.", D(2025, 1, 30)),
    ("email", "Bibliothek: Leihfrist läuft ab", "Drei Medien sind am 12.11.2024 zurückzugeben.", D(2024, 11, 5)),
    ("brief", "Sportverein TuS Opladen: Beitrag Jonas", "Jahresbeitrag Fußball-Jugend 2025: 120,00 €, Einzug im Februar.", D(2025, 1, 15)),
    ("brief", "Finanzamt: Umsatzsteuer-Vorauszahlung Hinweis", "Bitte reichen Sie die Voranmeldung für das 3. Quartal 2025 bis zum 10.10.2025 ein.", D(2025, 9, 15)),
    ("email", "Hausverwaltung-Software: Update", "Version 4.2 ist verfügbar. Neu: Export der Betriebskosten als PDF.", D(2024, 6, 11)),
    ("brief", "Schornsteinfeger: Termin Feuerstättenschau", f"Feuerstättenschau {HOUSE} am 07.05.2025 zwischen 8 und 12 Uhr.", D(2025, 4, 2)),
    ("email", "Mieterin Aylin Demir: Frage zur Mülltonne", "Hallo Frau Brandt, kann die Biotonne künftig an der Hofseite stehen? Viele Grüße, Aylin Demir", D(2025, 8, 3)),
    ("email", "Mieter Herbert Schwarz: Heizung tropft", "Guten Tag, der Heizkörper im Schlafzimmer tropft am Ventil. Gruß, H. Schwarz", D(2024, 11, 19)),
    ("brief", "Kita/Schule: Rechnung Mittagessen", "Mittagsverpflegung Jonas, Oktober 2024: 62,00 €.", D(2024, 10, 30)),
    ("email", "Fotowerk Pro: Neue Funktionen", "Die neue Version bringt KI-gestützte Freistellung.", D(2025, 2, 18)),
    ("brief", "Bank: Änderung der Kontoführungsgebühr", "Ab 01.07.2025 beträgt die Kontoführungsgebühr 6,90 € monatlich.", D(2025, 5, 2)),
    ("email", "Café Mühlenhof: Danke für die Speisekarte", "Liebe Frau Brandt, die neue Karte kommt bei den Gästen sehr gut an!", D(2024, 5, 21)),
    ("email", "TechNova Solutions: Neue Ansprechpartnerin", "Ab sofort ist Frau Ramos Ihre Ansprechpartnerin in der Buchhaltung.", D(2025, 2, 3)),
    ("brief", "Rundfunkbeitrag: Zahlungsaufforderung", "Rundfunkbeitrag 1. Quartal 2025: 55,08 €.", D(2025, 1, 10)),
    ("email", "Elternbeirat: Sommerfest", "Das Sommerfest der Grundschule ist am 28.06.2025, Kuchenspenden willkommen.", D(2025, 6, 2)),
]
for typ, title, text, d in NOISE:
    add(d, typ, title, text)

# ------------------------------------------------------------ bank statements
for y, m in months(D(2024, 1, 1), D(2025, 12, 31)):
    rows = sorted(b for b in bank if (b[0].year, b[0].month) == (y, m))
    body = "\n".join(f"{dd(d)}  {t:<78} {('+' if a > 0 else '−') + eur(abs(a)):>14}" for d, t, a in rows)
    add(month_end(y, m), "kontoauszug", f"Kontoauszug {m:02d}/{y}",
        f"""Rheinische Volksbank eG – Kontoauszug Nr. {m}/{y}
Kontoinhaberin: Katrin Brandt   IBAN {IBAN_OWN}
Zeitraum: 01.{m:02d}.{y} – {dd(month_end(y, m))}

{body}
""")

# ------------------------------------------------------------- lookup / absent
look = []
for flat, name, start, end, rent, dep in TEN:
    look.append((f"Wie hoch ist die Kaution im Mietvertrag mit {name}?", "amount", dep))
look.append((f"Wie hoch ist die Nettokaltmiete von {FLATS[2]} im Mietvertrag mit Tobias und Sarah Klein?", "amount", 640.0))
for name in ["Streamflix", "SicherNetz VPN"]:
    look.append((f"Wie lautet meine Kundennummer bei {name}?", "text", cust[name]))
for inv in R.sample(invoices, 4):
    look.append((f"Über welchen Bruttobetrag lautet meine Rechnung {inv['num']}?", "amount", inv["gross"]))
for c in R.sample([c for c in cinv if not c["credit"]], 2):
    look.append((f"Über welchen Betrag lautet die Rechnung {c['num']} von {c['firm']}?", "amount", c["amount"]))
for name in ["Tonfabrik Music", "FitPlus Studio"]:
    end = [s[4] for s in SUBS if s[0] == name][0]
    look.append((f"Zu welchem Datum endet mein Abonnement bei {name}?", "date", end))
look.append(("Auf welchen Betrag wurde die Grundsteuer 2025 für die Bergstraße 22 festgesetzt?", "amount", 1248.0))
look.append(("Wann findet die Feuerstättenschau in der Bergstraße 22 statt?", "date", D(2025, 5, 7)))
for i, (q, vk, v) in enumerate(look):
    questions.append({"id": f"lookup-{i + 1:02d}", "kind": "lookup", "family": "nachschlagen", "question": q,
                      "value_kind": vk, "value": v.isoformat() if isinstance(v, D) else v})
ABSENT = [
    "Wie hoch ist die Kaution im Mietvertrag mit Felix Wagner?",
    "Wie lautet meine Kundennummer bei Kinowelt Premium?",
    "Über welchen Bruttobetrag lautet meine Rechnung RE-2025-061?",
    "Wie hoch war das Angebot von Gerüstbau Maier für die Dachsanierung?",
    "Wie viel hat die Auxilia Krankenversicherung für die Rechnung der Augenarztpraxis Dr. Becker erstattet?",
    "Bei welcher Gesellschaft ist mein Auto LEV-KB 214 haftpflichtversichert, und wie hoch ist der Jahresbeitrag?",
]
assert "RE-2025-061" not in {i["num"] for i in invoices}
for i, q in enumerate(ABSENT):
    questions.append({"id": f"absent-{i + 1:02d}", "kind": "absent", "family": "nicht_im_archiv", "question": q})


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    docs.sort(key=lambda d: (d["date"], d["title"]))
    for i, d in enumerate(docs):
        d["id"] = f"D{i + 1:04d}"
    with open(os.path.join(out, "archive.jsonl"), "w") as f:
        for d in docs:
            f.write(json.dumps({k: d[k] for k in ("id", "date", "type", "title", "text")}, ensure_ascii=False) + "\n")
    with open(os.path.join(out, "questions.jsonl"), "w") as f:
        for q in questions:
            f.write(json.dumps(q, ensure_ascii=False) + "\n")
    chars = sum(len(d["text"]) for d in docs)
    kinds = {}
    for q in questions:
        kinds[q["kind"]] = kinds.get(q["kind"], 0) + 1
    print(f"{len(docs)} documents, {chars} characters (~{chars // 3} tokens), questions {kinds}, seed {SEED}")


if __name__ == "__main__":
    main()

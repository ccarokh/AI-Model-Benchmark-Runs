"""Vergleicht zwei Suite-Laeufe und leitet die Uebernahme-Entscheidung ab.

    compare.py <basis-lauf> <kandidat-lauf>

Die Suite misst; dieses Skript entscheidet NICHT, es prueft die drei Bedingungen
und legt sie offen. Die Entscheidung trifft der Betreiber -- eine einzelne
Durchsatzzahl als Freigabe hinzustellen waere genau der Fehler, den dieses Repo
an anderer Stelle dokumentiert.

Die Schwelle von 3 % ist keine Statistik, sondern eine Konvention: darunter
liegt bei uns Lauf-zu-Lauf-Streuung, und ein Unterschied darunter wird als
"unveraendert" gemeldet statt als Verbesserung verkauft.
"""
import csv, sys, os

SCHWELLE = 0.03  # 3 %

def lade(pfad):
    p = os.path.join(pfad, "ergebnis.tsv") if os.path.isdir(pfad) else pfad
    d = {}
    with open(p) as fh:
        for r in csv.DictReader(fh, delimiter="\t"):
            d[r["metric"]] = r["value"]
    return d, p

if len(sys.argv) < 3:
    sys.exit(__doc__)
basis, kand = lade(sys.argv[1]), lade(sys.argv[2])
b, k = basis[0], kand[0]

print("Basis    :", sys.argv[1])
print("Kandidat :", sys.argv[2])
print()

# --- Bedingung 1: gleiche Ausgabe ------------------------------------------
hb, hk = b.get("output_hash", "?"), k.get("output_hash", "?")
gleich = hb == hk and not hb.startswith("SKIPPED")
print("1) Ausgabe identisch : %s   (%s vs %s)" %
      ("JA" if gleich else "NEIN", hb, hk))
if hb.startswith("SKIPPED") or hk.startswith("SKIPPED"):
    print("   ⚠️ nicht gemessen -- damit ist die Bedingung NICHT erfuellt, nicht 'wahrscheinlich ok'")

# --- Condition 2: no kernel messages ---------------------------------------
kern = {m: v for m, v in k.items() if m.endswith("_kernel_msgs")}
schlimm = {m: v for m, v in kern.items() if v not in ("0", "")}
print("2) Kernel sauber     : %s%s" %
      ("JA" if not schlimm else "NEIN", "" if not schlimm else "   " + str(schlimm)))

# --- Condition 3: production-like numbers no worse -------------------------
print("3) Durchsatz")
regress = []
for metrik in sorted(set(b) & set(k)):
    if not metrik.endswith(("_pp_t_per_s", "_tg_t_per_s")):
        continue
    try:
        vb, vk = float(b[metrik]), float(k[metrik])
    except ValueError:
        continue
    if vb == 0:
        continue
    d = (vk - vb) / vb
    marke = "gleich"
    if d > SCHWELLE:  marke = "besser"
    elif d < -SCHWELLE:
        marke = "SCHLECHTER"
        if metrik.startswith("prod_"):
            regress.append(metrik)
    print("   %-26s %10.2f -> %10.2f  %+6.1f %%  %s" % (metrik, vb, vk, d*100, marke))

print()
erfuellt = gleich and not schlimm and not regress
print("Alle drei Bedingungen erfuellt:", "JA" if erfuellt else "NEIN")
if regress:
    print("  produktionsnahe Regression in:", ", ".join(regress))
print()
print("Das ist die Grundlage, nicht die Entscheidung. Ein 'JA' heisst, dass nichts")
print("dagegen spricht -- nicht, dass ein Wechsel noetig ist.")

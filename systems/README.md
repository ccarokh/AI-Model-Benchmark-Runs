# Systeme

Eine Datei je Rechner, und in jeder **dieselben Felder in derselben Reihenfolge**.

Der Tatsachenblock oben auf jeder Seite ist **erzeugt, nicht geschrieben**:
[`scripts/systems/erfassen.sh`](../scripts/systems/erfassen.sh) liest ihn auf dem
jeweiligen Rechner aus, die Ergebnisse liegen als JSON in
[`data/systems/`](../data/systems/), und
[`scripts/systems/gensystems.py`](../scripts/systems/gensystems.py) schreibt daraus den
Block zwischen die Marken. Der Fließtext darunter bleibt von Hand.

## Warum das nötig war

Vorher hatte jede Systembeschreibung ihre eigene Form. Die eine erzählte über
Arbeitsspeicher, die nächste über das BIOS, die dritte über den Treiber — und **ob
irgendwo etwas fehlte, war gar nicht zu sehen.** Eine Lücke sah aus wie ein Thema, das
nicht zur Sprache kam.

Die erste Erfassung nach demselben Muster hat sofort vier Dinge gefunden:

**Die PCIe-Angabe für System A war falsch.** Zwischen CPU und 7900 XTX sitzt eine Brücke.
Die Karte redet mit ihr in Gen 4 ×16, die Brücke mit der CPU in **Gen 3 ×8**. Im Dokument
stand nur „Gen 3, 8 GT/s" — die halbierte Breite fehlte.

**Der Kartenname kam vom falschen Gerät.** Der PCI-Pfad einer Karte hinter einem Switch
zeigt auf dessen Downstream-Port; dort stand „Navi 10 XL Downstream Port of PCI Express
Switch" statt des Kartennamens.

**System B liefert keine PCIe-Daten**, weil `lspci -vv` dafür root braucht. Das steht
jetzt als *nicht lesbar* da, statt als leeres Feld — ein fehlendes Recht sieht sonst aus
wie eine fehlende Fähigkeit.

**Die BIOS-Stände standen nirgends.** 11/2022, 09/2025 und 05/2021 — genau die Angabe,
die man bei Mikrocode-Fragen sucht.

## Neu erfassen

```
bash scripts/systems/erfassen.sh > data/systems/system-x.json   # auf dem Rechner selbst
python3 scripts/systems/gensystems.py                            # Seiten neu erzeugen
```

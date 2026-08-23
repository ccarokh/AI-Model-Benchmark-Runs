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

**Die PCIe-Angabe für System A war unvollständig.** Dokumentiert war „Gen 3, 8 GT/s", die
**Breite fehlte**: es sind **×8**, weil die RTX 2070 die anderen acht Bahnen belegt.

Und sie ist **kein Merkmal des Systems, sondern ein Zustand**: bis zum 3. August lief die
7900 XTX allein mit ×16. In [`versions.md`](versions.md) steht das seit jeher korrekt —
in der Übersichtstabelle stand es zeitlos, als wäre es immer so gewesen. **Eine erfasste
Momentaufnahme ist keine Geschichte**, und wo sich etwas geändert hat, muss die Tabelle
auf die Versionsliste zeigen statt den heutigen Wert als Konstante auszugeben.

Beim Nachsehen wäre ich dabei fast in die entgegengesetzte Falle gelaufen. `lspci` meldet
für die 7900 XTX auch eine Verbindung mit **Gen 4 ×16** — die ist aber *innerhalb der
Karte*, hinter dem PCIe-Switch, den Navi 31 selbst mitbringt:

```
CPU-Wurzelanschluss 00:01.0   Gen 3 ×8   ← mehr kann die CPU nicht
  └─ 01:00.0  Navi 10 XL Upstream Port of PCI Express Switch   ← auf der Karte
       └─ 02:00.0  Downstream-Port
            └─ 03:00.0  Navi 31 [Radeon RX 7900 XTX]
```

Wer nur die Karte abfragt, liest den kartinternen Zweig und hält ihn für die Anbindung an
den Rechner. **Deshalb erfasst das Skript beide Enden** — und deshalb steht in der Tabelle
„Karte zur Brücke" neben „Brücke zur CPU", statt einer Zahl, die man verwechseln kann.

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

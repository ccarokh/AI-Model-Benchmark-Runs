Schreibe ein vollständiges Browser-Spiel in dieses Verzeichnis. Es muss sich mit
`index.html` im Browser öffnen lassen.

Das Spiel ist ein Agility-Parcours mit einem **Hund**, der von links nach rechts läuft
(Seitenansicht, der Hund bleibt an derselben Stelle, die Welt scrollt).

**Zwei Hindernisarten, die zwei verschiedene Aktionen verlangen:**

1. **Hürden** — der Hund muss darüber **springen**
2. **Tunnel** — der Hund muss sich **ducken** und hindurchlaufen

**Spielanforderungen:**

- **Tastenbelegung. Jede einzelne dieser Tasten muss funktionieren:**

  | Aktion | Tasten |
  |---|---|
  | Springen | **Leertaste**, **W** |
  | Ducken (gedrückt halten) | **Strg**, **S** |
  | Neustart | **R**, **Enter** |

  Das ist keine Auswahl, sondern eine Liste: alle genannten Tasten sind Pflicht.
  Andere Tasten für diese Aktionen sind nicht erlaubt. **Schreibe die Belegung
  sichtbar auf die Seite.**
- Springen hilft beim Tunnel **nicht**, Ducken hilft bei der Hürde **nicht**
- **Ducken ist ein gehaltener Zustand, kein einzelner Tastendruck.** Wer die Ducktaste
  schon in der Luft drückt und gedrückt hält, duckt sich beim Aufsetzen — er darf nicht
  darauf angewiesen sein, die Taste erneut zu drücken.
- Punktestand, der mit der Zeit steigt
- **Highscore neben dem laufenden Stand.** Er überlebt den Neustart: wer 40 Punkte
  schafft, neu startet und bei 12 stirbt, sieht weiterhin 40 als besten Wert.
- Die Geschwindigkeit nimmt im Laufe des Spiels zu
- **Tag- und Nachtwechsel:** im Verlauf schlägt die Darstellung von hell nach dunkel
  um und wieder zurück
- Kollision beendet das Spiel und zeigt das Ergebnis an
- **Neustart, erst nach dem Spielende:** die Tasten **R** und **Enter** *und* eine
  anklickbare Schaltfläche **im Spielfeld**, nicht darunter. Mit der Maus allein muss
  ein neuer Lauf möglich sein. Während gespielt wird, ist die Schaltfläche nicht da —
  sie zieht sonst nur den Tastaturfokus vom Spiel weg.

**Die Grafik gehört zur Aufgabe.** Hund, Hürden und Tunnel entstehen im Code — Canvas,
SVG oder CSS.

- Der **Hund** muss als Hund erkennbar sein und beim Ducken anders aussehen als beim Laufen.
  Dabei gilt:
  - **Eine zusammenhängende Figur, keine schwebenden Teile.** Beine sitzen am Rumpf, der
    Kopf sitzt am Hals, der Schwanz am Hinterteil — sichtbare Lücken zwischen Körperteilen
    sind ein Fehler.
  - **Vier Beine, davon zwei vorn und zwei hinten.** Ein Hund mit allen Beinen unter dem
    Hinterteil ist keiner. Vorderbeine sitzen unter der Brust, Hinterbeine an der Hüfte.
  - **Proportionen bleiben stimmig**, auch in der Duckhaltung: der Kopf ist deutlich
    kleiner als der Rumpf, die Beine sind kürzer als der Rumpf lang ist, und die Schnauze
    ist kein zweiter Kopf. Ein gestauchter Hund ist flacher, nicht anders gebaut.
- **Hürde und Tunnel** müssen als das erkennbar sein, was sie sind, und voneinander
  unterscheidbar. Zwei gleich aussehende Rechtecke erfüllen das nicht — man muss auf einen
  Blick wissen, ob zu springen oder zu ducken ist.
- Die **Hürde** ist ein Sprunghindernis: Ständer links und rechts, waagerechte Stangen
  dazwischen, oben offen. Man sieht, dass darüber gesprungen wird.
- Der **Tunnel** ist ein Agility-Stofftunnel in Seitenansicht. So sieht das Vorbild aus,
  und danach richtet sich die Zeichnung:
  - eine **liegende Röhre, die flach auf dem Boden aufliegt** — keine Beine, keine
    Ständer, kein Sockel
  - **deutlich länger als hoch**, etwa zwei- bis dreimal, mit über die ganze Länge
    **gleichbleibendem Durchmesser**
  - die Oberfläche zeigt **quer verlaufende Ringe** wie bei einem Faltenschlauch; sie
    machen die Rundung sichtbar
  - **kräftig einfarbig** (das Vorbild ist blau), keine Streifen und keine Zeltspitze
  - am Ende, aus dem der Hund kommt, eine **kreisrunde dunkle Öffnung mit dunklem Rand**
  - Ein Torbogen, ein Zelt oder ein Hügel ist das nicht — unter denen läuft man hindurch,
    ohne dass es nach Röhre aussieht. **Die dunkle Öffnung ist das entscheidende Merkmal:**
    sie zeigt, dass es innen hohl ist und der Hund darin verschwindet.
- **Der Hund verschwindet im Tunnel.** Läuft er geduckt hindurch, ist er darin nicht mehr
  zu sehen — der Tunnel liegt vor ihm, nicht hinter ihm. Ein Hund, der über den Tunnel
  hinweg gezeichnet wird, läuft sichtbar davor vorbei statt hindurch.

**Das Spiel muss spielbar sein.** Die Sprunghöhe muss zur Hürdenhöhe passen und die
Tunnelöffnung zur geduckten Haltung, mit genug Spielraum, dass ein Mensch es zur richtigen
Zeit schafft — nicht nur rechnerisch in einem Zeitfenster von Millisekunden.

**Hürden treten in Gruppen von einer, zwei oder drei auf, und alle drei Gruppengrößen
müssen tatsächlich vorkommen** — nicht nur theoretisch möglich sein. Eine Gruppe muss mit
**einem** Sprung zu schaffen sein, auch bei der höchsten Geschwindigkeit, die im Spiel
vorkommt. Rechne die Sprungweite gegen die Gruppenbreite, statt es zu schätzen.

Die einzelnen Hürden einer Gruppe müssen **als einzelne erkennbar** sein. Lückenlos
aneinandergesetzt sehen drei Hürden aus wie eine breite, und dann ist die Gruppe
unsichtbar statt selten.

**Technische Vorgaben:**

- Einstiegspunkt ist `index.html`. Wie du den Rest aufteilst, entscheidest du.
- Keine externen Dateien aus dem Netz: kein CDN, keine Schriftarten von außen, keine
  Bibliothek, die beim Öffnen nachgeladen wird. Das Spiel muss ohne Internet laufen.
- Kein Build-Schritt. Die Datei im Browser öffnen muss reichen.

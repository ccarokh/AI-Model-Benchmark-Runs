# Agility-Spiel: Rohdaten

`urteile.tsv` — die menschliche Bewertung, eine Zeile je Lauf, neunzehn Spalten mit
`ja` / `nein` / `untestbar` / leer. Leer heißt **nicht beantwortet** und ist etwas
anderes als `nein`.

`baseline/` — der Blindlauf, der die Aufgabe validiert hat. Kein Wettbewerber und kein
Messpunkt gegen die lokalen Modelle: fremde Hardware, anderer Prüfstand, unbekannte
Quantisierung. Er beantwortet eine einzige Frage — **sind die neunzehn Kriterien
gleichzeitig erfüllbar** —, und die Antwort ist ja.

Ohne diesen Punkt wäre eine Tabelle voller `nein` nicht deutbar: zu schwache Modelle und
eine zu harte oder zu ungenaue Aufgabe sähen darin gleich aus.

| | |
|---|---|
| Modell | claude-opus-5 über Claude Code |
| Bedingungen | leeres Verzeichnis außerhalb des Projekts, eine einzige Nachricht, kein Verlauf |
| Aufgabe | `aufgabe.md`, Fingerabdruck `897f85484354`, zeichengleich geprüft |
| Dauer | 1 658 s · 57 Werkzeugaufrufe · 292 690 Ausgabe-Token |
| Ergebnis | **19 von 19 erfüllt** |

Der Weg dahin war zwei Anläufe lang. Der erste Blindlauf scheiterte an zwei Punkten:
der Tunnel sah aus wie ein Zirkuszelt, und der Hund lief sichtbar davor vorbei statt
hindurch. Beides waren **Lücken im Aufgabentext**, nicht Grenzen des Modells — der Text
verlangte nur, dass Hürde und Tunnel unterscheidbar sind, und ein Zelt erfüllt das.
Seitdem steht dort, woran man einen Tunnel erkennt, und dass der Hund darin verschwinden
muss.

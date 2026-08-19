#!/usr/bin/env python3
"""Bewertungsserver fuer die Agility-Spiele.

Warum lokal und nicht als Artefakt: die Spiele sind eigenstaendige Verzeichnisse
mit index.html plus den Dateien, die das Modell selbst angefordert hat. Sie
muessen als echte Seite geladen werden, mit funktionierender Tastatur -- in einem
eingebetteten Rahmen laesst sich ein Spiel nicht ernsthaft spielen.

Das Primaerurteil ist binaer: laesst sich das Spiel oeffnen und spielen.
Alles Weitere ist Kommentar.

Jedes Kriterium hat VIER Zustaende: ja, nein, untestbar, noch nicht beantwortet.
Ein Haekchen kann davon genau einen -- ein leeres Kaestchen hiesse gleichzeitig
"nein" und "noch nicht angesehen", und dann laesst sich nie sagen, ob eine
Bewertung fertig ist. Fertig heisst hier: alle acht beantwortet.

"Untestbar" ist kein Ausweichen, sondern die einzig ehrliche Antwort, wenn das
Spiel gar nicht erst startet: ob es mit der Zeit schneller wird, hat dann
niemand gesehen. Als "nein" gezaehlt waere es eine erfundene Beobachtung.

Nur Standardbibliothek.

    python3 spiel_bewerter.py [port]      # http://127.0.0.1:8109
"""
import http.server, json, os, socketserver, sys, urllib.parse
from datetime import datetime, timezone

HIER = os.path.dirname(os.path.abspath(__file__))
SPIELE = os.path.join(HIER, "game")
URTEILE = os.path.join(HIER, "spiel_urteile.json")
TABELLE = os.path.join(HIER, "spiel_urteile.tsv")

# Abzaehlbare Kriterien, die der Mensch nach dem Spielen abhakt.
#
# JEDE FRAGE FRAGT GENAU EINE SACHE. "Huerden und Tunnel sehen aus wie Huerden
# und Tunnel" war zusammengeklebt: bei "nein" weiss hinterher niemand, welches
# von beiden schuld war. Dasselbe galt fuer "Game Over und Neustart", fuer
# "Highscore steht daneben und ueberlebt den Neustart" und fuer "Springen hilft
# am Tunnel nicht (und umgekehrt)". Lieber siebzehn scharfe Fragen als zwoelf,
# deren Antworten sich nicht zurueckverfolgen lassen.
KRITERIEN = [
    ("oeffnet",       "Öffnet ohne Fehler"),
    ("spielbar",      "Ist spielbar"),
    ("hund",          "Der Hund ist als Hund erkennbar"),
    ("huerde_optik",  "Hürden sehen aus wie Hürden"),
    ("tunnel_optik",  "Tunnel sehen aus wie Tunnel"),
    ("huerde",        "Hürden lassen sich überspringen"),
    ("dreier",        "Drei Hürden hintereinander sind mit einem Sprung zu schaffen"),
    ("tunnel",        "Tunnel lassen sich durchducken"),
    ("tunnel_verdeckt", "Der Hund verschwindet im Tunnel"),
    ("sprung_nutzlos", "Springen hilft am Tunnel NICHT"),
    ("ducken_nutzlos", "Ducken hilft an der Hürde NICHT"),
    ("ducken_gehalten", "Ducktaste in der Luft gedrückt wirkt beim Aufsetzen"),
    ("punkte",        "Punktestand läuft"),
    ("schneller",     "Wird mit der Zeit schneller"),
    ("highscore",     "Highscore wird angezeigt"),
    ("highscore_bleibt", "Highscore überlebt den Neustart"),
    ("tagnacht",      "Tag- und Nachtwechsel findet statt"),
    ("gameover",      "Kollision beendet das Spiel und zeigt das Ergebnis"),
    ("neustart",      "Neustart funktioniert"),
]

# Im Klartext, was das Spiel erzeugt hat. Ohne diese Saetze steht auf der Seite
# ein Wort wie "direkt", das niemand einordnen kann -- und dann bewertet man das
# Modell fuer etwas, das der Pruefstand ihm gar nicht ermoeglicht hat.
PRUEFSTAND = {
    "claudecode_blind":
        "BLINDLAUF, der einzige faire Vergleichspunkt: eine leere Sitzung in einem leeren "
        "Verzeichnis ausserhalb des Projekts, eine einzige Nachricht -- der Aufgabentext, "
        "sonst nichts. Kein Verlauf, keine Bewertungsfragen, keine Rueckfrage. Dasselbe "
        "Blatt, das jedes lokale Modell bekommt. Trotzdem fremde Hardware und anderer "
        "Pruefstand: bei Geschwindigkeit und Groesse ist das kein Vergleich.",
    "claudecode": "Vergleichspunkt, kein Wettbewerber: Claude Opus 5 ueber Claude Code in "
                  "VS Code -- ein Modell aus der Cloud auf fremder Hardware, mit einem "
                  "anderen Pruefstand und unbekannter Quantisierung. Gegen die lokalen "
                  "Laeufe ist das in KEINER Hinsicht ein fairer Vergleich, weder bei "
                  "Geschwindigkeit noch bei Groesse. Er existiert fuer genau eine Frage: "
                  "sind die acht Kriterien ueberhaupt gleichzeitig erfuellbar? Ohne diese "
                  "Antwort saehen zu schwache Modelle und eine zu harte Aufgabe gleich aus.",
    "opencode": "Voller Pruefstand: das Modell arbeitet in OpenCode in einem leeren "
                "Verzeichnis, darf Dateien anlegen, Befehle ausfuehren und deren "
                "Ausgabe lesen -- gekapselt in einem Behaelter. Was am Ende dort "
                "liegt, ist das Ergebnis.",
}
LAUFZEIT = {
    "Anthropic-API (Cloud)": "Fremde Hardware, unbekannte Groesse, unbekannte Quantisierung.",
    "llamacpp": "llama-server, Chat-Vorlage aus der GGUF",
    "vllm": "vLLM auf ROCm, im Behaelter",
}

def modelle():
    aus = []
    if not os.path.isdir(SPIELE):
        return aus
    for n in sorted(os.listdir(SPIELE)):
        d = os.path.join(SPIELE, n)
        if not os.path.isdir(d):
            continue
        # Das Spiel liegt im Arbeitsverzeichnis des Agenten, nicht im Laufordner.
        arbeit = os.path.join(d, "arbeit")
        idx = os.path.join(arbeit, "index.html")
        eintrag = {
            "modell": n,
            "hat_index": os.path.exists(idx),
            "bytes": os.path.getsize(idx) if os.path.exists(idx) else 0,
            "dateien": sorted(os.listdir(arbeit)) if os.path.isdir(arbeit) else [],
            "kopf": {},
        }
        # Was diesen Lauf ausmacht, steht in lauf.json -- die Seite soll es
        # zeigen, nicht der Dateiname andeuten.
        lauf = os.path.join(d, "lauf.json")
        if os.path.exists(lauf):
            try:
                c = json.load(open(lauf, encoding="utf-8"))
                eintrag["kopf"] = {
                    "model": c.get("model", ""),
                    "beschreibung": c.get("beschreibung", ""),
                    "harness": c.get("harness", ""),
                    # Blindlauf und kontaminierter Lauf teilen sich den Pruefstand,
                    # unterscheiden sich aber im Entscheidenden -- also am Text trennen.
                    "harness_text": PRUEFSTAND.get(
                        c.get("harness", "") + ("_blind" if c.get("beschreibung") == "blind" else ""),
                        PRUEFSTAND.get(c.get("harness", ""), "")),
                    "runtime": c.get("runtime", ""),
                    "runtime_text": LAUFZEIT.get(c.get("runtime", ""), ""),
                    "temp": c.get("temp"), "maxtok": c.get("maxtok"),
                    "template": c.get("template", ""),
                }
            except (OSError, ValueError):
                pass
        aus.append(eintrag)
    return aus

def laden():
    if os.path.exists(URTEILE):
        try:
            return json.load(open(URTEILE, encoding="utf-8"))
        except (OSError, ValueError):
            pass
    return {}

def speichern(d):
    tmp = URTEILE + ".tmp"
    json.dump(d, open(tmp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    os.replace(tmp, URTEILE)          # atomar: nie halb geschrieben lesen
    z = ["model\tvollstaendig\t" + "\t".join(k for k, _ in KRITERIEN) + "\tkommentar\tzeit"]
    for m in modelle():
        u = d.get(m["modell"], {})
        # Leer heisst nicht beantwortet -- nicht "nein". Der Unterschied ist der
        # ganze Punkt der drei Zustaende.
        def wort(k):
            v = u.get(k, None)
            if v is True: return "ja"
            if v is False: return "nein"
            if v == "untestbar": return "untestbar"
            return ""
        z.append("\t".join([m["modell"],
                  "ja" if all(k in u for k, _ in KRITERIEN) else "nein"]
                 + [wort(k) for k, _ in KRITERIEN]
                 + [(u.get("kommentar") or "").replace("\t", " ").replace("\n", " "),
                    u.get("zeit") or ""]))
    tmp = TABELLE + ".tmp"
    open(tmp, "w", encoding="utf-8").write("\n".join(z) + "\n")
    os.replace(tmp, TABELLE)

class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *_): pass

    def _send(self, code, typ, body, extra=None):
        if isinstance(body, str): body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", typ)
        self.send_header("Content-Length", str(len(body)))
        # Kein Caching: die Spiele werden waehrend der Bewertung neu erzeugt.
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items(): self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        w = urllib.parse.urlparse(self.path).path
        if w in ("/", "/index.html"):
            return self._send(200, "text/html; charset=utf-8",
                              open(os.path.join(HIER, "spiel_bewerter.html"), "rb").read())
        if w == "/modelle":
            return self._send(200, "application/json; charset=utf-8",
                              json.dumps({"modelle": modelle(), "urteile": laden(),
                                          "kriterien": KRITERIEN}, ensure_ascii=False))
        if w.startswith("/spiel/"):
            rest = urllib.parse.unquote(w[len("/spiel/"):])
            teile = rest.split("/", 1)
            # Ohne Schraegstrich am Ende loest der Browser relative Verweise eine
            # Ebene zu hoch auf: aus game.js wird /spiel/game.js. Solange jedes
            # Spiel aus einer einzigen Datei bestand, fiel das nicht auf.
            if len(teile) == 1 or not teile[1]:
                teile = [teile[0], "index.html"]
            modell, datei = teile
            # Kein Ausbrechen aus dem Spielverzeichnis.
            basis = os.path.realpath(os.path.join(SPIELE, modell, "arbeit"))
            pfad = os.path.realpath(os.path.join(basis, datei))
            if not pfad.startswith(basis + os.sep) and pfad != basis:
                return self._send(403, "text/plain; charset=utf-8", "nein")
            if not os.path.isfile(pfad):
                return self._send(404, "text/plain; charset=utf-8", "nicht gefunden")
            typen = {".html": "text/html; charset=utf-8", ".js": "text/javascript",
                     ".css": "text/css", ".png": "image/png", ".jpg": "image/jpeg",
                     ".webp": "image/webp", ".svg": "image/svg+xml"}
            typ = typen.get(os.path.splitext(pfad)[1].lower(), "application/octet-stream")
            return self._send(200, typ, open(pfad, "rb").read())
        self._send(404, "text/plain; charset=utf-8", "nicht gefunden")

    def do_POST(self):
        if urllib.parse.urlparse(self.path).path != "/urteil":
            return self._send(404, "text/plain; charset=utf-8", "nicht gefunden")
        n = int(self.headers.get("Content-Length") or 0)
        try: ein = json.loads(self.rfile.read(n) or b"{}")
        except ValueError: return self._send(400, "text/plain; charset=utf-8", "kaputtes JSON")
        m = ein.get("modell")
        if not m or m not in {x["modell"] for x in modelle()}:
            return self._send(400, "text/plain; charset=utf-8", "unbekanntes Modell")
        d = laden(); e = d.get(m, {})
        for k, _ in KRITERIEN:
            if k in ein:
                v = ein[k]
                if v is None: e.pop(k, None)            # zurueck auf unbeantwortet
                elif v == "untestbar": e[k] = "untestbar"
                elif isinstance(v, bool): e[k] = v
                else: return self._send(400, "text/plain; charset=utf-8",
                                        "unzulaessiger Wert fuer " + k)
        if "kommentar" in ein:
            t = (ein["kommentar"] or "").strip()
            if t: e["kommentar"] = t
            else: e.pop("kommentar", None)
        e["zeit"] = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
        d[m] = e; speichern(d)
        # Das gespeicherte Urteil zurueckgeben: die Oberflaeche aktualisiert damit
        # genau eine Karte, statt die ganze Liste neu zu zeichnen.
        return self._send(200, "application/json; charset=utf-8",
                          json.dumps({"ok": True, "urteil": e}, ensure_ascii=False))

class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8109
    m = modelle()
    if not m:
        print("Keine Spiele unter %s" % SPIELE); return 1
    # Nur 127.0.0.1: keine Authentifizierung, und es fuehrt fremden Code aus.
    with S(("127.0.0.1", port), H) as srv:
        print("Bewertung laeuft:  http://127.0.0.1:%d" % port)
        print("%d Spiele  ->  %s" % (len(m), TABELLE))
        try: srv.serve_forever()
        except KeyboardInterrupt: print("\nbeendet")
    return 0

if __name__ == "__main__":
    sys.exit(main())

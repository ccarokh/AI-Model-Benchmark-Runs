#!/usr/bin/env python3
"""Bewertungsserver fuer die Agility-Spiele.

Warum lokal und nicht als Artefakt: die Spiele sind eigenstaendige Verzeichnisse
mit index.html plus den Dateien, die das Modell selbst angefordert hat. Sie
muessen als echte Seite geladen werden, mit funktionierender Tastatur -- in einem
eingebetteten Rahmen laesst sich ein Spiel nicht ernsthaft spielen.

Das Primaerurteil ist binaer: laesst sich das Spiel oeffnen und spielen.
Alles Weitere ist Kommentar.

Nur Standardbibliothek.

    python3 spiel_bewerter.py [port]      # http://127.0.0.1:8109
"""
import http.server, json, os, socketserver, sys, urllib.parse
from datetime import datetime, timezone

HIER = os.path.dirname(os.path.abspath(__file__))
SPIELE = os.path.join(HIER, "game")
URTEILE = os.path.join(HIER, "spiel_urteile.json")
TABELLE = os.path.join(HIER, "spiel_urteile.tsv")

# Abzaehlbare Kriterien, die der Mensch nach dem Spielen abhakt. Bewusst
# Ja/Nein und bewusst wenige -- bei der Bildreihe hat genau das die Haelfte der
# Urteile objektiv gemacht statt Geschmackssache.
KRITERIEN = [
    ("spielbar",   "Öffnet und ist spielbar"),
    ("hund",       "Der Hund ist als Hund erkennbar"),
    ("huerde",     "Hürden lassen sich überspringen"),
    ("tunnel",     "Tunnel lassen sich durchducken"),
    ("getrennt",   "Springen hilft am Tunnel NICHT (und umgekehrt)"),
    ("punkte",     "Punktestand läuft"),
    ("schneller",  "Wird mit der Zeit schneller"),
    ("neustart",   "Game Over und Neustart funktionieren"),
]

def modelle():
    aus = []
    if not os.path.isdir(SPIELE):
        return aus
    for n in sorted(os.listdir(SPIELE)):
        d = os.path.join(SPIELE, n)
        if not os.path.isdir(d):
            continue
        idx = os.path.join(d, "index.html")
        bilder = os.path.join(d, "bilder.json")
        eintrag = {
            "modell": n,
            "hat_index": os.path.exists(idx),
            "bytes": os.path.getsize(idx) if os.path.exists(idx) else 0,
            "dateien": sorted(f for f in os.listdir(d)
                              if not f.endswith((".log", ".json", ".txt"))),
            "prompts": [],
        }
        if os.path.exists(bilder):
            try:
                eintrag["prompts"] = json.load(open(bilder, encoding="utf-8"))
            except Exception:
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
    z = ["model\t" + "\t".join(k for k, _ in KRITERIEN) + "\tkommentar\tzeit"]
    for m in modelle():
        u = d.get(m["modell"], {})
        z.append("\t".join([m["modell"]]
                 + [str(u.get(k, "")) for k, _ in KRITERIEN]
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
            if len(teile) == 1: teile.append("index.html")
            modell, datei = teile
            # Kein Ausbrechen aus dem Spielverzeichnis.
            basis = os.path.realpath(os.path.join(SPIELE, modell))
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
            if k in ein: e[k] = bool(ein[k])
        if "kommentar" in ein:
            t = (ein["kommentar"] or "").strip()
            if t: e["kommentar"] = t
            else: e.pop("kommentar", None)
        e["zeit"] = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
        d[m] = e; speichern(d)
        return self._send(200, "application/json; charset=utf-8", json.dumps({"ok": True}))

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

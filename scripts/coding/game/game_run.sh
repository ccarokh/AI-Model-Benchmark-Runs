#!/bin/bash
# Agility-Spiel: dieselbe Aufgabe an jedes Coding-Modell.
#
#   game_run.sh                 # alle Modelle aus der Liste
#   game_run.sh qwen3.8-27b     # nur eines
#
# Was die Maschine hier misst, ist bewusst wenig: laeuft es, wie lang ist es,
# wie lange hat es gedauert, hat es die abzaehlbaren Anforderungen. Ob das Spiel
# SPIELBAR ist, kann nur ein Mensch sagen -- dafuer gibt es den Bewertungsserver.
set -u
E=/root/eval/game
M=/opt/llm-infra/models
D=/sys/class/drm/card1/device
AUFGABE=$E/task.md
PORT=18099; SPID=""
mkdir -p $E
L=$E/game.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a $L; }

declare -A MODELLE=(
  [qwen3.8-27b]=$M/qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf
  [qwen3.6-35b-a3b]=$M/qwen3.6-35b-a3b/Qwen3.6-35B-A3B-Q4_K_M.gguf
  [ornith-35b]=$M/ornith-35b/ornith-1.0-35b-Q4_K_M.gguf
  [qwen3-coder-30b-a3b]=$M/qwen3-coder-30b-a3b/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
  [mistral-small-3.2-24b]=$M/mistral-small-3.2-24b/Mistral-Small-3.2-24B-Instruct-2506-Q4_K_M.gguf
  [gpt-oss-20b]=$M/gpt-oss-20b/gpt-oss-20b-MXFP4.gguf
  [qwen3.5-27b]=$M/qwen3.5-27b/Qwen3.5-27B-Q4_K_M.gguf
)
AUSWAHL=("${@:-}")
[ -z "${AUSWAHL[0]:-}" ] && AUSWAHL=("${!MODELLE[@]}")

stop(){ [ -n "$SPID" ] && kill $SPID 2>/dev/null; sleep 6; [ -n "$SPID" ] && kill -9 $SPID 2>/dev/null; SPID=""; sleep 4; }
trap stop EXIT INT TERM
frei(){ for i in $(seq 1 45); do
    v=$(( $(cat $D/mem_info_vram_used)/1048576 )); s=$(pgrep -x llama-server|wc -l)
    [ "$v" -lt 500 ] && [ "$s" -eq 0 ] && return 0; sleep 20; done
  sag "  Karte belegt -- uebersprungen"; return 1; }

# DER PRUEFSTAND WIRD MITGEMESSEN, NICHT NUR DAS MODELL.
# Bei Belebele war der Pruefstand 70 Punkte wert; hier stecken mindestens fuenf
# Entscheidungen drin, die das Ergebnis tragen und keine Modelleigenschaft sind:
#   turns=1        ein Modell, das seinen eigenen Fehler in Runde 2 behoebe,
#                  wird hier dafuer bestraft, dass es keine zweite Runde gibt
#   max_tokens     wer laenger schreibt, wird abgeschnitten -- truncated zaehlt mit
#   temperature    0.2 ist eine Wahl, keine Naturkonstante
#   template       kommt aus der GGUF (--jinja), nicht von uns
#   extraction     wir schneiden HTML per Regex heraus; wer anders formatiert,
#                  verliert an unserem Parser, nicht am Koennen
HARNESS_TURNS=1
HARNESS_MAXTOK=16384
HARNESS_TEMP=0.2
HARNESS_ID="oneshot-t${HARNESS_TEMP}-m${HARNESS_MAXTOK}"

[ -f "$E/ergebnis.tsv" ] || printf 'model\tharness\tturns\ttemperature\tmax_tokens\ttruncated\tseconds\ttokens\thtml_bytes\traw_or_fenced\thtml_closed\troute\timages_requested\tcanvas_or_svg\tjump_key\tduck_key\tscore\trestart\tspeedup\n' > $E/ergebnis.tsv

for name in "${AUSWAHL[@]}"; do
  g="${MODELLE[$name]:-}"
  [ -s "$g" ] || { sag "$name: GGUF fehlt"; continue; }
  ziel=$E/$name; mkdir -p "$ziel"
  [ -s "$ziel/spiel.html" ] && { sag "$name: schon da, uebersprungen"; continue; }
  frei || continue
  sag "=== $name ==="
  export LD_LIBRARY_PATH=/opt/llama-cpp-nb/lib
  setsid nohup /opt/llama-cpp-nb/bin/llama-server -m "$g" --host 127.0.0.1 --port $PORT \
     -c 32768 -np 1 -ngl 99 -sm none -mg 0 --jinja > $ziel/server.log 2>&1 < /dev/null & SPID=$!
  ok=nein
  for i in $(seq 1 120); do curl -s -m 3 http://127.0.0.1:$PORT/health 2>/dev/null|grep -q ok && { ok=ja; break; }
    kill -0 $SPID 2>/dev/null || break; sleep 5; done
  [ $ok = ja ] || { sag "  Server kam nicht hoch"; stop; continue; }

  t0=$(date +%s)
  /root/evalvenv/bin/python - "$AUFGABE" "$ziel" > "$ziel/meta.json" 2>>$L <<'PY'
import json, re, sys, httpx
aufgabe = open(sys.argv[1]).read()
# Nur den Aufgabenteil senden, nicht unsere Begruendung darunter.
prompt = aufgabe.split("---")[1].strip()
r = httpx.post("http://127.0.0.1:18099/v1/chat/completions", timeout=7200.0, json={
    "messages": [{"role": "user", "content": prompt}],
    "temperature": 0.2, "max_tokens": 16384})
d = r.json(); m = d["choices"][0]["message"]
text = (m.get("content") or "")
ziel = sys.argv[2]
open(ziel + "/roh.txt", "w").write(text)

# HTML herausloesen -- robust, weil das Format des Modells KEINE Anforderung ist.
# Eine Antwort in einen Markdown-Block zu setzen ist normales Verhalten; wer
# daran scheitert, scheitert an unserem Parser und nicht am Koennen. Deshalb:
# Zaeune entfernen, Prosa davor und danach ignorieren, groesstes HTML nehmen.
def html_finden(t):
    """Dokument im Antworttext finden. Grob lokalisieren, dann PARSEN.

    Regex allein bricht hier an einer realistischen Stelle: ein Spiel, das eine
    Game-Over-Seite zusammenbaut, kann "</html>" in einem JS-String enthalten,
    und ein nicht-gieriges Muster schneidet dort ab. Deshalb wird die aeussere
    Grenze genommen (erstes <!doctype/<html> bis LETZTES </html>) und das
    Ergebnis mit html.parser geprueft -- der Parser sagt, ob es ein Dokument ist,
    nicht das Muster.
    """
    from html.parser import HTMLParser

    class Pruefer(HTMLParser):
        def __init__(self):
            super().__init__(convert_charrefs=True)
            self.hat_html = self.hat_body = self.hat_script = False
        def handle_starttag(self, tag, attrs):
            if tag == "html": self.hat_html = True
            elif tag == "body": self.hat_body = True
            elif tag == "script": self.hat_script = True

    def ist_dokument(k):
        if not k.strip(): return False
        p = Pruefer()
        try: p.feed(k)
        except Exception: return False
        return p.hat_html and p.hat_body

    # Markdown-Zaeune sind reine Textverpackung -- die duerfen weg, bevor
    # irgendetwas geparst wird.
    bloecke = re.findall(r"```(?:[a-zA-Z]*)\s*\n(.*?)```", t, re.S)
    bloecke.append(t)

    kandidaten = []
    for k in bloecke:
        low = k.lower()
        a = low.find("<!doctype html")
        if a < 0: a = low.find("<html")
        if a < 0: continue
        e = low.rfind("</html>")          # LETZTES, nicht erstes
        kandidaten.append(k[a:e + 7] if e > a else k[a:])
    gueltig = [k for k in kandidaten if ist_dokument(k)]
    if gueltig: return max(gueltig, key=len)
    return max(kandidaten, key=len) if kandidaten else ""

html = html_finden(text)
open(ziel + "/spiel.html", "w").write(html)

# Bilderblock, falls Weg B
bl = re.search(r"===\s*BILDER\s*===(.*?)===\s*ENDE BILDER\s*===", text, re.S)
bilder = []
if bl:
    for zeile in bl.group(1).strip().split("\n"):
        teile = [t.strip() for t in zeile.split("|")]
        if len(teile) >= 3 and teile[0].lower().endswith((".png", ".jpg", ".webp")):
            bilder.append({"datei": teile[0], "groesse": teile[1], "prompt": "|".join(teile[2:])})
open(ziel + "/bilder.json", "w").write(json.dumps(bilder, ensure_ascii=False, indent=1))

low = html.lower()
tok = (d.get("usage") or {}).get("completion_tokens") or 0
print(json.dumps({
    "tokens": tok,
    # Abgeschnitten heisst: das Modell war noch nicht fertig. Ohne diese Spalte
    # sieht ein halbes Spiel wie ein schlechtes Spiel aus.
    "truncated": tok >= 16384,
    "html_bytes": len(html),
    # Beobachtung, KEINE Bewertung: ob die Antwort roh oder in einem Block kam.
    # Das Ausgabeformat ist keine Anforderung der Aufgabe.
    "raw_or_fenced": "raw" if text.strip().lower().startswith("<!doctype") else "fenced_or_prose",
    "html_closed": html.rstrip().lower().endswith("</html>"),
    "route": "B_images" if bilder else ("A_code" if html else "none"),
    "images_requested": len(bilder),
    # Abzaehlbares, kein Urteil: taucht es im Code ueberhaupt auf?
    "canvas_or_svg": ("canvas" in low) or ("<svg" in low),
    "jump_key": bool(re.search(r"space|arrowup|keyw|'w'|\"w\"", low)),
    "duck_key": bool(re.search(r"arrowdown|keys|'s'|\"s\"|ctrl|shift", low)),
    "score": ("score" in low) or ("punkt" in low),
    "restart": ("restart" in low) or ("neustart" in low) or ("again" in low),
    "speedup": bool(re.search(r"speed\s*[+*]=|speed\s*=\s*speed|geschwindigkeit", low)),
}, ensure_ascii=False))
PY
  rc=$?; dauer=$(( $(date +%s) - t0 ))
  stop
  [ $rc -ne 0 ] && { sag "  Anfrage fehlgeschlagen"; continue; }
  HARNESS_ID="$HARNESS_ID" HARNESS_TURNS="$HARNESS_TURNS" HARNESS_TEMP="$HARNESS_TEMP" \
    HARNESS_MAXTOK="$HARNESS_MAXTOK" /root/evalvenv/bin/python - "$ziel/meta.json" "$name" "$dauer" >> $E/ergebnis.tsv <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
f = ["truncated","tokens","html_bytes","raw_or_fenced","html_closed","route","images_requested",
     "canvas_or_svg","jump_key","duck_key","score","restart","speedup"]
import os
kopf = [sys.argv[2], os.environ.get("HARNESS_ID",""), os.environ.get("HARNESS_TURNS",""),
        os.environ.get("HARNESS_TEMP",""), os.environ.get("HARNESS_MAXTOK","")]
v = [str(d.get(k, "")) for k in f]
# Reihenfolge: model harness turns temp maxtok truncated seconds tokens ...
print("\t".join(kopf + [v[0], sys.argv[3]] + v[1:]))
PY
  sag "  $(tail -1 $E/ergebnis.tsv)"
done
sag "=== GAME-LAUF DURCH ==="
echo FERTIG_GAME | tee -a $L

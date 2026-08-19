#!/bin/bash
# Agility-Spiel: EIN Lauf, beschrieben durch EINE Konfiguration.
#
#   game_run.sh config/qwen3.8-27b-standard-direkt.conf
#
# Dateiname = modell-beschreibung-pruefstand.conf, und das Skript prueft das.
#
# Modell, Pruefstand und Parameter stehen in der Konfiguration, nicht hier.
# Ein zweiter Pruefstand ist eine zweite Datei, kein zweites Skript.
#
# Was die Maschine hier misst, ist bewusst wenig: laeuft es, wie lang ist es,
# wie lange hat es gedauert, hat es die abzaehlbaren Anforderungen. Ob das Spiel
# SPIELBAR ist, kann nur ein Mensch sagen -- dafuer gibt es den Bewertungsserver.
set -u
HIER=$(dirname "$(readlink -f "$0")")
E=${GAME_DIR:-/root/eval/game}
D=/sys/class/drm/card1/device
PORT=18099; SPID=""
mkdir -p "$E"
L=$E/game.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }
ende(){ sag "  $*"; exit 1; }

CONF=${1:-}
[ -n "$CONF" ] || { echo "Aufruf: $0 <konfiguration>"; exit 2; }
[ -f "$CONF" ] || CONF=$HIER/$CONF
[ -f "$CONF" ] || { echo "Konfiguration nicht gefunden: ${1}"; exit 2; }
LAUF=$(basename "$CONF"); LAUF=${LAUF%.conf}

# --- Konfiguration lesen -----------------------------------------------------
# Kein `source`: das hier sind Daten, keine Befehle. Und ein Tippfehler im
# Schluessel MUSS abbrechen -- ein stillschweigend auf die Vorgabe
# zurueckfallendes `tmep=0.9` waere eine erfundene Messreihe.
model=""; gguf=""; harness=""; beschreibung=""
temp=0.2; maxtok=16384; ctx=32768; seed=-1; template=gguf; bildmodell=chroma
while IFS= read -r zeile; do
  zeile=${zeile%%#*}
  [ -z "${zeile// }" ] && continue
  case "$zeile" in *=*) ;; *) ende "Konfiguration: unverstaendliche Zeile: $zeile";; esac
  k=${zeile%%=*}; v=${zeile#*=}
  k=$(echo "$k" | tr -d '[:space:]'); v=$(echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$k" in
    model|gguf|harness|beschreibung|temp|maxtok|ctx|seed|template|bildmodell) printf -v "$k" '%s' "$v" ;;
    *) ende "Konfiguration: unbekannter Schluessel '$k'" ;;
  esac
done < "$CONF"
[ -n "$model" ]   || ende "Konfiguration: 'model' fehlt"
[ -n "$gguf" ]    || ende "Konfiguration: 'gguf' fehlt"
[ -n "$harness" ] || ende "Konfiguration: 'harness' fehlt"
[ -n "$beschreibung" ] || ende "Konfiguration: 'beschreibung' fehlt"
# Der Dateiname MUSS den Inhalt wiedergeben: modell-beschreibung-pruefstand.
# Eine Datei, die nach dem einen Modell heisst und das andere faehrt, ist genau
# der Fehler, der bei den Chunk-Groessen schon einmal eine erfundene Kurve
# erzeugt haette -- Etikett nachtraeglich aufgeklebt statt mitgefuehrt.
[ "$LAUF" = "$model-$beschreibung-$harness" ] || \
  ende "Dateiname und Inhalt weichen ab: '$LAUF.conf' muesste '$model-$beschreibung-$harness.conf' heissen"
[ -s "$gguf" ]    || ende "$model: GGUF fehlt: $gguf"
case "$harness" in
  direkt) ;;
  opencode|repair) ende "Pruefstand '$harness' ist noch nicht gebaut" ;;
  *)       ende "Pruefstand '$harness' unbekannt" ;;
esac
if [ "$template" != gguf ] && [ ! -s "$template" ]; then ende "Vorlage nicht gefunden: $template"; fi
case "$bildmodell" in chroma|sd35|realvis|flux|keins) ;; *) ende "Bildmodell '$bildmodell' unbekannt" ;; esac

# Der Pruefstand wird mitgemessen, nicht nur das Modell. Diese Entscheidungen
# tragen das Ergebnis und sind KEINE Modelleigenschaft -- deshalb stehen sie in
# jeder Zeile der Ergebnistabelle:
#   harness      eine Runde: wer seinen eigenen Fehler in Runde 2 behoebe, wird
#                hier dafuer bestraft, dass es keine zweite Runde gibt
#   maxtok       wer laenger schreibt, wird abgeschnitten -- truncated zaehlt mit
#   temp         0.2 ist eine Wahl, keine Naturkonstante
#   template     welche Chat-Vorlage gilt
# Nicht in dieser Liste: die Extraktion. Das Antwortformat ist keine Anforderung
# der Aufgabe, deshalb wird das Dokument geparst und nicht per Muster
# ausgeschnitten -- wer seine Antwort in einen Markdown-Block setzt, verliert
# dadurch nichts.
AUFGABE=${AUFGABE:-$HIER/task.md}
[ -s "$AUFGABE" ] || ende "Aufgabe nicht gefunden: $AUFGABE"

ziel=$E/$LAUF; mkdir -p "$ziel"
[ -s "$ziel/index.html" ] && { sag "$LAUF: schon da, uebersprungen"; exit 0; }
cat > "$ziel/lauf.json" <<J
{"lauf": "$LAUF", "model": "$model", "beschreibung": "$beschreibung", "harness": "$harness", "temp": $temp,
 "maxtok": $maxtok, "ctx": $ctx, "seed": $seed, "template": "$template", "bildmodell": "$bildmodell",
 "gguf": "$gguf", "aufgabe": "$(basename "$AUFGABE")"}
J

[ -f "$E/ergebnis.tsv" ] || printf 'lauf\tmodel\tbeschreibung\tharness\ttemperature\tmax_tokens\tctx\tseed\ttemplate\tbildmodell\ttruncated\tseconds\ttokens\thtml_bytes\traw_or_fenced\thtml_closed\troute\timages_requested\timages_generated\timage_seconds\tcanvas_or_svg\tjump_key\tduck_key\tscore\trestart\tspeedup\n' > "$E/ergebnis.tsv"

stop(){ [ -n "$SPID" ] && kill $SPID 2>/dev/null; sleep 6; [ -n "$SPID" ] && kill -9 $SPID 2>/dev/null; SPID=""; sleep 4; }
trap stop EXIT INT TERM
frei(){ for i in $(seq 1 45); do
    v=$(( $(cat $D/mem_info_vram_used)/1048576 )); s=$(pgrep -x llama-server|wc -l)
    [ "$v" -lt 500 ] && [ "$s" -eq 0 ] && return 0; sleep 20; done
  return 1; }
frei || ende "Karte belegt -- uebersprungen"

sag "=== $LAUF ($model / $beschreibung / $harness) ==="
export LD_LIBRARY_PATH=/opt/llama-cpp-nb/lib
TPL=(--jinja); [ "$template" != gguf ] && TPL=(--jinja --chat-template-file "$template")
setsid nohup /opt/llama-cpp-nb/bin/llama-server -m "$gguf" --host 127.0.0.1 --port $PORT \
   -c "$ctx" -np 1 -ngl 99 -sm none -mg 0 "${TPL[@]}" > "$ziel/server.log" 2>&1 < /dev/null & SPID=$!
ok=nein
for i in $(seq 1 120); do curl -s -m 3 http://127.0.0.1:$PORT/health 2>/dev/null|grep -q ok && { ok=ja; break; }
  kill -0 $SPID 2>/dev/null || break; sleep 5; done
[ $ok = ja ] || ende "Server kam nicht hoch"

t0=$(date +%s)
PORT=$PORT TEMP="$temp" MAXTOK="$maxtok" SEED="$seed" \
  /root/evalvenv/bin/python - "$AUFGABE" "$ziel" > "$ziel/meta.json" 2>>"$L" <<'PY'
import json, os, re, sys, httpx
aufgabe = open(sys.argv[1]).read()
# Nur den Aufgabenteil senden, nicht unsere Begruendung darunter.
prompt = aufgabe.split("---")[1].strip()
maxtok = int(os.environ["MAXTOK"]); seed = int(os.environ["SEED"])
anfrage = {"messages": [{"role": "user", "content": prompt}],
           "temperature": float(os.environ["TEMP"]), "max_tokens": maxtok}
if seed >= 0:
    anfrage["seed"] = seed
r = httpx.post("http://127.0.0.1:%s/v1/chat/completions" % os.environ["PORT"],
               timeout=7200.0, json=anfrage)
d = r.json(); m = d["choices"][0]["message"]
text = (m.get("content") or "")
ziel = sys.argv[2]
open(ziel + "/roh.txt", "w").write(text)

# HTML herausloesen -- robust, weil das Format des Modells KEINE Anforderung ist.
# Eine Antwort in einen Markdown-Block zu setzen ist normales Verhalten; wer
# daran scheitert, scheitert an unserem Parser und nicht am Koennen.
def html_finden(t):
    """Dokument im Antworttext finden. Grob lokalisieren, dann PARSEN.

    Ein Muster allein bricht an einer realistischen Stelle: ein Spiel, das eine
    Game-Over-Seite zusammenbaut, kann "</html>" in einem JS-Text enthalten, und
    ein nicht-gieriges Muster schneidet dort ab. Deshalb wird die aeussere Grenze
    genommen (erstes <!doctype/<html> bis LETZTES </html>) und das Ergebnis mit
    html.parser geprueft -- der Parser sagt, ob es ein Dokument ist.
    """
    from html.parser import HTMLParser

    class Pruefer(HTMLParser):
        def __init__(self):
            super().__init__(convert_charrefs=True)
            self.hat_html = self.hat_body = False
        def handle_starttag(self, tag, attrs):
            if tag == "html": self.hat_html = True
            elif tag == "body": self.hat_body = True

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
open(ziel + "/index.html", "w").write(html)

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
    "truncated": tok >= maxtok,
    "html_bytes": len(html),
    # Beobachtung, KEINE Bewertung: ob die Antwort roh oder in einem Block kam.
    "raw_or_fenced": "raw" if text.strip().lower().startswith("<!doctype") else "fenced_or_prose",
    "html_closed": html.rstrip().lower().endswith("</html>"),
    "route": "B_images" if bilder else ("A_code" if html else "none"),
    "images_requested": len(bilder),
    # Abzaehlbares, kein Urteil: taucht es im Code ueberhaupt auf?
    "canvas_or_svg": ("canvas" in low) or ("<svg" in low),
    # Achtung, Pruefstandsfehler gewesen: die Leertaste kommt als keys[' '],
    # also als blankes Zeichen, nicht als das Wort "space". Der erste Entwurf
    # meldete deshalb bei einem Spiel, das einwandfrei springt, "kein Sprung".
    "jump_key": bool(re.search(r"space|arrowup|keyw|'w'|\"w\"|keys\[' '\]|== ' '|=== ' '", low)),
    "duck_key": bool(re.search(r"arrowdown|keys|'s'|\"s\"|ctrl|shift", low)),
    "score": ("score" in low) or ("punkt" in low),
    "restart": ("restart" in low) or ("neustart" in low) or ("again" in low),
    "speedup": bool(re.search(r"speed\s*[+*]=|speed\s*=\s*speed|geschwindigkeit", low)),
}, ensure_ascii=False))
PY
rc=$?; dauer=$(( $(date +%s) - t0 ))
stop
[ $rc -ne 0 ] && ende "Anfrage fehlgeschlagen"

# --- Bildstufe -------------------------------------------------------------
# Die Aufgabe erlaubt ausdruecklich, die Grafik an ein Bildmodell abzugeben --
# solange die Prompts vom Modell selbst kommen. Genau das war die Luecke der
# ersten Sonde: das Modell lieferte drei Prompts, verwies auf drei PNG, und
# niemand erzeugte sie. Dann laedt das Spiel ins Leere und sieht kaputt aus,
# obwohl der Code stimmt. Also loest der Pruefstand die Prompts ein.
#
# Das Bildmodell ist damit Teil des Pruefstands, nicht des Modells -- deshalb
# steht es in der Konfiguration und in jeder Ergebniszeile.
B=/opt/llm-infra/models; F=$B/flux1-schnell
ERZEUGT=0; BILDSEK=0
if [ "$bildmodell" != keins ] && [ -s "$ziel/bilder.json" ]; then
  case $bildmodell in
    chroma)  SD=(--diffusion-model $B/chroma1-hd/Chroma1-HD-Q4_0.gguf --vae $F/ae.safetensors
                 --t5xxl $F/t5xxl_fp8.safetensors --cfg-scale 4.0 --steps 20) ;;
    sd35)    SD=(--diffusion-model $B/sd3.5-medium/sd3.5_medium-Q4_K_M.gguf --vae $F/ae.safetensors
                 --clip_l $F/clip_l.safetensors --clip_g $B/sd3.5-medium/clip_g.safetensors
                 --t5xxl $F/t5xxl_fp8.safetensors --cfg-scale 4.5 --steps 28) ;;
    realvis) SD=(-m $B/realvisxl-v5/RealVisXL_V5.0_fp16.safetensors --cfg-scale 7.0 --steps 25) ;;
    flux)    SD=(--diffusion-model $F/flux1-schnell-Q4_K.gguf --vae $F/ae.safetensors
                 --clip_l $F/clip_l.safetensors --t5xxl $F/t5xxl_fp8.safetensors
                 --cfg-scale 1.0 --steps 4) ;;
  esac
  /root/evalvenv/bin/python "$HIER/bilder_lesen.py" "$ziel/bilder.json" > "$ziel/bilder.tsv"
  b0=$(date +%s); bnr=0
  # Kartenwaechter VOR JEDEM BILD -- am 07.08. kosteten drei ErrorDeviceLost
  # einen halben Lauf, weil ein anderer Prozess dazwischenkam.
  while IFS=$'\t' read -r datei breite hoehe prompt; do
    [ -z "$datei" ] && continue
    frei || { sag "  Karte belegt, Bild $datei uebersprungen"; continue; }
    # Seed je Bild, nicht je Lauf. Beim ersten Durchgang forderte ein Modell
    # zwei Laufphasen fuer die Animation an -- mit identischem Prompt. Ein
    # fester Seed macht daraus zwangslaeufig zweimal dasselbe Bild und toetet
    # die Animation im Pruefstand, nicht im Modell. Abgeleitet und damit
    # weiterhin wiederholbar.
    bnr=$((bnr+1))
    if /opt/sd-cpp/bin/sd-cli "${SD[@]}" -p "$prompt" -W "$breite" -H "$hoehe" --seed $((42 + bnr)) \
         -o "$ziel/$datei" >> "$ziel/bilder.log" 2>&1 && [ -s "$ziel/$datei" ]; then
      ERZEUGT=$((ERZEUGT+1)); sag "  Bild $datei ($breite x $hoehe)"
    else
      sag "  Bild $datei FEHLGESCHLAGEN"
    fi
  done < "$ziel/bilder.tsv"
  BILDSEK=$(( $(date +%s) - b0 ))
fi

DAUER=$dauer ERZEUGT=$ERZEUGT BILDSEK=$BILDSEK /root/evalvenv/bin/python - "$ziel/meta.json" "$ziel/lauf.json" >> "$E/ergebnis.tsv" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1])); c = json.load(open(sys.argv[2]))
spalten = [c["lauf"], c["model"], c["beschreibung"], c["harness"], c["temp"], c["maxtok"], c["ctx"],
           c["seed"], c["template"], c["bildmodell"], d["truncated"], os.environ["DAUER"], d["tokens"],
           d["html_bytes"], d["raw_or_fenced"], d["html_closed"], d["route"],
           d["images_requested"], os.environ["ERZEUGT"], os.environ["BILDSEK"], d["canvas_or_svg"], d["jump_key"], d["duck_key"],
           d["score"], d["restart"], d["speedup"]]
print("\t".join(str(s) for s in spalten))
PY
sag "  $(tail -1 "$E/ergebnis.tsv")"
sag "=== $LAUF DURCH ==="

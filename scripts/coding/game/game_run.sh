#!/bin/bash
# Agility-Spiel: EIN Lauf, beschrieben durch EINE Konfiguration.
#
#   game_run.sh config/qwen3-coder-30b-a3b-llamacpp-opencode.conf
#
# Aufbau: der Pruefstand laeuft hier (.201) in einem Behaelter, der Modellserver
# auf dem Messrechner (.192) an der Karte. Getrennt, weil ein Agent, der Dateien
# schreibt und Befehle ausfuehrt, waehrend einer Messung keine Fremdlast auf dem
# Messrechner sein darf -- und weil fremd erzeugter Code gekapselt gehoert.
#
# Gemessen wird IMMER mit vollem Pruefstand. Ein einzelner Aufruf ohne Werkzeuge
# war einmal als Nulllinie gedacht und ist gestrichen: er misst nicht, was ein
# Modell kann, sondern was ihm die Umgebung verwehrt.
set -u
HIER=$(dirname "$(readlink -f "$0")")
E=${PRUEF_DIR:-/root/pruef}
MESS=${MESSRECHNER:-192.168.40.192}
PORT=18099
mkdir -p "$E/game"
L=$E/game.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }
ende(){ sag "  $*"; server_stop; exit 1; }

CONF=${1:-}
[ -n "$CONF" ] || { echo "Aufruf: $0 <konfiguration>"; exit 2; }
[ -f "$CONF" ] || CONF=$HIER/$CONF
[ -f "$CONF" ] || { echo "Konfiguration nicht gefunden: ${1}"; exit 2; }
LAUF=$(basename "$CONF"); LAUF=${LAUF%.conf}

# --- Konfiguration ---------------------------------------------------------
# Kein `source`: das sind Daten, keine Befehle. Und ein Tippfehler im Schluessel
# MUSS abbrechen -- ein stillschweigend auf die Vorgabe zurueckfallendes
# tmep=0.9 waere eine erfundene Messreihe.
model=""; gguf=""; harness=""; beschreibung=""; runtime=""
temp=0.2; maxtok=16384; ctx=32768; template=gguf; zeitlimit=3600; aufgabe=task.md
while IFS= read -r zeile; do
  zeile=${zeile%%#*}
  [ -z "${zeile// }" ] && continue
  case "$zeile" in *=*) ;; *) ende "Konfiguration: unverstaendliche Zeile: $zeile";; esac
  k=${zeile%%=*}; v=${zeile#*=}
  k=$(echo "$k" | tr -d '[:space:]'); v=$(echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$k" in
    model|gguf|harness|beschreibung|runtime|temp|maxtok|ctx|template|zeitlimit|aufgabe)
      printf -v "$k" '%s' "$v" ;;
    *) ende "Konfiguration: unbekannter Schluessel '$k'" ;;
  esac
done < "$CONF"
for pflicht in model gguf harness beschreibung runtime; do
  [ -n "${!pflicht}" ] || ende "Konfiguration: '$pflicht' fehlt"
done
# Der Dateiname MUSS den Inhalt wiedergeben. Ein Etikett, das nachtraeglich
# aufgeklebt wird, hat bei den Chunk-Groessen schon fast eine erfundene Kurve
# erzeugt -- hier bricht es ab.
[ "$LAUF" = "$model-$beschreibung-$harness" ] || \
  ende "Dateiname und Inhalt weichen ab: '$LAUF.conf' muesste '$model-$beschreibung-$harness.conf' heissen"
case "$harness" in
  opencode) ;;
  *) ende "Pruefstand '$harness' unbekannt" ;;
esac
case "$runtime" in
  llamacpp) ;;
  vllm) [ -n "$(ssh -n $MESS 'command -v docker' 2>/dev/null)" ] || ende "vLLM braucht Docker auf $MESS" ;;
  *) ende "Laufzeit '$runtime' unbekannt" ;;
esac
AUFGABE=$HIER/$aufgabe
[ -s "$AUFGABE" ] || ende "Aufgabe nicht gefunden: $AUFGABE"

ziel=$E/game/$LAUF
[ -s "$ziel/arbeit/index.html" ] && { sag "$LAUF: schon da, uebersprungen"; exit 0; }
rm -rf "$ziel"; mkdir -p "$ziel/arbeit" "$ziel/occonfig"
chown -R 1000:1000 "$ziel/arbeit" "$ziel/occonfig"

# Nur den Aufgabenteil, nicht die Begruendung darunter.
awk 'BEGIN{n=0} /^---$/{n++; next} n==1' "$AUFGABE" > "$ziel/aufgabe.txt"
[ -s "$ziel/aufgabe.txt" ] || ende "Aufgabentext leer -- Trennlinien in $aufgabe pruefen"

cat > "$ziel/lauf.json" <<J
{"lauf": "$LAUF", "model": "$model", "beschreibung": "$beschreibung",
 "harness": "$harness", "runtime": "$runtime", "temp": $temp, "maxtok": $maxtok,
 "ctx": $ctx, "template": "$template", "zeitlimit": $zeitlimit,
 "aufgabe": "$aufgabe", "gguf": "$gguf", "messrechner": "$MESS"}
J

[ -f "$E/ergebnis.tsv" ] || printf 'lauf\tmodel\tbeschreibung\tharness\truntime\ttemperature\tmax_tokens\tctx\ttemplate\tzeitlimit\tabgebrochen\tsekunden\tdateien\tbytes\that_index\tcanvas_or_svg\tjump_key\tduck_key\tscore\trestart\tspeedup\textern\n' > "$E/ergebnis.tsv"

# --- Modellserver auf dem Messrechner ---------------------------------------
server_stop(){
  ssh -n "$MESS" 'p=$(pgrep -x llama-server); [ -n "$p" ] && kill $p; sleep 5;
                  p=$(pgrep -x llama-server); [ -n "$p" ] && kill -9 $p; true' >/dev/null 2>&1
  [ "${runtime:-}" = vllm ] && ssh -n "$MESS" 'docker rm -f vllm-mess' >/dev/null 2>&1
  return 0
}
trap 'server_stop' EXIT INT TERM

frei(){ for i in $(seq 1 45); do
    r=$(ssh -n "$MESS" 'echo $(( $(cat /sys/class/drm/card1/device/mem_info_vram_used)/1048576 )) $(pgrep -x llama-server|wc -l)' 2>/dev/null)
    set -- $r
    [ "${1:-9999}" -lt 500 ] && [ "${2:-1}" -eq 0 ] && return 0
    sleep 20; done
  return 1; }
frei || ende "Karte auf $MESS belegt -- uebersprungen"

sag "=== $LAUF ($model / $beschreibung / $harness / $runtime) ==="
case "$runtime" in
  llamacpp)
    TPL='--jinja'; [ "$template" != gguf ] && TPL="--jinja --chat-template-file $template"
    ssh -n "$MESS" "export LD_LIBRARY_PATH=/opt/llama-cpp-nb/lib; setsid nohup /opt/llama-cpp-nb/bin/llama-server -m '$gguf' --host 0.0.0.0 --port $PORT -c $ctx -np 1 -ngl 99 -sm none -mg 0 $TPL > /root/eval/game_srv.log 2>&1 < /dev/null & echo ok" >/dev/null
    ;;
  vllm)
    ende "vLLM-Abbild ist noch nicht gebaut" ;;
esac
ok=nein
for i in $(seq 1 120); do
  curl -s -m 3 "http://$MESS:$PORT/health" 2>/dev/null | grep -q ok && { ok=ja; break; }
  sleep 5; done
[ $ok = ja ] || ende "Modellserver kam nicht hoch"

# --- Pruefstand -------------------------------------------------------------
cat > "$ziel/occonfig/opencode.json" <<J
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "lokal": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "$runtime auf $MESS",
      "options": { "baseURL": "http://$MESS:$PORT/v1", "apiKey": "egal" },
      "models": { "$model": { "name": "$model" } }
    }
  },
  "model": "lokal/$model",
  "small_model": "lokal/$model"
}
J
chown 1000:1000 "$ziel/occonfig/opencode.json"

t0=$(date +%s)
timeout "$zeitlimit" docker run --rm \
  -v "$ziel/occonfig":/home/pruef/.config/opencode \
  -v "$ziel/arbeit":/arbeit \
  -e OPENCODE_TEMPERATURE="$temp" \
  pruefstand:1 opencode run "$(cat "$ziel/aufgabe.txt")" > "$ziel/agent.log" 2>&1
rc=$?; dauer=$(( $(date +%s) - t0 ))
abgebrochen=nein; [ $rc -eq 124 ] && abgebrochen=zeitlimit
server_stop
sag "  Agent fertig nach ${dauer}s (rc=$rc)"

/usr/bin/python3 "$HIER/game_messen.py" "$ziel" "$dauer" "$abgebrochen" >> "$E/ergebnis.tsv" || ende "Auswertung fehlgeschlagen"
sag "  $(tail -1 "$E/ergebnis.tsv")"
sag "=== $LAUF DURCH ==="

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
model=""; gguf=""; hf=""; quant=""; harness=""; beschreibung=""; runtime=""
temp=0.2; maxtok=16384; ctx=32768; template=gguf; zeitlimit=3600; aufgabe=task.md
tool_parser=""; denken=an
while IFS= read -r zeile; do
  zeile=${zeile%%#*}
  [ -z "${zeile// }" ] && continue
  case "$zeile" in *=*) ;; *) ende "Konfiguration: unverstaendliche Zeile: $zeile";; esac
  k=${zeile%%=*}; v=${zeile#*=}
  k=$(echo "$k" | tr -d '[:space:]'); v=$(echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$k" in
    model|gguf|hf|quant|harness|beschreibung|runtime|temp|maxtok|ctx|template|zeitlimit|aufgabe|tool_parser|denken)
      printf -v "$k" '%s' "$v" ;;
    *) ende "Konfiguration: unbekannter Schluessel '$k'" ;;
  esac
done < "$CONF"
for pflicht in model quant harness beschreibung runtime; do
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
# Die beiden Laufzeiten lesen nicht dieselbe Datei: llama.cpp will GGUF, vLLM
# will HF-Format. Wo dazu eine andere Quantisierung noetig ist, macht das den
# Lauf nicht ungueltig -- es macht ihn zu einem anderen Lauf, und deshalb steht
# `quant` in jeder Ergebniszeile. Verglichen wird dann Laufzeit UND Gewicht,
# und wer die Tabelle liest, sieht es.
case "$runtime" in
  llamacpp) [ -n "$gguf" ] || ende "runtime=llamacpp braucht 'gguf'"
            [ -s "$(ssh -n $MESS "readlink -f '$gguf'" 2>/dev/null)" ] 2>/dev/null || true ;;
  vllm) [ -n "$hf" ] || ende "runtime=vllm braucht 'hf' (Pfad oder HF-Kennung)"
        # OFFEN heisst: noch nicht gemessen, welche Gewichte vLLM hier lesen kann.
        # Lieber sichtbar abbrechen als still etwas Beliebiges laden.
        [ "$hf" = OFFEN ] && ende "Gewichte fuer vLLM noch nicht bestimmt (hf = OFFEN)"
        [ -n "$(ssh -n $MESS 'command -v docker' 2>/dev/null)" ] || ende "vLLM braucht Docker auf $MESS"
        # llama.cpp leitet den Aufrufstil aus der Vorlage in der GGUF ab. vLLM
        # verlangt ihn benannt, je Modellfamilie ein eigener Parser -- und ohne
        # ihn liefert der Server 400 bei jedem Werkzeugaufruf. Das ist ein
        # Unterschied der Laufzeiten, kein Detail, und gehoert deshalb in die
        # Konfiguration statt in eine Fallunterscheidung im Skript.
        [ -n "$tool_parser" ] || ende "runtime=vllm braucht 'tool_parser'" ;;
  *) ende "Laufzeit '$runtime' unbekannt" ;;
esac
AUFGABE=$HIER/$aufgabe
[ -s "$AUFGABE" ] || ende "Aufgabe nicht gefunden: $AUFGABE"

ziel=$E/game/$LAUF
[ -s "$ziel/arbeit/index.html" ] && { sag "$LAUF: schon da, uebersprungen"; exit 0; }
rm -rf "$ziel"; mkdir -p "$ziel/arbeit" "$ziel/occonfig" "$ziel/ocdaten"
chown -R 1000:1000 "$ziel/arbeit" "$ziel/occonfig" "$ziel/ocdaten"

# Nur den Aufgabenteil, nicht die Begruendung darunter.
awk 'BEGIN{n=0} /^---$/{n++; next} n==1' "$AUFGABE" > "$ziel/aufgabe.txt"
[ -s "$ziel/aufgabe.txt" ] || ende "Aufgabentext leer -- Trennlinien in $aufgabe pruefen"
# Nicht der Dateiname zaehlt, sondern der Text. Die Aufgabe hat sich an einem
# Nachmittag achtzehnmal geaendert; zwei Laeufe mit "task.md" in der Spalte
# koennen voellig verschiedene Aufgaben gehabt haben. Der Fingerabdruck macht
# das sichtbar, statt es unter einem gleichen Etikett zu verstecken.
aufgabe_id=$(sha256sum "$ziel/aufgabe.txt" | cut -c1-12)

cat > "$ziel/lauf.json" <<J
{"lauf": "$LAUF", "model": "$model", "beschreibung": "$beschreibung",
 "harness": "$harness", "runtime": "$runtime", "temp": $temp, "maxtok": $maxtok,
 "ctx": $ctx, "template": "$template", "zeitlimit": $zeitlimit,
 "aufgabe": "$aufgabe", "aufgabe_id": "$aufgabe_id", "quant": "$quant",
 "tool_parser": "$tool_parser", "denken": "$denken", "gguf": "$gguf", "hf": "$hf",
 "messrechner": "$MESS"}
J

[ -f "$E/ergebnis.tsv" ] || printf 'lauf\tmodel\tbeschreibung\tharness\truntime\tquant\taufgabe_id\ttemperature\tmax_tokens\tctx\ttemplate\tzeitlimit\tabgebrochen\tsekunden\tdateien\tbytes\that_index\tcanvas_or_svg\tjump_key\tduck_key\tscore\trestart\tspeedup\textern\n' > "$E/ergebnis.tsv"

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
    # Denkmodus. Ein Modell, das zwoelf Minuten denkt und dabei nie einen
    # Werkzeugaufruf abschliesst, sieht aus wie ein Modell, das nichts kann.
    # Ob das an ihm liegt oder daran, dass wir den Modus anlassen, entscheidet
    # ein Lauf mit "aus" -- und beide Zeilen bleiben in der Tabelle stehen.
    [ "$denken" = aus ] && TPL="$TPL --chat-template-kwargs {\"enable_thinking\":false}"
    ssh -n "$MESS" "export LD_LIBRARY_PATH=/opt/llama-cpp-nb/lib; setsid nohup /opt/llama-cpp-nb/bin/llama-server -m '$gguf' --host 0.0.0.0 --port $PORT -c $ctx -np 1 -ngl 99 -sm none -mg 0 $TPL > /root/eval/game_srv.log 2>&1 < /dev/null & echo ok" >/dev/null
    ;;
  vllm)
    # Der Behaelter braucht die Karte durchgereicht -- anders als der Pruefstand,
    # der nur ueber HTTP redet. Kein --rm hier: bricht der Start ab, soll das
    # Protokoll noch da sein.
    ssh -n "$MESS" "docker rm -f vllm-mess >/dev/null 2>&1; setsid nohup docker run --name vllm-mess \
      --device=/dev/kfd --device=/dev/dri --group-add video \
      --security-opt seccomp=unconfined --shm-size 8g --ipc=host \
      -v /opt/llm-infra/models:/models -p $PORT:8000 \
      rocm/vllm:latest vllm serve '$hf' \
        --served-model-name '$model' \
        --max-model-len $ctx --gpu-memory-utilization 0.85 \
        --enable-auto-tool-choice --tool-call-parser '$tool_parser' \
      > /root/eval/vllm_srv.log 2>&1 < /dev/null & echo ok" >/dev/null
    ;;
esac
ok=nein
# llama.cpp antwortet auf /health mit einem Text, vLLM mit leerem 200. Deshalb
# auf den Statuscode pruefen und nicht auf den Inhalt.
for i in $(seq 1 180); do
  code=$(curl -s -o /dev/null -m 3 -w "%{http_code}" "http://$MESS:$PORT/health" 2>/dev/null)
  [ "$code" = 200 ] && { ok=ja; break; }
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
# Das eigene Protokoll des Agenten mit herausfuehren. Ohne es blieb bei einem
# Modell 731 Sekunden lang unklar, was passiert ist: der Modellserver zeigte
# Anfragen ueber 13733 Token, das Behaelterprotokoll drei Zeilen. Wer nicht
# mitschreibt, kann hinterher nur raten.
timeout "$zeitlimit" docker run --rm \
  -v "$ziel/occonfig":/home/pruef/.config/opencode \
  -v "$ziel/ocdaten":/home/pruef/.local/share/opencode \
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

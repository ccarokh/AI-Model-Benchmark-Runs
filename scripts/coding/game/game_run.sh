#!/bin/bash
# Agility game: ONE run, described by ONE config file.
#
#   game_run.sh config/qwen3-coder-30b-a3b-llamacpp-opencode.conf
#
# Layout: the harness runs here (.201) in a container, the model server runs on
# the measuring machine (.192) at the card. Separate, because an agent that
# writes files and runs commands must not be foreign load on the measuring
# machine during a measurement -- and because foreign code belongs sandboxed.
#
# Measurement is ALWAYS with the full harness. A single call without tools was
# once meant as a baseline and has been dropped: it measures not what a model
# can do but what the environment denies it.
set -u
HIER=$(dirname "$(readlink -f "$0")")
E=${PRUEF_DIR:-/root/pruef}
MESS=${MESSRECHNER:?MESSRECHNER ist nicht gesetzt, z.B. 10.0.0.2}
# NOT 18099: llm-runtime.service sits there, the on-demand server of the live
# infrastructure. The harness moves aside rather than getting in its way.
PORT=18199
mkdir -p "$E/game"
L=$E/game.log
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }
ende(){ sag "  $*"; server_stop; exit 1; }

CONF=${1:-}
[ -n "$CONF" ] || { echo "Aufruf: $0 <konfiguration>"; exit 2; }
[ -f "$CONF" ] || CONF=$HIER/$CONF
[ -f "$CONF" ] || { echo "Konfiguration nicht gefunden: ${1}"; exit 2; }
LAUF=$(basename "$CONF"); LAUF=${LAUF%.conf}

# --- Config ----------------------------------------------------------------
# No `source`: this is data, not commands. And a typo in a key MUST abort -- a
# silently-ignored tmep=0.9 falling back to the default would be a fabricated
# series.
model=""; gguf=""; hf=""; quant=""; harness=""; beschreibung=""; runtime=""
temp=0.2; maxtok=16384; ctx=32768; template=gguf; zeitlimit=3600; aufgabe=aufgabe.md
tool_parser=""; denken=an; tokenizer=""; tokenizer_mode=""
while IFS= read -r zeile; do
  zeile=${zeile%%#*}
  [ -z "${zeile// }" ] && continue
  case "$zeile" in *=*) ;; *) ende "Konfiguration: unverstaendliche Zeile: $zeile";; esac
  k=${zeile%%=*}; v=${zeile#*=}
  k=$(echo "$k" | tr -d '[:space:]'); v=$(echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$k" in
    model|gguf|hf|quant|harness|beschreibung|runtime|temp|maxtok|ctx|template|zeitlimit|aufgabe|tool_parser|denken|tokenizer|tokenizer_mode)
      printf -v "$k" '%s' "$v" ;;
    *) ende "Konfiguration: unbekannter Schluessel '$k'" ;;
  esac
done < "$CONF"
for pflicht in model quant harness beschreibung runtime; do
  [ -n "${!pflicht}" ] || ende "Konfiguration: '$pflicht' fehlt"
done
# The filename MUST reflect the contents. A label stuck on afterwards nearly
# produced a fabricated curve once already, with the chunk sizes -- here it
# aborts instead.
[ "$LAUF" = "$model-$beschreibung-$harness" ] || \
  ende "Dateiname und Inhalt weichen ab: '$LAUF.conf' muesste '$model-$beschreibung-$harness.conf' heissen"
# A harness is a file under harness/, not a case statement here. Adding another
# agent means writing one file and one config whose name ends in it. This script
# knows no agent by name.
ADAPTER=$HIER/harness/$harness.sh
[ -f "$ADAPTER" ] || ende "Pruefstand '$harness' unbekannt -- es gibt kein harness/$harness.sh"
. "$ADAPTER"
for f in agent_vorbereiten agent_ausfuehren; do
  command -v "$f" >/dev/null || ende "harness/$harness.sh liefert '$f' nicht"
done
# The two runtimes do not read the same file: llama.cpp wants GGUF, vLLM wants
# HF format. Where that requires a different quantisation, it does not make the
# run invalid -- it makes it a different run, which is why `quant` appears in
# every result row. Then runtime AND weights differ, and whoever reads the table
# can see it.
case "$runtime" in
  llamacpp) [ -n "$gguf" ] || ende "runtime=llamacpp braucht 'gguf'"
            [ -s "$(ssh -n $MESS "readlink -f '$gguf'" 2>/dev/null)" ] 2>/dev/null || true ;;
  vllm) [ -n "$hf" ] || ende "runtime=vllm braucht 'hf' (Pfad oder HF-Kennung)"
        # OFFEN means: not yet measured which weights vLLM can read here.
        # Better to abort visibly than to quietly load something arbitrary.
        [ "$hf" = OFFEN ] && ende "Gewichte fuer vLLM noch nicht bestimmt (hf = OFFEN)"
        [ -n "$(ssh -n $MESS 'command -v docker' 2>/dev/null)" ] || ende "vLLM braucht Docker auf $MESS"
        # llama.cpp derives the tool-call style from the template inside the
        # GGUF. vLLM wants it named, one parser per model family -- and without
        # it the server answers 400 to every tool call. That is a difference
        # between runtimes, not a detail, so it belongs in the config rather
        # than in a case statement here.
        [ -n "$tool_parser" ] || ende "runtime=vllm braucht 'tool_parser'" ;;
  *) ende "Laufzeit '$runtime' unbekannt" ;;
esac
AUFGABE=$HIER/$aufgabe
[ -s "$AUFGABE" ] || ende "Aufgabe nicht gefunden: $AUFGABE"

ziel=$E/game/$LAUF
[ -s "$ziel/arbeit/index.html" ] && { sag "$LAUF: schon da, uebersprungen"; exit 0; }
rm -rf "$ziel"; mkdir -p "$ziel/arbeit" "$ziel/occonfig" "$ziel/ocdaten"
chown -R 1000:1000 "$ziel/arbeit" "$ziel/occonfig" "$ziel/ocdaten"

# The task file holds the task and nothing else -- it goes out unchanged. The
# prompt used to live inside a document between two --- lines and was cut out
# with awk: a horizontal rule inside the prompt would have truncated it
# silently, and the results would only have shown that every model suddenly got
# worse.
cp "$AUFGABE" "$ziel/aufgabe.txt"
[ -s "$ziel/aufgabe.txt" ] || ende "Aufgabendatei ist leer: $aufgabe"
# What counts is the text, not the filename. The task changed eighteen times in
# one afternoon; two runs both reading "task.md" in that column can have had
# entirely different tasks. The fingerprint makes that visible instead of hiding
# it under an identical label.
aufgabe_id=$(sha256sum "$ziel/aufgabe.txt" | cut -c1-12)

cat > "$ziel/lauf.json" <<J
{"lauf": "$LAUF", "model": "$model", "beschreibung": "$beschreibung",
 "harness": "$harness", "runtime": "$runtime", "temp": $temp, "maxtok": $maxtok,
 "ctx": $ctx, "template": "$template", "zeitlimit": $zeitlimit,
 "aufgabe": "$aufgabe", "aufgabe_id": "$aufgabe_id", "quant": "$quant",
 "tool_parser": "$tool_parser", "denken": "$denken",
 "tokenizer": "$tokenizer", "tokenizer_mode": "$tokenizer_mode", "gguf": "$gguf", "hf": "$hf",
 "messrechner": "$MESS"}
J

[ -f "$E/ergebnis.tsv" ] || printf 'lauf\tmodel\tbeschreibung\tharness\truntime\tquant\taufgabe_id\ttemperature\tmax_tokens\tctx\ttemplate\tzeitlimit\tabgebrochen\tsekunden\tdateien\tbytes\that_index\tausserhalb\tagenten_dateien\tsyntax_ok\tgeoeffnet\tlaufzeit_fehler\tkonsole_fehler\tfehlende_dateien\tcanvas_bemalt\tcanvas_or_svg\tjump_key\tduck_key\tscore\trestart\tspeedup\textern\n' > "$E/ergebnis.tsv"

# --- Model server on the measuring machine ----------------------------------
server_stop(){
  ssh -n "$MESS" 'p=$(pgrep -x llama-server); [ -n "$p" ] && kill $p; sleep 5;
                  p=$(pgrep -x llama-server); [ -n "$p" ] && kill -9 $p; true' >/dev/null 2>&1
  [ "${runtime:-}" = vllm ] && ssh -n "$MESS" 'docker rm -f vllm-mess' >/dev/null 2>&1
  return 0
}
trap 'server_stop' EXIT INT TERM

# Card guard by memory only. Checking for "no llama-server" no longer works:
# llm-runtime.service keeps one running permanently, usually with a small
# embedding model. What matters is whether the card is free enough -- a large
# model takes gigabytes, not megabytes.
frei(){ for i in $(seq 1 45); do
    v=$(ssh -n "$MESS" 'echo $(( $(cat /sys/class/drm/card1/device/mem_info_vram_used)/1048576 ))' 2>/dev/null)
    [ "${v:-99999}" -lt 2000 ] && return 0
    sleep 20; done
  return 1; }
frei || ende "Karte auf $MESS belegt -- uebersprungen"

sag "=== $LAUF ($model / $beschreibung / $harness / $runtime) ==="
case "$runtime" in
  llamacpp)
    TPL='--jinja'; [ "$template" != gguf ] && TPL="--jinja --chat-template-file $template"
    # Thinking mode. A model that thinks for twelve minutes and never completes
    # a tool call looks like a model that can do nothing. Whether that is the
    # model or our leaving the mode on is decided by a run with "aus" -- and
    # both rows stay in the table.
    # Single quotes are mandatory: the whole command travels through ssh as a
    # double-quoted string, and bare JSON falls apart into
    # {enable_thinking:false} on the way -- llama-server then refuses to start.
    [ "$denken" = aus ] && TPL="$TPL --chat-template-kwargs '{\"enable_thinking\":false}'"
    ssh -n "$MESS" "export LD_LIBRARY_PATH=/opt/llama-cpp-nb/lib; setsid nohup /opt/llama-cpp-nb/bin/llama-server -m '$gguf' --host 0.0.0.0 --port $PORT -c $ctx -np 1 -ngl 99 -sm none -mg 0 $TPL > /root/eval/game_srv.log 2>&1 < /dev/null & echo ok" >/dev/null
    ;;
  vllm)
    # Tool calls from GGUF weights: the bundled text parser is not always
    # enough. Mistral writes [TOOL_CALLS]name[ARGS]{...}, and none of the 29
    # parsers in the image knows the [ARGS] separator -- the call then lands as
    # prose in the response and the agent sees none at all. With the Mistral
    # tokenizer, fetched separately from the weights, it is recognised. That is
    # an operating instruction, not a failure, so it belongs in the config.
    TOK=""
    [ -n "$tokenizer" ] && TOK="--tokenizer $tokenizer"
    [ -n "$tokenizer_mode" ] && TOK="$TOK --tokenizer-mode $tokenizer_mode"
    # This container needs the card passed through -- unlike the harness, which
    # only speaks HTTP. No --rm here: if the start fails, the log should still
    # be there.
    ssh -n "$MESS" "docker rm -f vllm-mess >/dev/null 2>&1; setsid nohup docker run --name vllm-mess \
      --device=/dev/kfd --device=/dev/dri --group-add video \
      --security-opt seccomp=unconfined --shm-size 8g --ipc=host \
      -v /opt/llm-infra/models:/opt/llm-infra/models:ro -p $PORT:8000 \
      rocm/vllm:latest vllm serve '$hf' \
        --served-model-name '$model' $TOK \
        --max-model-len $ctx --gpu-memory-utilization 0.85 \
        --enable-auto-tool-choice --tool-call-parser '$tool_parser' \
      > /root/eval/vllm_srv.log 2>&1 < /dev/null & echo ok" >/dev/null
    ;;
esac
ok=nein
# llama.cpp answers /health with text, vLLM with an empty 200. So check the
# status code, not the body.
#
# And: notice a dead server instead of waiting 15 minutes for it. vLLM gives up
# on an unsupported architecture after two minutes -- the other thirteen were
# pure waiting, six times in one night.
for i in $(seq 1 180); do
  code=$(curl -s -o /dev/null -m 3 -w "%{http_code}" "http://$MESS:$PORT/health" 2>/dev/null)
  [ "$code" = 200 ] && { ok=ja; break; }
  if [ "$runtime" = vllm ] && [ $i -gt 6 ]; then
    ssh -n "$MESS" 'docker ps --filter name=vllm-mess --format "{{.Names}}" | grep -q vllm-mess' || { ok=tot; break; }
  fi
  sleep 5; done
# The model server's log belongs to the run, not to a file the next run
# overwrites. Without this, six failures left only the last reason known.
if [ "$runtime" = vllm ]; then
  ssh -n "$MESS" 'tail -200 /root/eval/vllm_srv.log' > "$ziel/server.log" 2>/dev/null
else
  ssh -n "$MESS" 'tail -200 /root/eval/game_srv.log' > "$ziel/server.log" 2>/dev/null
fi
if [ "$ok" = tot ]; then
  grund=$(grep -aoE "(ValueError|OSError|RuntimeError|NotImplementedError):.*" "$ziel/server.log" | tail -1 | cut -c1-160)
  ende "Modellserver beendet sich: ${grund:-Grund siehe server.log}"
fi
[ $ok = ja ] || ende "Modellserver kam nicht hoch"

# --- Harness ----------------------------------------------------------------
# From here the work belongs to the adapter. What applies to all of them is in
# harness/README.md -- in particular that the limits belong in EVERY config:
# without them the agents guess, and a guessed max_tokens has already looked
# like model failure here.
agent_vorbereiten

t0=$(date +%s)
agent_ausfuehren
rc=$?; dauer=$(( $(date +%s) - t0 ))

# --- Pre-check ---------------------------------------------------------------
# Does the game run at all? Script syntax first, then the page in a headless
# browser, logging whatever goes wrong.
#
# In a SEPARATE container, and only after the agent has exited. A browser in the
# agent image would be a tool available to the model -- it could open and fix
# its own game, and that would be a different harness than the one we measure.
#
# If the checker fails, the file stays empty and so do the columns. A missing
# tool must not make a model look bad.
: > "$ziel/vorpruefung.json"
# The checker writes its screenshot as user 1000; the run directory belongs to
# root. Without this line it fails with EACCES -- and the error would be filed
# as a runtime error of the game, although it is ours.
chown 1000:1000 "$ziel" "$ziel/vorpruefung.json"
if docker image inspect spielpruefer:1 >/dev/null 2>&1; then
  { docker run --rm -v "$ziel/arbeit":/arbeit:ro -v "$ziel":/aus \
      spielpruefer:1 node /opt/pruefen/vorpruefung.js /arbeit
    docker run --rm -v "$ziel/arbeit":/arbeit:ro -v "$ziel":/aus \
      spielpruefer:1 node /opt/pruefen/laufzeit.js /arbeit /aus/bildschirm.png
  } > "$ziel/vorpruefung.json" 2>"$ziel/vorpruefung.log"
else
  sag "  Spielpruefer-Abbild fehlt -- Vorpruefung uebersprungen"
fi
abgebrochen=nein; [ $rc -eq 124 ] && abgebrochen=zeitlimit
server_stop
sag "  Agent fertig nach ${dauer}s (rc=$rc)"

/usr/bin/python3 "$HIER/game_messen.py" "$ziel" "$dauer" "$abgebrochen" >> "$E/ergebnis.tsv" || ende "Auswertung fehlgeschlagen"
sag "  $(tail -1 "$E/ergebnis.tsv")"
sag "=== $LAUF DURCH ==="

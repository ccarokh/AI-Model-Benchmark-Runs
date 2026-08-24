#!/bin/bash
# What the drift check does not cover: does the SERVER still behave the same.
#
#   server_smoke.sh /opt/llama-cpp-v0.2.0
#
# The drift check compares throughput and one completion hash from llama-cli.
# That is not what production runs. Production runs llama-server with a chat
# template, tool definitions and, for one model, a projector. Those are the
# parts a version bump breaks, and none of them shows up in a tokens-per-second
# number.
#
# Three probes, each run on the CANDIDATE and on the PRODUCTION build in the
# same session, because "it works" is not an answer -- "it does the same" is:
#
#   1. chat with --jinja       the template path itself
#   2. tool call               what an agentic harness depends on; recorded for
#                              tool_choice "required" AND "auto", since auto is
#                              already known to be unreliable on this slot
#   3. vision with --mmproj    the most fragile path we run in production
#
# One server at a time, killed by PID -- never by pattern, which has matched the
# killing process itself here more than once.
set -u

KANDIDAT=${1:-/opt/llama-cpp-v0.2.0}
PROD=${PROD:-/opt/llama-cpp}
CHAT=${CHAT:-/opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf}
VLM=${VLM:-/opt/llm-infra/models/gemma-4-12b-it/gemma-4-12b-it-Q4_K_M.gguf}
MMPROJ=${MMPROJ:-/opt/llm-infra/models/gemma-4-12b-it/mmproj-F16.gguf}
BILD=${BILD:-/root/probe_1024.jpg}
PORT=${PORT:-18099}
RUNTIME=${RUNTIME:-http://127.0.0.1:8080}
SCHLUESSEL=${SCHLUESSEL:-/etc/bench/lease.token}
L=${L:-/root/eval/server_smoke.log}
PACHT_ID=${PACHT_ID:-}; GEERBT=nein; HERZ=""; SRV=""

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "$L"; }

aufraeumen(){
  [ -n "$SRV" ] && kill "$SRV" 2>/dev/null && wait "$SRV" 2>/dev/null
  [ "$GEERBT" = ja ] && return 0
  [ -n "$HERZ" ] && kill "$HERZ" 2>/dev/null
  if [ -n "$PACHT_ID" ]; then
    curl -s -m 10 -o /dev/null -X DELETE "$RUNTIME/_manager/lease/$PACHT_ID" \
         -H "x-lease-token: $(cat "$SCHLUESSEL")" || true
    sag "Pacht $PACHT_ID zurueckgegeben"; PACHT_ID=""
  fi
}
trap aufraeumen EXIT INT TERM

pacht_nehmen(){
  # A step started inside the night window inherits the scheduler's lease: it is
  # already held, and llm-runtime grants exactly one. Asking for a second one is
  # refused, and the step then dies before it measures anything -- which is what
  # happened at 04:58 to both validation steps while the long series ran on.
  if [ -n "$PACHT_ID" ]; then GEERBT=ja; sag "Pacht $PACHT_ID vom Aufrufer geerbt"; return 0; fi
  local t a; t=$(cat "$SCHLUESSEL") || return 1
  a=$(curl -s -m 10 -X POST "$RUNTIME/_manager/lease" -H "x-lease-token: $t" \
        -H "Content-Type: application/json" -d '{"holder":"server_smoke"}')
  PACHT_ID=$(printf '%s' "$a" | sed -n 's/.*"lease_id":"\([^"]*\)".*/\1/p')
  [ -n "$PACHT_ID" ] || { sag "Pacht verweigert: $(printf '%s' "$a" | cut -c1-160)"; return 1; }
  sag "Pacht $PACHT_ID gehalten"
  ( while :; do sleep 120
      curl -s -m 10 -o /dev/null -X POST "$RUNTIME/_manager/lease/$PACHT_ID/heartbeat" \
           -H "x-lease-token: $t" || true
    done ) & HERZ=$!
}

server_starten(){  # $1 prefix, rest: extra arguments
  local pfad="$1"; shift
  LD_LIBRARY_PATH="$pfad/lib" "$pfad/bin/llama-server" --host 127.0.0.1 --port "$PORT" \
      -ngl 99 --device Vulkan0 --jinja --no-warmup "$@" >>"$L.srv" 2>&1 &
  SRV=$!
  for i in $(seq 1 120); do
    curl -s -m 2 "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q '"ok"' && return 0
    kill -0 "$SRV" 2>/dev/null || { sag "  Server beendet sich beim Start -- siehe $L.srv"; SRV=""; return 1; }
    sleep 5
  done
  sag "  Server wurde in 10 min nicht bereit"; return 1
}
server_beenden(){ [ -n "$SRV" ] && { kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; SRV=""; sleep 5; }; }

frage(){  # stdin = request body -> answer body
  curl -s -m 300 "http://127.0.0.1:$PORT/v1/chat/completions" \
       -H "Content-Type: application/json" --data-binary @- 2>/dev/null
}

# ---- the three probes, each printing ONE line that can be compared ----------
probe_chat(){
  # max_tokens 512, not 64: the chat model is a reasoning model. With a short
  # budget the whole allowance goes into the thinking block, the answer never
  # starts, and the probe reports LEER for a server that is working fine.
  # An empty answer therefore has to say WHY -- finish_reason and whether the
  # model was still thinking. "LEER" without a reason is a bug report about the
  # probe, not about the build.
  printf '{"model":"x","temperature":0,"seed":1234,"max_tokens":512,"messages":[{"role":"user","content":"Name the first ten prime numbers, comma separated, nothing else."}]}' \
  | frage | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('LEER (keine gueltige Antwort)'); sys.exit()
if d.get('error'): print('FEHLER %s' % str(d['error'])[:90]); sys.exit()
w=(d.get('choices') or [{}])[0]
m=w.get('message',{})
c=(m.get('content') or '').strip()
if c: print(' '.join(c.split())[:120]); sys.exit()
r=(m.get('reasoning_content') or '').strip()
print('LEER (finish=%s, denk-text %d Zeichen)' % (w.get('finish_reason'), len(r)))"
}

probe_werkzeug(){  # $1 = tool_choice
  printf '{"model":"x","temperature":0,"seed":1234,"tool_choice":"%s","tools":[{"type":"function","function":{"name":"get_weather","description":"Current weather for a city","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}],"messages":[{"role":"user","content":"What is the weather in Cologne? Use the tool."}]}' "$1" \
  | frage | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('LEER'); sys.exit()
m=(d.get('choices') or [{}])[0].get('message',{})
tc=m.get('tool_calls') or []
if not tc: print('KEIN_AUFRUF text=%r' % (' '.join((m.get('content') or '').split())[:60])); sys.exit()
f=tc[0].get('function',{})
try:
    a=json.loads(f.get('arguments') or '{}'); gueltig='ja'
except Exception: a={}; gueltig='nein'
print('AUFRUF name=%s argumente_gueltig=%s stadt=%s' % (f.get('name'), gueltig, a.get('city')))"
}

probe_bild(){
  python3 - "$BILD" "$PORT" <<'PY'
import base64, json, sys, urllib.request
bild, port = sys.argv[1], sys.argv[2]
b = base64.b64encode(open(bild, 'rb').read()).decode()
koerper = json.dumps({"model": "x", "temperature": 0, "seed": 1234, "max_tokens": 256,
    "messages": [{"role": "user", "content": [
        {"type": "text", "text": "Describe this image in one short sentence."},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b}}]}]}).encode()
try:
    r = urllib.request.urlopen(urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/chat/completions", koerper,
        {"Content-Type": "application/json"}), timeout=600)
    d = json.loads(r.read())
except Exception as e:
    print("FEHLER %s" % str(e)[:80]); raise SystemExit
if d.get("error"):
    print("FEHLER %s" % str(d["error"])[:90]); raise SystemExit
w = (d.get("choices") or [{}])[0]
c = (w.get("message", {}).get("content") or "").strip()
print(" ".join(c.split())[:120] if c else "LEER (finish=%s)" % w.get("finish_reason"))
PY
}

pruefen(){  # $1 = label, $2 = prefix
  local marke="$1" pfad="$2"
  sag "=== $marke ($pfad) ==="
  [ -x "$pfad/bin/llama-server" ] || { sag "  kein llama-server in $pfad"; return 1; }

  server_starten "$pfad" -m "$CHAT" --ctx-size 8192 || return 1
  sag "  chat        : $(probe_chat)"
  sag "  werkzeug/req: $(probe_werkzeug required)"
  sag "  werkzeug/aut: $(probe_werkzeug auto)"
  server_beenden

  server_starten "$pfad" -m "$VLM" --mmproj "$MMPROJ" --ctx-size 8192 || return 1
  sag "  bild        : $(probe_bild)"
  server_beenden
}

[ -x "$KANDIDAT/bin/llama-server" ] || { sag "kein Kandidat unter $KANDIDAT"; exit 2; }
pacht_nehmen || exit 1
sag "Kandidat $(cat "$KANDIDAT/.built-version" 2>/dev/null || echo '?') gegen Produktiv $(cat "$PROD/.built-version" 2>/dev/null || echo '?')"
pruefen "PRODUKTIV" "$PROD"
pruefen "KANDIDAT"  "$KANDIDAT"
sag "Die vier Zeilen je Stand gehoeren nebeneinander gelesen: gleiche Antwort, gleicher"
sag "Werkzeugaufruf, gleiche Bildbeschreibung. Ein Unterschied ist ein Befund, kein Rauschen."
sag "=== RAUCHTEST DURCH ==="

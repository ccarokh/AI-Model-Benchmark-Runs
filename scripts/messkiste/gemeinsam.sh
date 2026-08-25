# Shared helpers for the System C measurements. Sourced, not executed.
#
# Everything here exists because of a mistake this repository already made:
# a warm process that measured the previous run, a number taken while the card
# was busy with something else, a throughput figure from a card that had already
# reset itself, and a power figure averaged over the model load.
BAU=${BAU:-/opt/mess/llama.cpp/build}
MODELLE=${MODELLE:-/opt/mess/models}
M3=$MODELLE/llama-3.2-3b/Llama-3.2-3B-Instruct-Q4_K_M.gguf
M9=$MODELLE/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf

sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*" | tee -a "${L:-/root/mess/lauf.log}"; }

# "pp tg" from one llama-bench run, empty if it produced nothing. A step that
# prints an empty line where a number belongs must be visible as such -- an
# empty measurement that reads as a result is the failure mode this repo keeps
# running into.
bench(){   # $1 = binary directory, rest = arguments
  local b="$1"; shift
  LD_LIBRARY_PATH="$b" timeout 3600 "$b/llama-bench" "$@" -o json 2>>"${L:-/dev/null}.bench" | python3 -c "
import json, sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(1)
v = {}
for e in d:
    v['tg' if e['n_gen'] and not e['n_prompt'] else 'pp'] = e['avg_ts']
if not v: sys.exit(1)
print('%.2f %.2f' % (v.get('pp', 0), v.get('tg', 0)))"
}

# Same output, or only faster? A build or a flag that changes the answer has not
# made the same work faster -- it has done different work.
#
# It says why it has no hash rather than handing back a hash of nothing. The
# first version piped a missing binary into sha256sum and reported
# e3b0c44298fc1c14 for all four runs -- the checksum of an empty stream, printed
# as if two builds had agreed. The drift check on the other machine had the same
# defect the same night; a probe that cannot fail is not a probe.
LEER_HASH=e3b0c44298fc1c14

# WHICH FLAGS DOES THIS BUILD ACTUALLY KNOW?
# `-no-cnv` was accepted by v0.2.0 (21.08.) and is gone in 70adb1b (23.08.).
# Hard-coding it turned every comparison against a newer build into "produced no
# output" -- on this machine and on the drift check of the other one, where it
# cost a red verdict for a build that was probably fine. A removed CLI flag is a
# real upstream change and worth reporting; reporting it as an empty measurement
# is not. So the flags are read off --help, per build.
cli_flags(){  # $1 = binary directory
  local h f bin
  bin="$1/llama-completion"; [ -x "$bin" ] || bin="$1/llama-cli"
  h=$(LD_LIBRARY_PATH="$1" "$bin" --help 2>&1)
  f="--simple-io --no-warmup"
  printf '%s' "$h" | grep -q -- "-no-cnv"            && f="$f -no-cnv"
  printf '%s' "$h" | grep -q -- "--single-turn"      && f="$f -st"
  printf '%s' "$h" | grep -q -- "--no-display-prompt" && f="$f --no-display-prompt"
  printf '%s' "$f"
}

# Same output, or only faster? A build or a flag that changes the answer has not
# made the same work faster -- it has done different work.
#
# It says WHY it has no hash rather than handing one back for nothing. The first
# version piped a missing binary into sha256sum and reported e3b0c44298fc1c14 --
# the checksum of an empty stream -- for all four runs, as if two builds had
# agreed.
# llama-completion, not llama-cli. Current llama.cpp defaults llama-cli to
# conversation mode for instruct models, and the switch that turned that off
# (-no-cnv) is gone -- so it prints its answer and then sits in an interactive
# loop with nothing to read, until the timeout kills it. Ten minutes per probe,
# for a hash it had already produced in two seconds. llama-completion is the
# non-interactive tool and exits on its own.
ausgabe_hash(){  # $1 = binary directory, $2 = model
  local h fehler bin
  bin=""
  [ -x "$1/llama-completion" ] && bin="$1/llama-completion"
  [ -z "$bin" ] && [ -x "$1/llama-cli" ] && bin="$1/llama-cli"
  [ -n "$bin" ] || { echo "KEIN llama-completion/llama-cli in $1"; return 1; }
  h=$(LD_LIBRARY_PATH="$1" timeout 180 "$bin" -m "$2" -ngl 99 --seed 1234 --temp 0 \
      -n 96 --ctx-size 4096 $(cli_flags "$1") -p "List the first ten prime numbers." \
      < /dev/null 2>/tmp/cli_fehler.$$ | sha256sum | cut -c1-16)
  if [ "$h" = "$LEER_HASH" ]; then
    fehler=$(grep -m1 -iE "error|invalid|unknown" /tmp/cli_fehler.$$ | cut -c1-70)
    rm -f /tmp/cli_fehler.$$
    echo "LEER${fehler:+ -- $fehler}"; return 1
  fi
  rm -f /tmp/cli_fehler.$$
  echo "$h"
}

karte_leer(){
  for i in $(seq 1 30); do
    local v; v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
    [ "${v:-9999}" -lt 500 ] && return 0
    sleep 10
  done
  return 1
}

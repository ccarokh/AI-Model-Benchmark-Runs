#!/bin/bash
# Die SATA-Platte hier bestuecken, BEVOR sie in die 4070-Kiste wandert.
#
# Aufteilung: alles, was Netz oder fremde Rechner braucht, passiert HIER --
# Modelle, Skripte, Quelltext. Die 4070-Kiste bekommt eine Platte, die alles
# mitbringt, und braucht dort weder Netz noch Zugriff auf .192.
#
#   4070_platte_bestuecken.sh /mnt/arch      # Einhaengepunkt der Arch-Wurzel
set -eu
ZIEL=${1:?Einhaengepunkt der frisch installierten Arch-Wurzel angeben}
QUELLE_LOKAL=${QUELLE_LOKAL:-/home/arokh/KI/Coding/models}
QUELLE_FERN=${QUELLE_FERN:-root@192.168.40.192:/opt/llm-infra/models}
REPO=${REPO:-/home/arokh/KI/AI-Model-Benchmark-Runs}
sag(){ echo "[$(date '+%H:%M:%S')] $*"; }

[ -d "$ZIEL/etc" ] || { echo "$ZIEL sieht nicht nach einer Linux-Wurzel aus"; exit 1; }
M=$ZIEL/opt/mess
mkdir -p "$M/models" "$M/scripts"

# Die Auswahl fuer 12 GB. Die 27B-Klasse faellt weg -- 16 GB nur fuer die
# Gewichte. Uebrig bleibt genau das Feld, in dem hier die interessanteste
# Beobachtung steckt: der 5,4-GB-Standard, den kein groesseres Modell
# geschlagen hat, und das Coding-Modell, das ihn auf Deutsch dann doch schlug.
for m in qwen3.5-9b ornith-9b qwen2.5-coder-14b bge-m3; do
  if [ -d "$QUELLE_LOKAL/$m" ]; then
    sag "$m  <- lokal"
    rsync -a --info=progress2 "$QUELLE_LOKAL/$m/" "$M/models/$m/"
  else
    sag "$m  <- $QUELLE_FERN"
    rsync -a --info=progress2 "$QUELLE_FERN/$m/" "$M/models/$m/"
  fi
done

sag "Quelltext von llama.cpp mitgeben (die Kiste soll nichts holen muessen)"
[ -d "$M/llama.cpp" ] || git clone --depth 1 https://github.com/ggml-org/llama.cpp "$M/llama.cpp"
git -C "$M/llama.cpp" log -1 --format="  Bau: %H  %ad" --date=short

sag "Messskripte mitgeben"
cp "$REPO/scripts/hardware/4070_messen.sh" "$M/scripts/"
chmod +x "$M/scripts/4070_messen.sh"

sag "fertig"
du -sh "$M"/* | sed 's/^/  /'
cat <<ENDE

Auf der 4070-Kiste dann nur noch:
  bash /opt/mess/scripts/4070_messen.sh
ENDE

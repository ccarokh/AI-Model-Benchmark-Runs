#!/bin/bash
# Fetch the arms for the QAT comparison plus two extras. Ungated, no token.
set -u
B=/opt/mess/models
hole(){  # ziel-unterordner  dateiname  url
  mkdir -p "$B/$1"
  [ -s "$B/$1/$2" ] && { echo "  $1/$2 schon da"; return 0; }
  echo "  hole $1/$2"
  curl -fL --retry 3 -o "$B/$1/$2.teil" "$3" || { echo "  FEHLER bei $1/$2"; return 1; }
  # Erst umbenennen, wenn der Download durch ist -- eine halbe Datei unter dem
  # richtigen Namen sieht fuer jeden Test wie ein kaputtes Modell aus.
  head -c 4 "$B/$1/$2.teil" | grep -q GGUF || { echo "  KEIN GGUF: $1/$2"; rm -f "$B/$1/$2.teil"; return 1; }
  mv "$B/$1/$2.teil" "$B/$1/$2"
}
G=https://huggingface.co
hole gemma-4-12b-qat  gemma-4-12b-it-qat-q4_0.gguf  $G/google/gemma-4-12B-it-qat-q4_0-gguf/resolve/main/gemma-4-12b-it-qat-q4_0.gguf
hole gemma-4-12b-q4_0 gemma-4-12B-it-Q4_0.gguf      $G/ggml-org/gemma-4-12B-it-GGUF/resolve/main/gemma-4-12B-it-Q4_0.gguf
hole gemma-4-12b-mtp  mtp-gemma-4-12B-it-Q4_0.gguf  $G/ggml-org/gemma-4-12B-it-GGUF/resolve/main/mtp-gemma-4-12B-it-Q4_0.gguf
hole llama-3.1-8b     Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf $G/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf
echo FERTIG

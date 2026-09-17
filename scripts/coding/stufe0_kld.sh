#!/bin/bash
# Stage 0 of the Qwen3.8-27B question: how much does Q4_K_M cost, measured as
# KL divergence against BF16 on code — before anyone spends a night on the
# quantisation as an explanation.
#
# Two phases, because they belong to different times of day:
#   laden   -- download BF16 (55 GB), Q8_0 (29 GB), UD-Q6_K (22 GB) from
#              unsloth. Daytime only: a download during a measurement is load.
#   messen  -- llama-perplexity with --kl-divergence-base on BF16, then
#              --kl-divergence on each quant. Night queue, card leased.
# BF16 does not fit RAM+VRAM (55 GB against 15+24); it streams from NVMe per
# chunk, which is slow and fine for a few hundred KB of text.
# The text is code from the llama.cpp tree on this machine: deterministic,
# present, and the domain the model is being judged on.
set -uo pipefail
D=/opt/llm-infra/models/qwen3.8-27b-eval      # eval scratch, deleted afterwards
B=${B:-/opt/llama-cpp-stufe1}                  # pinned master snapshot (GDN fix in)
Q4=/opt/llm-infra/models/qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf
TXT=/root/eval/kld_code.txt
OUT=/root/eval/kld_qwen38.tsv
HF=https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main
sag(){ echo "[$(date '+%d.%m. %H:%M:%S')] $*"; }

case "${1:-}" in
laden)
  mkdir -p $D; cd $D
  for f in BF16/Qwen3.8-27B-BF16-00001-of-00002.gguf BF16/Qwen3.8-27B-BF16-00002-of-00002.gguf \
           Qwen3.8-27B-Q8_0.gguf Qwen3.8-27B-UD-Q6_K.gguf; do
    sag "lade $f"
    curl -sSL -C - --retry 5 --create-dirs -o "$f" "$HF/$f?download=true" || { sag "  FEHLER bei $f"; exit 1; }
  done
  ls -la $D $D/BF16; sag "geladen"
  ;;
messen)
  for f in $D/BF16/Qwen3.8-27B-BF16-00001-of-00002.gguf $D/Qwen3.8-27B-Q8_0.gguf $D/Qwen3.8-27B-UD-Q6_K.gguf; do
    [ -s "$f" ] || { sag "fehlt: $f -- Phase laden zuerst"; exit 1; }
  done
  [ -x $B/bin/llama-perplexity ] || { sag "kein $B/bin/llama-perplexity"; exit 1; }
  if [ ! -s $TXT ]; then
    # ~300 KB C and Python from the source tree; fixed files, fixed order.
    { head -c 200000 /opt/src/llama.cpp/ggml/src/ggml.c; head -c 100000 /opt/src/llama.cpp/convert_hf_to_gguf.py; } > $TXT
  fi
  [ -s "$OUT" ] || printf "datum\tbuild\tquant\tppl\tkld_mean\tkld_p99\ttop1_agree\tseconds\n" > "$OUT"
  export LD_LIBRARY_PATH=$B/lib
  v=$(cat $B/.built-version)
  sag "=== Referenz BF16 (streamt von NVMe, dauert) ==="
  t0=$(date +%s)
  timeout -k 30 10800 $B/bin/llama-perplexity -m $D/BF16/Qwen3.8-27B-BF16-00001-of-00002.gguf -f $TXT -c 2048 -b 512 -ngl 20 \
      --kl-divergence-base /root/eval/kld_bf16.base > /root/eval/kld_bf16.log 2>&1
  rc=$?; s=$(( $(date +%s) - t0 ))
  ppl=$(grep -oE "Final estimate: PPL = [0-9.]+" /root/eval/kld_bf16.log | grep -oE "[0-9.]+$")
  printf "%s\t%s\tBF16\t%s\t0\t0\t100\t%s\n" "$(date +%F)" "$v" "${ppl:-?}" "$s" >> "$OUT"
  sag "  BF16: rc=$rc ppl=${ppl:-?} (${s}s)"
  [ -s /root/eval/kld_bf16.base ] || { sag "keine Referenzdatei -- Abbruch"; exit 1; }
  for q in "Q8_0:$D/Qwen3.8-27B-Q8_0.gguf" "UD-Q6_K:$D/Qwen3.8-27B-UD-Q6_K.gguf" "Q4_K_M:$Q4"; do
    name=${q%%:*}; g=${q#*:}
    sag "=== $name ==="
    t0=$(date +%s)
    timeout -k 30 7200 $B/bin/llama-perplexity -m "$g" -f $TXT -c 2048 -b 512 -ngl 99 \
        --kl-divergence-base /root/eval/kld_bf16.base --kl-divergence > /root/eval/kld_$name.log 2>&1
    s=$(( $(date +%s) - t0 ))
    # llama-perplexity prints a summary block: Mean KLD, 99.0% KLD, Same top p
    ppl=$(grep -oE "Mean PPL\(Q\)[^0-9]*[0-9.]+" /root/eval/kld_$name.log | grep -oE "[0-9.]+$" | tail -1)
    kld=$(grep -oE "Mean KLD:? *[0-9.]+" /root/eval/kld_$name.log | grep -oE "[0-9.]+$" | tail -1)
    k99=$(grep -oE "99\.0% *KLD:? *[0-9.]+" /root/eval/kld_$name.log | grep -oE "[0-9.]+$" | tail -1)
    top=$(grep -oE "Same top p:? *[0-9.]+" /root/eval/kld_$name.log | grep -oE "[0-9.]+$" | tail -1)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$(date +%F)" "$v" "$name" "${ppl:-?}" "${kld:-?}" "${k99:-?}" "${top:-?}" "$s" >> "$OUT"
    sag "  $name: ppl=${ppl:-?} kld=${kld:-?} p99=${k99:-?} top1=${top:-?} (${s}s)"
  done
  echo FERTIG_KLD
  ;;
*) echo "usage: $0 laden|messen"; exit 2 ;;
esac

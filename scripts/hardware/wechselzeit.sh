#!/bin/bash
# How long does a model swap take, from launching llama-server to /health = 200?
# That is the wait a user sees on the first request after llm-runtime switched
# models. Cold = page cache dropped (the 15 GB situation: the file comes from
# NVMe). Warm = the same load again right after (the 64 GB situation: the file
# is already in RAM). Own server on its own port; llm-runtime is not touched.
B=/opt/llama-cpp; export LD_LIBRARY_PATH=$B/lib
PORT=8199
OUT=/root/eval/wechselzeit.tsv
[ -s $OUT ] || printf "datum\tmodell\tgroesse_gb\tzustand\tsekunden_bis_bereit\tcache_gb_vorher\n" > $OUT
bereit(){ # $1 = gguf -> seconds until /health answers 200
  local t0=$(date +%s.%N)
  $B/bin/llama-server -m "$1" --host 127.0.0.1 --port $PORT -ngl 99 -sm none -mg 0 \
      -c 8192 --no-warmup > /root/eval/wechselzeit_srv.log 2>&1 &
  local pid=$!
  for i in $(seq 1 1200); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' -m 1 http://127.0.0.1:$PORT/health)" = 200 ] && break
    kill -0 $pid 2>/dev/null || { echo "abgestuerzt"; return 1; }
    sleep 0.1
  done
  local t1=$(date +%s.%N)
  kill $pid; wait $pid 2>/dev/null
  echo "$t1 - $t0" | bc
}
for g in /opt/llm-infra/models/qwen3.5-9b/Qwen3.5-9B-Q4_K_M.gguf \
         /opt/llm-infra/models/gemma-4-12b-it/gemma-4-12b-it-Q4_K_M.gguf \
         /opt/llm-infra/models/qwen3-coder-30b-a3b/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf; do
  n=$(basename $(dirname $g)); gb=$(echo "scale=1; $(stat -c %s $g)/1073741824" | bc)
  for z in kalt warm; do
    [ $z = kalt ] && { sync; echo 3 > /proc/sys/vm/drop_caches; sleep 2; }
    c=$(free -g | awk '/^Mem:/{print $6}')
    s=$(bereit "$g")
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$(date +%F)" "$n" "$gb" "$z" "$s" "$c" >> $OUT
    printf "  %-22s %5s GB  %-5s %7s s   (Cache vorher %s GB)\n" "$n" "$gb" "$z" "$s" "$c"
  done
done
echo FERTIG_WECHSELZEIT

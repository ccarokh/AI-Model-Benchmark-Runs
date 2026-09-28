#!/bin/bash
# Do the offloaded expert layers scale with CPU threads? Qwen3-Coder-Next, every
# expert in host memory (-ncmoe 99), threads 1..16 on an 8-core/16-thread 9900K.
B=/opt/llama-cpp-master; export LD_LIBRARY_PATH=$B/lib
G=/opt/llm-infra/models/qwen3-coder-next/qwen3-coder-next-q4_k_m.gguf
j=$(timeout 3000 $B/bin/llama-bench -m "$G" -p 512 -n 64 -r 1 -ngl 99 -sm none -mg 0 -ncmoe 99 -t 1,2,4,8,16 -o json 2>/dev/null)
printf '%s' "$j" | python3 -c '
import json,sys
r={}
for e in json.load(sys.stdin):
    r.setdefault(e["n_threads"],{})["pp" if e["n_prompt"] else "tg"]=e["avg_ts"]
for t in sorted(r): print("  %2d Threads:  Prefill %7.2f   Generation %6.2f t/s" % (t, r[t].get("pp",0), r[t].get("tg",0)))'

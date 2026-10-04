#!/usr/bin/env python3
"""Qwen3.8-Flash-Next UD-IQ1_S with every expert in host memory (-ncmoe 99): two levers.

  lazy   -- master reads tensors above 4 GiB on demand (--lazy-mode auto, the default
            since 27.08.; the n-gram table is flagged for it). auto against off:
            resident memory, load time, speed.
  cache  -- PR #27861 (draft): a GPU-resident LRU cache for host-offloaded experts,
            --moe-expert-cache N slots per layer. 0 / 16 / 32 / 64 slots: speed, VRAM.

Each arm in a fresh llama-server process. Three prompts, 512 tokens each, greedy,
thinking off; the cache only acts in decode, so generation speed is the figure.
Usage: flashnext_test.py
"""
import json, os, subprocess, sys, time, urllib.request

G = "/opt/llm-infra/models/qwen3.8-flash-next/Qwen3.8-Flash-Next-UD-IQ1_S-00001-of-00003.gguf"
TSV = "/root/eval/flashnext_test.tsv"
VRAM = "/sys/class/drm/card1/device/mem_info_vram_used"
PORT = 18197
M, P = "/opt/llama-cpp-master", "/opt/llama-cpp-pr27861"
PROMPTS = [
    "Write a Python function that parses an ISO 8601 duration string like 'P3DT4H5M' into seconds, with type hints and a ValueError on invalid input.",
    "Explain in German, in about 300 words, how a hash map handles collisions, with one short code example.",
    "Implement binary search over a sorted slice in Go and write three table-driven tests for it.",
]
ARMS = [("lazy-auto", M, []), ("lazy-off", M, ["--lazy-mode", "off"]),
        ("cache-0", P, []), ("cache-16", P, ["--moe-expert-cache", "16"]),
        ("cache-32", P, ["--moe-expert-cache", "32"]), ("cache-64", P, ["--moe-expert-cache", "64"])]

def rss_gib(pid):
    for l in open(f"/proc/{pid}/status"):
        if l.startswith("VmRSS:"): return round(int(l.split()[1]) / 1048576, 2)

def main():
    neu = not os.path.exists(TSV)
    out = open(TSV, "a")
    if neu: out.write("date\tarm\tbuild\tload_s\trss_gib\tvram_mib\tlazy_tensors\tprompt\tpp_tps\ttg_tps\tpredicted_n\n")
    for arm, b, extra in ARMS:
        if not os.path.exists(b + "/bin/llama-server"):
            print(f"  {arm}: Build {b} fehlt -- uebersprungen", flush=True); continue
        log = f"/root/eval/flashnext_server_{arm}.log"
        args = [b + "/bin/llama-server", "-m", G, "--host", "127.0.0.1", "--port", str(PORT), "--device", "Vulkan0",
                "-ngl", "99", "-ncmoe", "99", "-c", "8192", "-np", "1", "--jinja", "--no-warmup"] + extra
        t0 = time.time()
        srv = subprocess.Popen(args, env=dict(os.environ, LD_LIBRARY_PATH=b + "/lib"),
                               stdout=open(log, "w"), stderr=subprocess.STDOUT)
        try:
            for _ in range(900):
                try:
                    if urllib.request.urlopen(f"http://127.0.0.1:{PORT}/health", timeout=2).status == 200: break
                except Exception: pass
                if srv.poll() is not None: break
                time.sleep(1)
            if srv.poll() is not None:
                print(f"  {arm}: Server beendet, siehe {log}", flush=True)
                out.write(f"{time.strftime('%F')}\t{arm}\t{b}\t-\t-\t-\t-\t-\t-\t-\tfehler\n"); out.flush(); continue
            load = round(time.time() - t0, 1)
            lazy = sum(1 for l in open(log) if "lazy read enabled" in l)
            for i, p in enumerate(PROMPTS):
                req = urllib.request.Request(f"http://127.0.0.1:{PORT}/v1/chat/completions", json.dumps(
                    {"messages": [{"role": "user", "content": p}], "max_tokens": 512, "temperature": 0, "seed": 1,
                     "chat_template_kwargs": {"enable_thinking": False}}).encode(), {"Content-Type": "application/json"})
                t = json.load(urllib.request.urlopen(req, timeout=1800)).get("timings", {})
                row = [time.strftime("%F"), arm, b, load, rss_gib(srv.pid), int(open(VRAM).read()) // 1048576, lazy, i,
                       round(t.get("prompt_per_second", 0), 1), round(t.get("predicted_per_second", 0), 2), t.get("predicted_n", "")]
                out.write("\t".join(map(str, row)) + "\n"); out.flush()
                print("  " + "  ".join(map(str, row[1:])), flush=True)
        finally:
            srv.terminate()
            try: srv.wait(60)
            except subprocess.TimeoutExpired: srv.kill()
            time.sleep(5)
    print("FERTIG_FLASHNEXT")

if __name__ == "__main__":
    main()

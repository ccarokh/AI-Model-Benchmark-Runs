#!/usr/bin/env python3
"""MTP speculative decoding on Qwen3.8-27B (the GGUF carries one nextn layer).

Arms, each in a fresh llama-server process (the server carries state between
requests, so a process is never reused across arms):
  base                      -- no speculation
  mtp n=1/2/3               -- --spec-type draft-mtp --spec-draft-n-max n
  offload base / mtp n=2    -- the same with 13 of 65 layers in host memory (-ngl 52):
                               does MTP win back what offloading costs?

Three code prompts, 512 tokens each, greedy, thinking off. Greedy speculation is
exact, so every arm must produce the same text as its base arm -- checked by hash.
Usage: mtp_test.py [build-dir]   (default: master)
"""
import hashlib, json, os, subprocess, sys, time, urllib.request

B = sys.argv[1] if len(sys.argv) > 1 else "/opt/llama-cpp-master"
G = "/opt/llm-infra/models/qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf"
TSV = "/root/eval/mtp_test.tsv"
PORT = 18198
PROMPTS = [
    "Write a Python function that parses an ISO 8601 duration string like 'P3DT4H5M' into seconds. Include type hints and handle invalid input with a ValueError.",
    "Implement a thread-safe LRU cache in Go with Get and Put methods and a fixed capacity. Explain the locking briefly.",
    "Schreibe eine Rust-Funktion, die in einem Vektor von Ganzzahlen die längste streng steigende Teilfolge findet und sie zurückgibt.",
]
ARMS = [("base", 99, None), ("mtp1", 99, 1), ("mtp2", 99, 2), ("mtp3", 99, 3),
        ("offload-base", 52, None), ("offload-mtp2", 52, 2)]

def post(body):
    req = urllib.request.Request(f"http://127.0.0.1:{PORT}/v1/chat/completions", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=1200))

def main():
    neu = not os.path.exists(TSV)
    out = open(TSV, "a")
    if neu: out.write("date\tbuild\tarm\tngl\tdraft_n_max\tprompt\ttg_tps\tpredicted_n\tdraft_n\tdraft_accepted\ttext_sha\n")
    ver = subprocess.run([B + "/bin/llama-server", "--version"], capture_output=True, text=True,
                         env=dict(os.environ, LD_LIBRARY_PATH=B + "/lib")).stderr.strip().splitlines()[0]
    for arm, ngl, n in ARMS:
        args = [B + "/bin/llama-server", "-m", G, "--host", "127.0.0.1", "--port", str(PORT), "--device", "Vulkan0",
                "-ngl", str(ngl), "-c", "16384", "-np", "1", "--jinja", "--no-warmup"]
        if n: args += ["--spec-type", "draft-mtp", "--spec-draft-n-max", str(n)]
        srv = subprocess.Popen(args, env=dict(os.environ, LD_LIBRARY_PATH=B + "/lib"),
                               stdout=open(f"/root/eval/mtp_server_{arm}.log", "w"), stderr=subprocess.STDOUT)
        try:
            for _ in range(240):
                try:
                    if urllib.request.urlopen(f"http://127.0.0.1:{PORT}/health", timeout=2).status == 200: break
                except Exception: pass
                if srv.poll() is not None: raise SystemExit(f"{arm}: Server beendet, siehe mtp_server_{arm}.log")
                time.sleep(1)
            for i, p in enumerate(PROMPTS):
                r = post({"messages": [{"role": "user", "content": p}], "max_tokens": 512, "temperature": 0,
                          "seed": 1, "chat_template_kwargs": {"enable_thinking": False}})
                t = r.get("timings", {}); txt = r["choices"][0]["message"]["content"]
                sha = hashlib.sha256(txt.encode()).hexdigest()[:12]
                row = [time.strftime("%F"), ver, arm, ngl, n or 0, i, round(t.get("predicted_per_second", 0), 2),
                       t.get("predicted_n", ""), t.get("draft_n", ""), t.get("draft_n_accepted", ""), sha]
                out.write("\t".join(map(str, row)) + "\n"); out.flush()
                print("  " + "  ".join(map(str, row[2:])), flush=True)
        finally:
            srv.terminate()
            try: srv.wait(30)
            except subprocess.TimeoutExpired: srv.kill()
            time.sleep(3)
    print("FERTIG_MTP")

if __name__ == "__main__":
    main()

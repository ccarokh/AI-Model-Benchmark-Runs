#!/usr/bin/env python3
"""MTP on Qwen3.8-27B, closer to production than mtp_test.py:

  prod-*      -- the production build (/opt/llama-cpp): does it accept draft-mtp at all?
  par4-*      -- master, 4 slots, 4 requests at once: aggregate throughput, base vs MTP n=2
  temp-*      -- master, 1 slot, sampling (temperature 0.7, top_p 0.8, top_k 20 -- Qwen's
                 non-thinking recommendation) instead of greedy: base vs MTP n=2

Fresh server per arm, 512 tokens per request, thinking off. Rows in mtp_test2.tsv.
"""
import concurrent.futures as cf, json, os, subprocess, time, urllib.request

G = "/opt/llm-infra/models/qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf"
TSV = "/root/eval/mtp_test2.tsv"
PORT = 18196
M, PR = "/opt/llama-cpp-master", "/opt/llama-cpp"
PROMPTS = [
    "Write a Python function that parses an ISO 8601 duration string like 'P3DT4H5M' into seconds. Include type hints and handle invalid input with a ValueError.",
    "Implement a thread-safe LRU cache in Go with Get and Put methods and a fixed capacity. Explain the locking briefly.",
    "Schreibe eine Rust-Funktion, die in einem Vektor von Ganzzahlen die längste streng steigende Teilfolge findet und sie zurückgibt.",
    "Erkläre in etwa 300 Wörtern, warum ein Hund an der Leine zieht und wie man das mit positiver Verstärkung trainiert.",
]
GREEDY = {"temperature": 0, "seed": 1}
SAMPLE = {"temperature": 0.7, "top_p": 0.8, "top_k": 20, "seed": 1}
ARMS = [  # name, build, slots, mtp n, sampling, parallel requests
    ("prod-base", PR, 1, 0, GREEDY, 1), ("prod-mtp2", PR, 1, 2, GREEDY, 1),
    ("par4-base", M, 4, 0, GREEDY, 4), ("par4-mtp2", M, 4, 2, GREEDY, 4),
    ("temp-base", M, 1, 0, SAMPLE, 1), ("temp-mtp2", M, 1, 2, SAMPLE, 1),
]

def ask(p, samp):
    body = {"messages": [{"role": "user", "content": p}], "max_tokens": 512,
            "chat_template_kwargs": {"enable_thinking": False}, **samp}
    req = urllib.request.Request(f"http://127.0.0.1:{PORT}/v1/chat/completions", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=1200)).get("timings", {})

def main():
    neu = not os.path.exists(TSV)
    out = open(TSV, "a")
    if neu: out.write("date\tarm\tbuild\tslots\tdraft_n_max\tparallel\tprompt\ttg_tps\tpredicted_n\tdraft_n\tdraft_accepted\twall_s\n")
    for arm, b, np_, n, samp, par in ARMS:
        args = [b + "/bin/llama-server", "-m", G, "--host", "127.0.0.1", "--port", str(PORT), "--device", "Vulkan0",
                "-ngl", "99", "-c", str(16384 * np_), "-np", str(np_), "--jinja", "--no-warmup"]
        if n: args += ["--spec-type", "draft-mtp", "--spec-draft-n-max", str(n)]
        log = f"/root/eval/mtp2_server_{arm}.log"
        srv = subprocess.Popen(args, env=dict(os.environ, LD_LIBRARY_PATH=b + "/lib"), stdout=open(log, "w"), stderr=subprocess.STDOUT)
        try:
            for _ in range(240):
                try:
                    if urllib.request.urlopen(f"http://127.0.0.1:{PORT}/health", timeout=2).status == 200: break
                except Exception: pass
                if srv.poll() is not None: break
                time.sleep(1)
            if srv.poll() is not None:
                last = [l.strip() for l in open(log)][-2:]
                print(f"  {arm}: Server startet nicht: {last}", flush=True)
                out.write(f"{time.strftime('%F')}\t{arm}\t{b}\t{np_}\t{n}\t{par}\t-\t-\t-\t-\t-\tstartet_nicht\n"); out.flush(); continue
            t0 = time.time()
            with cf.ThreadPoolExecutor(par) as ex:
                res = list(ex.map(lambda p: ask(p, samp), PROMPTS if par > 1 else PROMPTS[:3])) if par > 1 else [ask(p, samp) for p in PROMPTS[:3]]
            wall = round(time.time() - t0, 1)
            for i, t in enumerate(res):
                row = [time.strftime("%F"), arm, b, np_, n, par, i, round(t.get("predicted_per_second", 0), 2),
                       t.get("predicted_n", ""), t.get("draft_n", ""), t.get("draft_n_accepted", ""), wall]
                out.write("\t".join(map(str, row)) + "\n"); out.flush()
                print("  " + "  ".join(map(str, row[1:])), flush=True)
        finally:
            srv.terminate()
            try: srv.wait(30)
            except subprocess.TimeoutExpired: srv.kill()
            time.sleep(3)
    print("FERTIG_MTP2")

if __name__ == "__main__":
    main()

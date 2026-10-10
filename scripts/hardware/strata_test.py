#!/usr/bin/env python3
"""Qwen3.8-Flash-Next on Strata (github.com/Niko1221/Strata), the engine behind the
"94 tokens/s on a 12 GB card" claims -- measured here the same way flashnext_test.py
measured llama.cpp: three prompts, 512 tokens each, greedy, thinking off, a fresh
server per arm, timings in llama.cpp's names from Strata's /v1/status.

Strata's own Q2_0 (GSQ-RCO, its headline size), its own HIP engine built from source
for gfx1100, setup's configuration otherwise unchanged. Three arms, because the
claims do not say which one they are:

  spec-mtp     setup's default: MTP draft layer, verify window 4, plus prompt lookup
  spec-lookup  no MTP layer: drafts from prompt lookup only
  no-spec      no drafting at all: one token per step, the number to set next to
               llama.cpp's

Usage: strata_test.py
"""
import json, os, signal, subprocess, time, urllib.request

S = "/opt/src/strata"
BASE = f"{S}/strata-q2_0.json"
TSV = "/root/eval/strata_test.tsv"
VRAM = "/sys/class/drm/card1/device/mem_info_vram_used"
PORT = 18190
PROMPTS = [  # the same three as flashnext_test.py
    "Write a Python function that parses an ISO 8601 duration string like 'P3DT4H5M' into seconds, with type hints and a ValueError on invalid input.",
    "Explain in German, in about 300 words, how a hash map handles collisions, with one short code example.",
    "Implement binary search over a sorted slice in Go and write three table-driven tests for it.",
]

def ohne(args, flag, n_values=1):
    a = list(args)
    if flag in a:
        i = a.index(flag); del a[i:i + 1 + n_values]
    return a

def arms(base):
    a = base["args"]
    no_mtp = ohne(a, "--mtp")
    return [("spec-mtp", a),
            ("spec-lookup", no_mtp),
            ("no-spec", ohne(no_mtp, "--suffix-draft") + ["--suffix-draft", "0"])]

def get(path):
    return json.load(urllib.request.urlopen(f"http://127.0.0.1:{PORT}{path}", timeout=10))

def main():
    base = json.load(open(BASE))
    neu = not os.path.exists(TSV)
    out = open(TSV, "a")
    if neu:
        out.write("date\tarm\tload_s\tvram_mib\tprompt\tprompt_n\tpp_tps\tpredicted_n\ttg_tps\tdraft_n\tdraft_accepted\n")
    for arm, args in arms(base):
        cfg = dict(base, args=args, log=f"/root/eval/strata_{arm}.log")
        p = f"/root/eval/strata_cfg_{arm}.json"; json.dump(cfg, open(p, "w"), indent=1)
        t0 = time.time()
        # own process group: the server starts the engine as a child, and both must go at the end
        srv = subprocess.Popen([f"{S}/.venv/bin/python", f"{S}/serve/server.py", "--engine", "strata",
                                "--config", p, "--port", str(PORT)], cwd=S, start_new_session=True,
                               stdout=open(f"/root/eval/strata_server_{arm}.out", "w"), stderr=subprocess.STDOUT)
        try:
            ok = False
            for _ in range(600):
                try:
                    h = get("/health")
                    if h.get("loaded") is True: ok = True; break   # "status" says ok while the model still loads
                except Exception:
                    pass
                if srv.poll() is not None: break
                time.sleep(2)
            if not ok:
                print(f"  {arm}: Server nicht bereit, siehe /root/eval/strata_server_{arm}.out", flush=True)
                out.write(f"{time.strftime('%F')}\t{arm}\t-\t-\t-\t-\t-\t-\tfehler\t-\t-\n"); out.flush(); continue
            load = round(time.time() - t0, 1)
            for i, q in enumerate(PROMPTS):
                body = {"messages": [{"role": "user", "content": q}], "max_tokens": 512, "temperature": 0, "seed": 1,
                        "chat_template_kwargs": {"enable_thinking": False}}
                req = urllib.request.Request(f"http://127.0.0.1:{PORT}/v1/chat/completions", json.dumps(body).encode(),
                                             {"Content-Type": "application/json"})
                urllib.request.urlopen(req, timeout=1800).read()
                t = get("/v1/status").get("last_timings") or {}
                row = [time.strftime("%F"), arm, load, int(open(VRAM).read()) // 1048576, i, t.get("prompt_n", ""),
                       t.get("prompt_per_second", ""), t.get("predicted_n", ""), t.get("predicted_per_second", ""),
                       t.get("draft_n", ""), t.get("draft_n_accepted", "")]
                out.write("\t".join(map(str, row)) + "\n"); out.flush()
                print("  " + "  ".join(map(str, row[1:])), flush=True)
        finally:
            try: os.killpg(srv.pid, signal.SIGTERM)
            except ProcessLookupError: pass
            try: srv.wait(180)                  # the engine releases tens of GB of page-locked RAM on SIGTERM
            except subprocess.TimeoutExpired:
                os.killpg(srv.pid, signal.SIGKILL); srv.wait(30)
            time.sleep(10)
    print("FERTIG_STRATA")

if __name__ == "__main__":
    main()

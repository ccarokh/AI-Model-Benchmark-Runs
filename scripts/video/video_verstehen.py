#!/usr/bin/env python3
"""Video understanding on llama.cpp: does a vision model describe what happens
in a 30-second clip? Two ways of handing it the video, same prompt, same model:

  video   -- the clip itself as an OpenAI `video_url` content part (llama.cpp
             master since 2026-09; mtmd samples the frames with ffmpeg)
  frames  -- eight frames we sample evenly ourselves, as eight images

The clips are the freely licensed Wikimedia Commons videos listed in
data/video/clips.tsv (fetched and converted by clips_holen.py), so answers,
timings and the clips themselves can all be published. Whether a description
is right is judged afterwards against the key facts in that TSV.

A clip handed over as video costs tokens in proportion to its length (about 1.9k
per second here), so long clips need a larger context: VV_CTX. VV_NUR (clip ids,
comma-separated) and VV_MODI (video,frames) restrict a run to a subset.

Usage: video_verstehen.py <model-dir-name> [port]
"""
import base64, csv, glob, json, os, subprocess, sys, threading, time, urllib.request

MODELS = "/opt/llm-infra/models"
LISTE = "/opt/video-eval/clips.tsv"
CLIPS = [f"/opt/video-eval/commons/{r['id']}.mp4" for r in csv.DictReader(open(LISTE), delimiter="\t")]
B = "/opt/llama-cpp-master"
ANTWORTEN = "/root/eval/video_verstehen_commons_antworten.jsonl"
TSV = "/root/eval/video_verstehen_commons.tsv"
VRAM = "/sys/class/drm/card1/device/mem_info_vram_used"
PROMPT = ("Beschreibe genau, was in diesem Video passiert. Was tut der Hund, Schritt für Schritt? "
          "Was tut der Mensch? Welche Übung oder welches Verhalten ist zu sehen? "
          "Wenn Text oder Folien zu sehen sind, gib ihren Inhalt wieder. Antworte auf Deutsch.")

def b64(path, mime):
    return f"data:{mime};base64," + base64.b64encode(open(path, "rb").read()).decode()

def frames(clip, n=8):
    out = []
    dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                         "-of", "csv=p=0", clip]).decode().strip())
    for k in range(n):
        t = dur * (k + 0.5) / n
        f = f"/tmp/vv_{os.getpid()}_{k}.jpg"
        subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.2f}", "-i", clip, "-frames:v", "1",
                        "-vf", "scale='min(1024,iw)':-2", "-y", f], check=True)
        out.append(b64(f, "image/jpeg")); os.remove(f)
    return out

class Spitze:
    def __enter__(self):
        self.max, self._s = 0, False
        def lauf():
            while not self._s:
                self.max = max(self.max, int(open(VRAM).read())); time.sleep(0.5)
        self.t = threading.Thread(target=lauf, daemon=True); self.t.start(); return self
    def __exit__(self, *a): self._s = True; self.t.join()

def main():
    name = sys.argv[1]; port = int(sys.argv[2]) if len(sys.argv) > 2 else 18099
    d = os.path.join(MODELS, name)
    g = [f for f in glob.glob(d + "/*.gguf") if "mmproj" not in f][0]
    mm = glob.glob(d + "/mmproj*.gguf")[0]
    env = dict(os.environ, LD_LIBRARY_PATH=B + "/lib")
    srv = subprocess.Popen([B + "/bin/llama-server", "-m", g, "--mmproj", mm, "--host", "127.0.0.1",
                            "--port", str(port), "-c", os.environ.get("VV_CTX", "32768"), "-np", "1", "-ngl", "99", "-sm", "none",
                            "-mg", "0", "--jinja"], env=env, stdout=open("/root/eval/vv_server.log", "w"),
                           stderr=subprocess.STDOUT)
    url = f"http://127.0.0.1:{port}"
    for _ in range(300):
        try:
            if urllib.request.urlopen(url + "/health", timeout=2).status == 200: break
        except Exception: pass
        if srv.poll() is not None: sys.exit("Server beendet -- siehe /root/eval/vv_server.log")
        time.sleep(1)
    neu = not os.path.exists(TSV)
    tsv = open(TSV, "a")
    if neu: tsv.write("date\tmodel\tclip\tmode\tseconds\tprompt_tokens\tcompletion_tokens\tvram_peak_mib\tstatus\n")
    try:
        nur = [c for c in os.environ.get("VV_NUR", "").split(",") if c]
        modi = os.environ.get("VV_MODI", "video,frames").split(",")
        for clip in CLIPS:
            c = os.path.basename(clip)[:-4]
            if nur and os.path.basename(clip)[:-4] not in nur: continue
            for mode in modi:
                if mode == "video":
                    media = [{"type": "video_url", "video_url": {"url": b64(clip, "video/mp4")}}]
                else:
                    media = [{"type": "image_url", "image_url": {"url": u}} for u in frames(clip)]
                body = {"messages": [{"role": "user", "content": media + [{"type": "text", "text": PROMPT}]}],
                        "temperature": 0, "max_tokens": 1024, "seed": 1234,
                        "chat_template_kwargs": {"enable_thinking": False}}
                req = urllib.request.Request(url + "/v1/chat/completions", json.dumps(body).encode(),
                                             {"Content-Type": "application/json"})
                with Spitze() as sp:
                    t = time.time()
                    try:
                        r = json.load(urllib.request.urlopen(req, timeout=1800)); status = "ok"
                    except Exception as e:
                        # the server's reason is in the body of the 400, not in the exception text
                        body = e.read().decode(errors="replace") if hasattr(e, "read") else ""
                        r = {"error": (str(e) + " " + body)[:600]}; status = "fehler"
                    s = time.time() - t
                u = r.get("usage", {})
                txt = (r.get("choices") or [{}])[0].get("message", {}).get("content", r.get("error", ""))
                tsv.write(f"{time.strftime('%F')}\t{name}\t{c}\t{mode}\t{s:.1f}\t{u.get('prompt_tokens','')}\t"
                          f"{u.get('completion_tokens','')}\t{sp.max//1048576}\t{status}\n"); tsv.flush()
                with open(ANTWORTEN, "a") as p:
                    p.write(json.dumps({"date": time.strftime('%F'), "model": name, "clip": c, "mode": mode,
                                        "seconds": round(s, 1), "answer": txt}, ensure_ascii=False) + "\n")
                print(f"  {name:16} {c:24} {mode:6} {s:6.1f} s  in {u.get('prompt_tokens','?'):>6} tok  "
                      f"out {u.get('completion_tokens','?'):>5} tok  VRAM {sp.max//1048576} MiB  {status}"
                      + (f"  {txt[:300]}" if status != "ok" else ""), flush=True)
    finally:
        srv.terminate()
        try: srv.wait(30)
        except subprocess.TimeoutExpired: srv.kill()

if __name__ == "__main__":
    main()

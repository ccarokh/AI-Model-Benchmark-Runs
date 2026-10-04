#!/usr/bin/env python3
"""Fetch the video-understanding clips listed in data/video/clips.tsv from
Wikimedia Commons, check each file against its SHA1, and convert it to a
uniform MP4 (H.264, no audio, at most 1280 px wide) named <id>.mp4.

Every clip is freely licensed (public domain or CC BY / CC BY-SA, author and
licence in the TSV), so the clips, the questions and the models' answers can
all be published. Nothing here comes from private or course material.

Usage: clips_holen.py <clips.tsv> <out-dir> [--von <dir with already downloaded originals>]
"""
import csv, hashlib, os, shutil, subprocess, sys, time, urllib.request

UA = "AI-Model-Benchmark-Runs/1.0 (benchmark clip fetch)"

def sha1(p):
    return hashlib.sha1(open(p, "rb").read()).hexdigest()

def main():
    tsv, out = sys.argv[1], sys.argv[2]
    von = sys.argv[sys.argv.index("--von") + 1] if "--von" in sys.argv else None
    roh = os.path.join(out, "original"); os.makedirs(roh, exist_ok=True)
    for r in csv.DictReader(open(tsv), delimiter="\t"):
        name = r["source_title"].replace(" ", "_"); src = os.path.join(roh, name)
        if von and not os.path.exists(src) and os.path.exists(os.path.join(von, name)):
            shutil.copyfile(os.path.join(von, name), src)
        for versuch in range(4):
            if os.path.exists(src) and sha1(src) == r["sha1"]: break
            try:
                time.sleep(15)   # Commons answers bursts with 429
                data = urllib.request.urlopen(urllib.request.Request(r["file_url"], headers={"User-Agent": UA})).read()
                open(src, "wb").write(data)
            except Exception as e:
                print(f"  {r['id']}: {e} -- neuer Versuch", flush=True); time.sleep(60)
        if not os.path.exists(src) or sha1(src) != r["sha1"]:
            sys.exit(f"{r['id']}: SHA1 stimmt nicht oder Datei fehlt")
        ziel = os.path.join(out, r["id"] + ".mp4")
        if not os.path.exists(ziel):
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-an", "-c:v", "libx264", "-crf", "20",
                            "-pix_fmt", "yuv420p", "-vf", "scale='min(1280,iw)':-2", ziel], check=True)
        print(f"  {r['id']:24} ok  {r['license']}", flush=True)

if __name__ == "__main__":
    main()

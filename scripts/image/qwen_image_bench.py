#!/usr/bin/env python3
"""Qwen-Image-2.1 on the same tasks, seeds and resolution as the five models in
use-cases/image-generation.md -- plus one task none of them could do: a
transparent (RGBA) image. Private track (Qwen Research License: research and
private use; the Home Assistant install is private).

It does not fit the card whole (33 GB bf16: text encoder 17.5, transformer 14.2,
VAE 1.4), so diffusers moves one component at a time onto the card
(enable_model_cpu_offload). That needs the parts in host memory -- possible
only since the host has 64 GB. The time column therefore includes the swaps,
which is what this model costs on this machine.

Usage: qwen_image_bench.py [--smoke]   (--smoke: one image, to test the stack)
"""
import csv, os, sys, threading, time
import torch
from diffusers import QwenImage21Pipeline

MODEL = "/opt/llm-infra/models/qwen-image-2.1"
OUT = "/opt/out/qwen-image-2.1"
TSV = "/root/eval/qwen_image.tsv"
VRAM = "/sys/class/drm/card1/device/mem_info_vram_used"

P = {
 "01_arbeitsszene": "A worker in full protective equipment, helmet and safety harness and respirator, climbing through a manhole into a confined industrial tank, documentary photograph, natural light",
 "02_deutscher_text": "A yellow industrial warning sign mounted on a concrete wall, large bold black text reading ACHTUNG BEHAELTER, photorealistic, sharp",
 "03_piktogramm": "A flat minimalist vector icon of a lightbulb, single solid color, centered on plain white background, no shading, no gradient",
 "04_haende": "Close-up of a technician hands holding a torque wrench, tightening a bolt on a steel flange, sharp focus on the hands, workshop",
 "05_schema": "A clean technical schematic diagram of a two stage water filtration system, labeled boxes connected by arrows, line art on white background",
 "06_hund": "A German Shepherd dog running across a green meadow towards the camera, full body, all four legs visible, fur detail, natural daylight, photograph",
 "07_katze": "A tabby cat sitting on a wooden windowsill looking outside, soft afternoon light, sharp fur detail, photograph",
 "08_pferd": "A brown horse trotting in a sandy paddock, full body side view, all four legs visible, dust in the air, photograph",
}
# New: the one thing the other five cannot do at all.
P_RGBA = ("09_transparent", "A flat icon of a washing machine for a smart home dashboard, "
          "simple shapes, two colors, on a transparent background, RGBA with alpha channel")
SEEDS_TEXT = [7, 13, 42, 55, 99, 101, 314, 512, 777, 1001, 1234, 1618, 2026, 3141, 8888]


class Spitze:
    """Sample the card's VRAM once a second, keep the peak."""
    def __init__(self): self.max = 0; self._stop = False
    def __enter__(self):
        def lauf():
            while not self._stop:
                try: self.max = max(self.max, int(open(VRAM).read()))
                except OSError: pass
                time.sleep(1)
        self.t = threading.Thread(target=lauf, daemon=True); self.t.start(); return self
    def __exit__(self, *a): self._stop = True; self.t.join()


def main():
    smoke = "--smoke" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    neu = not os.path.exists(TSV)
    f = open(TSV, "a", newline=""); w = csv.writer(f, delimiter="\t")
    if neu: w.writerow(["date", "model", "task", "seed", "seconds", "vram_peak_mib", "mode", "file"])

    t0 = time.time()
    pipe = QwenImage21Pipeline.from_pretrained(MODEL, torch_dtype=torch.bfloat16)
    pipe.enable_model_cpu_offload()
    print(f"geladen in {time.time()-t0:.1f} s  (torch {torch.__version__}, hip {torch.version.hip})", flush=True)

    jobs = [(t, 42, p) for t, p in P.items()]
    jobs += [("02_deutscher_text", s, P["02_deutscher_text"]) for s in SEEDS_TEXT if s != 42]
    jobs.append((P_RGBA[0], 42, P_RGBA[1]))
    if smoke: jobs = jobs[:1]

    for task, seed, prompt in jobs:
        g = torch.Generator("cpu").manual_seed(seed)
        with Spitze() as sp:
            t = time.time()
            img = pipe(prompt=prompt, width=1024, height=1024, generator=g).images[0]
            s = time.time() - t
        name = f"{task}_s{seed}.png"
        img.save(os.path.join(OUT, name))
        w.writerow([time.strftime("%F"), "qwen-image-2.1", task, seed, f"{s:.1f}", sp.max // 1048576, img.mode, name]); f.flush()
        print(f"  {task:18} seed {seed:5}  {s:6.1f} s  VRAM {sp.max//1048576:6} MiB  mode {img.mode}", flush=True)
    print("FERTIG_QWEN_IMAGE")


if __name__ == "__main__":
    main()

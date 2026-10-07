#!/usr/bin/env python3
"""Video generation: Wan2.2-TI2V-5B (Apache-2.0, commercial use allowed) with
diffusers on PyTorch/ROCm. Text to video and image to video, five seconds each.

Model: 5B transformer in bf16 plus the umt5-xxl text encoder -- does not fit the
card together; components move from host memory one at a time (64 GB host).
Time per clip, VRAM peak and the clip itself; whether it is any good is judged
by looking.

On ROCm, run with TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1: without flash attention the
attention of one step wants 66.5 GiB in one piece.

Usage: video_erzeugen.py [--smoke]
"""
import csv, os, sys, threading, time
import torch
from diffusers import WanPipeline, WanImageToVideoPipeline, AutoencoderKLWan
from diffusers.utils import export_to_video, load_image

MODEL = "/opt/llm-infra/models/wan2.2-ti2v-5b"
OUT = "/opt/out/wan2.2-ti2v-5b"
TSV = "/root/eval/video_erzeugen.tsv"
VRAM = "/sys/class/drm/card1/device/mem_info_vram_used"
NEG = "blurry, low quality, distorted, extra legs, deformed, watermark, text"
T2V = {
    "01_hund_sitz": "A medium-sized black mixed-breed dog sits down on command next to its owner on a park path, the owner gives a treat, natural daylight, handheld documentary video",
    "02_treibball": "A border collie pushes a large orange exercise ball across a green meadow towards its owner, dog sports training, wide shot, overcast daylight",
    "03_folie": "A presentation slide with the German title 'Rueckwaertsgehen' and three bullet points appears, then a small dog walks backwards on a yoga mat, clean flat design",
}
I2V_BILD = "/opt/out/qwen-image-2.1/06_hund_s42.png"   # the German shepherd from the image benchmark
I2V_PROMPT = "The German Shepherd keeps running across the meadow towards the camera, fur moving, natural motion"

class Spitze:
    def __enter__(self):
        self.max, self._s = 0, False
        def lauf():
            while not self._s:
                self.max = max(self.max, int(open(VRAM).read())); time.sleep(1)
        self.t = threading.Thread(target=lauf, daemon=True); self.t.start(); return self
    def __exit__(self, *a): self._s = True; self.t.join()

def main():
    smoke = "--smoke" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    neu = not os.path.exists(TSV); f = open(TSV, "a", newline=""); w = csv.writer(f, delimiter="\t")
    if neu: w.writerow(["date", "model", "task", "mode", "seconds", "vram_peak_mib", "frames", "file"])
    vae = AutoencoderKLWan.from_pretrained(MODEL, subfolder="vae", torch_dtype=torch.float32)
    # Decoding 121 frames at 1280x704 in one piece wants 11.6 GiB on top of the model (05./06.10.: OOM after
    # 21 min of diffusion). Tiled decoding works through the frame in pieces.
    vae.enable_tiling()
    jobs = [("t2v", k, p) for k, p in T2V.items()] + [("i2v", "04_schaeferhund_i2v", I2V_PROMPT)]
    if smoke: jobs = jobs[:1]
    pipe = None
    for mode, task, prompt in jobs:
        if pipe is None or pipe._mode != mode:
            del pipe; torch.cuda.empty_cache()
            cls = WanPipeline if mode == "t2v" else WanImageToVideoPipeline
            pipe = cls.from_pretrained(MODEL, vae=vae, torch_dtype=torch.bfloat16)
            pipe.enable_model_cpu_offload(); pipe._mode = mode
        g = torch.Generator("cpu").manual_seed(42)
        kw = dict(prompt=prompt, negative_prompt=NEG, height=704, width=1280, num_frames=121,
                  guidance_scale=5.0, num_inference_steps=50, generator=g)
        if mode == "i2v": kw["image"] = load_image(I2V_BILD).convert("RGB").resize((1280, 704))
        with Spitze() as sp:
            t = time.time(); frames = pipe(**kw).frames[0]; s = time.time() - t
        name = f"{task}.mp4"; export_to_video(frames, os.path.join(OUT, name), fps=24)
        w.writerow([time.strftime("%F"), "wan2.2-ti2v-5b", task, mode, f"{s:.1f}", sp.max // 1048576, len(frames), name]); f.flush()
        print(f"  {task:22} {mode}  {s:7.1f} s  VRAM {sp.max//1048576} MiB  {len(frames)} Bilder", flush=True)
    print("FERTIG_VIDEO_ERZEUGEN")

if __name__ == "__main__":
    main()

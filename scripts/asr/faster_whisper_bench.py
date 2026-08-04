#!/usr/bin/env python3
"""Time faster-whisper on one audio file, once, for a given device and precision.

One fresh process per measurement, on purpose — see METHODOLOGY.md. Prints a single
JSON line so a shell loop can collect runs without parsing prose.

    python faster_whisper_bench.py cuda float16 large-v3
    python faster_whisper_bench.py cpu  int8     large-v3

Two environment variables decide whether this works at all:

    HF_HUB_OFFLINE=1
        Required once the model is cached. Without it the hub is contacted for a
        revision check that can block indefinitely on a host with broken IPv6 —
        the process sits in SYN-SENT and never times out. It looks exactly like a
        CUDA hang and is not one.

    LD_LIBRARY_PATH=<venv>/nvidia/cublas/lib:<venv>/nvidia/cudnn/lib
        Required for device=cuda. CTranslate2 links against the driver but ships
        neither cuBLAS nor cuDNN; install `nvidia-cublas-cu12` and
        `nvidia-cudnn-cu12` into the venv. No CUDA toolkit is needed.
"""

import json
import sys
import time

from faster_whisper import WhisperModel

# --- configuration ----------------------------------------------------------
AUDIO = "/tmp/clip_1.wav"  # 63.72 s, 16 kHz mono, German domain speech
LANGUAGE = "de"
BEAM_SIZE = 5  # the single largest quality lever measured — see transcription.md
VAD_FILTER = False  # VAD was measured to drop whole sentences
INITIAL_PROMPT = "Domain terms and proper names, comma separated."
# ----------------------------------------------------------------------------

device, compute_type, model_size = sys.argv[1], sys.argv[2], sys.argv[3]

t0 = time.time()
model = WhisperModel(model_size, device=device, compute_type=compute_type)
load_s = time.time() - t0

t1 = time.time()
segments, info = model.transcribe(
    AUDIO,
    language=LANGUAGE,
    beam_size=BEAM_SIZE,
    vad_filter=VAD_FILTER,
    initial_prompt=INITIAL_PROMPT,
)
segments = list(segments)  # the generator is lazy; decoding happens here
transcribe_s = time.time() - t1

text = " ".join(s.text.strip() for s in segments)
print(json.dumps({
    "device": device,
    "compute": compute_type,
    "model": model_size,
    "load_s": round(load_s, 2),
    "transcribe_s": round(transcribe_s, 2),
    "audio_s": round(info.duration, 2),
    "realtime_factor": round(info.duration / transcribe_s, 2),
    "segments": len(segments),
    "chars": len(text),
}, ensure_ascii=False))

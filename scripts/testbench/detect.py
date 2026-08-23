"""Discovery: what is on this machine, and what can therefore be measured.

The configuration may name everything explicitly. Whatever it does not name is
looked for here -- and what is not found becomes a reason in a result row, not a
blank. A test that never ran because no build was found has to say so.
"""
from __future__ import annotations

import re
from pathlib import Path

from harness import AmdPower, Build, Card, NvidiaPower, PowerSource, run

BACKEND_LIBS = ("vulkan", "cuda", "hip", "rocm", "sycl", "metal")


def backend_of(prefix: Path) -> str:
    """Identify a build by the backend libraries in it, never by its name.

    A prefix called `-rocm` holding only Vulkan libraries has happened here, and
    its numbers were filed under the wrong backend until an unrelated
    architecture error gave it away. ggml loads its backends at runtime, so
    `ldd` on the binary shows nothing -- the files themselves are the evidence.
    """
    found = []
    for key in BACKEND_LIBS:
        for sub in ("lib", "bin"):
            if any((prefix / sub).glob(f"libggml-{key}.so*")):
                if key not in found:
                    found.append(key)
                break
    return "+".join("rocm" if f == "hip" else f for f in found) or "unknown"


def find_builds(search_paths: list[str]) -> list[Build]:
    builds = []
    for raw in search_paths:
        p = Path(raw)
        if not (p / "bin" / "llama-bench").exists():
            continue
        version = "unknown"
        stamp = p / ".built-version"
        if stamp.exists():
            version = stamp.read_text().strip()
        builds.append(Build(path=p, backend=backend_of(p), version=version))
    return builds


def find_cards(build: Build) -> list[Card]:
    """Ask llama-bench, not the vendor tool.

    The device id the benchmark uses is the only one that can be passed back to
    it. A card that nvidia-smi lists and the backend does not is not measurable,
    and a device list that does not match the benchmark's own is how a
    measurement ends up pinned to the wrong card.
    """
    rc, out, err = run([str(build.bin / "llama-bench"), "--list-devices"],
                       timeout=120, env={"LD_LIBRARY_PATH": str(build.bin)})
    # Only the block under "Available devices:", and only identifiers that look
    # like a backend device id. The backends log to stderr while they
    # initialise, and one of those lines ("ggml_cuda_init: found 1 CUDA
    # devices") parses as a device called ggml_cuda_init with 11899 MiB.
    cards = []
    in_block = False
    for line in (out + err).splitlines():
        if line.strip().lower().startswith("available devices"):
            in_block = True
            continue
        if not in_block:
            continue
        line = line.strip()
        if ":" not in line or "MiB" not in line:
            continue
        ident, rest = line.split(":", 1)
        ident = ident.strip()
        if not re.fullmatch(r"[A-Za-z]+\d+", ident):
            continue
        name = rest.split("(")[0].strip()
        vram = 0
        for token in rest.split("("):
            if "MiB" in token:
                digits = "".join(c for c in token.split("MiB")[0] if c.isdigit())
                if digits:
                    vram = int(digits)
                    break
        cards.append(Card(index=ident, name=name, vram_mib=vram))
    return cards


def find_models(search_paths: list[str], limit: int = 40) -> list[Path]:
    """Guessing WHICH models to measure is not this suite's job.

    Naming them in the configuration is the honest way. But running with none at
    all is worse than running with what is lying there, so the search paths are
    the fallback -- and the projector files are excluded, because a mmproj is
    not a model and llama-bench will not load it.
    """
    found: list[Path] = []
    for raw in search_paths:
        base = Path(raw)
        if not base.is_dir():
            continue
        for p in sorted(base.glob("*/*.gguf")) + sorted(base.glob("*.gguf")):
            if "mmproj" in p.name.lower():
                continue
            if p not in found:
                found.append(p)
    return found[:limit]


def detect_power(config: dict) -> PowerSource:
    rc, out, _ = run(["nvidia-smi", "-L"], timeout=20)
    if rc == 0 and "GPU" in out:
        return NvidiaPower(index=int(config.get("card_index", 0)))
    drm = Path(config.get("amd_drm", "/sys/class/drm/card1/device"))
    if (drm / "mem_info_vram_used").exists():
        return AmdPower(drm)
    return PowerSource()

"""What it costs to come back after somebody else used your slot."""
NAME = "slot_restore"
DESCRIPTION = "The price of a slot eviction: cache hit, restore from RAM, or full re-prefill"

import json
import time
import urllib.request

from harness import _limited, card_is_idle, free_port  # noqa: F401
from harness import Build  # noqa: F401
import os
import subprocess
from pathlib import Path

# Sizing a service on slots only works if leaving a slot is cheap. llama.cpp
# parks an idle slot in a host-RAM prompt cache (`--cache-ram`, 8 GiB by
# default) and fetches it back when that conversation returns -- which is what
# makes "more users than slots" a real arrangement rather than a way to hide a
# queue.
#
# The claim is worth exactly what the return trip costs, and there are three
# possible prices:
#
#   hit      the slot was never taken away    -- measured here at 0.06 s
#   restore  it came back from host RAM       -- unknown, and the point of this
#   prefill  it was thrown away and recomputed
#
# The control is `--cache-ram 0`, which disables the RAM cache. Same sequence,
# same prompts, cache off: whatever the difference is, that is what the cache is
# worth.
SLOTS = 2
USERS = 3          # one more than there are slots, so somebody is evicted
PROMPT_REPEATS = 400   # about 6 800 tokens of prompt per user
CTX_PER_SLOT = 8192
SATZ = "Die Wartung der Anlage erfolgt jaehrlich im Maerz. "


def _prompts():
    """One long prompt per user, each a different sequence from the first token."""
    return [f"Notiz {i}. " + SATZ * PROMPT_REPEATS + f"\nFrage {i}: Wann wird gewartet?"
            for i in range(USERS)]


def _ask(port, prompt):
    body = json.dumps({"prompt": prompt, "n_predict": 8, "temperature": 0,
                       "cache_prompt": True}).encode()
    req = urllib.request.Request(f"http://127.0.0.1:{port}/completion", data=body,
                                 headers={"Content-Type": "application/json"})
    start = time.time()
    with urllib.request.urlopen(req, timeout=900) as r:
        data = json.loads(r.read())
    return {"wall": time.time() - start,
            "prompt_ms": data.get("timings", {}).get("prompt_ms", 0),
            "evaluated": data.get("tokens_evaluated"),
            "cached": data.get("tokens_cached")}


def _serve(build, model, cache_ram):
    port = free_port()
    log = Path(os.environ.get("TMPDIR", "/tmp")) / f"slot_restore.{port}.log"
    cmd = [str(build.bin / "llama-server"), "-m", str(model), "-ngl", "99",
           "-c", str(SLOTS * CTX_PER_SLOT), "-np", str(SLOTS),
           "--cache-ram", str(cache_ram),
           "--host", "127.0.0.1", "--port", str(port), "--no-warmup"]
    with log.open("w") as handle:
        proc = subprocess.Popen(_limited(cmd), stdout=handle, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL,
                                env=dict(os.environ, LD_LIBRARY_PATH=str(build.bin)))
    deadline = time.time() + 240
    while time.time() < deadline:
        if proc.poll() is not None:
            return None, port, "server exited during startup"
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2) as r:
                if b'"ok"' in r.read():
                    return proc, port, ""
        except Exception:
            time.sleep(1)
    proc.terminate()
    return None, port, "no health after 240s"


def run(ctx):
    done = total = 0
    for build in ctx.builds:
        if not (build.bin / "llama-server").exists():
            ctx.skip_permanently(NAME, f"{build.backend} build has no llama-server",
                                 backend=build.backend, build=build.version)
            continue
        for model in ctx.models:
            for cache_ram, name in ((8192, "cache-ram 8192"), (0, "cache-ram off")):
                total += 1
                key = f"{model.stem}:{name.replace(' ', '-')}"
                if ctx.results.has_prefix(NAME, "", build.backend, build.version, key):
                    done += 1
                    continue
                if ctx.out_of_budget():
                    return
                if not card_is_idle(ctx):
                    ctx.defer(NAME, f"card busy before {key}")
                    break
                proc, port, fehler = _serve(build, model, cache_ram)
                if not proc:
                    ctx.results.add(NAME, "", build.backend, build.version, key,
                                    "failed", "", fehler)
                    ctx.say(f"  {build.backend} {model.stem} {name}: {fehler}")
                    done += 1
                    continue
                try:
                    prompts = _prompts()
                    # Round one: everybody arrives. With one more user than
                    # slots, the first of them is pushed out.
                    erst = [_ask(port, p) for p in prompts]
                    # The first user comes back. Their slot is gone -- what does
                    # it cost them?
                    wieder = _ask(port, prompts[0])
                    # And immediately again, which cannot have been evicted:
                    # the yardstick for "free".
                    sofort = _ask(port, prompts[0])
                finally:
                    proc.terminate()
                    try:
                        proc.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                done += 1
                kalt = erst[0]
                ctx.results.add(NAME, "", build.backend, build.version, f"{key}:cold",
                                f"{kalt['prompt_ms']:.0f}", "ms prefill",
                                f"{kalt['evaluated']} tokens evaluated, "
                                f"{kalt['cached']} cached")
                ctx.results.add(NAME, "", build.backend, build.version, f"{key}:returning",
                                f"{wieder['prompt_ms']:.0f}", "ms prefill",
                                f"{wieder['evaluated']} tokens evaluated, "
                                f"{wieder['cached']} cached, after {USERS - 1} others "
                                f"used {SLOTS} slots")
                ctx.results.add(NAME, "", build.backend, build.version, f"{key}:still_warm",
                                f"{sofort['prompt_ms']:.0f}", "ms prefill",
                                f"{sofort['evaluated']} tokens evaluated, "
                                f"{sofort['cached']} cached")
                anteil = (wieder["prompt_ms"] / kalt["prompt_ms"]) if kalt["prompt_ms"] else 0
                ctx.say(f"  {build.backend} {model.stem} {name}: cold "
                        f"{kalt['prompt_ms']:.0f} ms, returning {wieder['prompt_ms']:.0f} ms "
                        f"({anteil:.0%} of cold), still warm {sofort['prompt_ms']:.0f} ms")
    ctx.coverage(NAME, done, total,
                 f"{len(ctx.builds)} builds x {len(ctx.models)} models x 2 cache settings")

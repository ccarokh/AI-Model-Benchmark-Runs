#!/usr/bin/env python3
"""One command, every measurement this repository knows how to make, on whatever
machine it is started on.

    run_all.py                     everything that applies here
    run_all.py --list              what exists, and what it does
    run_all.py matrix_path         only tests whose name contains this
    run_all.py --budget 4          stop STARTING tests after four hours
    run_all.py --lease             hold the GPU lease for the whole run
    run_all.py --window 23-11      only work inside that hour window

WHAT IT NEEDS: a configured llama.cpp -- at least one prefix or build directory
containing llama-bench -- and at least one model. Cards and backends are
discovered from the build itself. Everything else is optional, and its absence
becomes a documented skip rather than a crash.

RESUMABLE BY CONSTRUCTION. Every measurement carries a key, and a key already in
the results file is not measured again. Interrupt it, restart it, it continues.
Delete a row to repeat that measurement; delete the file to repeat everything.
The results ARE the state -- there is no second place to fall out of sync.

THE TESTS ARE NOT LISTED HERE. Whatever lies in tests/ is what runs, in filename
order. Adding a measurement means adding a file, not editing this one. A test is
a Python module with NAME, DESCRIPTION and run(ctx) -- or any executable file,
which gets the context as JSON on stdin and writes result rows to stdout.
"""
from __future__ import annotations

import argparse
import configparser
import importlib.util
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import detect                                    # noqa: E402
from harness import Context, Results, kernel_events, run  # noqa: E402

DEFAULTS = {
    "build_search_paths": "/opt/llama-cpp /opt/llama-cpp-nb /opt/llama-cpp-rocm "
                          "/opt/mess/llama.cpp/build /opt/mess/llama.cpp/build-cuda "
                          "/opt/src/llama.cpp/build /usr/local",
    "model_search_paths": "/opt/llm-infra/models /opt/mess/models /opt/models",
    "models": "",
    "card_index": "0",
    "amd_drm": "/sys/class/drm/card1/device",
    # auto | nvidia | amd | none -- see detect_power. Must be set on a host that
    # has cards from both vendors.
    "power_source": "auto",
    "out_dir": "",
    # Where the measuring happens. Empty means here. Anything else is an ssh
    # destination, and then only the measurement and its sampler run on that
    # machine -- the orchestration stays on the controller, which is the point.
    # Only these device ids. Empty means every card the build reports.
    "cards": "",
    "target": "",
    "target_path": "/root/scripts",
    "lease_url": "http://127.0.0.1:8080",
    "lease_token_file": "/etc/bench/lease.token",
}


def load_config(path: Path) -> dict:
    cfg = dict(DEFAULTS)
    if path.exists():
        parser = configparser.ConfigParser()
        parser.read(path)
        for section in parser.sections():
            for key, value in parser[section].items():
                cfg[key] = value
    for key in list(cfg):
        env = os.environ.get("TESTBENCH_" + key.upper())
        if env:
            cfg[key] = env
    return cfg


class Lease:
    """The GPU lease, if this machine shares its card with a service.

    Optional on purpose: a borrowed box with nothing else running needs none.
    Where a supervisor does share the card, measuring without the lease is how
    a night once produced two builds at 3.3 tokens/s instead of 103 -- both
    equally wrong, and the comparison between them looked perfectly consistent.
    """

    def __init__(self, url: str, token_file: str, holder: str = "testbench"):
        self.url, self.holder = url.rstrip("/"), holder
        self.token = Path(token_file).read_text().strip() if Path(token_file).exists() else None
        self.id = None
        self.reason = ""      # what the supervisor last said about refusing
        self._stop = False

    def hold(self, window: str = "") -> bool:
        """Keep it, do not merely take it once.

        A restart of the supervisor drops the lease -- it lives in memory. The
        night runner used to treat that as the end of the night and lost four of
        seven steps to a restart that had happened ninety minutes earlier.
        Returns False only when there is no point trying any more: the window
        closed.
        """
        import time as _t
        tries = 0
        while True:
            tries += 1
            if self.acquire():
                return True
            if window and not in_window(window):
                return False
            if tries == 1 or tries % 5 == 0:
                # THE SERVER'S OWN REASON, not "not granted". On 31.08. a run
                # waited sixteen minutes in this loop while the supervisor sat
                # in a grant that never completed -- and every line it printed
                # said only that it was retrying. The reason was one field away:
                # "a GPU lease is currently being granted", which names the
                # stuck party immediately.
                print(f"[lease] attempt {tries}: {self.reason or 'no answer from the supervisor'}"
                      f" -- retrying at {self.url}", flush=True)
            if not window and tries > 60:
                return False
            _t.sleep(60)

    def valid(self) -> bool:
        if not (self.id and self.token):
            return False
        rc, out, _ = run(["curl", "-s", "-m", "10", f"{self.url}/_manager/status",
                          "-H", f"x-lease-token: {self.token}"], timeout=20)
        return self.id in out

    def acquire(self) -> bool:
        if not self.token:
            return False
        rc, out, _ = run(["curl", "-s", "-m", "10", "-X", "POST", f"{self.url}/_manager/lease",
                          "-H", f"x-lease-token: {self.token}",
                          "-H", "Content-Type: application/json",
                          "-d", json.dumps({"holder": self.holder})], timeout=20)
        try:
            antwort = json.loads(out)
            self.reason = antwort.get("reason") or antwort.get("code") or ""
            self.id = antwort["lease_id"]
        except Exception:
            return False
        import threading
        def beat():
            while not self._stop:
                time.sleep(120)
                run(["curl", "-s", "-m", "10", "-o", "/dev/null", "-X", "POST",
                     f"{self.url}/_manager/lease/{self.id}/heartbeat",
                     "-H", f"x-lease-token: {self.token}"], timeout=20)
        threading.Thread(target=beat, daemon=True).start()
        return True

    def release(self):
        self._stop = True
        if self.id:
            run(["curl", "-s", "-m", "10", "-o", "/dev/null", "-X", "DELETE",
                 f"{self.url}/_manager/lease/{self.id}",
                 "-H", f"x-lease-token: {self.token}"], timeout=20)
            self.id = None


def discover_tests(only: list[str]) -> list[tuple[str, Path, str]]:
    """Whatever is in tests/, in filename order -- nothing is enumerated here."""
    found = []
    for path in sorted((HERE / "tests").glob("*")):
        if path.name.startswith("_") or path.is_dir():
            continue
        if path.suffix == ".py":
            description = ""
            for line in path.read_text().splitlines()[:20]:
                if line.startswith("DESCRIPTION"):
                    description = line.split("=", 1)[1].strip().strip('"\'')
                    break
            found.append((path.stem, path, description))
        elif os.access(path, os.X_OK):
            found.append((path.stem, path, "external test (JSON on stdin, rows on stdout)"))
    if only:
        found = [t for t in found if any(o in t[0] for o in only)]
    return found


def auf_karten(karten: list, cfg: dict) -> list:
    """The cards asked for, or all of them.

    Named by the device id the backend itself uses -- Vulkan0, CUDA0 -- because
    that is the only id that can be handed back to llama-bench. A name that
    matches nothing is refused rather than silently measuring every card: asking
    for one card and getting four is not a smaller answer, it is a different one.
    """
    gewuenscht = cfg.get("cards", "").split()
    if not gewuenscht:
        return karten
    gewaehlt = [k for k in karten if k.index in gewuenscht]
    if not gewaehlt and karten:
        sys.exit(f"cards: none of {gewuenscht} is present -- this build reports "
                 + ", ".join(k.index for k in karten))
    return gewaehlt


def in_window(window: str) -> bool:
    """A window is for machines somebody else needs during the day."""
    if not window:
        return True
    start, end = (int(x) for x in window.split("-"))
    hour = time.localtime().tm_hour
    return (hour >= start or hour < end) if start > end else (start <= hour < end)


def window_closes_at(window: str) -> float | None:
    """When the window shuts, as a timestamp.

    A WINDOW CHECKED ONLY BETWEEN TESTS IS NOT A WINDOW. On the night of 26.08.
    the check sat between steps, one step -- throughput over context depth
    across every model -- ran 550 minutes, and the run held the GPU lease of the
    machine that serves until 11:22, three and a half hours past the window it
    was started in. The service refused every request for that whole time.
    Turning the window into a deadline puts it where the budget already is:
    inside the tests, checked before every single measurement.
    """
    if not window:
        return None
    start, end = (int(x) for x in window.split("-"))
    jetzt = time.localtime()
    sekunden_heute = jetzt.tm_hour * 3600 + jetzt.tm_min * 60 + jetzt.tm_sec
    bis_ende = end * 3600 - sekunden_heute
    if bis_ende <= 0:                 # the closing hour is tomorrow
        bis_ende += 24 * 3600
    return time.time() + bis_ende


def main() -> int:
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("tests", nargs="*", help="run only tests whose name contains these")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--budget", type=float, default=0, help="hours; stop starting tests after")
    ap.add_argument("--window", default="", help="e.g. 23-11")
    ap.add_argument("--lease", action="store_true")
    ap.add_argument("--conf", default=str(HERE / "testbench.conf"))
    ap.add_argument("-h", "--help", action="store_true")
    args = ap.parse_args()
    if args.help:
        print(__doc__)
        return 0

    cfg = load_config(Path(args.conf))
    host = Path("/etc/hostname").read_text().strip() if Path("/etc/hostname").exists() else socket.gethostname()
    out_dir = Path(cfg["out_dir"]) if cfg["out_dir"] else HERE / "results" / host
    out_dir.mkdir(parents=True, exist_ok=True)

    tests = discover_tests(args.tests)
    if args.list:
        for name, path, description in tests:
            print(f"  {name:<24} {description}")
        return 0
    if not tests:
        print("no tests found in tests/", file=sys.stderr)
        return 2

    builds = detect.find_builds(cfg["build_search_paths"].split())
    if not builds:
        print(f"no llama.cpp found. Searched: {cfg['build_search_paths']}\n"
              f"Set build_search_paths in {args.conf}", file=sys.stderr)
        return 2
    models = ([Path(m) for m in cfg["models"].split()] if cfg["models"]
              else detect.find_models(cfg["model_search_paths"].split()))
    if not models:
        print(f"no models found. Searched: {cfg['model_search_paths']}", file=sys.stderr)
        return 2

    # Whichever comes first: the time budget, or the closing of the window.
    grenzen = [g for g in (time.time() + args.budget * 3600 if args.budget else None,
                           window_closes_at(args.window)) if g]
    frist = min(grenzen) if grenzen else None

    ctx = Context(
        host=host, out_dir=out_dir,
        results=Results(out_dir / "results.tsv", host),
        builds=builds,
        cards_by_build={str(b.path): auf_karten(detect.find_cards(b), cfg) for b in builds},
        models=models,
        power=detect.detect_power(cfg),
        log_path=out_dir / "run.log",
        deadline=frist,
        config=cfg)

    ctx.say(f"=== {host} ===")
    ctx.say(f"results: {ctx.results.path} ({len(ctx.results.keys)} rows already there)")
    for b in builds:
        ctx.say(f"build:  {b}")
    for b in builds:
        for c in ctx.cards_of(b):
            ctx.say(f"card:   {c.index}  {c.name}  {c.vram_mib} MiB  [{b.backend}]")
    ctx.say(f"models: {len(models)}")
    ctx.say(f"power:  {ctx.power.kind}"
            f"{' (limit settable)' if ctx.power.can_set_limit() else ' (limit not settable)'}")

    lease = None
    if args.lease:
        lease = Lease(cfg["lease_url"], cfg["lease_token_file"])
        if lease.hold(args.window):
            ctx.say(f"lease held: {lease.id}")
        else:
            ctx.say("NO LEASE GRANTED -- refusing to measure against a card somebody else may take")
            return 3

    kernel_before = kernel_events()
    try:
        for name, path, _ in tests:
            if args.window and not in_window(args.window):
                ctx.say(f"outside the window {args.window} -- NOT run: {name}")
                continue
            if ctx.out_of_budget():
                ctx.say(f"budget spent -- NOT run: {name}")
                continue
            # Before every test, not only at the start: the lease can be lost
            # mid-run by a restart of the service that grants it.
            if lease and not lease.valid():
                ctx.say("lease lost -- re-acquiring")
                if not lease.hold(args.window):
                    ctx.say("lease gone and the window is closed -- the rest stays undone")
                    break
                ctx.say(f"lease back: {lease.id}")
            ctx.say(f"--- {name} ---")
            started = time.time()
            try:
                if path.suffix == ".py":
                    spec = importlib.util.spec_from_file_location(f"test_{name}", path)
                    module = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(module)
                    module.run(ctx)
                else:
                    payload = json.dumps({
                        "host": host, "out_dir": str(out_dir),
                        "builds": [{"path": str(b.path), "backend": b.backend, "version": b.version} for b in builds],
                        "cards": {k: [{"index": c.index, "name": c.name, "vram_mib": c.vram_mib} for c in v]
                                  for k, v in ctx.cards_by_build.items()},
                        "models": [str(m) for m in models]})
                    p = subprocess.run([str(path)], input=payload, capture_output=True, text=True)
                    for line in p.stdout.splitlines():
                        if line.strip():
                            with ctx.results.path.open("a") as f:
                                f.write(line.rstrip("\n") + "\n")
            except Exception as e:                       # a broken test is a result too
                ctx.say(f"  TEST FAILED: {type(e).__name__}: {e}")
            ctx.say(f"--- {name}: {int((time.time() - started) / 60)} min ---")
    finally:
        ctx.power.restore()
        if lease:
            lease.release()
            ctx.say("lease returned")

    if kernel_events() != kernel_before:
        ctx.say("WARNING: the kernel logged the card during this run -- check every number")
    ctx.say(f"=== done: {len(ctx.results.keys)} rows in {ctx.results.path} ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())

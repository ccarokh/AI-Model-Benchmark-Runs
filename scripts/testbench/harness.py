"""Shared machinery for the test bench: results, measuring, guards.

Every rule in here is the residue of a measurement this repository had to throw
away. A warm process that measured the previous run. A number taken while
something else held the card. A throughput figure from a card that had already
reset itself. A power average that included model loading, which turned into a
published claim about MoE architectures drawing less power. An empty result that
read like a success.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

EMPTY_HASH = "e3b0c44298fc1c14"  # sha256 of an empty stream: the tell of a run that produced nothing
COLUMNS = ["key", "host", "time", "test", "card", "backend", "build",
           "parameter", "value", "unit", "note"]


def run(cmd, timeout=None, env=None, stdin_null=True, capture_stderr=False):
    """One subprocess call, with the failure mode kept visible.

    Returns (returncode, stdout, stderr). Nothing here raises on a non-zero
    exit: a failed measurement is a result that has to be recorded, not an
    exception that unwinds the run.
    """
    full = dict(os.environ)
    full.update(env or {})
    try:
        p = subprocess.run(
            cmd, timeout=timeout, env=full,
            stdin=subprocess.DEVNULL if stdin_null else None,
            capture_output=True, text=True)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 124, "", f"timeout after {timeout}s"
    except FileNotFoundError as e:
        return 127, "", str(e)


class Results:
    """The results file, and the reason the suite is resumable.

    Every measurement carries a key. Before measuring, the runner asks whether
    that key is already in the file; if it is, it is not measured again.
    Interrupt the run at any point and start it again -- it continues where it
    stopped. To repeat one measurement, delete its row. To repeat everything,
    delete the file. There is no separate state file to fall out of sync,
    because the results ARE the state.
    """

    def __init__(self, path: Path, host: str):
        self.path, self.host = path, host
        self.keys: set[str] = set()
        if path.exists():
            for line in path.read_text().splitlines()[1:]:
                if line.strip():
                    self.keys.add(line.split("\t", 1)[0])
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("\t".join(COLUMNS) + "\n")

    @staticmethod
    def key(test, card="", backend="", build="", parameter="") -> str:
        return "|".join([test, card, backend, build, parameter])

    def has(self, key: str) -> bool:
        return key in self.keys

    def has_prefix(self, test, card="", backend="", build="", parameter="") -> bool:
        """Has this measurement been made -- in any of the rows it produces?

        One measurement usually writes several rows: a prefill and a generation
        figure, a wattage and a tokens-per-watt-hour figure. They share a key
        PREFIX and differ in the last segment. Checking the bare prefix with
        has() therefore always came back false, and every test re-measured
        everything on a restart -- the resume feature was there, wrote its keys,
        and never matched a single one of them.
        """
        prefix = self.key(test, card, backend, build, parameter)
        return any(k == prefix or k.startswith(prefix + ":") for k in self.keys)

    def add(self, test, card="", backend="", build="", parameter="",
            value="", unit="", note=""):
        key = self.key(test, card, backend, build, parameter)
        row = [key, self.host, time.strftime("%Y-%m-%dT%H:%M:%S%z"), test,
               card, backend, build, parameter, str(value), unit, note]
        with self.path.open("a") as f:
            f.write("\t".join(x.replace("\t", " ") for x in row) + "\n")
        self.keys.add(key)
        return key


@dataclass
class Build:
    """A llama.cpp installation, identified by what is IN it.

    Never by its name: a prefix called `-rocm` that contains only Vulkan
    libraries has happened here, and the numbers from it were filed under the
    wrong backend until an architecture error gave it away.
    """
    path: Path
    backend: str
    version: str

    @property
    def bin(self) -> Path:
        return self.path / "bin"

    def __str__(self):
        return f"{self.path} [{self.backend}] {self.version}"


@dataclass
class Card:
    index: str      # the device id llama-bench itself uses, e.g. "Vulkan0"
    name: str
    vram_mib: int


@dataclass
class Context:
    host: str
    out_dir: Path
    results: Results
    builds: list[Build]
    # Cards PER BUILD, not per machine. The device id is a backend's id: the
    # same card is Vulkan0 to one build and CUDA0 to the next, and passing the
    # wrong one either fails or is ignored -- and being ignored means the run
    # measures whatever the backend picked, filed under the card that was asked
    # for.
    cards_by_build: dict[str, list[Card]]
    models: list[Path]
    power: "PowerSource"
    log_path: Path
    deadline: float | None = None
    config: dict = field(default_factory=dict)

    @property
    def cards(self) -> list[Card]:
        """The first build's cards -- for counting, not for pinning."""
        return next(iter(self.cards_by_build.values()), [])

    def cards_of(self, build: Build) -> list[Card]:
        return self.cards_by_build.get(str(build.path), [])

    def say(self, msg: str):
        line = f"[{time.strftime('%H:%M:%S')}] {msg}"
        print(line, flush=True)
        with self.log_path.open("a") as f:
            f.write(line + "\n")

    def time_left(self) -> float:
        return float("inf") if self.deadline is None else self.deadline - time.time()

    def out_of_budget(self) -> bool:
        return self.time_left() <= 0

    # -- the two kinds of not-running, and why they differ ------------------
    # permanent: this machine has one card, or no readable power sensor, or no
    #   second backend. It gets a row, so a restart does not ask again.
    # deferred: the card was busy, a model was missing, a build failed. It gets
    #   NO row, so a restart tries again.
    # Writing both as "skipped" would make a machine without a power sensor
    # retry that test on every run, forever.
    def skip_permanently(self, test, reason, **kw):
        self.say(f"  SKIPPED permanently: {test} -- {reason}")
        self.results.add(test, note=f"skipped: {reason}", **kw)

    def defer(self, test, reason):
        self.say(f"  DEFERRED to the next run: {test} -- {reason}")


class PowerSource:
    """Reading watts and moving the power limit, per vendor.

    Which mechanism produced a figure belongs next to the figure: this
    repository measured the AMD sensor under-reporting the real increase by
    about a quarter, while the NVIDIA one does not. A cross-vendor power
    comparison compares sensors as much as it compares cards.
    """
    kind = "none"
    default_limit_w: int | None = None

    def watts(self) -> float | None: return None
    def vram_used_mib(self) -> int: return 0
    def can_set_limit(self) -> bool: return False
    def set_limit(self, watts: int) -> bool: return False
    def restore(self): pass


class NvidiaPower(PowerSource):
    kind = "nvidia"

    def __init__(self, index: int = 0):
        self.index = index
        self.default_limit_w = self._query("power.limit")

    def _query(self, field):
        rc, out, _ = run(["nvidia-smi", "-i", str(self.index),
                          f"--query-gpu={field}", "--format=csv,noheader,nounits"], timeout=20)
        try:
            return float(out.strip().splitlines()[0])
        except Exception:
            return None

    def watts(self):        return self._query("power.draw")
    def vram_used_mib(self): return int(self._query("memory.used") or 0)
    def can_set_limit(self): return self.default_limit_w is not None

    def set_limit(self, watts):
        rc, _, _ = run(["nvidia-smi", "-i", str(self.index), "-pl", str(watts)], timeout=30)
        return rc == 0

    def restore(self):
        if self.default_limit_w:
            self.set_limit(int(self.default_limit_w))


class AmdPower(PowerSource):
    kind = "amd"

    def __init__(self, drm: Path):
        self.drm = Path(drm)
        hw = sorted(self.drm.glob("hwmon/hwmon*"))
        self.hwmon = hw[0] if hw else None

    def _read(self, p, div=1.0):
        try:
            return float(Path(p).read_text().strip()) / div
        except Exception:
            return None

    def watts(self):
        return self._read(self.hwmon / "power1_average", 1e6) if self.hwmon else None

    def vram_used_mib(self):
        v = self._read(self.drm / "mem_info_vram_used", 1024 ** 2)
        return int(v or 0)

    def can_set_limit(self):
        return bool(self.hwmon and os.access(self.hwmon / "power1_cap", os.W_OK))

    def set_limit(self, watts):
        try:
            (self.hwmon / "power1_cap").write_text(str(int(watts * 1e6)))
            return True
        except Exception:
            return False


def card_is_idle(ctx: Context, tries: int = 30, threshold_mib: int = 500) -> bool:
    """The card must be ours before a number counts.

    A server left over from a killed step makes the next measurement run on a
    card that is already half full, and the number looks entirely normal.
    """
    for _ in range(tries):
        rc, out, _ = run(["pgrep", "-x", "llama-server"], timeout=10)
        busy = bool(out.strip())
        if not busy and ctx.power.vram_used_mib() < threshold_mib:
            return True
        time.sleep(10)
    return False


def kernel_events() -> int:
    """A throughput test also runs through on a card that has already reset."""
    rc, out, _ = run(["dmesg"], timeout=30)
    pat = re.compile(r"NVRM: Xid|GPU has fallen off|amdgpu.*(ring|reset).*(timeout|error)"
                     r"|GPU reset|VRAM is lost", re.I)
    return sum(1 for line in out.splitlines() if pat.search(line))


def bench(build: Build, model: Path, *args, device: str | None = None,
          timeout: int = 3600, env: dict | None = None) -> dict | None:
    """One llama-bench run in a fresh process. None means it produced nothing.

    llama-bench and llama-server both carry state between runs; a warm process
    measures the previous run as well.
    """
    cmd = [str(build.bin / "llama-bench"), "-m", str(model), *map(str, args), "-o", "json"]
    if device:
        cmd += ["-dev", device]
    rc, out, err = run(cmd, timeout=timeout,
                       env={"LD_LIBRARY_PATH": str(build.bin), **(env or {})})
    try:
        entries = json.loads(out)
    except Exception:
        return None
    result = {}
    for e in entries:
        phase = "tg" if e.get("n_gen") and not e.get("n_prompt") else "pp"
        result[phase] = e["avg_ts"]
        result[phase + "_sd"] = e.get("stddev_ts", 0.0)
    return result or None


def bench_probe(build: Build, model: Path, *args, device: str | None = None,
                timeout: int = 900, env: dict | None = None) -> tuple[bool, str]:
    """Did this configuration run at all, and if not, what did it say?

    The ceiling tests need the reason, not just the failure: "out of memory" and
    "this model has no such context" are different answers to "does it fit", and
    a probe that reports both as False turns one into the other.
    """
    cmd = [str(build.bin / "llama-bench"), "-m", str(model), *map(str, args), "-o", "json"]
    if device:
        cmd += ["-dev", device]
    rc, out, err = run(cmd, timeout=timeout,
                       env={"LD_LIBRARY_PATH": str(build.bin), **(env or {})})
    try:
        if json.loads(out):
            return True, ""
    except Exception:
        pass
    reason = ""
    for line in err.splitlines():
        if re.search(r"error|failed|cannot|unable|out of memory|oom|exceed", line, re.I):
            reason = line.strip()[:120]
            break
    return False, reason or f"rc={rc}, no result"


def cli_binary(build: Build) -> Path | None:
    """llama-completion before llama-cli.

    Current llama-cli defaults to conversation mode for instruct models and then
    waits for input that never comes: it prints its answer and hangs until the
    timeout. llama-completion is the non-interactive tool and exits on its own.
    """
    for name in ("llama-completion", "llama-cli"):
        if (build.bin / name).exists():
            return build.bin / name
    return None


def cli_flags(build: Build) -> list[str]:
    """Which flags does THIS build understand?

    `-no-cnv` was valid in v0.2.0 and gone two days later. Hard-coding it turned
    every comparison against a newer build into "produced no output" -- and on
    the other machine it cost a drift check a red verdict for a build that was
    probably fine.
    """
    binary = cli_binary(build)
    if not binary:
        return []
    rc, out, err = run([str(binary), "--help"], timeout=60,
                       env={"LD_LIBRARY_PATH": str(build.bin)})
    help_text = out + err
    flags = ["--simple-io", "--no-warmup"]
    for flag in ("-no-cnv", "-st", "--no-display-prompt"):
        probe = {"-st": "--single-turn"}.get(flag, flag)
        if probe in help_text:
            flags.append(flag)
    return flags


def output_hash(build: Build, model: Path) -> tuple[str | None, str]:
    """Same answer, or only a faster one?

    A build that got faster and answers differently has not made the same work
    faster. Returns (hash, note) -- and when there is no hash, the note says why
    rather than handing back the checksum of nothing.
    """
    import hashlib
    binary = cli_binary(build)
    if not binary:
        return None, "no llama-completion/llama-cli in the build"
    cmd = [str(binary), "-m", str(model), "-ngl", "99", "--seed", "1234",
           "--temp", "0", "-n", "96", "--ctx-size", "4096",
           *cli_flags(build), "-p", "List the first ten prime numbers."]
    rc, out, err = run(cmd, timeout=240, env={"LD_LIBRARY_PATH": str(build.bin)})
    digest = hashlib.sha256(out.encode()).hexdigest()[:16]
    if digest == EMPTY_HASH:
        first = next((l for l in err.splitlines()
                      if re.search(r"error|invalid|unknown", l, re.I)), "")
        return None, f"empty output{': ' + first[:70] if first else ''}"
    return digest, ""


class WattSampler:
    """Power integrated over the compute window only.

    A sampler that starts with the benchmark still averages in model loading,
    and a 17 GB model loads for half a minute while the card idles. That
    artifact once became a published finding.
    """

    def __init__(self, power: PowerSource, interval: float = 1.0):
        self.power, self.interval, self.samples = power, interval, []
        self.vram: list[int] = []
        self._stop = False
        self._thread = None

    def __enter__(self):
        import threading
        def loop():
            while not self._stop:
                w = self.power.watts()
                if w is not None:
                    self.samples.append(w)
                # VRAM belongs in the same window as the power figure. Read
                # after the process exits it is always the idle value -- the
                # context-depth rows carried "17 MiB in use" for every depth up
                # to 65 536, which is precisely the number that test exists to
                # find and precisely the one it was not reporting.
                v = self.power.vram_used_mib()
                if v:
                    self.vram.append(v)
                time.sleep(self.interval)
        self._thread = threading.Thread(target=loop, daemon=True)
        self._thread.start()
        return self

    def __exit__(self, *exc):
        self._stop = True
        if self._thread:
            self._thread.join(timeout=3)

    @property
    def mean(self):  return sum(self.samples) / len(self.samples) if self.samples else None
    @property
    def peak(self):  return max(self.samples) if self.samples else None
    @property
    def count(self): return len(self.samples)
    @property
    def peak_vram(self): return max(self.vram) if self.vram else None

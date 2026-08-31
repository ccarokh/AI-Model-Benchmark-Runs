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


# A measurement that kills the machine is not a measurement.
#
# Twice now a run on the host with 15 GB of RAM ended with the kernel's OOM
# killer taking llama-bench -- and systemd taking the whole night service with
# it, because they share a unit. The GPU lease died with the heartbeat, the
# night ended hours early, and the log has no line that says so: the process
# that would have written it was killed too.
#
# The processes were not even large. The last one held 638 MB resident and had
# 57 GB of address space mapped, which is what mapping a 20 GiB model plus its
# buffers looks like. Guessing which model is safe is not the answer; putting
# each measurement in its own cgroup is. Then a runaway child is killed inside
# its own scope, the test records "no measurement" -- which is a result -- and
# the night carries on.
MEMORY_SCOPE = os.environ.get("TESTBENCH_MEMORY_LIMIT", "")


def _limited(cmd: list, limit: str | None = None) -> list:
    """The command, wrapped in a memory-capped scope if one was asked for.

    The cap can be overridden per call, because a guard that changes the numbers
    is not a guard -- and the only way to know is to measure the same work with
    it and without it.
    """
    scope = MEMORY_SCOPE if limit is None else limit
    if not scope:
        return cmd
    return ["systemd-run", "--scope", "-q", "--collect",
            "-p", f"MemoryMax={scope}", "-p", "MemorySwapMax=0",
            *cmd]


def run(cmd, timeout=None, env=None, stdin_null=True, capture_stderr=False,
        memory=None):
    """One subprocess call, with the failure mode kept visible.

    Returns (returncode, stdout, stderr). Nothing here raises on a non-zero
    exit: a failed measurement is a result that has to be recorded, not an
    exception that unwinds the run.
    """
    full = dict(os.environ)
    full.update(env or {})
    try:
        p = subprocess.run(
            _limited(cmd, memory), timeout=timeout, env=full,
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
        self.values: dict[str, str] = {}
        if path.exists():
            for line in path.read_text().splitlines()[1:]:
                if line.strip():
                    cells = line.split("\t")
                    self.keys.add(cells[0])
                    if len(cells) > COLUMNS.index("value"):
                        self.values[cells[0]] = cells[COLUMNS.index("value")]
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
        self.values[key] = str(value)
        return key

    def value_of(self, test, card="", backend="", build="", parameter="") -> str | None:
        """The value a previous run wrote, or None.

        Resume needs more than "was this measured": a comparison test has to
        read back what it compared AGAINST. Without this, a run interrupted
        after the baseline and restarted has the baseline row in the file and no
        way to reach the hash in it -- so it either re-measures the baseline or,
        worse, compares against nothing and calls everything identical.
        """
        return self.values.get(self.key(test, card, backend, build, parameter))


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

    def card_for(self, build: Build) -> str | None:
        """The card a test should pin, or None when there is nothing to pin.

        WITHOUT THIS, A TEST MEASURES WHATEVER THE BACKEND PICKED. On a host
        holding a 7900 XTX and an RTX 2070, llama.cpp spreads a model across
        both unless told otherwise -- and that is 35 to 65 percent slower than
        the fast card alone. Thirty-one models were measured both ways there and
        every single one was faster pinned, by 1.5x to 3.5x.

        Only 10_reference passed a device, and the rule sits in its comment: a
        number that silently used two cards is not a card's number. Every other
        test filed two-card figures under an empty card column.
        """
        cards = self.cards_of(build)
        return cards[0].index if cards else None

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
    def coverage(self, test, done: int, total: int, note: str = ""):
        """How much of the possible was actually measured.

        A test that quietly runs on the first build and the first two models
        reports "done" for a corner of the matrix, and the results file cannot
        tell that apart from full coverage -- absence of a row and absence of a
        measurement look identical. So every test writes what it covered.
        """
        self.results.add(test, parameter="coverage", value=f"{done}/{total}",
                         unit="combinations", note=note)
        if done < total:
            self.say(f"  coverage: {done} of {total} combinations{' -- ' + note if note else ''}")

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


def too_big_for(model: Path, card: "Card | None", margin: float = 0.92) -> str:
    """Why this model cannot run on this card -- or "" if it can be tried.

    A MEASUREMENT THAT CANNOT SUCCEED IS NOT WORTH ATTEMPTING, and on a machine
    with little system memory it is worse than useless. On the night of 27.08.
    the reference test worked its way through every model on both cards of a
    host that has a 24 GB card and an 8 GB one. Handing a 20 GB model to the
    8 GB card made llama-bench map 95 GB of address space on a box with 15 GB of
    RAM; the kernel's OOM killer took it, and systemd took the whole night
    service with it. The GPU lease died with the heartbeat, and the run was over
    at 01:26 with no line in the log to say so.

    Weights alone, before any cache: if they do not fit, nothing else matters.
    """
    if card is None or not card.vram_mib:
        return ""
    groesse = model.stat().st_size / 1024 ** 2
    if groesse > card.vram_mib * margin:
        return (f"weights {groesse / 1024:.2f} GiB do not fit on {card.index} "
                f"({card.vram_mib} MiB)")
    return ""


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
          timeout: int = 3600, env: dict | None = None,
          memory: str | None = None) -> dict | None:
    """One llama-bench run in a fresh process. None means it produced nothing.

    llama-bench and llama-server both carry state between runs; a warm process
    measures the previous run as well.
    """
    cmd = [str(build.bin / "llama-bench"), "-m", str(model), *map(str, args), "-o", "json"]
    if device:
        cmd += ["-dev", device]
    rc, out, err = run(cmd, timeout=timeout, memory=memory,
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


def alloc_probe(build: Build, model: Path, ctx_size: int, cache: str = "f16",
                timeout: int = 300, device: str | None = None) -> tuple[bool, str]:
    """Does a context of this size ALLOCATE -- without paying to fill it.

    The ceiling is an allocation limit, not a compute one: what fails is the KV
    cache and the buffers around it, and it fails before a single token is
    processed. Probing it with llama-bench -d meant prefilling the whole depth
    first -- seven minutes for one probe at 327 680 tokens, which put the search
    out of reach for anything but a model or two. Asking for the context and
    generating one token answers the same question in seconds.

    What it does NOT answer is what throughput looks like at that depth. That is
    a different test, and it stays expensive on purpose.
    """
    binary = cli_binary(build)
    if not binary:
        return False, "no llama-completion/llama-cli in the build"
    cmd = [str(binary), "-m", str(model), "-ngl", "99", "--ctx-size", str(ctx_size),
           "-n", "1", "--temp", "0", "--seed", "1", "-fa", "on",
           "-ctk", cache, "-ctv", cache, *(["-dev", device] if device else []),
           *cli_flags(build), "-p", "x"]
    rc, out, err = run(cmd, timeout=timeout, env={"LD_LIBRARY_PATH": str(build.bin)})
    text = out + err
    fail = re.search(r"(failed to allocate|allocation of size \d+ failed|out of memory|"
                     r"unable to (allocate|load)|failed to (create|init))[^\n]*", text, re.I)
    if fail:
        return False, fail.group(0)[:120]
    if rc != 0:
        line = next((l for l in err.splitlines()
                     if re.search(r"error|failed|cannot", l, re.I)), f"rc={rc}")
        return False, line.strip()[:120]
    return True, ""


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


def output_hash(build: Build, model: Path,
                device: str | None = None) -> tuple[str | None, str]:
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
           *(["-dev", device] if device else []),
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


# -- the server, and why the suite suddenly needs it ------------------------
# Every number in this repository up to here came from llama-bench: one model,
# one stream, one token at a time. Speculative decoding cannot be measured that
# way -- llama-bench has no draft path at all. The instrument is llama-server
# plus a single request, and the timings it reports for that request.
#
# The server is the more dangerous instrument of the two. It carries state
# between requests (a warm cache, a previous slot), so every measurement here
# gets a FRESH PROCESS and exactly ONE request. A second request into the same
# process measures the first one as well.
def free_port(start: int = 8099, tries: int = 50) -> int:
    import socket
    for port in range(start, start + tries):
        with socket.socket() as s:
            try:
                s.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    return start


def server_probe(build: Build, model: Path, prompt: str, *extra,
                 n_predict: int = 256, ngl: int = 99, ctx_size: int = 8192,
                 boot_timeout: int = 180, request_timeout: int = 600,
                 device: str | None = None) -> dict:
    """One fresh server, one request. Always returns a dict, never raises.

    Keys: ok, tg, pp, hash, text, acceptance, reason. When ok is false, `reason`
    carries the server's own words -- "this model cannot draft for that one" and
    "the card was full" are different answers, and a probe that reports both as
    False turns one into the other.
    """
    import hashlib
    import urllib.error
    import urllib.request

    port = free_port()
    log = Path(os.environ.get("TMPDIR", "/tmp")) / f"server_probe.{port}.log"
    cmd = [str(build.bin / "llama-server"), "-m", str(model),
           "-ngl", str(ngl), "-c", str(ctx_size),
           "--host", "127.0.0.1", "--port", str(port), "--no-warmup",
           *(["-dev", device] if device else []), *map(str, extra)]
    env = dict(os.environ, LD_LIBRARY_PATH=str(build.bin))
    out = {"ok": False, "tg": None, "pp": None, "hash": None, "text": "",
           "acceptance": None, "reason": ""}

    def died_because() -> str:
        text = log.read_text(errors="replace") if log.exists() else ""
        for line in reversed(text.splitlines()):
            if re.search(r"error|failed|cannot|unsupported|mismatch|out of memory|oom", line, re.I):
                return line.strip()[:140]
        return "server exited without a usable message"

    with log.open("w") as handle:
        proc = subprocess.Popen(_limited(cmd), stdout=handle, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, env=env)
    try:
        deadline = time.time() + boot_timeout
        ready = False
        while time.time() < deadline:
            if proc.poll() is not None:
                out["reason"] = died_because()
                return out
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2) as r:
                    if b'"ok"' in r.read():
                        ready = True
                        break
            except Exception:
                pass
            time.sleep(1)
        if not ready:
            out["reason"] = f"no health after {boot_timeout}s"
            return out

        body = json.dumps({"prompt": prompt, "n_predict": n_predict,
                           "temperature": 0, "cache_prompt": False}).encode()
        req = urllib.request.Request(f"http://127.0.0.1:{port}/completion", data=body,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=request_timeout) as r:
                data = json.loads(r.read())
        except Exception as e:
            out["reason"] = f"request failed: {str(e)[:100]}"
            return out
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            proc.kill()

    text = data.get("content", "")
    timings = data.get("timings", {})
    digest = hashlib.sha256(text.encode()).hexdigest()[:16]
    if digest == EMPTY_HASH:
        out["reason"] = "the server answered with nothing"
        return out
    hits = re.findall(r"draft acceptance = ([0-9.]+)",
                      log.read_text(errors="replace") if log.exists() else "")
    out.update(ok=True, tg=timings.get("predicted_per_second"),
               pp=timings.get("prompt_per_second"), hash=digest, text=text,
               acceptance=float(hits[-1]) if hits else None)
    return out


def common_prefix(a: str, b: str) -> int:
    """How far two answers agree, in characters.

    A hash says "different" and stops there. Where the two answers part company
    is the more useful number: a run that diverges at character 2 is a different
    first token, one that diverges at 133 is a coin flip deep in a sentence, and
    those are not the same finding.
    """
    n = 0
    for x, y in zip(a, b):
        if x != y:
            break
        n += 1
    return n


def server_load(build: Build, model: Path, prompt: str, users: int,
                per_user_ctx: int = 8192, n_predict: int = 200,
                ngl: int = 99, boot_timeout: int = 240,
                request_timeout: int = 900, slots: int | None = None,
                extra: tuple = (), device: str | None = None) -> dict:
    """How many people can this card serve at once, before it stops serving.

    Every other figure in this repository is a single request on an empty card
    -- the number a person sees when nobody else is using the machine. That is
    not the number a service delivers. This starts the server with `users` slots
    and `users * per_user_ctx` of context, fires that many requests at the same
    moment, and reports what each of them actually experienced.

    THE CONTEXT IS PER USER, NOT PER SERVER. llama.cpp divides --ctx-size
    between the slots, so asking for eight users on a fixed context silently
    gives each of them an eighth of it -- and the run then measures a smaller
    context, not more users. The total is scaled here so that every user keeps
    the same budget at every concurrency.

    Returns: ok, aggregate (tokens/s over all users), per_user (median),
    slowest (worst wall time), failures, reason.
    """
    import statistics
    import threading
    import urllib.error
    import urllib.request

    # SLOTS AND USERS ARE NOT THE SAME NUMBER. Every measurement here used to
    # give each user a slot of their own, which answers "how many can be served
    # simultaneously" and not "how many can use this service". llama.cpp parks
    # an idle slot in a host-RAM prompt cache and fetches it back, so more people
    # than slots is a supported arrangement -- it costs waiting, not failure,
    # and the waiting is the number worth having.
    slots = slots or users
    port = free_port()
    log = Path(os.environ.get("TMPDIR", "/tmp")) / f"server_load.{port}.log"
    cmd = [str(build.bin / "llama-server"), "-m", str(model),
           "-ngl", str(ngl), "-c", str(slots * per_user_ctx), "-np", str(slots),
           "--host", "127.0.0.1", "--port", str(port), "--no-warmup",
           *(["-dev", device] if device else []), *map(str, extra)]
    env = dict(os.environ, LD_LIBRARY_PATH=str(build.bin))
    out = {"ok": False, "aggregate": None, "per_user": None, "slowest": None,
           "failures": 0, "reason": "", "tokens": 0}

    with log.open("w") as handle:
        proc = subprocess.Popen(_limited(cmd), stdout=handle, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, env=env)
    try:
        deadline = time.time() + boot_timeout
        ready = False
        while time.time() < deadline:
            if proc.poll() is not None:
                text = log.read_text(errors="replace") if log.exists() else ""
                # WHICH allocation failed, not that one did. "exiting due to
                # model loading error" is the last line the server prints and
                # the least informative one: the size it could not get is three
                # lines above it, and that is the number the ceiling is made of.
                zeilen = text.splitlines()
                for muster in (r"out of memory|failed to allocate|allocation of size|unable to allocate",
                               r"error|failed|cannot"):
                    treffer = [l.strip() for l in reversed(zeilen) if re.search(muster, l, re.I)]
                    if treffer:
                        out["reason"] = treffer[0][:140]
                        break
                out["reason"] = out["reason"] or "server exited during startup"
                return out
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2) as r:
                    if b'"ok"' in r.read():
                        ready = True
                        break
            except Exception:
                pass
            time.sleep(1)
        if not ready:
            out["reason"] = f"no health after {boot_timeout}s"
            return out

        # ONE REQUEST BEFORE THE MEASURED ONES. A fresh server has allocated its
        # buffers and touched none of them; the first request pays for that, and
        # at two users that cost is half the measurement. It showed up as two
        # users being slower than four -- an ordering that is not physical.
        try:
            aufwaermen = json.dumps({"prompt": prompt, "n_predict": 16,
                                     "temperature": 0, "cache_prompt": False}).encode()
            req = urllib.request.Request(f"http://127.0.0.1:{port}/completion", data=aufwaermen,
                                         headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=request_timeout).read()
        except Exception:
            pass    # a warm-up that fails is not a result; the burst will say so

        ergebnisse: list[dict] = []
        sperre = threading.Lock()
        # All of them at the same moment, not staggered: the question is what
        # happens when the machine is actually busy, and a queue that never
        # forms is not a load test.
        los = threading.Event()

        def einer(index: int):
            body = json.dumps({"prompt": prompt, "n_predict": n_predict,
                               "temperature": 0, "cache_prompt": False}).encode()
            req = urllib.request.Request(f"http://127.0.0.1:{port}/completion", data=body,
                                         headers={"Content-Type": "application/json"})
            los.wait()
            start = time.time()
            try:
                with urllib.request.urlopen(req, timeout=request_timeout) as r:
                    data = json.loads(r.read())
                dauer = time.time() - start
                erzeugt = data.get("timings", {}).get("predicted_n") or 0
                with sperre:
                    ergebnisse.append({"ok": True, "dauer": dauer, "tokens": erzeugt})
            except Exception as e:
                with sperre:
                    ergebnisse.append({"ok": False, "dauer": time.time() - start,
                                       "fehler": str(e)[:80]})

        faeden = [threading.Thread(target=einer, args=(i,)) for i in range(users)]
        for f in faeden:
            f.start()
        beginn = time.time()
        los.set()
        for f in faeden:
            f.join()
        spanne = time.time() - beginn
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            proc.kill()

    gut = [e for e in ergebnisse if e["ok"]]
    out["failures"] = len(ergebnisse) - len(gut)
    if not gut:
        fehler = next((e.get("fehler", "") for e in ergebnisse if not e["ok"]), "")
        out["reason"] = f"every request failed: {fehler}"
        return out
    tokens = sum(e["tokens"] for e in gut)
    raten = [e["tokens"] / e["dauer"] for e in gut if e["dauer"] > 0]
    out.update(ok=True, tokens=tokens,
               aggregate=tokens / spanne if spanne else None,
               per_user=statistics.median(raten) if raten else None,
               slowest=max(e["dauer"] for e in gut))
    return out

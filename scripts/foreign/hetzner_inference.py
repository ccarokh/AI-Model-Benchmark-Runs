#!/usr/bin/env python3
"""Two models we already measured, served by somebody else. A one-off.

Hetzner's experimental Inference API offers exactly the two models this
repository got stuck on:

    Qwen3.8-27B       coding abandoned at 61 and 38 of 225 tasks -- 18.5 min
                      each, which rules out interactive use and says nothing
                      about the model
    Qwen3.6-35B-A3B   225 of 225 here, the fastest agent measured

It can answer two questions that local hardware cannot, and it can answer no
others. **An endpoint measures their hardware, their batching, their precision
and their load, none of it visible from here.** Throughput, context ceilings,
power, concurrency: not one of those is measurable through somebody else's
service, and nothing in this file tries.

What it can answer:

  1. WHAT DOES OUR QUANTISATION COST? Everything here is Q4_K_M on llama.cpp.
     Hetzner serves FP8. The QAT comparison showed that two Q4 variants of one
     model score the same; Q4 against FP8 is the question we never had a
     reference for.

  2. WHAT DOES THE ENDPOINT ACTUALLY SUPPORT? Asked first, and separately,
     because this repository's own finding is that how you ask is worth up to
     seventy points. Without knowing whether temperature 0 is honoured, whether
     logprobs exist, and whether two identical requests return the same text,
     any score from here is a number without a stand.

DELIBERATELY ONE-OFF. The service is experimental and free, which means it can
be withdrawn; its results carry a date and a provider and live in their own
file. They are not comparable with local rows and must never be merged into
them.

    HETZNER_TOKEN=... python3 hetzner_inference.py probe
    HETZNER_TOKEN=... python3 hetzner_inference.py belebele [n]
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASIS = "https://inference.hetzner.com/api/v1"
MODELLE = ["Qwen/Qwen3.6-35B-A3B-FP8", "Qwen3.8-27B"]

# Ten requests per sixty seconds, per the published limits. Six seconds between
# them, and the pause is taken BEFORE the request rather than after a refusal:
# a 429 is not a measurement, and a run that collects them is measuring its own
# impatience.
ABSTAND = 6.5


def token() -> str:
    t = os.environ.get("HETZNER_TOKEN", "").strip()
    if not t:
        sys.exit("HETZNER_TOKEN is not set. The token belongs in the environment,\n"
                 "not in this file and not in this repository.")
    return t


def anfrage(pfad: str, koerper: dict | None = None, timeout: int = 300) -> dict:
    kopf = {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}
    daten = json.dumps(koerper).encode() if koerper is not None else None
    req = urllib.request.Request(BASIS + pfad, data=daten, headers=kopf)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return {"ok": True, "status": r.status, "body": json.loads(r.read())}
    except urllib.error.HTTPError as e:
        roh = e.read().decode(errors="replace")[:300]
        return {"ok": False, "status": e.code, "error": roh}
    except Exception as e:
        return {"ok": False, "status": 0, "error": str(e)[:200]}


def frage(modell: str, inhalt: str, **kw) -> dict:
    koerper = {"model": modell, "messages": [{"role": "user", "content": inhalt}], **kw}
    return anfrage("/chat/completions", koerper)


def text_von(antwort: dict) -> str:
    return antwort["body"]["choices"][0]["message"]["content"] if antwort["ok"] else ""


def probe():
    """What this endpoint supports -- asked before anything is scored on it."""
    print("== /v1/models")
    liste = anfrage("/models")
    if not liste["ok"]:
        sys.exit(f"  unreachable: {liste['status']} {liste.get('error','')}")
    gemeldet = [m["id"] for m in liste["body"].get("data", [])]
    for m in gemeldet:
        print(f"  {m}")
    for m in MODELLE:
        if m not in gemeldet:
            print(f"  ! {m} is NOT in the list -- the list is definitive, this name will fail")

    for modell in [m for m in MODELLE if m in gemeldet]:
        print(f"\n== {modell}")
        # Determinism: the same question twice at temperature 0. Without it,
        # every later comparison is between two samples rather than two models.
        hashes = []
        for _ in range(2):
            time.sleep(ABSTAND)
            a = frage(modell, "Nenne die ersten zehn Primzahlen.", temperature=0, max_tokens=64)
            if not a["ok"]:
                print(f"  request failed: {a['status']} {a.get('error','')}")
                break
            hashes.append(hashlib.sha256(text_von(a).encode()).hexdigest()[:16])
        if len(hashes) == 2:
            print(f"  temperature 0 twice: {hashes[0]} / {hashes[1]}"
                  f"  -> {'deterministic' if hashes[0] == hashes[1] else 'NOT deterministic'}")

        # logprobs decide whether our published logprob stand can be used here
        # at all, or whether only the free-generation stand is available.
        time.sleep(ABSTAND)
        a = anfrage("/completions", {"model": modell, "prompt": "Die Hauptstadt von Frankreich ist",
                                     "max_tokens": 1, "temperature": 0, "logprobs": 5})
        if a["ok"]:
            wahl = a["body"]["choices"][0]
            hat = bool(wahl.get("logprobs"))
            print(f"  /v1/completions with logprobs: {'available' if hat else 'accepted but empty'}")
        else:
            print(f"  /v1/completions with logprobs: {a['status']} {a.get('error','')[:80]}")

        # A rate, recorded only so that nobody mistakes it for one of ours.
        time.sleep(ABSTAND)
        t0 = time.time()
        a = frage(modell, "Schreibe drei Saetze ueber Wartung.", temperature=0, max_tokens=200)
        if a["ok"]:
            n = a["body"].get("usage", {}).get("completion_tokens", 0)
            print(f"  {n} tokens in {time.time() - t0:.1f} s -- THEIR hardware under THEIR load, "
                  "not a figure to compare with anything in this repository")


def belebele(n: int = 900):
    """The comprehension corpus, on the free-generation stand only.

    The published local figures come from two stands. Which of them is
    reproducible here is what `probe` establishes; until it says logprobs work,
    only free generation is honest, and the comparison has to name that.
    """
    from datasets import load_dataset
    import re

    vorlage = ("Lies den folgenden Text und beantworte die Frage, indem du am Ende deiner "
               "Antwort NUR den Buchstaben A, B, C oder D in dieser Form angibst: 'Antwort: X'."
               "\n\nText: {passage}\n\nFrage: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}")
    ds = load_dataset("facebook/belebele", "deu_Latn", split="test").select(range(n))
    BUCHSTABE = re.compile(r"\b([ABCD])\b")
    zeilen = []
    for modell in MODELLE:
        richtig = ohne = 0
        t0 = time.time()
        for i, ex in enumerate(ds):
            time.sleep(ABSTAND)
            a = frage(modell, vorlage.format(
                passage=ex["flores_passage"], question=ex["question"],
                a=ex["mc_answer1"], b=ex["mc_answer2"], c=ex["mc_answer3"], d=ex["mc_answer4"]),
                temperature=0, max_tokens=512)
            if not a["ok"]:
                ohne += 1
                continue
            treffer = BUCHSTABE.findall(text_von(a))
            gold = ["A", "B", "C", "D"][int(ex["correct_answer_num"]) - 1]
            if treffer and treffer[-1] == gold:
                richtig += 1
            if (i + 1) % 25 == 0:
                print(f"  {modell} {i+1}/{n} -- {richtig/(i+1):.3f}", file=sys.stderr, flush=True)
        zeilen.append({"provider": "hetzner-inference-experimental", "model": modell,
                       "precision": "FP8", "harness": "generate", "n": n,
                       "correct": richtig, "accuracy": round(richtig / n, 4),
                       "no_answer": ohne, "seconds": round(time.time() - t0),
                       "measured": time.strftime("%Y-%m-%d")})
        print(json.dumps(zeilen[-1]))
    kopf = list(zeilen[0])
    print("\t".join(kopf))
    for z in zeilen:
        print("\t".join(str(z[k]) for k in kopf))


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("probe", "belebele"):
        sys.exit(__doc__)
    token()   # checked before anything prints, so a missing one is not a failed run
    if sys.argv[1] == "probe":
        probe()
    else:
        belebele(int(sys.argv[2]) if len(sys.argv) > 2 else 900)

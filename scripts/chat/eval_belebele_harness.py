"""Belebele deu_Latn -- derselbe Datensatz, dasselbe Modell, DREI Pruefstaende.

Warum das noetig ist: die beiden vorhandenen Skripte unterscheiden sich in drei
Dingen gleichzeitig -- wie die Antwort ausgelesen wird (Buchstaben-Logprob gegen
freies Erzeugen), wie der Prompt formuliert ist, und ob Denken erlaubt ist. Der
gemessene Abstand von 12,7 Punkten bei Nanbeige laesst sich deshalb keiner der
drei Ursachen zuordnen.

Die Stufen sind so gewaehlt, dass zwischen je zwei genau EINE Variable steht:

  logprob   Buchstaben-Wahrscheinlichkeit, Denken aus, Nur-Buchstabe-Prompt
            (= der veroeffentlichte Pruefstand hinter chat_belebele.tsv)
  generate  freies Erzeugen, Denken aus, "Antwort: X"-Prompt
            gegen logprob  -> isoliert Auslesen + Prompt
  thinking  freies Erzeugen, Denken an, "Antwort: X"-Prompt
            gegen generate -> isoliert das Denken

Aufruf:
    python3 eval_belebele_harness.py <base_url> <tokenizer> <modus> [n] [max_tokens]

Ausgabe: eine JSON-Zeile auf stdout, Fortschritt auf stderr.
"""

import json
import re
import sys
import time

import httpx
from datasets import load_dataset
from transformers import AutoTokenizer

BASE_URL, TOKENIZER, MODUS = sys.argv[1], sys.argv[2], sys.argv[3]
N = int(sys.argv[4]) if len(sys.argv) > 4 else 150
MAX_TOKENS = int(sys.argv[5]) if len(sys.argv) > 5 else 8192

if MODUS not in ("logprob", "generate", "thinking"):
    sys.exit(f"unbekannter Modus: {MODUS}")

PROMPT_LOGPROB = (
    "Lies den folgenden Text und beantworte die Frage, indem du NUR mit dem Buchstaben "
    "A, B, C oder D antwortest, ohne weiteren Text.\n\n"
    "Text: {passage}\n\nFrage: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}"
)
PROMPT_GENERATE = (
    "Lies den folgenden Text und beantworte die Frage, indem du am Ende deiner Antwort "
    "NUR den Buchstaben A, B, C oder D in dieser Form angibst: 'Antwort: X'.\n\n"
    "Text: {passage}\n\nFrage: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}"
)

tok = AutoTokenizer.from_pretrained(TOKENIZER)
ds = load_dataset("facebook/belebele", "deu_Latn", split="test").select(range(N))
LETTER_RE = re.compile(r"\b([ABCD])\b")
client = httpx.Client(timeout=600.0)

vorlage = PROMPT_LOGPROB if MODUS == "logprob" else PROMPT_GENERATE
denken = MODUS == "thinking"

# Not every tokenizer knows enable_thinking. Whether the switch arrived gets
# logged -- a silently ignored argument would turn the "thinking" stage into a
# copy of "generate" without anyone seeing it.
try:
    tok.apply_chat_template([{"role": "user", "content": "x"}], tokenize=False,
                            add_generation_prompt=True, enable_thinking=denken)
    schalter = "angenommen"
except TypeError:
    schalter = "nicht unterstuetzt"


def bauen(msg):
    kw = dict(tokenize=False, add_generation_prompt=True)
    if schalter == "angenommen":
        kw["enable_thinking"] = denken
    return tok.apply_chat_template([{"role": "user", "content": msg}], **kw)


korrekt = 0
ohne_antwort = 0
kein_buchstabe = 0
abgeschnitten = 0
tokens = []
t0 = time.time()

for i, ex in enumerate(ds):
    msg = vorlage.format(
        passage=ex["flores_passage"], question=ex["question"],
        a=ex["mc_answer1"], b=ex["mc_answer2"], c=ex["mc_answer3"], d=ex["mc_answer4"],
    )
    prompt = bauen(msg)
    gold = ["A", "B", "C", "D"][int(ex["correct_answer_num"]) - 1]

    if MODUS == "logprob":
        r = client.post(f"{BASE_URL}/v1/completions", json={
            "prompt": prompt, "max_tokens": 1, "logprobs": 20, "temperature": 0.0,
        })
        r.raise_for_status()
        top = r.json()["choices"][0]["logprobs"]["content"][0]["top_logprobs"]
        werte = {b: max((t["logprob"] for t in top if t["token"].strip() == b), default=-1e9)
                 for b in "ABCD"}
        if all(v == -1e9 for v in werte.values()):
            kein_buchstabe += 1
        vorhersage = max(werte, key=werte.get)
        tokens.append(1)
    else:
        r = client.post(f"{BASE_URL}/v1/completions", json={
            "prompt": prompt, "max_tokens": MAX_TOKENS, "temperature": 0.0,
        })
        r.raise_for_status()
        d = r.json()
        text = d["choices"][0]["text"]
        n_tok = (d.get("usage") or {}).get("completion_tokens") or 0
        tokens.append(n_tok)
        if n_tok >= MAX_TOKENS:
            abgeschnitten += 1
        treffer = LETTER_RE.findall(text)
        vorhersage = treffer[-1] if treffer else None
        if vorhersage is None:
            ohne_antwort += 1

    if vorhersage == gold:
        korrekt += 1
    if (i + 1) % 25 == 0:
        print(f"  {i+1}/{N} — laufend: {korrekt/(i+1):.3f}", file=sys.stderr)

tokens_ges = sum(tokens)
srt = sorted(tokens)
print(json.dumps({
    "modus": MODUS, "n": N, "correct": korrekt, "accuracy": round(korrekt / N, 4),
    "tokens_total": tokens_ges,
    "tokens_median": srt[len(srt) // 2],
    "tokens_mean": round(tokens_ges / N, 1),
    "truncated": abgeschnitten,
    "no_answer": ohne_antwort,
    "no_letter_in_top20": kein_buchstabe,
    "thinking_switch": schalter,
    "max_tokens": MAX_TOKENS,
    "seconds": round(time.time() - t0, 1),
}))

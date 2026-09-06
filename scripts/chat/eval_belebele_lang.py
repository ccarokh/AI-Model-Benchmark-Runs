"""Belebele in several languages, over /v1/chat/completions, template from the GGUF.

Same instrument as eval_belebele_chat.py, with two additions that a cross-language
comparison cannot do without:

THE SAME QUESTIONS EVERYWHERE. Belebele ships each language as its own file, and
the row order differs between them -- the first German row is not the first
English one. Taking the first N by position therefore compares languages AND
questions at once. Here the set is sorted by (link, question_number), a key that
exists in every language and covers all 900 items, so N is the same N everywhere.
The price: numbers are NOT comparable with runs that used the unsorted order.

PROMPT LANGUAGE IS ITS OWN PARAMETER. Asking in German about an English passage
mixes reading ability with prompt language, and the harness is worth up to 70
points here. Default is the passage language; passing it separately is what makes
the cross-check possible -- German passages asked in English, and the reverse.

    python3 eval_belebele_lang.py <base_url> <modus> <sprache> [prompt_sprache] [n] [max_tokens]

modus:   logprob | generate | thinking
sprache: deu_Latn | eng_Latn | fra_Latn | spa_Latn
"""

import json
import re
import sys
import time

import httpx
from datasets import load_dataset

BASE_URL, MODUS, SPRACHE = sys.argv[1], sys.argv[2], sys.argv[3]
PROMPT_SPRACHE = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != "-" else SPRACHE
N = int(sys.argv[5]) if len(sys.argv) > 5 else 150
MAX_TOKENS = int(sys.argv[6]) if len(sys.argv) > 6 else 8192

if MODUS not in ("logprob", "generate", "thinking"):
    sys.exit(f"unbekannter Modus: {MODUS}")

# One pair per language. The wording is a translation of the German original, not
# a better prompt -- the point is to keep the instruction constant in meaning so
# the language is the only thing that moves.
VORLAGEN = {
    "deu_Latn": (
        "Lies den folgenden Text und beantworte die Frage, indem du NUR mit dem Buchstaben "
        "A, B, C oder D antwortest, ohne weiteren Text.\n\n"
        "Text: {passage}\n\nFrage: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}",
        "Lies den folgenden Text und beantworte die Frage, indem du am Ende deiner Antwort "
        "NUR den Buchstaben A, B, C oder D in dieser Form angibst: 'Antwort: X'.\n\n"
        "Text: {passage}\n\nFrage: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}",
    ),
    "eng_Latn": (
        "Read the following text and answer the question by replying with ONLY the letter "
        "A, B, C or D, with no other text.\n\n"
        "Text: {passage}\n\nQuestion: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}",
        "Read the following text and answer the question, stating at the end of your answer "
        "ONLY the letter A, B, C or D in this form: 'Answer: X'.\n\n"
        "Text: {passage}\n\nQuestion: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}",
    ),
    "fra_Latn": (
        "Lis le texte suivant et réponds à la question en indiquant UNIQUEMENT la lettre "
        "A, B, C ou D, sans aucun autre texte.\n\n"
        "Texte : {passage}\n\nQuestion : {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}",
        "Lis le texte suivant et réponds à la question en indiquant à la fin de ta réponse "
        "UNIQUEMENT la lettre A, B, C ou D sous cette forme : 'Réponse : X'.\n\n"
        "Texte : {passage}\n\nQuestion : {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}",
    ),
    "spa_Latn": (
        "Lee el siguiente texto y responde a la pregunta indicando SOLO la letra "
        "A, B, C o D, sin ningún otro texto.\n\n"
        "Texto: {passage}\n\nPregunta: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}",
        "Lee el siguiente texto y responde a la pregunta indicando al final de tu respuesta "
        "SOLO la letra A, B, C o D con este formato: 'Respuesta: X'.\n\n"
        "Texto: {passage}\n\nPregunta: {question}\nA) {a}\nB) {b}\nC) {c}\nD) {d}",
    ),
}
if SPRACHE not in VORLAGEN:
    sys.exit(f"unbekannte Sprache: {SPRACHE}")
if PROMPT_SPRACHE not in VORLAGEN:
    sys.exit(f"unbekannte Prompt-Sprache: {PROMPT_SPRACHE}")

roh = load_dataset("facebook/belebele", SPRACHE, split="test")
# Stable across languages; position in the file is not.
ds = sorted(roh, key=lambda r: (r["link"], int(r["question_number"])))[:N]

LETTER_RE = re.compile(r"\b([ABCD])\b")
client = httpx.Client(timeout=900.0)

vorlage = VORLAGEN[PROMPT_SPRACHE][0 if MODUS == "logprob" else 1]
extra = {"chat_template_kwargs": {"enable_thinking": MODUS == "thinking"}}

korrekt = 0
ohne_antwort = 0
kein_buchstabe = 0
abgeschnitten = 0
fehler = 0
tokens = []
t0 = time.time()

for i, ex in enumerate(ds):
    msg = vorlage.format(
        passage=ex["flores_passage"], question=ex["question"],
        a=ex["mc_answer1"], b=ex["mc_answer2"], c=ex["mc_answer3"], d=ex["mc_answer4"],
    )
    gold = ["A", "B", "C", "D"][int(ex["correct_answer_num"]) - 1]
    rumpf = {"messages": [{"role": "user", "content": msg}], "temperature": 0.0, **extra}

    try:
        if MODUS == "logprob":
            rumpf.update({"max_tokens": 1, "logprobs": True, "top_logprobs": 20})
            r = client.post(f"{BASE_URL}/v1/chat/completions", json=rumpf)
            r.raise_for_status()
            top = r.json()["choices"][0]["logprobs"]["content"][0]["top_logprobs"]
            werte = {b: max((t["logprob"] for t in top if t["token"].strip() == b), default=-1e9)
                     for b in "ABCD"}
            if all(v == -1e9 for v in werte.values()):
                kein_buchstabe += 1
            vorhersage = max(werte, key=werte.get)
            tokens.append(1)
        else:
            rumpf["max_tokens"] = MAX_TOKENS
            r = client.post(f"{BASE_URL}/v1/chat/completions", json=rumpf)
            r.raise_for_status()
            d = r.json()
            w = d["choices"][0]["message"]
            text = (w.get("content") or "") + " " + (w.get("reasoning_content") or "")
            n_tok = (d.get("usage") or {}).get("completion_tokens") or 0
            tokens.append(n_tok)
            if n_tok >= MAX_TOKENS:
                abgeschnitten += 1
            treffer = LETTER_RE.findall(text)
            vorhersage = treffer[-1] if treffer else None
            if vorhersage is None:
                ohne_antwort += 1
    except Exception as e:
        fehler += 1
        print(f"  Fehler bei {i}: {type(e).__name__}", file=sys.stderr)
        tokens.append(0)
        vorhersage = None

    if vorhersage == gold:
        korrekt += 1
    if (i + 1) % 25 == 0:
        print(f"  {i+1}/{N} — laufend: {korrekt/(i+1):.3f}", file=sys.stderr)

srt = sorted(tokens)
print(json.dumps({
    "modus": MODUS, "sprache": SPRACHE, "prompt_sprache": PROMPT_SPRACHE,
    "n": N, "correct": korrekt, "accuracy": round(korrekt / N, 4),
    "tokens_total": sum(tokens),
    "tokens_median": srt[len(srt) // 2],
    "tokens_mean": round(sum(tokens) / N, 1),
    "truncated": abgeschnitten,
    "no_answer": ohne_antwort,
    "no_letter_in_top20": kein_buchstabe,
    "request_errors": fehler,
    "max_tokens": MAX_TOKENS,
    "seconds": round(time.time() - t0, 1),
}))

"""Abrufgenauigkeit fuer einen HF-Embedder, ohne llama.cpp.

Warum nicht ueber GGUF wie BGE-M3: Mankei bringt einen eigenen deutschen
Tokenizer mit, dessen Pre-Tokenizer llama.cpp nicht kennt
("BPE pre-tokenizer was not recognized"). Man koennte in get_vocab_base_pre()
einen bekannten eintragen -- raet man falsch, tokenisiert das Modell still
fehlerhaft und die Zahl saehe plausibel und falsch aus. Deshalb direkt ueber
transformers, wo der mitgelieferte Tokenizer benutzt wird.

    python3 eval_embed_hf.py <modellpfad> <kurz|lang> [n] [max_len]
"""
import json, sys, time
import numpy as np, torch
from datasets import load_dataset
from transformers import AutoModel, AutoTokenizer

PFAD, VAR = sys.argv[1], sys.argv[2]
POS = sys.argv[5] if len(sys.argv) > 5 else "ende"
N = int(sys.argv[3]) if len(sys.argv) > 3 else 80
MAXLEN = int(sys.argv[4]) if len(sys.argv) > 4 else 256

tok = AutoTokenizer.from_pretrained(PFAD)
mdl = AutoModel.from_pretrained(PFAD, dtype=torch.float32).eval()

ds = load_dataset("facebook/belebele", "deu_Latn", split="test")
rows = [r for r in ds if r["question_number"] == 1][:N]
fueller = [r["flores_passage"] for r in ds][:400]

def bauen(i, p):
    if VAR == "kurz":
        return p
    # Auf ~3000 Zeichen auffuellen (unsere echte Chunk-Groesse). Die POSITION der
    # Zielpassage ist eine eigene Variable, weil sie das Ergebnis traegt: ein
    # Modell mit last-token pooling gewichtet das Ende, eines mit Mittelung
    # nicht. Nur ans Ende zu setzen misst die Poolung, nicht das Modell.
    t, k = "", 0
    while len(t) + len(p) < 3000 and k < 60:
        f = fueller[(i * 7 + k) % len(fueller)]
        if f != p: t += f + "\n\n"
        k += 1
    if POS == "anfang": return p + "\n\n" + t
    if POS == "mitte":
        h = len(t) // 2
        return t[:h] + "\n\n" + p + "\n\n" + t[h:]
    return t + p

@torch.no_grad()
def emb(text):
    b = tok(text, return_tensors="pt", truncation=True, max_length=MAXLEN)
    h = mdl(**b).last_hidden_state
    # last-token pooling, wie die Modellkarte es nennt
    v = h[0, -1, :].float().numpy()
    return v / (np.linalg.norm(v) + 1e-9)

t0 = time.time()
chunks = [bauen(i, r["flores_passage"]) for i, r in enumerate(rows)]
# Wie viel wird tatsaechlich abgeschnitten? Das ist die Zahl, um die es geht.
laengen = [len(tok(c)["input_ids"]) for c in chunks]
P = np.stack([emb(c) for c in chunks])
ok = 0
for i, r in enumerate(rows):
    q = emb(r["question"])
    if int(np.argmax(P @ q)) == i: ok += 1
print(json.dumps({
    "model": PFAD.rstrip("/").split("/")[-1], "variante": VAR, "position": POS,
    "correct": ok, "n": N, "accuracy": round(ok/N, 4),
    "max_len": MAXLEN,
    "chunk_tokens_mean": round(sum(laengen)/len(laengen)),
    "chunk_tokens_max": max(laengen),
    "abgeschnitten": sum(1 for l in laengen if l > MAXLEN),
    "seconds": round(time.time()-t0, 1)}))

"""Abrufgenauigkeit, einmal mit kurzen und einmal mit langen Passagen.

Der bestehende Pruefstand nutzt Belebele-Passagen direkt -- die sind kurz genug,
dass eine 256-Token-Grenze gar nicht zubeisst. Fuer die Frage, ob ein Modell mit
kurzer Sequenzlaenge fuer UNSERE Chunks taugt, muss die Passage auf unsere
tatsaechliche Chunk-Groesse gebracht werden (~3000 Zeichen, siehe
ingestion-docx/chunking.py). Die Zielpassage steht dabei am ENDE des Chunks --
das ist der ungünstigste Fall und genau der, den eine Kuerzung zerstoert.

    python3 eval_embed_chunks.py <base_url> <name> <kurz|lang> [n]
"""
import json, sys, time
import httpx, numpy as np
from datasets import load_dataset

BASE, NAME, VAR = sys.argv[1], sys.argv[2], sys.argv[3]
POS = sys.argv[5] if len(sys.argv) > 5 else "ende"
N = int(sys.argv[4]) if len(sys.argv) > 4 else 80
ds = load_dataset("facebook/belebele", "deu_Latn", split="test")
rows = [r for r in ds if r["question_number"] == 1][:N]
fueller = [r["flores_passage"] for r in ds][:400]
cl = httpx.Client(timeout=300.0)

def bauen(i, p):
    if VAR == "kurz":
        return p
    # Auf ~3000 Zeichen auffuellen, Zielpassage ans Ende. Fuellmaterial aus
    # anderen Passagen, deterministisch ueber den Index gewaehlt.
    text = ""
    k = 0
    while len(text) + len(p) < 3000:
        f = fueller[(i * 7 + k) % len(fueller)]
        if f != p:
            text += f + "\n\n"
        k += 1
        if k > 50: break
    # Position als eigene Variable -- siehe Kommentar in eval_embed_hf.py.
    if POS == "anfang": return p + "\n\n" + text
    if POS == "mitte":
        h = len(text) // 2
        return text[:h] + "\n\n" + p + "\n\n" + text[h:]
    return text + p

def emb(t):
    r = cl.post(f"{BASE}/v1/embeddings", json={"model": NAME, "input": t})
    r.raise_for_status()
    return np.array(r.json()["data"][0]["embedding"], dtype=np.float32)

t0 = time.time()
chunks = [bauen(i, r["flores_passage"]) for i, r in enumerate(rows)]
P = np.stack([emb(c) for c in chunks])
P /= np.linalg.norm(P, axis=1, keepdims=True)
ok = 0
for i, r in enumerate(rows):
    q = emb(r["question"]); q /= np.linalg.norm(q)
    if int(np.argmax(P @ q)) == i: ok += 1
print(json.dumps({"model": NAME, "variante": VAR, "position": POS, "correct": ok, "n": N,
                  "accuracy": round(ok/N, 4),
                  "chunk_chars_mean": round(sum(len(c) for c in chunks)/len(chunks)),
                  "seconds": round(time.time()-t0, 1)}))

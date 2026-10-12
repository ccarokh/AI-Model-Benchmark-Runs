#!/usr/bin/env python3
"""Ask a model the archive questions over an OpenAI-compatible endpoint (llama-server).

Three ways for the model to reach the documents -- the variable a single
"local against cloud" number hides:

  context    every document in the prompt (~41k tokens for the default archive)
  retrieval  the k documents most similar to the question (bge-m3 embeddings),
             the way a RAG chat hands over excerpts
  agent      the model fetches for itself with three tools: suche (semantic
             search), liste (filter by type and date) and lies (read documents)

Thinking on/off is the second variable (chat_template_kwargs.enable_thinking).
Greedy, one fresh answer per question. Appends one JSON line per question to
--out and skips questions already answered for the same model/path/thinking.

Usage: run.py --archive DIR --url http://127.0.0.1:18300 --model NAME --path context|retrieval|agent
              [--thinking on|off] [--embed-url http://127.0.0.1:18301] [--k 8] [--out answers.jsonl]
              [--only id,id] [--max-tokens N] [--max-steps 25]
"""
import argparse, hashlib, json, math, os, sys, time, urllib.request

SYSTEM = """Du bist ein sorgfältiger Assistent für die privaten Unterlagen von Katrin Brandt (Leverkusen). Beantworte jede Frage ausschließlich anhand der Dokumente aus ihrem Archiv. Rechne genau; Beträge in Euro mit zwei Nachkommastellen, Datumsangaben als TT.MM.JJJJ. Heute ist der 05.01.2026.

Schließe jede Antwort mit genau diesem Block ab:
ERGEBNIS:
- <eine Zeile pro Posten, der zur Antwort gehört, mit seiner Bezeichnung oder Nummer – nur Posten, die mitzählen>
SUMME: <Betrag in Euro, falls nach einem Betrag gefragt ist; 0,00 €, wenn kein Posten zutrifft>

Bei einer Frage nach einem einzelnen Wert steht dieser Wert als einzige Zeile im Block. Steht die gesuchte Information nicht im Archiv, schreibe nur: ERGEBNIS: NICHT IM ARCHIV"""


def post(url, body, timeout=3600):
    req = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=timeout))


def render(d):
    return f"### Dokument {d['id']} · {d['date']} · {d['title']}\n{d['text']}"


class Index:
    """Document-level dense retrieval; documents are short (max ~2.4k characters)."""

    def __init__(self, docs, url, cache_dir):
        self.docs, self.url = docs, url
        h = hashlib.sha1("".join(d["id"] + d["text"] for d in docs).encode()).hexdigest()[:12]
        cache = os.path.join(cache_dir, f"embeddings-{h}.json")
        if os.path.exists(cache):
            self.vec = json.load(open(cache))
        else:
            self.vec = []
            for i in range(0, len(docs), 16):
                batch = [d["title"] + "\n" + d["text"] for d in docs[i:i + 16]]
                self.vec += [self.unit(e["embedding"]) for e in post(url + "/v1/embeddings", {"input": batch})["data"]]
            json.dump(self.vec, open(cache, "w"))

    @staticmethod
    def unit(v):
        n = math.sqrt(sum(x * x for x in v)) or 1.0
        return [x / n for x in v]

    def search(self, query, k):
        q = self.unit(post(self.url + "/v1/embeddings", {"input": [query]})["data"][0]["embedding"])
        s = sorted(((sum(a * b for a, b in zip(q, v)), i) for i, v in enumerate(self.vec)), reverse=True)
        return [self.docs[i] for _, i in s[:k]]


TOOLS = [
    {"type": "function", "function": {"name": "suche", "description": "Semantische Suche im Archiv. Liefert die passendsten Dokumente mit Id, Datum, Titel und Anfang des Texts.",
     "parameters": {"type": "object", "properties": {"anfrage": {"type": "string"}, "anzahl": {"type": "integer", "description": "1 bis 20, Standard 8"}}, "required": ["anfrage"]}}},
    {"type": "function", "function": {"name": "liste", "description": "Listet Dokumente (Id, Datum, Titel), gefiltert nach Typ und/oder Zeitraum. Typen: rechnung_aus, rechnung_ein, kontoauszug, angebot, vertrag, protokoll, abrechnung, gutschrift, brief, email.",
     "parameters": {"type": "object", "properties": {"typ": {"type": "string"}, "von": {"type": "string", "description": "JJJJ-MM-TT"}, "bis": {"type": "string", "description": "JJJJ-MM-TT"}, "titel_enthaelt": {"type": "string"}}}}},
    {"type": "function", "function": {"name": "lies", "description": "Liefert den vollständigen Text von bis zu 10 Dokumenten.",
     "parameters": {"type": "object", "properties": {"ids": {"type": "array", "items": {"type": "string"}}}, "required": ["ids"]}}},
]


def tool(name, args, docs, index):
    byid = {d["id"]: d for d in docs}
    if name == "suche":
        hits = index.search(args.get("anfrage", ""), max(1, min(20, int(args.get("anzahl") or 8))))
        return "\n".join(f"{d['id']} · {d['date']} · {d['title']} · {d['text'][:160].replace(chr(10), ' ')}" for d in hits)
    if name == "liste":
        sel = [d for d in docs if (not args.get("typ") or d["type"] == args["typ"]) and (not args.get("von") or d["date"] >= args["von"])
               and (not args.get("bis") or d["date"] <= args["bis"]) and (not args.get("titel_enthaelt") or args["titel_enthaelt"].lower() in d["title"].lower())]
        return "\n".join(f"{d['id']} · {d['date']} · {d['title']}" for d in sel[:200]) + ("\n(gekürzt auf 200)" if len(sel) > 200 else "") or "keine Treffer"
    if name == "lies":
        return "\n".join(render(byid[i]) if i in byid else f"### {i}: gibt es nicht" for i in (args.get("ids") or [])[:10])
    return f"unbekanntes Werkzeug {name}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", required=True); ap.add_argument("--url", required=True); ap.add_argument("--model", required=True)
    ap.add_argument("--path", choices=["context", "retrieval", "agent"], required=True); ap.add_argument("--thinking", choices=["on", "off"], default="off")
    ap.add_argument("--embed-url"); ap.add_argument("--k", type=int, default=8); ap.add_argument("--out", default="answers.jsonl")
    ap.add_argument("--only"); ap.add_argument("--max-tokens", type=int); ap.add_argument("--max-steps", type=int, default=25)
    a = ap.parse_args()
    docs = [json.loads(l) for l in open(os.path.join(a.archive, "archive.jsonl"))]
    qs = [json.loads(l) for l in open(os.path.join(a.archive, "questions.jsonl"))]
    if a.only:
        qs = [q for q in qs if q["id"] in a.only.split(",")]
    done = set()
    if os.path.exists(a.out):
        for l in open(a.out):
            r = json.loads(l)
            if (r["model"], r["path"], r["thinking"]) == (a.model, a.path, a.thinking) and not r.get("error"):
                done.add(r["qid"])
    index = Index(docs, a.embed_url, os.path.dirname(os.path.abspath(a.out))) if a.path != "context" else None
    max_tokens = a.max_tokens or (16384 if a.thinking == "on" else 4096)
    base = {"temperature": 0, "seed": 1, "max_tokens": max_tokens, "chat_template_kwargs": {"enable_thinking": a.thinking == "on"}}
    full = "\n".join(render(d) for d in docs)
    for q in qs:
        if q["id"] in done:
            continue
        t0, usage, calls, err, answer = time.time(), {"prompt_tokens": 0, "completion_tokens": 0}, 0, None, ""
        try:
            if a.path == "context":
                msgs = [{"role": "system", "content": SYSTEM + "\n\nDas Archiv:\n\n" + full}, {"role": "user", "content": q["question"]}]
            elif a.path == "retrieval":
                ctx = "\n".join(render(d) for d in index.search(q["question"], a.k))
                msgs = [{"role": "system", "content": SYSTEM + "\n\nDie zur Frage gefundenen Dokumente aus dem Archiv:\n\n" + ctx}, {"role": "user", "content": q["question"]}]
            else:
                msgs = [{"role": "system", "content": SYSTEM + "\n\nDu kommst über die Werkzeuge suche, liste und lies an die Dokumente. Hole dir alles, was du brauchst, bevor du antwortest."},
                        {"role": "user", "content": q["question"]}]
            for step in range(a.max_steps if a.path == "agent" else 1):
                body = dict(base, messages=msgs)
                if a.path == "agent":
                    body["tools"] = TOOLS
                    if step == a.max_steps - 1:
                        body["tool_choice"] = "none"
                r = post(a.url + "/v1/chat/completions", body)
                for k in usage:
                    usage[k] += (r.get("usage") or {}).get(k, 0)
                m = r["choices"][0]["message"]
                tcs = m.get("tool_calls") or []
                if a.path != "agent" or not tcs:
                    answer = m.get("content") or ""
                    break
                msgs.append({"role": "assistant", "content": m.get("content") or "", "tool_calls": tcs})
                for tc in tcs:
                    calls += 1
                    try:
                        args = json.loads(tc["function"].get("arguments") or "{}")
                    except json.JSONDecodeError:
                        args = {}
                    msgs.append({"role": "tool", "tool_call_id": tc.get("id", ""), "content": tool(tc["function"]["name"], args, docs, index)})
        except Exception as e:
            body = e.read().decode(errors="replace")[:300] if hasattr(e, "read") else ""
            err = (str(e) + " " + body)[:500]
        row = {"model": a.model, "path": a.path, "thinking": a.thinking, "qid": q["id"], "answer": answer, "seconds": round(time.time() - t0, 1),
               "prompt_tokens": usage["prompt_tokens"], "completion_tokens": usage["completion_tokens"], "tool_calls": calls, "error": err,
               "date": time.strftime("%F")}
        with open(a.out, "a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        print(f"  {a.model} {a.path} {a.thinking} {q['id']:22} {row['seconds']:7.1f} s  {usage['completion_tokens']:6} tok  {calls:2} tools"
              + (f"  FEHLER {err[:120]}" if err else ""), flush=True)
    print("FERTIG_DOCARCHIVE")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Score the answers of run.py against questions.jsonl -- computed, never judged.

Every answer has to end in a block

    ERGEBNIS:
    - <one line per item, naming it: subscription, invoice number, company ...>
    SUMME: <amount>

or `ERGEBNIS: NICHT IM ARCHIV`. Two readings of every answer:

  strict   only the block counts; no block = format failure
  lenient  as strict when there is a block; without one the whole answer is
           searched -- separates "could not follow the format" from "did not
           find it", the lesson of the aider runs. (Searching the whole answer
           even when a block exists counts items the model names in its
           reasoning only to exclude them.)

reconcile  solved = exactly the expected items named (none missing, none extra)
           and, where a total is asked, the total right to the cent.
           Item recall and precision are reported as well.
lookup     the expected value (amount, date TT.MM.JJJJ or text) stands in the block
absent     the block says NICHT IM ARCHIV and nothing else is claimed

Usage: score.py <questions.jsonl> <answers.jsonl> [--tsv-runs F] [--tsv-questions F]
"""
import collections, datetime as dt, json, re, sys

NOT_THERE = "nicht im archiv"


def norm(s):
    return re.sub(r"\s+", " ", s.lower().replace(" ", " ")).strip()


def amounts(s):
    out = []
    for m in re.finditer(r"(?<![\d,.])(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?(?![\d])", s):
        whole = m.group(1).replace(".", "")
        out.append(float(whole + "." + (m.group(2) or "0")))
    return out


def block(answer):
    i = answer.upper().rfind("ERGEBNIS")
    return answer[i:] if i >= 0 else None


def total_of(text):
    m = None
    for m in re.finditer(r"SUMME\s*:?\s*([^\n]*)", text, re.I):
        pass
    if not m:
        return None
    a = amounts(m.group(1))
    return a[0] if a else (0.0 if re.search(r"\b(keine|null)\b", m.group(1), re.I) else None)


def score_one(q, text):
    t = norm(text)
    says_absent = NOT_THERE in t
    if q["kind"] == "absent":
        return {"solved": says_absent}
    if says_absent:
        return {"solved": False, "recall": 0.0, "precision": 0.0} if q["kind"] == "reconcile" else {"solved": False}
    if q["kind"] == "lookup":
        v = q["value"]
        if q["value_kind"] == "amount":
            ok = any(abs(a - v) < 0.005 for a in amounts(text))
        elif q["value_kind"] == "date":
            d = dt.date.fromisoformat(v)
            ok = any(x in text for x in (d.strftime("%d.%m.%Y"), f"{d.day}.{d.month}.{d.year}"))
        else:
            ok = norm(v) in t
        return {"solved": ok}
    found = {u for u in q["universe"] if norm(u) in t}
    exp = set(q["items"])
    hit = len(found & exp)
    rec = hit / len(exp) if exp else (1.0 if not found else 0.0)
    prec = hit / len(found) if found else (1.0 if not exp else 0.0)
    tot = total_of(text)
    tot_ok = q["total"] is None or (tot is not None and abs(tot - q["total"]) < 0.005)
    return {"solved": found == exp and tot_ok, "recall": rec, "precision": prec, "total_ok": tot_ok, "total": tot}


def main():
    Q = {q["id"]: q for q in map(json.loads, open(sys.argv[1]))}
    ans = [json.loads(l) for l in open(sys.argv[2])]
    arg = lambda k: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else None
    runs = collections.OrderedDict()
    rows = []
    for a in ans:
        q = Q[a["qid"]]
        key = (a["model"], a["path"], a["thinking"])
        r = runs.setdefault(key, collections.Counter())
        text = a.get("answer") or ""
        b = block(text)
        strict = score_one(q, b) if b else {"solved": False, "recall": 0.0, "precision": 0.0}
        lenient = strict if b else score_one(q, text)
        r["n"] += 1
        r[q["kind"] + "_n"] += 1
        r[q["kind"] + "_strict"] += strict["solved"]
        r[q["kind"] + "_lenient"] += lenient["solved"]
        r["format_failures"] += b is None
        r["errors"] += bool(a.get("error"))
        r["seconds"] += a.get("seconds", 0)
        r["completion_tokens"] += a.get("completion_tokens") or 0
        r["tool_calls"] += a.get("tool_calls") or 0
        r["step_limit"] += bool(a.get("step_limit"))
        if q["kind"] == "reconcile":
            r["recall_sum"] += strict.get("recall", 0.0)
            r["precision_sum"] += strict.get("precision", 0.0)
        rows.append([*key, q["id"], q["kind"], int(strict["solved"]), int(lenient["solved"]), int(b is None),
                     f"{strict.get('recall', ''):.2f}" if "recall" in strict else "", a.get("seconds", ""), a.get("completion_tokens", "")])
    head = ["model", "path", "thinking", "n", "reconcile_solved", "reconcile_n", "reconcile_lenient", "item_recall", "item_precision",
            "lookup_solved", "lookup_n", "absent_solved", "absent_n", "format_failures", "errors", "step_limit", "seconds", "completion_tokens", "tool_calls"]
    out = ["\t".join(head)]
    for key, r in runs.items():
        rn = r["reconcile_n"] or 1
        out.append("\t".join(map(str, [*key, r["n"], r["reconcile_strict"], r["reconcile_n"], r["reconcile_lenient"],
                                       f"{r['recall_sum'] / rn:.3f}", f"{r['precision_sum'] / rn:.3f}", r["lookup_strict"], r["lookup_n"],
                                       r["absent_strict"], r["absent_n"], r["format_failures"], r["errors"], r["step_limit"], round(r["seconds"]),
                                       r["completion_tokens"], r["tool_calls"]])))
    print("\n".join(out))
    if arg("--tsv-runs"):
        open(arg("--tsv-runs"), "w").write("\n".join(out) + "\n")
    if arg("--tsv-questions"):
        with open(arg("--tsv-questions"), "w") as f:
            f.write("model\tpath\tthinking\tqid\tkind\tsolved\tsolved_lenient\tformat_failure\titem_recall\tseconds\tcompletion_tokens\n")
            for row in rows:
                f.write("\t".join(map(str, row)) + "\n")


if __name__ == "__main__":
    main()

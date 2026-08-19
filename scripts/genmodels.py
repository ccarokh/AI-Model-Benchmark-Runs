"""Erzeugt models/<modell>.md aus den Datendateien.

Bewusst datengetrieben: jede Zeile stammt aus einer TSV, nichts aus dem
Gedaechtnis. Die Prosa-Abschnitte stehen in NOTIZEN und werden angehaengt --
was nicht dort steht, bekommt keine Behauptung, nur Zahlen.
"""
import csv, glob, os, re, collections, json

# Aliase: dieselbe Sache unter verschiedenen Namen in verschiedenen Dateien.
ALIAS = {
    "gemma4-12b": "gemma-4-12b", "gemma4-e4b": "gemma-4-e4b",
    "qwen35-2b": "qwen3.5-2b", "qwen35-4b": "qwen3.5-4b",
    "qwen3.8-27b-abl": "qwen3.8-27b-abliterated",
    "bgem3_baseline": "bge-m3",
    "nanbeige-4.2-3b-q4_k_m": "nanbeige-4.2-3b",
    "llama-3.2-3b-instruct-q4_k_m": "llama-3.2-3b",
}
# Zeilen, die keine Modelle sind
KEIN_MODELL = re.compile(r"^(#|GOLD-PATCH$|cuda_|cpu_)")

QUELLE = {
 "chat_belebele": ("German comprehension — belebele, answer read from the first token's probability", "../use-cases/language-understanding.md"),
 "chat_belebele_harness": ("German comprehension across three harnesses — one variable between each pair", "../findings/harness-effect.md"),
 "chat_belebele_chattemplate": ("German comprehension — prompt formatted by the chat template inside the GGUF, not by a HuggingFace tokenizer", "../findings/harness-effect.md"),
 "chat_belebele_reasoning": ("German comprehension — model answers freely, the letter is extracted from the text", "../findings/harness-effect.md"),
 "coding_polyglot": ("aider-polyglot, 225 tasks", "../use-cases/coding.md"),
 "coding_swebench": ("SWE-bench Verified", "../use-cases/coding.md"),
 "coding_swebench_empty_causes": ("why each empty patch was empty", "../use-cases/coding.md"),
 "coding_real_task": ("one 299-line project spec", "../use-cases/coding.md"),
 "context_depth": ("throughput and energy against cache depth", "../findings/context-depth.md"),
 "energy_tokens": ("tokens per watt-hour", "../hardware/power.md"),
 "abliteration": ("de-refused variant against its base", "../findings/abliteration.md"),
 "embedding_retrieval": ("retrieval accuracy", "../use-cases/embedding.md"),
 "embedding_chunk_position": ("retrieval against answer position", "../findings/chunk-position.md"),
 "embedding_chunk_size": ("retrieval against chunk size", "../findings/chunk-position.md"),
 "image_generation": ("time, VRAM and licence", "../use-cases/image-generation.md"),
 "image_generation_ocr": ("text rendered into the image", "../use-cases/image-generation.md"),
 "image_generation_ab": ("one variable at a time", "../use-cases/image-generation.md"),
 "image_generation_seeds": ("the OCR measures across five seeds", "../use-cases/image-generation.md"),
 "image_generation_energy": ("energy per image", "../use-cases/image-generation.md"),
 "image_generation_verdicts": ("operator judgements, not measurements", "../use-cases/image-generation.md"),
 "integration_cost": ("what it took to get it running", "../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored"),
 "reference_bench": ("foreign benchmark, upstream flags", "../foreign/"),
 "reference_power_socket": ("wall-socket power", "../hardware/power.md"),
 "ollama_vs_llamacpp": ("same model on two runtimes", "../foreign/"),
 "throughput_looped_transformer": ("llama-bench, looped vs dense", "../findings/harness-effect.md"),
}

daten = collections.defaultdict(lambda: collections.defaultdict(list))
kopf = {}
for f in sorted(glob.glob("data/*.tsv")):
    name = os.path.basename(f)[:-4]
    with open(f) as fh:
        r = csv.DictReader(fh, delimiter="\t")
        if not r.fieldnames or r.fieldnames[0] not in ("model","slug"): continue
        kopf[name] = r.fieldnames
        sp = r.fieldnames[0]
        for row in r:
            m = (row.get(sp) or "").strip()
            if not m or KEIN_MODELL.match(m): continue
                # -nothink, -slot32k and -x8 are run configurations of the same
            # model, not different models. Without folding them, every
            # configuration would get a file of its own.
            basis = re.sub(r"-nothink.*$|-slot32k.*$|-x8$", "", m)
            basis = ALIAS.get(basis, basis)
            daten[basis][name].append(row)

os.makedirs("models", exist_ok=True)
NOTIZEN = json.load(open("scripts/model_notes.json"))
erzeugt = []
for m in sorted(daten):
    slug = m.replace("/", "-")
    z = ["# %s\n" % m,
         "Everything measured about this model here. **Blank means never measured, not \"failed\".**\n",
         "Numbers link back to the document that interprets them; the raw rows are in\n[`data/`](../data/).\n"]
    n = NOTIZEN.get(m)
    if n: z.append(n.rstrip() + "\n")
    for q in sorted(daten[m]):
        titel, link = QUELLE.get(q, (q, "../data/"))
        z.append("## %s\n" % titel)
        z.append("Source: [`%s.tsv`](../data/%s.tsv) · interpreted in [%s](%s)\n" %
                 (q, q, os.path.basename(link).replace(".md","").replace("#"," §"), link))
        sp = kopf[q]
        z.append("| " + " | ".join(sp) + " |")
        z.append("|" + "---|" * len(sp))
        for row in daten[m][q]:
            z.append("| " + " | ".join((row.get(c) or "").strip() or "—" for c in sp) + " |")
        z.append("")
    open("models/%s.md" % slug, "w").write("\n".join(z))
    erzeugt.append((slug, sum(len(v) for v in daten[m].values()), len(daten[m])))
print("%d Modelldateien" % len(erzeugt))
for s, zeilen, dateien in sorted(erzeugt, key=lambda x: -x[2])[:8]:
    print("  %-30s %2d Quellen, %3d Zeilen" % (s, dateien, zeilen))

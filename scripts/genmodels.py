"""Generates models/<model>.md — one file per model, organised by topic.

Two decisions worth knowing about:

**Grouped by topic, not by data file.** A reader asking "how is this model at
coding" wants one section, not three files named after harnesses. Several TSVs
can feed one section.

**Every topic appears in every file, including the empty ones.** A model with no
vision row still gets a Vision heading saying so. Otherwise a gap is invisible
and looks like an answer — the whole point of the per-model view is seeing what
has *not* been measured.
"""
import csv, glob, json, os, re, collections

# Same model under different spellings across files.
ALIAS = {
    "gemma4-12b": "gemma-4-12b", "gemma4-e4b": "gemma-4-e4b",
    "qwen35-2b": "qwen3.5-2b", "qwen35-4b": "qwen3.5-4b",
    "qwen3.8-27b-abl": "qwen3.8-27b-abliterated",
    "bgem3_baseline": "bge-m3",
    "nanbeige-4.2-3b-q4_k_m": "nanbeige-4.2-3b",
    "llama-3.2-3b-instruct-q4_k_m": "llama-3.2-3b",
}
NOT_A_MODEL = re.compile(r"^(#|GOLD-PATCH$|cuda_|cpu_)")

# topic key -> (heading, interpreting document, [data files])
TOPICS = [
 ("chat", "Language understanding — German chat", "../use-cases/language-understanding.md",
  ["chat_belebele", "chat_belebele_harness", "chat_belebele_chattemplate",
   "chat_belebele_reasoning", "abliteration"]),
 ("coding", "Coding", "../use-cases/coding.md",
  ["coding_polyglot", "coding_swebench", "coding_swebench_empty_causes", "coding_real_task"]),
 ("context", "Long context — cost against cache depth", "../findings/context-depth.md",
  ["context_depth"]),
 ("retrieval", "Retrieval — embedding and reranking", "../use-cases/embedding.md",
  ["embedding_retrieval", "embedding_chunk_position", "embedding_chunk_size"]),
 ("vision", "Vision — image input", "../use-cases/vision.md", ["vision"]),
 ("asr", "Speech to text", "../use-cases/transcription.md",
  ["transcription_fasterwhisper"]),
 ("image", "Image generation", "../use-cases/image-generation.md",
  ["image_generation", "image_generation_ocr", "image_generation_ab",
   "image_generation_seeds", "image_generation_energy", "image_generation_verdicts"]),
 ("power", "Power and energy", "../hardware/power.md",
  ["energy_tokens", "power_throttle_low", "reference_power_socket"]),
 ("throughput", "Throughput and runtime", "../foreign/",
  ["reference_bench", "throughput_looped_transformer", "ollama_vs_llamacpp"]),
 ("setup", "What it took to run it", "../METHODOLOGY.md#record-what-it-cost-to-run-the-model-not-only-how-it-scored",
  ["integration_cost"]),
]
# One line per data file, so a table says what it is without leaving the page.
WAS = {
 "chat_belebele": "answer read from the first token's probability",
 "chat_belebele_harness": "three harnesses, one variable between each pair",
 "chat_belebele_chattemplate": "prompt formatted by the chat template inside the GGUF",
 "chat_belebele_reasoning": "model answers freely, the letter extracted from the text",
 "abliteration": "de-refused variant against its own base",
 "coding_polyglot": "aider-polyglot, 225 tasks",
 "coding_swebench": "SWE-bench Verified",
 "coding_swebench_empty_causes": "why each empty patch was empty",
 "coding_real_task": "one 299-line project spec ⚠️ only `status` is fully trustworthy",
 "context_depth": "throughput and energy at four cache depths",
 "embedding_retrieval": "retrieval accuracy, cosine nearest neighbour",
 "embedding_chunk_position": "retrieval against where the answer sits in the chunk",
 "embedding_chunk_size": "retrieval against chunk size",
 "transcription_fasterwhisper": "one 63.72 s clip",
 "image_generation": "time, VRAM and licence",
 "image_generation_ocr": "text rendered into the image",
 "image_generation_ab": "one variable at a time",
 "image_generation_seeds": "the OCR measures across five seeds",
 "image_generation_energy": "energy per image",
 "image_generation_verdicts": "⚠️ operator judgements, not measurements",
 "energy_tokens": "tokens per watt-hour, prefill and generation separately",
 "power_throttle_low": "the throttle curve",
 "reference_power_socket": "wall-socket power",
 "reference_bench": "foreign benchmark, upstream flags",
 "throughput_looped_transformer": "llama-bench, looped against dense",
 "ollama_vs_llamacpp": "the same model on two runtimes",
 "integration_cost": "shipped format, steps needed, blockers hit",
 "vision": "memory and behaviour with a vision projector loaded",
}

rows = collections.defaultdict(lambda: collections.defaultdict(list))
header = {}
for f in sorted(glob.glob("data/*.tsv")):
    name = os.path.basename(f)[:-4]
    with open(f) as fh:
        r = csv.DictReader(fh, delimiter="\t")
        if not r.fieldnames or r.fieldnames[0] not in ("model", "slug"):
            continue
        header[name] = r.fieldnames
        key = r.fieldnames[0]
        for row in r:
            m = (row.get(key) or "").strip()
            if not m or NOT_A_MODEL.match(m):
                continue
            # -nothink, -slot32k and -x8 are run configurations of the same model,
            # not different models. Without folding them, every configuration
            # would get a file of its own.
            base = re.sub(r"-nothink.*$|-slot32k.*$|-x8$", "", m)
            base = ALIAS.get(base, base)
            rows[base][name].append(row)

notes = json.load(open("scripts/model_notes.json"))
os.makedirs("models", exist_ok=True)
made = 0
for m in sorted(rows):
    out = ["# %s\n" % m,
           "Everything measured about this model, by topic. **Every topic is listed, "
           "including the ones with no measurement** — a gap you cannot see looks like "
           "an answer.\n",
           "Generated from [`data/`](../data/) by "
           "[`scripts/genmodels.py`](../scripts/genmodels.py); every number traces to a "
           "row there.\n"]
    n = notes.get(m)
    if n:
        out.append(n.rstrip() + "\n")
    covered = 0
    for _, heading, doc, files in TOPICS:
        present = [f for f in files if rows[m].get(f)]
        out.append("## %s\n" % heading)
        if not present:
            out.append("Not measured. Interpreted in [%s](%s) where it is.\n" %
                       (os.path.basename(doc.rstrip('/')).replace('.md', '') or 'foreign', doc))
            continue
        covered += 1
        out.append("Interpreted in [%s](%s).\n" %
                   (os.path.basename(doc.rstrip('/')).replace('.md', '') or 'foreign', doc))
        for f in present:
            cols = header[f]
            out.append("**[`%s.tsv`](../data/%s.tsv)** — %s\n" % (f, f, WAS.get(f, "")))
            out.append("| " + " | ".join(cols) + " |")
            out.append("|" + "---|" * len(cols))
            for row in rows[m][f]:
                out.append("| " + " | ".join((row.get(c) or "").strip() or "—" for c in cols) + " |")
            out.append("")
    out.insert(3, "**Measured in %d of %d topics.**\n" % (covered, len(TOPICS)))
    open("models/%s.md" % m.replace("/", "-"), "w").write("\n".join(out))
    made += 1
print("%d model files" % made)

"""Speed that changes the answer is not speed."""
NAME = "speculative"
DESCRIPTION = "Speculative decoding: what it gains, and whether the wording survives"

from harness import card_is_idle, common_prefix, server_probe

# Every generation figure in this repository so far is bandwidth-bound: one
# token, one pass over the weights, and the card's memory bandwidth sets the
# ceiling. Speculative decoding is the one lever that beats that ceiling without
# changing the hardware -- several tokens are guessed and then verified in a
# single pass.
#
# It has a price that a throughput number cannot show. A first probe on System C
# measured 2.88x on a 12B model -- and a different answer to the same prompt at
# temperature 0. Three runs each confirmed both: the same configuration is
# reproducible, and the fast ones do not agree with the unspeculated model. That
# is the whole reason this test exists, and it is why every variant here is
# measured on TWO axes: tokens per second AND the wording.
#
# The wording is compared against this machine's own unspeculated run of the
# same model and the same prompt, never against a figure from elsewhere.
PROMPTS = {
    # Two workloads, because the ngram variants draft from the text that is
    # already there: they win on repetitive output and do nothing on prose.
    # Measuring only one of them would answer a different question than the one
    # asked, and would answer it as if it were general.
    "prose": "Erklaere in mehreren Absaetzen, warum ein Grafikprozessor fuer "
             "Sprachmodelle schneller ist als ein Hauptprozessor.",
    "code": "Schreibe eine Python-Funktion, die eine Liste von Zahlen einliest "
            "und die Summe der Quadrate zurueckgibt. Danach erklaere Schritt "
            "fuer Schritt, was sie tut.",
}

# No draft model needed -- these draft from the text they have already produced,
# so they cost no VRAM and work with every model on the machine.
NO_DRAFTER = ["ngram-simple", "ngram-mod", "ngram-map-k"]

# The threshold that decides how much of a draft is taken on trust. It is NOT
# monotone: on the first probe 0.9 reproduced the unspeculated wording exactly
# while 0.99 did not, three runs each. A parameter that behaves like that gets
# swept, not guessed.
P_MIN = ["0.0", "0.5", "0.9", "0.99"]

# Anything this small is a candidate draft model. Which of them can actually
# draft for which target is not decided here from names -- it is tried, and the
# server's refusal is recorded as the answer. Pairing by filename is how a
# vocabulary mismatch ends up filed as a measurement.
DRAFTER_MAX_GIB = 2.5
N_PREDICT = 256
CTX = 8192
# Sweeping p-min on a pairing that gains nothing burns a night on four ways of
# being no faster. The cut is written into the coverage row, not left silent.
SWEEP_IF_FACTOR_ABOVE = 1.1


def _record(ctx, build, key, probe, baseline, factor_note=""):
    """One variant's rows: the rate, and whether the answer survived."""
    b = ctx.results
    if not probe["ok"]:
        b.add(NAME, "", build.backend, build.version, key, "failed", "",
              probe["reason"])
        return None
    # A DRAFT THAT NEVER RAN IS NOT A SLOW DRAFT. The first run of this test
    # paired an embedding model as a drafter with a 12B target; llama-server
    # took the flag, quietly did not speculate, and the row came back as
    # "1.00x, wording identical" -- a pairing that cannot work, filed as a
    # measurement that it does not pay. The acceptance line is the proof that
    # speculation actually happened, and its absence is now the finding.
    engaged = probe["acceptance"] is not None
    note = f"acceptance {probe['acceptance']:.3f}" if engaged else ""
    if not engaged and key.rsplit(":", 1)[-1] != "none":
        note = "speculation did not engage -- the server took the flag and drafted nothing"
        factor_note = ""
    if factor_note:
        note = f"{factor_note}{'; ' + note if note else ''}"
    b.add(NAME, "", build.backend, build.version, f"{key}:tg",
          f"{probe['tg']:.2f}", "tokens/s", note)
    if baseline is None or not engaged and key.rsplit(":", 1)[-1] != "none":
        return probe if engaged else None
    same = probe["hash"] == baseline["hash"]
    where = common_prefix(baseline["text"], probe["text"])
    b.add(NAME, "", build.backend, build.version, f"{key}:wording",
          "identical" if same else "differs", "",
          f"hash {probe['hash']} vs baseline {baseline['hash']}"
          + ("" if same else f", diverges at character {where} of {len(baseline['text'])}"))
    return probe


def run(ctx):
    done = total = 0
    # Drafters are looked for in the model store itself, not in ctx.models. The
    # night chain deliberately keeps the MTP files out of the model list so the
    # other tests do not try to benchmark a draft head as if it were a model --
    # and that is exactly the file this test needs. Taking the list as given
    # would have left the one interesting pairing unmeasured, silently.
    roots = {m.parent.parent for m in ctx.models}
    found = sorted({f for r in roots for f in r.rglob("*.gguf")
                    if "mmproj" not in f.name.lower()})
    drafters = [f for f in found if f.stat().st_size / 1024 ** 3 <= DRAFTER_MAX_GIB]
    targets = [m for m in ctx.models if m not in drafters]
    skipped_sweeps = 0
    ctx.say(f"  {len(targets)} models, {len(drafters)} draft candidates: "
            + ", ".join(d.stem for d in drafters))

    for build in ctx.builds:
        # Not every build has one. The CUDA build on System C was configured
        # without the server, and the first run of this test died on a
        # FileNotFoundError halfway through the matrix -- taking the vulkan
        # results that were already on disk with it as far as the summary was
        # concerned.
        if not (build.bin / "llama-server").exists():
            ctx.skip_permanently(NAME, f"{build.backend} build has no llama-server",
                                 backend=build.backend, build=build.version)
            continue
        for model in targets:
            for prompt_id, prompt in PROMPTS.items():
                stem = f"{model.stem}:{prompt_id}"
                variants = [("none", [])]
                variants += [(v, ["--spec-type", v]) for v in NO_DRAFTER]
                for d in drafters:
                    kind = "draft-mtp" if "mtp" in d.stem.lower() else "draft-simple"
                    variants.append((f"{kind}+{d.stem}",
                                     ["--spec-type", kind, "-md", str(d), "-ngld", "99"]))
                total += len(variants)

                # The baseline is the yardstick for every other variant in this
                # block. It is measured first, and read back from the file when
                # a previous run already made it -- comparing against a missing
                # baseline would report every variant as identical.
                base_key = f"{stem}:none"
                baseline = None
                if ctx.results.has_prefix(NAME, "", build.backend, build.version, base_key):
                    done += 1
                    stored = ctx.results.value_of(NAME, "", build.backend, build.version,
                                                  f"{base_key}:hash")
                    if stored:
                        baseline = {"hash": stored, "text": "", "tg": None}
                else:
                    if ctx.out_of_budget():
                        return
                    if not card_is_idle(ctx):
                        ctx.defer(NAME, f"card busy before {stem}")
                        continue
                    probe = server_probe(build, model, prompt,
                                         n_predict=N_PREDICT, ctx_size=CTX)
                    _record(ctx, build, base_key, probe, None)
                    if not probe["ok"]:
                        ctx.say(f"  {build.backend} {stem}: no baseline -- {probe['reason']}")
                        continue
                    # The hash gets its own row so a later run can compare
                    # against it without re-measuring the baseline.
                    ctx.results.add(NAME, "", build.backend, build.version,
                                    f"{base_key}:hash", probe["hash"], "",
                                    f"{N_PREDICT} tokens at temperature 0")
                    baseline = probe
                    done += 1
                    ctx.say(f"  {build.backend} {stem} baseline: {probe['tg']:.2f} t/s")

                if baseline is None:
                    continue
                base_tg = baseline.get("tg")

                for name, args in variants[1:]:
                    key = f"{stem}:{name}"
                    if ctx.results.has_prefix(NAME, "", build.backend, build.version, key):
                        done += 1
                        continue
                    if ctx.out_of_budget():
                        return
                    if not card_is_idle(ctx):
                        ctx.defer(NAME, f"card busy before {key}")
                        continue
                    probe = server_probe(build, model, prompt, *args,
                                         n_predict=N_PREDICT, ctx_size=CTX)
                    factor = ""
                    if probe["ok"] and base_tg:
                        factor = f"{probe['tg'] / base_tg:.2f}x baseline"
                    _record(ctx, build, key, probe, baseline, factor)
                    done += 1
                    if probe["ok"] and probe["acceptance"] is None:
                        ctx.say(f"  {build.backend} {key}: no speculation happened -- "
                                "the flag was accepted and nothing was drafted")
                        continue
                    if probe["ok"]:
                        same = probe["hash"] == baseline["hash"]
                        ctx.say(f"  {build.backend} {key}: {probe['tg']:.2f} t/s "
                                f"{factor} -- wording {'identical' if same else 'DIFFERS'}")
                    else:
                        ctx.say(f"  {build.backend} {key}: did not run -- {probe['reason']}")
                        continue

                    # The threshold sweep, only where there is a gain to explain.
                    if not name.startswith("draft-") or probe["acceptance"] is None:
                        continue
                    if not (base_tg and probe["tg"] / base_tg > SWEEP_IF_FACTOR_ABOVE):
                        skipped_sweeps += 1
                        continue
                    for p in P_MIN:
                        p_key = f"{key}@p{p}"
                        total += 1
                        if ctx.results.has_prefix(NAME, "", build.backend, build.version, p_key):
                            done += 1
                            continue
                        if ctx.out_of_budget():
                            return
                        if not card_is_idle(ctx):
                            ctx.defer(NAME, f"card busy before {p_key}")
                            continue
                        sweep = server_probe(build, model, prompt, *args,
                                             "--spec-draft-p-min", p,
                                             n_predict=N_PREDICT, ctx_size=CTX)
                        f2 = f"{sweep['tg'] / base_tg:.2f}x baseline" if sweep["ok"] else ""
                        _record(ctx, build, p_key, sweep, baseline, f2)
                        done += 1
                        if sweep["ok"]:
                            same = sweep["hash"] == baseline["hash"]
                            ctx.say(f"    p-min {p}: {sweep['tg']:.2f} t/s {f2} -- "
                                    f"wording {'identical' if same else 'DIFFERS'}")

    note = (f"{len(ctx.builds)} builds x {len(targets)} models x {len(PROMPTS)} prompts "
            f"x {1 + len(NO_DRAFTER) + len(drafters)} variants")
    if skipped_sweeps:
        note += f"; {skipped_sweeps} threshold sweeps not run -- pairing gained under {SWEEP_IF_FACTOR_ABOVE}x"
    ctx.coverage(NAME, done, total, note)

"""Faster is only faster if the answer is the same."""
NAME = "output_equivalence"
DESCRIPTION = "Completion hash per build and model -- do two builds still agree?"

from harness import card_is_idle, output_hash


def run(ctx):
    if len(ctx.builds) < 2:
        ctx.skip_permanently(NAME, "only one build on this machine -- nothing to compare")
        return
    # Every model. "Two are enough, this asks whether the builds agree" was a
    # guess about where a disagreement would show -- and a disagreement that
    # only appears on the third model is exactly the one worth catching.
    done = total = 0
    for model in ctx.models:
        total += 1
        digests = {}
        for build in ctx.builds:
            key = ctx.results.key(NAME, "", build.backend, build.version, model.stem)
            if ctx.results.has(key) or ctx.out_of_budget():
                continue
            if not card_is_idle(ctx):
                ctx.defer(NAME, "card busy")
                continue
            digest, note = output_hash(build, model)
            ctx.results.add(NAME, "", build.backend, build.version, model.stem,
                            digest or "", "sha256:16", note)
            ctx.say(f"  {build.backend} {build.version} {model.stem}: {digest or note}")
            if digest:
                digests[str(build)] = digest
        # The comparison itself is a row, so a disagreement is findable without
        # reading a log: a build that answers differently has not got faster at
        # the same work.
        if len(digests) > 1:
            done += 1
            agree = len(set(digests.values())) == 1
            ctx.results.add(NAME, "", "all", "", f"{model.stem}:agreement",
                            "yes" if agree else "NO", "",
                            "; ".join(f"{k}={v}" for k, v in digests.items()))
    ctx.coverage(NAME, done, total, f"{len(ctx.builds)} builds compared per model")

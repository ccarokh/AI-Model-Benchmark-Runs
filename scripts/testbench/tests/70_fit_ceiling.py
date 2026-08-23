"""Where it stops fitting -- found by trying, not by asserting."""
NAME = "fit_ceiling"
DESCRIPTION = "Largest context that still runs, per model and KV cache, by bisection"

from harness import WattSampler, bench_probe, card_is_idle

# A fixed list of depths answers "does 65 536 fit" and stops there. The question
# is the other one: WHERE does it stop. So this grows until something breaks and
# then halves the gap -- the last depth that ran and the first that did not are
# both recorded, with the reason the failing one gave.
FIRST = 8192          # first probe; below this nothing interesting happens
GRANULARITY = 4096    # stop bisecting when the gap is this small
CEILING = 1_048_576   # a stop for models that never fail: 1M tokens is not a real workload
PROBE = ("-p", "64", "-n", "16", "-r", "1", "-ngl", "99")


def _state(ctx, build, model, cache, depth):
    """What is already known about this exact probe, from an earlier run."""
    base = f"{model.stem}:{cache}:d{depth}"
    for outcome in ("ok", "fail"):
        if ctx.results.has(ctx.results.key(NAME, "", build.backend, build.version,
                                           f"{base}:{outcome}")):
            return outcome
    return None


def _probe(ctx, build, model, cache, depth):
    known = _state(ctx, build, model, cache, depth)
    if known:
        return known == "ok"
    if not card_is_idle(ctx):
        raise RuntimeError("card busy")
    with WattSampler(ctx.power) as sampler:
        ok, reason = bench_probe(build, model, *PROBE, "-d", str(depth),
                                 "-fa", "on", "-ctk", cache, "-ctv", cache)
    ctx.results.add(NAME, "", build.backend, build.version,
                    f"{model.stem}:{cache}:d{depth}:{'ok' if ok else 'fail'}",
                    str(sampler.peak_vram or 0) if ok else "",
                    "MiB peak" if ok else "", reason)
    ctx.say(f"  {model.stem} {cache} d{depth}: {'runs' if ok else 'FAILS -- ' + reason}")
    return ok


def run(ctx):
    build = ctx.builds[0]
    for model in ctx.models[:2]:
        for cache in ("f16", "q8_0"):
            if ctx.results.has_prefix(NAME, "", build.backend, build.version,
                                      f"{model.stem}:{cache}:ceiling"):
                continue
            if ctx.out_of_budget():
                return
            try:
                # Grow first: doubling reaches the neighbourhood of the ceiling
                # in a handful of probes, where a linear walk would spend the
                # whole budget in the region that was never in question.
                good, bad = 0, None
                depth = FIRST
                while depth <= CEILING:
                    if _probe(ctx, build, model, cache, depth):
                        good = depth
                        depth *= 2
                    else:
                        bad = depth
                        break
                if bad is None:
                    ctx.results.add(NAME, "", build.backend, build.version,
                                    f"{model.stem}:{cache}:ceiling", str(good), "tokens",
                                    f"never failed up to {CEILING} -- stopped there, not a limit of the card")
                    ctx.say(f"  {model.stem} {cache}: no ceiling found below {CEILING}")
                    continue
                # Then halve: the gap between what ran and what did not is the
                # answer, and it is only worth narrowing to something a person
                # would actually configure.
                while bad - good > GRANULARITY:
                    middle = (good + bad) // 2
                    if _probe(ctx, build, model, cache, middle):
                        good = middle
                    else:
                        bad = middle
                ctx.results.add(NAME, "", build.backend, build.version,
                                f"{model.stem}:{cache}:ceiling", str(good), "tokens",
                                f"first failure at {bad}")
                ctx.say(f"  {model.stem} {cache}: CEILING {good} tokens "
                        f"(first failure at {bad})")
            except RuntimeError as e:
                ctx.defer(NAME, f"{model.stem}/{cache}: {e}")

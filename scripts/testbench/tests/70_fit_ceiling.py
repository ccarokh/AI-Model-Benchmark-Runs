"""Where it stops fitting -- found by trying, not by asserting."""
NAME = "fit_ceiling"
DESCRIPTION = "Largest context that still allocates, per build, model and KV cache"

from harness import WattSampler, alloc_probe, card_is_idle

# A fixed list of depths answers "does 65 536 fit" and stops there. The question
# is the other one: WHERE does it stop. So this grows until something breaks and
# then halves the gap -- the last size that worked and the first that did not are
# both recorded, with the reason the failing one gave.
FIRST = 8192          # first probe; below this nothing interesting happens
GRANULARITY = 4096    # stop bisecting when the gap is this small
CEILING = 2_097_152   # a stop for models that never fail -- not a limit of the card


def _state(ctx, build, model, cache, size):
    """What is already known about this exact probe, from an earlier run."""
    base = f"{model.stem}:{cache}:d{size}"
    for outcome in ("ok", "fail"):
        if ctx.results.has(ctx.results.key(NAME, "", build.backend, build.version,
                                           f"{base}:{outcome}")):
            return outcome
    return None


def _probe(ctx, build, model, cache, size):
    known = _state(ctx, build, model, cache, size)
    if known:
        return known == "ok"
    if not card_is_idle(ctx):
        raise RuntimeError("card busy")
    # An allocation probe, not a throughput one: what decides the ceiling is
    # whether the memory can be reserved, and that is settled before the first
    # token. Filling the depth instead took seven minutes for one probe at
    # 327 680 -- which put the search out of reach for more than a model or two.
    with WattSampler(ctx.power, interval=0.25) as sampler:
        ok, reason = alloc_probe(build, model, size, cache)
    ctx.results.add(NAME, "", build.backend, build.version,
                    f"{model.stem}:{cache}:d{size}:{'ok' if ok else 'fail'}",
                    str(sampler.peak_vram or 0) if ok else "",
                    "MiB peak" if ok else "",
                    reason or f"allocation probe, {len(sampler.vram)} samples")
    ctx.say(f"  {build.backend} {model.stem} {cache} d{size}: "
            + ("allocates" if ok else f"FAILS -- {reason}"))
    return ok


def _search(ctx, build, model, cache):
    """Double until it breaks, then halve until the gap stops mattering."""
    good, bad, size = 0, None, FIRST
    while size <= CEILING:
        if _probe(ctx, build, model, cache, size):
            good = size
            size *= 2
        else:
            bad = size
            break
    if bad is None:
        ctx.results.add(NAME, "", build.backend, build.version,
                        f"{model.stem}:{cache}:ceiling", str(good), "tokens",
                        f"never failed up to {CEILING} -- stopped there, not a limit of the card")
        ctx.say(f"  {build.backend} {model.stem} {cache}: no ceiling below {CEILING}")
        return
    while bad - good > GRANULARITY:
        middle = (good + bad) // 2
        if _probe(ctx, build, model, cache, middle):
            good = middle
        else:
            bad = middle
    ctx.results.add(NAME, "", build.backend, build.version,
                    f"{model.stem}:{cache}:ceiling", str(good), "tokens",
                    f"first failure at {bad}")
    ctx.say(f"  {build.backend} {model.stem} {cache}: CEILING {good} tokens "
            f"(first failure at {bad})")


def run(ctx):
    # Every build, because the ceiling is an allocation limit and the allocator
    # belongs to the backend. Measuring it once through Vulkan and filing it as
    # "the ceiling of this card" assumes exactly what it should be reporting.
    done = total = 0
    for build in ctx.builds:
        for model in ctx.models:
            for cache in ("f16", "q8_0"):
                total += 1
                if ctx.results.has_prefix(NAME, "", build.backend, build.version,
                                          f"{model.stem}:{cache}:ceiling"):
                    done += 1
                    continue
                if ctx.out_of_budget():
                    continue
                try:
                    _search(ctx, build, model, cache)
                    done += 1
                except RuntimeError as e:
                    ctx.defer(NAME, f"{model.stem}/{cache}: {e}")
    ctx.coverage(NAME, done, total,
                 f"{len(ctx.builds)} builds x {len(ctx.models)} models x 2 caches")

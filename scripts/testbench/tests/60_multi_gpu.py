"""Is a second card worth it -- and which split mode survives contact?"""
NAME = "multi_gpu"
DESCRIPTION = "Split modes and ratios across two or more cards"

from harness import bench, card_is_idle

# The separator in -ts is a SLASH. A comma is parsed as two separate runs, which
# is how "3,1" once produced numbers that looked like a ratio sweep and were not.
LAYOUTS = [("single", ("-sm", "none", "-mg", "0")),
           ("layer 1:0", ("-sm", "layer", "-ts", "1/0")),
           ("layer 7:1", ("-sm", "layer", "-ts", "7/1")),
           ("layer 3:1", ("-sm", "layer", "-ts", "3/1")),
           ("tensor 3:1", ("-sm", "row", "-ts", "3/1"))]


def run(ctx):
    if len(ctx.cards) < 2:
        ctx.skip_permanently(NAME, f"only {len(ctx.cards)} card on this machine")
        return
    build = ctx.builds[0]
    # The largest model, because a split only matters where one card is not
    # enough -- and -n 1000 rather than a short burst, since generation is what
    # the split costs and a three-second run cannot show it.
    model = max(ctx.models, key=lambda m: m.stat().st_size)
    for label, flags in LAYOUTS:
        key = ctx.results.key(NAME, "+".join(c.index for c in ctx.cards),
                              build.backend, build.version, f"{model.stem}:{label}")
        if ctx.results.has(key) or ctx.out_of_budget():
            continue
        if not card_is_idle(ctx):
            ctx.defer(NAME, f"card busy before {label}")
            continue
        r = bench(build, model, "-p", "2048", "-n", "1000", "-r", "2", "-ngl", "99", *flags)
        cards = "+".join(c.index for c in ctx.cards)
        if not r:
            ctx.results.add(NAME, cards, build.backend, build.version,
                            f"{model.stem}:{label}", "", "",
                            "no measurement -- this configuration did not run")
            ctx.say(f"  {label}: NO MEASUREMENT")
            continue
        for phase, unit in (("pp", "t/s prefill"), ("tg", "t/s generation")):
            ctx.results.add(NAME, cards, build.backend, build.version,
                            f"{model.stem}:{label}:{phase}", f"{r[phase]:.2f}", unit)
        ctx.say(f"  {label}: pp={r['pp']:.1f} tg={r['tg']:.2f}")

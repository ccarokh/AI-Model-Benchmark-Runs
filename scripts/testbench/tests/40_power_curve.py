"""What the card costs at each power limit, and where the optimum sits."""
NAME = "power_curve"
DESCRIPTION = "Efficiency against the power limit (tokens per watt-hour)"

from harness import WattSampler, bench, card_is_idle

# Generation only in the tokens/Wh figure: that is the phase a power limit bites
# in, and mixing prefill into it hides the effect. The steps go top-down so the
# card is never left at the lowest one if the run dies -- and the runner restores
# the original limit in a finally block regardless.
ARGS = ("-p", "2048", "-n", "256", "-r", "3", "-ngl", "99")


def run(ctx):
    if not ctx.power.can_set_limit():
        ctx.skip_permanently(NAME, f"power limit not settable ({ctx.power.kind})")
        return
    model = ctx.models[0]
    default = int(ctx.power.default_limit_w or 0)
    configured = ctx.config.get("power_steps", "")
    steps = [int(s) for s in configured.split()] if configured else \
            [w for w in range(default, 60, -20)] if default else []
    if not steps:
        ctx.skip_permanently(NAME, "no power steps known and no default limit readable")
        return

    for watts in steps:
        if any(ctx.results.has_prefix(NAME, "", b.backend, b.version,
                                      f"{model.stem}:{watts}W") for b in ctx.builds) \
           or ctx.out_of_budget():
            continue
        if not card_is_idle(ctx):
            ctx.defer(NAME, f"card busy before {watts} W")
            continue
        if not ctx.power.set_limit(watts):
            ctx.defer(NAME, f"could not set {watts} W")
            continue
        build = ctx.builds[0]
        # The sampler covers the compute window only. Starting it with the
        # process would average in model loading -- a 17 GB model loads for half
        # a minute while the card idles, and that artifact once became a
        # published claim about MoE architectures drawing less power.
        with WattSampler(ctx.power) as sampler:
            r = bench(build, model, *ARGS)
        if not r:
            ctx.defer(NAME, f"no measurement at {watts} W")
            continue
        mean, peak = sampler.mean, sampler.peak
        per_wh = r["tg"] * 3600 / mean if mean else None
        ctx.results.add(NAME, "", build.backend, build.version,
                        f"{model.stem}:{watts}W:tg", f"{r['tg']:.2f}", "t/s generation")
        ctx.results.add(NAME, "", build.backend, build.version,
                        f"{model.stem}:{watts}W:pp", f"{r['pp']:.2f}", "t/s prefill")
        if mean:
            ctx.results.add(NAME, "", build.backend, build.version,
                            f"{model.stem}:{watts}W:watt", f"{mean:.1f}", "W mean",
                            f"peak {peak:.1f} W, {sampler.count} samples, sensor {ctx.power.kind}")
            ctx.results.add(NAME, "", build.backend, build.version,
                            f"{model.stem}:{watts}W:tok_per_wh", f"{per_wh:.0f}", "tok/Wh",
                            f"sensor {ctx.power.kind}")
        ctx.say(f"  {watts} W: tg={r['tg']:.2f} at {mean:.1f} W mean "
                f"-> {per_wh:.0f} tok/Wh" if mean else f"  {watts} W: tg={r['tg']:.2f}")
    ctx.power.restore()

"""What the card costs at each power limit, and where the optimum sits."""
NAME = "power_curve"
DESCRIPTION = "Efficiency against the power limit (tokens per watt-hour), per model"

from harness import WattSampler, bench, card_is_idle

# EVERY MODEL, not the first one. "Where is the optimum" has no reason to have
# the same answer for a 3B running at 200 t/s and a 14B at 20 -- the fixed costs
# that make the curve turn back upwards are the same watts, but they are being
# amortised over very different token rates. Running this on models[0] and
# calling the test finished was an assumption in the shape of a measurement.
#
# Generation only in the tokens/Wh figure: that is the phase a power limit bites
# in, and mixing prefill into it hides the effect.
ARGS = ("-p", "2048", "-n", "256", "-r", "3", "-ngl", "99")


def run(ctx):
    if not ctx.power.can_set_limit():
        ctx.skip_permanently(NAME, f"power limit not settable ({ctx.power.kind})")
        return
    default = int(ctx.power.default_limit_w or 0)
    configured = ctx.config.get("power_steps", "")
    steps = [int(s) for s in configured.split()] if configured else \
            [w for w in range(default, 60, -20)] if default else []
    if not steps:
        ctx.skip_permanently(NAME, "no power steps known and no default limit readable")
        return

    # One build on purpose, and it is the only deliberate reduction left in the
    # suite: this test asks what the CARD does with watts, and the backend does
    # not change the power limit. It doubles the longest test in the programme
    # to re-answer a question about hardware. The coverage row says so, because
    # a limitation nobody can see in the results is indistinguishable from an
    # oversight -- which is exactly how the other five got theirs.
    build = ctx.builds[0]
    done = total = 0
    try:
        for model in ctx.models:
            for watts in steps:
                total += 1
                if ctx.results.has_prefix(NAME, "", build.backend, build.version,
                                          f"{model.stem}:{watts}W"):
                    done += 1
                    continue
                if ctx.out_of_budget():
                    continue
                if not card_is_idle(ctx):
                    ctx.defer(NAME, f"card busy before {model.stem} at {watts} W")
                    continue
                if not ctx.power.set_limit(watts):
                    ctx.defer(NAME, f"could not set {watts} W")
                    continue
                # The sampler covers the compute window only. Starting it with
                # the process would average in model loading -- a 17 GB model
                # loads for half a minute while the card idles, and that
                # artifact once became a published claim about MoE power draw.
                # A short unsampled run first. Setting a new power limit does
                # not move the clocks instantly, and the first seconds after the
                # switch are drawn at idle rates -- which lands in the mean and
                # makes the step look more efficient than it is. It showed as a
                # jump exactly at each model's FIRST step: 3B at 220 W came out
                # at 6 936 tok/Wh against 5 315 at 160 W, breaking an otherwise
                # monotone curve. Three of four models had it, in the same place.
                bench(build, model, "-p", "512", "-n", "32", "-r", "1", "-ngl", "99")
                with WattSampler(ctx.power, interval=0.25) as sampler:
                    r = bench(build, model, *ARGS)
                if not r:
                    ctx.defer(NAME, f"no measurement for {model.stem} at {watts} W")
                    continue
                mean, peak = sampler.mean, sampler.peak
                per_wh = r["tg"] * 3600 / mean if mean else None
                base = f"{model.stem}:{watts}W"
                ctx.results.add(NAME, "", build.backend, build.version, base + ":tg",
                                f"{r['tg']:.2f}", "t/s generation")
                ctx.results.add(NAME, "", build.backend, build.version, base + ":pp",
                                f"{r['pp']:.2f}", "t/s prefill")
                if mean:
                    ctx.results.add(NAME, "", build.backend, build.version, base + ":watt",
                                    f"{mean:.1f}", "W mean",
                                    f"peak {peak:.1f} W, {sampler.count} samples, "
                                    f"sensor {ctx.power.kind}")
                    ctx.results.add(NAME, "", build.backend, build.version,
                                    base + ":tok_per_wh", f"{per_wh:.0f}", "tok/Wh",
                                    f"sensor {ctx.power.kind}")
                done += 1
                ctx.say(f"  {model.stem} {watts} W: tg={r['tg']:.2f}"
                        + (f" at {mean:.1f} W -> {per_wh:.0f} tok/Wh" if mean else ""))
    finally:
        # Whatever happens, the card does not stay throttled. A measurement
        # machine left at 100 W produces "results" for weeks that are nothing
        # but the leftover of a run nobody remembers.
        ctx.power.restore()
    ctx.coverage(NAME, done, total,
                 f"{len(steps)} steps x {len(ctx.models)} models on {build.backend} only "
                 f"(of {len(ctx.builds)} builds -- deliberate: the power limit is the card's, "
                 f"not the backend's)")

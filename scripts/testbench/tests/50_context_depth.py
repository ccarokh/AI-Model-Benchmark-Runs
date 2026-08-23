"""How much context fits beside the model, and what it costs."""
NAME = "context_depth"
DESCRIPTION = "Throughput over context depth, f16 against a quantised KV cache"

from harness import WattSampler, bench, card_is_idle

# Up to the point where it breaks, not up to a round number. On a 12 GB card a
# 9B at Q4 sits at 5.5 GB and reaches 7.6 GB at 65 536 -- so a sweep that stops
# there answers "it fits" and never finds the ceiling the test exists to find.
# A depth the model or the card refuses is recorded as a refusal.
DEPTHS = (0, 4096, 8192, 16384, 32768, 65536, 131072, 262144)
CACHES = ("f16", "q8_0")


def run(ctx):
    model = ctx.models[0]
    build = ctx.builds[0]
    for cache in CACHES:
        for depth in DEPTHS:
            if ctx.results.has_prefix(NAME, "", build.backend, build.version,
                                      f"{model.stem}:{cache}:d{depth}") or ctx.out_of_budget():
                continue
            if not card_is_idle(ctx):
                ctx.defer(NAME, f"card busy before depth {depth}")
                continue
            # The sampler runs alongside, because the question this test asks
            # is how much memory the depth costs -- and that is only visible
            # while the run is happening.
            with WattSampler(ctx.power) as sampler:
                r = bench(build, model, "-p", "512", "-n", "128", "-d", str(depth),
                          "-fa", "on", "-ctk", cache, "-ctv", cache, "-r", "2", "-ngl", "99")
            if not r:
                # The most likely reason is exactly what is being measured. A
                # depth that fails is the number somebody needs; a blank line is
                # not, so this one is recorded rather than deferred.
                ctx.results.add(NAME, "", build.backend, build.version,
                                f"{model.stem}:{cache}:d{depth}", "", "",
                                "no measurement -- most likely too little VRAM for the cache")
                ctx.say(f"  {cache} depth {depth}: NO MEASUREMENT (probably out of VRAM)")
                continue
            for phase, unit in (("pp", "t/s prefill"), ("tg", "t/s generation")):
                ctx.results.add(NAME, "", build.backend, build.version,
                                f"{model.stem}:{cache}:d{depth}:{phase}",
                                f"{r[phase]:.2f}", unit,
                                f"peak {sampler.peak_vram or 0} MiB VRAM during the run")
            ctx.results.add(NAME, "", build.backend, build.version,
                            f"{model.stem}:{cache}:d{depth}:vram", str(sampler.peak_vram or 0),
                            "MiB peak")
            ctx.say(f"  {cache} depth {depth}: pp={r['pp']:.1f} tg={r['tg']:.2f} "
                    f"peak {sampler.peak_vram or 0} MiB")

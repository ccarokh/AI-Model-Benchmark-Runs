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
    # Every build and every model. One build was an arbitrary pick: whether the
    # depth curve looks the same through CUDA as through Vulkan is a question,
    # not a given -- different allocators, different compute buffers. And a
    # depth curve for one model says nothing about the model beside it, which
    # is the whole reason the 14B turned out to be the interesting case.
    done = total = 0
    for build in ctx.builds:
     for model in ctx.models:
      for cache in CACHES:
       for depth in DEPTHS:
            total += 1
            if ctx.results.has_prefix(NAME, "", build.backend, build.version,
                                      f"{model.stem}:{cache}:d{depth}"):
                done += 1
                continue
            if ctx.out_of_budget():
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
            done += 1
            ctx.results.add(NAME, "", build.backend, build.version,
                            f"{model.stem}:{cache}:d{depth}:vram", str(sampler.peak_vram or 0),
                            "MiB peak")
            ctx.say(f"  {cache} depth {depth}: pp={r['pp']:.1f} tg={r['tg']:.2f} "
                    f"peak {sampler.peak_vram or 0} MiB")
    ctx.coverage(NAME, done, total,
                 f"{len(ctx.builds)} builds x {len(ctx.models)} models x "
                 f"{len(CACHES)} caches x {len(DEPTHS)} depths")

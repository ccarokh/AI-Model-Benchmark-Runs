"""How much context fits beside the model, and what it costs."""
NAME = "context_depth"
DESCRIPTION = "Throughput over context depth, f16 against a quantised KV cache"

from harness import bench, card_is_idle

DEPTHS = (0, 4096, 8192, 16384, 32768, 65536)
CACHES = ("f16", "q8_0")


def run(ctx):
    model = ctx.models[0]
    build = ctx.builds[0]
    for cache in CACHES:
        for depth in DEPTHS:
            key = ctx.results.key(NAME, "", build.backend, build.version,
                                  f"{model.stem}:{cache}:d{depth}")
            if ctx.results.has(key) or ctx.out_of_budget():
                continue
            if not card_is_idle(ctx):
                ctx.defer(NAME, f"card busy before depth {depth}")
                continue
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
                                f"{ctx.power.vram_used_mib()} MiB in use just after")
            ctx.say(f"  {cache} depth {depth}: pp={r['pp']:.1f} tg={r['tg']:.2f}")

"""Which of these models fit on this card at all -- measured, not estimated."""
NAME = "model_ceiling"
DESCRIPTION = "Per model: does it run fully on the GPU here, and what does it occupy"

from harness import WattSampler, bench_probe, card_is_idle

# "That does not fit on 12 GB" is the sentence this test exists to replace. A
# file size and a VRAM figure are two different numbers -- the KV cache, the
# compute buffers and the context all come on top, and the only way to know is
# to load it.
#
# THE PROBE HAS TO LAST LONGER THAN THE SAMPLER'S STEP. The first version ran
# -p 64 -n 16 for about two seconds and sampled once a second, which caught the
# card mid-load: four of five models came back with a peak BELOW their own file
# size, an overhead of minus 500 MiB. A figure that is physically impossible is
# still a figure, and it went into the results looking like a measurement. The
# probe is now long enough to be sampled, the sampler runs four times a second,
# and a VRAM row that rests on fewer than four samples says so.
PROBE = ("-p", "512", "-n", "64", "-r", "2", "-ngl", "99")
INTERVAL = 0.25
MIN_SAMPLES = 4


def run(ctx):
    build = ctx.builds[0]
    for model in ctx.models:
        if ctx.results.has_prefix(NAME, "", build.backend, build.version, model.stem):
            continue
        if ctx.out_of_budget():
            return
        if not card_is_idle(ctx):
            ctx.defer(NAME, f"card busy before {model.stem}")
            continue
        size_gib = model.stat().st_size / 1024 ** 3
        with WattSampler(ctx.power, interval=INTERVAL) as sampler:
            ok, reason = bench_probe(build, model, *PROBE)
        peak = sampler.peak_vram or 0
        ctx.results.add(NAME, "", build.backend, build.version,
                        f"{model.stem}:fits", "yes" if ok else "no", "",
                        reason if not ok else f"file {size_gib:.2f} GiB")
        if ok:
            samples = len(sampler.vram)
            overhead = peak - size_gib * 1024
            doubt = ""
            if samples < MIN_SAMPLES:
                doubt = f"only {samples} samples -- undersampled, do not read as a peak"
            elif overhead < 0:
                doubt = "peak below the file size -- the load was not caught, treat as invalid"
            ctx.results.add(NAME, "", build.backend, build.version,
                            f"{model.stem}:vram", str(peak), "MiB peak",
                            f"file {size_gib:.2f} GiB, overhead {overhead:.0f} MiB, "
                            f"{samples} samples{'; ' + doubt if doubt else ''}")
        ctx.say(f"  {model.stem} ({size_gib:.2f} GiB): "
                + (f"runs, {peak} MiB peak" if ok else f"DOES NOT RUN -- {reason}"))

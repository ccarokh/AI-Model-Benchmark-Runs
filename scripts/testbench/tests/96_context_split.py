"""Ten users at 32k -- is that 320k of cache, or something worse?"""
NAME = "context_split"
DESCRIPTION = "The same total context split across 1..16 slots: does the memory cost change"

from harness import WattSampler, card_is_idle, server_probe

# The sizing question a deployment asks: ten people, 32 768 tokens each -- does
# that need a card that holds 327 680 tokens of cache?
#
# The arithmetic says yes and the arithmetic might be wrong in either direction.
# Each slot could carry its own compute buffers, making many small slots cost
# MORE than one big one; or the unified KV buffer could share something and make
# them cost less. Both are plausible from the flags alone
# (`--kv-unified` is on by default when the slot count is automatic), and
# neither is a thing to guess at when the answer decides how much card to buy.
#
# So: one total, held constant, cut into 1, 2, 4, 8 and 16 slots. If the peak
# memory is the same every time, the rule is clean multiplication and a sizing
# question can be answered on paper. If it is not, the difference is what nobody
# would have budgeted for.
SPLITS = [1, 2, 4, 8, 16]
SAMPLE_INTERVAL = 0.25
MIN_SAMPLES = 4


def run(ctx):
    done = total_cells = 0
    for build in ctx.builds:
        card = ctx.card_for(build) or ""
        if not (build.bin / "llama-server").exists():
            ctx.skip_permanently(NAME, f"{build.backend} build has no llama-server",
                                 backend=build.backend, build=build.version)
            continue
        for model in ctx.models:
            # The total comes from this machine's own measured ceiling for this
            # model, halved: a total that does not fit measures the allocator's
            # refusal instead of the cost of splitting. A model whose ceiling
            # was never measured here is skipped rather than guessed at.
            decke = ctx.results.value_of("fit_ceiling", "", build.backend, build.version,
                                         f"{model.stem}:f16:ceiling")
            try:
                gesamt = (int(decke) // 2 // 4096) * 4096
            except (TypeError, ValueError):
                gesamt = 0
            if gesamt < 4096 * max(SPLITS):
                ctx.results.add(NAME, card, build.backend, build.version, model.stem,
                                "not run", "",
                                f"measured ceiling {decke or 'unknown'} -- too small to "
                                f"split {max(SPLITS)} ways at 4096 each")
                continue
            for slots in SPLITS:
                total_cells += 1
                key = f"{model.stem}:{gesamt}:{slots}slots"
                if ctx.results.has_prefix(NAME, card, build.backend, build.version, key):
                    done += 1
                    continue
                if ctx.out_of_budget():
                    return
                if not card_is_idle(ctx):
                    ctx.defer(NAME, f"card busy before {key}")
                    break
                with WattSampler(ctx.power, interval=SAMPLE_INTERVAL) as sampler:
                    probe = server_probe(build, model, "Nenne drei Farben.",
                                         "-np", str(slots), device=card or None,
                                         n_predict=16, ctx_size=gesamt)
                peak = sampler.peak_vram or 0
                proben = len(sampler.vram)
                done += 1
                if not probe["ok"]:
                    ctx.results.add(NAME, card, build.backend, build.version, key,
                                    "failed", f"{gesamt} total, {slots} slots",
                                    probe["reason"])
                    ctx.say(f"  {build.backend} {model.stem}: {gesamt} in {slots} slots "
                            f"-- DOES NOT RUN: {probe['reason']}")
                    continue
                zweifel = ("only %d samples -- undersampled, do not read as a peak" % proben
                           if proben < MIN_SAMPLES else "")
                ctx.results.add(NAME, card, build.backend, build.version, f"{key}:vram",
                                str(peak), "MiB peak",
                                f"{gesamt} tokens total across {slots} slots, "
                                f"{gesamt // slots} each, {proben} samples"
                                + ("; " + zweifel if zweifel else ""))
                ctx.say(f"  {build.backend} {model.stem}: {gesamt} in {slots} slots "
                        f"({gesamt // slots} each) -- {peak} MiB")
    ctx.coverage(NAME, done, total_cells,
                 f"{len(ctx.builds)} builds x {len(ctx.models)} models x {len(SPLITS)} splits")

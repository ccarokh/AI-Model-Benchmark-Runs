"""Does the harness change the number it is taking?"""
NAME = "harness_cost"
DESCRIPTION = "The measurement's own instruments: does the memory cap or the sampler move the result"

from harness import WattSampler, bench, card_is_idle

# A guard that prevents a crash and shifts the numbers is not a guard, it is a
# bias with good intentions -- and a systematic shift does not show up as
# variance, so no amount of repeating finds it. Two instruments of this harness
# touch the machine while it measures, and both are under suspicion:
#
#   THE MEMORY CAP. Since 28.08. every measurement runs inside
#   `systemd-run --scope -p MemoryMax=… -p MemorySwapMax=0`, because twice an
#   OOM kill took the whole night service. But that cgroup also bounds the page
#   cache holding the model file: a capped run may re-read weights that an
#   uncapped one keeps in memory. On its first night the concurrency figures
#   came out 45 % below the same card's reference measurement and were not even
#   monotone in the user count.
#
#   THE POWER SAMPLER. It polls the vendor tool or sysfs one to four times a
#   second DURING the measured window. It cannot be removed -- without it there
#   are no wattage or VRAM figures at all -- so the question is not whether to
#   keep it but what it costs.
#
# One variable between arms, three runs each, and the arms are interleaved
# rather than grouped: a card that warms up over the hour would otherwise hand
# its drift to whichever arm ran last.
ARGS = ("-p", "2048", "-n", "128", "-r", "3", "-ngl", "99")
REPEATS = 3
MEMORY_ARMS = [("uncapped", ""), ("10G", "10G"), ("20G", "20G")]
SAMPLER_ARMS = [("off", None), ("1Hz", 1.0), ("4Hz", 0.25)]


def _record(ctx, build, model, arm, run_no, result, note):
    if not result:
        ctx.results.add(NAME, "", build.backend, build.version,
                        f"{model.stem}:{arm}:r{run_no}", "failed", "", note)
        return
    for phase, unit in (("pp", "t/s prefill"), ("tg", "t/s generation")):
        ctx.results.add(NAME, "", build.backend, build.version,
                        f"{model.stem}:{arm}:r{run_no}:{phase}",
                        f"{result[phase]:.2f}", unit, note)


def run(ctx):
    done = total = 0
    # One model, not all of them. This measures the harness, and a second model
    # answers the same question again rather than a new one -- the first entry
    # is the one the single-model tests use throughout this suite.
    model = ctx.models[0] if ctx.models else None
    if model is None:
        ctx.skip_permanently(NAME, "no model on this machine")
        return

    for build in ctx.builds:
        arms = ([(f"memory:{name}", ("memory", value)) for name, value in MEMORY_ARMS]
                + [(f"sampler:{name}", ("sampler", value)) for name, value in SAMPLER_ARMS])
        for run_no in range(1, REPEATS + 1):
            for arm, (kind, value) in arms:
                total += 1
                key = f"{model.stem}:{arm}:r{run_no}"
                if ctx.results.has_prefix(NAME, "", build.backend, build.version, key):
                    done += 1
                    continue
                if ctx.out_of_budget():
                    return
                if not card_is_idle(ctx):
                    ctx.defer(NAME, f"card busy before {key}")
                    return
                if kind == "memory":
                    # No sampler in this arm at all, so the two instruments are
                    # never varied at the same time.
                    result = bench(build, model, *ARGS, memory=value)
                    note = f"memory cap {value or 'none'}, no sampler"
                else:
                    if value is None:
                        result = bench(build, model, *ARGS, memory="")
                    else:
                        with WattSampler(ctx.power, interval=value):
                            result = bench(build, model, *ARGS, memory="")
                    note = f"sampler {arm.split(':')[1]}, no memory cap"
                _record(ctx, build, model, arm, run_no, result,
                        note if result else "produced no result")
                done += 1
                if result:
                    ctx.say(f"  {build.backend} {arm} run {run_no}: "
                            f"pp={result['pp']:.1f} tg={result['tg']:.2f}")
    ctx.coverage(NAME, done, total,
                 f"{len(ctx.builds)} builds x 1 model x {len(MEMORY_ARMS) + len(SAMPLER_ARMS)} "
                 f"arms x {REPEATS} runs")


def report(rows):
    """Each arm as a range, and the spread between arms beside it.

    A mean would hide exactly what this test exists to find: if the arms differ
    by more than they differ from themselves, the instrument is in the number.
    """
    import collections
    import statistics
    values = collections.defaultdict(list)
    for r in rows:
        p = r["parameter"]
        if not p.endswith(":tg"):
            continue
        teile = p.split(":")
        if len(teile) < 4:
            continue
        arm = ":".join(teile[1:-2])
        try:
            values[(r["backend"], arm)].append(float(r["value"]))
        except ValueError:
            pass
    if not values:
        return
    for backend in sorted({b for b, _ in values}):
        arme = {a: v for (b, a), v in values.items() if b == backend}
        alle = [x for v in arme.values() for x in v]
        print(f"  {backend}: generation t/s per arm, {len(alle)} runs")
        for arm in sorted(arme):
            v = arme[arm]
            print("    %-16s %s   spread within arm %.2f" % (
                arm, " ".join("%6.2f" % x for x in v), max(v) - min(v) if len(v) > 1 else 0))
        mitten = {a: statistics.median(v) for a, v in arme.items()}
        zwischen = max(mitten.values()) - min(mitten.values())
        innen = max((max(v) - min(v)) for v in arme.values() if len(v) > 1)
        print(f"    between arms {zwischen:.2f} t/s, worst within one arm {innen:.2f} t/s -- "
              + ("THE INSTRUMENT IS IN THE NUMBER" if zwischen > innen
                 else "no effect this test can see"))

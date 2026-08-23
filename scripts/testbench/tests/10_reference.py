"""The comparable measurement: same file, same flags, one card at a time."""
NAME = "reference"
DESCRIPTION = "Fixed reference workload per card, build and model"

from harness import bench, card_is_idle

# Upstream's own flags. DO NOT "improve" them -- the entire point is that the
# numbers can be held against somebody else's. -r 5 instead of upstream's -r 2 is
# the one deliberate change: it does not alter what is measured, only how many
# repetitions the mean covers, and a two-second run is too short for a power
# trace to mean anything.
ARGS = ("-p", "2048", "-n", "128", "-r", "5", "-ngl", "99")


def run(ctx):
    for build in ctx.builds:
        for card in ctx.cards or [None]:
            for model in ctx.models:
                card_id = card.index if card else "default"
                key = ctx.results.key(NAME, card_id, build.backend, build.version, model.stem)
                if ctx.results.has(key):
                    continue
                if ctx.out_of_budget():
                    return
                if not card_is_idle(ctx):
                    ctx.defer(NAME, f"card busy before {model.stem} on {card_id}")
                    continue
                # A fresh process per measurement, and one card per run: a
                # number that silently used two cards is not a card's number.
                r = bench(build, model, *ARGS, device=card.index if card else None)
                if not r:
                    ctx.defer(NAME, f"no measurement for {model.stem} on {card_id}")
                    continue
                for phase, unit in (("pp", "t/s prefill"), ("tg", "t/s generation")):
                    ctx.results.add(NAME, card_id, build.backend, build.version,
                                    f"{model.stem}:{phase}", f"{r[phase]:.2f}", unit,
                                    f"sd {r.get(phase + '_sd', 0):.2f}")
                ctx.say(f"  {card_id} {build.backend} {model.stem}: "
                        f"pp={r['pp']:.1f} tg={r['tg']:.2f}")

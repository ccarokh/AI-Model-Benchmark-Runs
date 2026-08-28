"""How many people can one card serve at once, before it stops serving."""
NAME = "concurrency"
DESCRIPTION = "Users in parallel: aggregate rate, what each one waits, and where it breaks"

from harness import card_is_idle, server_load

# Every other figure in this repository is one request on an empty card. That is
# what a person sees when nobody else is using the machine -- and it is not what
# a service delivers. This test asks the question a deployment actually has:
# **how many people at once, before it stops being usable?**
#
# There are two ways to stop being usable, and they are different answers:
#
#   HARD -- the server will not start, or requests fail. On a 12 GB card that
#     happens early, and it is a memory ceiling: the KV cache of every user has
#     to be resident at the same time.
#   SOFT -- everything still works and nobody wants to use it. A user reads at
#     roughly ten tokens a second; below that, an answer arrives slower than it
#     can be read.
#
# Both are recorded. Only one of them shows up as an error.
USERS = [1, 2, 4, 8, 16, 32, 64]

# THE SECOND HALF OF THE QUESTION. Above, every user gets a slot of their own,
# which answers "how many at the same instant" -- a memory question, and it ends
# in a refusal to start. It is not the question a service asks. llama.cpp parks
# an idle slot in a host-RAM prompt cache and fetches it back, so more people
# than slots is a supported arrangement: 32 users on 4 slots all got answers
# here, and what grew was the wait, not the failure count. So the same load is
# run again against a FIXED, affordable number of slots.
QUEUED_SLOTS = 4
QUEUED_USERS = [4, 8, 16, 32, 64]

# THE CONTEXT IS PER USER. A RAG turn carries its retrieved passages and some
# history; 8 192 tokens is the budget this system actually gives a turn. The
# server's total is scaled with the number of users so that the eighth user has
# the same room as the first -- otherwise raising the user count quietly lowers
# the context and the run measures the wrong variable.
PER_USER_CTX = 8192
N_PREDICT = 200

# Roughly reading speed. Below it, the answer arrives slower than a person reads.
USABLE_TOKENS_PER_SECOND = 10.0

# A retrieval turn, because that is the workload being sized -- not free prose.
PROMPT = (
    "Beantworte die Frage ausschliesslich mit dem folgenden Text und zitiere die "
    "belegende Stelle woertlich.\n\n"
    "Text: Die Wartung der Anlage erfolgt jaehrlich im Maerz. Zustaendig ist die "
    "Abteilung Betriebstechnik. Ersatzteile werden ueber das zentrale Lager in "
    "Halle 3 bezogen, die Bestellfrist betraegt vierzehn Tage. Bei Stoerungen "
    "ausserhalb der Wartung ist die Rufbereitschaft unter der Nummer 4711 zu "
    "erreichen. Die letzte Grossrevision fand im Maerz 2024 statt und dauerte "
    "elf Tage; dabei wurden die Lager der Hauptpumpe und zwei Ventile getauscht.\n\n"
    "Frage: Wer ist zustaendig, wann wird gewartet, wie lange dauert eine "
    "Ersatzteilbestellung, und was geschah bei der letzten Grossrevision?"
)


def run(ctx):
    done = total = 0
    for build in ctx.builds:
        if not (build.bin / "llama-server").exists():
            ctx.skip_permanently(NAME, f"{build.backend} build has no llama-server",
                                 backend=build.backend, build=build.version)
            continue
        for model in ctx.models:
            grenze_hart = None
            grenze_weich = None
            for users in USERS:
                total += 1
                key = f"{model.stem}:u{users}"
                if ctx.results.has_prefix(NAME, "", build.backend, build.version, key):
                    done += 1
                    continue
                if ctx.out_of_budget():
                    return
                if not card_is_idle(ctx):
                    ctx.defer(NAME, f"card busy before {key}")
                    break
                last = server_load(build, model, PROMPT, users,
                                   per_user_ctx=PER_USER_CTX, n_predict=N_PREDICT)
                done += 1
                if not last["ok"]:
                    ctx.results.add(NAME, "", build.backend, build.version, key,
                                    "failed", f"{users} users", last["reason"])
                    ctx.say(f"  {build.backend} {model.stem}: {users} users -- "
                            f"DOES NOT RUN: {last['reason']}")
                    grenze_hart = users
                    break
                ctx.results.add(NAME, "", build.backend, build.version, f"{key}:aggregate",
                                f"{last['aggregate']:.2f}", "tokens/s total",
                                f"{users} users, {PER_USER_CTX} context each, "
                                f"{last['failures']} failed")
                ctx.results.add(NAME, "", build.backend, build.version, f"{key}:per_user",
                                f"{last['per_user']:.2f}", "tokens/s each",
                                f"slowest answer {last['slowest']:.1f} s")
                ctx.say(f"  {build.backend} {model.stem}: {users:2d} users -- "
                        f"{last['aggregate']:.1f} t/s total, {last['per_user']:.1f} each, "
                        f"slowest {last['slowest']:.1f} s")
                if grenze_weich is None and last["per_user"] < USABLE_TOKENS_PER_SECOND:
                    grenze_weich = users
                    ctx.say(f"    below {USABLE_TOKENS_PER_SECOND:.0f} t/s per user "
                            "-- an answer now arrives slower than it is read")
            # The answer, written down rather than left to be reconstructed
            # from the rows above. "Usable" is the largest count tested that
            # both ran and stayed above reading speed -- not the count at which
            # it broke, which is one step too far by definition.
            brauchbar = [u for u in USERS
                         if (grenze_hart is None or u < grenze_hart)
                         and (grenze_weich is None or u < grenze_weich)]
            if grenze_hart or grenze_weich:
                ctx.results.add(NAME, "", build.backend, build.version,
                                f"{model.stem}:usable_users",
                                str(max(brauchbar) if brauchbar else 0), "users",
                                f"does not run at {grenze_hart or '> ' + str(USERS[-1])}, "
                                f"below {USABLE_TOKENS_PER_SECOND:.0f} t/s each at "
                                f"{grenze_weich or '> ' + str(USERS[-1])}")
            # Queued: the slot count stays put and the people keep coming.
            if grenze_hart is not None and grenze_hart <= QUEUED_SLOTS:
                # The card cannot even hold the fixed slot count for this model,
                # so there is nothing to queue against.
                ctx.results.add(NAME, "", build.backend, build.version,
                                f"{model.stem}:queued", "not run", "",
                                f"{QUEUED_SLOTS} slots do not fit -- hard limit is "
                                f"{grenze_hart} users")
                continue
            for users in QUEUED_USERS:
                total += 1
                key = f"{model.stem}:q{users}on{QUEUED_SLOTS}"
                if ctx.results.has_prefix(NAME, "", build.backend, build.version, key):
                    done += 1
                    continue
                if ctx.out_of_budget():
                    return
                if not card_is_idle(ctx):
                    ctx.defer(NAME, f"card busy before {key}")
                    break
                last = server_load(build, model, PROMPT, users, slots=QUEUED_SLOTS,
                                   per_user_ctx=PER_USER_CTX, n_predict=N_PREDICT)
                done += 1
                if not last["ok"]:
                    ctx.results.add(NAME, "", build.backend, build.version, key,
                                    "failed", f"{users} users on {QUEUED_SLOTS} slots",
                                    last["reason"])
                    ctx.say(f"  {build.backend} {model.stem}: {users} on {QUEUED_SLOTS} "
                            f"slots -- DOES NOT RUN: {last['reason']}")
                    break
                ctx.results.add(NAME, "", build.backend, build.version, f"{key}:aggregate",
                                f"{last['aggregate']:.2f}", "tokens/s total",
                                f"{users} users queued on {QUEUED_SLOTS} slots, "
                                f"{last['failures']} failed")
                ctx.results.add(NAME, "", build.backend, build.version, f"{key}:wait",
                                f"{last['slowest']:.1f}", "s slowest answer",
                                f"{last['per_user']:.2f} tokens/s each")
                ctx.say(f"  {build.backend} {model.stem}: {users:2d} on {QUEUED_SLOTS} slots "
                        f"-- {last['aggregate']:.1f} t/s total, {last['per_user']:.1f} each, "
                        f"slowest {last['slowest']:.1f} s, {last['failures']} failed")

    ctx.coverage(NAME, done, total,
                 f"{len(ctx.builds)} builds x {len(ctx.models)} models x "
                 f"{len(USERS)} user counts, then {len(QUEUED_USERS)} queued on "
                 f"{QUEUED_SLOTS} slots")


def report(rows):
    """Two tables: where the wall is, and what a queue costs.

    Written here rather than in the reporting command, because what these
    numbers mean is this test's knowledge. The framework only decides when to
    ask for it.
    """
    import collections
    aggregate = collections.defaultdict(dict)
    queued = collections.defaultdict(dict)
    wall = {}
    for r in rows:
        p, backend = r["parameter"], r["backend"]
        model = p.split(":")[0]
        if r["value"] == "failed" and ":u" in p and ":q" not in p:
            n = int(p.split(":u")[1])
            wall[(backend, model)] = min(wall.get((backend, model), 10 ** 9), n)
        if p.endswith(":aggregate") and ":u" in p:
            aggregate[(backend, model)][int(p.split(":u")[1].split(":")[0])] = float(r["value"])
        if p.endswith(":wait") and ":q" in p:
            queued[(backend, model)][int(p.split(":q")[1].split("on")[0])] = float(r["value"])

    if aggregate:
        stufen = sorted({u for v in aggregate.values() for u in v})
        print("  one slot per user -- aggregate tokens/s, and where the server refuses")
        print("    %-8s %-34s %s   wall" % ("backend", "model",
                                            " ".join("%6d" % u for u in stufen)))
        for (backend, model), v in sorted(aggregate.items()):
            print("    %-8s %-34s %s   %s" % (
                backend, model[:34],
                " ".join(("%6.0f" % v[u]) if u in v else "     ." for u in stufen),
                wall.get((backend, model), "> tested")))
    if queued:
        stufen = sorted({u for v in queued.values() for u in v})
        print("  more users than slots -- slowest answer in seconds")
        print("    %-8s %-34s %s" % ("backend", "model",
                                     " ".join("%5d" % u for u in stufen)))
        for (backend, model), v in sorted(queued.items()):
            print("    %-8s %-34s %s" % (
                backend, model[:34],
                " ".join(("%5.0f" % v[u]) if u in v else "    ." for u in stufen)))

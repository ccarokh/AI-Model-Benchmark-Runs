"""Which hardware path does the work -- and what does switching it off cost?"""
NAME = "matrix_path"
DESCRIPTION = "Matrix/tensor path isolation, per backend with its own switches"

from harness import bench, card_is_idle

# The switches are not interchangeable, and using the wrong ones produces three
# identical rows that look like a finding. GGML_VK_* means nothing to CUDA: a
# run that measured "coopmat2 on the CUDA build" measured the same thing three
# times and only the second decimal gave it away.
SWITCHES = {
    "vulkan": [("default", {}),
               ("no-coopmat2", {"GGML_VK_DISABLE_COOPMAT2": "1"}),
               ("no-decode-vector", {"GGML_VK_DISABLE_COOPMAT2_DECODE_VECTOR": "1"})],
    "cuda":   [("default", {}),
               ("force-mmq", {"GGML_CUDA_FORCE_MMQ": "1"}),
               ("force-cublas", {"GGML_CUDA_FORCE_CUBLAS": "1"})],
}
ARGS = ("-p", "2048", "-n", "128", "-r", "5", "-ngl", "99")


def run(ctx):
    for build in ctx.builds:
        variants = SWITCHES.get(build.backend.split("+")[0])
        if not variants:
            ctx.skip_permanently(NAME, f"no known switches for backend {build.backend}",
                                 backend=build.backend, build=build.version)
            continue
        for model in ctx.models[:2]:
            for label, env in variants:
                if ctx.results.has_prefix(NAME, "", build.backend, build.version,
                                          f"{model.stem}:{label}") or ctx.out_of_budget():
                    continue
                if not card_is_idle(ctx):
                    ctx.defer(NAME, "card busy")
                    continue
                r = bench(build, model, *ARGS, env=env)
                if not r:
                    ctx.defer(NAME, f"no measurement for {model.stem}/{label}")
                    continue
                for phase, unit in (("pp", "t/s prefill"), ("tg", "t/s generation")):
                    ctx.results.add(NAME, "", build.backend, build.version,
                                    f"{model.stem}:{label}:{phase}", f"{r[phase]:.2f}", unit)
                ctx.say(f"  {build.backend} {model.stem}/{label}: "
                        f"pp={r['pp']:.1f} tg={r['tg']:.2f}")

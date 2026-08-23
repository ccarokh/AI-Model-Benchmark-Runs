# Versions

**The version history lives with each machine**, not here. That is what the split is for:
one machine changes without the others changing, and whoever reads its numbers needs its
history next to them — not three directories away.

| | |
|---|---|
| [System A](system-a.md#history) | v1.0 to v1.6 — second GPU, ROCm, a second llama.cpp prefix, stable-diffusion.cpp, production llama.cpp on v0.2.0 |
| [System B](system-b.md#history) | v1.0 |
| [System C](system-c.md#history) | v1.0 — freshly installed |

## Why versions at all

Both permanent machines are rolling-release, and both gained hardware during the
measurement period. **A result therefore belongs to a system *version*, not to a machine.**
When anything in the stack or the hardware changes, the version increments and older
results stay attached to the state that produced them.

This is not bookkeeping for its own sake. System A's PCIe width was ×16 until 3 August and
has been ×8 since — treat today's snapshot as a property of the system and every earlier
measurement is filed wrong.

## Model files

Pinned by **SHA256 against a manifest**, with the upstream repository commit recorded
alongside. "Same model" means the same bytes, not the same name — two files carrying the
same model name were found to be a duplicate pair this way, and two others have lost their
upstream repository and are marked as such.

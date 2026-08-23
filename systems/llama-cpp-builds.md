# The llama.cpp builds, and why there is more than one

| Path | Build | Used by |
|---|---|---|
| `/opt/llama-cpp` | **v0.2.0** (`bb4caa7`), since 23.08.2026 — **b10098** before | the production supervisor (`LLAMA_SERVER_BIN`) |
| `/opt/llama-cpp-nb` | **b10273** | every `llama-bench` measurement in this repository, and the agility game series |
| `/opt/llama-cpp-v0.2.0` | `bb4caa7` | the drift check's candidate build, kept beside production |

**The benchmark figures all come from the second one**, so they are internally consistent
and unaffected by what production does — but any statement about the *running system*,
including the hourly health probe that shares this card, is about the first.

There is no `llama-cpp` distribution package installed on this host; both are built here.
Upstream release cadence therefore never reaches us on its own, which is precisely why
**a standing measurement against current upstream is required** rather than optional —
see [the drift check](#checking-for-drift-against-current-upstream).


## What happened on 23.08., and what it cost

Production was **replaced in place** with v0.2.0 between 04:21 and 04:27, without the
check below having run. Three things follow, and none of them is about v0.2.0 being a bad
build:

- **b10098 is gone as binaries.** An in-place install overwrote them. The rollback point
  is b10273 or a rebuild from `0278d8362`. A candidate belongs *beside* production, in its
  own prefix — that is not a style preference, it is the difference between a rollback and
  a rebuild.
- **The check that ran afterwards was worthless and looked perfect.** It compares the
  candidate against production; production *was already* the candidate, so all six
  criteria came out green on a comparison of v0.2.0 with itself. The script now refuses
  that explicitly ("production is a DIFFERENT state than the candidate") and additionally
  compares against the pinned measurement build, which no swap can touch.
- **The evidence that v0.2.0 is equivalent was collected after the fact, and it holds.**
  The reference completion hash `40beccc6ee14a703` is identical on b10098 (02:49),
  b10273 and v0.2.0; production-like throughput differs by under 2 %. The order was
  wrong, not the destination.

Two defects in the check itself came out of the same night: it produced a full green
verdict for a build whose install had failed (zero libraries in the prefix, empty
measurements, and the SHA-256 of an empty stream as the "output hash"), and
`git rev-parse --short v0.2.0` returned the **annotated tag object** rather than the
commit, so the version stamp named something that does not exist in the history. Both are
fixed; the check now exits 3 on a red verdict, so silence cannot look like success.

**What the drift check still does not cover:** the chat template, tool calls and the
projector — the three things a version bump actually breaks. Those live in
[`server_smoke.sh`](../scripts/hardware/server_smoke.sh), which runs the candidate and
production side by side and compares the answers rather than asking whether each works.

## Checking for drift against current upstream

A pinned build is reproducible and slowly becomes wrong about the world. At the time of
writing the measurement build sat **215 builds behind** master while upstream tagged four
builds in a single morning.

**The standing rule: build current upstream alongside the pinned one — never over it —
and run the reference workload on both in the same session.** Two numbers from the same
hour are a comparison; a number today against one from three weeks ago is not.

Three things make that check honest:

- **Side by side, never in place.** A second prefix that
  [silently resolves its libraries to the first](../METHODOLOGY.md#check-that-the-backend-you-measured-is-the-one-you-meant)
  has already happened here once. Count how many resolve where before trusting a number.
- **Compare output, not only throughput.** A build that got faster and answers
  differently has not got faster at the same thing.
- **Record the result either way.** "No change between b10273 and current" is worth
  writing down; without it the check gets repeated from scratch, which
  [has also already happened here](../METHODOLOGY.md#a-negative-result-that-is-not-written-down-will-be-re-derived-badly).


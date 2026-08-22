# The llama.cpp builds, and why there is more than one

| Path | Build | Used by |
|---|---|---|
| `/opt/llama-cpp` | **b10098** | the production supervisor (`LLAMA_SERVER_BIN`) |
| `/opt/llama-cpp-nb` | **b10273** | every `llama-bench` measurement in this repository |

175 builds apart. **The benchmark figures all come from the second one**, so they are
internally consistent — but any statement about the *running system*, including the
hourly health probe that shares this card, is about the first.

There is no `llama-cpp` distribution package installed on this host; both are built here.
Upstream release cadence therefore never reaches us on its own, which is precisely why
**a standing measurement against current upstream is required** rather than optional —
see [the drift check](#checking-for-drift-against-current-upstream).


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


# Power: what does throttling cost?

**Down to ~250 W, throttling is practically free — 2.7 % of generation speed. Even at
197 W, 29 % below stock, it costs 8.5 %. Efficiency improves down to a minimum at a
1200 MHz clock ceiling — 1.70 W per tok/s against 2.54 at stock — and gets worse again
below that.**

Measured on [System A v1.0](../SYSTEMS.md#system-a), quiet BIOS, on a
factory-overclocked RX 7900 XTX.

## The curve

`llama-bench -p 2048 -n 128 -r 3`, power sampled every 2 s during the run.

| Setting | Power, mean | SCLK reached | pp2048 | tg128 | Δ pp | Δ tg | **W per tok/s** |
|---|---:|---:|---:|---:|---:|---:|---:|
| **291 W (stock)** | 276 W | 2733 MHz | 2713.9 | 108.47 | — | — | 2.54 |
| 280 W | ~279 W ⚠️ | 2655 MHz | 2687.0 | 107.94 | −1.0 % | −0.5 % | — |
| 270 W | 268 W | 2582 MHz | 2645.7 | 108.00 | −2.5 % | −0.4 % | 2.48 |
| 261 W (card minimum) | 259 W | 2553 MHz | 2608.4 | 106.45 | −3.9 % | −1.9 % | 2.43 |
| **261 W + clock ≤ 2400** | **247 W** | 2442 MHz | 2597.3 | 105.49 | −4.3 % | **−2.7 %** | 2.34 |
| **261 W + clock ≤ 2000** | **197 W** | 2050 MHz | 2215.5 | 99.26 | −18.4 % | **−8.5 %** | **1.98** |
| **261 W + clock ≤ 1600** | **159 W** | 1637 MHz | 1788.9 | 91.86 | −34.1 % | **−15.3 %** | **1.73** |
| 261 W + clock ≤ 1400 | 149 W | 1439 MHz | 1568.3 | 86.68 | −42.2 % | −20.1 % | 1.71 |
| **261 W + clock ≤ 1200** | **140 W** | 1231 MHz | 1352.0 | 82.14 | −50.2 % | −24.3 % | **1.70** ← best |
| 261 W + clock ≤ 1000 | 129 W | 1029 MHz | 1132.4 | 72.16 | −58.3 % | −33.5 % | 1.79 |
| 261 W + clock ≤ 800 | **114 W** | 820 MHz | 908.0 | 59.12 | −66.6 % | **−45.5 %** | 1.93 |

⚠️ The 280 W mean is a sampling artifact — too few samples landed under load. Its peak
is sound, its mean is not.

**Generation is insensitive to throttling — but only in the upper half of the range.**
At 1637 MHz it still delivers 85 % of throughput, which is why overclocking the core did
nothing: generation is bandwidth-bound, and a core clock ceiling does not touch the
memory clock. **That stops holding below ~1600 MHz.** At 820 MHz generation is down to
**54 %**, and the loss per MHz is steepest at the bottom. Bandwidth is the limit until
the core becomes one.

### There is an optimum, and it sits at 1200 MHz

**This corrects an earlier claim in this file.** The curve previously stopped at 1600 MHz
— the lowest step tried at the time — and reported efficiency as improving monotonically
with no turning point. Extending it four steps further finds the turn:

| Ceiling | W per tok/s | pp2048 per W |
|---|---:|---:|
| 2000 MHz | 1.99 | **11.25** |
| 1600 MHz | 1.73 | **11.25** |
| 1400 MHz | 1.71 | 10.55 |
| **1200 MHz** | **1.70** | 9.68 |
| 1000 MHz | 1.79 | 8.79 |
| 800 MHz | 1.93 | 7.94 |

**Below 1200 MHz you buy nothing.** At 800 MHz efficiency is back where 2000 MHz was,
having given up 40 % of generation throughput to get there. The floor exists because
memory clock stays at 1250 MHz on every step — that power is constant, so as the core
slows it is amortised over fewer and fewer tokens.

**Prefill turns earlier than generation**: it is flat from 2000 to 1600 MHz and declines
from 1400 down. Weighted for a RAG workload, where prefill dominates the token count,
**the useful floor is 1600 MHz, not 1200.**

⚠️ **The new rows integrate power over the compute window only**; how the original rows
were integrated is not recorded. If the old rows included idle time, their watt figures
are understated and their efficiency flattered — which would make the published
monotonic claim *more* wrong, not less. **The turning point itself lies entirely within
the four new rows, all measured identically**, so it does not depend on the join.

Four stock measurements were interleaved through the run as a drift control:
**108.33 / 107.61 / 108.45 / 108.55 tok/s.** No kernel messages on any step.

Two further steps close the curve at the bottom:

| Ceiling | Power | tg128 | W per tok/s |
|---|---:|---:|---:|
| 800 MHz | 114.3 W | 59.12 | 1.933 |
| **600 MHz** | **96.8 W** | 45.96 | 2.106 |
| **500 MHz** | **84.5 W** | 38.50 | 2.195 |
| stock control, same session | 290.3 W | 107.96 | 2.688 |

**84.5 W is the floor reached here**, and efficiency keeps worsening all the way down —
2.195 W per tok/s against 1.700 at the 1 200 MHz optimum. The turning point identified
above now has four steps below it rather than one, and it holds.

The memory clock is a different matter — see the next section.

### The memory clock is not a knob you can turn down

The arithmetic above points at the memory clock: it is fixed at 1250 MHz on every core
step, so its power is constant and is what makes the curve turn back upwards. Lowering
it is the obvious next experiment. **It took the card off the PCIe bus.**

The run completed its stock control normally — pp2048 2734.3, tg128 108.94, 290.8 W,
output hash identical to a pre-run reference. It then set a 1000 MHz memory ceiling and
started the next benchmark. The machine died within a second: no panic, no GPU reset
message, the journal simply stops. CPU load was observed at 100 % as it went.

After the automatic reboot the card was **gone** — zero AMD devices on the bus, the x16
slot reporting `LnkSta: Width x0`, and `amdgpu` loading with no GPU to attach to. A PCI
rescan did not recover it, and neither did a second warm reboot. **Only pulling mains
power brought it back**, after which it enumerated at full 16 GT/s x16 with 23 GiB and
reproduced the reference hash bit-for-bit. No damage.

**The direction that looked safe is the dangerous one.** Raising the memory clock to
1450 MHz cost a GPU reset that the card survived and reported cleanly. Lowering it cost
the card's presence on the bus, silently, with nothing in the log to attribute it.

| | Result | Recoverable by |
|---|---|---|
| Memory clock **up** to 1450 MHz | GPU reset, `VRAM is lost` in the log | itself |
| Memory clock **down** to 1000 MHz | card off the bus, no log entry | **mains power only** |

**This axis is closed here.** Not "approach carefully" — the knob has no safe working
range downwards on this card, the failure gives no warning, and recovery needs physical
access. The core-clock curve already found its optimum without it.

⚠️ **If you repeat this, do not do it on a machine you cannot reach.** Everything else in
this repository recovers from a bad step by itself.

## The load case that counts — under production flags

The curve above is `llama-bench`, which measures without KV quantization and without
`--parallel`. Under production flags one 9B model collapses by a factor of 6.8, so the
same question was asked again on a real RAG turn: 6416 prompt tokens plus a 400-token
answer, three runs each.

| Operating point | Wall clock | Power under load | Time cost | Power saved |
|---|---:|---:|---:|---:|
| **Stock, 291 W** | 6.72 / 6.72 / 6.73 s | 286 W | — | — |
| **261 W + clock ≤ 2400** | 7.02 / 7.00 / 7.05 s | **230 W** | **+4.2 %** | **−20 %** |
| **261 W + clock ≤ 2000** | 7.71 / 7.74 / 7.74 s | **183 W** | +14.9 % | **−36 %** |

**The loss is smaller than the synthetic curve suggests.** There the 2000 MHz step cost
18.4 % of prompt processing; in a real turn it is 14.9 % of total time, because prefill
and generation mix and generation barely suffers.

**Recommended for continuous operation: 261 W + a 2400 MHz ceiling.** A fifth less
power for 4.2 % more waiting is a good trade for a card that runs around the clock.

## At the wall socket — the number that pays the bill

Everything above comes from the card's own sensor. A meter was put on the socket —
**Refoss-P11 running Tasmota 15.3.0.3** — and each state held under load for three
minutes. Baseline of the power strip without the machine: 3 W.

> **Declared tolerance: ±10 W.** These are consumer smart plugs, not laboratory
> instruments. Any socket difference below 10 W is treated as noise and is not a
> result. Everything reported below clears that bar by a wide margin — except one
> finding, which is marked where it appears.

| State | Card sensor | **Wall socket** | Saved at the socket |
|---|---:|---:|---:|
| **Idle** (booted, nothing loaded) | 7–22 W | **56 W** | — |
| Stock under sustained load | 252 W median | **390 W** | — |
| **261 W + clock ≤ 2400** | 224 W median | **344 W** | **−46 W (−11.8 %)** |
| **261 W + clock ≤ 2000** | 184 W median | **272 W** | **−118 W (−30.3 %)** |

⚠️ **This corrected an expectation.** The saving was assumed to come out *smaller* at
the socket, since CPU and base load continue unchanged. **The opposite is true** — the
card sensor reports 28 W saved on the first step, the socket shows 46 W. Factor 1.6.

## The AMD sensor under-reports. The NVIDIA one does not.

Cross-check on the RTX 2070, same load, two power limits, measured at the card and at
the socket simultaneously:

| | Socket, increase over idle | `nvidia-smi` | Ratio |
|---|---:|---:|---:|
| 2070 @ 225 W limit | 188 W | 194 W | 1.03 |
| 2070 @ 125 W limit | 111 W | 115 W | 1.04 |
| **Difference between the two** | **77 W** | **79 W** | **0.98** |

Same arithmetic for the AMD card: idle 56 W, sustained load 390 W at the socket —
**334 W of increase**, while `power1_average` reported **252 W**. The AMD sensor shows
about **three quarters** of the real increase.

`power1_average` measures the graphics chip, not the board: memory chips and VRMs are
extra, and power supply losses on top.

**Consequence: on the NVIDIA card `nvidia-smi` is enough. On the AMD card a socket
meter is not optional** — reading only the card sensor understates any power statement
by roughly a quarter.

## Idle is the bigger lever than anything under load

The card draws **7–22 W with no load**, and the whole machine idles at **56 W**.

That is ~490 kWh a year, and it accrues whether or not anything is computed. The
throttling above saves 46 W, but only during actual load. **Switching a throttle
between "someone is waiting" and "nobody is waiting" saves nothing** — tie it to the
*kind* of load (background/batch versus interactive) instead.

**For comparison, the machine sitting in its BIOS draws 132 W** — more than twice the
Linux idle. Rebooting for hardware work and leaving it there is expensive.

## Efficiency per token, and why the slow card still earns its slot

| | Increase at the socket | tg128 | **W per tok/s** |
|---|---:|---:|---:|
| RX 7900 XTX, stock | 334 W | 108.5 | **3.08** |
| RTX 2070, 225 W limit | 188 W | 49.7 | **3.78** |

The AMD card is **2.2× faster at 1.8× the power**, so about 19 % more efficient per
token. The 2070 earns its place anyway — not on efficiency, but because it takes load
off a card whose 24 GB would otherwise be occupied.

### It cannot be powered down when idle

Measured while the card was still running under `nouveau`; it uses the proprietary
driver now, and this was not repeated. Attempt to isolate its consumption by unbinding
the driver and suspending the device:

| | Socket |
|---|---:|
| 2070 with `nouveau` | 58 W |
| 2070 **without a driver**, device reported "suspended" | **68 W** |

⚠️ **This one sits exactly on the ±10 W tolerance and does not clear it.** The
difference is 10 W on consumer plugs, so as a measurement it is at best suggestive.

What it does establish is the **direction**: removing the driver certainly did not
save anything, which was the question. The mechanism is plausible — `nouveau` cannot
reclock Turing cards with GSP firmware but evidently applies clock gating, and with no
driver the card keeps running in its power-on state, with the reported suspend being
nominal only (`power_state` reads `unknown`). **Plausible is not measured**, and this
one would need a repeat or a better instrument to claim.

Either way: **removing the driver is not a saving strategy.** The 2070's standalone
draw remains unquantified — doing that properly means pulling the card and
re-measuring.

## The dual BIOS: quiet wins

| | Quiet | Performance |
|---|---:|---:|
| Prefill (pp2048) | 816.99 | 840.57 (+2.9 %) |
| Generation (tg3000) | 38.70 ± 0.06 | 37.67 ± 1.36 (noise) |
| Power, mean / peak | 258 / 291 W | **292 / 339 W** |
| Fan | 1211 rpm | 1553 rpm |

**13 % more power for 3 % more prefill and nothing on generation.** On a realistic RAG
case (4000-token prompt, 500-token answer) the performance BIOS is actually
*marginally slower* — 18.03 s against 17.82 s.

The two differ almost only in the power limit: `power1_cap_default` 339 W against
291 W, core clock 2990 against 2945 MHz. **Memory clock is 1250 MHz in both** — which,
generation being bandwidth-bound, is exactly why generation does not move.

**Quiet is the correct setting**, and it independently confirms the main finding: this
card is power-limited, and headroom on the power limit does not buy throughput.

## Overclocking: measured, rejected

| Setting | tg128 (tok/s) | vs stock |
|---|---:|---:|
| Stock (three runs, interleaved) | 108.55 / 108.63 / 109.04 | — |
| **Memory clock 1400 MHz only** | **115.76 / 114.64** | **+5.9 %** |
| Core clock 3300 MHz only | 109.30 / 109.01 | ±0 |
| Both | 114.61 / 115.23 / 115.71 | +5.9 % |
| Memory clock 1450 MHz | — | **GPU reset, `VRAM is lost`** |

Stock and combination runs were **interleaved**, so drift from warming or driver state
could not pass as an effect.

**The entire gain comes from the memory clock.** Core clock alone does nothing, and
the combination is no better than memory clock alone — consistent with generation
being bandwidth-bound.

Fifty MHz of margin between "worth discussing" and "the card resets".

**The card is electrically limited, not thermally** — 336 W drawn against a 291 W
limit, at 62 °C maximum. Raising the limit to 334 W buys +219 MHz of achieved clock,
**+0.5 % generation and nothing on prefill.** 60 W for nothing.

The small headroom was predictable: this is a factory-overclocked board with a
3000 MHz factory clock against roughly 2500 MHz reference. What was measured is not the
headroom over spec — it is what the factory left.

### The most important part is not the result

**A pure throughput test would have passed the broken step.** At 1450 MHz prefill and
generation looked entirely normal — while the card had already reset itself.

**Instability shows up in inference as wrong tokens, not as a crash.** The harness
therefore also compares generated text exactly and reads the kernel log after every
step. See
[METHODOLOGY.md](../METHODOLOGY.md#a-throughput-test-will-pass-a-broken-card).

## How to set it

`power1_cap` is in microwatts under `/sys/class/drm/cardN/device/hwmon/hwmon*/`.
**The card will not go below 261 W this way** (`power1_cap_min` = 261000000). Lower
requires a core clock ceiling:

```bash
K=/sys/class/drm/card1/device
HW=$(echo $K/hwmon/hwmon*/ | cut -d" " -f1)
echo 261000000 > $HW/power1_cap
echo manual    > $K/power_dpm_force_performance_level
echo "s 1 2000" > $K/pp_od_clk_voltage
echo c          > $K/pp_od_clk_voltage
```

Back:

```bash
echo r    > $K/pp_od_clk_voltage
echo c    > $K/pp_od_clk_voltage
echo auto > $K/power_dpm_force_performance_level
echo 291000000 > $HW/power1_cap
```

The clock ceiling needs OverDrive — `amdgpu.ppfeaturemask=0xffffffff` on the kernel
command line. **None of it survives a reboot or a GPU reset.** For continuous
operation it belongs in a systemd unit or a udev rule.

## Conditions

Temperature was never a factor: 52–56 °C across every step, and 54 °C even at a raised
351 W peak.

All of the above is the **quiet BIOS**. On the performance BIOS the limits sit higher
and the curve shifts; the percentages here apply to this profile.

## Tokens per watt-hour, per phase

**Under load this card draws 255–290 W no matter which model is resident.** Power is
not a model property here, so energy per token is throughput and nothing else. The
consequences are all in the second column: a generated token costs **19–30×** a read
token, and the spread between the best and worst model at generation is **6.9×**.

Nine models, `llama-bench -p 4096 -n 0` and `-p 0 -n 512`, `-r 5`, one fresh process
per measurement, card verified empty beforehand. Card sensor only — see the caveat
below. Full table in [`data/energy_tokens.tsv`](../data/energy_tokens.tsv).

| Model | Size | **Prefill, tok/Wh** | **Generation, tok/Wh** | W under load |
|---|---:|---:|---:|---:|
| Llama-3.2-3B | 1.87 GiB | **99 668** ⚠️ | **3 304** | 267 |
| Qwen3.8-27B · dense | 15.60 | 10 566 | **480** | 288 |
| gpt-oss-20B · MoE | 11.27 | 51 235 | 2 729 | 272 |
| Qwen3-30B-A3B · MoE | 17.28 | 36 138 | **2 501** | 278 |
| Qwen3-Coder-30B-A3B · MoE | 17.28 | 37 349 | 2 498 | 256 |
| Nanbeige-4.2-3B · looped | 2.50 | 36 056 | 1 704 | 277 |
| Qwen3.5-9B | 5.28 | 36 031 | 1 401 | 280 |
| DeepSeek-R1-14B | 8.37 | 19 395 | 987 | 291 |
| Gemma-4-12B | 6.62 | 21 023 | 969 | 285 |
| Qwen3.6-27B | 15.65 | 10 564 | **481** | 289 |

⚠️ The Llama-3.2-3B prefill row rests on **4 power samples** at 1 Hz over 3.3 s, and its
227.8 W mean is visibly below the 285–290 W every other row reports. The token figure is
correspondingly optimistic. Rows with fewer than ~8 samples are indicative only; the
`samples` column in the data file is there to be read.

### MoE wins on energy, and it is not because it draws less

**Qwen3-30B-A3B against Qwen3.6-27B is the cleanest pair in the table**: near-identical
file size (17.3 against 15.7 GiB), near-identical power (278 against 289 W), and
**5.2× the tokens per watt-hour.** Only ~3B parameters are active per token, so the card
does a fraction of the work for the same electricity. The energy result is the
throughput result — it carries no separate information, and that is itself the finding.

**Dense size is what costs.** Every dense model lands where its parameter count puts it,
and the 27B is last by a wide margin.

### The looped 3B does not buy back its loop

Nanbeige-4.2-3B is a 2.50 GiB model that generates at 1 704 tok/Wh — only **22 % better
than a 9B** at 40 % of the footprint, where a normal 3B of the same size manages
3 304. **The doubled layer passes cost roughly half the energy advantage of being
small.** It also runs the card at 277 W, in the middle of the field — the loop keeps the
card as busy as anything else does.

### Reading a token is cheap; writing one is not

| Model | Generated token costs |
|---|---:|
| Llama-3.2-3B | 30× a read token |
| Qwen3.5-9B | 26× |
| Qwen3.6-27B | 22× |
| Qwen3-30B-A3B | 14× |

**For RAG this is the whole argument for a long context.** Stuffing 4 000 more tokens of
retrieved passages into a prompt costs about as much energy as 150–280 generated tokens.
Retrieval is cheap; verbosity is not.

⚠️ **Card sensor only.** These figures come from `power1_average`, which
[under-reports the real increase by about a quarter](#the-amd-sensor-under-reports-the-nvidia-one-does-not).
Use them to compare models with each other. The socket figure is the still-open half of
this measurement.

⚠️ **This section was rewritten after publication.** The first version reported the two
MoE models at 112–116 W and called low power an architecture property. It was an
artifact: the power trace covered model loading as well as computing, and a 17 GB model
loads for ~28 s while the card idles. See
[METHODOLOGY](../METHODOLOGY.md#the-measurement-window-must-contain-only-the-work-you-are-counting).

## Still open: watt-hours per completed task

The `W per tok/s` column above is a partial answer to "what does this cost to run" —
partial because it comes from the card sensor, which under-reports by about a quarter
here. The next series measures at the socket and reports **two figures side by side**,
because they answer different questions and neither replaces the other:

| Figure | Question it answers | What it is blind to |
|---|---|---|
| **Tokens per watt-hour** | How efficient is the *hardware* at producing tokens? | Whether the tokens were worth producing — it rewards verbosity |
| **Watt-hours per completed task** | What does one finished answer *cost*? | Nothing about throughput; a slow-but-terse model can win |

The pair is the point. A model that writes 26 085 tokens for a task others solve in a
few hundred — [one did](../use-cases/coding.md) — scores well on the first and badly on
the second, and the gap between the two columns is exactly the verbosity tax.

**Both instruments logged in parallel**, not one or the other:

| Instrument | What it sees | Known behaviour |
|---|---|---|
| `power1_average` (AMD) | graphics chip only | under-reports the real increase by ~25 % |
| `nvidia-smi` (RTX 2070) | board | accurate to within 3–4 % of the socket |
| **Smart plug at the wall** — SONOFF Matter-over-WiFi switch, fw 1.0, read via Home Assistant | whole machine, incl. CPU and PSU losses | slow — only meaningful under sustained load |

Running both means the card sensor stays usable as a **per-GPU** signal (the socket
cannot separate two cards in one machine) while the socket supplies the figure that
matches the electricity bill — and the ratio between them stays visible instead of
being assumed.

⚠️ **The socket meter is not the same device across this repository.**

| Series | Meter |
|---|---|
| 2026-07-28 (all socket figures above) | Refoss-P11, Tasmota 15.3.0.3 |
| From the next series onwards | SONOFF Matter-over-WiFi switch, fw 1.0, via Home Assistant |

Absolute figures from the two are not interchangeable. The new series has to establish
its own idle baseline rather than continue the old numbers — **and the two meters
should be cross-checked once against each other on the same load before either is
trusted.** We already know from `power1_average` that a plausible-looking instrument
can be 25 % off; there is no evidence yet that these two agree.

That cross-check has a complication worth planning around: **the old meter has since
been moved to a different room and a different load.** Comparing them means bringing
them back together deliberately, not reading two historical logs.

Measured across the throttle steps **and** across models, so both the hardware axis and
the model axis are covered.

## Scripts

- [`scripts/hardware/rag_turn.sh`](../scripts/hardware/rag_turn.sh) — the real RAG turn,
  with power sampled *during* the request rather than after it

The overclocking and socket-measurement harnesses are not published yet — both are
tied to this card's sysfs paths and to a specific smart plug.

# Bandwidth against generation rate

`bandbreite_vs_erzeugung.tsv` — the same file, the same command, the same llama.cpp build
and the same driver on different cards. The card is the only variable.

```
llama-bench -m Llama-3.2-3B-Instruct-Q4_K_M.gguf -n 128 -p 512,4096 -pg 4096,128 -ngl 99 -r 20
build 70adb1b · Vulkan · driver 610.57.04
```

## Two measurements of the same card, and why both are here

The RTX 3080 sits in the development machine, and the first run had the desktop session on
the card: 2 620 MiB held, 22 % baseline load. The second ran after closing most
applications, 1 405 MiB.

| | with desktop | cleaned up |
|---|---|---|
| tg128 | 203.20 ± **15.55** | 218.90 ± **0.77** |
| pp512 | 8 734 ± **1 244** | 8 269 ± **143** |

**The spread drops twentyfold and the value rises 7.7 %.** That is the price of a busy
card, quantified — and the reason the cleaned-up run is the valid one.

It remains a **lower bound**: 1 405 MiB of desktop still sat on the card. That does not
weaken the finding, it strengthens it — the 3080 loses despite the handicap being on the
other side.

⚠️ **No raw data survives from the first measurement.** It was deleted on a "discard"
before it was decided that it should stay as a comparison point; only the averages from
the run's output remain. **Discarded measurements belong marked, not removed** — otherwise
exactly the evidence one later needs is the one that is gone.

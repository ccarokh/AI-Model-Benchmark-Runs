# The chains that drove System C

The borrowed RTX 4070 Super was measured by the Python suite in
[`scripts/testbench/`](../../testbench/), but nothing in the suite decides *when* to run
or *what comes next*. These are the shell scripts that did, kept because the results in
[`system-c-rtx4070-super.tsv`](../../../data/testbench/system-c-rtx4070-super.tsv) cannot
be traced without them.

| Script | What it drove |
|---|---|
| `hole_modelle.sh` | fetched the model store the whole series ran against |
| `nacht_101.sh` | the first night: wait for the downloads, then the suite |
| `qualitaet_101.sh` | belebele over the quantisation arms, two harnesses, n=900 |
| `nacht2_101.sh` | the fourth arm — requantise, measure, then belebele the rest of the store |
| `kette_101.sh`, `kette_26.sh`, `kette_27.sh` | one test after another, so the card never sat idle between them |
| `queue_probe.py` | the first look at more users than slots, before it became a test |

Each of them waits for the previous one instead of being scheduled, because **twice this
card sat idle for hours after something finished and nothing followed it**. That is also
their limitation: a chain that waits cannot start, so the card still stood still every
time a chain ran out.

`qualitaet_101.sh` carries the reason both belebele stands are always run: read as a
letter probability the QAT arm scored 35 % — barely above guessing — while answering
freely it scored 90 % on the same twenty questions, because the model thinks first.

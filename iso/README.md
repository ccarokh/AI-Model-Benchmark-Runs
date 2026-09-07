# A live ISO that turns a borrowed PC into a bench target

Somebody lends a graphics card that is bolted into their own machine. This builds a USB stick they boot, and from then on that machine answers to `bench` like any other target here.

**Nothing is installed and nothing is written to their disks.** The system runs from the stick into RAM. Pull it out, reboot, and their Windows or Linux comes back exactly as it was. That is not a nicety — it is the only arrangement a person agrees to when the machine is theirs.

## What the borrowed machine does on its own

1. Builds a **WireGuard tunnel outwards** to the hub. It sits behind a router nobody here controls, so nothing can reach in; the connection only ever goes the other way.
2. **Downloads the model files** over its own connection (`journalctl -fu fetch-models`). Resumable, and it checks size against the source rather than trusting that a file exists.
3. **Waits.** It measures nothing until somebody asks it to.

## What you do

```bash
cp iso/iso.conf.example iso/iso.conf   # then fill it in -- it is not in git
python3 iso/build.py
```

The build prints a WireGuard public key at the end. **Add that peer to the hub before handing over the stick**, with `AllowedIPs` set to the single guest address. Removing the peer afterwards is what revokes the access — there is no other door.

Write the ISO to a stick, then measure:

```bash
# ~/.config/bench/bench.conf
[target]
target = root@10.10.0.90

bench status
bench run reference
```

## What the person with the machine does

Boot from the stick, and nothing else. Two things worth telling them beforehand:

- **Secure Boot has to be off** in the BIOS, or the NVIDIA module will not load.
- **A run pulls real power for hours.** Their electricity, their decision when to stop — shutting the machine down is always allowed and costs nothing but a repeat.

## Why the version is pinned

`llama_cpp_ref` in the config is the build behind every `llama-bench` number in [`data/testbench/`](../data/testbench/). Measuring a borrowed card on a different version compares versions, not cards — and the card is the entire reason for borrowing it. The build is compiled once and cached under `iso/cache/`.

Vulkan, not CUDA, for the same reason: it is the one backend measured on all three machines here, so it is the only one whose numbers stand next to the existing rows.

## There is no secret in the image

The machine generates its own WireGuard key on first boot and shows the public half on screen — as text and as a QR code, so reading it back is a photograph rather than twenty transcribed characters. Everything the image carries is public: a hub address, a hub public key, an SSH public key.

Two things follow. The private key never leaves the machine that uses it, which is the rule every other host in this project already follows. And **the ISO itself is not a credential** — it can be rebuilt, copied, and handed to the next person with a card. Access is granted per machine by adding one peer, and revoked by removing it.

The tunnel cannot come up before that peer exists, so it retries every 30 seconds and the machine simply waits. That is the normal state after boot, not a fault.

## Why not encrypt a key to the borrower's public key

Because there is nothing to encrypt. That pattern is the right one when a secret genuinely has to travel — and this design removes the secret from the journey instead. It would also cost the borrower an `age` or GPG setup and a second artefact to handle, in exchange for a round trip they still have to make.

The one design that needs no message back at all is a single-use enrolment token in the image plus a registration endpoint at the hub, which the machine calls with its own fresh public key. That is worth building if borrowed cards become a habit rather than a one-off; it is infrastructure, not a config change.

## What a borrowed card is worth

Generation rate scales almost exactly with memory bandwidth — [the most direct confirmation in this repository](../foreign/geerlingguy-ai-benchmarks.md#generation-scales-with-memory-bandwidth-almost-exactly) puts two cards within 7 % of their bandwidth ratio. Every additional card is another point on that line, and the ones that fall off it are the interesting ones.

The reference workload (`-p 2048 -n 128 -r 5 -ngl 99`, upstream's own flags) is what carries that comparison, which is why it is the first model in the default list.

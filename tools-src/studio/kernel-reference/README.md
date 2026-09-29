---
title: "World kernel - the integer reference and the conformance check"
created: 2026-09-29
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio
status: done; the GDScript kernel passes on the PC and on the Galaxy S10
next_step: W3 (the deep village) builds on the kernel; any rule change goes through kernel.mjs and golden.mjs first
---

# The world kernel: reference and conformance

The world is a pure function of (seed, years, action log). Two implementations must agree exactly:

| | Where | Role |
|---|---|---|
| **The reference** (JavaScript) | `kernel.mjs` here | The spec: short, readable, and quick to change |
| **The kernel** (GDScript) | `game/scripts/studio/kernel/` | What runs in the game, on every phone |

```
 kernel.mjs ──node golden.mjs──► game/scripts/studio/kernel/golden.gd  (expected hashes)
                             └─► chronicle-js.txt                      (expected chronicle text)
 world.gd + history.gd ──run.gd --conform──► PASS / first year where the worlds part
```

## Why two implementations `[design]`

- **A port can repeat itself and still be wrong.** The same code on two phones proves determinism, not correctness. Two independent implementations that agree on every checkpoint make a port bug show up as the first 25-year window where they part.
- **Floats drift between phone chips** (fused multiply-add, differing maths libraries). Both implementations use integers only:
  - chances in parts per million, multipliers per mille, map positions in tenths;
  - no square roots except an integer table;
  - hashes kept inside 32 bits.
- **A server could replay the world later.** The Nakama runtime can run JavaScript, so this file can check a shared world without a phone.

## How to change the rules

1. Edit `kernel.mjs`.
2. Run `node experiments.mjs` to see the behaviour: growth, edits to the past, storms.
3. Run `node golden.mjs` to write new expected values.
4. Make the same change in `world.gd`.
5. Run:
   ```
   godot --headless --path game --script res://scripts/studio/kernel/run.gd -- --conform
   ```
   It must print `CONFORMANCE: PASS`.

## Results so far `[run]` (29 Sep 2026)

| Check | Result |
|---|---|
| The integer reference against the float prototype (`experiments-results.txt`) | The same behaviour: an edit to the past changes 21% of villages noticeably, the same as the prototype. The prototype's Holtorfen storm replays almost line for line |
| GDScript against the reference, PC (Windows, Ryzen 7 5800U) | 420 / 420 checkpoint hashes; 4 / 4 scenarios; the chronicle identical line for line (4,276 lines) |
| Speed, PC | 500 years: ~172 ms median in GDScript, 12 ms in JavaScript (Node) |
| Galaxy S10 (ARM64), debug build | 420 / 420, 4 / 4, chronicle hash identical; 500 years in 367 ms median (worst 679 ms). Run non-stop on a worker thread during play, the game held 30 fps (details: `docs/studio/KERNEL-S2.md`) |

## Files

- `kernel.mjs`: the reference.
- `golden.mjs`: writes the expected values.
- `experiments.mjs`: the S1 experiments re-run on integers.
- `experiments-results.txt`: their output.
- `chronicle-js.txt`: seed 1000's chronicle.
- The prototype it came from: `../kernel-prototype/` (floats; kept as the record).

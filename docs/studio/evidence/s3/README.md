---
title: "S3 - what a living village costs: villager decisions and crowds, on the PC and the Galaxy S10"
created: 2026-09-29
type: agent-draft
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: done - evidence for docs/studio/VILLAGE-PLAN.md
next_step: M2a reruns the crowd benchmark after the villager mesh merge, near-only shadows and animation throttling
---

# S3: what a living village costs

**Code** (on the studio branch):
- `game/scripts/studio/village/decision_bench.gd` and `crowd_bench.gd`;
- the runner `game/scripts/studio/run.gd`;
- on phones, the dev argument `--studio=<name>`.

## 1. Villager decisions `[run]`

A stand-in for the planned decision layer:
- 30 villagers;
- 16 actions × 4 considerations, with integer response curves as lookup tables;
- 4 of the actions choose a target among all 30 villagers;
- a rumour step;
- a heap reschedule.

| | PC (Ryzen 7 5800U) | Galaxy S10 (debug build) |
|---|---|---|
| One decision | 35.9 µs (27 per ms) | **70.0 µs** (14 per ms) |
| A village day, 24 decisions each | 25.8 ms | 50.4 ms |
| A village year (the same) | 9.4 s | 18.4 s |
| 30 days away, catching up (the same) | 0.77 s | 1.51 s |

**What it means** (the numbers above are measured; the reading is ours) `[design]`:
- **Live play is nearly free.** A game day lasts 12 real minutes, so 30 villagers deciding hourly make about one decision per real second.
- **Catch-up is the cost.** Dawn plans plus replans (about 6 decisions per villager per day) bring 30 days to about 0.4 s on the S10.
- **Testing thousands of simulated years** needs the JavaScript reference in Node. GDScript on the PC would take 9 s per village-year.

## 2. Crowds of Enea's own characters (CharacterVisual), tilted camera, walking `[run]`

| Villagers | PC: median / worst, draws | S10: median / 95th / worst, draws |
|---|---|---|
| 0 | 33.4 / 36.3 ms, 287 | 33.3 / 37.6 / 42.7 ms, 286 |
| 10 | 33.3 / 36.3 ms, 717 | 33.4 / 36.7 / 168.3 ms (first-spawn stutter), 732 |
| 20 | 33.3 / 35.7 ms, 1,095 | **33.2 / 36.5 / 39.8 ms**, 1,090 |
| 30 | 33.3 / 36.7 ms, 1,394 | 39.7 / 44.9 / 54.0 ms, 1,395 |
| 45 | 33.2 / 59.6 ms, 2,107 | 66.2 / 72.6 / 92.8 ms, 2,082 |
| 60 | 41.1 / 70.6 ms, 2,855 | 98.6 / 107.4 / 109.4 ms, 2,840 |

**What drives the cost on the S10** (median frame; 30 and 45 villagers) `[run]`:

| Variant | 30 villagers | 45 villagers |
|---|---|---|
| Full | 39.7 ms (1,395 draws) | 66.2 ms (2,082 draws) |
| Villagers cast no shadows | **33.2 ms** (870 draws) | 46.3 ms (1,212 draws) |
| Animation frozen (no skeleton updates) | 34.2 ms (1,471 draws) | 56.6 ms (2,113 draws) |

**Reading** `[design]`:
- **Each character costs about 40 draw calls,** because every outfit part is its own mesh, drawn again for shadows. On the S10, a draw call costs about 23 µs ((66.2 - 46.3) ms over 870 draws).
- **Animation costs about 0.2 ms per villager** at full rate.
- **Today the S10 holds 30 fps with about 20 walking villagers.**
- **No single fix reaches a 45-60 crowd.** It takes all four:
  - merge each villager into one mesh (about 40 draws down to 1-2);
  - shadows for the nearest dozen only;
  - animation throttled with distance;
  - a baked, instanced crowd for the back rows.
- **Estimate for a 60-person execution after all four:** about 430 draws and about 4 ms of animation, inside budget. M2a measures it.

Raw outputs are in this folder (`s10-*.txt`). The PC outputs are quoted above from the session.

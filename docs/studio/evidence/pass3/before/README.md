---
title: "Pass 3 baseline - how the villagers move today, in numbers and frames (the 'before')"
created: 2026-10-01
type: evidence
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: measured on pass3 a1ca032 plus the motion probe (stage 0); three runs, which agree to within a count or two
next_step: stage 1 is measured with the same probe (--people-probe=motion --people-targets=1); its board goes in ../after-1/ beside this one for Hilmi at M1
---

# How the villagers move today

**Verdict** `[run]`: by every sign the plan names, today's villagers move like a timetable, not like people.

| What an eye sees | Measured |
|---|---|
| A household leaves its door on the same frame and walks the whole way fused into one body (`shrine-1.0.jpg`) | 58 new body-through-body contacts a minute on the walk to the shrine. About 7 pairs are inside each other at any moment |
| Legs walk at 1.3 m/s while the body crawls | Cruising speeds of 0.31-1.0 m/s. Feet slide 86-100% of moving time |
| Everyone sets off together | 19 people within 0.00 s at nine (the shrine); 19 within 0.23 s at six (the evening walk) |
| Talkers queue along the path instead of standing in circles (`well-*.jpg`) | 6% of talkers stand in a circle; on average they stand 1.9 m from their group's centre |
| A struck villager snaps round to face the player but is not rocked by the blow | Body turned in 0.03-0.07 s; head moved on the body: never, never, 1.17 s |
| Up to three speech bubbles at once | 3 at once, one overlap. Widest 12% of the screen from the game's camera |

The full table is in the plan, section 6 (`plan/PASS-3-PLAN-2026-10-01.md` in the studio repository).

## The board

`sheet.jpg` has one row per window. The first column is the game's own camera (what the player sees); the next six are a camera 7 m off the busiest spot (or the person struck), half a second apart:

| Row | Window | When |
|---|---|---|
| shrine | the pious walk to the shrine | day 0 (a holy day), 09:00 |
| evening | the whole village walks from work to the evening's place | day 0, 18:00 |
| well | the evening talk at the well | day 0, 19:40 (dusk) |
| scene | a small scene the director brought near the player (a chat at the well) | day 1, around 12:35 |
| blow | the first of three blows, through the talk screen's fight | day 1, after the scene |

The frames are run 3's: the final probe code, every frame drawn live.

In run 2 the game window was minimised partway, and a minimised Godot window stops drawing: 21 frames were the same image. The probe now:
- puts its window back if it finds it minimised;
- fails the run when that happened;
- fails a sequence whose frames stop changing.

Run 2's numbers still stand: nothing they measure needs drawing, and they match runs 1 and 3.

## Files

- `sheet.jpg`, `<window>-<t>.jpg`: the board and its frames (run 3).
- `run1-motion.txt`, `run2-motion.txt`, `run3-motion.txt`: the probe's lines, `MOTION <window> {json}` per window (`people/motion_watch.gd` summary). Run 1 still counted the body's turn as the blow showing; runs 2 and 3 separate the two.

## How to run it again

```
godot --path game --resolution 1560x720 -- --studio=village/live --people-probe=motion --people-shots=<dir> --test-save=<unique>
godot --headless --path game --script <studio>/toolbox/lookboard/sheet.gd -- <dir> <dir>/motion-shots.txt
```

About six minutes, at real speed. The window must stay visible.

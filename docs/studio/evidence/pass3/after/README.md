---
title: "Pass 3 after stages 1-5 - how the villagers move now, in numbers and frames (the 'after')"
created: 2026-10-01
type: evidence
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: measured on pass3 6870d0c with the motion probe at --people-targets=5 (desktop, 30 fps cap); then on Hilmi's S24 Ultra at 60 fps on pass3 e0fc716 (section at the end)
next_step: Hilmi looks at this board beside ../before/ and at the game itself; his words decide, the numbers only say where to look
---

# How the villagers move now

**Verdict** `[run]`: every sign the plan names is at its target except one. Slow shuffling in the densest crowd, the holy-day arrival at the shrine, is exactly at the line (5%, target under 5%). Measured on the same probe and windows as `../before/`, plus a new window for daily life.

| What an eye sees | Before (`../before/`) | Now |
|---|---|---|
| Bodies walking through each other | 10-58 new contacts a minute | 0 in every window |
| Legs and ground speed out of step (feet sliding) | 86-100% of moving time | 2-5% |
| Walking at a pace nobody walks | 68-92% of walking time | 0-1% everywhere but the shrine crowd (5%) |
| Speed snapping; facing snapping (walking, standing) | 13-54; 17-48; 17-28 a minute | 0; 0; 0 |
| Everyone out of their doors at once | 19 within 0.00 s | departures spread over 8-58 s |
| Talkers in a circle, facing in | 6% (queued along the path, 1.9 m out) | 93-95% (0.6 m from the middle) |
| A blow rocks the struck | never, never, 1.17 s | 0.07 s, every blow |
| Listeners' heads on the speaker | 24% on anyone | 61-100% |
| Bubbles at once; overlapping | 3; 0-1 | at most 2 from our people; 0 overlapping |
| Standing about doing nothing (new) | not measured | 5-17% of standing time; nobody stands still for 15 s (statues 0%) |
| Standing in an awkward spot (new) | not measured | 0-1.4% |
| Meetings near the player (new) | none | 2-15 a minute, 2-5 kinds per window, no kind over half |
| The village's frame work (desktop) | p50 0.76-0.87 ms | p50 1.3-2.0 ms, p90 1.5-2.3 ms |

## The board

`sheet.jpg` has one row per window. The first column is the game's own camera (what the player sees); the next six are a camera 7 m off the busiest spot (or the person struck), half a second apart.

| Row | Window | When |
|---|---|---|
| shrine | the pious walk to the shrine (holy day) | day 0, 09:00 |
| life | daily life from the square: work, yards, children, meetings (new in stage 3) | day 0, 14:00 |
| evening | the whole village walks from work to the evening's place | day 0, 18:00 |
| well | the evening talk at the well | day 0, 19:40 (dusk) |
| scene | a small scene the director brought near the player | day 1 |
| blow | the first of three blows, through hold to fight | day 1, after the scene |

## Seen on the board, to pass on

- **A third bubble can show** (`well-game.jpg`: "Hm." beside two of ours). It is a greeting from one of Enea's own characters (`state/npcs.gd`). Enea's characters draw their own world-size bubbles (`world/npc.gd` `_label`), outside the speech manager. Routing them through it would be one marked hook in his file, but how his characters speak is his look. This is for Enea, through Hilmi.
- **The well at dusk is crowded:** 26 people on a narrow path between houses. The circles keep their shape (93%), but from the game camera they read as one crowd.
- **The close camera frames are from the probe,** at a 45° field of view, so a bubble's size there is not the size the player sees. The game camera's column is the true size.

## 60 fps on the S24 Ultra (pass3 e0fc716)

**Verdict** `[run]`: the phone holds 60 fps through every window - the median frame is 16.7 ms everywhere and the village's own work is about 2 ms of it. What remains is six borderline marks, one or two events each, listed below with their cause. Run 5 of 5 on the phone (`toolbox/device-lab/phone_session.sh`, probe build `p3probe-e0fc716.apk`, `fps_cap=60`, sound off, a fresh test save; his own save was kept and the normal build put back).

| Window | People | fps (mean) | Frame p50 / p90 / p99 ms | Village work p50 / p90 ms |
|---|---|---|---|---|
| shrine | 25 | 57.3 | 16.69 / 18.09 / 21.28 | 2.32 / 2.78 |
| life | 17 | 58.2 | 16.68 / 17.77 / 20.47 | 1.80 / 2.09 |
| evening | 29 | 56.9 | 16.69 / 17.72 / 21.68 | 2.04 / 2.38 |
| well | 26 | 57.8 | 16.68 / 17.58 / 20.55 | 2.04 / 2.35 |
| scene | 21 | 54.5 | 16.67 / 17.77 / 23.11 | 1.89 / 2.20 |
| blow | 20 | 54.0 | 16.88 / 18.27 / 30.59 | 2.06 / 2.59 |

The phone's skin went from 37.8 to 40.0 °C over the run `[run]`. The mean sits under 60 because a few long frames (p99) pull it down; the blow window's 30.6 ms p99 includes the strike's save (about 18 ms, still open).

**Held at 60 fps, every window** `[run]`: bodies through each other 0; feet sliding 2-5%; statues 0; awkward spots 0-1.1%; circles 90-96% (where a window has them); listeners' heads on the speaker 78-100%; evening departures spread over 19 s; a blow rocks the struck within 0.04-0.05 s, all three blows; at most 2 of our bubbles at once.

**Borderline in run 5, with the cause read from the trace** `[run]`:

| Mark | Value (target) | What happened |
|---|---|---|
| shrine: odd pace | 6% (< 5%) | the holy-day crowd on the narrow path, people slowing behind each other; 6-7% in every phone run (5% on desktop at 30 fps), so this one is steady, not chance |
| shrine: speed snap | 1 event | one walker shoved by a neighbour in the holy-day crowd (0.41 to 0.81 m/s within a few frames) |
| well: speed snap | 1 event | one walker shoved by a neighbour in the 26-person dusk crowd |
| blow: speed snap | 1 event | the probe walks the player into a villager on purpose; the villager now gives way at a step's pace (0.44 m/s, it was flung at 3.85) - the snap counter's line is 4 m/s², this was 4.4 |
| blow: villagers through the player | 1.7 a minute | the same bump: capping the shove means the player's collider takes the rest, so they overlap briefly; 0 on desktop |
| blow: one kind of meeting over half | 57% of 7 meetings | a short window with few meetings; 22-40% elsewhere |

They stay open as marks, not passes. Whether any of them shows at play speed is for Hilmi's eye on the phone, not for the counters.

**Phone board** (`phone/`): `phone/sheet.jpg`, one frame per window from the game's own camera on the phone, full size as `phone/phone-<window>.jpg`. Seen on it: the frame counter reads 60 fps, worst 17 ms at the well at dusk; the action button reads "Talk / hold: fight" beside a villager and "Attack" once the fight starts, with the target ring under the struck villager (`phone-blow.jpg`).

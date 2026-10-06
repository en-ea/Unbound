---
title: "People animation and rigging - built record"
created: 2026-10-03
type: build-record
voice: agent-draft
author: Claude, animation/rigging specialist
status: slices A and B built and engine-run (windows 3-5: 18/18 checks, before/after boards); 6c85349 answers the window 4 boards
next_step: integration takes 3942c7b..6c85349 (and this record) into the connected encounter; Body adds the player pose hud line
---

# People animation - built record

Outer plan: `plan/PEOPLE-ANIMATION-BUILD-2026-10-03.md`. Live handoff: outer `plan/handoffs/people-build/20261003/animation.md`.
Paths are nested-game-relative; `game/scripts/studio/` is `res://scripts/studio/`. Labels as in the studio: [repo] read
in code, [run] produced by running, [design] proposal.

## Look tool [repo]

`game/scripts/studio/people/animation_board.gd` (c8e2e5e): hidden filmstrips. One frame per row; column k began its
beat `offset` seconds before the capture. Rows impact, fall, fire, limp, fear, death. Elements play through Body's
runner with a fixture port. Run inside a granted heavy window through `capture_hidden.sh` with
`--studio=people/animation_board --board=<row> --shotframe=999999`. The frozen before is the detached worktree
`people-animation-before-c8e2e5e` (the base's body, pose and elements plus the board).

## Slice A: capability (d271053) [repo]

```
 facts ──Body's runner──> element.begin/step/end ──port.pose(key, fields)──> runner.layers
                                                                                 │ every frame (residents)
 Mind hints ──residents.express_body──> body.express(hints)          body.apply_elements(layers)
                                              │                                  │
                                              v                                  v
                         pose.gd: one SkeletonModifier3D per body       villager_body: posture lock, surface,
                         (expression, element layers, look, flinch)     gait, effects, flash
                                              │
                         TwoBoneIK3D wrist hold (pillory) runs after it: the last word on the arms
```

**pose.gd** - the one procedural controller. `set_layer(key, params, weight, fade)` / `clear_layer(key, fade)` /
`has_layer(key)`; params: spine, head (Vector3 pitch/roll/yaw), shoulders, reach_l/_r {bone, at, pole, priority}
(analytic two-bone reach in the body's axes), fist(_l/_r), breath Vector2(Hz, rad), tremble, flail, roll (pelvis),
knee_l/_r, apply Callable. Expression from Mind's S5 shape: `contraction(fear, show, steady)` draws a timid body in
(hunch, shoulders up, hands to chest, tremble, darting look); a bold one braces (chest up, fists, a locked, faster
look). Anger leans in. A fleeing body glances back past the neck's reach and a panicked runner throws its arms up.
Postures down/dead/carried turn the look off. `animating()` keeps a stepped far body advancing while it moves;
`idle()` lets the owner drop the modifier.

**villager_body.gd** - `hold_posture(name, clip, at, blend, rate, soft)` / `play_posture(name, clip, from, rate,
blend)` / `release_posture(name)` / `posture()`: while held, play_motion/play_loop/play_action leave the body alone
(nothing knocks a lying body back to idle); a later posture takes over and only its own name releases it.
`set_gait("limp")` plays `Walk_Limp`, derived at library build from `Zombie_Walk_Fwd`'s legs and `Walk`'s upper body
with the pelvis half way (1.333 s loop, 1.016 m/s native; no new binary). `set_surface(soot, ember)` on the body's own
material copy. `vocal(kind, strength)` emits `vocalized` and plays a PLACEHOLDER made of the body's talking blips
(no recorded cry exists). `express(hints)`: pose expression, idle rate (bold stillness, timid fretting), and a soft
timid cower (`Crouch_Idle` with hands over the head) that the next step ends. `apply_elements(layers)`: the single
consumer of Body's runner layers. Fields: pose params plus weight/fade; `posture` {name, clip, at|from, rate, blend,
soft} ranked dead > carried > down > cower; `surface` Vector2; `gait` "limp"; `still` (masks every other layer's
motion); `fx` {kind flames|smoke|steam, bone, at, size}; `flash` int.

**Checks:** `game/scripts/studio/people/animation_checks.gd` (11 lines: rig, derived limp, posture lock, layers,
reach, wrist hold last, one-file element, cleanup, element layers, equal fear, vocal hook):
`godot --headless --path game --script res://scripts/studio/run.gd -- people/animation_checks`. The one-file proof
is `people/proofs/elements/wince.gd`. Machinery only; the look is judged on the boards. [run] pending window 1.

## Slice B: the fact elements on Body's port (3942c7b, 6c85349) [repo]

Built over the named dependency ebf5e46. Every element is one file in `people/elements/`, posts only its own named
layers through `port.pose`/`drop_pose`, carries its active clock in each layer (`clock`), announces and cries only on
a fresh begin, and ends cleanly on removal. Shared clip placements and shapes: `people/gestures.gd`.

| Element | Fresh begin | Body | Rehydrated / blocked |
|---|---|---|---|
| impact (played) | grunt, flash | under 0.3 a rock; to 0.75 Hit_Chest/Hit_Head planted, arms out, Body's stagger backs away; from 0.75 throw only | never saved |
| down | announce fall (transition) + cry, cry | turns to face the source, Hit_Knockback scrubbed, lies breathing with a knee drawn, LayToIdle up when the fact ends (pain slows the squat); a carried body waits until set down, a corpse never rises | lying at once, silent; held upright: no posture, a sag |
| hurt | none | a hand to the hurt place (chest/belly/head/arm/leg/burn), breath, limp + pace from a leg or 0.6, burn soot and 12 s of smoke | shown at once |
| burning | announce cry, scream; placeholder screams/wails every few seconds | flames up the trunk, soot rising, embers; upright swatting, on the ground thrashing, held: spine/legs struggle | flames at once, silent |
| doused | announce doused, gasp | gasp, then hands to the face, embers die, steam (water) or smoke, burned out: a spent sag | silent |
| dead | a placeholder groan | Death01 scrubbed to one corpse pose (or a 0.8 s blend from the ground), then `still` masks everything | the corpse at once |
| carried | none | on its back, knees drawn, head hanging, turned a little; `keep` survives death; pain and fire go on over it | same |

villager_body additions: a posture with the same name and clip only seeks (element-clock scrub); clocks that stood still
freeze clips, pose, flash, embers, particles and the placeholder voice; `kick`, `action`, `keep`, `clock` fields;
posture `toward` turns the visual rig to face a fall's source (held while lying, eased back once up; Body's facing is
untouched; pose.gd composes in the turned frame through `turn`); carried ranks over dead; a corpse shows no feeling;
the shown angry lean and panicked run publish `people_observable` {threatening, fleeing}; soft radial puff sprites made
in code. `player/player_pose.gd`: Body's Hands intent as cross-faded layers on the player's skeleton (strike/heavy
coils by drag, shove thrust on release, guard, grip, casting hand, carry); wired by one Body line in `ui/hud.gd`.

## Evidence [run]

Outer `plan/evidence/people-animation/20261003/`. Window 3: 11/11 slice A checks, fear and layers boards. Window 4
(3942c7b): 18/18 checks, 12 boards before (c8e2e5e) and after; a recorded thermal violation (launched at 94.85C).
Window 5 (6c85349): 18/18 checks, six after boards, clean. The boards show what the before did not: planted hits with
backing steps, falls away from the blow, distinct burning by posture, doused gasps, one unmistakable corpse pose, a
charred burned corpse, carried and set-down bodies, the player's coils and guard. Still weak: the arm clutch, the
player's grip seen from the front, carried bodies without a carrier on the board.


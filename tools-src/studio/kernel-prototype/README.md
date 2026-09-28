---
title: "S1 - the world as a function of (seed, time, actions): feasibility spike"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), Claude Code on Hilmi's PC
status: done - evidence for docs/studio/ROUTE-r2.md and docs/studio/ROUTE.md (S1b added for r3)
next_step: Stage A0 of route r3 - a fixed-point kernel with the social layer (L1-L3) for one deep village, run headless
---

# S1 - the world as a function

**Question.** Can a history that "keeps happening" run on the phone alone - offline, no game server - and still support time storms, edits to the past, catch-up after days away, and two players sharing one world?

**Answer** `[run]`: yes, at the coarse settlement level tested here, with a lot of headroom. The numbers below come from `node run.mjs` (Node 24, this PC, 28 Sep 2026); the full output is in `results.txt`.

## What was built

`sim.mjs` (316 lines, no dependencies) - three peoples, 12 founding villages, one step per year: food and land, droughts, floods, hunger, aid and raids, foundings and ruins, and knowledge that needs other trades first (charcoal before copper, copper before iron) and can be lost and rediscovered.

Two ideas are under test:
- **Keyed randomness.** Every random draw is a hash of (seed, year, place, purpose), not the next number from one shared stream. A change can then only spread along real causes.
- **Actions as a log.** What players do - in the present or inside a storm in the past - is a small list of `{year, kind, target, player, seq}`. Every phone sorts it into one canonical order and computes the same world.

`run.mjs` runs the eight experiments.

## Results `[run]`

| # | Test | Result |
|---|---|---|
| 1 | 500 years of history, 20 seeds | median **24-28 ms**; ~29 settlements, ~4,600 logged events; same seed twice gives an identical world hash |
| 2 | Checkpoints every 25 years | 20 snapshots, **162 KB** in total |
| 3 | Time-storm view of any place in any year | **~1 ms** (resume from the nearest checkpoint) |
| 3 | The whole world run 100 years into the future | ~8 ms |
| 4 | Edit the past (warn a village of its flood), re-simulate to today | median **~19 ms**; always identical to a full re-run from year 0 |
| 4 | How far the edit spreads - villages a player would notice changed (size stage, knowledge, ruin, >10% population) | **keyed 21%** vs **shared stream 61%** (medians over 20 trials) |
| 5 | Catch-up after 30 days offline at one world-year per day | ~1.2 ms |
| 6 | Two players' logs merged in different arrival orders | identical hash; the four actions are **330 bytes** of JSON |
| 8 | Hinge search - try every flood in history as a counterfactual | ~100 counterfactuals in ~1 s; the best changes 2-4x more villages than the median |

## What it means `[design]`

- **No server is needed for the world to evolve.** The world at any moment is computed, not stored. The phone catches up on open in milliseconds, which is the train case.
- **Keyed randomness is what makes time travel safe to share.** With one shared stream, any edit reshuffles every later random draw, and 61% of villages noticeably change. With keyed draws, change travels only through causes (trade, aid, raids), and 21% change. That makes "bounded rewrites" a property of the mechanism, not only a rule.
- **History heals itself.** Warning Wenor of its year-107 flood saved its mill, but a neighbour would have taught it milling that same year, so today's Wenor differs by 4 people. Most edits are absorbed. For storms to matter, they must land on the hinges, and the game can find those itself (test 8).
- **Multiplayer becomes exchanging tiny logs**, not streaming state from an authoritative server.

## S1b - time-storm enclaves (added after Hilmi's clarification)

**Question.** A storm turns part of a village into its own past. Does the past turn on the village it was once part of, with nothing scripted?

**How.** `enclave.mjs`. At year 500, a share of the largest village is replaced by its own people from year 500 minus a gap, carrying that year's knowledge, food and relationships. Both claim the same fields and the same name. Any conflict has to come from the ordinary rules: shared land, then hunger, then a raid or a plea. The experiment ran 20 seeds for each setting, over the 25 years after the storm. Full output is in `enclave-results.txt`.

| Years back | Share folded | Past raids present | Present raids past | Any fighting | Past teaches others | Origin smaller than without the storm (median) |
|---|---|---|---|---|---|---|
| 40 | 30% | 0% | 70% | 70% | 15% | 21% |
| 40 | 60% | 15% | 15% | 30% | 25% | 30% |
| 150 | 30% | 0% | 70% | 70% | 20% | 20% |
| 150 | 60% | 25% | 15% | 40% | 20% | 30% |
| 300 | 30% | 0% | 60% | 60% | 10% | 19% |
| 300 | 60% | 15% | 10% | 25% | 20% | 28% |

**Reading** `[design]`:
- **Conflict emerges.** In a quarter to over two thirds of storms, the two halves fight within 25 years without any script.
- **Size decides who strikes.** A small enclave gets preyed on by the present. A large one strikes back. One chronicle: "Old Holtorfen raids Holtorfen for grain; 18 fall", 24 years after a storm pulled it out of year 350.
- **The past also gives.** In 10-25% of storms, the enclave teaches its knowledge to neighbours.
- **Era barely matters here, and that is the limit.** The fighting is driven by shared land, not by what separates the ages. For a village's past to turn on it because of who they were (their values, their grudges, their gods), the model needs the social layer that route r3 describes. This toy only has land and food.

## What it does not show

- **It is a toy model.** It has villages, not individual villagers, and no geography beyond distance. A richer model costs more. The headroom here is large, but it is not unlimited.
- **It ran on V8 on a PC, not in GDScript on the phone.** GDScript runs tight loops roughly 40-100x slower than C++ `[web]`, and V8 is a few times slower than C++. A GDScript port would land around 0.5-1.5 s per 500-year history on a desktop-class core `[design]` estimate. That is fine for world creation and a storm transition, but it is not a per-frame budget. S2 measures it on the real phone.
- **Nothing here touches rendering, the hands layer (combat, gathering) or the AI villagers.**

---
title: "Village life, steps 3 and 4 - the argument, decided by the rules and played on the bodies"
created: 2026-10-02
type: evidence
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: steps 3 and 4 done; the density gates are not yet met (step 7)
next_step: step 5 (news and the board); the gates are judged again after step 6 (the town meeting)
---

# Steps 3 and 4: the argument

**Verdict** `[run]`: arguments now come from two places:
- the rules' own quarrels near the player (the director's attention, a deed the day planned);
- meetings of two who dislike each other near the player (a request: the rules decide).

They play as a scene with a cast, onlookers and an ending. Over 40 minutes of play in the square (headless, 4x, the same seed as the baseline), the rules decided 4 arguments: 2 from deeds (one ended in blows, one parted by a neighbour) and 2 from meetings (one cooled, one parted). Three were played within sight. **Their median was 10 people, the two and those who came to watch, against 2 for the old 8-10 s staged quarrel.**

**The gates are not met yet** `[run]` (plan section 8; the pass stays open):

| Gate | Before (baseline, same seed) | After steps 3-4 | Gate |
|---|---|---|---|
| Longest quiet gap in view by day | 367.5 s | 286.8 s | at most 180 s |
| Happenings in view per 20 minutes | 8.0 | 8.8 | at least 10 |
| People in a happening, median | 2.0 | 3.0 | at least 4 |
| The commonest kind's share | 0.20 | 0.27 | at most 0.40 |
| Villagers near the player out of doors | 0.63 | 0.63 | higher after |

The rest is for the town meeting (step 6) and the director's tuning (step 7, `QUIET` and `LEAD`, live path only).

**What else holds** `[run]`:
- `news_tests` 9 of 9: an argument applied once, never twice a day per pair, both wary; the player's step in; at least three endings across 40 villages, every peacemaker one who was there, every blow a crime; the same requests give the same happening; the chronicle untouched; threads, pacing, save and restore of the stories; headlines short and plain.
- `conformance` 3 of 3: the reference's golden hashes unmoved, live villages deterministic, storms.
- `people_tests` 40 of 40, the integration checks headless 20 of 20, the save test 33 of 33, `notes_tests` 21 of 21, and the evening motion probe passing.

**Retired** `[repo]`: `incidents.gd _quarrel` is no longer called (the quarrel and brawl deeds become arguments in `Incidents.show`). Pass 3's encounter quarrel now asks the rules through the society's new `instead` hook. Deleting `_quarrel` waits for Hilmi's approval.

## The runs (NEWS GATES)

Baseline (code before step 3, rules edits stashed):
```
{"day_minutes":25.0,"game_minutes":5232,"in_view":10,"in_view_per_20":8.0,"kinds":{"hearing:trial":1,"incident:chat":2,"incident:help":2,"incident:play":2,"incident:quarrel":2,"public:pillory":1},"meetings_per_min":2.6,"outdoors_samples":8512,"outdoors_share":0.63,"people_median":2.0,"people_median_by_kind":{"hearing:trial":20.0,"incident:chat":2.0,"incident:help":2.0,"incident:play":3.0,"incident:quarrel":2.0,"public:pillory":30.0},"quiet_gap_s":367.5,"real_minutes":40.0,"top_share":0.2}
```
After steps 3 and 4:
```
{"day_minutes":25.0,"decided":{"argument:deed:blows":1,"argument:deed:parted":1,"argument:meeting:cooled":1,"argument:meeting:parted":1},"game_minutes":5232,"in_view":11,"in_view_per_20":8.8,"kinds":{"happening:argument":3,"hearing:trial":1,"incident:chat":2,"incident:help":2,"incident:play":2,"public:pillory":1},"meetings_per_min":2.6,"outdoors_samples":8428,"outdoors_share":0.63,"people_median":3.0,"people_median_by_kind":{"happening:argument":10.0,"hearing:trial":20.0,"incident:chat":2.0,"incident:help":2.0,"incident:play":3.0,"public:pillory":30.0},"quiet_gap_s":286.8,"real_minutes":40.0,"top_share":0.27}
```

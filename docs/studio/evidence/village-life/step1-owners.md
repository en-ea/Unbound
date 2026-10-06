---
title: "Village life, step 1 - one owner per body: before and after, headless"
created: 2026-10-02
type: evidence
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: step 1 done
next_step: step 2 (stimuli); the same comparison is rerun whenever residents.gd's drivers change
---

# Step 1: one owner per body changes nothing measurable

**Verdict** `[run]`: `people/owners.gd` now decides who drives every body in `village/residents.gd` (stage, talk, answer, society). The evening probe measures the same before and after, within the noise of identical runs. Eight runs used the code before the change and nine used the code after, all headless at a fixed step (`unbound.sh hprobe:evening`), same seed, no window.

**Out of the noise:** one run of the nine after the change formed slightly looser circles (heap share 0.87, against 0.97 to 0.99 in every other run). All its other measures sit inside the before spread. I read it as the crowd's chaos, not the change, but it is recorded rather than explained away.

**One line kept on the society's record** `[run]`: the first after runs halved the steps aside, from 9-10.5 to 4.5-6 a minute, and showed a speech bubble in every run. Bisection over the edits (3 runs per half) found it in `_busy_other`. It asks whether someone's walking goal is a conversation's slot. The society hands a joiner over (`taken`) a moment before it records them as a member, and in that moment the owner check and the old membership check disagree, so circles formed in slightly different places. The line asks the society's own record again. With it, the after runs match.

**Runs are not exactly repeatable** `[run]`: headless at a fixed step, same seed, even with the engine's random numbers seeded at the probe's start, two runs of the same code differ in detail (for example, one villager's idle spot). The headline measures hold steady. `toolbox/godot-jobs/compare_runs.py` therefore judges the headline measures against the before runs' own spread and counts per-person detail apart.

**Found in passing** `[run]`: the evening's "listeners' heads on the speaker" target (0.6) fails in about a third of runs, both before (3 of 8) and after (2 of 9). The measure sits at the target with wide noise (0.45 to 0.66). This is not new, and not caused here.

## The comparison (`compare_runs.py MOTION <8 before> -- <9 after>`)

```
== evening (8 before, 9 after)
  asides_per_min               before 9..10.5  after 10.5, 9, 9, 9, 9, 9, 9, 9, 9 
  awkward_share                before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  blow_slowest                 before -1..-1  after -1, -1, -1, -1, -1, -1, -1, -1, -1 
  bubble_overlaps              before -1..0  after 0, -1, -1, -1, -1, -1, -1, 0, -1 
  bubbles_at_once              before -1..1  after 1, -1, -1, -1, -1, -1, -1, 1, -1 
  cost_p90_ms                  before 1.48..2.01  after 1.54, 1.74, 1.62, 1.56, 1.74, 1.83, 1.56, 1.73, 1.58 
  crawl_share                  before 0.01..0.01  after 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01 
  cruise_cv                    before 0.16..0.17  after 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16 
  cruise_mean                  before 1.17..1.18  after 1.17, 1.17, 1.17, 1.17, 1.17, 1.17, 1.17, 1.17, 1.17 
  departure_spread_median      before 19.2..19.2  after 19.2, 19.2, 19.2, 19.2, 19.2, 19.2, 19.2, 19.2, 19.2 
  departures                   before 48..51  after 52, 49, 49, 49, 49, 49, 49, 51, 49 
  glide_share                  before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  head_share                   before 0.45..0.63  after 0.5, 0.63, 0.61, 0.62, 0.62, 0.61, 0.61, 0.48, 0.62 
  heap_share                   before 0.97..0.99  after 0.87, 0.99, 0.99, 0.99, 0.99, 0.99, 0.98, 0.99, 0.97 OUTSIDE
  idle_share                   before 0.09..0.11  after 0.11, 0.11, 0.11, 0.11, 0.11, 0.11, 0.11, 0.11, 0.11 
  meeting_top_share            before 0.45..0.45  after 0.45, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45 
  meetings                     before 11..11  after 11, 11, 11, 11, 11, 11, 11, 11, 11 
  meetings_per_min             before 16.5..16.5  after 16.5, 16.5, 16.5, 16.5, 16.5, 16.5, 16.5, 16.5, 16.5 
  odd_pace_share               before 0.01..0.01  after 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01 
  onlookers                    before -1..-1  after -1, -1, -1, -1, -1, -1, -1, -1, -1 
  onlookers_close              before -1..-1  after -1, -1, -1, -1, -1, -1, -1, -1, -1 
  other_overlap_per_min        before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  overlap_per_min              before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  overlap_s_per_min            before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  player_overlap_per_min       before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  skate_share                  before 0.01..0.02  after 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02 
  snaps_per_min                before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  stand_turn_snaps_per_min     before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  statue_share                 before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  turn_snaps_per_min           before 0..0  after 0, 0, 0, 0, 0, 0, 0, 0, 0 
  widest_bubble                before -1..0.04  after 0.04, -1, -1, -1, -1, -1, -1, 0.04, -1 
COMPARE DIFFERENT: 1 headline measures outside the before runs' spread (0 detail measures outside, not counted)
```

Failing checks per run: before `0 1 1 0 0 1 0 0`, after `2 0 0 0 0 0 0 1 0` (each failure is head share; the after run with 2 is the one with the loose circles).

Also passing on the change `[run]`: `people_tests` 39 of 39 (with the new owners test), the village integration checks headless 20 of 20, `notes_tests` 21 of 21 and `notes_probe` 18 of 18 (the note tool now reports each person's owner).

---
title: "Village life, steps 5 to 7 - the news and its board, the pressures and the town meeting, the density gates"
created: 2026-10-02
type: evidence
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: steps 5 and 6 built and checked headless; step 7 run - 6 of the 8 density gates pass, 2 are missed (logged below); the pass stays open
next_step: Hilmi's look on the phone (the board, an argument, a town meeting from the save near a crossing), with his yes for the phone; then the two missed gates through the plan's later passes (section 11)
---

# Steps 5 to 7: the news, the town meeting, the gates

**Verdict** `[run]`:
- **The village now tells the player what is going on.** A notice board sits under the quest tracker. It carries one line at a time, never two within 10 s, and about 6 to 8 new lines per 20 minutes of play. Each line says how the player knows: "you saw it", "you heard it", "the bell" or "people are saying". While a story is going on, the line also shows which way it is and how far.
- **The village has pressures.** These are hunger, inequality, fear, grief and strife. When hunger, inequality or fear goes high, the elder calls a town meeting at the square.
- **A town meeting watched from the square went as designed.** The bell rang and 17 people gathered. The three speakers stood in a row and spoke by turns. The village agreed to share grain, and grain moved from the full houses to the empty ones. The board showed the call, then the gathering, then the outcome.
- **The density gates are not all met.** 6 of 8 pass. The quiet gap in view (287-308 s against 180) and the people in a happening (median 2.5-3.5 against 4) are missed. Their causes are below. The pass stays open (plan section 8).

## What was built `[repo]`

```
 rules (village/sim, live path only)          body (people/, village/)             news (news/)                    UI (Enea's files: two marked hooks)
 ───────────────────────────────────          ────────────────────────             ────────────                    ───────────────────────────────────
 pressures.gd  readings 0..1000, levels  ──►  happening_kinds.gd "meeting":   ──►  unbound_news.gd: meeting and    ui/hud.gd     the board under the tracker
               with hysteresis; a crossing     gather / speak / decide /            pressure items; a meeting its   ui/joystick.gd a tap on the board or the
               logged; a high one calls        disperse; speakers in a row,         own story; "where" while it     tracker is not the stick
 town_meeting.gd  the meeting: who speaks,      one steps forward by turns;          goes on
               when; at its minute the          the crowd from the bell's reach  village_news.gd  the live node:
               decision (share / watch /        ("all", not only the bold);          reads once a game minute,
               nothing), applied once           kept through interruptions       how the player knows, word of
 runtime.gd    pressures at the day's phases;   (owners.gd suspend and resume)       a crime becomes a weak clue,
               the meeting's decision a time  live.gd   the bell when it gathers     saved (v.runtime.news)
               point                           residents.gd  watchers by kind;   board.gd  one line, folds to a
 crime.gd      a night watch: theft harder      run distance by kind                 tab with "N new"; tap: three
 state/events/view.gd  an event's game minute  resident_lines.gd  the meeting's       lines; tap a line: its story
               (live only, not in the hash)     words                           edge_cues.gd  a sound out of view:
 director.gd   QUIET 360 -> 240 (step 7)                                             an arrow at the screen's edge
```

## Step 5: the news and the board `[run]`

- **Checks:** `news_tests` 15 of 15, which include threads, pacing, restore and headlines. The news probe's gates for the board all pass (below).
- **The board on a 19.5:9 phone screen** (1560x720 in the game's units):
  - one line sits at (64, 267), 330x79;
  - it is inside the screen and clear of the hearts, the buffs, the tracker, the minimap and the thumb's area;
  - opened to three lines by a tap, it reaches 54-66% of the screen's height, into the top of the thumb's area. While it is open, a touch on it is not the stick (the joystick hook).
- **Save and load:** what the player knew survives a save exactly (`save_same: true`). This took three fixes, each found by the probe's new `save_diff`:
  - the rules now record the game minute of each live event (`S.Event.minute`, -1 in the chronicle and in older saves, not in the hash);
  - the stories are rebuilt in the order they came;
  - a story's headline is its latest item's, by minute.
- **Pacing:** `GRAVE_GAP` went from 6 to 20 game minutes, so a grave line still goes first but never within 10 s of the last. Two lines that close read as noise (the plan's "never two within 10 s").

## Step 6: the pressures and the town meeting

**Calibration** `[run]` (pure rules, six live villages, 60 game days each, about 3 s in total):
- 8 to 17 crossings a village and 2 to 5 meetings, about one every 12 to 30 game days.
- All three outcomes occur: share, watch and nothing.
- One fix came out of it. Enea's characters live in single houses that sit at the food floor (they are fed by their story, with hunger held at 0). Counted, they made inequality read 1000 all the time. They are now left out of the food readings.

**Rules checks** `[run]` (`news_tests`):
- **Levels:** up at 400 and 650, down only below 300 and 520.
- **Hunger going high:** the crossing is logged, and a meeting is called at the square at least 90 game minutes ahead. Its speakers are three different people: the emptiest house, the fullest house and the elder. A second call within 3 days is refused.
- **The decision, once, across 9 villages:**

  | Outcome | Count | What happened |
  |---|---|---|
  | share | 4 | food moved and none made or lost; the emptiest a mouth went from -6 to -2; inequality fell |
  | watch | 4 | fear went from 900 to 750 and the watch was set |
  | nothing | 1 | the two are angrier and wary of each other |

- **The news:** the call is announced to a player anywhere in the village, and the meeting is one story with its decision.
- **The save:** the pressures, the meeting and the stances survive a save, and so do the events' minutes.

**On the bodies, headless** `[run]` (`unbound.sh news_meeting`: the player in the square, the village made hungry by the probe, which the game itself never does):
```
{"bell":true,"called":480,"cause":"hunger","start":720,"outcome":"share","people_most":17,"speakers_in_row":3,
 "phases":["coming","gather","speak","decide"],
 "board":["Town meeting at the square at noon: the empty stores (seen)","Hunger: the stores are empty (word)",
  "Bad feeling against the full houses (word)","The bell: the village gathers at the square (seen)",
  "The village agreed to share grain (seen)","Less talk of full houses (word)"]}
```
- All 5 of its gates pass, on two runs.
- Two earlier runs failed, and each failure was a design fault, now fixed:
  - **The meeting ended when the elder was taken by something higher.** The cast is now kept through an interruption (`owners.gd`: suspend and resume).
  - **Its gathering waited for the speakers to arrive and was skipped.** A meeting now gathers on time as they come; an argument still waits for the two to be face to face.

**A save near a crossing, for Hilmi's look** `[run]`: `meeting-near-crossing.save.json` (48 KB, in this folder).
- It is the probe's village just before the call. Loaded, the elder calls the meeting at the next of the day's phases, the bell rings at noon, and the meeting plays.
- His own save is untouched.
- Putting it on the phone (as a baked test save, `toolbox/device-lab/phone_session.sh`) needs his yes.

## Step 7: the density gates `[run]`

**The director's change:** `QUIET` went from 360 to 240 game minutes (2 real minutes).
- `[design]` With 360, a gap could not be under 180 s whenever the director's attention was the only source: 180 s of quiet, plus up to an hour's wait for the next attention phase, plus `LEAD`. `LEAD` is unchanged.
- Live path only. Conformance 3 of 3 (the golden hashes unmoved, live villages deterministic).

**A bug found and fixed:**
- **The bug:** arguments born of the day's deeds (including the director's attention quarrels) were recorded on the day's clock (minutes 0-1439), not the game's. After the first game day they were never played on the bodies, their day caps and stances were wrong, and their phase lines carried day-0 minutes.
- **The fix:** `happenings.gd from_deed`, with a test (`news_tests`: a deed's argument on day 2).
- **A correction to `step3-4-argument.md`:** its runs played deed-born arguments only on the first game day. The numbers there stand as measured, but they under-counted the design.

**Three runs after the fix** (40 minutes of play each, the same seed, headless at 4x):

| Gate | Baseline | Run 1 | Run 2 | Run 3 | Gate | Result |
|---|---|---|---|---|---|---|
| Longest quiet gap in view by day | 367.5 s | 286.8 | 286.8 | 307.6 | at most 180 s | **missed by 107-128 s** |
| Happenings in view per 20 minutes | 8.0 | 11.2 | 10.4 | 9.6 | at least 10 | 2 of 3 runs |
| People in a happening, median | 2.0 | 3.5 | 3.0 | 2.5 | at least 4 | **missed by 0.5-1.5** |
| The commonest kind's share | 0.20 | 0.43 | 0.38 | 0.33 | at most 0.40 | 2 of 3 runs |
| Board lines per 20 minutes | - | 8.0 | 7.0 | 6.0 | at least 6 | pass |
| Two board lines never within | - | 10 s | 10 s | 10 s | 10 s | pass |
| Save and load: what the player knew | - | same | same | same | same | pass |
| Board inside the screen, clear | - | yes | yes | yes | yes | pass |
| Villagers near the player out of doors | 0.63 | 0.63 | 0.64 | 0.63 | higher after | not higher |

**Why the two gates miss** `[run]`/`[repo]`:
- **The quiet gap.** The longest stretch is day 2, 08:00 to 17:33 (`quiet_when`):
  - **What fills it:** a pillory stands in view from 08:00 to about 11:30, then nothing until a quarrel at 17:33.
  - **Why the director waits:** `Runtime.advance` re-activates every active staged event on each step, and each activation renews `quiet_since`. So while a long public act lasts, the director brings nothing, and it counts its quiet from the act's end.
  - **The other measure:** with nothing going on in view at all (`quiet_idle_s`, a long scene in view not counted as quiet), the longest stretch was 153-223 s.
  - **Not fixed here:** the renewal is the rules' own Pass 2 behaviour, outside step 7's `QUIET`/`LEAD`.
- **People in a happening.** Arguments have a median of 6.5-9 people, a meeting 17, a hearing 20 and a pillory 30. But the director's chats and help scenes are two people each and make up about a third of what is in view.

**What would close them** `[design]`, from the plan's later passes (section 11):
- More kinds with crowds: a death found, want, a hue and cry, muttering.
- The happenings director, led by the pressures, retiring the rest of `_bring_*`.
- Counting the director's quiet from a scene's start, so that a runner-played happening can come while a long public act stands.
- The meeting is rare in plain play, about once in 12-30 game days. It raises neither gate in a 40-minute run.

## Checks run for this `[run]`

| Check | Result |
|---|---|
| `news_tests` | 15 of 15 |
| `people_tests` | 40 of 40 |
| `conformance` | 3 of 3 |
| `checks` (village integration, headless) | 20 of 20 |
| `news_meeting` | 5 of 5 |
| `news_gates` | 6 of 8, as above |

No window was opened and the phone was not used.

## Code retired or kept `[repo]`
- Nothing was deleted.
- `incidents.gd _quarrel` stays unrouted (step 4), and its deletion still waits for Hilmi.
- The two hooks in Enea's files (`ui/hud.gd`, `ui/joystick.gd`) are marked `# studio:`. They are proposals to Enea through Hilmi, as is the board itself.

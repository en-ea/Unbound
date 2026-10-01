---
title: "Unbound master goals, revision 2 - who builds what, where we are, what needs what"
created: 2026-09-30
type: master-goals
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio; revises Astra's MASTER-GOALS.md (29 Sep, b16438c)
status: the authoritative programme; corrected 1 Oct (Pass 2 done and pushed; Hilmi's 1 Oct verdict on the people). D-A and D-B were settled by Hilmi on 30 Sep (section 2)
next_step: Hilmi reviews the people architecture (PEOPLE-ARCHITECTURE.md), the new foundation in section 5; on his go the lead plans Pass 3 as its steps 1 and 2
---

# Unbound master goals, revision 2

> **1 Oct correction - read this first.** The 30 Sep text below said things that are no longer true, and the route would have led to more of what Hilmi rejected on 1 Oct. Each correction is added beside the 30 Sep text, which stays as written (git holds every version):
> - **Who builds what:** D-A and D-B are not open; Hilmi settled them on 30 Sep as a partnership with continuous merging (section 2, end).
> - **Where we are:** Pass 2 is done and pushed (`c5cbdfa`). Section 3 has a 1 Oct table; section 4 has a 1 Oct state per goal.
> - **The verdict on the people** `[chat]`, Hilmi, 1 Oct: "I am still not very happy with the interaction of people or the way they react to getting hit (very simple and robotic)", and "the speed and movement of these npc's look way too robotic, and they walk through eachother". Pass 2's checks pass, so G03 and G09 are engineering verified and **not** owner accepted.
> - **The route:** B1 met its checks by building each interaction as a special case. Building B3, B4 or B5 the same way would multiply that. A people architecture now sits under every people batch (section 5, layer PA; `PEOPLE-ARCHITECTURE.md`).
> - **A new rule:** infrastructure, not scenes (section 6).
> - **The seed:** the home village is the same in every game; random seeds are for testing and, later, villages found on the map (H4 reversed in part).

[design] This revision keeps the 29 Sep document's goal IDs, intent and principles. It corrects four things, traced in `plan/STATE-2026-09-30.md` (studio repository):
- **A stale baseline.** Enea's `camera-test` already builds part of what the 29 Sep document assigned to the studio.
- **No division of labour, and no path for studio work into Enea's game.**
- **B1's real prerequisite.** A live, minute-level layer for the village the player is in.
- **Form.** It is shorter, with fewer tags and more diagrams.

The 29 Sep text stays in `MASTER-GOALS.md` as history.

## 1. The game

[chat] Unbound is a phone action-adventure and life game in a world with a life of its own:
- gather, craft, fight, find gear and powers, build a home, explore three lands, and later play with friends;
- people work, misunderstand, steal, help, remember, organise and sometimes turn on one another;
- the player is a person among them, who can intervene, cause trouble, leave, and meet the consequences later.

Village drama is optional side fun: "it shouldn’t make the game too focused on this" (S0). A player who ignores it and goes to a dungeon must have just as good a game.

[design] The test for progress is what a player can do and understand. Two examples:
- **First:** punch a villager, see that particular person react (puzzled, afraid, angry), see a bystander decide whether to step in, and come back later to a village that remembers the right incident.
- **Later:** free a captive, restrain their captor, move them both, and face escapes, witnesses and retaliation. None of it scripted as a mission.

## 2. Who builds what, and how it lands

[repo] Unbound is Enea's game ("Enea owns Unbound: product, look and feel", studio `CLAUDE.md`). His brief to his own agents says: "Hilmi's `studio` branch: don't merge or build on it without my OK." Studio work reaches players only if Enea takes it into `main`.

**D-A, who builds what** (proposal; Hilmi takes it to Enea):

| Enea (`main`, `camera-test`) | The studio (`studio`) | Shared seam (a contract both keep) |
|---|---|---|
| The adventure: combat feel, enemies, classes and abilities, camera, story characters and quests, gear, loot, art, music | The people: one population, daily life, social agency and consequences, storms and settlements, persistence and performance plumbing, later co-op | Hitting a resident goes through his `take_hit`. Resident perception reuses his bandits' sight model. Story characters are residents with authored roles |

**D-B, the landing path** (proposal):
- **Now:** the village is one module. It lives under `scripts/studio/`, plus a handful of marked hooks in `main.gd`, `save_game.gd`, `day_night.gd`, `player.gd`, `settings.gd` and `project.godot`.
- **The switch:** it gets a Settings switch ("Living village").
- **The landing:** it goes to `main` as one reviewed pull request when Enea is happy with it.
- **Until then:** Enea plays it through the `studio` branch's Vercel preview, which exists behind his login.

Until D-A is answered, the studio builds nothing in Enea's column.

**30 Sep, later: Hilmi settled both** `[chat]`: "why can't we just merge them whenever possible but into our own branches? as in my new things get copied into his when hes working and his work is copied into ours when we notice it there and we work from there? we are working towards the same goals and should see his work as a creative partner."
- **The flow runs both ways.** The studio merges `main` and `camera-test` whenever new work appears. Enea merges `studio` while he works.
- **The table above is read as a partnership, not a wall.** His work is the base; the studio extends his systems through small marked hooks. The landing is continuous merging, made safe by a "Living village" switch and by running his checks before every push.
- **The plan:** `plan/PASS-2-PLAN-2026-09-30.md` (studio repository).
- **So "until D-A is answered, the studio builds nothing in Enea's column" no longer holds** as written. What holds: the studio extends his systems through small marked hooks, and changes inside his systems (for example E1-E4 in `PEOPLE-ARCHITECTURE.md`) wait for his OK through Hilmi.

## 3. Where we are (30 Sep)

| Area | State | Owner |
|---|---|---|
| Adventure loop on `main` | Gather, craft, tiers and loot, armour, cooking, trader and projects, home, regions, Wren/Brakk/Morrow/Seeker and quests, smarter fights, round minimap `[repo]` | Enea |
| `camera-test` (to merge into `main` "when I say") | Turning low camera with a lock-on ring; parry and perfect dodge; Red Hand bandits (sight cones, line-of-sight rays, ?/! awareness, alarms, bodies noticed); sneaking and takedowns; shrine, class screen, Pyromancer, two ability buttons; music; Morrow's quest `[repo]`, read not run | Enea |
| Village rules | Deterministic, well checked `[run]`, but computed a day at a time: incidents are decided at dawn and never embodied `[repo]` | Studio |
| Runtime authority | Correct for event windows (hearing, public act, rite) `[run]`. There is no action path outside an event. The consequences of player acts are recorded but read nowhere `[repo]` | Studio |
| What the player sees of the village | Residents walking between plan places. Events with a bar of raw buttons and simulator text. Residents cannot be talked to `[repo]` | Studio |
| Save and platform | Village save about 690 KB after 150 game days, mostly past stagings, written every 15 s `[run]`. All village measurements are native Android; there is no web or iPhone data `[repo]` | Studio |
| Two populations | Enea's authored villagers and the studio's generated residents share one village without knowing each other `[repo]` | Seam |

### Where we are (1 Oct, after Pass 2)

| Area | State | Owner |
|---|---|---|
| Enea's work | `main` and `camera-test` up to `4a1df30` merged into `studio`: hunting, carcasses, hauling and the ox cart, talents, quest log and guide, flick buttons, homes `[repo]` | Enea |
| Village rules | Unchanged at heart. Deeds now happen at their minute near the player, and the player counts as eyes. Cases no longer stick when a hearing is cancelled `[run]` | Studio |
| Runtime authority | One action path outside events (square up, strike, shove, give), each accepted once, saved at once, and reported to the elder by a witness `[run]`. Free and restrain outside events are not built | Studio |
| What the player sees | Everyone can be talked to through Enea's panel. Six small scene kinds are brought near the player about hourly. Struck villagers answer in 9 ways, with onlookers. **Judged "very simple and robotic" by Hilmi** `[chat]`. Bodies replay timetables, so they walk through each other at one speed `[repo]` | Studio |
| Save and platform | 150 days is 26-27 KB on disk `[run]`. Web on this PC: 19.6 fps in the pane, the villagers 0.8 ms of a 49 ms frame `[run]`. The iPhone and the S10 are not measured this pass | Studio |
| One population | Wren, Morrow, Brakk and the Seeker are residents with authored roles, protected from the rules `[run]` | Seam |
| Publication | `studio` pushed through `c5cbdfa` with a note for Enea (`PASS-2-FOR-ENEA.md`). The seed change `6319c32` and these documents are local `[repo]` | Studio |

## 4. Goals

[design] IDs are stable. "Enea" means the studio does not build it without his say. "Studio" means studio-built, with Enea reviewing at landing.

| ID | Goal | Owner | State (30 Sep) | State (1 Oct, after Pass 2) |
|---|---|---|---|---|
| G01 | Deliberate, responsive combat and targeting | Enea | Lock-on ring, parry and dodge on `camera-test` | Merged into `studio`; "Pick a fight" and fight-back use it `[run]` |
| G02 | Physical actions create world incidents | Studio | Event-bound only; F3 | **Partial.** Square up, strike, shove and give work outside events `[run]`; take, free and restrain do not. Scenes near the player are picked by the director, not set off by anything in the world (layers P and C) |
| G03 | Individual, varied resident reactions | Studio | Foundations only (traits, opinions) | **Engineering verified, not owner accepted.** 9 answer states by temperament and hurt `[run]`; Hilmi: "very simple and robotic" `[chat]`. To rebuild on layers S and B |
| G04 | Witnesses, reports, bounded local knowledge | Studio (on Enea's perception) | Crime sources exist; live perception exists for bandits only; F4 | **Engineering verified, narrow.** Enea's sight model decides who saw a blow; one witness tells the elder `[run]`. Asked once per blow; no hearing, no attention (layer P) |
| G05 | Recognition, suspicion, disguises | Studio | Missing (masks are cosmetic) | Missing |
| G06 | Relationships, accountability, ways back | Studio | Recorded, never used | **Partial.** What a villager remembers of the player shapes greetings and lines; a gift softens a grudge `[run]`. Memories cannot name the event; no apology or restitution (S3, S4) |
| G07 | Restraint, rescue, captivity, escape | Studio | Event-specific Free only | Unchanged |
| G08 | Carrying, horses, transport | Seam (mount: Enea; passengers and captives: studio) | Missing; Enea's IDEAS has carcass carrying | Enea's hauling (carry, drag, ox cart) merged `[repo]`; carrying a person not built |
| G09 | Ordinary life and optional drama | Studio | Thin: walking and three loops | **Engineering verified, not owner accepted.** Work, meals, evening chat, indoors at night; six small scene kinds `[run]`. Hilmi: movement "way too robotic", people "walk through eachother" `[chat]` (layers B and C) |
| G10 | Crime, manipulation, live justice | Studio | Focused subset (hearings, public acts) | Same subset; a cancelled hearing no longer leaves its case open `[run]` |
| G11 | Groups, factions, cults | Studio | Missing | Missing; situations that last (C3) are the base |
| G12 | Collective conflict, proportionate response | Seam | Missing; Enea's bandit camp is a hostile group with alarms | Missing |
| G13 | Time storms as playable encounters | Studio | Rite subset; demo cadence to remove (H2) | Demo storms out of live play (H2 done) `[run]` |
| G14 | Reusable settlements and districts | Studio | One village, hand-mapped | One village. The home village is the same in every game; seeds make others for tests and, later, villages found on the map (`6319c32`, local). Placing them needs the spawner (C5) |
| G15 | Three lands and progressive liberation | Enea | Story start on `camera-test` | Enea's; on `studio` through the merge |
| G16 | Classes, abilities, weapons, dungeons | Enea | Pyromancer and two abilities on `camera-test` | Enea's; talents added, on `studio` through the merge |
| G17 | Home, economy, companions | Enea (studio for residents' needs) | Home and projects on `main` | Enea's homes merged; residents' needs unchanged |
| G18 | Intuitive world, camera and interface | Enea (studio for its own cues) | Studio cues are debug-grade (H3) | The debug bar and caption are gone; talk goes through Enea's panel `[repo]`. Speech bubbles overlap and grow too large (B7). H3's acceptance not formally checked |
| G19 | Art, sound, readable consequences | Enea (studio for resident reactions) | Enea's pipeline | Reactions use stock animations that read stiffly; the animation source is Enea's call (E3) |
| G20 | Phone performance at useful scale | Shared | S10 only; F5 adds web | Web on this PC measured: the villagers 0.8 ms of a 49 ms frame; hitches of 1.0 s at Play and 267 ms at the first body `[run]`. iPhone and S10 not measured |
| G21 | Persistence, one clock, authoritative actions | Studio | Village subset works; save budget missing (H1) | Save budget met: 26-27 KB at 150 days, 74-109 KB at 1,000 `[run]` |
| G22 | Online co-op | Studio (with Enea) | Future; authority has the right shape | Unchanged |
| G23 | Reliable delivery and a repeatable loop | Shared | Studio builds are separate from Enea's app until D-B | Continuous merging both ways; the `studio` preview carries the living village; Enea's `main` does not `[repo]` |

## 5. The studio's route

```
 H  hygiene (now; no product decision)
    H1 save budget: past stagings and derived tables are not saved; histories are capped
    H2 storms: the demo cadence leaves the runtime; no live storms until B7
    H3 legibility: the permanent caption, raw buttons and simulator text become in-world
       cues and one contextual action at a time
    H4 one player-reputation record; a village seed per new save; probes and demo data
       out of exports
        |
 F  foundations
    F1 one population: Enea's villagers become residents with authored roles and
       protections                                                   <- D-A
    F2 the player's village lives at minute resolution: thefts, quarrels and help are
       performed by bodies when the player is there, and the player counts as eyes;
       away from the player the day rules run as now                  <- H1
    F3 one action path outside events: strike, shove, give, take, free, restrain;
       accepted once, then shown                                      <- F2
    F4 perception shared with Enea's bandits (cones, line of sight, noise, alarms),
       extended to residents                                  <- camera-test in main
    F5 a performance baseline on the web build (PC browser now; iPhone through the
       preview link when an owner can)                                <- H1
        |
 B  playable batches
    B1 provoke a person          <- F1 F2 F3 F4, Enea's lock-on and combat
    B5 ordinary life with substance <- F1 F2 (runs beside B1: drama stays optional
                                    only if ordinary life is worth watching)
    B3 recognised or disguised   <- B1 F4
    B4 captivity                 <- B1 F3
    B7 storms as places          <- F2 H2, a second district (G14)
    B10 co-op                    <- a stable solo slice
```

**Acceptance, per item:**
- **H1:** a 150-day save is under 100 KB, and a 1,000-day save under 250 KB. Load, continuation and the goldens are unchanged.
- **H2:** no storm strikes in live play. Storm tests still pass.
- **H3:** in ordinary play, no text shows unless the player is next to someone or something they can act on, and none of it names a rule or an internal number.
- **H4:** a new save gets its own village, and an old save keeps its own. Export size drops by the probes and demo data.
- **F1:** Wren, Brakk, Morrow and the Seeker exist once, as residents, with authored looks, lines, quests and protections. The rules can name them (for example as a witness), and their story roles cannot be broken.
- **F2:**
  - with the player present, at least theft, a quarrel and one kindness are performed by bodies at their minute;
  - the player standing near stops a theft that needs no eyes;
  - leaving the region hands the day back to the rules, with no double counting;
  - the goldens for the away rules are unchanged.
- **F3:** each verb is accepted once, applied before its animation, and survives an immediate save and load, travel, midnight and duplicate input.
- **F4:** a resident behind a wall does not see; an alarm carries danger, not identity; a report keeps its origin through saves.
- **F5:** frame distribution, the worst hitches and memory for the meadow with the village on, in the web build on this PC, then on the iPhone.

The B items keep the goal cards of the 29 Sep document (`MASTER-GOALS.md`, section 5), re-based on the prerequisites above.

### The route (1 Oct)

**What went wrong with the route above.** It stopped at foundations for the rules. It had no layer for how people notice, feel, choose and move, so B1 was met by special cases `[repo]`:
- **Reactions:** a rule tree;
- **Acting them out:** one routine per reaction;
- **Scenes:** one builder per scene kind;
- **Bodies:** timetable replay.

The checks passed, yet Hilmi found the result robotic `[chat]`. Each further batch built that way costs new special cases and adds nothing the next batch can use.

**The correction.** Layer PA, the people architecture, comes under every people batch. Its parts, what each replaces, and the order are in `PEOPLE-ARCHITECTURE.md`.

```
 H  hygiene                      H1 H2 done; H3 built, acceptance not checked; H4 done, seed revised 1 Oct
 F  foundations                  F1 F2 done; F3 partial (no take, free, restrain); F4 partial (sight only,
                                 asked once per blow); F5 done on PC, the iPhone open
 B1 provoke a person             engineering verified; owner: "very simple and robotic"
        |
 PA the people architecture     (new, 1 Oct; each step ends in a playable build)
    PA-1 body foundation         steering, avoidance, formations, gait
    PA-2 body expression         head and eyes, impact, one voice at a time
    PA-3 perception              stimuli, senses, attention, one grid, the rules bridge
    PA-4 inner state             affect, appraisal, episodes, stances          (save extends)
    PA-5 choice and situations   offers, a chooser, situations, behaviours     (retires B1's special cases)
    PA-6 the world               the spawner and a first catalogue             (roads; found villages later)
    PA-7 Enea's seams            fight-back through his enemy brain, gestures  (his OK; can come earlier)
        |
 B  playable batches, now built as data on PA
    B5 ordinary life with substance   <- PA-1 to PA-5
    B1 re-judged                      <- PA-2, PA-4, PA-5
    B3 recognised or disguised        <- PA-3, PA-4
    B4 captivity                      <- PA-5, F3 (free, restrain), Enea's hauling
    B7 storms as places               <- PA-6, a second district (G14)
    B10 co-op                         <- a stable solo slice
```

**Acceptance for each P step:**
- **Judged by eye as well as by code:** look boards, frame sequences and Hilmi's eye. Pass 2's checks proved that things happen, not how they read.
- **Measured signs of robotic behaviour:**
  - body overlaps per minute;
  - the spread of speeds between people;
  - the spread of reaction onsets;
  - overlapping speech;
  - the same scene twice running.
- **Not merged** until Hilmi has looked.

## 6. Rules that hold

| Subject | Rule | Sources |
|---|---|---|
| The central loop | Gathering, crafting, combat, loot, classes, home and exploration stay central. Story opens places; play continues afterwards | S2, S3, S4 |
| Drama | Optional and surprising. No attendance duty, and no punishment for doing something else | S0, S1 |
| Agency | Physical actions create situations. They are not only answers to offered event buttons | S0, S1 |
| Behaviour | Motives, local knowledge and circumstances decide. "internal decision models for the villagers so they dont just roboticslly fight back every time (would be cool to see there bro just puzzled he just got punched)" | S0 |
| Three lands | Enea's authored geography and progression. Land 2's hostility is one faction, not a whole people. Land 3 opens community by community | S0, S2, S3 |
| Player role | Starts as an ordinary villager and grows into a champion | S2, S3 |
| Storms | Three ages: tribal, village, town. The affected people are that place's own forebears. The player and their possessions are kept. Story anchors are exempt | S1, S5 |
| Camera and controls | Enea's call (look and feel). Hilmi prefers the tilted everyday view; Enea's `camera-test` explores a low turning camera with lock-on. The studio adapts its cues to whichever he chooses | S1, S4, S10 |
| Platforms | Web on the iPhone is the product. Native Android is a measuring tool. A free native iPhone build comes later | S4 |
| Co-op | Friends in one world, across networks. Solo quality first, but new state and actions keep it possible | S1, S2-S5 |
| Runtime AI | No cloud model calls in play; local decisions and short lines | S0, S1 |
| Content (private build) | Dark events, hostages and stylised adult injury are allowed. Excluded: sexual violence, owning or trading people, medieval torture. Children are never targeted by the player or by public punishment in the current build. A stricter store build later | S1, route r4 |
| Conserving the world | Unloading changes detail, never facts: who is hurt, who holds whom, who knows what. Groups do not appear from nowhere | 29 Sep, section 6 |
| Infrastructure, not scenes (1 Oct) | Every change, however small, adds to shared infrastructure, so that interesting things can turn up around the world and people can interact with them. A new interaction should be mostly data on the people architecture, not new special-case code. "every tiny change we do, I want it to be infrastructure that allows interesting things to spawn around the world and more interactional type things" | Hilmi, 1 Oct `[chat]` |
| Behaviour is judged by how it reads (1 Oct) | The S0 rule above is met in its letter (9 answer states) and not in its spirit: Hilmi found the result "very simple and robotic". Behaviour counts as done only when it looks alive to the eye, as well as passing its checks | Hilmi, 1 Oct `[chat]` |
| Home village and seeds (1 Oct) | The home village is the same in every game. Random seeds are for testing, and later for villages found on the map: "this should be more so for testing and utilised for villages found randomly on the map later on" | Hilmi, 1 Oct `[chat]` |

```text
 player or NPC action
   -> validate target, reach, state, time, duplicate id
   -> apply the persistent effect, cost and incident once
        -> the victim's immediate response; the interrupted activity
        -> witnesses learn only what they could perceive
        -> reports, relationships and groups change over time
        -> save and travel keep this same state
   -> body, movement, sound and cue show the accepted result
```

## 7. How the studio works

- **Lead:** owns intent, the shared contracts, the hard interactions and integration, and personally builds the coupled parts.
- **Helpers:** at most two, Sonnet named explicitly, launch metadata checked. If the model is unavailable, stop and report; never fall back silently. On night 1 the lead fell back to Opus; that is not repeated. Currently no helpers (Hilmi, 30 Sep: "Without subagents now").
  - **1 Oct:** Pass 2 ran two named Sonnet helpers under the plan Hilmi approved. Both are merged, and none is running. The usage rules from the 30 Sep audit hold (`plan/PASS-2-STATE.md`, section 4): a fresh helper per bounded task, direct edits, only the affected check after each change, and the full suite at milestones.
- **Every batch:**
  1. write its bounded outcome, base commit, files and checks in the ledger first;
  2. prove one end-to-end path early, including a save and a region change;
  3. run cheap causal checks while building;
  4. finish with a normal launchable build, commits and a short play route.
- **States:** not started, foundation, partial, engineering verified, owner reviewed, blocked (with its external dependency).
  - **Engineering verified** means: reachable in the normal build, visible and persistent effects agree, the boundaries are checked, the adventure still works, performance is measured where warranted, and it is reproducible.
  - **Owner reviewed** means actual words from Hilmi or Enea.
- **Enea's work:**
  - merge `main` into `studio` on each of his milestones, and `camera-test` once it lands;
  - never edit his files except marked hooks;
  - never merge into `main`, push elsewhere or message him without Hilmi's explicit yes.

## 8. Ledger

| Entry | Scope | State | Evidence and next action |
|---|---|---|---|
| Night 1 and the continuation | Rules, hearing, rescue, rite, residents, persistence, device repair | Engineering verified for V1-V14; owner feel pending; pushed through `535fd40` | `CONTINUATION.md`, `NIGHT-1.md`, `evidence/continuation/s10-final/FINAL-RESULTS.md` |
| Master goals, 29 Sep | Whole vision | Superseded by this revision | `MASTER-GOALS.md` (b16438c) |
| `main` 0709565 merged into studio | Reconcile Enea's drift | Done locally, `df6f214`: import clean, kernel 420/420, village golden, live and storm twins, save/input 20/20, rescue boundaries, smoke render | Unpushed |
| B1 selection (30 Sep, `77afe3b`) | Provoke a person | Withdrawn before starting: its prerequisites F1-F4 were missing, and its control belongs to Enea's lock-on | This revision |
| H hygiene | H1-H4 | Folded into Pass 2 | See Pass 2 |
| Pass 2, "the village around you" | Events near the player (a player-aware director, the village minute by minute), people you can meet, one population, provoke a person, clean foundations (H, F1-F5, B5-lite, B1) | Proposed 30 Sep; waiting for Hilmi's go | `plan/PASS-2-PLAN-2026-09-30.md`; the lead plus two explicit Sonnet helpers |
| Pass 2 (1 Oct) | As above | Approved 30 Sep (Hilmi: "Yes."). Engineering verified at `951b215`; pushed `b16438c..c5cbdfa` with `PASS-2-FOR-ENEA.md`. Owner verdict on the people: "very simple and robotic" (Hilmi, 1 Oct) | `PASS-2-REPORT.md`; no reply from Enea recorded yet |
| Enea's `camera-test` 4a1df30 merged (30 Sep) | Hunting, carcasses, hauling, ox cart, talents, quest log, flick buttons, homes | Done, `969f45f`: 9 conflicts, both sides kept; his six tests ran clean | Pushed in `c5cbdfa` |
| The home seed (1 Oct) | The home village the same in every game; `--village-seed=N` or `random` for tests and found villages | Done, `6319c32`; save test updated | Local; the push waits for Hilmi's yes |
| People architecture (1 Oct) | Body, perception, inner state, choice and situations, spawner (section 5, PA) | Proposed | `PEOPLE-ARCHITECTURE.md`; next: Hilmi's go, then Pass 3 as PA-1 and PA-2 |
| Pass 3, "people who move like people" (1 Oct) | PA-1 and PA-2: one mover and crowd for every body (anticipatory avoidance, own paces, gait), formations, head turns, flinches, one speech manager | Approved 1 Oct (Hilmi: "yes plan and prepare to begin, you will be doing everything solo"). Solo. Stage 0 under way on branch `pass3`: the steering spike passes (`c1a45d8`) | `plan/PASS-3-PLAN-2026-10-01.md` and `plan/PASS-3-STATE.md` (studio repository); next: the robotic-signs baseline, then stage 1 |

**Record for each batch:** batch, date and lead; the bounded player outcome; the base commit and files; the contracts; the state; commits and the build; the checks and results; performance; owner feedback (only if received); and the next action and publication status.

## 9. Open choices

| Choice | Working direction |
|---|---|
| D-A who builds what | Section 2 table (proposal) |
| D-B the landing path | One opt-in module and one PR (proposal) |
| Camera | Enea's; the studio's cues work with either camera |
| Striking a villager on purpose | Enea's lock-on ring selects; the studio decides what the struck person does |
| Everyday cadence | Tune from ordinary sessions; severe events rare enough to matter; no quotas |
| Perception potion | Resets specified beliefs of specified observers, never the whole world; decided with B3 |
| Online and offline time | Keep the solo pause now; decide shared time before B10 |
| Publication | `studio` pushed through `535fd40` (authorised). Later pushes need a fresh yes |
| D-A, D-B (1 Oct) | Settled by Hilmi on 30 Sep: a partnership with continuous merging both ways and the Living village switch (section 2, end). Landing in `main` is Enea's call |
| Publication (1 Oct) | `studio` pushed through `c5cbdfa` (authorised 1 Oct). `6319c32` and the 1 Oct documents are local, waiting for a fresh yes |
| Everyday cadence (1 Oct) | Now one small scene about hourly of game time after about 3 quiet real minutes. It moves to the spawner's pacing budget (PA-6) |
| Seeds (1 Oct) | Settled by Hilmi: the home village is fixed; seeds are for testing and found villages |
| Animation source for gestures and reactions | Enea's call (E3 in `PEOPLE-ARCHITECTURE.md`); to ask through Hilmi early, so his answer is in before PA-7 |

## 10. Sources

| ID | Source |
|---|---|
| S0 | Hilmi's Codex conversation with Astra (`01a0ed3d-...`) and the Hilmi/Enea exchange quoted in `MASTER-GOALS.md` section 10 (speakers unlabelled) |
| S1 | Claude session `65e25e70-...` (the original Opus conversation) |
| S2, S3 | `docs/DESIGN.md`, `docs/GAME_PLAN.md` |
| S4 | `docs/studio/FROM-ENEA.md` |
| S5, S6 | `ROUTE-r4.md`, `VILLAGE-PLAN.md` |
| S7 | The owner ideas AI summary (lower authority) |
| S8 | `NIGHT-1.md`, `CONTINUATION.md`, the evidence folders |
| S9 | `docs/PLAN.md`, `docs/SYSTEMS.md`, the code |
| S10 | Enea's `camera-test` (commit `24cc517`: `SYSTEMS.md`, `NEXT_CHAT_PROMPT.md`) and `main`'s `NEXT_CHAT_PROMPT.md` (0709565) |
| S11 | `plan/STATE-2026-09-30.md` (studio repository): the traced state behind this revision |

---
title: "Unbound master goals, revision 2 - who builds what, where we are, what needs what"
created: 2026-09-30
type: master-goals
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio; revises Astra's MASTER-GOALS.md (29 Sep, b16438c)
status: the authoritative programme from 30 Sep; D-A and D-B (section 2) are proposals awaiting Hilmi and Enea
next_step: Hilmi answers D-A/D-B with Enea; the lead runs the hygiene step H (section 5) meanwhile
---

# Unbound master goals, revision 2

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

## 4. Goals

[design] IDs are stable. "Enea" means the studio does not build it without his say. "Studio" means studio-built, with Enea reviewing at landing.

| ID | Goal | Owner | State (30 Sep) |
|---|---|---|---|
| G01 | Deliberate, responsive combat and targeting | Enea | Lock-on ring, parry and dodge on `camera-test` |
| G02 | Physical actions create world incidents | Studio | Event-bound only; F3 |
| G03 | Individual, varied resident reactions | Studio | Foundations only (traits, opinions) |
| G04 | Witnesses, reports, bounded local knowledge | Studio (on Enea's perception) | Crime sources exist; live perception exists for bandits only; F4 |
| G05 | Recognition, suspicion, disguises | Studio | Missing (masks are cosmetic) |
| G06 | Relationships, accountability, ways back | Studio | Recorded, never used |
| G07 | Restraint, rescue, captivity, escape | Studio | Event-specific Free only |
| G08 | Carrying, horses, transport | Seam (mount: Enea; passengers and captives: studio) | Missing; Enea's IDEAS has carcass carrying |
| G09 | Ordinary life and optional drama | Studio | Thin: walking and three loops |
| G10 | Crime, manipulation, live justice | Studio | Focused subset (hearings, public acts) |
| G11 | Groups, factions, cults | Studio | Missing |
| G12 | Collective conflict, proportionate response | Seam | Missing; Enea's bandit camp is a hostile group with alarms |
| G13 | Time storms as playable encounters | Studio | Rite subset; demo cadence to remove (H2) |
| G14 | Reusable settlements and districts | Studio | One village, hand-mapped |
| G15 | Three lands and progressive liberation | Enea | Story start on `camera-test` |
| G16 | Classes, abilities, weapons, dungeons | Enea | Pyromancer and two abilities on `camera-test` |
| G17 | Home, economy, companions | Enea (studio for residents' needs) | Home and projects on `main` |
| G18 | Intuitive world, camera and interface | Enea (studio for its own cues) | Studio cues are debug-grade (H3) |
| G19 | Art, sound, readable consequences | Enea (studio for resident reactions) | Enea's pipeline |
| G20 | Phone performance at useful scale | Shared | S10 only; F5 adds web |
| G21 | Persistence, one clock, authoritative actions | Studio | Village subset works; save budget missing (H1) |
| G22 | Online co-op | Studio (with Enea) | Future; authority has the right shape |
| G23 | Reliable delivery and a repeatable loop | Shared | Studio builds are separate from Enea's app until D-B |

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
| H hygiene | H1-H4 | Selected 30 Sep; next | Base `df6f214`, files under `scripts/studio/` only |

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

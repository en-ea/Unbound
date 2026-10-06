---
title: "The foundation - what the studio built under Unbound, the rules that keep it sustainable, and how to build on it"
created: 2026-10-06
type: hand-over
voice: agent-draft
author: Claude, Foundations thread in Hilmi's studio
status: draft for the merge-enea line; Mind, Body and Animation review their sections through the desk; goes to Enea only with Hilmi's yes
next_step: the desk relays the owners' review; on Hilmi's yes it ships with merge-enea and Enea's CLAUDE.md points here first (proposal in FOUNDATION-CLAUDE-MD-PROPOSAL.md)
---

# The foundation

**Read this first if you are an AI working on Unbound after the studio merge.** You know Enea's game: the meadow, the classes, the bow, the shops, the regions. This page explains what runs underneath it now, and how to add to it without breaking it. Labels: `[repo]` read in the code, `[run]` measured, `[design]` a rule we chose.

Hilmi, 6 Oct `[chat]`: "Since this is a new foundation, we need to ensure we also set a premise for how it should sustainably build from now on".

## 1. What the foundation is

Five layers sit under Enea's game. Each one has a single owner file or folder, and each talks to the next through one door.

```
   INPUT (his buttons, the thumb area, the stick)            WORLD (his scenes, regions, buildings, props)
        │ intents, never facts                                     │ positions, models, water
        v                                                          v
   CONTACT  village/contact.gd ── measures who or what is actually reached (bodies, sweeps, walls, things)
        │ a request {action_id, actor, target, verb, parameters} + measured context
        v
   THE CHECKED DOOR  people_bridge.accept -> acceptance.gd transact ──────────────────────────────┐
        │ inside ONE batch: rules decide facts                                                      │
        │   people_actions.gd  (strike, shove, burn, extinguish, carry, ... on people)              │
        │   thing_actions.gd   (burn, soak, strike, break on things)                                │
        │   People.learn/flush (Mind: what witnesses perceive, feel, remember)                      │
        │ then ONE journal line is written and flushed, and only then is anything published         │
        v                                                                                           │
   STATE  village/sim/state.gd  Village { people[Person{mind, body_facts}], thing_facts, runtime, ...}
        │ read-only for everything below                                                            │
        v                                                                                           │
   CHOICE   people/chooser.gd + offers/  each person scores the offers around them                  │
   BODY     people/body_elements.gd + elements/, mover.gd, crowd.gd  how facts look and move        │
   GRAPHICS render/ (S1 batching, S2 character merge, S4 thing state, S5 houses)  how it is drawn   │
                                                                                                    │
   SAVE  village/sim/image.gd (what disk holds) + village/journal.gd (lines + worker checkpoints) <─┘
```

| Layer | What it owns | Where | Owner thread |
|---|---|---|---|
| Mind | perception, attention, feelings (affect), stances, remembered episodes, pending notices | `people/{perception,attention,appraisal,affect,temperament}.gd`, `village/sim/people.gd` | Mind |
| Choice | what each person decides to do: offers scored by the chooser, carried out as steps | `people/{offer,chooser,performer,step}.gd`, `people/offers/`, `people/steps/` | Mind / shared |
| Body | how a fact looks and moves: elements (burning, down, doused...), one mover per body, crowds, the player's hands and gestures | `people/{element,body_elements,mover,crowd}.gd`, `people/elements/`, `village/contact.gd`, `player/` | Body |
| Village sim | the living village's rules (days, crimes, justice, happenings), deterministic and saved | `village/sim/*.gd` | Foundations |
| Step 4 save | the save image, the journal, the checked door's write | `village/sim/{image,save}.gd`, `village/journal.gd`, `village/acceptance.gd` | Foundations |
| Things | facts on world things (fence, bench, crates, rack): burning, scorched, soaked, struck, broken | `village/sim/{thing_facts,thing_actions}.gd`, `village/things.gd` | Foundations (save) / Body (rules) |
| Graphics | S0 draw probe, S1 static batching, S2 character merge, S4 thing state, S5 house grammar | `render/` and `things/` | Animation |

`[repo]` All of it lives under `game/scripts/studio/`. Enea's own files hold only short marked `# studio:` lines that call into it (section 2.6).

**Rules decide facts; the body decides how they look.** Who was hurt, who saw it, what they feel and remember, and what is burning are facts: keyed, deterministic and saved. Paths, speeds, glances, flames and debris are presentation: free to be smooth and varied, never saved. This is the line every layer respects. `[design]`

## 2. The rules that keep it sustainable

These are not style preferences. Each one exists because breaking it cost the studio a failed build or a lost day; section 5 has the evidence.

1. **One authoritative route for every fact, choice and movement. No special cases.** `[design]`
   - A fact enters only through `people_bridge.accept` and `acceptance.gd transact`. That covers a blow, a fire, a gift or a shove, on a person or a thing.
   - A person's choice comes only from the chooser scoring offers. No scene script decides for a person.
   - A body moves only through its one mover (`people/owners.gd` decides who holds it).
   - If a new feature seems to need a shortcut, the route is missing a parameter. Add it to the route, not beside it.
2. **Game state is separate from visuals and input, and changes only through action functions.** This is Enea's own rule (his CLAUDE.md), and it keeps co-op possible. `[design]`
   - Input produces intents.
   - Contact measures them.
   - The checked door turns them into facts.
   - Visuals read facts and never write them.
3. **Every change is accepted through the checked door.** `transact(prepare, writer?)` runs `prepare` on the live village. If it is refused, replayed, invalid or unaffordable, the batch is put back exactly from the save image. If it is accepted, one journal line is written and flushed before anything is published (no signal, sound or animation of the outcome before the write). `[repo]`
   - A batch that names what it touched (`VillageImage.touch_field`, `touch_person`, `touch_key`) is compared cheaply.
   - Code that writes state must name it. `thing_facts.gd put/clear` show the pattern.
4. **The save guard is on in every test.** `--save-guard` compares the saved image with the live village exactly after every batch, and any difference fails the run. Every runner passes it to every live probe. A probe that sets up its own fixture must mark it as a full save (`VillageImage.stale = true`). `[repo/run]`
5. **Rule 7's budgets** (the phone's frame), measured on the owner's real saves `[design]`:
   - acceptance median 16 ms or less, worst 33 ms or less, no growth over a long session;
   - the save's own time 400 ms or less in every 20-second window;
   - the combined (save plus Mind) total reported, never more than 15 % above the last delivered build's.
   - The workload is a real Heavy and the 9-round escalating session, not a short test. Over 9 rounds the crowd gathers, witnesses pile up, and that is where costs grow.
6. **Edits in Enea's files are marked `# studio:` lines.** A studio system attaches to his game through one short marked line in his file. Examples: `StaticBatch.attach(self) # studio: proposal (graphics S1)` in `main.gd`, and `CharacterMerge.after_look(self) # studio: proposal (graphics S2)` in `character_visual.gd`. The logic lives in studio files. His code is never rewritten silently, so he can always see and remove what we added. `[design]`
7. **Visible changes ship behind switches.** Each look change has a project setting with its default stated: `studio/render/merge_characters`, `batch_static`, `thing_state`, `house_variety`. Each also has a dev argument (`--studio-merge=off`, `--studio-batch=off`, ...). Turning a switch off gives today's scene exactly. `[repo]`
8. **Evidence before claims.** A claim names how it is known: measured, read in code, or the owner's own words. A passing test or an impressive build is not approval. Approval is the owner saying so. A missing result line is not a pass. `[design]`
9. **Extensions are one file in a folder.** People's offers, elements, sources, contacts, modifiers and temperaments, and things' elements, are discovered from their folder by `people/modules.gd` (sorted, ID-unique). A new one is a new file with a unique `ID`: no registration list and no edit elsewhere. `[repo]`

## 3. How to add things - worked examples

Each example names where the code goes, which route it uses and which check proves it. Run the checks from section 4 before you call it done.

### 3.1 A new villager reaction (for example: people cover their ears at a loud bang)
- **The stimulus:** a source file in `people/sources/` (copy `cry.gd`). Give it an `ID`, `make(actor, target, at, fields)` returning a bounded record, and `NOTICE` naming the facts it reveals. The bang is announced through the bridge, never sent straight to a person.
- **What they feel:** Mind turns what they perceive into affect and memory. You add nothing there unless the bang is a new kind of evidence (then add an appraisal feature, Mind's file).
- **What they choose:** an offer in `people/offers/` (copy `retreat.gd` or `help_fire.gd`), with `ANSWERS` (the stimulus kinds it answers), `ROLES`, `PRIORITY`, `can`, `score`, `steps`, `lasts`. The chooser weighs it against everything else they could do.
- **How it looks:** if it is a body state, an element in `people/elements/` (copy `doused.gd`: `ID`, `HOLDS`, `GIVES`, `begin`, `step`, `end`). Fresh-only effects never replay on a reload.
- **Proof:** a line in `people/foundation_state_test.gd` or a new headless test (`run.gd -- <test>`), then the live probe with `--save-guard`, and the regression.

### 3.2 A new thing kind (for example: a cart that can burn, or rain that soaks things)
- **The carrier:** add its model to `CARRIERS` in `village/things.gd` and `render/thing_state.gd` (model path -> kind), and its kind to `KINDS` in `village/sim/thing_actions.gd` (its toughness). Ids are `<kind>@<x dm>,<z dm>`, the same on every load.
- **The facts:** written only through `village/sim/thing_facts.gd put/clear`, inside the checked door (`Contact.things` -> `people_bridge.accept`). Kinds and their fields are listed at the top of that file. A new fact kind means one row in its `KINDS`, plus `LASTING` or `TIMED`.
- **Time:** a rule's own next moment goes in the row's `due_tick`. `advance()` is the one expiry loop, and your rule reacts to the list it returns.
- **Rain:** a world rule, not a thing rule. `thing_actions.gd rain()` soaks exposed things through the same door. The weather decides when; it never writes facts itself.
- **How it looks:** a thing element in `things/elements/`, played by Body's own runtime. The state texture means a change of state costs no draw call.
- **Proof:** `village/sim/thing_facts_test` (shape, codec, journal under the guard), `thing_actions_test` (the rules), Body's live probe `--body-play=things --save-guard`, and graphics S4's check for the look.

### 3.3 A new ability on the controls (for example: a kick)
- **The intent:** his button, or a motion in the thumb area (`player/hands.gd`, `gesture.gd`, `tap_rule.gd`), produces an intent with a press id. It never applies damage.
- **The reach:** `Contact.perform(tree, actor, source, verb, fields, origin, reach, forward)` measures who is actually reached: real bodies, sweeps and walls.
- **The fact:** if the verb is new, add it to `people_actions.gd` (`VERBS` and its branch in `prepare`). Force 0..1000 is separate from harm, and injury stays `Person.hurt`. A press repeated is the same act (the action id), never a second hit.
- **The hook in his code:** one marked line in his ability or player file calling the studio function. The rest lives in studio files.
- **Proof:** `player/act_gesture_test` (the gesture table), `body_play_probe --body-play=contact` and `--body-play=sequence` (the physical acts) with `--save-guard`, and the regression.

### 3.4 A new saved kind (for example: a quest board's notices, or a companion's state)
- **Village-owned state:** add a typed field to `Village` (or `Person`) in `village/sim/state.gd`. The codec (`village/sim/save.gd`) carries every field by reflection under its own name, so the key is stable and nothing else needs registering. Older saves load with the field's default. If old data needs reshaping, convert it once at load (see `People.upgrade` and `ThingFacts.at_load`), never on every read.
- **Writes:** only inside the checked door, and name the field (`VillageImage.touch_field("<field>")`) so the save image compares it.
- **Enea's own saved kinds** (bounties, residents, lettings, waystones, companions, fishing): they move into this format with a one-time conversion. That is part of the merge-enea work, and this section will name where they landed.
- **Proof:** `village/sim/save_test` (round trip, older saves), a journal round trip under the guard (copy `thing_facts_test._journal`), and owner-save on the real saves (`people/owner_save_test --owner-saves=...`): every earlier save must still load.

### 3.5 A new region (for example: a second village in the Highlands)
- **The scene** is Enea's: his region builder and his layout win. Village spots (where people work, gather and live) are read from the real buildings in the scene, never from a hard-coded list, so any layout works. `[design]`: this is part of the merge-enea work, and this section will name the function once it lands.
- **The village state today** `[repo]`: one village (`VillageSession`, an autoload that survives region changes), saved through the image and journal. Its live presentation (`village/live.gd`, the residents' bodies) is attached only in the meadow (`session.gd`: `if Region.current == "meadow"`).
- **Where it is going** `[design]`: more villages, each catching up to the one world clock when you return. The clock is owned by the core game and saved once; caves and beds act on it. That is merge-enea work, and this section will name the functions once they land. Until then, a new region with people means extending `VillageSession`, not adding a second village system beside it (rule 2.1).
- **Things and graphics** attach by themselves: carriers are found by scanning the region, and S1, S4 and S5 attach through the existing `StaticBatch.attach` line once the region is built.
- **Proof:** normal entry into the region with 0 script errors, the regression, and the sustained session on a save that has visited it.

## 4. The checks to run, and what passing means

All runners are in `tools-src/studio/cloud/runs/` and need the studio clone beside the game repo (`STUDIO_ROOT`) for the owner's real saves. They print one `JOB <name> PASS|FAIL|INCOMPLETE` line per check. A check passes only when its run completed, its expected result lines all appeared, and there were no failure lines and no engine errors.

| Check | Command | Passing means |
|---|---|---|
| Regression | `bash tools-src/studio/cloud/runs/regression.sh <new evidence dir>` | every job PASS (people, Mind, Body, things, graphics S1/S2/S4/S5), and no `FAIL save-image guard` line in any log |
| Release gate | `bash tools-src/studio/cloud/runs/gate.sh <new evidence dir>` | `GATE complete status=0`: the owner's real saves load with no recovery fallback, every memory kept, then one new action, decay, a gift, an interruption and reload with no duplicate harm (owner-save 40), owner-play 11, encounter 28 |
| The guard | `--save-guard` on every live probe (the runners pass it) | silence: any `FAIL save-image guard` line fails the change, whatever else passed |
| Sustained session | 3 sessions x 9 rounds of the owner-play workload from a real save, each 20 s window split into the save's share and Mind's share, with `vmstat 1` alongside | rule 7 holds in every window (section 2.5) and against the last delivered build |
| Normal entry | the main scene with no arguments on each real save | 0 script errors, no recovery fallback |

Evidence folders are always new (the runners refuse an existing one). A rerun under the same name once loaded the previous run's village, a false alarm that cost a day (L031).

## 5. What not to do (lessons, short)

- **L027 - don't verify heavy work on a hot shared machine.** A laptop's heat gate held a finished repair unverified for two hours, while a cloud machine ran the same batch in three minutes. Run heavy checks where they don't queue behind heat or other work.
- **L028 - judge picture parity in place, not across launches.** A living village does not replay frame for frame, so comparing two launches hid a missing player in 5 of 9 views. Compare the frame, the change, and the frame again, in one paused moment.
- **L029 - release-check against the owner's real saves.** A build that passed every generated test produced 3,968 script errors on Hilmi's phone, because his save held older records. The real saves are fixtures: every candidate loads them first.
- **L030 - gate on sustained, escalating play.** Three short rounds passed while nine rounds doubled the cost as crowds gathered. The gated workload is the long session.
- **L031 - keep the exact save check on in every live probe.** Cheap change signals missed three real gaps (objects edited in place, a list that kept its size, a double learn in one frame). Only the exact guard on every probe found them.

## 6. Where everything lives

- **Contracts between the layers** (who produces and who consumes each record): `docs/studio/PEOPLE-CONTRACTS.md`.
- **Why the people layers exist and what they replaced:** `docs/studio/PEOPLE-ARCHITECTURE.md`.
- **Graphics batching and the switches:** `docs/studio/RENDER-BATCHING.md`.
- **Running checks in a cloud session:** `docs/studio/CLOUD-SESSIONS.md`.
- **Code:** `game/scripts/studio/` (people, village, village/sim, player, render, things). The runners are in `tools-src/studio/cloud/`.
- **Enea's files with studio lines:** search for `# studio:`. Each line is a proposal he can read and remove.

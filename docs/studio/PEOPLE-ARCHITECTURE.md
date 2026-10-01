---
title: "The people architecture - what each layer does, what it replaces, and the order to build it"
created: 2026-10-01
type: design
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio
status: proposal; awaiting Hilmi's go. The seams in section 4 also need Enea's OK
next_step: Hilmi reviews this; on his go the lead plans Pass 3 as steps 1 and 2 of section 5
---

# The people architecture

## Why this exists

Hilmi, 1 Oct `[chat]`:
- "I am still not very happy with the interaction of people or the way they react to getting hit (very simple and robotic)"
- "every tiny change we do, I want it to be infrastructure that allows interesting things to spawn around the world and more interactional type things. we spent so long stressing the dynamic behaviour of npc's and it feels like its been too narrow on completing the task rather than making a genuine expandable experience."
- "the speed and movement of these npc's look way too robotic, and they walk through eachother, surely there is a clever algo you can make"

`[repo]` **The cause.** Pass 2 built each interaction as its own special case:
- **Scenes:** each scene kind is hand-written across five files. For example, "chat" appears in `director.gd` (its own `_bring_*`), `crime.gd`, `incidents.gd`, `staging.gd` and `stage.gd`.
- **Reactions:** a reaction is one label per blow, from a rule tree (`reactions.gd`), and each label maps to one stock animation (`resident_acts.gd`).
- **Movement:** a body's position is computed from its timetable, so nothing can deflect it.

Each new interaction therefore costs new code in several files, and nothing compounds.

`[design]` **The aim.** Every change becomes infrastructure:
- things in the world offer something to do;
- people notice, feel, choose and move like people;
- a new interaction is mostly data.

## 1. The shape

```
 anything in the world: a person, the player, Enea's wolves and crows, a carcass, the well, a fire, someone hurt
    │ gives off STIMULI (noise, sight, touch)          │ OFFERS things to do (help up, gawk, butcher, chat, steal)
    v                                                  │
 PERCEPTION   who notices what, and what they attend to (Enea's sight model plus hearing)
    v                                                  │
 INNER STATE  fear, anger, interest, pain and alertness that build and fade;
    │         remembered episodes (who did what to whom, where)         [rules: saved, deterministic]
    v                                                  v
 CHOICE       each person scores the offers around them  ──────────> joins or starts a SITUATION
              (needs, feelings, temperament, relations)              (a conversation, a crowd, a quarrel, a brawl,
                                                                      a hearing: roles, places, who speaks, escalation)
    v
 BODY         steering and avoidance, gait, head and eyes, flinch, gestures, one voice at a time

 SPAWNER (the director, rebuilt): places situations and things near the player, and later along roads and in
          found villages, when the world's state fits them
```

**Where the line runs.**
- **The rules decide facts.** Who was hurt, who saw it, what they now feel and remember. These are keyed, deterministic and saved.
- **The body decides how it looks.** Paths, speeds, glances and gestures. It is free to be smooth and varied, and is never saved.

This is the boundary Pass 2 already uses for actions and witnesses.

## 2. What exists, and what each layer turns it into

| Layer | Today `[repo]` | Becomes `[design]` |
|---|---|---|
| Body | `residents.gd` replays timetables. `resident_acts.gd` has one hand-written routine per reaction. `stage.gd` plays scripted beats. `villager_body.gd` has an AnimationPlayer and one procedural modifier (the running lean) | One body controller every person uses: on routine, in a scene, reacting or fighting |
| Perception | Rules: witnesses by place at the minute of a deed (`crime.gd`). Game: Enea's sight model asked once per blow (`provoke.gd witnesses`) | A shared stimulus door and senses, used by people, creatures and the rules bridge |
| Inner state | Traits, opinions, grudges, beliefs, stress, `hurt`; the player's standing as memory tokens (`runtime.acquaintance`); the event log `V.events` | Affect (fear, anger, interest, pain, alertness) plus episodes that refer to logged events |
| Choice | Crime motives (motive, opportunity, inhibition); daily plans; `director.gd _bring_*`; the reaction tree | One utility chooser over offers, for every kind of behaviour |
| Situations | Stagings (roles, phases, beats) and runtime events (hearing, public act, rite, incident) | Situations with roles, places and turn-taking. Authored events (hearings, rites) stay scripted but run on the same bodies |
| Spawner | `director.gd` attention: six hand-coded scene kinds | A catalogue of situation templates and world things with conditions; the director places them |

**What stays.**
- The rules kernel, justice, gossip, the runtime authority, the save, the stage's authored events, and every Pass 2 check.

**What goes as each layer replaces it.**
- `reactions.gd`'s tree;
- `resident_acts.gd`'s per-state routines;
- `incidents.gd`'s per-kind builders;
- `director.gd`'s `_bring_*`;
- the timetable replay for bodies near the player.

## 3. Each functionality

### B - Body (presentation only)

| ID | Functionality | Replaces or fixes | Done means |
|---|---|---|---|
| B1 | **Steering locomotion.** The timetable gives a goal and a deadline. The body has velocity, acceleration and a turn rate, eases to a stop, and hurries when it is late. Speed comes from age, mood and urgency: stroll, walk, hurry, jog, run | Timetable replay; uniform speed; instant starts and stops | Two people on the same errand move differently. No snapping when a plan changes |
| B2 | **Avoidance.** Reciprocal velocity obstacles (ORCA): each person steers around others, the player and Enea's creatures before they touch. Godot's NavigationServer has RVO-based avoidance built in; check it on 4.7 and in the web build first, and write our own ORCA over a grid if it falls short. Static obstacles come from the stage's existing router. Personal space depends on the relation | Walking through each other; the heap of people | Zero body overlaps per minute in the square at the evening chat |
| B3 | **Formations and places.** Conversation circles (F-formations) with an open space in the middle; a spectator ring at a set distance; queues; pairs side by side. Each person gets their own place in a situation | Everyone running to the same spot | A crowd round an incident forms a ring. A conversation of three forms a circle |
| B4 | **Gait.** Walk and run play at the speed actually moved (no foot sliding), with starts, stops and turning steps. Idling varies: weight shifts, glances | Skating, mechanical loops | A frame sequence shows feet planted |
| B5 | **Head and eyes.** A look-at modifier, built like the running lean: the head turns first, then the body. Glances go to whatever was noticed (P3). A conversation's turn-taking moves the gaze | Whole-body snapping turns | Heads turn to a noise before anyone moves |
| B6 | **Impact.** A procedural flinch, stagger or knock-back on every blow, scaled by its force, added over whatever the body is doing. Enea's hit clips are used where they fit | Hitting a statue | Every landed blow shows within 0.1 s, whatever the reaction |
| B7 | **Speech.** One voice at a time within a situation, taking turns. Priority goes to the one struck, then whoever steps in, then the crowd. Bubbles are capped in size and never overlap. Short vocal sounds (Enea's voice blips) carry the barks that need no words | The wall of words; the huge bubble near the camera | No overlapping speech. No bubble wider than about a third of the screen |
| B8 | **A gesture vocabulary.** A small set of upper-body gestures that compose with walking: point, beckon, hands up, wave off, cover face, shrug, kneel and help. Which animations to use is Enea's call on the look (section 4) | Spell and repair animations standing in for feelings | Each gesture reads as itself on a look board |

### P - Perception

| ID | Functionality | Replaces or fixes | Done means |
|---|---|---|---|
| P1 | **The stimulus door.** One typed record: kind (a blow, a shout, a fall, running, a scream, a carcass, fire, a bell, a wolf), position, loudness or visibility, source, time. It is given off by anything through one call | Each scene's private "who saw it" code | Enea's wolves and carcasses become noticeable through a one-line hook each |
| P2 | **Senses.** Sight uses Enea's model (range, view cone, night, sneaking, line of sight). Hearing uses loudness against distance, with walls damping it | Sight asked only at the moment of a blow; no hearing | A shout behind a house is heard but not seen; a blow behind it neither |
| P3 | **Attention.** What each person is attending to. Noticing takes time, longer when distracted or far away, and repeated stimuli matter less | Everyone reacting in the same frame | Onlookers notice over 0.2 to 1.5 s, not all at once |
| P4 | **One spatial grid,** shared by perception, avoidance and offers | A full scan of every body on every check | The cost grows with the people nearby, not with the whole village |
| P5 | **The rules bridge.** What a person perceived and that matters reaches the rules as an observed fact (who saw what, when), exactly as Pass 2's witnesses do | `player_sees` and `provoke.witnesses` as separate special cases | One path for every deed |

### S - Inner state and memory (rules side: deterministic, saved)

| ID | Functionality | Replaces or fixes | Done means |
|---|---|---|---|
| S1 | **Affect.** Fear, anger, interest, pain and alertness per person, as integers. Events raise them; they fade at rates set by temperament; they are saved | No state between blows | A second blow lands on someone already frightened |
| S2 | **Appraisal.** One function judges any event for a person: who did it, to whom, how bad, whether provoked, whether they are safe, their role and their relations. Its output is affect changes | The reaction tree; separate logic for blows, theft, gifts and wolves | The same blow gets different answers from different people, and from the same person on different days |
| S3 | **Episodes.** One memory record: who did what to whom, where and when, how bad it was, and how it was learned (saw it, told). It refers to the existing event log, and gossip and reports pass these records along | Memory tokens that cannot name what happened | A line names the event: "you hit Oswin at the well" |
| S4 | **Stances towards others.** Wary of (keep away), trusts, owes, resents. They come from episodes and fade over days | Forgetting within seconds | A struck villager keeps their distance for hours |
| S5 | **Expression hints.** Affect becomes posture, gaze, the distance kept, walking speed and word choice, for the body to act out | Every person of a label acting the same | The same state looks different in a timid and a bold person |

### C - Choice and situations

| ID | Functionality | Replaces or fixes | Done means |
|---|---|---|---|
| C1 | **Offers.** People, things, places and situations advertise actions. Each offer is data: who may take it (age, role, state), how attractive it is (a function of needs, affect, traits and relations), its effects in the rules, and a behaviour for the body | Special-case code per interaction | A new interaction ("help up the fallen") is added as data only |
| C2 | **The chooser.** Each person scores the offers within reach (P4) and keeps a choice for a while rather than flip-flopping. Ties are broken by key. People near the player think a few times a second; far away, they think rarely or fall back to the rules' day | `_bring_*`, the reaction tree, per-scene casting | Choices can be traced: why each person did what they did |
| C3 | **Situations.** A shared object people join: roles, places (B3), turn-taking (B7), states (calm, heated, violent, over) and how it escalates or ends. Conversation, crowd, quarrel to brawl, helping, mourning, trading. Hearings and rites become situations with authored scripts | Scripted beat lists for incidents; onlookers acting alone | A quarrel can cool, or escalate when someone joins |
| C4 | **Behaviours.** Composable steps (go to a place, face, look, gesture, say, wait for, use the thing, follow, keep away), with their parameters taken from affect. Written once, reused everywhere | One routine per reaction state | Fleeing, fetching help and stepping in share the same steps |
| C5 | **The spawner.** The director becomes a placer. Situation templates and world things have conditions on the world's state and a pacing budget (small often, notable about hourly, grave rare). The same placer serves roads and found villages later | Six hand-coded scene kinds | A cart with a broken wheel appears on the road. Who stops to help depends on who they are |
| C6 | **The first catalogue.** Conversation; a gawking crowd; helping the fallen; fetching help that actually comes; tending wounds; comforting; scolding; avoiding someone feared; greeting or calling out to the player; trading a gift; a quarrel that can escalate; a pen to steal from; a carcass to gawk at or claim | Pass 2's six scenes | Each one is data plus behaviours, and is played on a look board |

## 4. Seams with Enea (each needs his OK)

| ID | Seam | Why |
|---|---|---|
| E1 | **Hooks in his creatures and things.** One line to give off a stimulus, and one to declare offers. Wolves, bandits, carcasses, crows, fire | `[repo]` His carcasses already draw crows, then wolves, and "left in the village, someone takes it" (`world/carcass.gd`). This generalises his pattern so villagers can be that someone |
| E2 | **Fighting back through his enemy behaviour.** A villager who fights back borrows his enemy brains with a villager's profile: fists, cautious, yields when hurt. His bandits circle, wind up, attack, recover and stagger; his wolves also feint, lunge, retreat and dodge | `[repo]` Our fighter only loops: close in, wind up, swing, recover. His bandits and wolves each have 11 states (`creatures/bandit.gd`, `creatures/wolf.gd`). Two combat brains would be a duplicate |
| E3 | **The animation source** for gestures and reactions (B8) | His look and feel. Quaternius has few emotional clips, and his notes say hand-posed animations looked bad |
| E4 | **His talk panel** for conversations | It already carries every villager's talk |

## 5. The order to build it

```
 1 BODY FOUNDATION   B1 steering · B2 avoidance · B3 formations · B4 gait                  presentation only
        │
 2 BODY EXPRESSION   B5 head and eyes · B6 impact · B7 speech                              presentation only
        │
 3 PERCEPTION        P1 stimuli · P2 senses · P3 attention · P4 grid · P5 rules bridge      (E1 for his creatures)
        │
 4 INNER STATE       S1 affect · S2 appraisal · S3 episodes · S4 stances · S5 expression    rules and save
        │
 5 CHOICE AND        C1 offers · C2 chooser · C3 situations · C4 behaviours                retires the special cases
   SITUATIONS
        │
 6 THE WORLD         C5 spawner · C6 catalogue · found villages by seed later               the expandable part
        │
 7 ENEA'S SEAMS      E2 fight back through his enemy brain · E3 gestures                   whenever he agrees; can come earlier
```

**Why this order.**
- **Steps 1 and 2 fix most of what is visibly robotic,** with no risk to the rules or the save:
  - walking through each other, and uniform speed;
  - the heap of people;
  - hitting a statue;
  - the wall of words;
  - snapping turns.

  Every later layer needs a body that can be steered, placed and made to look.
- **Step 3 comes before step 4,** because affect has nothing to react to until people perceive.
- **Step 5 comes after both,** because a chooser without senses or feelings is the old rule tree again.
- **Step 6 is the payoff Hilmi asked for:** things placed in the world that people are drawn into.
- **Each step ends in a playable build,** and retires the special cases it replaces.

| Step | You would see `[design]` | Judged by |
|---|---|---|
| 1 | No one walks through anyone. Speeds differ by person. Circles, rings and pairs, not heaps | Frame sequences of the square; body overlaps per minute (0); spread of speeds across people |
| 2 | Every blow lands visibly. Heads turn to the noise. Speech you can read | Frame sequences around a blow; overlapping speech (0) |
| 3 | Onlookers notice one by one and look first. Villagers notice wolves and a carcass | Spread of reaction onsets; hooks in Enea's code with his OK |
| 4 | Reactions grow out of a person and last. Lines name what happened | The same blow answered differently by history; save and load keep affect; sweeps extended with affect invariants |
| 5 | Helpers come. A crowd forms and talks. Quarrels cool or escalate | Special cases removed (counted); one interaction added as data alone |
| 6 | Things happen along the road and around the village that people are drawn into | A new situation added as data appears in play |

**Judged by eye as much as by code.** Pass 2's checks all passed while the behaviour was robotic, because they test that something happens, not how it reads. Each step's verdict therefore rests on:
- look boards and frame sequences;
- the robotic signs measured above;
- Hilmi's eye.

The logic checks stay underneath.

## 6. Cost and risk

- **Phone budget.** Today the villagers cost 0.8 ms of a 49 ms frame on this PC's web build `[run]`. Budgets: body at most 1.5 ms and thinking at most 0.5 ms for 30 people near the player, measured at each step. Far from the player, people stay on the rules' day.
- **Determinism.** Affect, episodes and choices with consequences stay in the keyed rules. Bodies may vary freely.
- **Scope.** Each step is one pass or less, ends playable, and is not merged until Hilmi has looked.
- **Enea.** Our side of every seam is built first. His code changes only through the hooks he agrees to.

## 7. Master goals served

G02, G03, G04, G06, G09, G11 (groups are situations that last), G12, G14 (found villages through the spawner and seeds), G18, G19 and G20 (`MASTER-GOALS-r2.md` section 4).

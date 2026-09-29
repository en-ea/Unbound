---
title: "Unbound route r4 - a living world you play through, with friends: the vertical slice first"
created: 2026-09-29
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio
status: route; decisions of 29 Sep recorded in section 8; open questions in section 9
supersedes: docs/studio/ROUTE.md (route r3, kept unchanged as the record; its kernel, misbehaviour catalogue, singled-out rules and storm research carry over)
inputs: docs/studio/inputs/2026-09-29-owner-ideas-ai-summary.md (an AI summary Hilmi supplied, plus his own words)
next_step: M0 - the multiplayer spike (two phones, one fight, online, on two candidate backends); in parallel M1 - the village's crimes, trials and storms, headless
---

# Unbound, route r4: a living world you play through, with friends

## 0. Verdict

1. **The game is a third-person action-adventure for 2-4 friends across three lands**, set inside a world that lives on its own `[chat]` (the summary Hilmi supplied, and his own words):
   - each player starts as the champion of their own land;
   - villages grow, steal, scheme, try people and hang them;
   - time storms drag parts of the land back into earlier ages;
   - a few story villages stay stable as checkpoints;
   - you play from the ground: fight, trade, sneak, and now and then manipulate people to stage an event.
2. **Nothing is managed from above.** Route r3's god-view ladder, map table and village diorama are dropped. Influence becomes your reputation and your power to stage events.
3. **The foundations from sessions 1-3 all carry over, and matter more:**
   - **The world kernel.** It gives the identical world on every phone, and that is what keeps four players in one world. Its history is where a storm gets the older age from `[run]` (`KERNEL-S2.md`).
   - **The misbehaviour and "singled out" rules.** They are now staged physically, with the gallows in the square.
   - **Native apps, the device lab and the three phone fixes** (pull requests #2-#4).
4. **The biggest engineering change is live multiplayer.** Fights and enemies must be networked in real time, not only the world. It has to be designed in now, because Enea's combat is single-player code today and adding multiplayer later is how projects stall.
5. **The next target is a vertical slice** (Hilmi, 29 Sep `[chat]`): one land, two villages, one storm, one crime leading to a trial, and two phones playing live (section 4). Everything else waits until that slice is fun.

---

## 1. The game in one loop

```
  YOUR LAND (you are its champion)                                   LAND 3 (with friends)
  ┌──────────────────────────────────────────────────────────┐       ┌───────────────────────────────────┐
  │ NOTICE ──► GO ──► ACT ──────────────► CONSEQUENCE ───┐   │ sea   │ live co-op · convergence          │
  │ smoke,    walk    fight · trade ·     the village     │   │ ────► │ secret traitor orders at key      │
  │ a crowd,  or run  sneak · barter ·    remembers; the  │   │ routes│ moments · disguise by regional    │
  │ a storm   there   manipulate (plant,  land is pacified│   │       │ armour                            │
  │ on the            bribe, testify)     step by step    │   │       │                                   │
  │ horizon                                              ─┘   │       │                                   │
  └──────────────────────────────────────────────────────────┘       └───────────────────────────────────┘
   underneath, always: the world kernel (villages, crimes, trials, storms, ages), identical on every phone
```

---

## 2. What changes from route r3

| Route r3 | Route r4 | Consequence `[design]` |
|---|---|---|
| Influence ladder from villager to ruler: wider views, a map table | A champion on the ground; no management layer | Drop the god-view rungs, TABLE and the diorama. Influence = reputation and staging power |
| A camera "director" with explore, fight, build, witness, talk and vantage framings | **One default camera, the tilted view** (-32°, Hilmi's pick). The low, eye-level view **only when switched on to look at something**. The high view for building. Closer inside buildings; a simple zoom when talking | Much less camera work. Section 3.8 |
| "Tap anyone: what they want and why"; a text chronicle | **Show, don't read** | Intent shown through movement, gestures, short spoken lines, crowds, props (a gallows going up, torches). The chronicle becomes a testing tool or an in-world notice board |
| On-device AI voices for named villagers | Not needed for now | Template lines and barks. This removes the memory cost and the uncertain question of Apple's model in a free-signed app |
| A storm folds a district into its own past, beside the present | A storm wave regresses a zone to an earlier age; the player stays as they are | One mechanism covers both (section 3.3). **New art cost: every age needs buildings, clothes and behaviours** |
| Two players sharing a world, mostly asynchronously | 2-4 players, separate starting lands, live together in Land 3, secret traitor orders | Live netcode for fights and enemies, plus the kernel's action log for the world (section 3.9) |
| A $99 Apple account as one option | No paid accounts; a small budget from Hilmi for services | iPhone through free sideloading. One small server becomes possible |
| Negotiation as part of the social layer | No diplomacy minigames. Manipulation is a side dish, "a fun component to see how we can manipulate behaviour and stage events" (Hilmi `[chat]`) | Levers are actions and items in the world, never menus |

---

## 3. The systems, reconciled

### 3.1 The world kernel (carries over from S1 and S2)

It stays deterministic and integer-only, and runs on a worker thread `[run]`. Additions:

| Addition | What it is |
|---|---|
| **Anchored settlements** | Story villages. The kernel never storms them and keeps them free of random ruin. Quests and hand-built content live there safely |
| **Ages (three)** | Tribal (stone age), village (today's look) and town. Each settlement, district and person carries an age. Values, law, language and building family all follow from it |
| **Regression zones** | A storm sets a zone's age back. Its population is replaced by that place's own ancestors from the history log (section 3.3) |
| **Language distance** | Computed from the difference in age and people. It decides how you can interact (section 3.4) |
| **Staged-event output** | Alongside chronicle events, the kernel emits **stagings**: who gathers where, the steps of a trial, where the gallows goes. The game plays them out near the player |
| **Manipulation verbs** | Actions entering the log: plant an item, tell someone something (a rumour), give coins (a bribe), testify, free a prisoner. They can be done by players and, later, by scheming villagers |

### 3.2 Village life: crimes, trials, punishment

This is r3's behaviour stack, now embodied:
- **Minds.** Needs, values (per person, people and age), grudges and secrets. From these come crimes: theft, smuggling, bribery, violence and heresy (`ROUTE.md` section 5 catalogue). The storyteller paces them so a village never spirals.
- **Singled out** (`CAMERA-AND-FORMAT.md` section 7, grounded in the witch-trial and plague-pogrom research) `[web]`:
  - a group's risk rises with a shock, with how much it is seen as outsiders, with the age's belief in plots, and with rumours;
  - it falls with how much the village needs the group;
  - the age's law chooses the outcome: exile, pillory, hanging or burning, or veneration if good fortune followed them.
- **Near the player, villagers are full bodies.** Behaviour trees or state machines handle walking to the square, working and fleeing, and they carry out the kernel's decisions. Far away they are folded into households and keep their identity. (STALKER's lesson, `ROUTE.md` section 4.)
- **Legibility without reading.** Each notable act has a visible cause chain: someone seen taking, someone telling, a crowd forming, the elder calling a trial. The headless test from r3 carries over: every notable act has a logged reason, now paired with a staged cue.

### 3.3 Time storms, with three ages and ancestors

Decided 29 Sep `[chat]`: storm people are **their own ancestors**, and there are **three ages**.

```
 FORECAST (a dark front on the horizon, days ahead) ──► the wave hits a zone (never an anchored village)
      zone age ◄── set back one or two ages (village → tribal; town → village or tribal)
      buildings ── swapped to that age's family, plot by plot (the same growth stage, another age's models)
      people ───── replaced by that place's ancestors, rebuilt from the history log: names, knowledge,
                   grudges, and that age's values, law and tongue
      the player ─ unchanged: stats, weapons and inventory intact
 then the ordinary rules run: the zone and the rest of the village claim the same fields, graves and name
      ─► coexistence and barter · a split (the old part turns on the village it came from) ·
         merging over time · the storm returning to take them back
```

- **The simulation already showed this conflict without a script** `[run]` (S1b, re-run on integers in S2): fighting in 25-70% of storms within 25 years.
- **Taken from r3:**
  - storms add, never erase (the player's builds are anchored);
  - consequences settle after a while;
  - forecasts give a reason to open the app.

### 3.4 Language distance (unifies the isolated tribes with time)

| Distance | Between | What you can do |
|---|---|---|
| 0 | the same age and people | talk (short lines), trade, hire, testify |
| 1 | a neighbouring age, or another people | trade with misunderstandings (wrong goods, odd prices), gestures |
| 2 | two ages apart, or an uncontacted tribe | barter rituals and gestures only; sounds, not words |
| hostile | territorial, and threatened | spears on sight; warning calls first |

This makes the summary's "linguistically isolated factions" what time *does*, not a separate system. There are no translated persuasion menus `[chat]`.

### 3.5 Manipulation, as a side dish

The levers are:
- plant evidence;
- start a rumour (tell the right person);
- bribe the judge;
- testify at the trial;
- free a prisoner at night;
- join the mob.

Each is an action in the world, entered into the log, and the outcome is staged. It is fun to try and never required.

### 3.6 Show, don't read

The legibility budget goes to animation and staging:
- gestures and postures (fear, anger, reverence);
- one-line barks from templates, at most a sentence;
- crowd gathering and dispersal;
- props: gallows, pillory, torches, a shrine, notices;
- sounds.

The text chronicle stays as our headless test output. In the game it may appear as an in-world notice board or a town crier, if Enea wants it.

### 3.7 Combat and inventory (Enea's layer; the studio advises)

The summary's designs are:
- **Gesture cluster:** hold to lock on and close in, drag down to parry, drag up for a special.
- **Loadout and items:** a loadout switch, an auto-use healing item, a radial wheel for items, and target cycling.
- **Two tiers of skills:** permanent upgrades, plus spells from the black market or crypts.

**Studio notes** `[design]`:
- **Prototype the gesture cluster on both phones before it replaces the current controls.** It clashes with today's hold-to-sprint, and auto-approach removes positioning skill.
- **Build it networked from the start** (section 3.9): inputs go to the authority, and results come back.
- **Feed the black market from the villages' own smugglers.** That illicit economy is the source of rare spells.
- **Disguise uses Enea's outfit system** (13 ready-made outfits): regional sets grant faction clearance.

### 3.8 Camera

Hilmi, 29 Sep `[chat]`:
- "we don't think different camera angles for fighting is necessary unless its some simple zoom in";
- "I do not think the low camera would be used much unless its specifically enabled to view something";
- on look board 1's three views: "remember there was 3 though, one low/eye level, one tilted and one high - I think best was tilted".

| Mode | When | Framing |
|---|---|---|
| **Default** | almost always, fighting included | **The tilted view:** -32°, 12 m, field of view 45° (look board 1's second row, labelled FIGHT there). Hilmi's pick; Enea to confirm |
| **Look** | switched on to view something: the other lands from the shore, a storm front, a gathering | The low view (-10°, the EXPLORE row). The fog is pushed out for it (60-300 m; look board 1 shows the vista it uncovers) |
| **Inside** | in a building | Closer; walls fade |
| **Talk** | with a villager | A simple zoom-in |
| **Build** | placing things at home | The high view: today's -45°, 18 m, field of view 32° |
| **Fighting** | any mode | Edge markers for attackers off screen. **Target-follow** (the camera turns to keep your lock) in the Look mode |

**Evidence** `[run]`:
- On the S10, every framing held 30 fps standing still.
- The tilted default wasn't among the S10 runs. On the PC it draws 270 calls and 82k triangles: close to today's high view (207 calls, 61k) and far below the eye-level view (746, 171k). So 30 fps on the S10 is expected, not yet measured (M3 measures it).
- Turning the low camera stutters on some launches; the cause is not yet attributed (`LOOKBOARD-1.md`, correction).
- Occasional use makes this smaller, but the shader warm-up still gets extended.

### 3.9 Multiplayer: structure, architecture, options

**Structure** (the summary, as confirmed in chat):
- Player 1 starts in Land 1, Player 2 in Land 2.
- Players 3 and 4 join as lieutenants.
- Everyone converges on Land 3 by sea.
- Private traitor orders arrive at key moments.
- Disguise works by regional armour.

**Architecture** `[design]`:
```
 WORLD LAYER  - the kernel's action log; each phone computes the same world (proven identical, S2)
               apart: each land's log is stored in the cloud; together: logs merge in one canonical order
 LIVE LAYER   - players, enemies, hits and projectiles; one authority (a phone or a small server) simulates,
               the others send inputs and draw what it sends; runs at 20-30 Hz with interpolation
 PRIVATE      - traitor orders are sent only to that player's screen (fine among friends;
               a modified app could read them, which is acceptable here and not for a public release)
```

**Backend options**. There is no choice yet: a spike (M0) measures them `[web]`.

| Option | Cost | Strengths | Weaknesses |
|---|---|---|---|
| Epic Online Services via the EOSG plugin | £0 | Free relays for phones on mobile networks; lobbies; cloud storage; iOS arm64 and Android arm64 builds | Unofficial plugin; needs a free Epic developer account (a person signs up); one phone hosts |
| A small server (e.g. Hetzner CX23, about €6/month) running a headless Godot server or Nakama | about £5/month | The server referees: fair fights, no phone has to host, it stores the logs | Someone maintains it; slightly over £5 |
| WebRTC phone-to-phone, plus Cloudflare's free STUN and TURN (1,000 GB/month free), plus a small matchmaking service on Hilmi's domain | about £0 | Cheap and flexible | More plumbing; one phone hosts |
| Home Wi-Fi only | £0 | Simplest | No online play |

What Hilmi's own domain runs on decides whether it can carry the matchmaking and log storage (section 9).

### 3.10 Platforms and tools

- **Android.** Native APKs installed directly. The device lab already builds, signs and measures them.
- **iPhone.** Free sideloading (SideStore or AltStore): re-sign every 7 days, at most 3 sideloaded apps (`IOS-FINDINGS.md`). Builds need macOS: GitHub's macOS runners, within the free minutes. The CI workflow needs Enea's repo to hold it.
- **Emulators.** Used for multi-client tests (3-4 players on the PC), never for performance. The S10 stays the floor.
- **AI.** Deterministic state machines and templates. The on-device LLM layer is parked.

---

## 4. The vertical slice

| Part | In the slice | Not yet |
|---|---|---|
| World | Land 1 (Enea's meadow region). **One story village** (anchored: Enea's existing village). **One ordinary village** that lives by the kernel | Lands 2 and 3, the sea, the town age |
| Villagers | 20-30 near you with needs and values. One crime chain: theft → accusation → gathering → trial → a punishment by the age's law | Schemes, faith, factions |
| Manipulation | Plant evidence, testify, bribe | Rumour chains, freeing prisoners |
| Storm | One forecast storm. Part of the ordinary village regresses to the **tribal** age: ancestors, language distance 2 (barter or spears), border conflict, one of the four endings | Multiple storms, the town age |
| Combat | Enea's combat plus a lock-on and parry prototype; edge markers | Radial wheel, spells, target cycling |
| Camera | The tilted default, Look (eye level), Inside, Talk, Build (high) | - |
| Together | **Two phones live in the same land:** the same enemies, the same trial, the same world | 3-4 players, traitor orders, disguise |
| Platforms | Native Android. iPhone sideloaded, if the macOS build route works | - |

**Done when:**
1. You and Enea play 20 minutes on two phones, and each tells a story the village made (a trial or a storm) that neither of you scripted.
2. It holds 30 fps on the S10.
3. There is no divergence between the phones over 20 minutes: the world hashes match and the live layer stays in sync.

---

## 5. Order of work (milestones, gated)

| # | Milestone | Done when | Needs |
|---|---|---|---|
| **M0** | **Multiplayer spike**: two phones, one boar, online. The S24 on 4G against the S10 or the PC, on **two** backends | Latency and reliability measured; a backend chosen with evidence | A free Epic developer account if EOS is tested (someone signs up); a server if the server route is tested (Hilmi's budget); Y3 (the S24) |
| **M1** | **The village, headless** (A0 reshaped): crimes → trials → punishments; storms → regression → ancestors; language distance; staged-event output; anchored villages | Thousands of simulated years pass the invariants: every notable act has a reason and a staged cue; no collapse loops; no single behaviour dominates; conformance against a JavaScript reference | Nothing |
| **M2** | **The village on screen**: embodied villagers and stagings (gathering, trial, gallows) in Enea's game; the ordinary village built from building families, today's plus tribal | A trial plays out on the S10 at 30 fps, and you can read it without text | M1; tribal building and clothing sets (Blender scripts, Enea's pipeline) |
| **M3** | **Camera**: the tilted default, Look, Inside, Talk, Build; edge markers; target-follow in Look; the shader warm-up extended; a Perfetto trace of the turning stutter | Smooth switching between modes; no stutter above 50 ms on the S10 after the warm-up | Enea confirms the tilted default |
| **M4** | **Live together**: the chosen backend; host authority for enemies and hits; the world log in sync | 20 minutes on two phones with no divergence | M0, M2 |
| **M5** | **Slice playtest** (owner play) | The "done when" of section 4 | M1-M4 |

**In parallel, Enea's layer:**
- the lock-on and parry prototype, built to the networking rules the studio gives him from M0;
- the auto-use healing item and the loadout switch.

---

## 6. Art for three ages

- **The swap stays mechanical.** Each plot keeps a function and a growth stage (`BUILDING-SHEETS.md`: families by function and stage, plus ruins). An age is one more axis: the same plot, another age's model.
- **Tribal set, needed for the slice:**
  - huts, hide tents, a longhouse;
  - a totem or shrine, a fire pit, palisades;
  - hides and bone clothing;
  - spears.
- **The town set comes after the slice.**
- **Enea's Blender pipeline builds them from scripts** (`tools-src/blender/make_village.py`), and look boards decide the look `[repo]`.

---

## 7. Risks

| Risk | What we do |
|---|---|
| Live multiplayer arrives late and breaks single-player systems | M0 first. Enea's combat and every new system follow the networking rules from the start |
| "Show, don't read" costs more animation and staging than expected | One crime chain in the slice. Reuse the Universal Animation Library animations; props do the talking |
| Art per age multiplies | Three ages, and only tribal in the slice. Plot-by-plot swaps reuse the families |
| Gesture combat feels worse than the current buttons | A prototype on both phones first; Enea decides |
| Free iPhone signing is fragile (7-day expiry, the 3-app limit, the macOS build route) | Android carries the slice; the iPhone follows once the build route works |
| Scope creep from the full spec | The slice table (section 4) is the contract. New ideas go to "not yet" |
| The S10 stutters when the camera turns | The low view is occasional; warm-up and a trace (M3) |

---

## 8. Decisions recorded

| Date | Decision | Source |
|---|---|---|
| 29 Sep | The direction, native apps and the camera: settled | through Hilmi `[chat]` |
| 29 Sep | No paid Apple account: the iPhone goes by free sideloading | Hilmi `[chat]` |
| 29 Sep | No special fight camera ("unless its some simple zoom in"); the camera changes inside buildings and when talking | Hilmi `[chat]` |
| 29 Sep | The low camera only "if specifically enabled to view something"; target-follow and edge markers | Hilmi `[chat]` (answer) |
| 29 Sep | Storm people are their own ancestors; three ages | Hilmi `[chat]` (answers) |
| 29 Sep | Story villages are exempt from randomness and storms | Hilmi `[chat]` |
| 29 Sep | Manipulation is a side component, not the core (not like Crusader Kings) | Hilmi `[chat]` |
| 29 Sep | A small budget from Hilmi for a server or services if needed; keep the backend options open | Hilmi `[chat]` |
| 29 Sep | The next target is the vertical slice | Hilmi `[chat]` (answer) |
| 29 Sep | Default camera: the tilted view (-32°), from look board 1's three views | Hilmi `[chat]`: "I think best was tilted" |

---

## 9. Open questions

1. **What does Hilmi's domain run on** (a website host, Cloudflare, or a server of its own)? That decides matchmaking and log storage (M0).
2. **Enea's confirmation of the tilted default** (Hilmi picked it). The fighting pass was tuned on today's high view, so check it on the tilted view (M3).
3. **Who builds the lock-on and parry prototype?** Assumed: Enea, with the studio's networking rules.
4. **The Epic developer account (free) for testing EOS in M0:** who signs up? The studio can't create accounts.
5. **The sideloaded iPhone build:** will Enea install SideStore or AltStore on his phone when the first build exists?

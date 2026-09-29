---
title: "Unbound route r4 - a living world you play through, with friends: the vertical slice first"
created: 2026-09-29
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio
status: route; decisions of 29 Sep recorded in section 8; open questions in section 9
supersedes: docs/studio/ROUTE.md (route r3, kept unchanged as the record; its kernel, misbehaviour catalogue, singled-out rules and storm research carry over)
inputs: docs/studio/inputs/2026-09-29-owner-ideas-ai-summary.md (an AI summary Hilmi supplied, plus his own words)
next_step: M1 - the village's crimes, trials and storms, headless, built to the multiplayer-ready rules (section 3.9); multiplayer itself comes after the slice
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
4. **The biggest engineering change is live multiplayer, and it is left until after the slice.** Hilmi, 29 Sep `[chat]`: "multiplayer needs to have the capacity kept in mind but left until later". Fights and enemies will need live networking, and Enea's combat is single-player code today. So every system built before then follows the **multiplayer-ready rules** (section 3.9); retrofitting is how projects stall.
5. **The next target is a vertical slice** (Hilmi, 29 Sep `[chat]`): one land, two villages, one storm and one crime leading to a trial, played on each phone (section 4). Everything else waits until that slice is fun.

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
| A $99 Apple account as one option | No money from Enea; Hilmi funds up to about £5 a month | iPhone through free sideloading. One small server becomes possible |
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

### 3.2a Public acts: the catalogue (Hilmi's additions, 29 Sep, and the studio's inventions)

Hilmi `[chat]`: "I want to add some more things though, like bonfire burning, pillories, cannabilism, rock throwing and more - you don't need my permission for these sort of inventive things."

**How a public act is chosen** `[design]`. The kernel picks, so every phone agrees:
- **The age's law table:** crime, severity and the accused's standing give the allowed acts.
- **The crowd's mood:** anger, fear, hunger and reverence rise with shocks, rumours and omens.
- **The authority's strength:** a respected elder holds a trial; a weak one loses the crowd to a mob.
- **The levers you pull.**

The crowd's mood escalates the same act. At a pillory, the crowd starts with rotten food, moves to mud, and, if anger peaks, throws stones. So a shaming can turn lethal, as it sometimes did historically.

| Act | Ages | Triggered by | What you see | Your levers |
|---|---|---|---|---|
| **Pillory and stocks** | village, town | petty theft, cheating at market, slander | The accused locked in the square; the crowd pelts, and the escalation shows in what they pick up | Throw too; shield them; calm the crowd (food in famine lowers anger); free them at night |
| **Rock throwing (stoning)** | tribal, village | adultery rumours, blasphemy, a "cursed" outsider; or a pillory gone wrong | A ring of villagers, stones in hand, one thrown first | Throw the first stone, or step into the ring |
| **Bonfire burning (the stake)** | village (in fearful ages), tribal (sacrificial fire) | witchcraft, heresy, storm people taken for demons, cannibals | Wood carried in over hours; the stake raised; the bonfire lit at dusk, the crowd lit orange; smoke seen from the next village | Bring evidence; bribe the priest; swap in an effigy (the crowd accepts it if appeased); rescue before dusk |
| **Effigy burning** (the gentler outcome) | village, town | the crowd is appeased but needs a ritual; festivals | A straw figure in the accused's clothes burned; a feast follows | Talk the crowd down to it |
| **Hanging** | village, town | murder, arson, repeated theft, treason | The gallows built plank by plank in the square; the crowd gathers | Testify; bribe; demand trial by combat; cut the rope (outlaw) |
| **Trial by combat** | village, town | an accused with no witnesses; a noble accusation | A ring marked in the square; the accused or a champion fights the accuser | **Fight as their champion.** Enea's combat becomes justice |
| **Trial by ordeal** | village | no evidence either way | Ducking in the millpond (floating means guilty), or carrying hot iron | Rig it; plead; replace the test |
| **Branding** | village, town | theft (second offence) | A mark on the villager's face or hand, visible on their model for the rest of their life | Marked villagers are treated as thieves by everyone; hire them anyway |
| **Exile** | all | any crime when the law is lenient, or the accused is needed elsewhere | The accused walks out carrying one bundle, with the village watching | **Exiles persist.** They become outlaws or bandits in the wilds, and may come back for revenge |
| **Scapegoat drive** | tribal | a drought, or a storm omen | A goat, or an outsider, driven into the wilds "carrying" the village's sins | Follow and save them, or leave them |
| **Sacrifice** | tribal | a storm or a drought the age reads as divine anger | A procession to the stone circle at dawn | Replace the offering; stop it; let it happen and watch the omen "work" |
| **Head on a stake** (aftermath) | tribal, town | an executed raider or traitor | A warning at the gate | It raises other villages' fear of this one |
| **Tar and feathering** | town | a disliked official; a "traitor" | A mob with a bucket and a pillow sack | Join or stop the mob |
| **Charivari, "rough music"** | village, town | an unpopular marriage, a hen-pecked husband, a miser | A night crowd banging pots outside a house: shaming without violence | Join it (the village likes you more); warn them |
| **Burning the accused's house** | all | a mob with no trial | Torches at night | Put it out; save what's inside |
| **Veneration** (the opposite outcome) | all | good fortune followed a group: rain after they arrived, the storm passed them by | Offerings at their door, a shrine, pilgrims from other villages; generations later, possibly torn down again | Preach their holiness; fake a miracle; expose a fake |

**Cannibalism** (every age, from two roots, shown only through aftermath):
- **Famine.** The kernel already models hunger. In a long famine, a desperate household may eat the dead in secret. The signs are a missing body, a sealed door, a cooking pit, bones, and a rumour. **Discovery is the worst taboo in the village and tribal ages:** a trial, then burning or stoning, and the family's name is marked for generations.
- **Ritual, in the tribal age.** Some peoples in the tribal age eat a slain enemy's heart for their strength. When a storm regresses a zone, **the village's own ancestors may bring that rite back with them**. To the present-day village that is monstrous, and it is the sharpest culture clash between the ages. It drives the burning of the "demon" ancestors, or a war on the regressed zone: the "turn on the village it came from" given a reason.
- **You can be captured by a regressed tribe.** In single-player you escape or trade your way out. In co-op, your friend comes for you.

**More misbehaviour for the kernel's catalogue** (villagers do these on their own; players can too):
- **Poisoning a well,** and blaming the outsiders. This is the classic pogrom trigger, and the same verb as the traitor orders later.
- **False accusation** to take a neighbour's field. Villagers use the trial system for their own schemes.
- **Hoarding grain in famine;** grave robbing; body snatching (town).
- **Arson;** cattle rustling.
- **Night rituals of a secret cult.**
- **Omens,** read through the age's beliefs (a two-headed calf, a red moon, a storm front), which raise the crowd's fear and pick a scapegoat.

**Boundaries that stay** (from r3 section 5, set by Hilmi and Enea; not changed by the standing permission):
- no sexual violence;
- no children as victims;
- no torture detail;
- slavery is never a mechanic.

Death is staged: silhouettes at a distance, the crowd's reaction, the aftermath. It is never gore. **Age rating:** this content means PEGI 16 to 18 if the game is ever published on a store. For private sideloaded play, it's the owners' call.

**In the slice** (section 4), two chains show the ages clashing:
1. **Theft → pillory, with pelting that can escalate → hanging or exile.** It includes trial by combat as the player's lever.
2. **A storm → tribal ancestors with a sacrificial or cannibal rite → the village's fear → a bonfire burning, or veneration.**

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

**When.** After the single-player slice (M5-M6). Players are never on the same Wi-Fi (Hilmi `[chat]`), so play is online only.

**Multiplayer-ready rules, for everything built before then** `[design]`. They build on Enea's own convention: "Game state (inventory, world, characters) is separate from visuals and input, and changes go through clear action functions. This keeps co-op possible later." (`CLAUDE.md`) `[repo]`.
1. **World changes go through the kernel's action log.** They are never written directly.
2. **State is plain data with a stable ID.** Every player, enemy and nearby villager keeps its state as plain data, apart from its visuals.
3. **Input becomes intents** (move, attack, parry, use), and one simulation step applies them. A remote player's intents can later enter the same path.
4. **Gameplay randomness is keyed or seeded per event** (hits, loot, AI choices), never drawn from a global random stream. An authority can then reproduce it.
5. **Nothing gameplay-relevant depends on the local camera or screen.** Lock-on uses world geometry; see-through fades are visual only.
6. **Anything that must agree runs on the fixed simulation tick,** not the frame's delta.
7. **Private per-player state lives apart from the shared state.** That is where the traitor orders will go later.

Every milestone checks the rules with a **replay test**: the action log, replayed headless, must reproduce the world hash of the live run.

**Backend options.** There is no choice yet: a spike (M5) measures them `[web]`.

| Option | Cost | Strengths | Weaknesses |
|---|---|---|---|
| Epic Online Services via the EOSG plugin | £0 | Free relays for phones on mobile networks; lobbies; cloud storage; iOS arm64 and Android arm64 builds | Unofficial plugin; needs a free Epic developer account (a person signs up); one phone hosts |
| A small server (e.g. Hetzner CX23, about €6/month) running a headless Godot server or Nakama | about £5/month | The server referees: fair fights, no phone has to host, it stores the logs | Someone maintains it; slightly over £5 |
| **Cloudflare, on Hilmi's account** (dltreasures already runs there): a Durable Object "room" per match relays over WebSockets; storage for each land's world log; the JavaScript kernel reference can run there to hold the canonical world between sessions | Free plan: 100,000 requests a day (1 per 20 WebSocket messages received), about one room awake all day. Or Workers Paid, $5 a month | Already Hilmi's platform; the kernel's JavaScript version runs there; a few friends for a few hours fit the free plan (our estimate) | WebSockets run over TCP, so lag suffers on lossy mobile links, unlike UDP relays; one phone still simulates enemies unless the logic moves into the room |
| WebRTC phone-to-phone, plus Cloudflare's free STUN and TURN (1,000 GB/month free), with matchmaking on Hilmi's Cloudflare | about £0 | Cheap; UDP | More plumbing; one phone hosts |

Hilmi's domain runs on Cloudflare `[chat]`, so matchmaking, rooms and log storage can live there.

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
| Villagers | 20-30 near you with needs and values. **Two chains** (section 3.2a): theft → pillory (the pelting can escalate) → hanging or exile, with trial by combat; and storm → tribal ancestors' rite → fear → bonfire burning or veneration | The rest of the catalogue, factions |
| Manipulation | Plant evidence, testify, bribe | Rumour chains, freeing prisoners |
| Storm | One forecast storm. Part of the ordinary village regresses to the **tribal** age: ancestors, language distance 2 (barter or spears), border conflict, one of the four endings | Multiple storms, the town age |
| Combat | Enea's combat plus a lock-on and parry prototype; edge markers | Radial wheel, spells, target cycling |
| Camera | The tilted default, Look (eye level), Inside, Talk, Build (high) | - |
| Together | **Not in the slice.** Every system follows the multiplayer-ready rules, and a replay test proves the log reproduces the world | Live play (M5-M6), 3-4 players, traitor orders, disguise |
| Platforms | Native Android. iPhone sideloaded, if the macOS build route works | - |

**Done when:**
1. You and Enea each play 20 minutes on your own phone, and each tells a story the village made (a trial or a storm) that neither of you scripted.
2. It holds 30 fps on the S10.
3. The replay test passes: the session's action log, replayed headless, reproduces the world hash. That shows the world would sync between phones.

---

## 5. Order of work (milestones, gated)

| # | Milestone | Done when | Needs |
|---|---|---|---|
| **M1** | **The village, headless** (A0 reshaped): crimes → trials → the public acts of section 3.2a (the slice's two chains first); storms → regression → ancestors; language distance; staged-event output; anchored villages | Thousands of simulated years pass the invariants: every notable act has a reason and a staged cue; no collapse loops; no single behaviour dominates; conformance against a JavaScript reference | Nothing |
| **M2** | **The village on screen**: embodied villagers and stagings (gathering, trial, gallows) in Enea's game; the ordinary village built from building families, today's plus tribal | A trial plays out on the S10 at 30 fps, and you can read it without text; the replay test passes | M1; tribal building and clothing sets (Blender scripts, Enea's pipeline) |
| **M3** | **Camera**: the tilted default, Look, Inside, Talk, Build; edge markers; target-follow in Look; the shader warm-up extended; a Perfetto trace of the turning stutter | Smooth switching between modes; no stutter above 50 ms on the S10 after the warm-up | Enea confirms the tilted default |
| **M4** | **Slice playtest** (owner play, each on your own phone) | The "done when" of section 4 | M1-M3 |
| **M5** | **Multiplayer spike**: two phones, one boar, online. The S24 on 4G against the S10, on **two** backends (Cloudflare rooms and one other) | Latency and reliability measured; a backend chosen with evidence | Y3 (the S24); an Epic developer account only if EOS is one of the two |
| **M6** | **Live together**: the chosen backend; host authority for enemies and hits; the world log in sync | 20 minutes on two phones with no divergence | M4, M5 |

**In parallel, Enea's layer:**
- the lock-on and parry prototype, built to the multiplayer-ready rules (section 3.9);
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
| Multiplayer comes later (Hilmi's call), and retrofitting breaks single-player systems | The multiplayer-ready rules from day one, and a replay test in every milestone |
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
| 29 Sep | The direction, native apps and the camera are accepted: "I think enea is forced to accept these things at this point" | Hilmi `[chat]` |
| 29 Sep | No money from Enea (no $99 Apple account): the iPhone goes by free sideloading | Hilmi `[chat]` |
| 29 Sep | No special fight camera ("unless its some simple zoom in"); the camera changes inside buildings and when talking | Hilmi `[chat]` |
| 29 Sep | The low camera only "if specifically enabled to view something"; target-follow and edge markers | Hilmi `[chat]` (answer) |
| 29 Sep | Storm people are their own ancestors; three ages | Hilmi `[chat]` (answers) |
| 29 Sep | Story villages are exempt from randomness and storms | Hilmi `[chat]` |
| 29 Sep | Manipulation is a side component, not the core (not like Crusader Kings) | Hilmi `[chat]` |
| 29 Sep | Hilmi funds up to about £5 a month; keep the backend options open | Hilmi `[chat]` |
| 29 Sep | The next target is the vertical slice | Hilmi `[chat]` (answer) |
| 29 Sep | Default camera: the tilted view (-32°), from look board 1's three views | Hilmi `[chat]`: "I think best was tilted" |
| 29 Sep | Multiplayer left until after the slice, with the capacity kept in mind; players are never on the same Wi-Fi | Hilmi `[chat]`: "we would never be under the same wifi though and multiplayer needs to have the capacity kept in mind but left until later" |
| 29 Sep | Hilmi's domain runs on Cloudflare: a candidate home for rooms, matchmaking and world logs | Hilmi `[chat]` |
| 29 Sep | Enea may read Hilmi's own words in the branch documents | Hilmi `[chat]`: "let him see them" |
| 29 Sep | Bonfire burning, pillories, cannibalism and rock throwing added; **standing permission for inventive content of this kind** (the boundaries in section 3.2a stay) | Hilmi `[chat]`: "you don't need my permission for these sort of inventive things" |

---

## 9. Open questions

1. ~~What does dltreasures run on?~~ **Answered:** Cloudflare (section 3.9).
2. **Enea's confirmation of the tilted default** (Hilmi picked it). The fighting pass was tuned on today's high view, so check it on the tilted view (M3).
3. **Who builds the lock-on and parry prototype?** Assumed: Enea, with the studio's networking rules.
4. **Deferred to M5:** an Epic developer account (free), only if EOS is one of the two backends tested. The studio can't create accounts.
5. **The sideloaded iPhone build:** will Enea install SideStore or AltStore on his phone when the first build exists?

---
title: "Unbound - civilisations you live inside (route r3)"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), Claude Code on Hilmi's PC, lead agent, session 2
status: awaiting-hilmi-review
supersedes: docs/studio/ROUTE-r2.md (kept unchanged as the record; its kernel, research and advice on Enea's build carry over, and section 12 lists what changed)
next_step: Hilmi reviews and challenges back; decisions D1-D7 (section 13) go to Enea through Hilmi; Stage A0 (a headless deep village) can start on Hilmi's go
evidence_base: Hilmi's clarification of 28 Sep (quoted in section 1); spikes S1 and S1b in tools-src/studio/kernel-prototype (run 28 Sep); web sources in section 14; en-ea/Unbound at e08cbca
---

# Unbound - civilisations you live inside

**Labels:** `[repo]` measured in this repo or its git history · `[run]` produced by running something here · `[web]` cited source (section 14) · `[chat]` Hilmi's or Enea's words · `[design]` my proposal.

---

## 0. Verdict

1. **The game, as clarified, is a new combination.** Civilisations grow through the ages, misbehave in ways you understand, and deal with each other. Time storms fold villages, or parts of villages, into other ages, where they can turn on the village they came from. Throughout, you are one person inside that world, with your own life.
   - **The parts all have precedents** `[web]`:
     - Deisim and WorldBox for civilisations across eras;
     - Norland, Crusader Kings 3 and Dwarf Fortress for social depth and misbehaviour;
     - Mount & Blade, Bellwright and Medieval Dynasty for a person living inside a living world.
   - **Nobody combines them, and nobody does it on phones with cross-play.** The genre's weak spot shows in Deisim's reviews: players call it repetitive and thin in its later stages, and one reviewer unlocked everything in about two hours `[web]`. Depth is where this game wins or loses.
2. **You are right that the composition must change.** It needs:
   - a camera that zooms continuously from your character to the whole land;
   - native builds on both phones instead of the web;
   - crowds rendered on the GPU;
   - the world simulation on its own thread;
   - a look that reads at a distance, not just close up.

   Section 8 gives the specifics. The hands-on layer (combat, gathering, crafting, the character creator) stays.
3. **Where I push back** (section 3):
   - **"Lots of logic" is half the answer.** Players judge intelligence by what they can read. "If the AI didn't say it, it didn't happen" (F.E.A.R.'s AI lead) `[web]`. The legibility layer deserves as much work as the brains.
   - **Unbounded misbehaviour breaks worlds.** Oblivion's NPCs killed a dealer before the player could reach him, and Bethesda toned them down `[web]`. It needs a storyteller that paces it, plus agreed content limits.
   - **Storms must add, not erase.** Civilization VII's forced era switches were its most hated feature, and 2K's CEO said "we got it wrong" `[web]`.
   - **Scope is the real enemy.** Building every layer thin is how Deisim ended up shallow. Depth in one village comes first, then breadth.
   - **Graphics fidelity is the wrong axis on phones at this scale.** Readability, crowds and running cool matter more. Your S24 Ultra throttles to roughly half its peak graphics performance under sustained load `[web]`.
4. **The world kernel from r2 carries the new ideas.** Tested on your storm idea without any scripted conflict `[run]` (S1b):
   - folding part of a village into its own past led the two halves to fight in 25-70% of storms within 25 years;
   - who strikes first depends on the enclave's size;
   - the past also teaches lost knowledge in 10-25% of cases.

   The limit: in the toy, the fighting comes from shared land, not from the ages being different people. That is the social layer's job (section 4).
5. **Your S24 Ultra makes this a cross-play game**, and that forces four things (section 9):
   - native Android plus native iOS;
   - a cross-platform sync server (Nakama), not Apple services;
   - a per-phone AI model: Apple's on the iPhone, a bundled open model on yours;
   - integer maths in the world simulation, so both phones compute the identical world.
6. **Seven decisions** are for you and Enea (section 13). The first is whether this reframing is the game.

---

## 1. The game, in your words

Hilmi, 28 Sep `[chat]`: "I was thinking of those sorts of game deisim on the meta quest or the many relevant games that are found on pc too, where civilisations can grow over time, illicit behvaiours you may expect but not expect in a game and interact with other civilisations, with time storms also shaking things up by converting either certain villages or even parts of villages into a different time and potentially even make it turn on the village it was once part of, all of this while the player also has its own things to do and own ways to interact with people."

And: "I also suspect the current composition of the game must change, both camera angles, rendering type, graphics and a whole lot else."

**Five proposed pillars** `[design]`. They are for Enea to accept or rewrite, because the product is his.

| # | Pillar | What it rules in |
|---|---|---|
| P1 | **The world lives without you and remembers you** | Civilisations grow, trade, scheme and fall whether you are there or not; your deeds enter their memory and their rumours |
| P2 | **People, not units** | Every villager has needs, a temperament, values, relationships and secrets. They misbehave for reasons you can read |
| P3 | **Time is weather** | Storms fold places into other ages. Past and present meet, trade, clash and sometimes merge |
| P4 | **You are someone** | You start as one person with your own life. Your influence grows from yourself, to a household, a village, a people, and finally across time |
| P5 | **Two friends, two lands, one history** | You (S24 Ultra) and Enea (iPhone 16 Pro Max) share a world across phones, offline-first |

These sit on top of Enea's existing pillars `[repo]`: endless, not story-driven; gather → craft → stronger; a loot chase; a world that feels alive. They fit, with one open conflict: resets (r2 section 4.7, still open as D3).

---

## 2. The reference class: what to take, what to beat

| Game | Platform | What it does best `[web]` | Its weakness | Take |
|---|---|---|---|---|
| **Deisim** | Quest, PC | Tile-by-tile god game; autonomous humans from the Stone Age to modern eras; heretics convert towns and start wars; miracles cost mana from believers | Players call it repetitive and thin late on; one reviewer unlocked everything in about two hours | Eras as progression; heresy as a system; miracles paid for by faith |
| **WorldBox** | Phones, PC | "A petri dish for your fantasy civilizations"; one bottom power bar on touch | You watch rather than live | Proof of the itch on phones; its touch interface |
| **Norland** | PC | A story generator: crime, riots, affairs, religious fights, murders "out of anger"; you run spies and assassinate | Isometric and UI-heavy; balance at scale is the open question | The social palette, and misbehaviour with consequences |
| **Crusader Kings 3** | PC | Schemes with phases, secrecy and agents; secrets and hooks (blackmail) | Menu-driven | Schemes as plans that can be discovered |
| **Dwarf Fortress** | PC | Personality facets, values and needs; civilisations have values; villains, corruption, spy networks tracked through evidence | Legibility, mostly text | Values per people and per age (the key to storm culture clash) |
| **RimWorld** | PC, consoles | Storytellers pace events on a tension curve; moods and thoughts on screen | - | A storyteller for misbehaviour and crises |
| **Talk of the Town** (research) | - | Characters observe, tell, misremember and lie; knowledge spreads and decays | A prototype | Rumours about you, and about the storm people |
| **Versu** (research) | iOS (cancelled) | "Social practices": greetings, meals, courtship as shared plans that offer agents choices | Small casts | Structure for interactions that don't look robotic |
| **Mount & Blade, Bellwright, Medieval Dynasty** | PC, consoles | A person in a living world: clans that defect; a village you run from the ground; a family line across generations | Grindy; the villages feel mechanical | The person-inside-the-world loop |
| **Manor Lords** | PC | City builder with an on-foot mode | That mode is look-only: you can't interact with anything or fight in it | A warning: the avatar must matter at every zoom |
| **Civilization VII** | PC, consoles | Ages with crises | Forced civ switching drew the backlash; made optional in May 2026 | Eras must layer, not replace |

**The gap Unbound can own** `[design]`: deep social simulation, plus a person you play, plus time as a force. On phones. Two friends, cross-play, offline-first.

---

## 3. Where I push back

**3.1 "A lot of logic so it isn't robotic" - half right.**
- Halo's designers set "intelligible" as the first design goal: enemies broadcast their intent through barks and animations.
- F.E.A.R.'s AI lead: "If the AI didn't say it, it didn't happen... There is no point in expending significant effort implementing complex AI if the player doesn't notice it." Players remembered the squad dialogue, not the planner behind it `[web]`.
- A 2025 study found players rate NPCs lower on intelligence and believability when their behaviour contradicts expectations `[web]`.
- **Therefore:** consistent motives, plus a legibility layer, plus modest decision logic beats deep hidden logic. Section 4 budgets the work that way.

**3.2 Misbehaviour needs a governor.**
- Oblivion's Radiant AI let NPCs choose how to eat. In testing, skooma addicts killed the dealer the player was sent to find, and designers had to "consciously tone down" behaviours. The shipped game gates crime behind a 0-100 "Responsibility" score `[web]`.
- RimWorld paces its drama with storytellers on cycles and cooldowns `[web]`.
- **Therefore:** misbehaviour is emergent, but a storyteller times it, and D2 sets content limits (section 5).

**3.3 Storms must add, not erase.**
- Civ VII made players swap civilisation at each age. Firaxis later admitted that its "history is built in layers" idea hadn't landed: transitions felt like replacements, with too much lost. 2K's CEO: "we got it wrong... a bridge too far". Switching became optional on 19 May 2026 `[web]`.
- **Therefore:** a storm puts an enclave beside the present. It does not delete what players built. Player-made things are anchored.

**3.4 Scope.**
- This combines a god game, an action RPG, a social simulation, time mechanics and cross-play multiplayer, on phones, built mostly by agents.
- The failure mode is every layer shipped thin, which is Deisim's review problem.
- **Therefore:** depth before breadth. One village of about 30 people who feel alive, and you inside it, comes before three civilisations (section 11).

**3.5 Graphics.**
- **Sustained performance is what counts on phones.** The S24 Ultra leads the iPhone 16 Pro Max at peak graphics (about 122 vs 108 fps in 3DMark Wild Life Unlimited). Under sustained load it keeps about 47-57% of that peak, against about 65-90% for the iPhone. Once both are heat-limited, they perform about the same `[web]`.
- **A civilisation game renders crowds and distance.** So "better graphics" here means readable silhouettes, era palettes, light, fog and hundreds of cheap animated people, not detail per model. Enea's own rules already lock 30 fps for heat `[repo]`.

**3.6 The avatar must matter at every zoom.**
- Manor Lords' walk mode is look-only and "experimental" `[web]`. Hybrids split into two half-games when the person and the god view don't connect.
- **Therefore:** the zoom levels are earned through your influence (section 7). Even from the land view, you remain someone the world can talk about, rob or crown.

**3.7 A patent to design around.**
- Warner Bros' "Nemesis" patent (US 10,926,179) runs to August 2036. It covers a combined system: NPC hierarchies, forts, **"social vendettas"** where one player's nemesis is sent into another player's game, and followers `[web]`.
- Grudges and memory in general are not covered. But r2's "strangers arrive as echoes" idea must not become one player's nemesis sent into a friend's game with hierarchy promotion. A patent attorney should check the final design.

---

## 4. Making it not robotic: the behaviour stack

```
 L5  VOICE        barks, gossip, conversation          templates for the crowd; on-device LLM for ~10-20 named people
 L4  LEGIBILITY   visible intent (icons, animation),    "tap anyone: what they want, why, what they remember of you";
                  thoughts, the chronicle, rumours       rumours about you reach you; the chronicle on open
 L3  DRAMA        a storyteller with a tension budget   decides WHEN a crime, feud or crisis may fire; escalates
                                                         with wealth; cools after tragedy
 L2  SOCIAL       practices (greet, trade, court,       each practice offers choices; agents pick by utility;
                  feast, trial, funeral)                 knowledge spreads and can be wrong; schemes have phases,
                  knowledge and rumour · schemes         secrecy and agents; evidence can expose them
 L1  MIND         needs · temperament facets · values   values held by each person AND by each people and age:
                  (person, people, age) · memories ·     the fuel for storm culture clash
                  relationships · secrets
 L0  WORLD        the kernel (S1): land, food,          deterministic, keyed randomness, fixed-point, logged actions
                  knowledge, settlements, storms
```

**How each layer is built, and why** `[design]`:
- **L0-L3 live inside the deterministic kernel.** Both phones compute the same schemes, rumours and crimes. Anything L4 or L5 changes in the world, such as a promise made in a conversation, enters the action log.
- **L1 values per age are what S1b lacked.** Dwarf Fortress gives each civilisation values that individuals may deviate from `[web]`. Give each age its values too (tradition, faith, fairness, craft). A district folded to year 150 then holds year-150 values, and it clashes over graves, gods, inheritance and the mill, not just food.
- **L2 practices come from Versu**: shared plans that never control an agent directly. They only offer choices, and each agent picks by utility `[web]`.
- **L2 schemes come from CK3**: phases, secrecy, agents, discovery. CK3's designers found schemes without agents worked better for simple cases `[web]`.
- **L2 knowledge comes from Talk of the Town**: characters "observe, tell, misremember and lie"; repeated lies become believed `[web]`.
- **L3 is RimWorld's storyteller idea**: cycles, cooldowns, threat scaling with wealth `[web]`.
- **L4 is Halo's and F.E.A.R.'s rule.** Every non-routine act emits something readable. Headless, the toolbox can check a **legibility invariant**: the share of notable acts that produced a bark, a rumour or a chronicle line.
- **L5 LLMs add voice and variety, not decisions for the crowd.**
  - Project Sid's LLM agents were found "frustratingly independent" by the public `[web]`.
  - Named people can have an LLM "rewrite their policy" (r2 section 4.8). The result is logged.

**Scale by level of detail.** STALKER's A-Life splits the world into online (near the player) and offline (simulated on a graph) `[web]`.
- STALKER 2 launched without working offline A-Life, and players called its NPCs "random encounters in a bubble... no past and no future". GSC had to patch in offline persistence `[web]`.
- **The lesson: what players notice is identity that persists outside the bubble.** So every person keeps their identity at all levels. Near you, they are full agents. Elsewhere, they are folded into households and settlements, and unfolded again unchanged.

---

## 5. Misbehaviour: the catalogue and its limits (decision D2)

| Kind | Examples | Precedent `[web]` | Grows from | Your handles |
|---|---|---|---|---|
| Property | theft, smuggling, black markets, grave-robbing ruins, counterfeiting | Oblivion (theft for food); Dwarf Fortress (artifact theft) | Need plus low scruples plus opportunity | Catch, fence, tip off, run your own smuggling |
| Power | bribery, embezzlement, rigged appointments, coups, framing a rival | Dwarf Fortress villains and corruption; CK3 | Ambition plus greed plus a weak office | Expose with evidence, blackmail (hooks), back a coup |
| Intimacy | affairs, secret courtship, a hidden heir | Norland; CK3 seduction | Relationships plus a spouse's opinion | Keep a secret or trade it. Enea's light romance fits here |
| Violence | feuds, raids, duels, murder (off-screen, reported) | Norland ("kill one another out of anger"); CK3 murder schemes | Grudges, hunger, rivalry, the storyteller's permission | Mediate, avenge, hire out, defend |
| Faith | heresy, cults, relic theft, conversion wars | Deisim heretics; Project Sid's religion spread | Values drift plus a charismatic figure | Convert, protect, exploit |
| Loyalty | spies, desertion, betrayal | Dwarf Fortress spy networks; **Enea's Hidden Fourth** `[repo]` | A secret organisation recruiting through corruption | Investigate through evidence and interrogation (DF's model) |
| Time | storm people claiming their descendants' houses and graves; smuggling objects or knowledge across ages; "the future says you'll lose, so strike first" | New to Unbound | Values per age plus shared land | Mediate claims, trade across ages, keep secrets of the future |

**Enea's lore becomes a system.** His Hidden Fourth "hide among the people of both lands and look like everyone else" `[repo]`. That is a Dwarf Fortress-style secret organisation, uncovered clue by clue. His own "Traitors among us" idea in the Three Lands picker asks for exactly that `[repo]`.

**Limits (D2)** `[design]`. Proposed tone: Norland or CK3 as seen from a village. Consequences are real, and the worst acts happen off-screen and reach you as news. Excluded:
- sexual violence;
- harm to children;
- torture detail;
- slavery as a mechanic.

The app-store age ratings on both stores follow whatever tier the two of you choose.

---

## 6. Time storms, made concrete

**What a storm can fold** (smallest first):

| Scale | What happens |
|---|---|
| A person | A stranger from another age walks out of a storm |
| A building or household | A house becomes its own past (the mill before the fire) |
| **A district** | Part of a village becomes its own past or future, with its real people from the history log |
| A whole village | The whole village is folded into another age |

**What happens next** `[run]` `[design]`:
- **The folded people are real.** They are rebuilt from the history log: their names, their knowledge, their grudges, and (once L1 exists) their age's values.
- **Both halves claim the same things:** the name, the fields, the graves, the relics.
- **Conflict emerges in the toy already** `[run]`, with no script. The table below is the S1b result: 20 seeds per row, 25 years after the storm.

| Years back | Share folded | Past raids present | Present raids past | Any fighting | Past teaches others | Origin smaller than without the storm |
|---|---|---|---|---|---|---|
| 40 | 30% | 0% | 70% | 70% | 15% | 21% |
| 40 | 60% | 15% | 15% | 30% | 25% | 30% |
| 150 | 30% | 0% | 70% | 70% | 20% | 20% |
| 150 | 60% | 25% | 15% | 40% | 20% | 30% |
| 300 | 30% | 0% | 60% | 60% | 10% | 19% |
| 300 | 60% | 15% | 10% | 25% | 20% | 28% |

The chronicle from one of those runs: "a time storm folds 333 of Holtorfen's people into year 350; 305 people of that age stand in their place and call themselves Old Holtorfen ... yr 524 Old Holtorfen raids Holtorfen for grain; 18 fall."

**Rules taken from precedents** `[web]` `[design]`:
- **Forecast storms.** Hinge search (r2) aims them at the sensitive moments, and the forecast is a reason to open the app.
- **Add, don't erase** (Civ VII). The enclave stands beside the present, and player-built things are anchored.
- **Changes settle** (Achron's timewaves). Achron carries changes forward in waves, and once an event falls off the changeable window it "locks". Here, a storm's consequences become fixed history after N days, which ends paradox loops.
- **Time actions cost more the further back they reach** (Achron's chronoenergy). This keeps players from rewriting the distant past cheaply.
- **Four ways it ends, all emergent:**
  - coexistence and trade (the past sells lost knowledge);
  - a schism into a new faction (your "turn on the village it was once part of");
  - merging through marriage and time;
  - the storm returning to take them back.

**Your handles:** warn, mediate, take a side, lead the enclave, smuggle across ages, buy the lost technique, or send them home.

---

## 7. Your life inside it: influence decides your view

```
 influence rung      you are...                      camera you unlock        powers
 ───────────────     ─────────────────────────────   ──────────────────────   ─────────────────────────────────────
 0  person           one villager (Enea's start)     your character (today)   gather · craft · fight · trade · talk ·
                                                                              court · steal · inform
 1  household        a family and a home             street                   hire, house settlers (Enea's home base)
 2  village          elder, guild head or crime boss village diorama          village projects, laws, work priorities
 3  people           a voice for your land           land map                 diplomacy, trade routes, war, faith
 4  storm-walker     marked by the shrines            the ages (timeline)     enter storms, move things across ages,
                                                                              shrine miracles paid for with faith
```

- **The god view is earned, not given.** Each rung is a camera and a set of verbs. This is Mount & Blade's clan tiers joined to Deisim's faith-paid miracles.
- **Enea's material has a home in this ladder** `[repo]`: his "ordinary villager... becomes the mainland's strongest over time", his shrine powers, his home base and his companions.
- **You stay a person at every rung.** The world can rob you, gossip about you, betray you or crown you. That is the guard against the Manor Lords problem.
- **Short and long sessions both work.** Enea's design already asks for "short tasks for 2-minute stops, and long goals for long sessions" `[repo]`. On the train: read the chronicle, answer one rumour, run one errand. At home: a storm expedition or a feud settled by the sword.

---

## 8. What must change: camera, controls, rendering, look

**Camera: one continuous zoom, five steps** `[design]`.
- Rise of Kingdoms' "infinite zoom" moves city → region → world with two fingers. It took the team 90 days and "200 sketches for five separate layers" of interface, so each layer shows only its functions `[web]`.
- Pinch runs continuously through rungs 0-3. Step 4 (the ages) is a panel.
- At rung 0, the joystick and action buttons stay as they are today `[repo]`. From rung 1 up it is touch-first: tap to inspect, drag to direct, and one bottom power bar, as WorldBox does `[web]`.
- Whether rung 0 keeps Enea's Tunic-style fixed angle is his call. The ladder works either way.

**Rendering** `[web]` `[design]`:

| | Today `[repo]` | Needed |
|---|---|---|
| Build | Web, Compatibility renderer (WebGL 2), one thread | **Native Android and iOS**, Mobile renderer (Vulkan on your S24, Metal on the iPhone) |
| Crowds | About 20 animated characters at most | **Vertex-animation textures plus MultiMesh** for everyone beyond ~20 m. Godot plugins exist for every renderer. Chunk them for culling. Watch the open 4.7.1 MultiMesh bug #123257 |
| Simulation | Main thread | **Its own thread** (native only). The web export is single-threaded on iPhones |
| Distance | Fog, a small region | Level of detail and impostors for buildings; one mesh per settlement at the land zoom |
| Budget | 30 fps default, measured on the iPhone | 30 fps, **tested after 20 minutes on both phones** (throttled numbers, not peak) |

**Look** (a proposal for look boards; the look is Enea's):
- **Close up:** stays Tunic, Omno and Journey: light, fog, glow `[repo]` `[chat]`.
- **From the village zoom up:** readable at a glance. Each people and age has its own building silhouette (Enea's building families map straight onto this `[repo]`), accent colours for factions, and a diorama feel. References `[web]`: Townscaper and Tiny Glade for buildings; Bad North, a minimalist low-poly strategy game that shipped on phones, for small readable units.
- **Storms:** an era palette per age and a visible storm wall. Folded districts use the growth-stage and ruin variants from Enea's sheets.
- **Crowds:** vertex-animated versions of Enea's outfits `[repo]`, with faces only at close zoom.

**What stays** `[repo]`:
- combat feel;
- gathering and crafting;
- the character creator;
- the Bag and trader screens;
- the balance file;
- the performance rules.

---

## 9. Cross-play: your S24 Ultra with Enea's iPhone 16 Pro Max

| Need | Choice | Why `[web]` |
|---|---|---|
| Your builds | **Android APK installed over USB (ADB)**, or a free hobbyist developer account (up to 20 devices, no ID) | Google's verification starts on 30 Sep 2026 in four countries, not the UK (UK in 2027). ADB installs are exempt |
| Enea's builds | TestFlight ($99 a year) with a macOS build (a Mac, or GitHub's macOS runner) | Unchanged from r2 |
| Sync and co-op | **Nakama** (Apache-2.0, official Godot 4 client, realtime and storage), self-hosted on a small VPS | Cross-platform. CloudKit and Game Center are Apple-only |
| AI on the iPhone | Apple Foundation Models (on-device, free; Game Mode caveat, see r2) | - |
| AI on your S24 | **A bundled small open model through llama.cpp**: Qwen3 0.6B/1.7B or Gemma 4 (both Apache-2.0). Estimated ~20-40 tokens a second for a 1B model on your chip | Google's on-device Gemini Nano API is not confirmed for the S24 series. The NobodyWho Godot plugin supports Android (not Godot on iOS) |
| Same world on both | **Integer or fixed-point maths in the kernel**, plus a hash check on both phones in continuous integration | Compilers on these ARM chips fuse multiply-add, and maths libraries differ, so floats drift across devices. Box2D reached cross-platform determinism only by turning that fusion off and writing its own trigonometry |
| Different AI, one world | AI outputs are logged actions (r2) | Your phone's model and Enea's can phrase things differently, but the world stays identical |

**Quest, since you named it.** Godot's Meta Quest support is strong in 2026. Meta funds it, and the Mobile renderer is now recommended for standalone headsets `[web]`. A Deisim-style VR land view could be a later platform on the same code. **Not now.**

---

## 10. The architecture, updated

```
                        ┌──────────────────────── KERNEL (deterministic, fixed-point, own thread) ────────────────────────┐
  seed + canon ────────►│ L0 world: lands, peoples, settlements, knowledge, storms                                     │
  clock ───────────────►│ L1 minds: people folded into households far away, full agents near you (same identity)       │
  action log ──────────►│ L2 social: practices, rumours (can be wrong), schemes      L3 storyteller: when drama may fire  │
   (you, Enea, AI       └───────────────┬───────────────────────────────┬─────────────────────────────────────────────────┘
    outputs, storms)                    │ state queries                 │ events
                                        ▼                               ▼
                        PRESENTATION (per phone, may differ)     CHRONICLE + RUMOURS
                        camera ladder · crowds (GPU) · barks ·   what reaches you, and when
                        voice (Apple model / llama.cpp)
                        HANDS: Enea's current game ── actions ──► back into the log
                                        ▲
  Nakama (logs, realtime co-op) ◄───────┴──────► the other phone (S24 ⇄ iPhone)
```

---

## 11. Sequencing: depth first

| Stage | What | Done when | Checked by |
|---|---|---|---|
| **A0** headless deep village | About 30 people with L1-L3: values, 3 practices, rumours, 3 kinds of misbehaviour, a storyteller. Fixed-point kernel | Thousands of simulated years pass the invariants: no collapse loops, **every notable act has a logged reason**, legibility coverage above a threshold, and no single behaviour dominates | Headless toolbox runs, in seconds |
| **A1** you in it, on both phones | Native builds; Enea's hands layer; tap-to-inspect "what they want and why"; rumours about you; the chronicle on open | You and Enea each tell a story the village made that the other didn't know | Owner play on both phones |
| **B** storms | District folds with values per age; the forecast; four endings; anchoring | A storm is the event you both open the app for | Headless metrics, look board, play |
| **C** civilisations | Enea's three lands and peoples; trade, diplomacy, war, faith; the camera ladder to rung 3; crowds on the GPU | The land view is worth watching and acting on, after a 20-minute thermal test on both phones | Headless, look boards, play |
| **D** two lands meet | Cross-play co-op on Nakama; named minds on each phone's model | Enea's land and yours meet and affect each other | Play |
| **E** later | Ages, heresy wars, Quest | - | - |

**Cut rule:** a feature that can't be made deep in its stage waits. It doesn't ship thin.

---

## 12. What changed since r2

| | r2 | r3 |
|---|---|---|
| Frame | An action game over a living history | **Civilisations you live inside**; the action game is the rung-0 layer |
| AI focus | Named villagers with minds | **The legibility plus social stack (L1-L4)** for everyone; LLM voice for the named few |
| Storms | A region shows its past; edits to the past | **Districts fold into other ages and can turn on their village** (S1b); enclaves beside, not replacing |
| Platform | Web now, native later | **Native on both phones now**: crowds, threads, AI and cross-play need it |
| Sync | Nakama or CloudKit | **Nakama only** (cross-play) |
| AI models | Apple on-device | **Apple on the iPhone, a bundled Apache-2.0 model on Android** |
| Kernel maths | Unspecified | **Fixed-point** (cross-device determinism) |
| Strangers | Echoes through storms | Kept, but redesigned so it is not the patented "social vendetta" |
| Carried over unchanged | The kernel, keyed randomness, logs, hinge search, advice on Enea's build (extend `Money.stock()` and `WorldResources`), the building grammar, look boards, the verification ladder | |

---

## 13. Decisions

| # | Who | Decision |
|---|---|---|
| D1 | Enea (with you) | Is the game "civilisations you live inside" (this route), or r2's action game over a living history? |
| D2 | Both | Misbehaviour limits and age-rating tier (section 5) |
| D3 | Both | Resets: storms fold and settle locally by default, plus an optional new Age, or none (open since r2) |
| D4 | Enea | Native on both phones now and retire the web build for the main game; Apple $99 a year |
| D5 | Enea | The camera ladder (section 7), and whether rung 0 keeps the Tunic fixed angle |
| D6 | Both | Which references matter most. Name 2-3 and I'll set the bar against them |
| D7 | You | How and when this goes to Enea |

---

## 14. Sources `[web]`

**Reference games**
- Deisim: https://www.meta.com/experiences/deisim/3526702020710931/ · https://www.androidcentral.com/gaming/virtual-reality/deisim-for-oculus-quest-filled-the-void-in-my-heart-that-black-and-white-left · https://theeliteinstitute.net/2025/06/11/deisim-meta-quest-3/ · https://deisim.fandom.com/wiki/Heretic
- Norland: https://store.steampowered.com/app/1857090/Norland/ · https://gameswatch.net/norland-review/ · https://www.pcgamer.com/games/strategy/library-heists-bandit-bribes-and-multiple-orgasms-how-i-became-a-happy-king-in-medieval-strategy-sim-norland/
- Crusader Kings 3 schemes: https://forum.paradoxplaza.com/forum/developer-diary/dev-diary-157-schemes-stories.1703863/ · https://www.pcgamer.com/crusader-kings-3-ck3-intrigue-hooks/
- Dwarf Fortress personality and villains: https://dwarffortresswiki.org/index.php/Personality_value · https://dwarffortresswiki.org/index.php/Villain · https://dwarffortresswiki.org/index.php/Intrigue
- RimWorld storytellers: https://rimworldwiki.com/wiki/AI_Storytellers · https://rimworldgame.com/
- Hybrids: https://primagames.com/gaming/how-to-walk-around-in-third-person-mode-in-manor-lords · https://store.steampowered.com/app/1812450/Bellwright/ · https://medieval-dynasty.fandom.com/wiki/Medieval_Dynasty
- Civilization VII ages: https://www.gamespot.com/articles/civilization-7-is-a-completely-different-game-following-the-test-of-time-update/1100-6540040/ · https://kotaku.com/ceo-admits-civilization-7-was-a-bridge-too-far-as-it-ditches-its-most-controversial-mechanic-in-new-fundamentally-game-changing-update-over-one-year-later-2000693964
- Achron: https://en.wikipedia.org/wiki/Achron
- Rise of Kingdoms zoom: http://forum.lilithgame.com/viewtopic.php?t=20680
- WorldBox: https://www.superworldbox.com/changelog · https://apps.apple.com/us/app/worldbox-god-sandbox/id1450941371

**Believable behaviour**
- Halo: https://gdcvault.com/play/1022590/Creating-the-Illusion-of-Intelligence · https://www.jmeiners.com/shamans/papers/ai/the_illusion_of_intelligence.pdf
- F.E.A.R.: https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter02_Combat_Dialogue_in_FEAR_The_Illusion_of_Communication.pdf
- NPC coherence study: https://arxiv.org/abs/2512.07388
- Versu: https://versu.com/about/how-versu-works/ · https://www.ifwiki.org/Versu
- Talk of the Town: https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter37_Simulating_Character_Knowledge_Phenomena_in_Talk_of_the_Town.pdf
- Oblivion's Radiant AI: https://www.escapistmagazine.com/oblivion-npcs-brought-their-world-to-life-then-they-nearly-killed-it/ · https://blog.paavo.me/radiant-ai/
- STALKER A-Life: https://www.gamedeveloper.com/design/a-life-an-insight-into-ambitious-ai · https://support.stalker2.com/hc/en-us/articles/32829700589073-Major-Patch-1-1-is-here · https://www.windowscentral.com/gaming/stalker-2-devs-explain-why-a-life-is-broken-pledge-to-patch-it
- Nemesis patent: https://patents.google.com/patent/US20160279522A1/en · https://www.gamespot.com/articles/monoliths-shadow-of-mordor-nemesis-system-patent-doesnt-expire-for-another-decade/1100-6529722/

**Phones, rendering, cross-play**
- Thermal throttling: https://www.androidauthority.com/iphone-16-pro-max-benchmarks-3484521/ · https://www.tomsguide.com/phones/i-put-the-iphone-16-pro-max-vs-galaxy-s24-ultra-through-a-7-round-face-off-heres-the-winner
- Vertex-animation crowds: https://github.com/antzGames/Godot_Vertex_Animation_Textures_Plugin · https://docs.godotengine.org/en/latest/tutorials/performance/vertex_animation/index.html · https://github.com/godotengine/godot/issues/123257
- Determinism: https://box2d.org/posts/2024/08/determinism/ · https://gafferongames.com/post/floating_point_determinism/ · https://www.hemispheregames.com/2017/05/08/osmos-updates-and-floating-point-determinism/
- Android sideloading: https://thehackernews.com/2026/06/google-sets-sept-30-deadline-for.html · https://developer.android.com/developer-verification/guides/faq
- Gemini Nano on Android: https://developers.google.com/ml-kit/genai · https://github.com/googlesamples/mlkit/issues/1003
- llama.cpp on phones: https://github.com/nobodywho-ooo/nobodywho · https://raw.githubusercontent.com/meta-llama/llama-models/main/models/llama3_2/MODEL_CARD.md · https://github.com/JackZeng0208/llama.cpp-android-tutorial
- Model licences: https://qwenlm.github.io/blog/qwen3/ · https://en.wikipedia.org/wiki/Gemma_(language_model)
- Godot on Quest: https://godotengine.org/article/godot-xr-update-mar-2026/ · https://godotengine.org/releases/4.7/
- Nakama: https://heroiclabs.com/docs/nakama/client-libraries/godot/

**Carried over from r2:** see `docs/studio/ROUTE-r2.md` section 9.

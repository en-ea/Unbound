---
title: "The living village - design and build plan (M1 headless, M2 on screen), with the tradeoffs"
created: 2026-09-29
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio
status: plan; research and the S10 measurements folded in
inputs: docs/studio/ROUTE-r4.md (sections 3.1-3.5, 3.2a, 3.9); docs/studio/research/ (two reports); docs/studio/evidence/s3/
next_step: M1a (people, households, lineages, the day plan, places offering actions), spec first in JavaScript; Enea reads it (no decision needed)
---

# The living village: design and build plan

Hilmi, 29 Sep `[chat]`: "This is a key component of the game, ensure you prepare accordingly first and also plan how this can be done to its its best (while optimal) capacity while making tradeoffs clear".

## 0. Verdict

1. **"Alive" comes from a few rules the player can see working, not from a big simulation.** The research is consistent on this (section 2). The best systems use:
   - **per-culture norm tables:** each age or people rates each act;
   - **places that offer roles:** a pillory offers "jeer" and "pelt" to whoever is near;
   - **knowledge only through witnesses;**
   - **crowds as tipping-point cascades;**
   - **a pacing director** that rations the big moments.

   Each is cheap. The expensive route (thousands of hand-weighted desires, full gossip about everything, planners) made other games opaque and hard to tune.
2. **The failures to design against are known:**
   - violence as the cheapest route to any goal (Oblivion);
   - grief spirals (Dwarf Fortress);
   - sameness (Shadows of Doubt, Crusader Kings' repeating events);
   - causes the player can't see;
   - people reduced to meters (Frostpunk, Manor Lords);
   - villagers spawning around the player (STALKER 2).
3. **Three tiers of detail running one set of rules.** Distant villages and history use the coarse kernel (S2, years). The player's region runs people as records (M1, hours). Near the player, the same people are bodies acting out their plans (M2, frames).
4. **Our measurements set the budgets** `[run]`:
   - **Decisions:** one full villager decision costs **70 µs on the S10** (36 µs on the PC). A game day lasts 12 real minutes, so **live play is nearly free**. The costs are catch-up (about 0.4 s for 30 days away, once villagers plan at dawn) and testing (a village year takes 18 s in GDScript on the S10), which is why the rules also run in JavaScript.
   - **Crowds are the real constraint.** Today the S10 holds 30 fps with **20 walking villagers**; 30 bring it to about 25 fps, and 45 to about 15. Each of Enea's characters costs about 40 draw calls, because every outfit part is drawn separately and again for shadows. A draw call costs about 23 µs on the S10, and animation about 0.2 ms per villager.
   - **Only all four fixes together** reach a 45-60 person trial: one merged mesh per villager, shadows for the nearest only, animation slowed with distance, and a baked, instanced crowd at the back.
5. **The hard choices, with my recommendations** (section 10 has the full table):
   - three tiers;
   - villagers plan their day at dawn and replan only when something happens;
   - knowledge covers crime facts only;
   - ancestors are generated from lineages, not simulated through the centuries;
   - a JavaScript reference for the rules, with GDScript conformance (the S2 pattern);
   - content as shared data tables;
   - merged villager meshes, and a cheaper far crowd;
   - GDScript until the measured triggers in section 9 fire.

---

## 1. What the village must do (the brief, from route r4 and Hilmi)

| # | Requirement | Source |
|---|---|---|
| R1 | Villagers with needs and values commit crimes **for reasons**: theft, poisoning, false accusation, famine cannibalism | r4 3.2, 3.2a |
| R2 | Authorities try people or mobs form; public acts (pillory, stoning, hanging, bonfire, trial by combat, exile, sacrifice...) chosen by the age's law, the crowd's mood and the authority's strength | r4 3.2a |
| R3 | Acts **unfold live in phases with rescue windows**; the victim is always somewhere reachable | r4 3.2a (Hilmi) |
| R4 | **Show, don't read**: causes and intent are visible without text | r4 3.6 |
| R5 | Manipulation (plant, rumour, bribe, testify, free) is a fun side component | r4 3.5 |
| R6 | Storms regress zones to that place's **own ancestors** (three ages), whose values clash with the present | r4 3.3 |
| R7 | Language distance decides how you can deal with people | r4 3.4 |
| R8 | Anchored story villages are exempt from storms and randomness | r4 3.1 |
| R9 | Content rules: the private build and the store build | r4 3.2a |
| R10 | Deterministic and co-op-ready (the seven rules, and a replay test) | r4 3.9 |
| R11 | 30 fps on the S10 | r4 4 |
| R12 | Not grim and not samey: rhythm, reversals, veneration, festivals | the research (section 2) |

---

## 2. The evidence this plan stands on

**Systems research** `[web]` (a research agent, 29 Sep; the full report with sources is `docs/studio/research/village-systems.md`).
- **Dwarf Fortress:**
  - personality as integers where the middle band stays silent, so only the extremes show;
  - crime cases exist only if someone witnessed the crime;
  - the "tantrum spiral" and its damper: burials and memorials.
- **RimWorld:**
  - the storyteller's on/off cycles;
  - precepts that rate execution per culture;
  - rituals that score higher with more spectators;
  - wealth-scaled threats that players learned to game.
- **Crusader Kings 3:**
  - secrets that are "criminal" or merely "shunned", depending on the faith;
  - opinion penalties that spread along kin and friends;
  - written events that repeat.
- **Shadows of Doubt:**
  - each citizen's day planned in a batch at dawn;
  - a sightings table;
  - memory where the time blurs first;
  - critics found it "samey": five murder types, and killers with no motive.
- **Talk of the Town:** eleven evidence types, and retelling strengthens a belief. It was too expensive to simulate fully, so its knowledge was implanted at generation.
- **Versu:**
  - practices that offer choices and never command;
  - a violated norm spawns a response practice;
  - a "dominating practice" (a body found) suppresses jokes.
- **The Sims:** places advertise actions, so behaviour lives in objects and new props add behaviour for free.
- **Frostpunk:** execution with a cooldown; the designer's point that nobody can care about 700 people.
- **Oblivion's Radiant AI:** killing was the cheapest route to any goal.
- **STALKER:** the offline tier is a lower level of detail of the online one, with the same rules; STALKER 2 shipped a spawn bubble and players noticed.
- **History:**
  - **Salem:** cascades travelled along invitations and kin; resisters were accused; confession traded guilt for life.
  - **Oster, and Christian:** hardship creates demand for a scapegoat; the authorities' capacity decides how many trials happen.
  - **Granovetter:** thresholds decide whether a riot happens or one window breaks.
  - **Centola and Macy:** accusations are a "complex contagion" that needs several sources.
  - **Ordeals:** 62.5% acquitted at Várad.
  - **Crowds:** Foucault's crowds that rescued the condemned; Defoe pelted with flowers.
  - **Girard:** the scapegoat is first demonised, then made sacred.

**Measurements** `[run]` (spike S3; the details and raw outputs are in `docs/studio/evidence/s3/`):

| What | PC (Ryzen 7 5800U) | Galaxy S10 |
|---|---|---|
| **One villager decision:** 16 actions × 4 considerations, 4 choosing a target among 30 villagers, a rumour step, a queue reschedule | 35.9 µs (27 per ms) | **70.0 µs** (14 per ms) |
| **A village day,** 30 villagers deciding 24 times each | 25.8 ms | 50.4 ms |
| **A village year** (the same) | 9.4 s | 18.4 s |
| **Walking villagers:** median frame (draws) | 20: 33 ms (1,095); 30: 33 ms (1,394); 45: 33 ms with 6 frames over 50 ms (2,107); 60: 41 ms (2,855) | 20: **33 ms** (1,090); 30: 40 ms (1,395); 45: 66 ms (2,082); 60: 99 ms (2,840) |
| **What drives it, S10, 30 / 45 villagers** | - | Full: 40 / 66 ms. No villager shadows: **33 / 46 ms**. Animation frozen: 34 / 57 ms |
| For reference: a game day | 12 real minutes (`day_night.gd`) | - |

**Engineering research** `[web]` (a second agent, 29 Sep; the full report with sources is `docs/studio/research/village-engineering.md`):
- **Navigation**
  - Godot's navigation queries run on the main thread by default, have no built-in time-slicing, and cost more with more navmesh polygons.
  - Per-agent grid pathfinding scales badly: 500 agents took 670 ms per frame, against 2 ms with one shared flow field.
  - Hitman and Fieldrunners 2 used precomputed flow fields for crowds.
- **Animation**
  - About 5-12 µs per animation instance before any bones; about 13.5 µs per skeleton on a desktop.
  - A hidden skeleton still costs CPU.
  - There is no built-in animation or bone level of detail. The workaround is to advance the animation manually, at a rate chosen per distance.
  - The Compatibility renderer skins on the GPU.
  - Assassin's Creed Unity: full NPCs within 12 m (at most 40), puppets to 40 m, an instanced crowd beyond.
  - Baked animation on MultiMesh gives thousands of animated instances in one draw call.
- **Decisions and scheduling**
  - Utility AI with multiplying considerations and early outs (Guild Wars 2).
  - Shipped GOAP planners ran under 1 plan per second per NPC, even in C++.
  - RimWorld spreads ticks into Normal, Rare and Long lists.
  - Kingdom Come: Deliverance II's LOD kept scripts unaware of it.
- **GDScript vs C++**
  - 7-13x on boids on Godot 4.7.2, and 40-100x on pure maths.
  - Calling the engine per element erases the gain.
  - WorkerThreadPool gives the S10 about 2 low-priority workers, and every task must be waited on.
  - The S10's little cores are 2-3x slower than its big ones.
- **Determinism**
  - Godot's `Array.sort` is not stable, and its RNG algorithm is "not to be depended upon".
  - ARM compilers fuse multiply-adds, so floats can differ between the PC and phones.
  - Factorio kept 800 cross-platform tests comparing checksums, and diffed save-load-save to find hidden state.
- **Warnings for us**
  - The game's own scripts already peak near 20 ms per frame on the S10, which leaves villagers about 5 ms of main-thread time.
  - Godot 4.7.2 has an iOS link issue with GDExtensions (#122549), fixed in 4.8.

**One disagreement, settled by our measurement.** The research estimated 2-4 draw calls per skinned character. We measured about 40 on Enea's characters, because each outfit part is a separate mesh with its own shadow pass. Merging the parts is therefore the first job (section 9).

---

## 3. Architecture: three tiers, one set of rules

```
 TIER C  COARSE (the S2 kernel)       every village and people in the lands, history over centuries
         years · settlements           storms' past, far villages' fortunes, lineages' origins
             │ promotes a settlement to tier V when the player's region needs it (and demotes it after)
             ▼
 TIER V  VILLAGE (M1, worker thread)   people as records: households, lineages, roles, values, needs,
         game hours · events           beliefs, grudges; day plans at dawn; crimes, cases, trials,
                                       crowds, public acts, stagings; the pacing director
             │ stagings and plans (who goes where, doing what, until when; rescue windows)
             ▼
 TIER E  EMBODIED (M2, main thread)    the same people as bodies near the player: walk, work, gather,
         frames · visual only           jeer, pelt; gestures, barks, props; the player's actions go
                                       back into tier V as logged actions
```

- **One set of rules at different cadences** (the STALKER lesson). A tier-V village away from the player keeps running daily, and villagers never spawn in the player's view. A headless probe checks that a village run at the far cadence and at the near cadence gives consistent outcomes (section 11).
- **Tiers C and V are deterministic and logged** (r4's rules 1-7). Tier E is visual only: anything that matters, such as a rescue, a hit or a planted item, returns as a logged action.
- **Promotion and demotion.** Entering a region promotes its villages from tier C to tier V: people are generated deterministically from the settlement's state and its lineages. Leaving demotes them, folding people back into households with their identity kept.

---

## 4. People: what each villager is (and what we don't model)

Sylvester's filter applies: **a variable exists only if it ends up in a story the player can see.**

| Part | Content | Visible as |
|---|---|---|
| Identity | id, name, lineage, household, sex, age band (child / adult / elder), age-era (tribal / village / town) | Clothes and props by era; family groups |
| Role | farmer, smith, miller, priest, elder, guard, merchant, beggar, outlaw... | Workplace, tools, schedule |
| Traits | 4-6 facets from 0 to 100 (boldness, piety, greed, compassion, honesty, temper). **The middle band is silent**; only extremes show | Walk and pose; who throws the first stone |
| Values | Deviation from the village's culture table (tradition, faith, law, mercy) | Reactions at trials |
| Needs | food, rest, safety, belonging; decay per day | Queues at the well; hunger, then theft |
| Stress | 0-400. Rises from acting against one's values and from grief; falls with rites and festivals | Coping: drinking, praying, refusing to take part |
| Relationships | Sparse opinion links: kin, friends, rivals, grudges; at most 12 per person | Who defends, who accuses |
| Beliefs | **Crime facts only**, capped at 8 per person: who did what, where, and how strong the belief is. Evidence types: observed, told, lie, confabulated | Accusations; rumours (a whisper to someone, a nod towards the accused) |
| Marks | branded, exiled, venerated, cursed | On the model; how people step aside |

**Not modelled:** general small talk, full gossip, fine-grained needs, skills beyond the role, and inner monologue. They cost a lot and don't reach the screen.

---

## 5. How villagers decide

1. **The day plan at dawn** (Shadows of Doubt). Each villager gets 4-8 activities (work, eat, market, prayer, tavern, home), chosen from their role, needs, values and the season. **They replan only when something happens:** an event near them, a need spiking, a staging calling them. This is the single biggest saving (section 9).
2. **Places offer actions** (The Sims). The well offers "draw water" and "gossip"; the pillory offers "jeer", "pelt", "pity" and "free"; the shrine offers "pray" and "offer"; the stake offers "bring wood", "watch", "look away" and "intervene". Each offer is weighted by the villager's needs, traits and values. **The choice is weighted-random among the top three**, never the single best, so crowds don't move in lockstep. It uses keyed randomness, so it's deterministic. New acts and places are data, not code.
3. **The norm table per culture and age** (RimWorld precepts, Crusader Kings doctrines). Each act is rated per culture and age: required, respected, indifferent, shunned, criminal or abhorrent. The rating decides:
   - whether an act is a crime;
   - how people react;
   - how much stress acting against it costs.

   It is also where the ancestors and the present clash. Ritual cannibalism is "required" in the tribal culture and "abhorrent" in the village.
4. **Not used, with the reason:**
   - **GOAP and HTN planners:** the cost per decision, and they're harder to keep deterministic and legible.
   - **Language models:** the cost, determinism, and r4 parks them.
   - **Thousands of weighted rules** (Prom Week, Versu): the authors found them hard to tune.

---

## 6. Crime to consequence: the pipeline

```
 MOTIVE (a need or grievance) + OPPORTUNITY (unwatched place and time) + INHIBITION too weak (values, fear)
   → the ACT (theft, poisoning, false accusation, famine cannibalism...)
   → TRACES (a missing item, a body, a cooking pit, a poisoned well) + SIGHTINGS (who saw what; fades)
   → BELIEFS spread along relationships (retelling strengthens; confabulation leans towards the disliked)
   → a CASE opens once 2 independent sources point to one person (accusation is a complex contagion);
     gossip needs 1
   → the AUTHORITY: capacity (its strength, funds) × demand (hardship, fear, omens) decides
       a TRIAL (witnesses, ordeal, confession, trial by combat) or, if the authority is weak and the crowd
       angry, a MOB
   → a PUBLIC ACT from the law table (r4 3.2a), in phases with rescue windows
   → the crowd as a THRESHOLD CASCADE (who joins, how far pelting escalates, whether it turns)
   → AFTERMATH: grief rites (the damper), feuds along kin, marks, exiles who persist as outlaws, graves;
     and if the truth comes out, the wrongly executed become venerated and the accuser falls
```

**Guards against the known failures:**
- **Every crime needs a grievance or a need** (Radiant AI). Killing is never the cheap route: it needs a strong motive, an opportunity and weak inhibitions together.
- **Grief has a damper** (Dwarf Fortress): burials, wakes and memorials visibly lower stress. Kin defend each other only when the kin is the victim, which stops loyalty cascades.
- **Story-critical roles in anchored villages are protected** from death by the simulation.
- **Children** follow r4's content tier (private or store).

---

## 7. Crowds, pacing and variety

- **Crowd as a cascade** (Granovetter). Each villager has an integer threshold built from temper, grievance, kinship to the condemned, and fear of the authority. They join once enough others have.
  - Pelting escalates from food to mud to stones, and a mob forms or dissolves, by cascade.
  - **The player's lever is the early joiners:** calm the hothead, or throw the first flower (Defoe's crowd).
  - Cascades also turn. A sympathetic victim and a hated accuser can flip the crowd to rescue, as Foucault's scaffold crowds did.
- **The pacing director** (RimWorld's storyteller):
  - keyed on/off cycles per village;
  - **at most one lethal public act per on-cycle**;
  - after a death, a cooldown with grief rites;
  - off-cycles carry births, weddings, festivals and harvests (what Manor Lords players asked for).
- **Variety targets** (checked headless):
  - no act type twice in a row in one village;
  - **no single ending above ~40%** of cases (carried out, commuted, rescued, crowd turns, ordeal acquits, confession spares, venerated);
  - most cases end in a fine, penance, the pillory or exile, and death needs the norm, the cascade and the authority to line up.
- **Villages differ** in:
  - culture table and age;
  - a founding feud (between lineages, over a field, a well or a grave);
  - their current hardship.

  Following Kate Compton, difference is judged by perception (look boards, story samples), not by seed counts.

---

## 8. Storms, ancestors, language, anchored villages

- **Ancestors come from lineages, not from centuries of individuals.**
  - Every household belongs to a lineage (tier C records a lineage's village, founding and fortunes).
  - When a storm regresses a zone, its people are **generated deterministically** from each lineage, the past year and that age's culture table. Names repeat down lineages ("Old Aldric", great-grandfather of today's Aldric), and traits are inherited with drift.
  - **The tradeoff:** we can't recall "the specific grandfather who stole the mill in year 312" unless tier C logged it. Tier C does log notable acts per lineage (a few per century), so the famous ones return.
- **The clash is automatic.** The regressed zone becomes a tier-V settlement with the tribal norm table. The rites, trials and fears follow from the tables.
- **Language distance** (r4 3.4), from the difference in age and people, gates which offered actions work across the border:
  - talk;
  - trade with misunderstandings (goods mistaken);
  - barter and gestures only;
  - hostile.
- **Anchored villages** have authored roles and schedules alongside the rules. They are exempt from storms and random ruin, and their story roles are protected.

---

## 9. Performance: budgets, measured costs, optimisations, and when to move to C++

**Budgets** `[design]` (the S10 is the floor):

| Use | Budget | What drives it |
|---|---|---|
| Live play | < 1 ms of worker time per real second; main thread untouched | Decisions per real second: about 30 × (plans + replans) ÷ 720 s |
| Catch-up after time away | < 2 s on opening (one game day per real day away, up to 30) | Village-days × cost per village-day |
| A storm's view into the past | < 0.5 s | Lineage generation, not simulation |
| Headless testing (PC) | 1,000 village-years in < 15 minutes | JavaScript reference in Node (section 11) |
| Embodied crowd | 30 fps on the S10 with 30 villagers near, and a trial crowd of 45-60 | Draw calls per villager; animation cost |

**Where the measured costs land** `[run]` + `[design]`:
- **Decisions** `[run]` + `[design]`. At 70 µs each on the S10 and hourly decisions, a village day costs 50 ms. With dawn plans plus replans (about 6 decisions per villager per day instead of 24), it's about 13 ms.
  - Catch-up for 30 days: about 0.4 s.
  - Live play: about 0.1 ms of worker time per real second.
  - On the S10's little cores, which are 2-3x slower, catch-up is still about 1 s.
  - **GDScript is enough for tier V in play.**
- **Testing thousands of years in GDScript is too slow** (9 s per village-year, PC). That is why the rules are also written in JavaScript: Node runs them 10-15x faster (S2 measured 14x), so 1,000 village-years take minutes. The GDScript version is checked against it over shorter spans.
- **Drawing and animation are the real constraints** `[run]`: 20 walking villagers is today's S10 limit at 30 fps.
  - **Draw calls.** About 40 per villager, because each outfit part, and its shadow, is drawn separately. About 23 µs each on the S10: turning villager shadows off took 45 villagers from 66 to 46 ms.
  - **Animation.** About 0.2 ms per villager at full rate: freezing it took 45 villagers from 66 to 57 ms.
  - **The fixes are needed together, in order:**
  1. **Merge each villager's parts into one skinned mesh.** Colours already come from palette UVs (Enea's own technique), so one material is expected to take a villager from about 40 draws to 1-2.
  2. **Shadows only for the nearest villagers.**
  3. **Throttle animation for distant villagers** (fewer skeleton updates).
  4. **Past about 30 bodies, a cheaper far crowd:** vertex-animation textures with MultiMesh, or impostors, for the back rows of a trial crowd.
- **When to move to C++ (GDExtension)**, restated from S2 with real costs. Any one of these fires it:
  - catch-up of 30 days over 2 s on the S10;
  - a live-play worker load over 5% of one core;
  - tier V needing more than one fully simulated village near the player at a time (Land 3 with friends).

  Until then, GDScript: it's faster to change, and Enea can read it.

**Presentation (tier E) on the main thread**: the design, from the engineering research. Main-thread budget for villagers: **about 5 ms per frame on the S10**, since the game's scripts already peak near 20 ms.

| Subsystem | Technique | Expected S10 cost `[design]` (estimates) | Fallback if over budget |
|---|---|---|---|
| Routine walking (30 villagers) | **Cached paths between the village's fixed points** (about 40 points, built on the worker at load). **No NavigationAgent per villager.** Unseen villagers' positions computed from path and time | 0.05-0.15 ms | A waypoint graph only |
| Unplanned routes (chase, flee) | `query_path` on the worker; navmesh under 1,000 polygons; at most 2 requests per frame | about 0 on the main thread | The nearest cached path |
| Gathering crowds (30-60) | **A precomputed flow field per venue** (square, gallows, stake, shrine, gate; about 4 KB each); slot rings around the focal point, assigned by id; separation steering | 0.3-0.6 ms | Steer at 15 Hz in staggered halves |
| Avoidance | Separation on a spatial hash; the engine's RVO only near the camera | 0.1-0.5 ms | Separation only |
| Near animation | The ~12 nearest at full rate. Enea's characters already use AnimationPlayer without AnimationTree, which avoids the worst measured cost | 0.5-1.2 ms | 8 characters at 15 Hz |
| Mid animation (12-40 m) | Skeletal, advanced manually at 10-15 Hz | small | Fewer, slower |
| Crowd animation (beyond) | **A baked bone texture on MultiMesh**: every Quaternius character shares one skeleton, so one small texture (about 0.4 MB) serves every costume. A custom shader, about 1-2 days of work | under 0.2 ms, 1-3 draws | Animated impostors |
| Off-screen villagers | Mixers and skeletons switched off explicitly (a hidden skeleton still costs CPU) | 0 | - |
| Handing the simulation to the scene | A double-buffered snapshot per simulation tick | 0.1-0.3 ms | Apply half the villagers each frame |
| **Draw calls** | **Merge each villager's parts into one skinned mesh** (palette UVs, so one material); shadows for the nearest only | from about 40 to 1-2 draws per villager (measured before, to be measured after) | Fewer outfit parts in the far crowd |

Estimated total for a 60-person execution after the fixes: **about 430 draw calls** (the S10 held 629 at 30 fps in look board 1) **and about 2-4 ms of main-thread time** `[design]`, inside the 5 ms budget. M2a measures it. The game's own 20 ms script peak on the S10 is worth profiling separately; it is Enea's code and needs his input.

**The simulation (tier V) on the worker**:
- **Its own thread** (a dedicated `Thread`, or one bounded pool task per simulation tick), never a pool task that runs forever. `thread_probe.gd`'s long-running pool task is fine for a probe, not for the game.
- **Budgeted for the S10's little cores** (2-3x slower than the big ones).
- **A timing wheel** keyed by (tick, id) instead of the spike's binary heap: about 1-2 µs per event against 5-15 µs `[design]`. Interrupts pull a villager's next decision forward, and stale entries are skipped by a generation counter.
- **Decisions:** response curves as lookup tables (already in the spike); inputs cached per decision; targets pruned to the top few by proximity and knowledge; cheap considerations first, so a zero stops the decision early.
- **Multi-step acts** (accuse, gather witnesses, fetch the reeve) as short hand-written method lists. GOAP planning would cost 5-50 ms per plan in GDScript on the S10 `[design]`.

---

## 10. The tradeoffs (the decisions this plan makes)

| Decision | Options | We gain | We give up | Recommendation |
|---|---|---|---|---|
| Fidelity by distance | Everyone as a full agent / **three tiers** | 10-100x less cost; offline villages keep going | Nuance of distant villages (the daily level only) | **Three tiers, same rules** |
| When villagers think | Every tick / **dawn plan plus replans on events** | About 4x fewer decisions; schedules read as routines | Reactions between events are slower (a replan triggers on anything notable) | **Dawn plan plus replans** |
| Knowledge | Full Talk-of-the-Town gossip / **crime facts only** (8 per person) | Cost and legibility; accusations stay traceable | Gossip about everything; romantic intrigue | **Crime facts only** (romance can be added as a fact type later) |
| Ancestors | Simulate every generation / **generate from lineages** | Instant storms; coherent names and traits | Unlogged specific deeds of ancestors | **Lineages, with notable deeds logged per lineage** |
| Rules verification | GDScript only / **JavaScript reference plus GDScript conformance** | Thousands of years tested in minutes; correctness; the same rules can run on Cloudflare later (r4 3.9) | About 1.5x the work on the rules code | **The twin, for tier V rules only** (not for tier E) |
| Content | Code / **shared data tables** (norms, acts, places, laws) | Both implementations read the same data; new acts without code; Enea can tune them | A table format to design | **Data tables** |
| Choice | Best option / **weighted-random among the top 3** | Crowds don't move in lockstep; surprise | Occasionally a less-than-best choice (intended) | **Top 3** |
| Crowd rendering | Every villager as-is / **merged meshes, near shadows, a far crowd** | 30-60 bodies at 30 fps | A day of tooling (the mesh merge); far crowds less detailed | **Merge first, then measure** |
| Language | GDScript / C++ now | Speed now (7-13x on simulation code; more on pure maths) | Iteration speed; Enea's readability; iPhone build risk (4.7.2's GDExtension link issue) | **GDScript until a trigger fires** (section 9); then C++ only for measured hot loops, with one call per tick carrying packed arrays |
| Movement | NavigationAgent per villager / **cached paths, venue flow fields, separation** | Main-thread cost near zero; deterministic | Exact avoidance in tight crowds (separation is looser) | **Cached paths and flow fields** |
| Animation | Every body at full rate / **full rate near, throttled mid, baked crowd far** | 60-person scenes on the S10 | Far bodies animate more simply (idle, cheer, jeer, walk loops) | **The tiered approach** |
| Scheduling | Heap / **timing wheel** | 5-10x cheaper scheduling in GDScript | A fixed tick granularity (one game minute) | **Timing wheel** |
| Legibility | Text chronicle / **cues** (pose, gesture, bark, prop, gaze at the target) | "Show, don't read" | Precision for subtle causes | **Cues**, plus the optional in-world notice board (r4 3.6) |

---

## 11. Verification: how we know the village is alive and not broken

- **Conformance** (the S2 pattern). The tier-V rules are written in JavaScript (`tools-src/studio/village-reference/`), with golden hashes. The GDScript version must reproduce them.
- **Invariants over thousands of simulated years** (in Node):
  - every notable act has a recorded cause chain (motive, traces, beliefs, case) **and** a cue;
  - no collapse loops: a village never empties through punishment spirals, and grief always has a damper;
  - variety targets (section 7): no ending above 40%, no act type twice in a row;
  - lethal public acts per village-year stay inside the director's budget;
  - storms produce a clash in a share of cases, as S1b did, now driven by norm tables as well as land.
- **Replay test** (r4 3.9): a session's action log replayed headless reproduces the world hash.
- **Save-load-save round trip** (Factorio's lesson): saving, loading and saving again gives identical bytes. That finds hidden state that would desynchronise co-op.
- **Every sort breaks ties by id** (Godot's sort is unstable), and the village simulation holds no floats.
- **Tier consistency:** one village run at the far cadence and at the near cadence gives consistent outcomes (the STALKER check).
- **Story extraction** for owner review: the best 10 stories per 100 years, as short readable chains. These are for us, not the game. They test whether the village is interesting, which no metric can.
- **On the S10:** decision cost, catch-up time and crowd frame times, measured by the device lab at every sub-milestone.

---

## 12. Build order (M1 and M2), each with its gate

| Step | What | Gate |
|---|---|---|
| **M1a** | People, households, lineages; roles; the day plan at dawn; places offering actions; needs | 30 villagers live 10 years headless with plausible routines; S10 cost measured |
| **M1b** | Norm tables per culture and age; crimes with motive, opportunity and inhibition; sightings; crime beliefs; the 2-source accusation rule | Crimes arise only with a recorded cause; accusations can be traced |
| **M1c** | Authority capacity and demand; trials (witnesses, ordeal, confession, trial by combat); mob thresholds; public acts with phases and rescue windows; aftermath (grief rites, marks, exiles, shrines, veneration) | The slice's chain 1 (theft → pillory → hanging or exile) runs end to end headless, with every ending reachable |
| **M1d** | The pacing director; variety guards; the JavaScript reference; conformance; the invariants over 1,000+ years | All invariants pass; the golden hashes match on the PC and the S10 |
| **M1e** | Storms → lineage ancestors → the tribal norm table; language distance; anchored villages; promotion and demotion between tiers | The slice's chain 2 (storm → rite → fear → bonfire or veneration) runs headless |
| **M2a** | The villager mesh merge; near-only shadows; animation throttling by distance; cached paths and venue flow fields; the baked-bone crowd shader; the crowd benchmark rerun | 30 villagers plus a 45-60 trial crowd at 30 fps on the S10, with villagers under 5 ms of main-thread time |
| **M2b** | Embodiment: schedules walked, places used, stagings played (gathering, the gallows built, the stake raised) | A trial plays out on the S10 and reads without text |
| **M2c** | Cues: poses, gestures, gaze at targets, barks, props that persist; rescue interactions | Two outside viewers (you and Enea) can say why each act happened |

---

## 13. Risks

| Risk | Response |
|---|---|
| The village is correct but dull | Story extraction reviewed by the owners at M1c and M1e; tune the norm tables and the director before M2 |
| Tuning many weights becomes a swamp (Versu's warning) | Few variables (section 4); data tables; the headless metrics show the effect of every change |
| Crowds break the S10 even after the merge | The far-crowd technique; smaller crowds in the private build; the tilted camera limits what's on screen |
| Determinism slips through tier E | Everything that matters returns as a logged action; the replay test at every step |
| Content tiers diverge (private or store) | One world setting read by the rules; both tiers covered by the invariants |

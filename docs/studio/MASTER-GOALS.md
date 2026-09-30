---
title: "Unbound master goals - the adventure and the world we can interfere with"
created: 2026-09-29
type: master-goals
voice: agent-draft
author: Codex (Astra), grounded in Hilmi and Enea's intent and the original Opus conversation
status: superseded on 30 Sep by MASTER-GOALS-r2.md (kept as history; its goal cards in section 5 remain the detail for the B batches)
next_step: an Opus lead selects the first bounded play loop in section 7, checks current branches, and implements it with at most two explicitly selected Sonnet helpers
---

# Unbound master goals

> **30 Sep: superseded by [MASTER-GOALS-r2.md](MASTER-GOALS-r2.md).** The revision adds the division of labour with Enea, the landing path, the `camera-test` baseline and the missing foundations. The goal cards in section 5 below still hold as detail.

[design] Read the [intent](#1-the-game-we-are-building), [current baseline](#3-current-baseline-what-exists-and-what-does-not) and [goal index](#4-goals-and-initial-status) first. Implementation leads then use the [batch sequence](#7-work-in-related-playable-batches), [execution brief](#8-opus-lead--sonnet-helper-operating-brief) and [living ledger](#9-living-completion-ledger-and-open-choices). Detailed goal cards and source provenance follow in the same document.

## 1. The game we are building

[chat/design] **Unbound is a mobile action-adventure and life game in a world with a life of its own.** Gather, craft, fight, discover powers and equipment, build a home, explore three lands and eventually play together. Along the way, people work, misunderstand, steal, help, remember, organise and sometimes turn on one another. The player is a person among them, able to intervene, cause trouble, leave and meet the consequences later. Village drama enriches the adventure; attending hearings is never the main job.

[chat/design] The latest brief asks for this master document so an **Opus lead can select a few related goals, direct Sonnet helpers and keep delivering coherent improvements**. It is a programme for future implementation, not a declaration that every feature below already exists, and not an instruction to implement the whole catalogue in one run. The original night slice is one completed engineering milestone within this larger ambition.

[design] Judge progress by what a player can do and understand. A strong first example is: **punch a resident, see that particular person react, see a nearby person decide whether to intervene, escape or make amends, and return to a village that remembers the right incident.** A later example is: free a captive, capture their captor, change your mind and restrain both, move them somewhere else, and face escape attempts, witnesses and retaliation. Those actions should compose without requiring a bespoke mission for each combination.

[chat/design] Equally valid play is ignoring all of this, gathering supplies, improving gear and heading into a dungeon. Successful work must serve both players.

## 2. Authority, sources and reconciled intent

### How to read this document

[repo] Evidence labels follow the studio convention: **[chat]** owner words or supplied conversation; **[repo]** inspected files/Git; **[run]** recorded execution; **[design]** a proposed implementation or acceptance criterion. A proposed number, behaviour or schedule is not an owner decision merely because it appears here. The source register in section 10 distinguishes original messages, an assistant's interpretation and implemented evidence.

[design] Apply the latest explicit owner statement to the subject it addresses. Preserve compatible earlier decisions. An agent-written route or AI summary does not override Enea's game plan or Hilmi's later clarification. If two current owner intentions genuinely conflict, prepare the concrete choice and ask once; continue independent work. Do not use an old prototype's limits to silently reduce the ambition.

| Subject | Controlling interpretation | Sources |
|---|---|---|
| The central loop | [chat] Gathering, crafting, combat, loot, class growth, home and exploration remain central. Story opens places; play continues afterwards. | S2, S3, S4 |
| Village drama | [chat] Optional, surprising side fun. No obligation to attend a daily hearing; no punishment for simply pursuing another activity. | S0, S1 lines 523, 3120, 3187 |
| Agency | [chat/design] Physical actions should create situations, not only answer offered event buttons. Violence, rescue, capture, transport, deception and assistance belong to the shared world. | S0, S1 lines 3374, 3396, 3898 |
| Character behaviour | [chat/design] Motives, local knowledge and circumstances matter. A surprised or puzzled response to a first punch is as valid as fear or retaliation. Avoid universal instant aggression. | S0, S1 lines 523, 3660; S6 |
| Three lands | [chat] Keep Enea's authored geography and progression. Land 2 has internal ideological factions; hostility from one group does not make its entire people enemies. Land 3 opens community by community. | S0, S2, S3 |
| Player role | [chat] Begin as an ordinary villager and grow into a champion. Older wording that everyone starts as an established champion describes an eventual role, not a replacement opening. | S2, S3; reconcile S5 |
| Scale of influence | [chat/design] Individuals can affect families, groups and settlements through deeds and relationships. Do not restore the superseded god-view or city-management ladder. | S1 lines 3187, 3253; S0 |
| Storms | [chat] Three ages: tribal, village, town. Affected people are that place's forebears. Local regression preserves the player and possessions, with protected story anchors. | S1 line 3189; S5 |
| Controls | [chat/design] Improve lock-on and consider two ability buttons above/below the main action. The earlier gesture-cluster summary is a prototype idea, not an approved mandatory replacement. | S0; S1 line 3187; S7 |
| Camera | [chat/design] Hilmi prefers the tilted everyday view; low/eye-level is optional for looking, high view useful for building. Do not add automatic fight-camera choreography. Enea's feel confirmation remains open. | S1 lines 3189, 3253; S4, S5 |
| Platforms | [chat] Web is Enea's immediate route. Native Android is useful for development; free native iPhone later remains desirable. Older native-only directions are superseded. | S4; S1 line 3894 |
| Co-op | [chat] Friends sharing a world is a real goal. Solo quality first, online co-op later; they will not rely on being on the same Wi-Fi. Preserve room for it in new state/action work. | S1 line 3262; S2-S5 |
| AI and cloud | [chat/design] Opus/Sonnet cloud usage is the development workforce. Runtime villagers do not require cloud model calls. Use economical local decisions and short expressive lines unless a measured gameplay need warrants revisiting this. | S0; S1 lines 3187, 3660 |

[repo/run] **Cadence correction:** twelve real minutes is the current length of a game day. The measured first hearing at about thirteen minutes was one run, not a promise or a universal hearing interval. Cases arise from rules; the director can introduce pressure after prolonged quiet. This still needs ordinary-play tuning against the latest side-fun intent. Neither “completely unscheduled” nor “a hearing every thirteen minutes” accurately describes the implementation. See G09 and S8.

### Creative scope and content

[chat] Hilmi explicitly allowed invention in characters, behaviour, interactions and reusable map composition. Preserve that latitude. The goals below give outcomes and constraints; they do not require an approval request for every compatible prop, animation choice or small behaviour.

[chat/design] The private-game content discussion allows dark events, hostages, rescue and stylised adult injury. It excludes sexual violence, owning/trading people and medieval torture systems. The latest capture/horse/basement example belongs to captivity with agency and consequences; it is not permission to turn residents into tradable property. Keep escape, rescue, release and retaliation meaningful. The latest conversation's speakers are not individually labelled, so do not fabricate attribution to Enea or Hilmi for its individual lines.

[repo/chat/design] Children are protected from player attacks/public punishment in the current continuation. Preserve that for the next batches. The older chat separately contemplated indirect danger from world events and excluded visible wounds/dismemberment on children; any later expansion must explicitly reconcile those records instead of silently changing the current rules. A possible public/store version is later scope, with fresh platform review then. It must not consume the next gameplay batches.

## 3. Current baseline: what exists and what does not

[repo] Snapshot checked on 29 September 2026: game repository `C:/Users/hilmi/Downloads/Unbound-Studio/game`; Godot project `game/`; local and published `studio` at **`535fd4041c150f1c233fb2112da9093e4dabea05`** before this document. Product source is `17c1f06`; Web export is committed at `6c4667b`. The outer studio repository is a separate repository. Recheck all branches at each implementation launch.

[repo] A fresh read-only fetch during this document found **`origin/main` at `1d6f4ed`**, beyond the continuation's integrated base `b9618d6`. New work includes Wren's two-handed shears, Morrow's look and wandering, eased NPC walking, build-lab residents, masks and hats. It has **not** been merged during this documentation task. Preserve and reconcile it before overlapping edits; new cosmetic masks are not evidence of working disguises. Enea continues owning `main`; studio work must not overwrite it.

| Capability | Actual state at this snapshot |
|---|---|
| Existing adventure | [repo/run] Walking, gathering, basic combat, crafting, skills, gear/loot/armour, cooking, trader/projects, meadow/forest travel, home/interior/furnishing and named NPC dialogue/quests exist. Coverage varies; use `SYSTEMS.md` and inspect the current code rather than treating this row as an exhaustive regression pass. |
| Village identity and life | [repo/run] Persistent simulated people, households, traits, kin, knowledge and simple daily routes. Same resident body is borrowed by an event. Everyday presentation is still fairly simple. |
| Hearing/public-act/rite influence | [repo/run] Listen, inspect a trace, testify, a conditional coin offer, locally discovered planted evidence, Free, a shield contact and a rite offering. Accepted consequences save immediately and survive travel/reload. |
| Arbitrary assault | [repo] Missing. `player/fighter.gd` targets the `enemy` group; ordinary residents have no combat damage adapter. Village actions currently require an existing event window. |
| Reactive social combat | [repo] Missing as a general live system. Stored standing/grudges are not pursuit, defence, flight or organised retaliation against the player. |
| Trial by combat | [repo] A simulated result/presentation exists. The player does not yet fight an actual champion duel to determine the verdict. |
| Generic custody | [repo] Event-specific restraint and rescue exist. Player capture, repeated restraint, carrying, horse transport, home confinement and escape are not a completed reusable system. |
| Perception and disguise | [repo] Crime witness/source rules and outfit assets exist. General live recognition, disguises, suspicion and perception-reset items are missing. |
| Groups and large conflicts | [repo] Traits, kin, crowd decisions and coarse world history provide ingredients. Persistent emergent factions/cults, live group objectives and responding forces are not delivered. |
| Storms | [repo/run] Local household/district ancestor replacement, an interruptible rite and recession persistence exist. Full forecast-to-border-conflict gameplay, three-age building conversion and settlement-scale integration remain incomplete. |
| Reusable world expansion | [repo] One focused village layer uses the existing meadow sites. This is not an implemented generator of all three lands or a complete coarse-to-near settlement lifecycle. |
| Combat growth | [repo] Combo/heavy/roll/stamina/gear systems exist. Lock-on/parry proposals, two ability controls, the class tree and broader weapon/spell range must be checked and implemented; plans alone do not count. |
| Persistence | [repo/run] The village has one logical clock, persistent events and normal saves; menu/background/app closure freeze it, playing in another region advances it. This does not prove every existing game system uses that same clock. |
| Networking | [repo] No live multiplayer. Deterministic village/kernel checks are useful foundations, not proof that physics, combat RNG or the entire game are network-ready. |
| Performance | [run] Optimised resident bodies retained. S10 sustained village and 45-walker checks passed; cold arrival still hit about 312 ms and sustained uncapped play throttled thermally. A walking crowd is not a battle benchmark. |
| Delivery | [repo/run] Web build and separate Android APK prepared; ordinary APK installed on S10. Actual iPhone Safari/offline/safe-area checks and owner feel remain pending. |

[repo] Implementation entry points: [fighter](../../game/scripts/player/fighter.gd), [player actions](../../game/scripts/player/player.gd), [village actions](../../game/scripts/studio/village/sim/runtime.gd), [live bridge](../../game/scripts/studio/village/live.gd), [residents](../../game/scripts/studio/village/residents.gd), [session](../../game/scripts/studio/village/session.gd), [crime](../../game/scripts/studio/village/sim/crime.gd), [justice](../../game/scripts/studio/village/sim/justice.gd), [ordinary named NPC](../../game/scripts/world/npc.gd), [system map](../SYSTEMS.md). Existing simulation tests and the JavaScript reference are under `game/scripts/studio/village/sim/` and `tools-src/studio/village-reference/`.

## 4. Goals and initial status

[design] IDs are stable. Select a **bounded part** of a goal in a batch; a goal can span several batches. Prerequisites mean the smallest relevant contract or slice, **not completion of the entire referenced goal**. For example, a local storm can work before full faction formation, and a new authored route can open before settlement generation is complete. The initial status below describes the whole goal, not the existence of individual ingredients. All acceptance criteria below are proposed engineering/play criteria, not claims of tests already passed.

| ID | Goal | Initial state | Main prerequisites |
|---|---|---|---|
| G01 | Deliberate, responsive phone combat and targeting | Partial | Existing fighter; current-main reconciliation |
| G02 | Physical actions that create world incidents | Missing integration | G01 minimal targeting; G21 |
| G03 | Immediate, individual resident decisions | Partial foundations | G02, G04 minimal perception |
| G04 | Witnesses, reports and bounded local knowledge | Partial | G02; current crime-source rules |
| G05 | Recognition, suspicion and disguises | Missing | G04, G06 identity/standing contract |
| G06 | Relationships, accountability and ways back | Partial | G02-G04 |
| G07 | Reusable restraint, rescue, captivity and escape | Event-specific only | G02-G04, G21 |
| G08 | Carrying, horses and transport between places | Missing | G07 for captives; region transitions |
| G09 | Ordinary life, varied social contact and optional drama | Partial | G03; existing routines |
| G10 | Crime, manipulation and live justice | Focused subset | G02-G04, G06-G07 |
| G11 | Groups, factions, cults and changing allegiances | Missing integration | G03-G04, G06, G09 |
| G12 | Collective conflict and proportionate intervention | Missing | G01-G03, G11, G20 |
| G13 | Time storms and three ages as playable encounters | Focused subset | Local G14 district + G21 lifecycle; G07/G11 only for custody/conflict extensions |
| G14 | Reusable settlements, growth and district organisation | Partial design/prototypes | Existing sites/kernel; G20-G21 |
| G15 | Three lands, their peoples and progressive liberation | Land 1 partial | Existing region travel + authored story integration; selected G14/G16 content |
| G16 | Classes, abilities, weapons, dungeons and rewarding growth | Partial adventure | G01; existing gear/skills; G18 |
| G17 | Home, useful economy, companions and longer life | Partial | Existing home/projects/quests; G09, G21 |
| G18 | Intuitive world, camera and mobile interface | Partial | Every relevant gameplay batch |
| G19 | Character, art, sound and readable consequences | Partial | Every relevant gameplay batch |
| G20 | Sustainable phone performance at useful scale | Partial, measured limits | Integrated workload, not empty benchmarks |
| G21 | Persistent state, consistent time and authoritative actions | Village subset complete | Extend existing path per new action |
| G22 | Online co-op and eventual asymmetric roles | Future, required | A stable solo slice; G20-G21; explicit network milestone |
| G23 | Reliable delivery and a repeatable development loop | Partial | Each completed batch |

## 5. Goal cards

### G01 - Deliberate, responsive phone combat and targeting

[chat/design] Preserve simple, satisfying real-time fighting. Make selecting, keeping, changing and releasing a target clear. The latest idea of two smaller ability buttons above/below the main action should be prototyped on actual touch hardware alongside attack, roll/sprint, heavy and interaction. An ordinary talk/use press must not unexpectedly assault a bystander. Allow intentional aggression without requiring a person to be pre-labelled an enemy.

[design] **First deliverable:** deliberate targeting of an adult resident or hostile, one readable hit, interruption/recovery and an unambiguous way to disengage. **Accept when:** moving targets, another nearby enemy, occlusion, death, travel and opening/closing menus never leave a stale lock or stuck finger; Free/interact remains usable; two fingers can move and act together. Later add defensive timing/parry, target cycling and ability slots through G16. Preserve positioning skill; automatic approach and gesture-only controls remain alternatives to test, not defaults to impose.

### G02 - Physical actions that create world incidents

[chat/design] A strike, shove, threat, theft, rescue or restraint should enter the world through a small shared action path even when no staged event exists. Record the actual actor, target, place, time, effect and incident identity. A landed hit must affect the persistent resident and their visible body together. Separate intentional new swings from duplicate delivery of the same swing.

[design] **First deliverable:** one spontaneous adult assault outside any hearing. **Accept when:** the right resident is injured or staggered once; they stop the conflicting activity; witnesses can react; saving immediately or leaving/reloading preserves the effect; a repeated command cannot double damage. Include meaningful injury/down/death outcomes as the combat slice expands, without making a person cease to exist because their scene unloaded. Cancelling or revising a hearing/rite when a participant becomes unavailable must remain consistent. Do not simply put every villager in the enemy group. Generated residents and authored NPCs such as Wren currently have different presentation/state paths; define an identity adapter and explicit story-role handling rather than making one population interactive while silently excluding the other.

### G03 - Immediate, individual resident decisions

[chat/design] Residents assess an interruption using what they know, their injury, danger, temperament, relationships, role and nearby support. Useful responses include startled hesitation, puzzled protest, retreat, seeking help, defending another person, retaliation, surrender and returning cautiously to work. More attacks may change the response. These need short visible transitions, not a universal aggression switch or arbitrary random twitching.

[design] **First deliverable:** the same provocation produces explainable differences in at least three controlled residents, and a bystander makes an independent choice. **Accept when:** a startled person has a believable next action; a fleeing person heads somewhere useful; an ally need not defend a wrongdoer blindly; a frightened worker does not continue harvesting during the attack; threats ending leads to a stable recovery rather than permanent panic or an immediate reset. Replan on meaningful events and bounded ticks. No per-frame general-purpose planner or runtime LLM is required.

### G04 - Witnesses, reports and bounded local knowledge

[chat/design] Distinguish seeing an act, hearing an alarm, recognising someone, receiving a report and discovering aftermath. Distance alone must not make someone behind a wall an eyewitness. A witness can be frightened, mistaken, loyal, dishonest or unable to identify the attacker. A report has an origin; several retellings are not several independent witnesses.

[design] **First deliverable:** witnessed and unseen assaults produce different local responses, with one actual report reaching another resident. **Accept when:** an unseen distant village does not instantly know; an alarm conveys danger without magically proving identity; reports preserve their source through saves; a false claim can be challenged; bounded memory still retains facts necessary for an active dispute. Reuse existing crime provenance but add live perception and delivery. Near and offscreen rules must agree about what could have been observed, without requiring every distant person to run expensive vision checks.

### G05 - Recognition, suspicion and disguises

[chat/design] Costumes, masks and regional dress can help infiltration. Recognition depends on the observer's knowledge, familiarity, sight, recent continuity and suspicious actions. Clothing is evidence of identity or affiliation, not a global replacement for identity. Swapping outfits in front of the victim must not erase what they just saw.

[design] **First deliverable:** a stranger, a close acquaintance and a recent eyewitness react differently to the same disguise. **Accept when:** changing unseen can break an uncertain identification; known face/voice/continuous pursuit can defeat it; behaving violently draws attention; taking off a disguise does not duplicate the person or erase injuries; saves preserve both known identity and suspected appearance. Resolve how armour's cosmetic visibility toggle interacts with disguise - social disguise must follow a deliberate worn configuration and cannot silently depend on a graphics preference. Full faction clearance belongs with G11/G15.

### G06 - Relationships, accountability and ways back

[chat/design] Consequences should be local, proportionate and recoverable. Distinguish immediate danger, personal memory, household opinion, faction standing and an unresolved case. Support apology, restitution, aid, release, time apart and services where those make sense. A serious enemy can remain one; one awkward encounter should not make ordinary play permanently exhausting.

[chat/design] Include the suggested rare dungeon/crypt potion that resets **specified perceptions**. Its exact scope is an open design choice: whose belief changes, what it costs, and what evidence survives must be understandable. It is not an automatic whole-world amnesty.

[design] **Accept when:** a minor incident can settle through a visible route; repeated harm escalates; witnesses disagree coherently; restitution is charged once and persists; a perception item affects only its declared targets/facts while material damage, independent evidence and unaffected witnesses remain coherent. No requirement to attend routine court sessions to keep playing.

### G07 - Reusable restraint, rescue, captivity and escape

[chat/design] Extend event-specific Free into a general lifecycle: free, threatened, subdued, restrained, escorted/carried, confined, escaping and released, with health separate from custody. The same people and rules serve raiders, authorities, captors and the player. Support the supplied example of freeing a captive, restraining the captor, and later restraining either or both through deliberate actions. Rescue does not grant permanent control or gratitude regardless of later treatment.

[design] **First deliverable:** restrain one subdued adult, move them on foot, place them in a reachable holding place and release them; then exercise a second captive. **Accept when:** captor/holder/location are unambiguous; capacity is respected; ropes/doors have real affordances; witnesses react to abduction; escape/rescue is possible; release and recapture update memory; captor death, player knock-out, region unload and immediate save/load cannot orphan or duplicate anyone. Story-role protection needs explicit feedback and a recovery policy. Horse transport and a basement are later connected deliveries under G08/G17, not implied by a cut-rope animation.

### G08 - Carrying, horses and transport between places

[chat/design] Let the player move useful cargo and, when restrained, people. Build on a shared carrier/passenger relationship with capacity, attachment, destination and a safe dismount/drop point. A horse should also be useful for ordinary travel and expeditions, not exist solely for captivity.

[design] **First deliverable:** carrying/escorting across an existing region boundary; then a rideable mount and deliberate attachment/detachment. **Accept when:** cargo and residents survive travel/save; blocked doors, tight paths, mount knock-out and falls have consistent outcomes; a passenger cannot simultaneously walk elsewhere; dropping near geometry finds reachable ground; the player can release either of two captives separately. A home basement/holding space must be physically reachable and part of G17's save lifecycle. Mount assets, animations and controls are genuine missing work; reuse suitable assets first and generate only what a selected slice needs.

### G09 - Ordinary life, varied social contact and optional drama

[chat/design] Work, food, rest, visitors, trade, small kindnesses, quarrels, mourning, repair and celebration give villagers reasons to matter between crises. Use existing roles and relationships to choose visible activities and brief interactions. Quiet should feel inhabited, not empty. Some people are helpful, some curious, some suspicious; not everyone needs a unique dialogue tree.

[design] **First deliverable:** a short ordinary visit offers useful or amusing contact without a trial, and routines respond to a local disturbance then recover. **Accept when:** players can pursue gathering/gear/home goals uninterrupted; events signal opportunities without compulsory pop-ups or attendance; several seeds and ordinary sessions show quiet stretches and different situations; a public-act frequency target does not manufacture violence to meet a quota. Retain causal pacing and population recovery. Treat the old ending-diversity check as a regression signal, not permission to override honest player-caused outcomes to fill percentages.

### G10 - Crime, manipulation and live justice

[chat/design] Finish the broader chain of actions already envisioned: theft, witnessing, accusation, intimidation, rumours, bribes, testimony, confession, appeal, rescue and aftermath. The same verbs should eventually work for players and NPCs. Authorities have limited capacity and different norms; a hearing is one possible response, not the answer to every punch.

[design] **Next deliverables, one at a time:** a player-created incident entering an actual case; a rumour deliberately told to a recipient; a real player champion duel determining a trial; custody before a public act with more than one intervention route. **Accept when:** truth and belief remain distinct; false accusations can occur without omniscience; a verdict has the correct consequence; interrupted actors do not continue an obsolete scene; nonlethal resolutions and refusing to get involved remain viable. Broader public-act catalogue entries in route r4 are backlog content, not already-working promises.

### G11 - Groups, factions, cults and changing allegiances

[chat/design] People can organise around kinship, protection, deprivation, belief, grievance, opportunity or a persuasive figure. Track membership, shared purpose, knowledge, resources, territory and internal disagreement only as far as they produce visible behaviour. Include ordinary cooperative groups as well as hostile factions and secret cults. Membership should change for reasons; a random spawn is not an emergent faction.

[design] **First deliverable:** a local imbalance or repeated grievance produces a small group with a recognisable objective; help, obstruction or changed conditions can split or dissolve it. **Accept when:** the player can identify why the group formed and what it wants through behaviour, dress, places and short cues; members differ; allegiance survives travel; recruitment cannot grow without bound; suppressing one leader does not always erase every grievance. Fictional Land 2 prejudice is a particular faction's ideology with individual variation, not a universal property of a whole people.

### G12 - Collective conflict and proportionate intervention

[chat/design] A feud, raid, cult or serious imbalance can outgrow one person and provoke an organised response from local defenders, neighbouring communities or a faction. The desired scale is felt through objectives, arrivals, territory and aftermath. “Army-like intervention” does not mandate hundreds of full combat brains fighting on one phone.

[design] **First deliverable:** two small groups contest a concrete objective, with a responding party travelling from a known source. **Accept when:** warnings and reports precede informed intervention; danger, courage and numbers affect commitment; retreat, surrender, defence and negotiation through actions can change the outcome; survivors persist; a request for help has a travel delay; the player can join, disrupt or avoid the conflict. Measure active fighters separately from spectators. Widen the scale through admitted combatants and offscreen resolution that conserves identities/outcomes, never unearned damage to nearby visible actors or invented reinforcements.

### G13 - Time storms and three ages as playable encounters

[chat/design] Bring the original idea beyond the existing rite: forecasts and world signs, a bounded district transition, its own forebears and different laws/language, a border shared with the present, and coexistence, conflict, assimilation or recession. Keep history causal. An ancestor is not just a generic enemy with an old-fashioned outfit.

[design] **First deliverable:** a clearly bounded ordinary district changes in one storm; the player can understand who arrived and choose more than fighting. **Accept when:** story anchors and player builds remain protected; architecture/props and occupants agree about the age; gestures/barter work where speech does not; both communities can pursue a disputed resource; rescue/capture/transport across the boundary has explicit persisted outcomes; recession cannot undo an accepted intervention or duplicate people. Address displaced original residents and transported ancestors explicitly. Complete tribal/village contrast before building the full town-age asset set. No prestige wipe or compulsory loss of progression.

### G14 - Reusable settlements, growth and district organisation

[chat/design] Use a reusable settlement configuration for homes, work, public space, storage, routes, refuges, entrances and surrounding resources. Give different settlements distinct culture, economy, geography and visible identity. Preserve Enea's crafted locations and style. Plot function, growth stage and historical age are useful separate dimensions; no speculative universal city generator is required.

[design] **First deliverable:** instantiate a second small ordinary settlement/district with the same behaviour contracts but a distinct layout and pressure. **Accept when:** residents know reachable homes/workplaces; crowds, mounts and clues do not occupy walls/doors; construction and damage alter what the player can use; entering/leaving retains identity and unfinished activities; the scene can be loaded within G20's measured budget. Integrate coarse world history with nearby people only when conservation of people, resources and past interventions is proven. Anchored story locations keep explicit protection rather than relying on naming conventions.

### G15 - Three lands, their peoples and progressive liberation

[chat/design] Preserve the authored game: mainland home; allied second land with internal ideological tensions and a hostile subgroup; isolated third land under the Hidden Fourth, whose near half is freed community by community and whose far half needs the peoples' strongest and guardians together. Begin ordinary, awaken the shrine and grow. Communities that are freed should visibly help, with routes, resources, allies or refuge changing.

[design] **First deliverable:** one additional meaningful mainland route/community that joins exploration, combat rewards and social consequences. Later add Land 2's arrival and one faction encounter, then one Land 3 liberation loop before scaling the map. **Accept when:** each region offers a reason to travel and an understandable route; story unlocks do not require village hearings; allies remain individually legible; liberation survives reload and changes play; the Hidden Fourth develops through places, short exchanges and events. Keep current Wren/Brakk/Morrow and quests intact. Whole-land implementation must not be a prerequisite for the first new useful area.

### G16 - Classes, abilities, weapons, dungeons and rewarding growth

[chat/design] Keep the gather/craft/grow/go-further loop moving alongside the social work. Classes and weapons are independent. Permanent earned abilities coexist with rare discoveries, relic modifiers and spells from dangerous places or illicit trade. Retain the rarity ladder through Mythic and the three story Heirlooms. More power should broaden choices, not trivialise every enemy or resident interaction.

[design] **First deliverable:** one earned ability, one discovered alternative and a clear equip/use flow on the two proposed ability controls, integrated with real combat. Then add a meaningful enemy/boss encounter and reward loop. **Accept when:** effects, costs, cooldowns and targets are readable; controller/touch state cannot double-cast; unlocks and loadouts persist; class choice does not prohibit unrelated weapons; no mandatory grind through social incidents. Include two weapon slots, defensive options and later weapon families incrementally. A light unarmed shove/punch for social interaction does not imply a full fist weapon class; older weapon preferences and the latest punching example can coexist.

### G17 - Home, useful economy, companions and longer life

[chat/design] Grow the existing home into a useful base, eventually one per land, with placement, crafting stations, food/farms, storage, residents and village projects. Money should open opportunities: projects, upgrades, useful supplies and changing rare stock. Add a special companion plus purposeful casual companions/expeditions. Preserve later light romance and festivals as backlog, not the next engineering dependency.

[design] **First deliverable:** one existing household/project need becomes something the player can help with and receives a visible practical benefit. A separate custody slice can add a reachable holding room/basement using G07, with access, escape and rescue rules. **Accept when:** interiors and region travel conserve occupants/items; helpers do not duplicate rewards or silently die while unavailable; settlements are useful beyond courts; production does not inflate infinitely; companions respond sensibly to danger and player wrongdoing. Expand fishing, farming, animals and expedition life after core loops support them. Preserve the prohibition on city-builder-style plot purchases everywhere.

### G18 - Intuitive world, camera and mobile interface

[chat/design] Organise information around what the player can perceive and do now. Landmarks, routes, posture, sounds, a short bark and a clear contextual prompt should explain most situations. Reserve fuller interfaces for inventory, abilities, map and deliberate conversations. Do not expose event IDs, simulator jargon or a screen of debugging buttons in the ordinary game.

[design] **Accept per batch:** a new player can identify the target, understand the offered action/cost, act intentionally and recognise the immediate result; warnings do not fill the screen; touch areas work with safe areas and simultaneous fingers; menus never receive their opening gesture as a second click. Prototype camera changes using existing tilted/Look/build options and preserve threat visibility, occlusion and readable interiors. Do not force eye-level camera or camera-thumb control. Map organisation and optional minimap should help exploration without turning every surprise into a checklist marker.

### G19 - Character, art, sound and readable consequences

[chat/design] Keep the stylised low-poly, atmospheric, mysterious look and Enea's character direction. Reuse models, clothes, animations and props. Make purposeful additions where existing assets cannot express a selected behaviour: a recoil, puzzled pause, raised hands, restrained pose, carrying attachment or a useful sound can communicate more than another line of UI.

[design] **Accept per batch:** the same person remains recognisable before/during/after events; materials and attachments work at the chosen detail levels; bodies do not continue contradictory work animations; injury, fear and relief have readable cues; audio provides information without relentless alarm loops. Adult stylised wounds/dismemberment is a later visual goal compatible with the recorded brief, not a prerequisite for social reaction. Measure custom rig/attachment costs before multiplying them across a crowd. Character originality and polished silhouettes matter; automated asset generation is not itself progress.

### G20 - Sustainable phone performance at useful scale

[chat/design] Retain the body optimisation. Budget the integrated game: resident decisions, active combat, navigation, animation, shadows, construction, UI, audio, particles and save work. Keep 30 fps as the default target, with the existing optional higher setting. Use distance/detail tiers and bounded active work while preserving consequences.

[run/design] Baseline: repaired S10 ordinary village ran 900 seconds with stable memory; uncapped later-frame median/p95 were 20.036/33.648 ms, including severe thermal throttling. Cold maximum was about 312 ms. Final warm 45-walker uncapped median/p95/max were 25.3/32.1/34.5 ms. Those are specific evidence, not spare budget for forty-five fighters. The Mali-G76 Compatibility MSAA workaround must remain unless new evidence justifies a change.

[design] **Accept each cost-bearing batch:** comparable before/after integrated samples on a frozen source; cold arrival/body creation included; stable memory; a sustained foreground run at a meaningful checkpoint; readable behaviour under load. Report frame distribution, worst hitches, active bodies/fighters, thermals, renderer and exact source. Separate native Android from browser results. Profile before new rendering/native-extension work; no repeated unchanged benchmarks or speculative network/rendering framework. Smaller controlled checks suffice for small changes without relevant performance impact.

### G21 - Persistent state, consistent time and authoritative actions

[design] Extend the existing village authority rather than building a parallel “combat village”. New incidents, wounds, custody, recognition, group membership and consequences need stable IDs and plain persistent state. Authoritative acceptance applies the state and cost once before presentation. Scene destruction, animation completion and the camera must not decide what happened.

[design] **Accept per new action:** duplicate input, exact-deadline input where relevant, midnight, immediate normal save/load, leaving/re-entering the region, menu/background interruption, target death/disappearance and storm recession all have defined outcomes. Validate old saves and damaged-payload recovery. Bound growing histories without discarding facts active cases need. Reuse JS/GDScript parity for social rules; do not demand that visual physics become a second JavaScript engine. Record where current combat RNG/time differs from the new contract and close that gap when the relevant feature requires it. Keep current solo closed-app freeze unless a later offline/shared-world decision explicitly changes it.

### G22 - Online co-op and eventual asymmetric roles

[chat/design] Deliver friends in one world across phone types and different networks. Later support separate Land 1/Land 2 starts, additional guardian/lieutenant players, meeting in Land 3 and optional private betrayal objectives. Cross-play is a goal; the exact hosting/backend and service budget are not chosen by this document.

[design] **First milestone, after the solo interaction/combat slice is stable:** two clients meet and fight the same enemy over different networks, with clear authority for hits, inventory and consequences. **Accept when:** joining/rejoining, delayed/duplicate commands, disconnects, host loss and version mismatch have defined behaviour; both players agree on injuries, rescue/captivity and death; private objectives are delivered only to the intended player; no unbounded catch-up freeze. Resolve shared-world pause, solo saves versus shared saves, and offline return before broad world synchronisation. Compare viable backends at that milestone using current evidence; historical pricing is not a live estimate. No network framework should block the next solo batch.

### G23 - Reliable delivery and a repeatable development loop

[chat/design] Every completed batch ends in a usable build, a coherent commit and an accurate short play route. Keep web usable for Enea and native Android useful for S10 measurements. Track actual iPhone Safari touch/safe-area/offline-reopen checks separately. Free native iPhone delivery can be investigated later without forcing Enea off web or presuming an account purchase.

[design] **Accept per batch:** source/build identity recorded; normal launch has no test arguments; tests use isolated saves and restore the ordinary app; no data clearing or unrelated package change; the report distinguishes machine checks from owner feel. Device unavailable means pending with a runnable command, not passed. Check current branches and preserve independent work. Commit locally; push only within current explicit authorisation. Never merge into Enea's `main`, message him, buy a service or change an account as an implicit completion step.

## 6. Shared design contracts

[design] These are the few coupled decisions the Opus lead owns personally. Helpers can implement bounded pieces once their inputs/outputs and invariants are fixed.

```text
player or NPC action
        |
        v
validate real target, reach, state, time and duplicate identity
        |
        v
apply persistent physical effect + cost + incident once
        |
        +--> immediate victim response and interrupted activity
        +--> actual witnesses learn what they could perceive
        +--> reports / relationships / groups change over time
        +--> save and region travel preserve this same state
        |
        v
visible body, movement, sound and cue express the accepted result
```

[design] A useful next contract separates **person identity**, **current appearance**, **physical condition**, **custody**, **current intent**, **known facts** and **social relationships**. Keep the representation small; add fields only when a selected behaviour needs them. No framework rewrite is justified just to match this vocabulary.

[design] Events interrupt routines and other events through explicit ownership/priorities: a person cannot harvest while being carried, testify while unconscious or act as both captive and captor in contradictory places. Multiple players later must use the same conflict rules. Decide tie-breaking before helpers implement competing handlers.

[design] Immediate reactions cannot wait for the next daily plan or whole village minute. Give authoritative actions enough temporal resolution for hit contact, recoil, escape and interruption, while deriving calendar deadlines and slow planning from the same progression of time. Preserve pause/background semantics. Do not introduce a second free-running presentation clock that can injure someone after the simulation says they escaped.

[design] Scale should conserve the world: unloading changes presentation detail, not whether the person was injured, who holds them, or what a witness knows. Groups do not teleport from nowhere because the player triggered a threshold. Route and travel constraints are part of the cost of intervention.

[design] Positive and negative actions should share foundations. Carrying an injured ally, escorting a willing visitor and moving a captive can reuse movement/carrier state while retaining different consent, custody and social consequences. A disguise and a false accusation both depend on uncertain identification. Helping a hungry household and a faction uprising both depend on local needs and resources. Choose batches that exploit these connections.

## 7. Work in related, playable batches

[design] The lead selects **two to four related goal slices**, one central player experience and a finite acceptance set. Cross-cutting persistence, performance and mobile usability remain gates, not excuses to expand every batch. The table is a proposed route; re-order it for dependencies, Enea's parallel work and actual owner feedback. Finish one integrated outcome before opening another large branch of work.

| Batch | Goal slices | Concrete experience to deliver |
|---|---|---|
| B1 - Provoke a person | G01 minimal intentional target, G02 assault, G03 response, G04 nearby witness | Hit an adult outside an event; see varied immediate reaction and one locally informed bystander; leave/save/return to the correct aftermath. This is the recommended first batch. |
| B2 - Strengthen the adventure | G01 defence/lock, G16 ability/reward loop, G18 touch layout, G19 cues | One satisfying fight with an earned/discovered ability and useful loot; no requirement to engage with village drama. Advance this immediately after B1 so the main adventure improves alongside social agency. |
| B3 - Be recognised and recover | G04 report, G05 disguise, G06 consequences | A witness recognises you, another is uncertain, a disguise helps only where plausible, and one real route repairs a minor offence. Potion scope is designed here; acquisition can use B2/G16. |
| B4 - Make captivity physical | G02 subdue, G07 custody, G08 on-foot transport, G17 one holding space | Free, restrain, move, confine and release real residents, including the former captor; two captives, escape and interruption are checked. |
| B5 - Give daily life substance | G09 useful ordinary encounters, G10 player-caused case/rumour, G17 household/project help | Help or disrupt a household, see a small change in its life and reputation, and encounter an optional consequence later. |
| B6 - Let people organise | G03 group choices, G11 formation, G12 one response, G20 integrated conflict budget | A local grievance forms a group, a defending party arrives from somewhere real, and the player can alter or avoid the conflict. |
| B7 - Give storms a place | G13 local transition, G14 second district, G18 readable boundary, G19 age cues | A forebear district visibly changes the world and offers coexistence or conflict beyond a single rite. |
| B8 - Travel with consequences | G08 horse, G07 transported custody, G17 home destination, G15 one route | Ride a useful route, transport cargo/two captives, arrive at a reachable holding place and handle escape or pursuit. |
| B9 - Expand authored progression | G15 one community/land step, G16 dungeon/relic, G14 reusable settlement, G17 companion | An expedition unlocks a meaningful place and ally, advancing the three-land story without replacing it with social management. |
| B10 - Play together | G22 two-client online slice, G21 authority reconciliation, G23 cross-platform delivery | Two people fight/intervene together and agree on outcomes after reconnecting. Expand roles/lands only after that works. |

[design] **B1 launch contract:** use a neutral adult, a timid adult, an assertive adult and a nearby witness in controlled fixtures, plus ordinary play. Cover first hit, repeated genuine hit, duplicated same hit, unseen hit, intervention during an existing event, target disappearance, save immediately and travel away/back. Start with a readable nonlethal reaction and explicit escalation rules; do not silently turn all combat into nonlethal play. Reuse present combat effects and body animation where possible. The lead personally owns target/incident/reaction consistency; helpers may handle bounded animation/UI integration and the independent scenario runner.

[design] **First broader checkpoint after B1-B4:** the player can fight deliberately, provoke and understand a resident response, be recognised or plausibly disguise themselves, recover from a minor dispute, and move/release a captive. Existing gathering/crafting/quest play remains useful. This is a foundation for a natural village, not a requirement to finish every goal before another playable delivery.

[design] **Coverage guard:** after every two completed batches, review the whole goal index. If village work is advancing while combat, exploration or usability remain stalled, select the next connected adventure improvement or record the real dependency. Do not indefinitely polish hearings because they are easiest to test. Do not use a fixed throughput quota or deadline to declare incomplete behaviour done.

## 8. Opus lead / Sonnet helper operating brief

[chat/design] This is a future Claude implementation workflow. This documentation task does not launch Opus/Sonnet sessions or create recurring automation. An active run can continue across selected batches while authorised; unattended scheduled continuation needs its own explicit setup. The historical overnight push grant is not blanket publication authority for future runs.

### At the beginning of each run

1. [repo/design] Read local instructions and their required session documents. On the first run, read this master and its controlling owner sources fully. On subsequent cycles, check changed intent, the latest ledger entry, selected goal cards and relevant code instead of repeatedly researching the whole project. Fetch and inspect current `studio`/`main` before overlapping work. Inspect status/worktrees; preserve uncommitted files and unmerged valuable commits. Do not assume this document's hash is still current.
2. [design] Select one batch or a similarly coherent set of two to four goal slices. Write the precise player outcome, exclusions, base commit, owned files, contracts and finite checks in the cycle ledger **before implementation**, briefly. This is a working record, not another architecture essay.
3. [design] Choose the smallest implementation that actually makes that loop work in normal play. Prove one end-to-end path early, including save and scene return. Then broaden its cases. A test-only entry point or animation demonstration does not close the goal.

### Who does what

| Role | Responsibility |
|---|---|
| Opus lead | [chat/design] Own intent, causal design, shared state/action contracts, difficult interactions, integration and final acceptance. Personally implement coupled decisions; do not become only a reviewer or delegator. Inspect helper outputs and play the integrated result. |
| Sonnet helper A | [design] One bounded independent implementation task once contracts are fixed: a touch-control component, an existing animation adapter, a mechanical JS/GD port, a limited content/configuration task. |
| Sonnet helper B | [design] Independent finite scenarios, broad sweeps at a stable checkpoint, device measurements/evidence, or a second disjoint implementation task. It can review causality at boundaries without editing the lead's files. |

[chat/design] **Maximum two helpers concurrently. Select Sonnet explicitly.** Record the exact configured model identifier and verify launch metadata; disclose if the provider exposes no independent backend identifier. If the requested model is unavailable, do not silently drop the model field or fall back to a more expensive default. Continue useful lead work and report the constraint. The previous Claude night did fall back after a failed model launch; this workflow must not repeat that behaviour.

[design] Every helper brief includes: exact base SHA; branch/workspace; file ownership; agreed data/behaviour contract; finite examples; required tests and artifact paths; prohibited overlapping edits; required return format (commit, files, observed results, failures, unresolved questions). A helper should not push, merge into `main`, message Enea, alter accounts or generate broad new assets. Reuse suitable worktrees; never casually clean old work. No helper spawns additional helpers beyond the shared two-person limit.

### During and after a batch

1. [design] Do cheap causal checks while implementing. Check a saved state immediately after the player action, not only at the end of an animation. Test a natural input route as well as a direct simulation call.
2. [design] Integrate helpers against the agreed base; review semantics, not merely clean merges. Reconcile Enea's new work with deliberate small merges or adaptations. Preserve history and source/build provenance.
3. [design] Run the required engine/parity/input checks for changed behaviour. Delegate expensive sweeps only after rules stabilise. Measure actual changed rendering/behaviour workloads on device at stable checkpoints. Do not retest an unchanged build repeatedly or use an emulator for phone performance claims.
4. [design] Inspect a small set of useful in-game evidence. Then repair found gaps. A screenshot proves presentation at that moment, not a causal chain, save reliability or ordinary event frequency.
5. [design] Commit reviewable milestones and produce the normal launchable build. Record what the player can now do, where to find it, how long it naturally takes, evidence paths and material limitations. Mark engineering and owner-feel states separately.
6. [design] Update the cycle ledger and affected goal statuses. If another authorised batch is ready, continue with a fresh bounded selection. At quota/context exhaustion, leave a runnable handoff with current branch, dirty files, active processes, next exact action and unresolved failures. Do not mark the goal done merely to end the run.

[design] When a device, credentials or owner feel decision is unavailable, finish independent engineering and write the exact remaining check. Do not convert an unavailable test into a pass or leave unrelated closable gaps open. Ask the owner for intent, platform access or truly external authority; do not make the owner hunt file paths, hashes or routine bugs.

### What counts as complete

[design] Track each goal as **not started / foundation / partial / engineering verified / owner reviewed**, plus **blocked** with the exact external dependency if needed. A goal advances to engineering verified only for its stated scope when all of these apply:

- The player can reach it through the ordinary build and controls.
- Visible reactions and persistent effects agree at the time of action.
- Necessary hostile/failure/duplicate/save/travel/time boundaries pass.
- Existing relevant adventure flows still work.
- Performance is measured where the change warrants it, with cold/sustained limits disclosed.
- Source/build/evidence/commit are recorded and another agent can reproduce the result.

[design] Owner-reviewed means actual Hilmi/Enea feedback, quoted or accurately attributed; it cannot be inferred from a simulation, a screenshot or a passing benchmark. A completed narrow slice never means every feature in its parent goal is complete.

### Launch brief for the next Opus lead

[design] The following is a reusable brief; using this document alone does not start a new agent or grant publication authority:

> Continue Unbound on the studio side using `docs/studio/MASTER-GOALS.md`. Read its intent, current baseline and source corrections, inspect applicable instructions and current branches, then select two to four related goal slices that produce one playable outcome. The recommended first batch is B1: deliberate provocation of a resident, an individual immediate response and a locally informed witness, with persistence through save and travel. Record your bounded selection in the ledger and implement it through integration and verification. Personally own the coupled action, timing, identity and decision logic. Use at most two explicitly selected Sonnet helpers with exact base commits, file ownership, finite scenarios and required outputs; verify the model selection and never silently fall back. Reuse the existing bodies, rules, combat and assets. Deliver a normal playable build, reviewable commits, actual evidence and a short player test route; close engineering gaps before asking for feel feedback. Keep the adventure progressing alongside the social systems. Preserve Enea's parallel work, check current publication authority, and do not merge into main or message Enea without authorisation. If your selected batch is complete and continued local work is authorised, select the next related batch rather than beginning an unbounded rewrite.

## 9. Living completion ledger and open choices

### Baseline and selected work

| Entry | Goals / scope | State | Evidence / next action |
|---|---|---|---|
| Recovered night and focused continuation | Existing hearing/rescue/rite, residents, persistence and device repair | [repo/run] Engineering complete for V1-V14; owner feel pending; published through `535fd40` | [Continuation ledger](CONTINUATION.md), [night report](NIGHT-1.md), [device packet](evidence/continuation/s10-final/FINAL-RESULTS.md). Older local-only publication statements there are historical; the push was later authorised and verified. |
| Master goals reconciliation | Whole vision, source conflicts, missing gameplay and execution order | [repo/chat/design] This document | Based on S0-S9; no new gameplay implied. |
| Next proposed batch | B1: G01/G02/G03/G04 narrow slices | [design] Selected 30 Sep (record below); not started | Main 0709565 merged locally as df6f214 with all checks passing; implement the strike action and one reaction end to end. |

#### B1 - Provoke a person (selected 30 Sep 2026, not started)

```text
Batch / date / lead and exact helper selections: B1 / 30 Sep 2026 / Claude (claude-opus-5-5) as lead; no helpers (Hilmi, 30 Sep: "Without subagents now")
Goal IDs and the bounded player outcome: G01 (intent only), G02, G03, G04 (one witness chain). Outside any event, the player squares up to an adult resident on purpose and strikes them. That person reacts in their own way (puzzled, protesting, fleeing, calling for help or hitting back; more blows change the answer). A nearby resident who could actually see it decides for themselves (step in, raise the alarm, back away, look away). One of them carries a report with its origin to the elder. Saving at once, or leaving and coming back, keeps the bruise, the fear and the report.
Source base, inspected main head, branch and file ownership: studio df6f214 (merge of main 0709565 into 17c1f06/b16438c); nested game repo, branch studio. Owned: scripts/studio/village/sim/{runtime,state,save}.gd plus a new sim/provoke.gd, scripts/studio/village/{residents,live}.gd, tools-src/studio/village-reference/ (the JS twin of the decision rules). Enea's files: only small marked hooks in player/fighter.gd and player/player.gd.
Contracts the lead owns: (1) intent - an ordinary tap never assaults: a deliberate square-up (proposed: hold the action button near an adult resident) selects the target, and the lock releases on distance, menu, travel, the target's absence or a second hold; children and story characters cannot be selected (story characters answer with a visible refusal); (2) one authoritative "strike" action through runtime.act (actor, target, place, minute, swing id): the injury and the incident are applied once, a repeated delivery of the same swing is a no-op; (3) the reaction decision is a pure keyed function of the target's traits, injury, standing towards the stranger, kin and nearby support, with a JS twin and shared fixtures; (4) perception is distance plus the existing obstacle blocks (no eyewitness through a wall); an alarm carries danger, not identity; a report keeps its origin.
Status: selected; not started
Commits and normal build identity / launch route: (to fill)
Acceptance scenarios and actual results / evidence paths: controlled fixtures - a neutral, a timid and an assertive adult plus one witness: first hit, repeated real hit, duplicated same hit, an unseen hit, a hit during an existing event, the target disappearing, immediate save/load, travel away and back; plus ordinary play. (to fill)
Performance scope, device and limits: reactions are event-driven (no per-frame planner); one short S10 sample of a provoked crowd at a stable checkpoint.
Owner feedback (only if received): none yet. The square-up control is shown to the owner before any wider change to combat.
Remaining gap, next exact action and publication authority/status: next - implement the strike action and one reaction end to end, with save and travel. Local commits only; df6f214 and later are unpushed; no main merge or outward message.
```

[design] Add each implementation batch as a new entry using this compact record; preserve failed results and corrections rather than rewriting them as successes:

```text
Batch / date / lead and exact helper selections:
Goal IDs and the bounded player outcome:
Source base, inspected main head, branch and file ownership:
Contracts the lead owns; exact helper tasks:
Status: foundation | partial | engineering verified | owner reviewed | blocked
Commits and normal build identity / launch route:
Acceptance scenarios and actual results / evidence paths:
Performance scope, device and limits (or why no new benchmark was warranted):
Owner feedback (only if received):
Remaining gap, next exact action and publication authority/status:
```

### Choices to settle when their batch makes them concrete

| Choice | Working direction, without blocking independent work |
|---|---|
| Deliberate civilian targeting | [design] Prototype explicit target/intent selection that still fits the phone. Show the actual control to the owner before replacing the whole combat scheme. |
| Ability buttons versus gestures | [chat/design] Start from the latest two-side-button idea. Test conflicts with attack/heavy/roll/interact; no unseen gesture replacement. |
| Serious injury, story characters and captivity | [design] Define knock-out/death/capture recovery and quest safety per role. Keep children protected in the next implementation. Do not leave invulnerability or quest failure inexplicable. |
| Recognition and perception potion | [design] Prefer observer-specific uncertainty and a limited, communicated effect. Decide duration/targets/scarcity when a real disguise/recovery loop is playable. |
| Normal event cadence | [design] Tune from ordinary sessions where the player pursues their own goals. No hearing attendance quota; severe events rare enough to matter. |
| Group scale | [design] Start with small, causal groups and measured active fighters. Choose wider numbers from integrated measurements, not a 45-walker benchmark. |
| Camera feel | [chat/design] Tilted everyday framing is the studio starting point; Enea's confirmation remains open. Prototype with actual fights/interiors and useful low-view vistas. |
| Online/offline time | [design] Preserve current solo pause semantics now. Decide shared-world time and absence rules before G22 persistence/synchronisation work. |
| Land 2 faction details / Land 3 access | [chat/design] Preserve allied peoples, hostile subgroup and incremental liberation; names, ideology, route and exact story beats belong with Enea's authored content. |
| Publication and continuation authority | [chat/repo] `studio` push through `535fd40` was authorised in this chat. This document creates no unrestricted future push/main merge authority. Record any new scoped grant in a cycle entry. |

## 10. Source register and intent excerpts

[repo/chat] Local transcript paths below are provenance for local agents; a cloud agent can read the repository sources and the attributed excerpts here. Do not upload the entire private Claude transcript merely to make this document usable. The excerpts are selected for this game and do not carry forward old operational instructions as new grants.

| ID | Source | How it was used |
|---|---|---|
| S0 | Hilmi's current Codex conversation, `01a0ed3d-ee0f-76b3-a3f1-9f4b446db160`, request for this master and supplied Hilmi/Enea exchange | [chat] Latest intent: optional drama, natural physical agency, groups/conflict, land identities, controls, disguises, perception items, optimisation and Opus/Sonnet workflow. Individual pasted speakers are unlabelled. |
| S1 | Claude **Project handover and review**, session `65e25e70-4b05-4f5c-b52e-6dde2079ec36`; local transcript `C:/Users/hilmi/.claude/projects/C--Users-hilmi-Downloads-Unbound-Studio/65e25e70-4b05-4f5c-b52e-6dde2079ec36.jsonl` | [repo/chat] Read original design exchanges and lead responses, including lines 523, 749, 3111, 3116, 3187, 3189, 3253, 3262, 3339, 3374, 3396, 3660, 3664, 3894, 3898 and 5558. Responses identify `claude-opus-5-5`; this is historical metadata, not a prescribed future model ID. |
| S2 | [DESIGN.md](../DESIGN.md), especially Pillars, Story, Sessions, Multiplayer and owner Q&A | [repo/chat] Authored game identity, three-land story, short sessions, exclusions and ordinary-villager start. |
| S3 | [GAME_PLAN.md](../GAME_PLAN.md) | [repo/chat] Owner-decided progression, regions, classes, rarity, bases, companions and build order. |
| S4 | [FROM-ENEA.md](FROM-ENEA.md) | [repo/chat] Later Enea answers: living world grows out of existing game, web now, native free later, cross-play required. This file is a Claude-written record with owner quotes, not a raw full owner transcript. |
| S5 | [ROUTE-r4.md](ROUTE-r4.md) | [repo/design/chat] Reconciled original Opus direction, three ages, language, manipulation, content discussion and later co-op. Its native-only and earlier scope assumptions are corrected in section 2 here. |
| S6 | [VILLAGE-PLAN.md](VILLAGE-PLAN.md) | [repo/design] Motives, roles, bounded memory, local knowledge, crowd thresholds, pacing, detail tiers and tradeoffs. Its benchmarks/proposals are historical, not current integrated evidence. |
| S7 | [Owner ideas AI summary](inputs/2026-09-29-owner-ideas-ai-summary.md) | [repo] Explicitly derived, lower authority. Useful idea inventory; exact gesture/camera/native choices are not treated as ratified. |
| S8 | [NIGHT-1.md](NIGHT-1.md), [CONTINUATION.md](CONTINUATION.md), [witness board](evidence/witness/CONTINUATION.md) and [final S10 results](evidence/continuation/s10-final/FINAL-RESULTS.md) | [repo/run] Actual implementation, V1-V14 coverage, natural first-hearing observation, preserved failures, costs and limitations. |
| S9 | [PLAN.md](../PLAN.md), [SYSTEMS.md](../SYSTEMS.md), current source and fresh Git inspection | [repo] Development constraints and concrete code. Current `origin/main` drift is recorded in section 3. No expensive tests were rerun for this document. |

### Original words that anchor the programme

[chat] Hilmi, S1 line 523, 28 Sep 20:36 UTC: "civilisations can grow over time, illicit behvaiours you may expect but not expect in a game and interact with other civilisations, with time storms also shaking things up by converting either certain villages or even parts of villages into a different time and potentially even make it turn on the village it was once part of, all of this while the player also has its own things to do and own ways to interact with people."

[chat] Hilmi, S1 line 3374, 29 Sep 02:46 UTC: "staging things sounds annoying, again it is low polly so the detail doesn't need to be amazing but it has to add detail to the game, even adds possibility for saving people during the process."

[chat] Hilmi, S1 line 3898, 29 Sep 03:52 UTC: "full freedom to change the map how you would like (or you can make it a specific type that can be reused through the map, this may be more intelligent), full freedom for creativity with the characters and behaviours, freedom to add what you want to these characters and even freedom to develop how the player may interact with these npc's. Keep in mind optimisation is important."

[repo/design] Opus's response at S1 line 3187 is the aligned interpretation worth preserving: a third-person adventure for friends, played from the ground; autonomous villages and ancestor storms; occasional manipulation; visible acts and short lines; stable authored story settlements. The same response explicitly dropped its earlier god-view ladder and broad conversational AI. Its proposed early multiplayer spike was subsequently deferred by Hilmi at line 3262. Its later night commitment at line 3894 was a finite witness/rules/crowd milestone, not the complete ambition.

[chat] Supplied current Hilmi/Enea exchange, S0, speaker labels unavailable:

> "it shouldn’t make the game too focused on this"
>
> "could be cold for big scale conflicts or genuine imbalances to the people where they retaliate or maybe factions/cults whatever can form"
>
> "free the guy from the hostage taker or whatever, and just kidnap both tie them to ur horse take them to ur house basement"
>
> "even the fact the 3rd land has to be unlocked bit by bit was gonna be different communities"
>
> "internal decision models for the villagers so they dont just roboticslly fight back every time (would be cool to see there bro just puzzled he just got punched)"
>
> "costumes/disguises otherwise the way ppl would remember you would get annoying, maybe secret potions around thr world in dungeons that resets certain perceptions of you"

[design] These are connected goals: freedom to act, people who interpret it, consequences that travel through the world, and ways to keep having fun afterwards. Every new batch should make one part of that chain tangible while protecting the adventure around it.

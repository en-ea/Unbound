---
title: "Owner ideas, 29 Sep 2026 - an AI summary Hilmi supplied, with his own notes"
created: 2026-09-29
type: input
voice: derived (an AI's summary of Hilmi's and Enea's messages; not their own words)
author: supplied by Hilmi in chat; summarised by an unnamed AI outside this studio
status: input; acted on in docs/studio/ROUTE-r4.md
next_step: acted on in ROUTE-r4.md; its section 9 holds the questions still open
---

# Owner ideas, 29 Sep: an AI summary, as supplied

**Provenance.** Hilmi pasted this into the studio chat on 29 Sep 2026 with the words "I got an ai to summarise some of the ideas we covered in messages". It is a **derived record**: another AI's summary of messages between Hilmi and Enea. It is not their own wording. Where it conflicts with their own words, their words win.

## Hilmi's own words in the same messages `[chat]`

- "I think enea is forced to accept these things at this point, he won't be spending any money, we don't think different camera angles for fighting is necessary unless its some simple zoom in but even then its specific cases and the only time it may change is when inside somewhere or interacting with an npc possibly."
- After the summary: "(on that last point though, we can somewhat have that but it most not be a main component of the game like it is in crusador kings, its more so a fun component to see how we can manipulate behaviour and stage events) (also certain villages would probably not suffer the randomness and 'timenados' and instead serve as story checkpoints)."
- "This probably raises a lot of questions and changes previous assumptions you had on the game, take the time to think about this now"
- "I do have a domain (dltreasures) that I wouldnt mind paying £5 a month for more calls for"
- "but there are many options, dont narrow yourself too early on"

## The summary (verbatim, as pasted; its SVG sketch is omitted)

The summary's own titles and bullets are kept below. The embedded SVG of a "Touch Combat Gesture Cluster" is omitted. It showed an attack ring: hold for auto-lock and approach, drag down to parry or counter, drag up for a special.

### Mobile Input & Combat Mechanics Engine
The combat design replaces standard floating virtual buttons with a contextual gesture cluster. This system solves mobile ergonomics by merging directional targeting, primary melee engagement, and defensive reactions into a continuous single-thumb input stream.
- **Continuous Contact Targeting:** Holding the primary action button initiates a kinematic lock-on to the nearest prioritized hostile within a forward 120-degree cone. The player character maintains facing direction and closes distance autonomously, converting directional tracking into a predictable baseline variable.
- **Drag-to-Defend Transition:** Sliding the active thumb downward into the defensive quadrant without breaking screen contact interrupts basic attack animations with a parry or directional guard window.
- **Modifier Slide (Ranged & Magic):** When a ranged weapon (such as a composite bow) is equipped, initiating the draw locks onto target centers. Sliding upward into the ability node primes specialized ammunition (e.g., ignition arrows) before release.
- **Dual-Tier Skill Progression:** Combat abilities are partitioned into foundational, permanent upgrades unlocked through a personal skill matrix, and situational active spells acquired through high-risk black-market barter or hidden crypt exploration.

### Inventory Architecture & Ergonomics
To prevent HUD clutter and avoid pausing gameplay on mobile viewports, item management relies on quick-toggle slots, automated triage routines, and radial overlays.

| Control Surface | Physical Input | Engine Response | Design Objective |
|---|---|---|---|
| Loadout Switcher | Single Tap | Instantly swaps Slot 1 (Melee primary) and Slot 2 (Ranged/Heavy secondary). | Maintains rapid tactical adaptability without sub-menus. |
| Auto-Triage Backpack | Single Tap | Queries inventory arrays and consumes the lowest-tier restorative item. | Eliminates micro-management and menu friction mid-engagement. |
| Radial Arsenal | Hold & Drag | Presents an 8-way directional wheel for utility items, traps, and disguises. | Enables contextual item deployment within sub-300ms reaction windows. |
| Target Reticle | Double Tap | Cycles priority targets (Commanders, spellcasters, siege engines). | Allows deterministic tactical prioritization in dense mobs. |

### Camera Dynamics & Environmental Horizons
The current fixed perspective is replaced with an over-the-shoulder third-person camera configured for scale appreciation and long-distance navigation.
- **Sightline Anchoring:** The vertical camera pitch is pitched upward to maintain a visible horizon line across open waters, rendering the silhouettes of Lands 2 and 3 visible from shoreline vantage points to establish environmental scale and progression goals.
- **Combat Auto-Framing:** Upon entering engagement states, the camera transitions dynamically along an orbit curve, tracking the midway vector between the player entity and the locked target while subtly zooming to highlight attack startup frames and parry cues.
- **Occlusion Culling:** Building walls, foliage canopies, and dense geometry dynamically transition to dithered transparencies when intersecting the line of sight between the camera rig and the player character.

### Autonomous Settlement Simulation & World Anomalies
Rather than relying on macro-scale management simulation, settlement dynamics operate at ground level, driven by autonomous non-player character (NPC) behavior trees.
- **Emergent Adjudication Systems:** Villages evaluate civilian crimes and internal faction friction autonomously. Severe transgressions trigger automated civilian gatherings, judicial proceedings, and public gallows executions at central village nodes without player predetermination.
- **Temporal Distortion Events:** Catastrophic environmental anomalies occur at calculated intervals. These events apply temporal regression waves across specific geographic zones, shifting architectural states and NPC behavioral sets back to primitive eras (e.g., tribal stone-age survival routines) while keeping the player character's physical stats, weapons, and inventory entirely intact.
- **Linguistically Isolated Factions:** Distant regional settlements employ asymmetric communication models. Uncontacted or primitive tribes cannot be negotiated with using standard dialog trees; interaction is limited to acoustic markers, aggressive territorial defense with ranged spears, or ritualistic barter.

### Multiplayer Progression & Asymmetric Traitor Pipeline
The campaign structure uses regional divergence to set up cooperative play that eventually allows for covert opposition.
- **Initial Regional Segregation:** Player 1 begins in Land 1; Player 2 begins in Land 2. Each protagonist acts as their region's designated Champion, starting with culturally distinct regional gear and relic weapons. Early progression requires both players to pacify their domestic territories before unlocking seafaring routes to converge on Land 3.
- **Subordinate Cohort Roles:** Secondary connections (Players 3 and 4) join as lieutenants embedded within the hierarchy of either starting Champion, functioning as operational support units during faction expansion.
- **Covert Subversion Directives:** During key narrative transitions in the shared endgame zone, secondary clients receive asynchronous, private objectives routed strictly to their UI. These directives task the player with covert subversion - such as triggering settlement alarms, poisoning shared supply reserves, or assassinating a regional leader - introducing dynamic social tension within standard cooperative sessions.
- **Disguise Mechanics:** Armor functions simultaneously as defensive protection and faction clearance. Equipping full regional sets allows players to bypass sentry perimeters and infiltrate hostile enclaves without provoking immediate combat.

### Technical Pipeline & Mobile Optimization
To avoid the architectural boundaries and memory ceilings encountered during preliminary browser testing, the development workflow shifts entirely to native compilation.
- **Native Engine Deployment:** Transitioning from Godot Web (WebGL) to native mobile builds eliminates browser canvas memory limits, multi-touch event latency, and thread contention, allowing full access to hardware Vulkan/Mobile rendering backends.
- **iOS Sideloading Architecture:** Testing without paid Apple Developer Program credentials requires establishing an automated local re-signing pipeline (via tools such as SideStore or AltStore). This maintains local provisioning entitlements within the free 7-day certificate window.
- **Hardware Tiering & Simulation:** Development relies on desktop Android emulation environments (using dedicated Vulkan-compatible virtual device instances) to run high-framerate entity simulation tests and profiling passes without degrading physical device batteries.
- **On-Device Entity Processing:** Complex cloud neural network calls are discarded in favor of deterministic, local Finite State Machines coupled with lightweight, pre-trained local evaluation models for autonomous NPC dialog and emergent conflict generation.

### The Passive Narrative & Exposition Trap
- **No Endless Dialogue Trees:** Characters will not deliver paragraphs of world history through branching text boxes. Interactions are rapid, functional, and environmental.
- **Show, Don't Read:** Story progression relies on physical landmarks, dynamic visual set-pieces, and emergent player actions rather than visual novel-style narrative delivery.
- **No Artificial Diplomatic Minigames:** Hostile or isolated factions communicate through aggression, acoustics, and bartered resources - not translated persuasion menus.

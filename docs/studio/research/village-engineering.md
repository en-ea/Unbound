---
title: "Research - crowd, AI and simulation performance for a living village on the Galaxy S10 (Godot 4.7)"
created: 2026-09-29
type: research
voice: agent research (a research subagent, 29 Sep 2026); recorded in substance, lightly condensed
author: research agent, commissioned by Claude (claude-opus-5-5), lead agent in Hilmi's studio
status: evidence for docs/studio/VILLAGE-PLAN.md (section 9); its estimates are labelled and several were since measured (docs/studio/evidence/s3/)
next_step: none of its own; the village plan acts on it
---

# Crowd, AI and simulation performance on the S10

**Verdict** (the agent's): the plan fits on the S10 if the main thread only presents the villagers, and everything costly per villager goes to the worker thread, to precomputation or to the GPU. The biggest risks:
- skeletal animation: CPU-heavy in Godot 4, on the main thread, with no built-in animation or bone level of detail;
- navmesh queries: on the main thread by default, not time-sliced, cost growing with polygons;
- float determinism across x86 and ARM.

Stay in typed GDScript; move to GDExtension only for measured hot loops, through coarse calls.

**Budget:** at 30 fps, 33.3 ms per frame. Scripts already peak near 20 ms on the S10, so villagers get about 5 ms of main-thread time. One GDScript call on the S10 is about 0.48 µs (0.23 µs × 2.1).

## 1. Navigation

**Evidence** `[web]`:
- Path query cost depends on navmesh polygons and edges, not world size. Unreachable targets search everything. Re-path in staggered groups: https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html
- On a 10,000+ polygon navmesh, `GetNextPathPosition` took 1.7-2.0 ms each (desktop), and 200 queries caused a 0.5 s hitch. The navigation maintainer confirmed that queries run on the main thread by default, with no built-in time-slicing: https://github.com/godotengine/godot/issues/105648
- Since 4.4, 4 query slots per map allow parallel queries: https://github.com/godotengine/godot/pull/100129. Since 4.5, `path_search_max_polygons` caps the worst case: https://github.com/godotengine/godot/pull/102767
- The NavigationServer is thread-safe; AStar2D, AStar3D and AStarGrid2D are not: https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html
- ORCA (RVO): 5,000 agents in 8 ms on 8 Xeon cores, about 13 µs per agent per core: https://gamma.cs.unc.edu/ORCA/publications/ORCA.pdf. Godot warns avoidance with many agents is costly: https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_agent_avoidance.html
- A pause bug added every agent to avoidance (fixed for 4.8): https://github.com/godotengine/godot/pull/120249
- 500 agents each calling AStarGrid2D per frame took 670 ms per frame, against 2 ms with one shared field (a vendor benchmark): https://github.com/Vav-Labs/godot-crowd-pathfinding-benchmark
- Hitman precomputed a "panic flow" per exit: https://media.gdcvault.com/gdc2012/slides/Programming%20Track/Fauerby_Kasper_CrowdsInHitman.pdf. Fieldrunners 2 moved thousands of units on mobile with shared flow fields: https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter24_Efficient_Crowd_Simulation_for_Mobile_Games.pdf

**Recommendation** `[design]`:
- No NavigationAgent3D per villager. Cache paths between about 40 points of interest (about 1,560 paths), built on the worker at load.
- Ad-hoc routes: `NavigationServer3D.query_path` on the worker, a navmesh under about 1,000 polygons, `path_search_max_polygons` set, about 2 requests per frame.
- Gatherings: a flow field per venue (square, gallows, church, gates), about 4 KB each at 64×64; ring slots around the focal point, assigned by id; staggered arrivals.
- Avoidance: separation steering on a spatial hash; RVO only near the camera (`max_neighbors` about 5).
- Tradeoffs: flow fields assume static geometry (rebake if a gate closes); separation is less exact than ORCA in tight crowds, but deterministic and cheap.

## 2. Animated characters

**Evidence** `[web]`:
- 2,400 AnimationPlayer plus AnimationTree instances with trivial tracks took 11 ms on an M2 and about 30 ms on a Ryzen 3600 (6.2 ms in Godot 3.6): about 5-12 µs per instance before any bones. Profiling pointed at AnimationTree; a reporter says 4.7-dev is "much closer to 3.6"; a further 70% speed-up PR is open: https://github.com/godotengine/godot/issues/101494
- 2,000 skeletons took about 30 ms of CPU, about 13.5 µs each on an i3-10105F: https://github.com/godotengine/godot/issues/93568. A moving hidden skeleton still costs CPU: https://github.com/godotengine/godot/issues/108997
- Threaded skeleton processing (https://github.com/godotengine/godot-proposals/issues/11814) and animation LOD (https://github.com/godotengine/godot/pull/111730) are unmerged. The workaround now: `callback_mode_process = MANUAL` plus `advance(delta)` at a rate chosen per distance: https://docs.godotengine.org/en/stable/classes/class_animationmixer.html
- The Compatibility renderer skins on the GPU with transform feedback, once per frame: https://github.com/godotengine/godot-proposals/issues/3959
- Assassin's Creed Unity: full NPCs within 12 m (at most 40); puppets from 12 to 40 m; an instanced low-resolution crowd beyond. CPU per member: about 150 µs per puppet, about 25 µs low-res: https://archive.org/details/GDC2015Cournoyer
- Hitman: Absolution: 1,200 agents, 500 on screen; about 2 ms of animation on the main core plus about 20 ms spread over the SPUs.
- Vertex-animation-texture MultiMesh plugins:
  - antzGames: all renderers, under 8,192 vertices, uses `custom_data` and `instance_color`: https://github.com/antzGames/Godot_Vertex_Animation_Textures_Plugin
  - shadecoredev: tens of thousands of instances in one draw call; first surface only; no per-instance LOD: https://github.com/shadecoredev/AnimatedMultimeshInstance3D
  - Octahedral impostors are for static meshes only: https://github.com/zhangjt93/godot-imposter

**Our case** `[repo]`: the character code drives AnimationPlayer directly, with no AnimationTree (`game/scripts/player/character_visual.gd`).

**Estimate:** 40-100 µs per 65-bone character. **Measured since:** about 200 µs per villager on the S10 at full rate (S3, the frozen-animation variant).

**Recommendation** `[design]`:
- Full rate for the ~12 nearest; 10-15 Hz from 15 to 40 m by manual `advance`; an instanced crowd for the rest.
- Mixers and skeletons off explicitly when off-screen.
- **A baked bone-matrix texture** (every Quaternius character shares the UAL skeleton): about 0.37 MB for 65 bones × 120 frames, against about 7.7 MB for per-vertex VAT on a 4,000-vertex mesh. A custom shader, about 1-2 days of work.
- For distant bodies, a copy of the animations with the finger tracks stripped.

**Draw calls:** the agent estimated 2-4 per skinned character. **We measured about 40 on Enea's characters**, from the multi-part outfits (S3).

## 3. Level-of-detail AI and scheduling

**Evidence** `[web]`:
- STALKER: agents within about 150 m are online; the rest run offline on a coarse graph spanning levels: http://aigamedev.com/open/interviews/stalker-alife/
- Kingdom Come: Deliverance II: about 2,400 NPCs, half in one city. AI LOD was added "while keeping the scripting interface as unaware of the LODs as possible": https://schedule.gdconf.com/session/supporting-thousands-of-npcs-in-kingdom-come-deliverance-kingdom-come-deliverance-ii/915120
- LOD Trader: 57 µs per frame to manage AI LOD: http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter14_Phenomenal_AI_Level-of-Detail_Control_with_the_LOD_Trader.pdf
- Hitman split a 36-byte hot "agent core" from the 256-byte full agent.
- RimWorld ticks agents on Normal, Rare (every 250 ticks) and Long (every 2,000 ticks) lists, with hash offsets: https://github.com/UnlimitedHugs/RimworldHugsLib/wiki/Custom-Tick-Scheduling

**Recommendation** `[design]`:
- LOD changes only the embodiment; decisions, knowledge and crimes run identically at every LOD.
- Four tiers: E0 near and full; E1 mid and throttled; E2 in the village but unseen, positions computed from path and time; E3 other villages on a coarse graph.
- Event-driven scheduling on a **timing wheel** keyed by (tick, id): about 1-2 µs per event against 5-15 µs for a GDScript heap pop `[estimate]`. Interrupts pull a decision forward, and a generation counter skips stale entries.

## 4. Utility AI, GOAP and HTN

**Evidence** `[web]`:
- The Infinite Axis Utility System in Guild Wars 2: Heart of Thorns multiplies considerations, so a zero stops the decision early, with cheap considerations first. Early-outs were "a large part of what made the Heart of Thorns AI sufficiently performant": https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter13_Choosing_Effective_Utility-Based_Considerations.pdf and https://www.gdcvault.com/play/1021848/Building-a-Better-Centaur-AI
- Planners in shipped games made under 1 plan per second per NPC, of 4 actions or fewer, taking up to "several milliseconds" each in C++: https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter13_Optimizing_Practical_Planning_for_Game_AI.pdf. Logged rates: F.E.A.R. up to 8.5 plans per second per NPC, Killzone 3 up to 3.4: https://cdn.aaai.org/ojs/12728/12728-52-16245-1-2-20201228.pdf
- Transformers: Fall of Cybertron's HTN planner was "considerably faster" than the GOAP planner in War for Cybertron: https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter12_Exploring_HTN_Planners_through_Example.pdf

**Recommendation** `[design]`:
- Utility AI on the worker; curves as lookup tables; inputs cached per decision; targets pruned to the top few; cheap considerations first.
- Multi-step acts as short, hand-written HTN-style method lists.
- **No GOAP in GDScript:** 5-50 ms per plan on the S10 `[estimate]`.

## 5. GDScript vs C++, and threads

**Evidence** `[web]`:
- Pure maths: typically 40-100x. One microbenchmark: 16.033 ms in typed GDScript against 0.021 ms in C++ for 65,536 iterations: https://github.com/godotengine/godot/pull/70838
- Boids on Godot 4.7.2, GDExtension vs GDScript: 1.8 vs 23.8 ms at 5,000 boids, 7.5 vs 51.2 ms at 10,000 (7-13x): https://github.com/sanchitgulati/godot-cpp-gdextension-csharp-gdscript-benchmark
- Calling the engine per element erases the gain: `get_pixel`/`set_pixel` over 512² took 30 ms in GDExtension against 20 ms in GDScript: https://github.com/godotengine/godot-cpp/issues/1063
- Static typing gives 5-150%: https://godotengine.org/article/gdscript-progress-report-typed-instructions/
- iOS needs `.xcframework`s for `ios.debug` and `ios.release`, plus godot-cpp: https://github.com/godotengine/godot-cpp/blob/master/test/project/example.gdextension. Godot 4.5.2 fixed loading of static and xcframework libraries: https://godotengine.org/article/maintenance-release-godot-4-5-2/
- **Godot 4.7.1 and 4.7.2 fail to link on iOS** (undefined SDL symbols) with `DEAD_CODE_STRIPPING=NO`, `ENABLE_TESTABILITY=YES` or `-rdynamic`. Fixed for 4.8, closed 28 Sep 2026: https://github.com/godotengine/godot/issues/122549
- WorkerThreadPool: every task must be waited on, waiting from inside a task can deadlock (`ERR_BUSY`), and `low_priority_thread_ratio` is 0.3, so the S10's 8 cores give about 2 low-priority workers: https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html
- Exynos 9820: 2× Mongoose M4 at 2.73 GHz, 2× Cortex-A75 at 2.31 GHz, 4× Cortex-A55 at 1.95 GHz: https://en.wikichip.org/wiki/samsung/exynos/9820. GDScript can't pin thread affinity.

**Recommendation** `[design]`:
- A persistent simulation on a dedicated `Thread`, or one bounded pool task per simulation tick. `thread_probe.gd`'s pool task that runs until stopped is fine for a probe, not for the game.
- Size the tick budget for an A55 core, 2-3x slower than an M4 `[estimate]`.
- A double-buffered snapshot to the main thread.
- GDExtension only for measured hot loops, with one call per tick carrying packed arrays; expect 10-30x on branchy simulation code `[estimate]`.

## 6. Deterministic simulation

**Evidence** `[web]`:
- **Age of Empires:** commands scheduled 2 turns ahead, turns of about 200 ms, seeded RNG, periodic checksums: https://www.gamedeveloper.com/programming/1500-archers-on-a-28-8-network-programming-in-age-of-empires-and-beyond
- **StarCraft II:** 16 simulation loops per game second (22.4 at "Faster") with interpolated rendering; replays store inputs only and play on the version that recorded them: https://ar5iv.labs.arxiv.org/html/1708.04782 and https://sc2reader.readthedocs.io/en/latest/articles/whatsinareplay.html
- **Factorio:**
  - its own trig, because libm results differ across platforms: https://www.factorio.com/blog/post/fff-36
  - an ambiguous sort comparator that desynced: https://factorio.com/blog/post/fff-52
  - a cheap CRC every tick: https://factorio.com/blog/post/fff-55
  - 800 tests comparing CRCs across platforms: https://www.factorio.com/blog/post/fff-158
  - save-load-save diffing: https://www.factorio.com/blog/post/fff-63
  - a desync that depended on the core count: https://www.factorio.com/blog/post/fff-415
- **Godot:** the RNG's PCG32 is "an implementation detail and should not be depended upon": https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html. `Array.sort` isn't stable; Dictionary keeps insertion order.
- **ARM64:** clang's default `-ffp-contract=on` fuses `a*b+c` into FMA on ARM64 but not on default x86-64: https://discourse.llvm.org/t/impact-of-ffp-contract-defaults-on-benchmarking/87906

**Recommendation** `[design]`:
- A fixed simulation tick; inputs carry the tick they apply at.
- Keyed integer RNG (such as SquirrelNoise5, https://www.gdcvault.com/play/1024365/Math-for-Game-Programmers-Noise).
- Integer state; iterate by id and break sort ties by id.
- A cheap hash every tick and a full hash at checkpoints; golden replays on the S10 as well as the desktop; a save-load-save round trip.

## Summary table (the agent's; costs are estimates)

| Subsystem | Technique | Expected S10 cost | Fallback |
|---|---|---|---|
| Routine walking (30) | Cached paths between points of interest; position from path and time when unseen | 0.05-0.15 ms per frame (main) | A waypoint graph |
| Ad-hoc paths | `query_path` on the worker; navmesh under 1,000 polygons; at most 2 per frame | about 0 (main); 0.1-0.5 ms per query (worker) | Coarser navmesh; nearest cached path |
| Gathering crowds (30-60) | A flow field per venue; slot rings; separation | 0.3-0.6 ms per frame | 15 Hz in staggered halves (about 0.2 ms) |
| Avoidance | Separation; RVO near the camera only | 0.1-0.5 ms | Separation only |
| Near animation (at most 12) | AnimationPlayer, manual advance by distance | 0.5-1.2 ms | 8 characters at 15 Hz, finger tracks stripped |
| Crowd animation | Baked bone texture (or VAT) on MultiMesh | under 0.2 ms CPU, 1-3 draws | Sprite impostors |
| Decisions | Utility on the worker; curve tables; input cache; early outs | 0 main; about 5 ms of worker per second | Longer intervals; top-k targets; a C++ kernel |
| Multi-step acts | HTN-style method lists | negligible | Scripted sequences |
| Scheduling | Timing wheel (tick, id) | about 1-2 µs per event | Rare and Long buckets |
| Abstract villages | Offline coarse graph, hourly ticks | 1-5 ms of worker per game hour | Daily ticks |
| Simulation to scene | Double-buffered snapshot per tick | 0.1-0.3 ms | Half the agents per frame |
| Determinism checks | Keyed hash RNG; integer state; per-tick hash; golden runs on device | about 0.05 ms per tick | Hash every N ticks |

A 60-person execution is estimated at about 2-4 ms of main-thread time, inside the roughly 13 ms left, provided the current 20 ms script peak isn't growing. That peak is worth profiling separately.

**Two actions before anything else:**
- check the Xcode dead-stripping and testability settings before the first iPhone build (#122549);
- move the kernel off a long-running pool task.

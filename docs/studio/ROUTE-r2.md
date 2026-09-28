---
title: "Unbound - ways to build the idea, and what to do with what exists (route r2)"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), Claude Code on Hilmi's PC, lead agent from session 2
status: awaiting-hilmi-review
supersedes: the studio's first route (studio record, not in this repo) (kept unchanged as the record; section 7 says what survives)
next_step: Hilmi reviews; decisions D1-D4 (section 8) go to Enea through Hilmi; S2 starts on Hilmi's go
evidence_base: en-ea/Unbound at e08cbca in game/; spike tools-src/studio/kernel-prototype (run 28 Sep); web sources in section 9; the session-1 transcript fd3e06dd...jsonl
---

# Unbound - ways to build the idea, and what to do with what exists

**Labels:** `[repo]` measured in this repo or its git history · `[run]` produced by running something here · `[web]` cited source (section 9) · `[chat]` Hilmi's or Enea's words as pasted on 28 Sep · `[design]` my proposal.

---

## 0. Verdict

1. **Make the world a function, not a database.** The world at any moment is computed from three things: one seed, the time, and a small log of everyone's actions.
   - That single choice lets the idea run on the phone, offline, without a game server.
   - It also lets the world keep evolving, show any era in a time storm, take edits to its past, and be shared between friends by swapping logs of a few hundred bytes.
   - The spike proves the mechanics `[run]`: 500 years of history in ~25 ms, a view of any place in any year in ~1 ms, a changed past recomputed in ~19 ms, and two players' logs merging into the same world on both phones.
2. **It accommodates the ideas instead of correcting them.** Nearly every idea from Hilmi and Enea becomes a use of the same machinery (section 4): the living world, time storms, reversing time, centuries interacting, two lands that meet, strangers who "come in and mess with stuff", and history replayed at speed.
3. **Villagers with minds cost nothing per call.** Enea's iPhone 16 Pro Max carries Apple's on-device language model, which works offline `[repo]` `[web]`.
   - Named characters get that model: companions, elders, the traitor.
   - Everyone else runs on cheap rules.
   - The AI writes rules and lines. Its outputs go into the action log, so every phone replays the same result.
   - Caveats: it needs a native app, and Game Mode may block the model mid-play. Both are testable (S3).
4. **Keep Enea's build and extend it.** His code already contains the two patterns this route needs `[repo]`:
   - trader stock computed from the clock (`Money.stock()`);
   - regrowth caught up after time away (`WorldResources.load_data(data, away)`).

   The previous route would have replaced both with a server. Section 6 gives the file-level plan and six small steps that don't stall his fighting work.
5. **Two conflicts are the owners' to settle**:
   - **Resets.** Hilmi's "Then time resets" meets Enea's written "Excluded: ... prestige resets" `[chat]` `[repo]`. My proposal is local resets through storms by default, plus an optional new Age.
   - **Web or native.** My proposal is to stay on the web now and go native when the villager minds start (D3).
6. **The previous route (ROUTE-2026-09-28) stays as the record.**
   - Kept: its diagnosis, its building-grammar insight and its fair corrections.
   - Withdrawn: its server-first architecture, its cost framing and three factual claims (section 7).

---

## 1. (Omitted here)

*Section 1 reviews the studio's own first draft. It is kept in the studio's records and left out of this copy.*

---

## 2. What the owners asked for

**Enea** (his repo docs `[repo]` and the pasted chat `[chat]`):

| # | Requirement | Source |
|---|---|---|
| E1 | Played offline on the train; home-screen app on his iPhone 16 Pro Max | DESIGN.md, CLAUDE.md `[repo]`; "i want a game u just expand on like when u hop on it during train offline" `[chat]` |
| E2 | Endless, not story-driven; "no fixed end" | DESIGN.md pillar 1 `[repo]` |
| E3 | Gather → craft → stronger → further → rarer; real-time combat; loot chase (Outriders, Borderlands) | DESIGN.md pillars 2-3 `[repo]` |
| E4 | "A world that feels alive... places that grow because of you" | DESIGN.md pillar 4 `[repo]` |
| E5 | Tunic look, with Omno, A Short Hike, Sky and a touch of Journey; fixed camera | DESIGN.md `[repo]` |
| E6 | Co-op with one player per land, "both expand a bit... only then they meet, to work towards that 3rd"; a secret traitor | GAME_PLAN.md `[repo]`; `[chat]` |
| E7 | **Excluded:** prestige resets, curse outbreaks, seasons that change routes, plot-buying | DESIGN.md `[repo]` |
| E8 | Buildings: "nothing hits proper"; "telling an ai feels impossible without pics" | `[chat]` |
| E9 | Doubts he raised: "there will always be a finish line in something like an open world, how does that get fixed"; procedural is "kinda hard without reusing the same bs elements"; public worlds get stripped and need resets | `[chat]` |

**Hilmi** (`[chat]`):

| # | Idea |
|---|---|
| H1 | "The more procedural the better": replayability and unexpected scenarios |
| H2 | A manipulable, evolving world: "its about fucking with things and seeing what happens" |
| H3 | A world that keeps running, where "random ppl can even come in" |
| H4 | "assign cheap models to some of the villagers for decisions/behaviour rewrites or conversation" |
| H5 | "time storms where they pass over certsin places and the age they correspond to changes" |
| H6 | "a history remake that ai plays out at high speed... someone has to rediscover dna... one guy needs to cook for the other to continue" |
| H7 | "being able to be reversed back in time tho and different centuries interacting with eachother" |
| H8 | "Then time resets." "Infinite replayability" |
| H9 | Look: Omno, Journey, clean low-poly (the images he sent) |
| H10 | Adapt a polished open-source game, investigate engines, adapt the open-source Godot engine |

**Tensions to resolve:**

| | Conflict | Where it's handled |
|---|---|---|
| T1 | Offline (E1) versus a world that keeps running and is shared (H3, E6) | Section 3 |
| T2 | No prestige resets (E7) versus time resets (H8) | Section 4.7, decision D2 |
| T3 | Enea's written lore (the Tethered, the Hidden Fourth, the core) versus "the more procedural the better" (H1) | Section 4.4: the lore becomes the fixed skeleton, and history is generated around it, as Caves of Qud does |
| T4 | Co-op "later" versus an architecture decided now | Section 3: logs make co-op native from day one |

**A gap:** Enea's Atlas (keep/maybe/cut notes) and his Three Lands picks sit behind his claude.ai login. I did not sign in. Asking him to export both would close the gap.

---

## 3. The core move: the world as a function

```
   canon (Enea's lore: three peoples, the Tethered, the core, the Fourth)   ◄── fixed, hand-written
        │
   seed ─┼──►  ┌──────────── history kernel (deterministic, coarse) ───────────────┐
        │     │ one step per world-year: land and food, trades, knowledge,      │
        │     │ floods, raids, aid, foundings, ruins                             │
        │     │ randomness = hash(seed, year, place, purpose)   ◄── "keyed"      │
        │     └────────┬─────────────────────────────┬───────────────────────────┘
        │              │ checkpoint every 25 years   │ event log
        │              ▼                             ▼
        │     any place, any year          the chronicle · villagers' memories ·
        │     (time-storm view, ~1 ms)     every ruin's cause · "while you were away"
        │
   actions ─► a small log per player {year, kind, target, player, seq}
             from both the present and inside storms; merged in one canonical order
             Enea's phone ⇄ Hilmi's phone ⇄ a stranger's echo   (4 actions = 330 bytes)
   clock ───► world time moves with real time (e.g. 1 world-year per real day; tunable);
             opening the app catches up (30 days away = ~1 ms)
```

**Two layers.** Only the world layer has to be deterministic:

```
 WORLD layer  (kernel above)           villages, knowledge, resources at region scale, storms,
   deterministic, coarse ticks         ruins, relationships, the chronicle
        ▲  results of play enter as actions ("cleared the woods at Wenor", "funded the Smithy")
        │
 HANDS layer  (Enea's current game)    joystick, combat, gathering, building, camera, effects
   real-time, local, may stay random   unchanged - it plays inside whatever the world layer says
```

This is the same split Veloren uses: a coarse simulation of the whole world, plus physical detail only near the player `[web]`.

**Precedents** `[web]`:

| Precedent | What it shows |
|---|---|
| Dwarf Fortress | History is "a giant zero-player strategy game... and history is just a record of it" |
| Idle games (Melvor Idle, and others) | Compute the time away when the player returns; one deterministic function serves both live play and catch-up |
| Rollback netcode (GGPO) | Load a past state, change an input, re-simulate to now: 20 years of mature technique for "change the past" |
| Enea's own `Money.stock()` | Seeds its random generator from the time block, so every phone computes the same stock with no server `[repo]` |

**What the spike showed** `[run]` (`tools-src/studio/kernel-prototype/`):

| Test | Result |
|---|---|
| 500 years, 3 peoples, 12→~29 settlements | median **~25 ms**; deterministic |
| Any place in any year (storm view) | **~1 ms** |
| Edit the past and recompute today | **~19 ms**; identical to a full re-run |
| Edit spread, as villages a player would notice change | **21%** with keyed randomness, **61%** with one shared random stream |
| Two players' logs, any arrival order | identical world |
| Hinge search: every flood tried as a counterfactual | ~100 counterfactuals in ~1 s; the best changes 2-4x the median |

Three findings go beyond feasibility:
- **Keyed randomness makes shared time travel tractable.** Change spreads only along real causes.
- **History heals itself.** Most edits get absorbed: Wenor's saved mill left the present 4 people different. Storms must land on hinges.
- **The game can find its own hinges.** It tries counterfactuals and ranks them by impact.

**Limits:**
- The spike is a coarse toy, run in V8 on a PC.
- A typed-GDScript port is estimated at roughly 0.5-1.5 s per 500 years on a desktop-class core `[design]`, from GDScript being ~40-100x slower than C++ in tight loops `[web]`. That is fine for creating a world and for a storm transition. S2 measures it on Enea's phone.
- If GDScript is too slow, the kernel moves into a C++ module compiled into the engine. That is Hilmi's "adapt the open-source Godot engine", and it works on both web and iOS because the module is linked statically (section 4.11).

---

## 4. Idea by idea: the ways researched

Each subsection lists the options with their precedent, then a recommendation `[design]`.

### 4.1 A world that keeps evolving, including on the train (E1, E4, H3)

| Option | Precedent | Offline | Cost | Fit |
|---|---|---|---|---|
| A. An always-on server simulates the world | MMOs; the old route's SpacetimeDB | No | Server plus operations | Fails E1 |
| B. Catch up on open | Melvor Idle replays up to 24 h `[web]`; Enea's regrowth `[repo]` | Yes | Free | Good for simple systems |
| C. The world as a function of time | Enea's `Money.stock()` `[repo]`; the S1 kernel `[run]` | Yes | Free | Same world on every phone with no server |
| D. C plus a small relay that swaps action logs when online | Local-first software (Ink & Switch) `[web]` | Yes | Free tier | Adds sharing without taking offline away |

**Recommendation: C + D.** The train is the full game. Signal only adds other people's actions.

### 4.2 Two players, two lands, meeting later (E6)

| Option | Precedent | What it gives |
|---|---|---|
| A. Each plays their own land offline; their logs merge into one world history | Death Stranding's strand system: other players' structures appear in your world `[web]` | Before meeting, you see the other land grow: its traders, its knowledge arriving by boat, the bridge they funded |
| B. Lands connect inside the simulation | Enea's own "each land has its own resources... rebuilding the third land needs both" (Three Lands picker) `[repo]` | Meeting is earned: boats or a bridge join the lands (the spike's `canReach`) |
| C. Live co-op when both are online | Nakama (Apache-2.0, official Godot 4 client, realtime and storage) `[web]`; Game Center on a native app | Play together on the third land |
| D. **Different centuries, live** | Rusty Lake's *The Past Within*: one player in the past, one in the future of the same place, solving it together (iOS; 94% positive on Steam) `[web]` | A storm opens on both maps. One player steps into year 150, the other stays in today. What one does in the past changes the other's present within seconds (~19 ms to recompute) |

**Recommendation: A and B from the start (they come free with logs), C for the meeting, D as the signature co-op moment.** D is Hilmi's "different centuries interacting" and Enea's co-op in one feature, and I found no precedent for it in an open world.

### 4.3 Strangers who "come in and mess with stuff" (H3), without the stripped world Enea fears (E9)

| Depth | Precedent `[web]` | Server needed |
|---|---|---|
| 1. Traces | Dark Souls messages; Sky's Shared Memories (120-second recordings others replay, visible for 14 days) | Storage only |
| 2. Shared builds | Death Stranding: bridges and ladders appear in other worlds, with likes and a "bandwidth" cap | Storage only |
| 3. Visits to a snapshot | Animal Crossing Dream Address: changes don't persist | Storage only |
| 4. Raids on a base that defends itself | Clash of Clans: the defender is offline, the base's AI defends, and shields follow a loss | Storage plus validation |
| 5. A live public world | Roblox and MMOs: servers close when empty, so persistence is scripted | Always-on server |

**Recommendation: strangers arrive as echoes through storms.** A stranger's action enters your world as an event "from another age", drawn from depths 1-4:
- a message in a ruin;
- a bridge someone built;
- a raid your village has to repel.

A daily effect budget, like Death Stranding's bandwidth, keeps it from stripping the world.

Friends' logs have full effect; strangers' echoes are bounded. This delivers Hilmi's point without a live public server, and it answers Enea's strip-mining worry by construction.

### 4.4 History at high speed, rediscovery, linked trades (H6, H1, T3)

| Option | Precedent `[web]` | Verdict |
|---|---|---|
| A. Thousands of agents, zero-player strategy | Dwarf Fortress, ~1 year per 2 s with 20,000 people | Too heavy for a phone at that scale |
| B. Coarse settlement-level simulation | Veloren rtsim ("tens of thousands of NPCs... in real-time", coarse and throttled); the S1 kernel, 500 years in ~25 ms `[run]` | **Causes**: every ruin has a reason |
| C. Generate the events, then rationalise them | Caves of Qud's sultans: a state machine plus a replacement grammar, "first generates historical events and ratio[nales] for them afterward" | **Voice**: legends with bias and myth |
| D. A civilisation of LLM agents | Project Sid: up to 1,000 GPT-4o agents; above 1,000 the server buckled; public users found them "frustratingly independent" | Wrong tool for the bulk; the right tool for a few named minds (4.8) |

**Recommendation: B for causes, C's grammar for the chronicle's voice, and D only for named characters.**

- **Enea's lore is the fixed skeleton.** Caves of Qud keeps one hand-written sultan, Resheph, fixed in every world and generates the other five `[web]`. Enea's Tethered, Hidden Fourth and core play that role, with generated history filling in around them. This resolves T3.
- **"One guy needs to cook for the other" is a dependency graph.** In the kernel, iron needs copper and charcoal; copper needs charcoal and a miner; bread needs the mill and pottery. Collapse makes knowledge lost, and ruins make rediscovery easier `[run]`.
- **What the player does in it.** The player carries knowledge across eras and lands, or becomes the missing trade: your charcoal gets Wenor to iron.

### 4.5 Time storms (H5)

| Option | Precedent `[web]` | Cost |
|---|---|---|
| A. Two stacked maps, teleport between them | Dishonored 2 "A Crack in the Slab": maps offset by 600 m, with a preview lens showing the other time | Hand-built, two eras only |
| B. Age or restore a single object | Singularity's Time Manipulation Device: age a pipe until it bursts, restore a collapsed stair | Cheap and local |
| C. Global storms that punish | Vintage Story: many players switch them off, and ask for local moving storms (cited in the old route) | Proven unpopular |
| D. **Kernel-driven local storms** | The S1 kernel: a region renders its state in year Y (~1 ms) | Content multiplied by every era a place passes through |

**Recommendation: D, with B as a tool the player uses inside storms, and A's preview lens as the interface.**
- Buildings in the storm come from Enea's own growth ladder and ruin family (section 4.10). The kernel's stages already map one to one: hut → homestead → hamlet → village → town → ruin.
- **Storms go to hinges.** The game runs its own counterfactuals and sends storms to where history is most sensitive `[run]`.
- **The forecast is a reason to open the app.** "A storm is gathering over the Old Mill, year 107" answers Hilmi's "new things to expect". It also answers Enea's "ruins that change each visit" `[repo]`.

### 4.6 Reversing time, and centuries interacting (H7)

| Option | Precedent `[web]` | Fit |
|---|---|---|
| A. Curated cause and effect | Oracle of Ages: plant a seed in the past to find a tree in the present; a bridge repaired in the past opens a route today | Hand-authored puzzles |
| B. Personal rewind | Braid, Prince of Persia | Moves the player, not the world |
| C. **Counterfactual re-simulation** | Rollback netcode (GGPO): load a past frame, change the input, re-simulate; the S1 kernel does it in ~19 ms `[run]` | Oracle of Ages' logic emerges from the simulation instead of being scripted |
| D. Two players, past and future | *The Past Within* | See 4.2 D |

**Recommendation: C, with A-style signposting at the hinges.** Planting, teaching or warning in year 300 changes today.

The old route's bounds stay, now backed by a mechanism:
- keyed randomness keeps the spread causal (21% versus 61%);
- one edit per storm;
- player-built things are anchored and survive rewrites;
- the change lands when the storm leaves.

### 4.7 Time resets versus "no prestige resets" (H8 against E7): decision D2

| Option | Precedent `[web]` | Hilmi's H8 | Enea's E7 and E3 |
|---|---|---|---|
| A. Global Age reset with a legacy (old route) | Seasonal leagues | Yes | Conflicts as written |
| B. The world resets, and knowledge is the only progress | Outer Wilds: "knowledge is the only thing you get" | Yes | Conflicts with the loot chase |
| C. **Local resets through storms** | Singularity's restore; Enea's "ruins that change each visit" `[repo]` | Partly: time resets, place by place | Yes: the player keeps everything |
| D. An optional new Age with a new seed, carrying heirlooms and legends | Opt-in leagues | Yes, for those who want it | Yes, if never forced |

**Proposal: C by default, D offered and never forced.** C also mends stripped or burned regions over time, which answers E9. This is the owners' call, and I have not assumed it.

### 4.8 Villagers with minds (H4)

The layers, cheapest first:

```
 everyone (hundreds)     needs, jobs, schedules, relationships     rules: utility scoring        free, deterministic
                         (The Sims-style needs; utility AI)        inside the kernel/hands
 named few (~10-20)      companions, elders, the traitor,          Apple on-device model         free, offline,
                         the romance NPC                           (iPhone 15 Pro and later)     native app only
 slow jobs               the chronicle digest, "behaviour          Apple Private Cloud Compute   free under the Small
                         rewrites" for a village's policy          (iOS 27, 32K context)         Business Program, daily cap
```

**What Apple's model offers** `[web]`:
- **Size and memory.** About 3 billion parameters, with 4,096 tokens per session: memories must be summarised.
- **Output.** Guided generation into fixed types (constrained decoding), so decisions can be picked from a fixed list, plus tool calling so a villager can look up real game state.
- **Speed.** About 30-50 tokens a second on an iPhone 15 Pro. The open-source `open-apple-models` toolkit reports enum decisions valid 10 times out of 10 in about 1.2 s, and grounded answers in 2-3 s, with a C interface for Godot. That toolkit needs iOS 27.
- **iOS 27 cloud model** (shipped 14 September). The larger Private Cloud Compute model, with 32K context. It is free for developers in the Small Business Program with fewer than 2 million downloads, but needs an entitlement and has a per-user daily quota.

**Hilmi's "behaviour rewrites", made safe for multiplayer.**
- The model writes rules, not frame-by-frame actions. After a raid, Wenor's village mind might raise the weight on "fortify" and "stockpile".
- The kernel validates the change.
- The result is recorded in the action log as data, so other phones replay the output rather than re-running the model. That keeps the world deterministic.
- Precedents `[web]`: Voyager, where an LLM writes a reusable skill library; Generative Agents, with memories plus periodic reflections. AI Town is an MIT-licensed re-implementation of the latter, useful as a reference.

**Risks, each testable in S3:**
- **Native only.** The web build cannot reach the model.
- **Game Mode.** Guides list "not in Game Mode" as a requirement. A game can opt out with `GCSupportsGameMode` and `LSSupportsGameMode` set to false, but whether the model then stays available during play must be measured.
- **Enea's settings.** Apple Intelligence must be switched on.
- **Guardrails and fallbacks.** Players try to trick open chat, as Where Winds Meet shows `[web]`. The design uses fixed choices for decisions and prepared lines as a fallback.

**Cost:** $0 per call, against the old route's ~$75-100 a month.

### 4.9 A world you can mess with (H2)

- **BOTW's chemistry engine** is three rules `[web]`:
  - elements change materials;
  - elements change elements;
  - materials don't change materials.

  Combined with physics, that gave "multiplicative gameplay".
- **For Unbound** `[design]`: a small element-and-material table in the hands layer:
  - fire spreads through dry grass and timber roofs;
  - rain and water douse it;
  - wind carries embers;
  - frost hardens the ground.

  Results enter the world layer as actions. Burn the mill, and the village remembers, prices move, and the next storm over it can show the mill before the fire.
- **The appetite is proven on phones.** WorldBox, a "petri dish for your fantasy civilizations", went from Android and iOS to millions of downloads and 96% positive of ~30k Steam reviews `[web]`. Hilmi's instinct has a market.

### 4.10 Buildings and the look (E8, E5, H9)

| Option | Precedent `[web]` | For Unbound |
|---|---|---|
| A. Hand-model every building (today) | 20 houses, each a bespoke Blender function; about 24 commits on buildings `[repo]` | The words-to-geometry loop Enea says "nothing hits proper" |
| B. A modular kit plus a grammar | Townscaper: an irregular grid, wave function collapse and marching-cubes modules. Tiny Glade: roofs derived from the wall outline, and buildings that "glue" together | A consistent look from a small kit. Enea's growth columns and ruin family become rule variants the kernel drives |
| C. Image-to-3D from Enea's own sheets | Tripo Smart Mesh and Meshy 6 have low-poly modes; TRELLIS.2 is MIT-licensed (self-hosting needs a 24 GB GPU). **Not Hunyuan3D: its licence excludes the UK** | Family "shells" fast, then a clean-up script |
| D. The look through light, fog, colour and shader | Tunic, Omno, Journey: atmosphere comes mostly from lighting | Enea already has one shared shader (`foliage_solid.gdshader`) `[repo]` |

**Recommendation: B + C + D, chosen by picture.**
- Look boards render real options side by side, and Enea picks. That answers "telling an ai feels impossible without pics".
- His sheets already hold the system: families by function and by growth stage, plus a ruin family (`docs/studio/BUILDING-SHEETS.md`).

### 4.11 "Adapt a polished open-source game or engine" (H10): the honest answer

- **No finished open-source game matches.** Searched again, more widely `[web]`:
  - Godot 3D RPG and survival projects are templates or works in progress: the Souls-like template (Unlicense), a sci-fi survival template (MIT), Reia (Godot plus Rust, in private testing).
  - Veloren is GPL, Rust and not on iOS: a design study only.
- **Two things are worth studying:**
  - OpenAcre/Hourbloom, which targets Godot 4.7 and uses "a headless event/signal bus [that] keeps background logic like crop growth and AI running in unloaded chunks";
  - Veloren's rtsim design notes.
- **Parts worth adopting:**

  | Part | Licence | Use |
  |---|---|---|
  | Nakama | Apache-2.0; official Godot 4 client; `NakamaMultiplayerBridge` works with Godot's own multiplayer API | Log relay, echoes, live co-op |
  | SwiftGodot, GodotApplePlugins | Open source | How Swift code, such as the Foundation Models bridge, gets into a Godot iOS build as an xcframework |
  | Wave function collapse (mxgmn); the Sylves Townscaper grid | MIT | The building grammar |
  | TRELLIS.2 | MIT | Building shells |
  | AI Town | MIT (its Convex backend is FSL) | Reference for memory and reflection |

- **Adapting Godot itself** is justified in one place: a C++ module holding the kernel, compiled into custom export templates, if S2 shows GDScript is too slow.
  - It works on web and iOS because it is linked statically.
  - The Rust bindings (gdext) still call Wasm and iOS "experimental", with nightly-toolchain breakage in June 2026 `[web]`, so not Rust for now.
  - Godot 4.7's web export is WebGL 2 only. Safari's WebGPU doesn't help it yet `[web]`.

---

## 5. Platform: web now, native when the minds start (decision D3)

| | Web (today) | Native app (TestFlight) |
|---|---|---|
| Offline on the train | Yes, through Enea's own `offline.sw.js` `[repo]` | Yes |
| Apple's on-device model and cloud model | **No** | Yes (S3 checks Game Mode) |
| Renderer | Compatibility (WebGL 2), one thread; iOS Safari audio crashes reported, worked around by switching web audio playback to Stream `[web]` | Mobile renderer on Metal |
| Cost and friction | $0; publish by push | $99 a year; builds need macOS (a Mac or GitHub's macOS runners); Xogot Connect for quick device runs needs Xogot Pro `[web]` |
| Sync | Nakama or any web store | Nakama, CloudKit, Game Center |

**Recommendation: build the kernel and its steps (section 6) on the web build as it is today. Switch to native when the named villagers start, gated by S3.** Nothing in the kernel depends on the platform. The previous route switched first and asked questions later.

---

## 6. The existing implementation: keep, extend, replace

**Verdict: keep almost all of it and extend two patterns. No rewrite, no server, no engine change.**

| | Files `[repo]` | Why |
|---|---|---|
| **Keep as is** (hands layer) | `player/*`, `creatures/*`, `ui/*`, `camera/*`, `audio/*`, `state/balance.gd`, `state/items.gd`, `gear.gd`, `food.gd`, `skills.gd`, `inventory.gd`, the character pipeline, dev arguments, the test menu | Feel-tested on his phone; the world layer sits beside it |
| **Extend** (the seeds) | `state/money.gd` `stock()`: RNG seeded by the time block → generalise into a `WorldClock` plus a keyed-random helper. `state/world_resources.gd` `load_data(data, away)` → generalise into kernel catch-up. `state/projects.gd` `fund()` → funded projects become logged world actions | These already do the hard part offline |
| **Fix** (world layer only) | `world_resources.gd` calls `_rng.randomize()` and times regrowth with `Time.get_ticks_msec()` (session-relative). Move both to the world clock and keyed draws. Creatures and effects can stay random: they are hands | Determinism where it matters, nowhere else |
| **Add** | `state/world_clock.gd`, `state/action_log.gd`, `world/kernel/*` (the history kernel, headless-testable), a chronicle panel | New, small, and separate from the hands layer |
| **Replace gradually** | Typed-in region layouts (`world_shape.gd`) stay for handcrafted home areas; new regions come from the kernel and grammar. Houses from `make_buildings.py`/`make_village.py` → the grammar, keeping a few favourites (the Swoop lodge, the Stump house) as landmarks | Nothing is thrown away before its replacement is chosen by picture |
| **Don't** | Move state to a server; switch engines; drop the web build before S3 | Each would cost what exists and buy nothing yet |

**Six steps.** Each is shippable, and none blocks Enea's fighting and loot work:

```
 1  WorldClock + keyed random + ActionLog     no visible change; existing actions also append to the log
 2  Kernel v0 in typed GDScript, headless     the three lands' villages as data; invariants run in ms;
                                              a dev argument times it on his phone (= spike S2)
 3  "While you were away"                     projects and resource use enter the log; opening shows a chronicle
 4  First storm                               one region shows year Y using growth-stage and ruin variants
                                              (look board first); the storm is aimed by hinge search
 5  Native + first named villager (= S3)      one elder who speaks from the chronicle, on Enea's phone
 6  Two phones, one history (= S4)            Hilmi's and Enea's logs sync; each sees the other's land change
```

**Process advice for Enea's agent:**
- Buildings are chosen from rendered look boards, never described in words.
- Kernel changes are checked headless in milliseconds before anything reaches his phone.
- The "Publish web build" commits carry engine binaries every time: 30 of 134 commits `[repo]`. They belong in a build step, not in history.

---

## 7. What survives from ROUTE-2026-09-28

| | Items |
|---|---|
| **Kept** | Diagnosis: hand-made content can't keep pace; nothing in the repo generates or changes the world. The building system read from Enea's sheets. Look boards. The verification ladder. The toolbox design. Fair corrections: a shared world must fight back against stripping; edits to the past need bounds; "procedural causes, not scenery". Storms driven by the history log. The chronicle as the answer to "the story felt cold". Most of the keep/replace/park table |
| **Changed** | Server-authoritative world → the world as a function, with logs synced. The LLM cost model → on-device first. Age resets as the centrepiece → local resets plus an optional new Age (D2). "Go native now" → native when the minds start (D3). A Rust simulation → a GDScript kernel first, then a C++ engine module if measured too slow |
| **Withdrawn** | "Xogot Lite free for native runs from the Windows editor". Hunyuan3D as a tool (licence excludes the UK). The "$30,000 a month" framing. SpacetimeDB and BitCraft as the base. The claim "there is no polished open-source game to fork, only parts" is correct but incomplete: section 4.11 is the complete answer |

---

## 8. Next steps and decisions

**Spikes, cheapest first:**

| Spike | What it decides | Needs |
|---|---|---|
| S1 (done `[run]`) | The world as a function works at the settlement level | - |
| S2: the kernel in typed GDScript inside Enea's project, timed on his phone through a dev argument | GDScript or a C++ engine module | Nothing new; a branch in his repo |
| S3: a minimal native build on Enea's iPhone: Game Mode opted out, one villager grounded in the chronicle, availability measured during play | When to go native, and whether the minds are on-device | $99 Apple account and a macOS build (a Mac, or GitHub's macOS runner) |
| S4: two phones, one history (log relay on Nakama's free self-host, or CloudKit if native) | Friends sharing a world without a game server | A $5 VPS or nothing |
| S5: storm look board: one region in three eras, built from two of Enea's families | Whether storms look worth chasing | Blender headless, or image-to-3D credits |

**Decisions:**

| # | Who | Decision |
|---|---|---|
| D1 | Enea | This direction: a world with a history that keeps happening, built beside his current game, which stays the hands layer |
| D2 | Enea and Hilmi | Resets: local storms by default, with an optional new Age (section 4.7), or none |
| D3 | Enea | Native app ($99 a year) when the named villagers start, after S3 |
| D4 | Hilmi | Whether and how this reaches Enea (for example, the verdict plus one chronicle excerpt from S1). Also asking Enea to export his Atlas and Three Lands picks |

---

## 9. Sources `[web]`

**On-device and cloud AI (Apple)**
- Foundation Models, context and speed: https://developer.apple.com/videos/play/wwdc2025/286/ · https://developer.apple.com/forums/thread/806542 · https://zats.io/blog/making-the-most-of-apple-foundation-models-context-window/
- iOS 27 and Private Cloud Compute: https://developer.apple.com/videos/play/wwdc2026/241/ · https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel · https://www.heise.de/en/news/Apple-releases-large-cloud-model-for-free-to-smaller-developers-11329079.html · https://daringfireball.net/linked/2026/06/13/pcc-severely-limited-third-party-developers
- Game-oriented toolkit: https://github.com/SpaceCorps/open-apple-models
- Game Mode: https://github.com/onmyway133/blog/issues/1063 · https://developer.apple.com/documentation/bundleresources/information-property-list/gcsupportsgamemode · https://developer.apple.com/documentation/bundleresources/information-property-list/lssupportsgamemode

**Godot, iOS and web**
- Swift in Godot iOS builds: https://github.com/migueldeicaza/SwiftGodot · https://github.com/migueldeicaza/GodotApplePlugins
- Xogot: https://xogot.com/connect/ · https://blog.xogot.com/make-games-anywhere-introducing-godot-for-iphone-and-xogot-lite/
- Web export and iOS Safari: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html · https://github.com/godotengine/godot/issues/116750 · https://app.cinevva.com/news/2026-06-19-godot-4-7-released
- GDScript speed: https://github.com/godotengine/godot/pull/70838
- Rust bindings status: https://github.com/godot-rust/gdext · https://github.com/godot-rust/gdext/issues/498
- Open-source Godot games: https://github.com/bearlikelion/awesome-godot-games · https://github.com/fgh345/Hourbloom · https://github.com/Quaint-Studios/Reia

**Simulation, history and catch-up**
- Dwarf Fortress history as simulation: https://www.gamedeveloper.com/design/q-a-dissecting-the-development-of-i-dwarf-fortress-i-with-creator-tarn-adams · https://gamerant.com/dwarf-fortress-interview-evolution-after-release/
- Caves of Qud: https://www.freeholdgames.com/papers/Generation_of_mythic_biographies_in_Cavesofqud.pdf · https://wiki.cavesofqud.com/wiki/World_generation
- Veloren rtsim: https://veloren.gitlab.io/veloren/veloren_rtsim/index.html · https://blog.jsbarretto.com/post/veloren
- Offline progress in idle games: https://wiki.melvoridle.com/w/Offline_Progression · https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii
- Rollback: https://www.snapnet.dev/blog/netcode-architectures-part-2-rollback/ · https://www.ggpo.net/
- Local-first software: https://www.inkandswitch.com/local-first/

**Multiplayer and strangers**
- Death Stranding: https://deathstranding.fandom.com/wiki/Social_Strand_System · https://screenrant.com/death-stranding-multiplayer-social-strand-system-online-build/
- Sky's Shared Memories: https://sky-children-of-the-light.fandom.com/wiki/Shared_Memories
- Clash of Clans: https://www.deconstructoroffun.com/blog//2012/09/clash-of-clans-winning-formula.html
- The Past Within: https://store.steampowered.com/app/1515210/The_Past_Within/ · https://www.cbr.com/rusty-lake-the-past-within-video-game-review/
- Nakama: https://heroiclabs.com/docs/nakama/client-libraries/godot/ · https://github.com/heroiclabs/nakama-godot
- CloudKit: https://developer.apple.com/icloud/cloudkit/ · https://fatbobman.com/en/posts/my-eight-years-with-cloudkit/

**Time mechanics**
- Dishonored 2: https://kotaku.com/what-made-dishonored-2s-time-travel-level-so-good-1819596566 · https://dishonored.fandom.com/wiki/A_Crack_in_the_Slab
- Oracle of Ages: https://zelda.fandom.com/wiki/The_Legend_of_Zelda:_Oracle_of_Ages · https://www.triforcetimes.com/2026/01/09/oracle-of-ages-did-time-travel-better-than-ocarina-of-time/
- Singularity: https://en.wikipedia.org/wiki/Singularity_(video_game) · https://singularity.fandom.com/wiki/Time_Manipulation_Device
- Outer Wilds: https://www.gamedeveloper.com/design/road-to-the-igf-alex-beachum-s-i-outer-wilds-i-

**AI agents and systemic design**
- Project Sid: https://arxiv.org/abs/2411.00114 · https://www.technologyreview.com/2024/11/27/1107377/a-minecraft-town-of-ai-characters-made-friends-invented-jobs-and-spread-religion/
- AI Town and Generative Agents: https://github.com/a16z-infra/ai-town · https://arxiv.org/abs/2304.03442
- Voyager: https://arxiv.org/abs/2305.16291
- LLM NPCs in shipped games: https://arcanumrpgs.com/blog/where-winds-meet-ai/ · https://game8.co/games/inZOI/archives/504226
- BOTW chemistry engine: https://www.thumbsticks.com/gdc-17-breath-of-the-wild-science-lies/ · https://www.engadget.com/2017-03-12-breath-of-the-wild-gdc-talk.html
- WorldBox: https://en.wikipedia.org/wiki/WorldBox · https://store.steampowered.com/app/1206560/WorldBox__God_Simulator/

**Buildings and assets**
- Townscaper: https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making · https://boristhebrave.com/docs/sylves/1/articles/tutorials/townscaper.html · https://github.com/mxgmn/WaveFunctionCollapse
- Tiny Glade: https://80.lv/articles/exclusive-tiny-glade-developers-discuss-bevy-proceduralism-publishers-cozy-games · https://80.lv/articles/a-look-at-procedural-tower-roofs-in-tiny-glade
- Image-to-3D: https://app.cinevva.com/guides/ai-3d-model-generators · https://help.scenario.com/articles/1263568892-comparing-generative-3d-models
- Hunyuan3D licence: https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/blob/main/LICENSE

---
title: "Unbound - the camera, the format and the playable experience"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), Claude Code on Hilmi's PC, lead agent, session 2
status: awaiting-hilmi-review
relates_to: docs/studio/ROUTE.md (this expands its section 8 and adds the format and the "singled out" mechanic)
next_step: Hilmi reviews; permission to install Godot 4.7.2 so the real game can be rendered in each proposed framing (look board, section 9); the camera decision (D5) goes to Enea with that board
evidence_base: two frames rendered from Enea's published web build on 28 Sep (docs/studio/evidence/camera/); camera geometry computed from game/scripts/camera/follow_camera.gd; web sources in section 10
---

# The camera, the format and the playable experience

**Labels:** `[repo]` measured in this repo · `[run]` produced by running something here · `[web]` cited source · `[chat]` Hilmi's or Enea's words · `[design]` my proposal.

Hilmi, 28 Sep `[chat]`: "not that those camera angles in the pictures are optimal, that was more showing off the loss in capacity with the current implementation in comaprison, both graphics and angle". And: "the birds eye view current camera angle would probably give such a poor feel to the game".

---

## 0. Verdict

1. **The loss is real and measurable** (section 1).
   - The gameplay camera looks down at 45° through a narrow 32° lens. It sees a patch of ground about 17 m deep, from 5 m behind you to 12 m ahead, in a play area 192 m across. **It never shows the sky** `[repo]` `[run]`.
   - Enea's own title screen renders the same world from a low angle, and it is visibly a different game (the two frames in `docs/studio/evidence/camera/`).
   - The web renderer then removes most of what makes Omno's look: depth of field, post-processing effects and volumetric fog `[web]`.
2. **For this game the horizon is the interface of the living world, not decoration.** It is where you see:
   - smoke rising from a burning in the next village;
   - a storm wall rolling in;
   - torches of a procession at dusk;
   - the veiled third land across the strait.

   Four of Enea's own lore options in his Three Lands picker depend on seeing the horizon `[repo]`. A camera without a horizon hides the simulation this whole route is built on.
3. **Recommendation: a "living camera"** (section 4). It is not Omno's shot and not a god view. It is:
   - a low, auto-framed third-person camera by default;
   - a camera director that changes the framing with what you are doing: explore, fight, build, witness, talk, vantage;
   - Enea's current top-down framing kept for building, with a variant of it for fighting, so his combat tuning survives.

   Seeing the whole land is earned **inside the world**: from vantage points, at a map table in your house that shows the land as a living miniature (Deisim on your table), and with storm-sight from the shrines. There is no floating god camera.
4. **2.5D in the side-view sense is the strongest alternative, and I recommend against it for this game.** Kingdom proves it on phones and it stages public events like theatre. Its own designer says it makes strategy one-dimensional, and it cannot show a land or a horizon (section 3).
5. **The cost is real.** From the low title camera, the same build draws 498 calls and 121k triangles, against 267 and 80k from the gameplay camera `[run]`. That was measured in this PC's browser, not on a phone. A horizon camera needs:
   - the native Mobile renderer;
   - level of detail and impostors;
   - far-away versions of each settlement.

   Dynamic third-person cameras are "the hardest to design" (Journey's camera designer) `[web]`, so this must be prototyped and played, not written.
6. **The playable format** (section 6): a person living inside a civilisation. The loop is notice → go → witness or act → consequence → back to your own life. Sessions work at 2, 15 and 60 minutes.
7. **Groups singled out get a mechanic grounded in real history** (section 7). Witch trials rose with cold years and slow growth. Plague-era persecutions depended on shock, belief and economic ties `[web]`. The same group can be hanged in one age and worshipped in another, and the chronicle can always say why.

---

## 1. What the current build loses (measured)

**The camera** (`follow_camera.gd`) `[repo]`: pitch -45°, distance 18 m, vertical field of view 32°, never rotates, always faces north, far plane 220 m.

**What that sees** `[run]` (computed from those values):

```
            camera 13.7 m up, 12.7 m behind you
               ●
                \  top of the frame: 29° BELOW the horizon  → no sky, ever
                 \
                  \   ░░░ what you see: 17 m deep (5 m behind you → 12 m ahead), ~36 m wide at the far edge
   ────────────────\──░░░░░░░░░░░░░────────────────────────────────────────────── ground (play area 192 m)
                     you
```

**The same build from two angles** `[run]` (rendered on 28 Sep in the browser pane at a 915x412 phone-landscape viewport, Enea's release web build, frames saved to `docs/studio/evidence/camera/`):

| | Gameplay camera (`gameplay-camera-45deg.png`) | Title-screen camera (`title-screen-low-camera.png`) |
|---|---|---|
| Sky or horizon | None | Haze, hills, distant trees |
| Your character | ~15% of screen height | ~60% |
| Houses | Cropped roofs seen from above | Facades, depth, layering |
| Draw calls / triangles | 267 / 80k | 498 / 121k (about 1.9x and 1.5x) |
| Frame rate in this PC's browser (30 fps lock) | 30 | 24 |

**What that costs the game** `[design]`:
- **Nothing on the horizon can pull you anywhere.** Breath of the Wild's designers put tall structures where they are "visible from far away" to create "gravity" `[web]`. Here, nothing further than 12 m ahead exists on screen.
- **The living world can't be seen**: not a storm coming, not smoke from the next village, not a crowd gathering.
- **Enea's character work is shrunk.** His 13 outfits and his character creator show at about 15% of the screen height.
- **His own lore needs a horizon** `[repo]` (Three Lands picker):
  - "The third land is visible on the horizon, veiled";
  - "Every step of restoring it is visible from both sides";
  - "A striking goal you can literally see from anywhere in the world";
  - the Great Tree "visible from everywhere".

**The renderer.** The web build is locked to Godot's Compatibility renderer `[repo]` `[web]`.

| What Omno's look uses (its developer, `[web]`) | Web build today (Compatibility) | Native Mobile renderer |
|---|---|---|
| Sun plus skylight, low sun | Yes | Yes |
| Exponential height fog | Yes | Yes |
| Depth of field | **No** | Yes (known bug with MSAA on) |
| Glow | Yes | Yes (overhauled in 4.6) |
| Post-processing passes (god rays, stylised grading) | **No** | Yes |
| Volumetric fog | No | **No** (Forward+ only), so god rays are faked with fog cards and post |
| Threads for the simulation | **No** (single-threaded web) | Yes |

Omno's developer, working solo, says the look comes from a "pretty basic" lighting setup. That frees the GPU for "post-processing and fog, which makes the real deal", plus a low sun and god rays `[web]`. On phones, the native Mobile renderer can do nearly all of that. The web build cannot.

---

## 2. The terms you asked about

| Term | What it usually means | Examples |
|---|---|---|
| **2.5D (a)** | 3D graphics, but you move on a 2D line (side view) | Kingdom Two Crowns (side-scrolling village strategy, though its art is 2D pixel), Little Nightmares |
| **2.5D (b)** | 3D seen from a fixed high angle (isometric-style) | **Enea's current camera**, Tunic, Hades |
| **"Bounded 3D"** (not a standard term) | Either a 3D camera whose freedom is limited (it frames itself, with limits on how far you can turn or zoom), or a 3D world built as bounded areas joined by passages | Journey, Sky and A Short Hike (bounded camera); Omno ("fairly large areas connected by shorter linear passages") and Enea's regions (bounded world) |

What I recommend is bounded in the first sense: a 3D camera that frames itself within limits and lets you take over when you want.

---

## 3. The options, judged for this game

| Camera | Precedent `[web]` | Shows the living world | You feel like a person inside | Crowds and events read | Fights read | Phone controls | Build and render cost |
|---|---|---|---|---|---|---|---|
| Fixed high angle (today) | Tunic, Hades | ✗ no horizon | ✗ you're a token | ~ close crowds only | ✓ | ✓ joystick only | Lowest |
| **Side-view 2.5D** | Kingdom: 4M+ sold across the series, built for mobile. Its designer: units are "in-range or out-of-range on a one-dimensional line" | ~ one line of it | ✓ intimate | ✓ staged like theatre | ~ | ✓ | Low, but a rewrite of the world and combat |
| **Low auto third-person** | Journey, Sky (one hand; drag with two fingers for the camera), Omno | ✓ | ✓ | ✓ with framing | ~ needs a combat framing | ✓ with auto-follow | High (camera design, draw distance) |
| Free orbit third-person | Genshin Impact on phones: drag any empty area to turn; auto-reset and combat-camera settings | ✓ | ✓ | ✓ | ✓ | ✓ proven by millions | High |
| Over-the-shoulder | Kingdom Come, many action games | ~ | ✓ | ✗ narrow on a phone | ✓ | ~ | High |
| First-person | Medieval Dynasty | ✓ | ✓ | ~ | ✗ on touch | ✗ nausea, and hides Enea's character | High |
| Diorama god view | Deisim, WorldBox, Townscaper | ✓ from above | ✗ you watch | ✓ | ✗ | ✓ | Medium |

**The side view deserves one more line.**
- It stages a hanging in the square the way a stage play would, and villages read cleanly as a line of lives.
- Its designer chose it because moving through the world equals panning the map, and admits the price: strategy on "a one-dimensional line" `[web]`.
- For a game about two lands, a strait, storms rolling across a landscape and a third land on the horizon, that price is too high. It would also mean redoing Enea's world and combat.

**Recommendation: low, auto-framed third person plus a camera director** (section 4). It takes Genshin's optional drag and Sky's auto-framing, and it keeps Enea's top-down framing where it serves: fights and building.

---

## 4. The living camera: one director, several framings

| Framing | When | Pitch | Vertical FOV | Distance | Sky | What it does `[design]` |
|---|---|---|---|---|---|---|
| **EXPLORE** | walking, travelling | about -10° | about 50° | about 8 m | ~30% of frame | Follows your heading with lag; you ~25% of screen height; the horizon carries the world's signals |
| **FIGHT** | enemies engaged | about -32° | about 45° | about 12 m | none | Close to Enea's tuned view, so tells, glints and enemies around you read as he balanced them; blends in about 0.4 s |
| **BUILD** | placing things in your yard | -45° | 32° | 18 m | none | Exactly today's camera `[repo]` |
| **WITNESS** | a gathering, trial, ritual or execution | framed | - | - | yes | Frames the crowd plus the focal point; a slow push-in; you can still walk away |
| **TALK** | a conversation | two-shot | - | - | - | Speaker and listener; the "why" of a person is readable |
| **VANTAGE** | top of a hill, tower or belfry | about -5° | about 40° | long | large | Pan across the land; settlements' far signals; the storm forecast |
| **TABLE** | at the map table at home | diorama | - | - | - | The land as a living miniature; village and people powers (influence rungs 2-3, r3 section 7) |

The explore numbers are first guesses computed from geometry `[run]`; the look board and play decide them. Explore at -10°/50°/8 m puts the horizon about 30% down the frame, with your character at about 25% of the height.

**Controls** `[web]` `[design]`:
- **Landscape.** Enea's floating joystick on the left and action buttons on the right stay `[repo]`.
- **The camera follows by itself**, so Enea's "No camera thumb" rule `[repo]` holds by default. Dragging any empty area turns it, as in Genshin, and it re-centres after you let go (a "free move zone"). Pinch changes distance within bounds: the "bounded" part.
- **Movement stays steady while the camera turns.** Movement is relative to the camera, snapped to 45° (Suzy Cube), so turning the camera doesn't make you drift.
- **Journey's camera designer's rules** `[web]`:
  - honour the player's intent;
  - rays ("whiskers") keep you in view;
  - rise over hills, don't swing away as if they were walls;
  - keep a gap so the lens never clips into you;
  - no sharp cuts;
  - offer settings to tone movement down.

  His opening warning, "Dynamic third-person cameras are the hardest to design", is why section 9 starts with a prototype on both phones.

---

## 5. Build the world for the horizon

- **Horizon signals** `[design]`. Every settlement has a far version driven by the world kernel, so its life reads at 300-800 m:
  - a silhouette by people and age (Enea's building families);
  - smoke (hearths versus a burning);
  - bells, banners, and torches at night;
  - a storm wall over a folded district.

  This is r3's legibility layer at landscape scale.
- **Backdrops.** Distant mountains and the other lands become silhouette layers in the haze, as in Omno. The veiled third land sits on the horizon.
- **Draw distance and cost.** The measured jump (267 → 498 draw calls) has to be clawed back:
  - fog;
  - level of detail;
  - impostors for forests;
  - merged village meshes;
  - GPU crowds (r3).

  Target: the same budget as today, tested after 20 minutes on both phones.
- **Renderer.** Native Mobile renderer: depth of field, glow, and post passes for god rays and colour grading. Height fog plus fog cards in place of volumetric fog.
- **Look.** Omno's lesson, adapted: simple lighting, and spend the budget on atmosphere. Enea's own look pillars already say this `[repo]`: "atmosphere done through lighting, fog, colour grading and gentle bloom". The web renderer is what held that back.

---

## 6. The playable format: a person inside a living civilisation

**The loop:**

```
   NOTICE  ─────────────►  GO  ─────────────►  WITNESS / ACT  ─────────────►  CONSEQUENCE  ──┐
   a horizon signal,       walk or ride          talk, give evidence, bribe,     the chronicle,   │
   a rumour, the           (gather and fight     protect, join, steal, preach,   your standing,    │
   chronicle, a storm      on the way: Enea's    lead - or just watch            who loves or      │
   forecast                loop)                                                 hates you         │
        ▲                                                                                          │
        └────────────────────  YOUR OWN LIFE: home, craft, trade, family, companions  ◄───────────┘
```

**Sessions** (Enea: "Short tasks for 2-minute stops, and long goals for long sessions" `[repo]`):

| Length | What happens |
|---|---|
| 2 minutes (a train stop) | Open the app. The chronicle: "While you were away: frost in Holtorfen; the elder blames the Old Holtorfen folk; a trial at dusk". Answer one rumour, or stock the market stall. Close |
| 15 minutes | Walk to Holtorfen as the light goes. From the ridge (VANTAGE) you see torches gathering. In the square (WITNESS), talk to whoever spread the rumour, bring the evidence you have, bribe the judge, or leave. The outcome enters everyone's memory, including yours |
| 60 minutes | A storm expedition into the year it came from, a feud settled by the sword (FIGHT), or a season at the map table (TABLE) steering your village through a hard winter |

**Two friends.** Before your lands connect, Enea's land is lights across the strait. Once they connect, you can see each other's settlements burning, thriving or worshipping on the horizon. That exists only with a horizon camera.

---

## 7. Singled out: hanged, burned, exiled or worshipped

Hilmi, 28 Sep `[chat]`: "it would genuinely be so entertining to play a game where we witness a random group get hanged/burned/ worshipped ect depending on the eras and circumstances."

**It should feel random, but it shouldn't be random.** History gives a model that players can read afterwards `[web]`:
- **Oster (2004).** Witch trials in Europe rose in colder periods (the Little Ice Age) and in years of slower growth, even after controlling for weather. Her example: after the cold May of 1626, peasants in Zeil called for new persecutions.
- **Jedwab, Johnson and Koyama (2019), on the Black Death.** Negative shocks raised the chance of persecuting a minority. But the worst-hit cities persecuted *less* where the minority was economically needed. Persecution was more likely where conspiracy beliefs were stronger.

**The rule set** `[design]`. It lives in the kernel's social layer (r3 L1-L3), so it is deterministic and explainable:

```
 risk that a group is singled out  rises with:  a recent shock (frost, failed harvest, plague, storm damage)
                                                how "other" the group is (storm people, foreigners, heretics, the Tethered)
                                                the age's belief in plots and curses (a value per age)
                                                rumour exposure (who told whom: Talk of the Town)
                                                the elder's or priest's stance
                                   falls with:  how much the village needs them (the only smiths or millers)
                                                a shock so severe that everyone is needed
 what happens is chosen by the age's law and values:
      exile · pillory · trial by ordeal · hanging · burning · drowning        or, if good fortune followed their arrival:
      veneration · a shrine · pilgrimages · the group made sacred (and, generations later, possibly torn down again)
```

- **Storm people are the natural out-group.** In a devout, fearful age they may be burned as demons. In an age that honours ancestors, the same district may be worshipped as returned forebears. This is the S1b follow-up: a storm fold decided by values, not just by land.
- **Your levers:**
  - find and show evidence;
  - trace and discredit the rumour's source;
  - bribe or pressure the judge;
  - hide the group, or free them at night;
  - redirect blame (the illicit route);
  - join the mob;
  - preach their holiness.

  Every outcome enters the chronicle with its reason.
- **Staging and content (D2 in r3).** The WITNESS framing can show it close. The VANTAGE framing can show it as smoke over the next village, seen from the ridge, which is often the stronger image. For the age rating: PEGI 12 covers non-realistic violence towards human-like characters, and PEGI 16 applies when it looks as it would in real life `[web]`. A stylised, low-poly treatment plus staging choices keeps you in control of the rating. You and Enea decide the ceiling.

---

## 8. What happens to Enea's camera and code

| | `[repo]` today | Proposal |
|---|---|---|
| `camera/follow_camera.gd` | One fixed framing, facing north | Becomes the BUILD framing and the basis for FIGHT, inside a camera director with blends |
| Title screen camera | Already low, with haze and depth | Proof the world holds up close. It becomes the reference shot for EXPLORE |
| Character creator, 13 outfits | Seen at ~15% of screen height | Seen at ~25% while exploring, and full frame in TALK and WITNESS. His work pays off more |
| Regions (256 m, 192 m playable) | Built to be seen from above | Need horizon backdrops, far versions of neighbouring settlements, and edges hidden by terrain and haze |
| Web build, Compatibility renderer | Published | Native Mobile renderer (r3 D4) |

---

## 9. Deciding it well

1. **A look board of the real game** (vision rung). Enea's project rendered in each framing (EXPLORE, FIGHT, BUILD, WITNESS, VANTAGE), at dawn and dusk. That needs Godot 4.7.2 on this PC, because the published web build is a release build and ignores the dev camera arguments `[run]`. **This needs your permission to download** (see the note below).
2. **A playable camera prototype on both phones.** Explore, fight and build framings with blends, the drag-to-orbit and re-centre, plus one horizon signal (smoke over the next village). You and Enea each play 10 minutes. Feel can only be judged in the hands.
3. **Decisions:**
   - D5 (Enea): the living camera, or keep the fixed angle;
   - D2 (both): content ceiling for singled-out groups;
   - the side-view alternative, recorded as considered and rejected unless Enea wants it.

**Download needed for step 1:** `Godot_v4.7.2-stable_win64.exe.zip` from github.com/godotengine/godot/releases (the official release, roughly 60-70 MB), unpacked outside the repos. It is not installed system-wide.

---

## 10. Sources `[web]`

- Journey's camera designer: https://gdcvault.com/play/1020460/50-Camera · https://www.gamedeveloper.com/design/video-50-common-game-camera-mistakes----and-how-to-fix-them
- Omno: https://80.lv/articles/omno · https://80.lv/articles/omno-developing-an-indie-game-for-kickstarter · https://en.wikipedia.org/wiki/Omno
- Godot renderers: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html · https://github.com/godotengine/godot/issues/110383
- Kingdom: https://gonintendo.com/archives/302237-kingdom-two-crowns-dev-explains-how-they-made-a-strategy-side-scroller · https://www.gamedeveloper.com/business/indie-publisher-raw-fury-has-acquired-the-rights-to-the-i-kingdom-i-franchise
- Sky's controls: https://developer.apple.com/news/?id=zm47it7t · https://thatgamecompany.helpshift.com/hc/en/17-sky-children-of-the-light/section/116-controls-navigation/
- Genshin Impact's mobile camera: https://game8.co/games/Genshin-Impact/archives/297508 · https://genshin-impact.fandom.com/wiki/Settings
- Mobile camera practice: https://www.gamedeveloper.com/design/third-person-camera-design-with-free-move-zone · https://www.gamedeveloper.com/design/lessons-from-suzy-cube-mobile-controls-that-feel-great
- Breath of the Wild's "gravity" and towers: https://www.nintendolife.com/news/2017/10/zelda_breath_of_the_wilds_ingenious_design_is_all_about_triangles_apparently · https://www.gamedeveloper.com/design/breath-of-the-wild-open-world-analysis-gravity-to-go-forward
- The war table (a strategy layer inside the world): https://dragonage.fandom.com/wiki/War_table
- Persecution research: https://www.aeaweb.org/articles?id=10.1257%2F089533004773563502 · https://link.springer.com/article/10.1007/s10887-019-09167-1 · https://cepr.org/voxeu/columns/pandemics-and-persecution-minorities-evidence-black-death
- PEGI labels: https://pegi.info/what-do-the-labels-mean

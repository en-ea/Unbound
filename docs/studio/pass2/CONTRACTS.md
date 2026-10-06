---
title: "Pass 2 contracts - what the lead and the two helpers agree on"
created: 2026-09-30
type: contracts
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: stage 0; binding for helpers A and B; changes only by the lead, announced to both
next_step: helpers A and B build against these; the lead implements the rules side behind them
---

# Pass 2 contracts

The plan is `plan/PASS-2-PLAN-2026-09-30.md` in the studio repository. Every helper brief gives its base commit.

## Branches and files

| Who | Branch / worktree | Owns (may create and edit) | May add a marked hook to | Must not edit |
|---|---|---|---|---|
| Lead | `studio`, main clone | `sim/village, crime, director, runtime, state, justice, storm, view, world_actions`, `sim/perception.gd`, `player_acts.gd` | any of Enea's files | - |
| A, "People you can meet" | `studio-pass2-a`, `Temp/unbound-pass2-a` | `residents.gd`; the UI parts of `live.gd` (cue, buttons, feedback); `stage.gd`, `stage_props.gd`, `props.gd`; new `resident_talk.gd`, `resident_lines.gd`, `resident_react.gd`, `resident_anims.gd` | `state/npcs.gd` (`get_def`), `state/quests.gd` (`talk`), `ui/hud.gd` (`open_dialogue`), `tools-src/make_voices.py` (new generic voices only) | anything under `sim/` except reading it; `session.gd`; `save.gd` |
| B, "Foundations and proof" | `studio-pass2-b`, `Temp/unbound-pass2-b` | `sim/save.gd`, `session.gd` (seed only), `sim/conformance.gd`, `sim/golden_data.gd`, new `sim/sweeps.gd`, `sim/golden_gd.gd`, `web_probe.gd`, `sim/*_test.gd` it adds | `export_presets.cfg` (exclusions only) | the rules files above; `live.gd`; `residents.gd` |

A marked hook is one to three lines with a trailing `# studio` comment. It keeps Enea's behaviour exactly unless the studio case applies. Every file is under `game/scripts/studio/village/` unless a path says otherwise.

## The resident view (`sim/view.gd`; the lead's, read-only)

Presentation reads residents only through this contract:
- `describe(v, id)` returns:
  - identity: `{id, name, sex, age, age_group ("child"|"adult"|"elder"), role, lineage, home}`;
  - state: `alive, present, held, authority, priest, forebear, outsider, marks, epithet`;
  - `mood`: `"calm"|"wary"|"hostile"|"afraid"|"grieving"|"hungry"|"uneasy"`;
  - `activity`: `{verb, place, moving, since, until}`;
  - `toward_player`: `{met, feeling -100..100, memories:[token]}`;
  - `protected` (true for Enea's authored characters, from stage 2).
- `activity.verb` is one of: `walking, sleeping, eating, at_home, visiting, farming, herding, woodcutting, hunting, gathering, milling, smithing, praying, fetching_water, chatting, trading, loitering, travelling, hiding, held, away, idle`. New verbs are only appended.
- Memory tokens now: `met, freed_by_you, angered`. Coming: `you_testified, you_offered_coins, you_planted, saw_you_plant, hit_by_you, saw_you_hit, told_about_you, helped_by_you`. Unknown tokens are ignored.

## Actions (`sim/world_actions.gd`, `player_acts.gd`; the lead's)

- **The call:** `PlayerActs.request(player, registry, verb, resident_id, parameters) -> result`. It is the only door for presentation.
  - `talk` works now and returns `{accepted, outcome: "first meeting"|"talked", target}`, or `{accepted: false, reason}`.
  - `strike`, `shove` and `give` answer `"not yet"` until stage 2. Their parameters will be `{press_id}` (a swing id from the fighter, so a re-delivered swing is a duplicate) and `{item, count}` for give.
- **Event verbs stay where they are:** `live.gd _act(verb, parameters)` for listen, inspect, testify, bribe, plant, offer, free and shield. A may change how they are offered (the UI), never what they send.
- **The player's standing** with each resident lives in `runtime.acquaintance[str(id)]`: `{met, feeling, memories}`, written only by the rules.

## Settings

`Settings.living_village` (default true in studio), with the "Living village" row in Settings. Off means no residents, no events and Enea's day clock, and the village waits unchanged. Presentation must do nothing when `VillageSession.active` is false.

## Coming from the lead in stage 1 (build for them now)

- **A new runtime event type, `"incident"`,** with stagings of new kinds appended to `staging.gd KINDS`: `theft, quarrel, kindness, alarm, gathering`. They are small: 2-6 people, walk_to, stand, gesture, carry, react and leave beats, usually 5-30 minutes.
  - A makes the stage play them.
  - B makes `save.gd valid()` accept `"incident"`.
- **New props appended to `staging.gd PROPS`:** `goose, sack, basket, bread`. A builds them (low-poly, `props.gd` style, one mesh each).

## The save (for B)

- **Save only what the future needs:**
  - the runtime;
  - people (dead or faded people without beliefs, feelings, grudges or plan);
  - households, lineages, the director, storms, the schedule, pending acts;
  - open crimes and cases;
  - `events`, all for now (the lead adds trimming with an id offset if the budget needs it; ask);
  - only the stagings that an open runtime event, pending act, hearing or rite refers to.
- **Never saved:** past stagings, or layout tables the game recomputes: `homes, place_*, dist2, n_places, pl_*, role_work` (recompute with `Village.make_places(V, layout)` after decode; the layout is `village.gd MEADOW`).
- **The encoding may be made compact.** Old saves (today's format) must load.
- **Budget:** a 150-game-day village under 100 KB; 1,000 days under 250 KB. Any record that stops a budget being met is reported to the lead, not dropped.
- **The canonical check** stays true: a save, a load and a continuation equal the unbroken run, byte for byte in the canonical state (`lifecycle_test`, `runtime_test`).

## Checks every milestone runs

- Headless import clean.
- `run.gd -- village/sim/conformance`: goldens, live twin, storm twin.
- `village/sim/contracts_test`, `runtime_test`, `lifecycle_test`, `actions_test`.
- `--studio=village/live --village-checks --test-save=<unique>`: 20 normal save and input assertions.
- `--village-soon --village-rescue-test --test-save=<unique>`: rescue boundaries.
- Enea's `--defencetest`, `--lab --packtest`, `--lab --bandittest`, `--lab --pyrotest`, `--region=forest --sealtest`, with no script errors.
- A smoke render.

Godot: `C:/Users/hilmi/AppData/Local/UnboundStudio/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (windowed: `..._win64.exe`). Test saves always use `--test-save=<unique name>`; never the owner's `save.json`.

## Stage 2 additions (lead, 30 Sep)

- **The phased day** (`village.gd begin_day`/`run_phase`, `runtime.gd advance`):
  - `v.day` is "today" all day long;
  - `Runtime.next_dawn(v)` gives the next midnight;
  - `Runtime.set_player(v, present, x_dm, z_dm)` is written by `live.gd`.
- **Incidents** (`sim/incidents.gd`): runtime events of type `"incident"` whose deadline is their end. Kinds: `theft` (`done`/`abandoned`), `quarrel` (`words`/`blows`), `kindness`. They are staged only while the player is present.
- **World verbs** (`sim/world_actions.gd`):
  - `square_up`, `strike` (`{press_id, damage}`), `shove`, `give` (`{item, count}`, with context `have` and `food`).
  - The rules refuse children ("never a child") and Enea's characters ("not them").
- **Reactions** (`sim/reactions.gd`):
  - they are written to `runtime.reactions[str(id)] = {state, since, until}` (game minutes);
  - the one struck: puzzled, startled, protest, flee, call_help, fight_back, plead, down;
  - onlookers: intervene, shout, flee, back_away, watch.
- **In the game:** `provoke.gd` (`square_up(id)`, `landed()`, `witnesses()`) and `fight_target.gd` (group `"enemy"`, only while squared up).
- **Codes:** runtime results carry a `code`; key presentation on it, never on the prose.
- **The view:** `describe` gains `look` (outfit index), `protected` and `authored`.
- **Enea's characters** (`sim/authored.gd`) are residents with `authored` set to their Npcs id.
  - Presentation never makes a body, talk spot or stage actor for them.
  - `Village.rebuild_places(V)` replaces `make_places(V, MEADOW)` after a save is decoded.
- **Memory tokens:** `threatened_by_you`, `hit_by_you`, `shoved_by_you`, `saw_you_hit`, `saw_you_shove`, `gift_from_you`, `told_about_you`, `you_shielded`.

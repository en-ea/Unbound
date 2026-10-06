---
title: "Pass 2 - the village around you: what was built, what it measured, what is left"
created: 2026-09-30
type: report
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: engineering verified on this PC, except the web frame measurement; owner play pending
next_step: Hilmi plays the studio build (section 6) and decides what to tell Enea; the lead measures web frame times with the browser pane showing
---

# Pass 2: the village around you

Plan: `plan/PASS-2-PLAN-2026-09-30.md` (studio repository). Contracts: `docs/studio/pass2/CONTRACTS.md`. Programme: `docs/studio/MASTER-GOALS-r2.md`.

## 1. Verdict

`[run]` Walk into the village and something happens near you within minutes: a quarrel at the well, a neighbour helping carry a sack, children playing, a thief who thinks better of it because you are watching. Anyone can be talked to. You can give them something, or pick a fight with a grown-up, and they answer as themselves:
- they can be puzzled, startled, protest, flee, call for help, plead, go down, or fight back through Enea's parry;
- onlookers who could actually see it step in, shout, flee or back away;
- one of them tells the elder;
- the right people remember it later.

Enea's four characters are residents the village knows about, and their stories are protected.

`[run]` Every check passes at `951b215` (section 4). In the web build on this PC, the whole game runs at about 20 fps in the browser pane. Almost all of that is the world itself: the title screen alone is 46 ms a frame, and the villagers cost 0.8 ms. **The iPhone is still to be measured.**

`[repo]` All work is on `studio`. It is pushed once, at the end of the pass, as Hilmi authorised. There has been no merge into `main` and no message to Enea.

## 2. What the player gets

```
 you walk into the village ──> it knows you are there, and your eyes count
        │
 quiet for about 3 minutes of play ──> the director brings a real tension near you
        │                                  theft · quarrel · kindness · chat · help · play
        │                                  (never the same kind twice running)
        v
 a small scene plays where you can see it          a thief you are watching turns away
        │
 talk to anyone: a line from who they are and what they remember of you
        │    "Give..." (coins or food; a gift softens a grudge)
        │    "Pick a fight" (grown-ups only; never a child, never Enea's characters)
        v
 Enea's lock-on and fighter. Each blow:
   the one struck answers in one of 9 ways, by temperament and how hurt they are;
     a fight back is a real exchange: wind-up, glint, blow, and you can parry it
   those who could see (his sight model; walls block) answer in their own way
   one tells the elder within the hour; everyone involved remembers
   saved at once: a reload, midnight, leaving and coming back keep it all
```

## 3. What was built

| Commit | What |
|---|---|
| df6f214, 58621d9 | Enea's `main` and `camera-test` merged in (morning) |
| 752be7f | Stage 0: the Living village switch in Settings, the resident view, one door for world actions, contracts |
| 755caea | **The phased day** (deeds happen at their minute), the player's eyes count, **the director brings things near**, incidents staged, storms off, one reputation record |
| fc17fec, 6df241f | **Provoking:** square up, strike, shove, give; reactions; witnesses by Enea's sight model; reports to the elder; an in-game fight target |
| b8b46af | Helper A, stage 1: talk to anyone, lines, events said rather than pressed, daily loops, incident stagings |
| 2811138, 08b49fb | Stable result codes; **Enea's characters as protected residents** |
| 46b0f00, cc1b0fb | The lively probe; gentle scenes (chat, help, play); attention every hour |
| 969f45f | **Enea's `camera-test` 4a1df30 merged** (hunting, carcasses, ox cart, talents, quest log, flick buttons, homes): 9 conflicts, both sides kept |
| 325a4d2, 37b4781 | **Helper B merged:** save format 2 (a 150-day village is 26 to 27 KB on disk; it was 690 KB), a village per new game, a lean web export, the web probe, GDScript sweeps. Plus the fix for dictionary order |
| d88b0c9, b8ca397 | **Helper A, stage 2 merged:** reactions acted out, fight-back through Enea's defence, Pick a fight and Give, outfits by trade, the village bell |
| 95e4cd7 | Cases no longer stuck when a hearing or a sentence is cancelled |
| 951b215 | Fight-back lasts a real exchange; probes hardened |
| cad1656 | The studio web build in `web/` (a preview of `studio` shows the living village) |

## 4. Checks at 951b215

| Kind | Check | Result |
|---|---|---|
| Rules, headless | contracts, save, runtime, lifecycle, actions, phased, provoke | all PASS `[run]` |
| | conformance (golden, live villages, storms) | PASS `[run]` |
| | save budget, 3 seeds: 150 days and 1,000 days | PASS: 26 to 27 KB and 74 to 109 KB on disk (budgets 100 and 250) `[run]` |
| | sweeps, 4 villages x 100 years, batch and runtime mode | PASS, no stuck cases `[run]` |
| The game, real input | village checks (save, recovery, pause, input, merchant Buy, bribe) | 20 of 20 `[run]` |
| | provoke integration (a tap never hits; a swing lands once; save and load; away and back) | PASS `[run]` |
| | rescue integration (3 parts) | PASS `[run]` |
| | lively: 10 minutes of play in the square | first small scene at 3.5 min; clock ran fully; player present 100% `[run]` |
| | people probe: talk (3 residents, 3 different lines, the meeting remembered) | 0 failures `[run]` |
| | people probe: provoke (Give, Pick a fight, 9 answer states, the parry, knocked down, onlookers) | 0 failures `[run]` |
| | people probe: daily (work, meals, chatting, indoors at night, back in the morning) | 0 failures `[run]` |
| Enea's own | `--lab --packtest`, `--lab --pyrotest`, `--lab --bandittest`, `--defencetest`, `--fighttest`, `--gathertest` | all ran clean (they print figures, not verdicts) `[run]` |
| Web, on this PC | save and reload on the web platform | 7.2 KB, saved in 11 ms, loaded in 8 ms, the same after reload `[run]` |
| | frame times: 60 s in play in the village, the browser pane showing (1 Oct) | 19.6 fps; frames p50 49.1 ms, p95 56.9 ms; video memory 94 MB; 430 draw calls. The title screen alone: p50 45.9 ms. **The villagers' own cost: p50 0.8 ms, p95 1.0 ms.** Hitches: one frame of 1,041 ms around pressing Play; the first villager body built in 267 ms `[run]` |

## 5. Found and fixed on the way

| What | Effect in play | Fix |
|---|---|---|
| The save's validator refused the new incident events `[run]` | After the first small scene, a reload lost the village (the player's belongings were kept) | Helper B's format 2 accepts them; rescue integration confirms (325a4d2) |
| Format 2 wrote dictionaries as JSON objects, whose keys JSON sorts `[run]` | After a reload the order differed. Past 256 actions a recent receipt could be dropped, and a repeated press counted twice | A plain object only when its keys are already sorted (37b4781) |
| A hearing or sentence cancelled because a witness or bystander had gone `[run]` | Its case stayed open for good (7 in 4 villages x 100 years) | Put back to the next dawn, 3 times, then cold (95e4cd7) |
| The stage did not know the scene kinds chat, help and play `[repo]` | Those scenes were refused rather than shown | Added (b8ca397) |
| A fight-back lasted about 5 real seconds `[run]` | One blow, then over: never parryable | 15 seconds; gives up past 12 m (951b215) |
| The windowed probes froze when another desktop window had focus; Enea's boars and wolves killed the probe's idle player; some provoke checks were only printed `[run]` | Flaky or hollow results | Probe runs ignore focus-out; creatures are cleared per scenario; the checks are real (951b215). Lesson L015 in the studio repository |

## 6. How to play it

`[repo]` On this PC, from the game repository:

```bash
node tools-src/serve.js --local
```

Then open `http://127.0.0.1:8087/` (`build/web` holds the same build as `web/`). The native build:

```powershell
& 'C:/Users/hilmi/AppData/Local/UnboundStudio/tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path game
```

`[design]` A short route:
1. Walk to the square and wait about three minutes. Something small happens near you: watch who does what.
2. Talk to a few people. A child talks differently from a smith.
3. Give someone an apple.
4. Pick a fight with a grown-up, and hit them a few times. A bold one fights back: when the glint shows, press Parry.
5. Watch who saw it. Walk away, come back later and talk to them.

Settings has a "Living village" switch: off means Enea's village only.

## 7. Against the plan's acceptance

| Item | State |
|---|---|
| M1 liveliness: a scene within 10 minutes, people doing more than walking | met `[run]` |
| M1 presence prevents theft; the same theft happens when no one is there | met (phased test) `[run]` |
| M1 talk to any adult through Enea's panel; no other text | met (people probe) `[run]` |
| M1 held while away, released near the player | met in the rules (phased test); not watched in the game `[run]` |
| M1 determinism; GDScript goldens agree on PC and S10 | PC met `[run]`; **S10 not run this pass** |
| M1 invariants, 20 villages x 1,000 years | **partly:** 4 x 100 in both modes passes `[run]`; the long sweep not run |
| M1 save under 100 KB at 150 days; old saves load | met `[run]` |
| M1 Enea's flows still work | met (his six tests, the normal checks) `[run]` |
| M2 deliberate only; varied reactions; one witness chain with a report; robustness; remembered | met (provoke test, provoke integration, people probe) `[run]` |
| Performance on web (PC) and the S10; the iPhone route | web on PC measured: the villagers cost 0.8 ms of a 49 ms frame `[run]`. S10 not run; the iPhone route is section 6 |
| Stage 3 stretch: the player summoned to a hearing | not started |

## 8. For Enea when he merges `studio`

`[repo]` Studio code lives under `scripts/studio/` and `docs/studio/`. Outside those, `studio` changes these files of his, each a marked hook or a fix:
- **Hooks:** `core/settings.gd` and `ui/settings_panel.gd` (the Living village switch), `core/save_game.gd` (the village in the save), `main.gd`, `world/day_night.gd`, `player/player.gd` (an urgent village action comes before a fight), `ui/hud.gd` (the talk screen for residents), `state/npcs.gd` and `state/quests.gd` (residents' talk), `player/character_look.gd`, `tools-src/make_voices.py` (four voices).
- **Fixes:**
  - `core/safe_file.gd` (crash-safe saves);
  - `ui/safe_area.gd`, `ui/hearts.gd` and `ui/pickup_feed.gd` (clear of notches);
  - `ui/action_button.gd` (a press that opens a panel keeps its finger);
  - `ui/shop_panel.gd` (callbacks without `.unbind(0)`, which broke Buy on 4.7).
- **Set-up:**
  - `project.godot` (the VillageSession autoload);
  - `dev/dev_args.gd` (studio dev flags);
  - `export_presets.cfg` (Android presets, and the web export leaving out studio test tools);
  - `tools-src/serve.js` (`--local`), `tools-src/make_bell.py`, and four new voice files.
- **Build files:** `web/` holds the studio build. Whoever merges keeps their own.

## 9. Next

1. **The iPhone.** Watch the two hitches measured on the PC: about 1 s when Play is pressed, and 267 ms for the first villager body (shader and mesh preparation, worth warming at load). The web build is a release build, so the web probe cannot skip the title: press Play within 10 seconds of loading.
2. **Live observation** (lesson L015): position, health, clock rate, focus and errors streamed to the agent, and readable by Hilmi. HQ's foundations v2 (sections 4 and 5) already design this contract. So Unbound builds a Godot adapter to it once HQ's Stage A has settled it, not a studio-shaped tool ahead of it.
3. **Enea's hauling** (carry, drag, cart) as the base for carrying a person (G08) and captivity (B4). **His quest guide beam** as the way a gathering catches the eye.
4. The stretch left from this pass: the player reported and summoned to a hearing; an apology or restitution as a way back.
5. The S10 golden check and the long sweep, at the next milestone.

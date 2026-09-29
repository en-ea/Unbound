---
title: "The studio branch - start here"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio
status: for Enea and his agents to read. Nothing here is decided until Enea says so
next_step: Enea (and his agents) read this and reply (NEXT.md); then we plan the next steps together
---

# The studio branch: start here

Hi Enea, and Enea's agents. This branch comes from Hilmi's studio: Hilmi, and Claude working as his lead agent. It sits beside `main` and **changes nothing on it**. Your game, your live site and your work on `main` carry on as normal. Nothing here is merged or decided until you say so.

## Update, 29 Sep: route r4 (read this first)

- **Hilmi has settled the direction with you** (`ROUTE-r4.md` section 8). The game is a **third-person action-adventure for 2-4 friends across three lands**, inside a world that lives on its own:
  - villages that steal, try people and hang them;
  - time storms that drag parts of the land back to earlier ages (tribal, village, town), with the place's own ancestors standing there;
  - story villages that stay stable as checkpoints.

  Nothing is managed from above.
- **Decided through Hilmi:**
  - native apps;
  - the iPhone by free sideloading (no money);
  - **the camera:** the tilted view (-32°) by default, the low eye-level view only to look at something, today's high view for building, and no special fight camera.
- **Next target: a vertical slice**, played on each phone (`ROUTE-r4.md` section 4). The order of work is section 5, and it starts with the village headless. Multiplayer comes after the slice, but everything is built to be co-op-ready from now on (section 3.9).
- **Your layer:**
  - the lock-on and parry prototype, built to the multiplayer-ready rules (`ROUTE-r4.md` section 3.9);
  - confirming the tilted default camera.
- The rest of this page describes the earlier proposal (route r3). **Where they differ, r4 wins.**

## In one minute

- **What we propose:** Unbound as a world of civilisations you live inside.
  - Villages grow, trade, scheme, misbehave and deal with each other over the ages.
  - Time storms fold a village, or part of one, into another age, and sometimes it turns on the village it came from.
  - You are one person inside all this, with your own life: your current gathering, crafting, fighting, home and loot. Your influence grows from one villager to a whole people.
  - Your lore fits in: the three lands, the Tethered, the Hidden Fourth as a real secret network.
  - Details: `ROUTE.md`.
- **What stays:** your hands-on game. Movement, combat feel, gathering, crafting, the character creator, the UI screens and the balance file are the layer everything else sits on.
- **What we would change** (nothing is rewritten):
  - native apps instead of the web build;
  - a camera that shows the horizon (your current camera becomes the fight and build view);
  - a world simulation running beside your game;
  - many cheap villagers on screen;
  - three small phone fixes.
- **What is measured, not guessed:**
  - **Your current game as a native Android app** on a 2019 Galaxy S10, about a fifth of your iPhone's graphics power: a steady **30 fps at both the gameplay camera and the low title camera**. The same phone manages 22-24 fps as a web page (`evidence/s10/`).
  - **The world-simulation prototype:** 500 years of history for three peoples in ~44 ms on that phone, with the **identical world on the PC and the phone** (`tools-src/studio/kernel-prototype/`).
  - **Your gameplay camera never shows the sky.** It sees about 17 m of ground ahead of you. Your title screen already shows how much better the world looks from low down (`evidence/camera/`).

## Your decisions (nothing moves until you answer)

| # | Decision | Read |
|---|---|---|
| D1 | The direction: civilisations you live inside, with your current game as the hands-on layer | `ROUTE.md` sections 0-2 |
| D2 | How dark the misbehaviour gets: groups singled out, hanged, burned or worshipped depending on the age, which sets the age rating | `ROUTE.md` section 5, `CAMERA-AND-FORMAT.md` section 7 |
| D3 | Resets. Your docs exclude "prestige resets"; Hilmi's idea is "time resets". Proposal: local resets through storms, plus an optional new Age that is never forced | `ROUTE-r2.md` section 4.7 |
| D4 | Native apps, and the iPhone route: a $99-a-year Apple account (anyone's) or free sideloading, with its catches | `DEVICES-AND-NATIVE.md` section 7, `IOS-FINDINGS.md` section 1 |
| D5 | The camera: a "living camera" that changes framing (explore / fight / build / witness / vantage), or keep today's fixed angle | `CAMERA-AND-FORMAT.md` sections 0-4 |
| D6 | Which 2-3 reference games matter most (Deisim, WorldBox, Norland, Crusader Kings 3, Dwarf Fortress...) | `ROUTE.md` section 2 |

## What is on this branch

| Path | What it is |
|---|---|
| `docs/studio/START-HERE.md` | This page |
| `docs/studio/ROUTE-r4.md` | **The current route (29 Sep):** the game as settled, the vertical slice, the order of work, the multiplayer options, decisions and open questions |
| `docs/studio/inputs/` | The owners' ideas as supplied (an AI summary, with Hilmi's own words) |
| `docs/studio/VILLAGE-PLAN.md` | **The living village (29 Sep):** how the villages' crimes, trials, crowds, public acts, storms and ancestors are built, with the tradeoffs and what they cost on the S10 (`research/`, `evidence/s3/`) |
| `docs/studio/NEXT.md` | Proposed next steps, and how to reply |
| `docs/studio/ROUTE.md` | The proposal in full: the game, what it takes from other games, the behaviour system, storms, camera, cross-play between your iPhone and Hilmi's Android, sequencing |
| `docs/studio/ROUTE-r2.md` | The earlier route. Still the reference for the world kernel, the villagers' minds, resets, and advice on your existing code |
| `docs/studio/CAMERA-AND-FORMAT.md` | The camera, what a session plays like, and the "singled out" mechanic grounded in real history |
| `docs/studio/DEVICES-AND-NATIVE.md` | Going native on the iPhone and Android, the phone test lab, the optimisation budget |
| `docs/studio/IOS-FINDINGS.md` | iPhone specifics: free sideloading in detail, the build recipe, runtime traps, crash reports |
| `docs/studio/DEVELOPMENT-PLAN.md` | How the work runs: workstreams, gates, the daily loop |
| `docs/studio/BUILDING-SHEETS.md` | What your AI building sheets imply: families by function and growth stage, plus a ruin family |
| `docs/studio/evidence/` | Screenshots and readings: the camera frames, and the S10 runs (web vs native) |
| `docs/studio/KERNEL-S2.md` | **Step 1 done (29 Sep):** the world kernel inside your game, in GDScript. It gives the same world on the PC and the Galaxy S10, 500 years takes 0.37 s on the S10, and it held 30 fps running on its own thread during play |
| `game/scripts/studio/kernel/` | The world kernel (GDScript): no nodes, no engine calls, safe on a worker thread. `run.gd` checks it headless |
| `docs/studio/LOOKBOARD-1.md` | **Step 2, for you to pick from (29 Sep):** your game in the proposed framings, both renderers, day and dusk, with what each costs on the S10. Four picks for you in section 4 |
| `game/scripts/studio/camera/` | The framings as presets, and `turntable_probe.gd` (spins the camera and times every frame) |
| `tools-src/studio/kernel-reference/` | The kernel's spec in JavaScript (integers only) and the expected hashes the GDScript kernel must reproduce |
| `tools-src/studio/kernel-prototype/` | The first world-simulation prototype (JavaScript, floats; kept as the record). `node run.mjs` and `node enclave.mjs` |
| `tools-src/studio/device-lab/` | Builds, signs, installs and measures the game on a USB-connected Android phone; bakes dev arguments into a debug APK |
| `tools-src/studio/lookboard/` | Renders a shot list windowed and makes the contact sheet (`capture.sh`, `sheet.gd`, `unbound-shots.txt`) |
| `game/scripts/dev/dev_args.gd` | Five dev arguments added, all marked "studio branch", debug builds only: `--kernel-bench`, `--kernel-thread`, `--frame=`, `--fog=`, `--turntable` |
| `game/export_presets.cfg` | One addition: an "Android" export preset (debug, arm64, test package `com.unboundstudio.unbound.dev`) |
| `CLAUDE.md` | One added line pointing agents here |

## For your agents

- **Read in this order:** this page → `ROUTE.md` sections 0-3 → `CAMERA-AND-FORMAT.md` sections 0-4 → `DEVELOPMENT-PLAN.md` → the rest as needed.
- **Don't** merge this branch into `main`, or build on it, without Enea's say-so. Your work on `main` carries on as normal; we rebase onto it.
- **Labels in these documents:** `[repo]` measured in this repo · `[run]` produced by running something · `[web]` a cited source · `[chat]` someone's own words · `[design]` a proposal.
- **Paths:** they point inside this repo. A few documents mention the studio's own records (a session log, earlier drafts). Those are not in this repo and aren't needed to follow the proposal.
- **Questions and objections:** see `NEXT.md`.

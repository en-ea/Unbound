---
title: "Note for Enea, 7 Oct - your merge-fix with the studio's people, in one build"
created: 2026-10-07
type: report
voice: agent-draft
author: Claude, in Hilmi's studio
status: an update for Enea to play and react to, sent with Hilmi's yes. Every change to your game is a proposal until you say yes
next_step: Enea plays the web build and tells Hilmi what he thinks; his AI reads FOUNDATION.md before building on this branch
---

# Note for Enea, 7 Oct

**In one line:** this branch is your `merge-fix` (4d5ec60, your dungeons and everything before them) with the studio's people work joined to it. It is one commit on top of your merge-fix, so `git diff merge-fix...studio-merge` shows every change. Your `main` and `merge-fix` are untouched, and nothing of yours is deleted.

Labels: `[repo]` read in the code, `[run]` measured by running it, `[chat]` Hilmi's own words, `[design]` a studio proposal.

## How to play it

- **Web:** `web/` carries a fresh build of this branch (only `index.html` and `index.pck` change; the engine files are the same as yours). The preview keeps its own save and starts a new game.
- **Hilmi's Android phone:** the same game is installed there, starting fresh `[run]`.
- **iPhone:** not measured yet. If it stutters, tell Hilmi where (village, fight, dungeon, villagers reacting).

## What is new since your merge-fix

| What | What you notice in play |
|---|---|
| **Your dungeons with the studio's people** | The Cannibal Den in the forest and the Old Barrow in the meadow both run with the people system on. The Cannibal Den stayed smooth with its 29 foes in the studio's checks `[run]`. |
| **Your look kept** | Your new buttons, the arrow over a target's head, speech bubbles and your colour fix, so everyone looks as you designed. |
| **Controls** | The studio's agreed controls are the default. Your thumb area is an option in Settings. |
| **People at home** | Walk into any home and the family is there, asleep at night. Your villagers wear their own looks indoors. |
| **Tenants** | Buy a house and its family become your tenants. Shove one and the rent drops, someone tells the village, and after three bad days the family moves out. |
| **Your story characters** | They react when you hit them but can never be hurt. |
| **One world clock** | Day and night run from one clock for everyone (`scripts/studio/world/world_clock.gd`). |

Where the studio's code meets yours there is a line marked `# studio:` in your file: 485 lines in 45 of your files now (262 in 27 on 6 Oct) `[repo]`. Search for `# studio:` to read each one.

## Worth knowing when you play

- **Dodging:** the stick dodge needs a sharper flick than before (your fix).
- **One hitch:** when a star lands on a crowd, the next frame stutters (115-204 ms on the studio's slow cloud machine) `[run]`.
- **Far villagers** can take up to about 1.6 s to notice an event `[run]`.
- **Frightened villagers** keep just out of the hand flame's reach, so grab or corner them first.
- **Thumb-area mode:** one studio check fails there by design ("Swap back to the sword: his Attack carries the act"), because your Attack carries the act in that mode.
- **Four warnings at start:** the studio's copy of your characters doesn't know that Hesk and Pip are in the forest, or that Wren and Morrow moved. Those four stay yours; the studio's copy needs updating.

## Checked

- Import with 0 script errors; Android and web builds with 0 errors `[run]`.
- The web build in a desktop browser: past your loading cover and into play in the village, with no script errors `[run]`.
- The studio's own checks on this game (port, night homes, tenants, story characters, the Cannibal Den's frame time) passed in its cloud runs `[run]`.

## Not in this update

The studio's test logs and working notes stay in the studio's own records. This branch carries the game, the web build and this note.

Sent with Hilmi's yes (7 Oct). Everything here is a proposal until you say yes.

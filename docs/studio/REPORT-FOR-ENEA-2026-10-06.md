---
title: "Studio report for Enea, 6 Oct - your game and the studio's work in one build"
created: 2026-10-06
type: report
voice: agent-draft
author: Claude, the desk in Hilmi's studio
status: a preview for Enea to see and react to, sent with Hilmi's yes. The direction comes from Hilmi; every change to your game is a proposal until you say yes
next_step: Enea plays the preview and tells Hilmi what he thinks; his AI reads FOUNDATION.md before building on this branch; the studio finishes the checkpoint below and refreshes this branch
---

# Studio report for Enea, 6 Oct

**In one line:** this branch is your latest game (your `main`, 8b5fbef, 4 Oct) merged with everything Hilmi's studio has built since 1 Oct. Nothing of yours was deleted. Your `main` and your live site are untouched. It is a **preview half-way through the merge**: it plays, but the controls are temporary and a few of your systems are still being joined up (section 5).

Labels: `[repo]` read in the code, `[run]` measured by running it, `[chat]` Hilmi's own words, `[design]` a studio proposal.

## 1. How to play it

- **On your iPhone:** this branch carries its own web build in `web/`, the folder Vercel serves. If your Vercel project makes previews for branches, the branch page on GitHub shows a Vercel preview link ("View deployment"). Open it in Safari.
  - The preview has its own address, so it keeps **its own save**. Your real save on your live site is not touched.
  - It starts a fresh game.
- **On your PC:** export as usual (CLAUDE.md, "Export for the phone"), then run `node tools-src/serve.js --local` and open http://localhost:8087/.
- **Not measured yet on an iPhone** `[run]`. The studio has checked this line on PC, in the cloud and on Hilmi's Android phone. This preview is its first time in iPhone Safari. If it stutters, tell Hilmi where it happened (in the village, in a fight, when villagers react). That is exactly what we need to know.

## 2. What the studio built (the short version)

Hilmi's studio took on "the people": villagers that feel alive. Under your meadow there is now:

| What | What you notice in play |
|---|---|
| **A living village** | Villagers have homes, jobs, families and a real day. They notice what you do, have feelings about it, remember it and choose what to do next, each for themselves. |
| **Reactions with consequences** | Push someone and they stumble out of your way. Hit someone, and witnesses gather, tell others and remember. Crimes can lead to justice in the square. |
| **Fire and damage on things** | Fences, benches, crates and racks can burn, get scorched or soaked, and break. People react to it. |
| **Crash-safe saving** | Every change is written to a small journal first, so a crash or a closed app loses almost nothing. |
| **Cheaper graphics** | Static scenery is batched and each character drawn as one mesh, so fewer draw calls. Each look change has an on/off switch. |
| **Touch controls for acting on people** | One thumb area does use, guard, strike and shove by how you move your thumb (section 4). |

All of it lives in `game/scripts/studio/`. Where it attaches to your code, there is a short line marked `# studio:` in your file. There are 262 of them in 27 of your files `[repo]`. Search for `# studio:` to see every one; each is a proposal you can read and remove.

## 3. Your features since 1 Oct, in this preview

| Your feature | In this preview |
|---|---|
| Glimmerdeep cave, Stonecrest Highlands, forest region | in, unchanged |
| Bow (rebuilt), sword and bow swap | works: your Swap button appears when you have a bow; with the bow out, your Attack button draws and looses (checked by touch, 12/12 `[run]`) |
| Fishing | works: tap at the shore to cast, then your Hook button (checked by touch `[run]`) |
| Shade class | its powers sit on the thumb-area arcs; not yet checked by a probe (section 5) |
| Story start, its separate save | in; the Story save runs through the studio's crash-safe save |
| Bounty boards, waystones, the big map | in |
| Homes to let, tenants, Tomas, Elsa, Nell and Bram | in, running as you built them (section 5) |
| Elk riding, Cinder the fire companion | in |
| Your new village layout (houses in a ring round the green) | **your layout wins**: the studio's villagers now read their homes, doors and pens from your buildings (spots check 4/4 `[run]`) |
| Your own character merge (fewer draw calls) | kept; the studio's merge steps aside for every character yours already joins |
| Your 4 Oct button redesign and the button editor | in the code, **hidden for now** behind the studio's thumb controls; it comes back as the frame of the new controls (section 6) |
| Your saves | a save from your 8b5fbef build converts cleanly: your six new saved kinds and your belongings all load (7/7 `[run]`) |

## 4. Controls in this preview (temporary)

```
 LEFT THUMB (your joystick)                 RIGHT THUMB (one area; how you move picks the act)
   move ............ walk                     tap ............ use (talk, a station, pick up,
   hold at the rim . sprint                                     put out a fire, finish a downed foe)
   quick flick ..... dodge that way           hold ........... guard
   tap the base .... crouch / stand           fast flick ..... strike (a sharper flick hits harder;
                                                               the hardest knocks down)
                                              slow push ...... shove
                                              arcs above it .. your class powers
```

Stamina still exists in this preview. Section 6 says what replaces it.

## 5. What is not finished in this preview

- **Controls are the interim ones** above. Your buttons are hidden, and only the bow and fishing use them for now.
- **The Shade's powers** appear on the arcs, but nobody has checked them by touch yet. While the bow is out, the class powers are not on screen.
- **Two villager systems run side by side.** Your Tomas, Elsa, Nell, Bram and the tenants still run on your code. The studio's villagers run on theirs. They will become one system (section 6).
- **The village clock** is still the studio village's clock. Caves and beds will move to one world clock.
- **One bug in your fishing code** `[repo]`: stopping during the 0.45 s cast frees the bobber while its flight tween still writes to it, so it errors every frame. The fix is one line in `player/fisher.gd`: `_bobber.create_tween()` instead of `create_tween()`. It comes in the next refresh as a marked line, and it's yours to keep or change.
- **iPhone speed is unmeasured** (section 1).

## 6. What happens next (the intentions)

Hilmi set the direction for this merge on 5 Oct `[chat]`:

> "We should have his button design but refined and with our abilites design in our position lined at the top. Sprint should be removed and made our way with stamina removed as a mechanic, then functionality should be adjusted for the setting, like pushing a villager should become a heavy attack, dismemberment (later on I assume) could become holding the heavy attack, refined sliding between buttons for better detection and more."

> "Rent and buisness is a good idea but can his things not be ported into ours? We would offer far superior performance and functionality while keeping his idea"

> "spots should be well intergrated anyways, if villages are going to be found along the world with a randomness factor then hardcoding it would be silly"

Being built now, in this order `[design]`:

1. **The new controls.**
   - **Frame:** your button cluster and editor, refined.
   - **Abilities:** the studio's ability row as an arc along the top, each with an aim preview. This covers both Pyromancer and Shade.
   - **Movement:** sprint at the stick's edge, no sprint button.
   - **Stamina goes.** Recovery time after a heavy swing, a guard that breaks under a hard enough hit, a short wait after quick repeated rolls, and the bow's draw time do its job.
   - **Heavy:** tap Heavy on a villager shoves them. Hold Heavy for the most severe act (the finish, or your stealth takedown). A longer hold is kept free for dismemberment.
   - **Sliding between buttons:** better detection, on by default.
   - Every action you have keeps a home. The bow and fishing move onto the new controls.
2. **Your residents and tenants move into the people system.**
   - Your names, rules and numbers stay, as the design.
   - A tenant's mood comes from what they actually feel and remember about you: did you help them, hit them, gift them.
   - Rent and the shops get built on the studio side from your rules.
3. **One world clock.** It belongs to the core game and is saved once. Every village catches up to it, on screen or not. Caves and beds act on it. This keeps the door open for villages found out in the world, and for co-op.
4. **Your old saves convert once**, on first load, into the studio's format.
5. **Then Hilmi plays it on his phone.** When he is happy with it, that is the end of this checkpoint, and this branch gets refreshed.
6. **Next after that:** dismemberment, on holding Heavy.

## 7. What is yours to decide

You own the game: its product, look and feel. These are the big proposals waiting on you, through Hilmi:

- the new controls, with your buttons as their frame (item 1), and stamina replaced by recovery times;
- your residents and tenants moving into the people system (item 2);
- the studio's look switches staying on: character merge, static batching, things showing their state, house variety;
- the marked `# studio:` lines in your files, every one of them.

## 8. Working together from here

**For you:**
- Play the preview and send Hilmi what you think. Feel, looks and what's confusing all count.
- **Safe to keep building now:** new regions, quests, items, creatures, buildings, art, sounds and music.
- **Please hold, or tell Hilmi first,** before changing: the buttons and HUD (`hud.gd`, `action_button.gd`, `button_editor.gd`, `controls.gd`), the player and combat (`player.gd`, `fighter.gd`, `abilities.gd`, `stamina.gd`), saving (`save_game.gd`), the villagers (`npcs.gd`, residents, lettings) and the clock (`day_night.gd`). These are the files being joined right now. A change there would mean merging again.
- The studio pulls your `main` again before the next refresh, so your new work comes along.

**For your AI:**
- Read `docs/studio/FOUNDATION.md` first. It explains the layers under the game, the rules that keep it sustainable (one route for every fact, the checked door, the save guard, the performance budgets), worked examples for adding things, and the checks to run.
- `docs/studio/FOUNDATION-CLAUDE-MD-PROPOSAL.md` is a proposed section for your CLAUDE.md. It's a proposal only; you decide.
- Edits to your own files stay as marked `# studio:` lines, so you can always see what came from the studio.

## 9. Where this came from

- This branch is a single snapshot commit on your `main` (8b5fbef). Compare it with `git diff main...studio-merge` to see every change.
- **The studio's line:**
  - a three-way merge of its pass3 build (501bffa) and your main (8b5fbef), on your 1 Oct commit 76d24ad;
  - then the merge work: crowd push, your bow and fishing reach, the foundation guide, your save conversion and your village layout;
  - and the graphics fix for your character merge.
- The studio's history and evidence stay in Hilmi's studio repository. Ask Hilmi for any record.

# Graphics from Hilmi's studio: what changed, how to switch it, how to remove it

For Enea, through Hilmi. Nothing here is yours until you say so. Everything can be switched off or removed in a minute.
Written by the studio's graphics thread, 5 Oct 2026 (graphics stages S1, S2, S4, S5; the plan is
`plan/GRAPHICS-STAGES-2026-10-04.md` in the studio's records).

## In one paragraph

Your game now draws the same world with far fewer draw calls, which is what keeps a phone smooth and cool. Your
characters draw their outfits merged (the player 5 draws instead of 43). The village's still props and houses draw a
few merged meshes per 60 m square. In the meadow at the morning view the frame went from 576 draw calls to 393 (-32 %),
and in the forest from 522 to 374 (-28 %). Nothing looks different: every stage was checked frame by frame against
yours, in place. Two things are new looks for you to judge: things that burn, soak and break (approved by Hilmi for his
build), and house variety built from your own house scripts (his build draws your houses exactly, through them).

## Your files: two marked lines, nothing else

| File | Line | What it does |
|---|---|---|
| `game/scripts/player/character_visual.gd`, first line of `apply_hero_look()` | `CharacterMerge.after_look(self) # studio: proposal (graphics S2)` | after a look is applied, the outfit is drawn as one merged mesh |
| `game/scripts/main.gd`, `_ready()`, after the VillageSession line | `StaticBatch.attach(self) # studio: proposal (graphics S1)` | once the region is built: the batching, and the switches for things and houses |

Everything else lives in studio folders: `game/scripts/studio/render/`, `game/scripts/studio/things/`,
`game/assets/studio/houses/`, `tools-src/studio/blender/`.

## The switches (project settings; also dev arguments)

| Setting | When absent | Dev argument | What it is |
|---|---|---|---|
| `studio/render/merge_characters` | on | `--studio-merge=off\|on` | characters draw merged (S2) |
| `studio/render/batch_static` | on | `--studio-batch=off\|on` | still props, houses and light scatter merged per square (S1) |
| `studio/render/thing_state` | on (Hilmi, 5 Oct) | `--studio-things=off\|on` | fences, benches, camp crates and racks burn, char, soak, flash and break (S4) |
| `studio/render/house_variety` | preset (the desk's rule for Hilmi's build) | `--studio-houses=off\|preset\|variety` | your cottage, cabin and round house drawn from the house grammar (S5): on preset they are your models exactly |

Off is your game exactly as before for that stage.

## What leaves a batch by itself (S1)

A merged mesh never hides your code's intent. Any prop that is hidden, moved or freed by your code gets its own drawing
back at once, and its square re-merges a moment later. Interactables, anything animated, unevenly scaled or using
another shader, trees and anything you can chop, mine or pick are never merged. To keep anything out on purpose, put
it (or a parent) in the group `studio_no_batch`.

## Copies of your shader to keep in step

`game/scripts/studio/render/batched_solid.gdshader` and `thing_solid.gdshader` are copies of your
`shaders/foliage_solid.gdshader` (the merged meshes and the things need two small additions each). If you change yours,
make the same change in both copies.

## Visible changes

- **Masks glow on villagers (S2).** Villagers wearing the aurum, hollow or raven mask now light it as your own
  characters do. Before, the villager merge drew them unlit.
- **Smoke and steam lost a black disc (S4).** The people's smoke and steam drew a black disc in their first second.
  Flames now also start fully formed.
- **Things with state (S4; approved by Hilmi for his build).** Scorch is dark charred wood, a hit is a brief brighten,
  and flames, embers, steam and broken planks show what happens to them. Body (the studio's people layer) sets the
  facts: a burning person or your flame dash sets a fence alight, the fire spreads, well water puts it out, a hard
  shove breaks a crate.
- **House variety (S5; preset in Hilmi's build, so every house you placed is yours exactly).** Your house scripts (`make_buildings.py`, through
  `tools-src/studio/blender/house_grammar.py`, which edits nothing of yours) can make seeded variants of your
  cottage, cabin and round house, and market stalls. On "preset" the village is exactly yours (the cottage is your
  own file byte for byte).

## Numbers (cloud, software rendering; the phones measure time in S3)

| | before | after |
|---|---|---|
| Meadow, morning view, draw calls | 576 | 393 |
| Forest clearing, morning view, draw calls | 522 | 374 |
| The player's draw calls | 43 | 5 |
| Extra memory for merged meshes | | +8.5 MB per region |
| Load added | | under the loading cover (about 50 ms on the cloud machine) |
| Things, idle (no facts) | | 0.5-4 microseconds a frame |
| House switch, a frame | | nothing (swapped once at load) |

## Two proposals, for you to decide

- **Scatter (S1):** most of the meadow's plant draws stay unmerged because each scatter group mixes trees and
  gatherables in with plain plants. If `scatter.gd` kept gatherables and trees in their own groups, the plain plants
  would merge too.
- **Glowing houses (S1):** the village gives glowing parts glow 1.5; the batching carries 1.2 only, so your cabin
  and round house draw by themselves today. A small change would merge them too.

## How to remove it all

1. Delete the two marked lines above.
2. Delete `game/scripts/studio/render/`, `game/scripts/studio/things/`, `game/assets/studio/houses/` and
   `tools-src/studio/blender/`.

Or keep the code and set the four settings off.

## Where the proof is

The studio's records, `plan/evidence/graphics/20261005/`: `s0/` (the measurements), `s2/` (characters), `s1/`
(batching), `s4/` (things, with the boards), `s5/` (houses, with the boards). Every stage has a README that starts
with its verdict.

---
title: "Enea's building references - what they are and what they imply"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5)
status: awaiting-hilmi-review
next_step: basis for spike 0D (look board); Enea confirms which families belong to which people
---

# Enea's building references

## Source

`enea-drive-2026-09-28/` holds a copy of Hilmi's download of Enea's Google Drive folder (28 Sep).
- The folder lists 9 files. The zip held 8: `6FCE9888-30C7-4AD2-A254-235E4BB11A26.png` (2.4 MB) is missing.
- The originals stay untouched in Hilmi's Downloads.

## What they are `[run]` (viewed)

AI-generated style sheets on a dark navy background: chunky stylised low-poly with warm glowing windows. Every sheet has the same structure, **a family of buildings in rows of four**:

| Sheet | Families (rows) | What the four columns are |
|---|---|---|
| `D684BCF7-....png` (the clearest) | Stump house, Swoop lodge, Arch cottage, Round house, Tunnel house | family home · cozy home · **workshop** (blacksmith, training grounds, tavern, mill, mine) · **civic** (market, warehouse, healer, town hall, greenhouse) |
| `IMG_5330.JPG` | Stump, Swoop, Arch, Round, Tunnel, Crystal-spire grotto | variations, including the Dual Ring and Market Stalls round houses already built in `game/` |
| `IMG_5327.JPG`, `IMG_5328.JPG`, `IMG_5329.JPG` | Stump, Swoop, Arch, Round, Tunnel, Crystal cavern, Sky-islands | single → specialised → duplex or tower → **cluster or village** |
| `IMG_5325.JPG` | Root cellar, Shroom shanty, Vine vault, Pebble palace, Dew-drop dome | hut → function (hearth, forge, market) → **village** |
| `IMG_5326.JPG` | Crystal glade, **Moss-covered stone ruin**, Subterranean | the same growth ladder, plus a **ruined** family |
| `IMG_5332.PNG` | An iPhone photo-viewer screenshot of `IMG_5330` | - |

## What they imply `[design]`

1. **Enea has already drawn a building system, not a list of houses.**
   - Each family is a style: silhouette, roof and material.
   - Each column is a function or a growth stage.
   - The agent built them one house at a time: "Market round house", "Large swoop home" and "Dual ring house" in commit `053d6b0`. The system underneath was never used.
2. **The growth ladder is what a history simulation drives.** A village moves from hut, to specialised building, to cluster, to village as it grows. The ruin family is what the same place looks like after a collapse, and a time storm can show either.
3. **The families map naturally onto peoples and lands.** For example:
   - warm timber and thatch on the mainland (Swoop, Arch, Round);
   - forest folk (Stump, Root, Shroom, Tunnel);
   - a strange third people (Crystal, Sky-islands).

   This is Enea's call.
4. **This changes spike 0D.**
   - These sheets are chunkier and more toy-like than the trim-textured Quaternius Medieval Village kit. That kit may not match, so it drops from first choice for the building shells.
   - The route becomes:
     - a small **shell kit per family** (2-3 shells each), generated from Enea's own sheets with image-to-3D in low-poly mode, then flat-shaded and cleaned by script;
     - a **shared prop library** (stalls, forge, banners, lanterns, fences, crates, chimneys, windmill sails), drawing on Quaternius Fantasy Props where it fits;
     - a grammar that composes family shell, function props, growth stage and era (new, lived-in, ruin, overgrown).

# Unbound: Design

Working title: **Unbound**. The owner may rename it later, possibly after the game's unique life-energy, using an invented word.

A 3D action-life game for iPhone, played offline (on the train) as a home-screen web app.
The player gathers, crafts, fights and grows stronger in a handcrafted world, with no fixed end.
The full picker results live in the "Three Lands" page:
https://claude.ai/artifact/GguWfzpYKvqzLmG4MFiSDz (db doc `picks/round3`, including the owner's notes).

## Pillars
1. **Endless, not story-driven.** Story is background and gates new areas, and the game keeps going after it. Replayability and long play come first.
2. **Gather → craft → get stronger → go further → rarer stuff.** Every system feeds this loop.
3. **Real-time combat that is simple but fun**, with a loot and gear chase (Outriders and Borderlands are the owner's favourites).
4. **A world that feels alive:** day/night, wildlife, people with routines, random events, and places that grow because of you.
5. **Tunic look and feel:** fixed camera angle, low-poly, soft light and fog, a sense of mystery.
6. **Light on heavy visual storytelling.** Tell the story through places, short dialogue and events, not cutscenes.

## Look and feel
- **Visual targets:** **Tunic, Omno, A Short Hike, Sky: Children of the Light**, with a touch of **Journey** (flowing light and cloth, glow). Clean low-poly, soft glowing light, dreamy skies, cozy but mysterious. Occasional moodier moments (nights, deep places) can borrow a little from Dredge and Death's Door, but not their overall gloom. BOTW is OK as a secondary reference. Avoid overly flat, simple looks (Sable).
- **Camera:** fixed angle like Tunic. It follows the player and never rotates, and it can zoom slightly or angle in specific spots. No camera thumb.
- **Style:** stylised low-poly, with atmosphere done through lighting, fog, colour grading and gentle bloom. Natural colours that change with biome and time of day. No neon, vintage or muted-misty looks.
- **Assets:** only good-looking free (CC0) packs. **Quaternius** is the first choice (the KayKit and Kenney test models were rejected as ugly). Anything custom (props, buildings, shrines, terrain) is made with Blender scripts.
- **UI:** clean and good-looking. The owner cares about it a lot, so the look gets decided properly once the game takes shape.
- **Sound:** mostly nature sounds, very satisfying sound effects, and different music per place (acoustic, ambient, orchestral, piano). Characters may speak in short babble, with minimal text.

## Controls (iPhone, landscape)
- Virtual joystick on the left: touch anywhere on the left half and drag.
- Action buttons on the right (attack, interact/gather, dodge…).
- No tap-to-move, no hold-to-gather, no auto-actions.

## Core loop and systems (in the order to build)
- **Gathering:** woodcutting, mining, fishing, foraging, farming, raising animals.
- **Crafting and smithing**, with gear tiers.
- **Skills** that level up by use (RuneScape style), plus money and several currencies.
- **Combat:** real-time, simple but fun, with light and deep modes and bosses. Caves and dungeons.
- **Loot:** rare drops, relics from lost peoples that craft into legendary gear.
- **Home base plus expeditions.** Several bases are fine later (home, a moving base, camps). Land is never bought plot by plot like city builders; at most a couple of special unlocks.
- **Companions:** recruited from each land, with their own skills. They fight beside you and can go on gathering expeditions. **Some are not who they seem.**
- **Taming:** maybe later. A flying mount is a stretch goal.

## Story (background, never the main focus)
- **Three lands, each with its own people:**
  - **The mainland** (the player's home).
  - **A second land.** The mainland and the second land are **allies**, but the second land has sub-factions with different ideologies that dislike each other. One recurring character hates the player and only realises he was wrong at the end.
  - **The third land.** Its people are still there, alone and cut off, **controlled by the Hidden Fourth**.
- **The Hidden Fourth are the puppeteers.**
  - They lost their own land long ago.
  - They hide among the people of both lands and look like everyone else.
  - They mainly sit in the third land, which they rule through its puppeted people. They want to expand and take the other lands too.
  - They are revealed gradually through clues.
- **The third land is split in two.**
  - **The near half:** freed village by village, and freed people help you.
  - **The far half:** special, and needs all three peoples to reclaim it. It holds the finale.
  - An ancient shared structure (a core) that once powered all the lands is part of this, and can power everyone again afterwards.
- **The "chosen" idea:**
  - The player starts as an **ordinary villager**. On a normal day of chores a shrine nearby wakes, and the player becomes the mainland's strongest over time, not through a past life.
  - Each land has its strongest plus a few guardians below them (1, 2, 3…).
  - The ending needs the strongest of all three lands and their guardians together. The Fourth are dealt with after that.
- **Idea bank (use at small scale later):**
  - one flashback place where you watch a past day,
  - forgotten details (blank map spots, missing song verses),
  - a third-land elder's old bargain with the Fourth,
  - the third land's people drained of a unique life-energy,
  - nights when the veil thins,
  - legendary wandering beasts,
  - the deepest underground holding the Fourth's lost land.
- **Excluded:** curse outbreaks (or at most a very minor version), seasons that change routes, prestige resets, turn-based or auto combat, romance, museum-style collection logs, festivals, and plot-buying.

## World
- **Start:** the mainland only, a normal but varied land. It has underground pockets and distinct areas (an Omno-style shrine zone, a village, forests, ruins).
- **Later:** one properly developed island (the second land), maybe a small wild isle, and the split third land. The layout gets decided once the mainland exists. Keep coastlines and routes open.
- **Areas are separate scenes** that load as you travel, so the world can grow without slowing the phone.

## Sessions
- Play as long or as short as you like, and save anywhere, instantly. No energy limits.
- Short tasks for 2-minute stops, and long goals for long sessions.

## Multiplayer (later, but the architecture is ready from day one)
- **Solo first. Co-op later**, possibly with one player per land and a strongest plus guardians structure, which caps at about 4 players (easy to change).
- **Secret-traitor twist:** in bigger groups, one guardian may secretly be told to betray the others.
- **Code rule from day one:** game state (inventory, world, characters) is kept separate from visuals and input, and changes happen through clear actions, so networking can be added later without a rewrite.

## Money (someday, not now)
- Most likely free, with worthwhile optional purchases (cosmetics, expansions). For now it's just for the owner.

## Owner decisions (Q&A, 2026-09-27)
- **Tools:** can be dropped/lost, but a basic one is always cheap to craft. Without an axe you can punch trees (about double the hits). The current axe may be a bit too fast. No wear or durability.
- **Tool/gear upgrades:** always carry one axe, one pickaxe and one weapon, used automatically. Better ones (crafted or found, with tiers and rarities; found ones can roll bonuses) are equipped from the Bag.
- **Knock-out:** option toggle: either nothing lost, or drop some carried items where you fell and go back for them.
- **Bag:** limited slots, upgraded through crafting.
- **Enemy strength:** mostly fixed per area, some roaming ones scale. You should clearly get stronger, but never to the point of one-shotting everything.
- **Classes/abilities (idea):** something like Outriders: pick a class and choose abilities as you go.
- **Weapon styles eventually:** sword and shield, spear, dual wield, bow, magic/relic powers, big two-handed.
- **Nights:** special night-only creatures and loot. Nights are currently too dark.
- **Food:** heals plus short buffs, depending on the food.
- **Money:** open. Selling to villagers is fine, but money should matter more within the game. Needs ideas.
- **Home:** maybe purchased, with a few options to choose from; could grow into a base later. Open.
- **Map:** minimap, which can be hidden (setting).
- **Travel between lands:** a boat to the second land, later a bridge (maybe with a horse). The third land needs something more special. Loading screens only where performance needs them.
- **Music:** much later; sounds first. Name: keep "Unbound" for now.
- **Idea (maybe):** blacksmithing your own gear as a hands-on minigame (like Jacksmith).

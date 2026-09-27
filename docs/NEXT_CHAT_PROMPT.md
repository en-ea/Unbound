We're building my game "Unbound" (working title) in C:\SoonGame. Read CLAUDE.md, docs/DESIGN.md and docs/PLAN.md first, and check your memory for this project. Everything is set up (Godot, Blender 4.5 in tools/blender, phone server, git). Start the phone server in the background (`node tools-src/serve.js`).

Where we are (M1 "Walk the world" is basically done, M2 is next):
- Meadow slice: terrain, path, pond (wadeable), standing-stone circle with light beams on the hill, day/night, fireflies, synthesized nature sounds and footsteps, shader warm-up behind a loading cover. Steady 30 FPS on my iPhone 16 Pro Max.
- Hero v4 (make_hero.py) follows the owner's reference sheets (Fighter / Explorer / Merchant / Fisherman): faceted layered clothes, hats, backpacks, scarves; outfit presets + parts/colour picker. Old test looks removed.
- Title screen (Play / Character / Settings), pause menu (gear icon, dev tools inside), settings (frame rate, stats, sound), Kenney CC0 icons.
- Earlier character notes: our own character style "hero" (tools-src/blender/make_hero.py on the Quaternius UAL rig): large head, clean faceted low-poly clothing (tunic, V-neck, belt+pouch, bracers, knee boots), choices for face, cheeks, 7 hairstyles, 5 beards, hood, chest (strap/vest), pads, scarf/cape; recolourable. Look picker with Parts/Colours tabs (Dev → Look). In-game look picker (Dev → Look). Dev → Swap look cycles hero/wanderer/villager.
- Our own faceted low-poly trees/pines/bushes (tools-src/blender/make_trees.py; clump colours stored in UVs), faceted ground with crisp path/shore in the terrain shader. The owner shared low-poly tree references (faceted icosphere clumps, twisty trunks).

M2 "Gather" first pass is in:
- State (no visuals): Items (scripts/state/items.gd), Inventory and WorldResources autoloads (hits, drops with chances, respawn timers).
- Scatter registers trees/apple trees/rocks/mushrooms/flowers; ResourceVisuals does shake, chips, sounds (Kenney impacts), stumps, grow-back; drops fly to the player (drop.gd) with "+1 Wood" popups; rare finds sparkle and chime.
- Gatherer on the player + round action button (Chop/Mine/Pick, multi-touch safe) + Bag screen. Axe/pickaxe from tools-src/blender/make_tools.py. Dev: --gathertest.
- Trees have sizes (young/grown/old: 3/4/6 hits, 1-2/2-3/4-5 wood), fall over when chopped, and regrow from saplings. Pickup feed pills in the HUD. All nature models are our own faceted ones (make_trees.py); the Quaternius nature pack is gone (download ~6.5 MB).
- Chop/mine use UAL2's TreeChopping (started part-way for wind-up then strike), picking uses UAL1 PickUp_Table; hit-stop + camera shake. Trees covering the player dither-fade (occlusion_fader.gd). Richer generated ambience (make_sounds.py).
- Known: item icons are colour dots; hair and the character need a proper art pass (owner wants it better in general); no saving yet (M5).
- Item models (make_items.py) for drops + rendered Bag/feed icons (ItemIcons autoload). Look pass: ground patches/detail, baked shade under objects, warm sun/cool shade, soft shadows, haze, AgX, vignette.
- M3 started: boar enemy (make_boar.py parts + procedural animation in boar_visual.gd; AI in boar.gd: wander/alert/charge/recover/hurt/dead, respawns). Player: sword 3-hit combo (fighter.gd, UAL2 Sword_Regular_A/B/C), dodge roll, knockback (no player health/death yet). Dev: --fighttest.
- M3 still to do: player health and death/respawn, enemy variety later, combat polish from the owner's feedback.

Work in small steps, keep usage low (no repeated screenshot loops), keep replies short, check in with me every few steps, and tell me what to test when it's ready.

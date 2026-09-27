We're building my game "Unbound" (working title) in C:\SoonGame. Read CLAUDE.md, docs/DESIGN.md and docs/PLAN.md first, and check your memory for this project. Everything is set up (Godot, Blender 4.5 in tools/blender, phone server, git). Start the phone server in the background (`node tools-src/serve.js`).

Where we are (M1 "Walk the world" is basically done, M2 is next):
- Meadow slice: terrain, path, pond (wadeable), standing-stone circle with light beams on the hill, day/night, fireflies, synthesized nature sounds and footsteps, shader warm-up behind a loading cover. Steady 30 FPS on my iPhone 16 Pro Max.
- Our own character style "hero" (tools-src/blender/make_hero.py on the Quaternius UAL rig): large head, clean faceted low-poly clothing (tunic, V-neck, belt+pouch, bracers, knee boots), choices for face, cheeks, 7 hairstyles, 5 beards, hood, chest (strap/vest), pads, scarf/cape; recolourable. Look picker with Parts/Colours tabs (Dev → Look). In-game look picker (Dev → Look). Dev → Swap look cycles hero/wanderer/villager.
- Our own faceted low-poly trees/pines/bushes (tools-src/blender/make_trees.py; clump colours stored in UVs), faceted ground with crisp path/shore in the terrain shader. The owner shared low-poly tree references (faceted icosphere clumps, twisty trunks).

Next: M2 "Gather":
- Our own trees (and choppable versions), rocks to mine, flowers/mushrooms to pick.
- Right-side action button (Chop / Mine / Pick) with tool swing animations (UAL has Sword_Attack, Interact, PickUp), hit shake, chips/particles, sounds.
- Drops pop out and are collected when you walk near. Small chance of rare drops.
- Inventory state kept separate from visuals (actions like Inventory.add), plus a clean inventory screen (UIStyle).
- Resources respawn after a while with a grow-in animation.

Work in small steps, keep usage low (no repeated screenshot loops), keep replies short, check in with me every few steps, and tell me what to test when it's ready.

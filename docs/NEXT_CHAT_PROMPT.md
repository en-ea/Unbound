We're building my game "Unbound" (Godot 4.7.2, played on my iPhone as a web app). Repo: GitHub en-ea/Unbound; Vercel serves the `web/` folder. Read CLAUDE.md, docs/PLAN.md and docs/SYSTEMS.md first (docs/DESIGN.md and docs/GAME_PLAN.md for design work). Cloud sessions: run `bash tools-src/cloud_setup.sh` first. To publish: export Web, copy the two files, `bash tools-src/publish_web.sh`, commit, push to main.

Where we are:
- Done: walking, gathering, crafting with tool tiers, skills, bag, saving/offline, regions (meadow + Whispering Wood), food and cooking, coins/trader/Smithy, home base with yard building, balance file, test menu (Settings > Codes > Paladin).
- Fighting: tap Roll = roll, hold Roll = sprint; stamina on the Roll button's rim; Heavy button; enemies glow and flash a glint with a "ting" before they strike.
- Loot and armour: six rarities with rolled bonuses and names, armour (helm/chest/boots, defence blocks hits; helm hidden unless "Helm: shown" in the Bag), Bag Gear tab with compare, found-loot card. Models are placeholders until I send weapon/armour designs.
- Character screen: clean ‹ › cards, 13 ready-made outfits, eye colour, nose, elf ears, markings.
- Build lab (title screen): small walled room; the Lab board switches buildings and spawns enemies, trees, rocks, ores, chests and loot.
- Home inside: walk in through your front door; a cosy room per house (hearth cooks, bed rests to morning); Furnish button places, turns and puts away 13 furniture pieces; mailbox by the path has the home menu.

Hilmi (my friend) works on the `studio` branch (docs/studio/START-HERE.md): a bigger "living civilisations" direction, native apps, a new camera. My answers are in docs/studio/FROM-ENEA.md. Don't merge or build on `studio` without my OK. Because fighting and the camera may change on his side, prefer work that stays the same either way (looks, content, data, screens).

Next: (pick from the ideas at the end of the last chat, or my playtest notes).

How I like to work: I don't code; keep replies short and plain. Batch my requests into one go, commit after each working step, only screenshot when a visual check really matters, make things look good (not basic), and at the end tell me concisely what to test.

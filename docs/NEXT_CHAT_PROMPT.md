We're building my game "Unbound" in C:\SoonGame. Read CLAUDE.md, docs/PLAN.md and docs/SYSTEMS.md first (docs/DESIGN.md only for design work), and check your memory for this project. Start the phone test server in the background if needed (`node tools-src/serve.js`); the game is also on GitHub (en-ea/Unbound) and Vercel serves the `web/` folder (update it with `bash tools-src/publish_web.sh`, commit, push).

Where we are: M1 (walk the world) and M2 (gathering) are done. M3 (fighting) is done and polished: boar enemy with warning, charge, health bar, leash; sword combo, roll, 5 hearts, knock-out and respawn. Also: our own faceted low-poly art (trees, items, houses, boar, the hero with outfit presets), title and loading screens, pause menu, settings, Bag with item icons.

Next, in order:
1. Saving (M5 core): save anywhere, instantly (inventory, world resources, look, position, time of day), plus offline play via a simple service worker so the home-screen app works without signal.
2. M4: crafting at a workbench, tool tiers (axe/pickaxe/sword), skills that level with use.
Later: character and hair art pass, body variety (sizes, builds, kids), non-human NPCs, village (M6).

Keep usage low: read only the files a task needs, avoid screenshots unless a visual check really matters (one at a time), commit after each working step, keep replies short, and tell me what to test.

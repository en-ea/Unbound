We're building my game "Unbound" in C:\SoonGame. Read CLAUDE.md, docs/PLAN.md and docs/SYSTEMS.md first (docs/DESIGN.md only for design work), and check your memory for this project. Start the phone test server in the background if needed (`node tools-src/serve.js`); the game is also on GitHub (en-ea/Unbound) and Vercel serves the `web/` folder (update it with `bash tools-src/publish_web.sh`, commit, push).

Where we are: M1-M4 are done: walking, gathering, fighting (boar, wolf packs), crafting at a workbench with tool tiers (Worn/Stone/Copper/Iron), copper and iron ore, found tools with rarity and bonuses, skills that level with use, bag slots, saving anywhere and offline play. Also: minimap, ruins with chests, critters, a knock-out scene, a reworked character screen (Face/Hair/Body/Outfit/Colours with height and build sliders). The Unbound Atlas planning map is https://claude.ai/artifact/5mZUEA4PkbbENxTMcLctLW (I leave keep/maybe/cut and notes there; read its db).

The big plan is decided in docs/GAME_PLAN.md. Houses are parked for now (placeholders are fine).

Next: follow the build order in docs/GAME_PLAN.md, starting with the forest region and region travel.

Keep usage low: read only the files a task needs, avoid screenshots unless a visual check really matters, commit after each working step, keep replies short, and tell me what to test.

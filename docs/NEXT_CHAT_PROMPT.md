We're building my game "Unbound" (Godot 4.7.2, played on my iPhone as a web app). Repo: GitHub en-ea/Unbound; Vercel serves the `web/` folder. Read CLAUDE.md, docs/PLAN.md and docs/SYSTEMS.md first (docs/DESIGN.md and docs/GAME_PLAN.md for design work). Cloud sessions: run `bash tools-src/cloud_setup.sh` first. To publish: export Web, copy the two files, `bash tools-src/publish_web.sh`, commit, push to main.

Branches: `main` is my real app. `camera-test` = main + the new low turning camera (drag the right half to turn, lock-on ring) and has its own test link: https://unbound-git-camera-test-en-eas-projects.vercel.app (separate save). Work on `main`; afterwards merge main into `camera-test`, export and push it too, so the test link stays current. Hilmi's `studio` branch: don't merge or build on it without my OK. Ideas I want kept (not scheduled): docs/IDEAS.md. Reference pictures: docs/Builds/characters/.

What's new on camera-test (30 Sep, built while I was away; see the in-game Update log): music, an Update log
screen, better hit feel (move out of swings, damage numbers, kill finisher, level-up banner), loot flashes, Parry
button and perfect dodge, the Red Hand bandits and their camp in the Whispering Wood, sneaking and takedowns,
Morrow's dark quest "The Black Seal", and the story start (the shrine on the meadow hill wakes, the class screen,
the Pyromancer with Flame Dash and Meteor). main doesn't have these yet: merge camera-test into main when I say.

Waiting on me: AI pictures of swords, bows, armour and the Hollowhorn sword (I'll send them; build the models
from them then). The Brakk redo (chipped boulders + baked shading) is parked on branch `brakk-redo`, untested.

Then tell me concisely what changed and what to test, and give me the updated options list:
- Polish: tune fight difficulty from my playtest; camp performance (~670 draw calls in view); villager
  performance; hats and masks; villager life; menus; prices and drops.
- Build on: more classes (I name them); class levels and more Pyromancer abilities; more quests; a forest boss
  (Hollowhorn the Elder Stag, or Tuskfather / Greymaw / Thornmother / Lantern Moth Queen); two weapon slots and
  bows; Morrow's next job; second village project; trader's rare stock.
- New: Stumplings and Sporecaps (forest mobs); elite enemies; bounty board; dangerous nights; knock-out that costs
  something; a small cave dungeon; a dog companion; challenges; shrines as fast travel; light rain and mist; fishing.

How I like to work: I don't code; keep replies short and plain. Batch my requests into one go, commit after each
working step, only screenshot when a visual check really matters, and watch usage (no waste, but good quality).

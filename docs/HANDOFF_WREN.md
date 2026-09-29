# Handoff: finish and polish Wren (talk screen, sound, reward moment)

Paste this to the next Claude. Read CLAUDE.md, docs/PLAN.md and docs/SYSTEMS.md first (the "Smoking" and "Villagers and quests" sections).
The owner doesn't code: keep replies short and plain, only screenshot when a visual check really matters, and do only what is asked here.

## Where we are
- Repo en-ea/Unbound. Work is on branch `claude/laughing-maxwell-vmlnd1` (NOT merged to `main` yet). `main` (commit a7772b2) is the last published build:
  cigarettes, Wren the tobacco grower with his first quest, a plain talk card, Wren walking his round.
- Everything after that is on the branch and has NOT been played on the phone or published.
- Done and working earlier: cigarettes (tobacco plant, roll at a campfire, Smoke in the Bag), Wren (leaf cloak, sun hat, shears), quest system
  (`state/quests.gd`, `state/npcs.gd`, `ui/quest_tracker.gd`), Wren wandering (harvest / water / plant seeds, stops and turns to you).
- Quest: Wren's Smokes. Pick 4 wild tobacco (patch west of the houses), roll 3 cigarettes at a campfire, hand them in for 60 coins + 5 tobacco.
  Wren stands at (-2.6, 18) by the white fence near the spawn. Dev: `--talk`, `--talk=quest`, `--talk=done` (hands in the quest after 1 s), `--at=x,z`.

## What the owner asked for about Wren (all six points; the first draft of each is already on the branch, check them and polish)
1. **Talk screen was basic; each character's speech should have its own look.** Now: `ui/dialogue_panel.gd` has a card themed per villager
   (`"theme"` in `state/npcs.gd`: background, accent colour, fonts, voice), name plate with a fading line, typed-out text, buttons that appear when the words finish,
   a slide-in. Make it look genuinely good, not just changed. Needs a look at a real phone-size screenshot.
2. **No sound, just reading.** Now: little talking blips (`game/assets/sounds/voice_wren_*.wav`, `voice_brakk_*.wav`, made by `tools-src/make_voices.py`), one every second letter
   with random pitch, pauses at punctuation. Check they sound good (not annoying) and tune `make_voices.py` if not. Consider a soft UI sound on open and on button press.
3. **Fonts were plain.** Now: Almendra (Wren) and Cinzel (Brakk) in `game/assets/fonts/` with their OFL licences. CLAUDE.md says "no OFL fonts unless the owner agrees":
   the owner asked for less plain fonts, so I used them. Tell the owner, and update CLAUDE.md's rule if they are happy. Check the glyphs you need exist (apostrophes, ×, …).
4. **Show the character next to the text.** Now: a live 3D portrait (SubViewport, chest-up, `"portrait"` in `state/npcs.gd`: camera, look-at, turn) standing out of the card's top-left,
   talking animation while the words type (`CharacterVisual.talk`). Wren's portrait works; frame him nicely (bigger face, good angle). Note: soft alpha smoke looks black on a
   transparent SubViewport, so smoke is switched off in portraits (`Npcs.dress_visual(..., portrait=true)`).
5. **Make Wren look better.** Done so far: the sun hat is tipped back so his face shows, brown stubble, stern brows, and a cigarette always in his mouth with smoke
   (`Smoking.start_endless`). Still to consider: reference was a tall thin man with a huge brim, a poncho of big overlapping leaves and big shears held low in both hands.
   The hat now reads a bit like a sombrero; the leaves could be bigger/varied; shears are small; only one hand holds them. Model code: `tools-src/blender/make_hero.py`
   (`sun_hat`, `leaf_cloak`, run it, then `godot --headless --import`), shears in `make_items.py`. The owner's reference: a man in a huge straw hat, a cloak of overlapping golden-brown tobacco leaves, garden shears.
6. **Handing in the quest did nothing.** Now: `ui/quest_complete.gd` (hooked in `ui/hud.gd` via `Quests.completed`): a "QUEST COMPLETE" banner with fanfare, sparkles, coin and item
   rewards popping in, plus Wren nods (`"Yes"` animation) and the portrait does the same. **This has never been seen on screen.** Run `--talk=done` with `--shot`, look at it, fix layout/timing.
   Also think about a better after-quest state (marker gone, Wren's chatter changes, maybe he sells tobacco).

## Do NOT touch
The golem (Brakk, `tools-src/blender/make_golem.py`, `game/assets/characters/golem.glb`, his entry in `state/npcs.gd`, anvil/hammer models). It is on the branch and in the village at (-13.5, 11), but the owner
is not happy with the model yet and it is being handled separately. Leave it exactly as it is.

## Things to know
- **Publishing gotcha (this cost a round trip):** the Godot web export sometimes leaves `build/web/index.pck-XXXXXX` and does NOT replace `index.pck`. Before exporting run
  `rm -f build/web/index.pck*`; after exporting check `build/web/index.pck` has a new timestamp and no `index.pck-*` file exists; delete stray ones in `web/` too. Then copy the manifest and
  `offline.sw.js`, `bash tools-src/publish_web.sh`, commit, push. The owner must fully close and reopen the app to see a new version.
- Merge the branch to `main` only after the owner has seen it (or say clearly what you are publishing).
- Screenshots: `xvfb-run -a -s "-screen 0 1280x720x24" ~/godot/Godot_v4.7.2-stable_linux.x86_64 --rendering-driver opengl3 --path game -- <dev args> --shot=/tmp/x.png --shotframe=150`.
  The game camera is behind the player; `--view=d,pitch` is confusing (negative pitch looks from the front/low), so for looking at a character use the preview scene instead:
  `GV_NPC=wren timeout 120 xvfb-run ... godot --path game res://scenes/tmp_view.tscn` (talk screen over a green background, saves `/tmp/claude-0/s/gv.png` after 90 frames;
  `GV_MODE=body` shows the full body, `GV_ANGLE=deg`). Run `godot --headless --path game --import` after every model change or the old imported model is used.
- Fonts, sounds and models are our own or free (CC0 / OFL). Placeholders for the tobacco plant etc. are fine.
- Godot version 4.7.2, GL Compatibility renderer, target is an iPhone Safari web app at 30 FPS: keep effects light.
- Files added for this: `state/npcs.gd` (villager data + `make_visual` / `dress_visual`), `world/npc.gd` (villager in the world: routine, marker, bubble), `state/quests.gd`,
  `ui/dialogue_panel.gd`, `ui/quest_complete.gd`, `ui/quest_tracker.gd`, `player/smoking.gd`, `dev/tmp_view.gd` + `scenes/tmp_view.tscn` (preview helper; fine to keep or tidy).

## At the end
Tell the owner concisely what to test on the phone (talk to Wren: look, portrait, sound, hand in the quest and see the banner). Update docs/SYSTEMS.md if anything above changes.

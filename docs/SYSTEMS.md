# How the game is put together (for adding things)

Game state is separate from visuals: state scripts hold data and change through small action
functions; visual scripts listen to signals. Keep it that way (co-op later).

## Add an item
1. `game/scripts/state/items.gd`: add an entry to `DEFS` (name, colour, rarity).
2. `tools-src/blender/make_items.py`: add a model function and an `export(...)` line; run it.
   Drops and Bag icons pick the model up automatically (`Items.mesh`, `ItemIcons`).

## Add a gatherable resource (like trees, rocks, plants)
1. `game/scripts/state/world_resources.gd`: add a type to `TYPES` (hits, respawn, reach, tool,
   verb, drops as `[item, min, max, chance]`). Trees use `TREE_STAGES` (size decides hits/wood).
2. `game/scripts/world/scatter.gd`: place it with `_place(model, kind, pos, scale, tilt, "<type>")`.
   Shake, chips, sounds, stumps, regrowth and drops are handled by `resource_visuals.gd`.

## Tools, tiers and crafting (M4)
- `game/scripts/state/gear.gd` (autoload `Gear`): `TIERS` (Worn, Stone, Copper, Iron: power = hits per
  swing / sword damage, speed = swing speed), `RECIPES` (slot, tier, cost in items), owned and equipped
  tools, and the actions `craft()` and `equip()`. Saved with the game.
- Resource types can require a tier with `min_tier` (ore rocks in `world_resources.gd`); a weaker tool
  just glances off and the HUD hints what's needed.
- The workbench (`world/workbench.gd`) is an "interactable": any node in that group with `verb`, `reach`
  and `interact()` takes over the action button when you're near (see `player.gd`).
- Screens: `ui/crafting_panel.gd` (workbench), tool badges in the Bag (`ui/inventory_panel.gd`).
- Tool heads are tinted by tier in `character_visual.gd` (`show_tool`).
- Each owned tool is a record `{tier, rarity, bonuses}`; `Gear.roll_found()` makes a found one
  (chests 40%, boars 6%, wolves 8%) with Swift / Mighty / Lucky bonuses. `drop_tool()` leaves you
  with fists (trees take a punch animation, half an axe's power).
- Bags: `Gear.BAGS` (12 / 16 / 22 kinds of item); `Inventory.has_room()`; a full bag leaves new
  kinds of item on the ground (`drop.gd`).

## Loot, rarities and armour
- `state/loot.gd` (`Loot`, static): six rarities (Common..Mythic, `Balance.RARITIES`: colour, stat multiplier,
  bonus count), rolls by source (`Balance.LOOT_ODDS`: enemy, elite, chest, trader), bonuses with values
  (`Balance.BONUSES`: which gear, value range, text), names (Mythic pieces get their own).
- A piece is `{tier, rarity, bonuses: {id: value}, seed}`. Tools and the sword live in `Gear`; armour in
  `state/armor.gd` (autoload `Armor`: helm/chest/boots, `defence()`, `block_chance()`, `bonus_total()`).
  `Gear.roll_found(source)` rolls any kind; `Gear.take(slot, piece)` routes it. Bonus effects are plain numbers
  read in few places: `Gear.damage/hit_damage/speed/luck/lifesteal`, `player.take_damage` (block), player speed
  (Fleet), heart regen (Mending). Swap these hooks if fighting changes; the data stays.
- Worn armour shows on the player (`CharacterVisual.wear_gear`, `_worn_parts`: helm, armour top, boots; Metal
  takes the tier colour). Placeholder looks until armour designs arrive. Drop/icon models: `make_tools.py`.
- UI: `ui/gear_view.gd` (cards, detail with compare, "On you" rows), the Bag's Gear tab, `ui/loot_card.gd`.
  Test menu: Random gear, One of each rarity, Armour set. Dev: `--loot` (with `--bag`), `--lootcard`.

## Skills (M4)
`game/scripts/state/skills.gd` (autoload `Skills`): woodcutting, mining, combat. XP from
`gatherer.gd` (2 per hit, plus the node's hits when it's finished), `fighter.gd` (3 per hit) and
kills (boar 25, wolf 20). Perks: gathering speed +1.5% and extra-drop chance +1% per level, sword
damage +1 per 10 combat levels. The HUD shows a small bar on gains and a message on level-up.

## Food, money and village projects
- `state/food.gd` (autoload `Food`): `FOODS` (hearts healed, buff, seconds), `BUFFS` (strong, swift, nimble,
  sturdy), campfire `RECIPES`; actions `cook()` and `eat()`. Buffs are read by Gear.damage, player speed and
  damage taken, and gatherer pace. Eat from the Bag (Eat button); the HUD shows running buffs.
- `state/money.gd` (autoload `Money`): coins (`earn`, `spend`), the trader (`sell`, `buy`, `stock()` rotates
  every 15 min from `STOCK_POOL`). Sell prices are `value` in `Items.DEFS`.
- `state/projects.gd` (autoload `Projects`): `DEFS` (name, region, spot, coins and item cost, what it unlocks);
  `fund()`. The spot shows scaffolding and a board until funded (`world/project_site.gd`). The Smithy unlocks
  Steel tools (recipes with `"needs": "smithy"` in `gear.gd`).
- One screen for all three: `ui/shop_panel.gd` (mode cook / trade / project), opened by `world/station.gd`
  (any interactable spot) through `hud.open_station()`. Campfires: `world/campfire.gd`, one per region.
- Dev: `--rich` (coins and materials), `--open=cook|trade|project:smithy`.

## Balance
Every gameplay number (enemy health/damage/XP, hearts and regen, tool tiers and recipes, bags, resources,
food, prices, trader stock, project and home costs, skill curve) lives in `state/balance.gd` with the
targets at the top. Other scripts alias its constants (`Gear.TIERS := Balance.TIERS` and so on).

## Home base
`state/home.gd` (autoload `Home`): owned house, pieces built in the yard, `missing()` (needs the Smithy,
a skill total and coins, see Balance.HOME), `buy()`, `place()`, `remove()`. `world/home_plot.gd` shows the
plot (meadow, west of the village); `ui/build_mode.gd` is the building bar (preview in front of you on a
half-metre grid, or Snap: fences join, 1 m grid, square turns; `_hook`). The mailbox by the path opens the home
screen (build, or move into another house). Add a buildable: `Home.PIECES` + its cost in `Balance.HOME_PIECES`. Dev: `--home`.

## Inside your home
`world/home_interior.gd`: one room far off the map (`AT`), built from `assets/interior/room_<house>.glb`
(`tools-src/blender/make_interior.py`: floor, cut-away walls, hearth, windows as a separate "Windows" object,
shelves; furniture `furn_<id>.glb`; the mailbox). Walk into the front door (or Enter) / out through the doorway
(or Leave on the mat), with `Region.fade_through()`. Indoors: `DayNight.set_indoors()` (softer sun, warmer ambient),
camera `enter_room()` / `leave_room()` (closer, steeper, stays on the room), no fog, quieter ambience, wooden steps,
HUD `set_indoors()` (Furnish button, no minimap). The hearth cooks; a bed "Rest" sleeps to morning and heals.
Furniture state: `Home.FURNITURE` (name, model, footprint, "wall"/"rug"/"", action), `Home.furniture`, `Home.stored`
(put away = free to place again), `furnish()`, `put_away()`, `room_fits()` (rects; rugs only mind rugs;
`ROOM_BUILT_IN`, `ROOM_DOORWAY`), `STARTER` (a new home's pieces). Costs: `Balance.HOME_FURNITURE`.
Furnish bar = `ui/build_mode.gd` with `room = true` (0.5 m grid, wall pieces back onto the nearest wall).
Saved indoors → you wake up inside. Add furniture: a model in make_interior.py + `Home.FURNITURE` + its cost.
Dev: `--inside[=hill]`, `--furnish`, `--house=lantern`. Test menu: "One of each furniture".

## Places
`world/places.gd`: named placeholder spots per region (watchtower, farmstead, camp, hollow, cave...),
built from simple shapes; their ground is a clearing in `WorldShape.REGIONS`.

## Regions and travel
- `game/scripts/core/region.gd` (autoload `Region`): the current region, its display name (`NAMES`) and its
  gates (`GATES`: trigger spot, the region it leads to, where you arrive). `travel()` saves, fades, and
  reloads the main scene, which builds the new region; `arrived()` fades in and shows the name.
- `WorldShape.REGIONS`: each region's pond, hill (standing stones), spawn, path, clearings, roughness, seed.
  Scripts read `WorldShape.POND_CENTER` etc., set by `WorldShape.use()` for the current region.
- Per-region content: trees and plants (`scatter.gd`, `_scatter_forest_trees`), enemies (`enemies.gd` HOMES),
  ruins and chests (`treasure.gd`), gates (`world/region_gates.gd`). The village and workbench are meadow only.
- Saving: each region's trees/rocks/chests are saved separately with the time they were saved; on load the
  time away is applied, so things grow back while you are elsewhere or the app is closed.
- Add a region: an entry in `WorldShape.REGIONS`, `Region.NAMES` and `Region.GATES` (both directions), then its
  scatter, enemies and treasure lists. Dev: `--region=forest`.

## Minimap
Anything in group `"map_building"` with a `"map_size"` meta (Vector2 footprint) shows as a building.

## Stamina and fighting moves
- `player/stamina.gd` (a child of the player): `use("roll"|"heavy")`, `drain()` while sprinting, `winded` when
  emptied (until `winded_until`). Numbers in `Balance.STAMINA`, `SPRINT_SPEED`, `HEAVY_DAMAGE`, `HEAVY_PUSH`.
- Roll button (`hud._update_roll_button`): a tap rolls (on release), holding it past `HOLD_TO_SPRINT` sprints
  (label turns "Sprint", it lights up, bigger dust). Its rim shows stamina while not full. Q on the keyboard.
- Heavy button (fights only; F on the keyboard): `fighter.heavy()`. The sword glows through the wind-up; the blow
  hits every enemy in front within `HEAVY_REACH`, staggers them (`_hurt_time`), and freezes the world for a
  moment (`Engine.time_scale`), with a shockwave ring (`shaders/shockwave.gdshader`) and a deep thud.
- Attack warnings: in a WINDUP state enemies set `visual.tell` (0..1, red-hot pulse via `warn` in foliage_solid),
  and when their aim locks (`AIM_LOCK`) `visual.glint()` flares a star at the eyes with a "ting"
  (`shaders/glint.gdshader`, `assets/sounds/tell_glint.wav`, made by us). Dev: `--telltest`.

## Add an enemy
Copy the boar pattern: a model made of parts with pivots (`tools-src/blender/make_boar.py`), a
visual script that animates the parts in code (`boar_visual.gd`), a behaviour script with a small
state machine and `take_hit()` / `is_alive()` / group `"enemy"` (`boar.gd`, with a WINDUP state: glow, then a glint), and spawn it from
`scripts/creatures/enemies.gd`. The player's `fighter.gd` finds anything in group `"enemy"`.

## Add a character look or outfit
Parts and colour slots: `tools-src/blender/make_hero.py` (mesh names `H_<slot>_<choice>[_extra]`; choice names
have no underscores; extra pieces can use fixed colours like Gold, Leaf, Fur, Straw). Choices, picker names
(`CHOICE_NAMES`), palettes and the ready-made outfits: `game/scripts/player/character_look.gd`. Headwear that
covers the head is listed in `CharacterVisual.COVERING` (hair switches to its `_hat` cut). The picker
(`ui/look_picker.gd`) shows each slot as tap-to-pick chips; tabs list their slots in `SLOTS`.
Dev: `--lineup[=N]` (7 outfits from the Nth), `--outfit=Mage`.

## Add a building or NPC
Models: `tools-src/blender/make_buildings.py`. Placement, clearings and NPCs:
`game/scripts/world/village.gd` and `WorldShape.clearings`.

## Look and style
All props use `shaders/foliage_solid.gdshader` (per-face colours stored in UVs by the Blender
scripts; `lowpoly.py` / `rigkit.py`). Ground: `shaders/terrain.gdshader`. Light, fog and sky:
`scripts/world/day_night.gd`.

## Test menu (for the owner)
Menu → Settings → Codes → "Paladin": buttons that give coins, items, food, Steel tools, the biggest bag,
skill levels, build every village project (or undo them all), give the home back (`Home.reset()`), heal, or travel. In `ui/settings_panel.gd` (`_cheat_page`);
add a button there whenever a new system needs quick testing. Dev: `--cheats` opens it.

## Build lab (testing in the game)
`dev/build_lab.gd`: a walled floor far below the world with one building on a showcase pad; the Lab board opens
`dev/lab_menu.gd` (switch building, spawn enemies/trees/rocks/ores/chests/loot in front of you, clear). Spawns are
removed on leaving (`WorldResources.truncate`, `ResourceVisuals.forget`, `treasure.remove_chest`), so they never
reach a save. Add a building: `BUILDINGS`; add a spawnable: `GATHERABLES` or `spawn()`. Dev: `--lab`, `--labmenu`, `--labtest`.

## Testing without the phone
Dev arguments (after `--`), see `game/scripts/dev/dev_args.gd`: `--gathertest`, `--fighttest`,
`--lineup`, `--showcase`, `--shot=path.png`, `--at=x,z`, `--view=d,pitch`, `--time=0.5`.

## Smoking
`player/smoking.gd` (child of the player, `player.smoke()`): a cigarette on the head bone (`CharacterVisual.head_attachment()`),
glowing tip, wisp and puffs, burns down over `Balance.SMOKE_SECS`; cosmetic only. Items `tobacco` (a gatherable plant, `tobacco_1`
in make_trees.py; a patch by Wren in `scatter._tobacco_patch`) and `cigarette` (campfire recipe with `"n": 3`, trader stock). Dev: `--smoke`.

## Villagers and quests
- `state/npcs.gd`: each villager (name, title, spot, `look` = CharacterLook parts + colour indices, body scale, hand `prop`, greetings, chatter).
  `world/npc.gd` builds one (an "interactable": the action button says Talk), turns to face you, shows a bubble and a "!" / "?" marker.
  Add one: an entry in `Npcs.NPCS`; the village builds them all. New looks come from make_hero.py (Wren: `sunhat`, `leafcloak`, prop `shears` in make_items.py).
- `state/quests.gd` (autoload `Quests`): `DEFS` (giver, the words for each moment, steps, reward). A step is `have` (finishes itself when you
  carry the items) or `turn_in` (handed over when you talk). Actions `accept()`, `turn_in()`; `talk(npc)` gives the talk screen as
  `{text, options:[{label, do}]}` (`do` returns the next screen, or `{}` to end). Saved with the game.
- UI: `ui/dialogue_panel.gd` (bottom card, typed text), `ui/quest_tracker.gd` (top-left). Dev: `--talk`, `--talk=quest`.
- First quest: Wren's Smokes (pick 4 tobacco, roll 3 cigarettes at a campfire, hand them in for 60 coins and 5 tobacco).

## Brakk the golem blacksmith
Model: `tools-src/blender/make_golem.py` → `assets/characters/golem.glb`, on the UAL rig (all UAL animations work). Built from
chiselled stone blocks (`rock()`), each fixed to one bone so nothing stretches; glowing parts use the "Glow" material. LOD
generation is off in `golem.glb.import` (it broke the blocks). Villager entry "brakk" in `state/npcs.gd` (scale 1.6, hammer,
anvil, portrait). Sonnet's first version is kept: `make_golem_v1.py` / `golem_v1.glb`. Preview: `GV_NPC=brakk GV_MODE=body
GV_ANGLE=-20 GV_DIST=5.5 ... res://scenes/tmp_view.tscn` (writes /tmp/claude-0/s/gv.png); without GV_MODE it shows his talk screen.

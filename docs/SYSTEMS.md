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

## Add an enemy
Copy the boar pattern: a model made of parts with pivots (`tools-src/blender/make_boar.py`), a
visual script that animates the parts in code (`boar_visual.gd`), a behaviour script with a small
state machine and `take_hit()` / `is_alive()` / group `"enemy"` (`boar.gd`), and spawn it from
`scripts/creatures/enemies.gd`. The player's `fighter.gd` finds anything in group `"enemy"`.

## Add a character look or outfit
Parts and colour slots: `tools-src/blender/make_hero.py` (mesh names `H_<slot>_<choice>`).
Choices, palettes and outfit presets: `game/scripts/player/character_look.gd`.

## Add a building or NPC
Models: `tools-src/blender/make_buildings.py`. Placement, clearings and NPCs:
`game/scripts/world/village.gd` and `WorldShape.clearings`.

## Look and style
All props use `shaders/foliage_solid.gdshader` (per-face colours stored in UVs by the Blender
scripts; `lowpoly.py` / `rigkit.py`). Ground: `shaders/terrain.gdshader`. Light, fog and sky:
`scripts/world/day_night.gd`.

## Test menu (for the owner)
Menu → Settings → Codes → "Paladin": buttons that give coins, items, food, Steel tools, the biggest bag,
skill levels, build every village project, heal, or travel. In `ui/settings_panel.gd` (`_cheat_page`);
add a button there whenever a new system needs quick testing. Dev: `--cheats` opens it.

## Testing without the phone
Dev arguments (after `--`), see `game/scripts/dev/dev_args.gd`: `--gathertest`, `--fighttest`,
`--lineup`, `--showcase`, `--shot=path.png`, `--at=x,z`, `--view=d,pitch`, `--time=0.5`.

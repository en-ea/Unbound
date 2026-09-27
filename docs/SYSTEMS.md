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

## Testing without the phone
Dev arguments (after `--`), see `game/scripts/dev/dev_args.gd`: `--gathertest`, `--fighttest`,
`--lineup`, `--showcase`, `--shot=path.png`, `--at=x,z`, `--view=d,pitch`, `--time=0.5`.

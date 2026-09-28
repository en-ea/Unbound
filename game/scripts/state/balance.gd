class_name Balance
extends RefCounted
## Every number that decides how the game plays, in one place: enemies, your hearts, tools, recipes,
## resources, food, prices, projects and skills. Change a number here and it changes everywhere.
##
## Targets (a steady, not-too-easy climb; tune by playing):
## - Stone tools ~5 min in, Copper ~15 min, Iron ~40 min, Steel (needs the Smithy) ~1.5 h.
## - Fights: a fresh player needs ~6 hits on a boar and must dodge; a pack of 2 wolves can knock a
##   careless player out. Forest enemies are tougher than meadow ones. Food matters for hard fights.
## - Hearts come back slowly on their own; food heals fast.
## - Coins: selling a trip's worth of loot pays ~30-60; the Smithy takes a few trips; a home much more.

# --- you ---------------------------------------------------------------------------------------
const HEARTS := 5
const REGEN_DELAY := 8.0          # seconds without a hit before hearts start coming back
const REGEN_EVERY := 6.0          # then one heart this often
## Stamina: sprinting (hold Roll), rolling and heavy attacks use it; it refills after a short pause.
## Run it empty and you are winded: no sprint, roll or heavy until it is back to `winded_until`.
const STAMINA := {"max": 100.0, "regen": 34.0, "delay": 0.6, "sprint": 20.0, "roll": 26.0, "heavy": 34.0,
	"winded_until": 35.0}
const SPRINT_SPEED := 7.6         # m/s (a run is 5.4)
const HEAVY_DAMAGE := 2.5         # a heavy attack does this many times a normal hit (rounded up)
const HEAVY_PUSH := 2.2           # and knocks the enemy back this much further

# --- enemies: health, damage per hit, seconds to come back, combat XP, found-tool chance ------
const BOAR := {"hp": 12, "damage": 1, "respawn": 60.0, "xp": 25, "tool": 0.06}
const WOLF := {"hp": 8, "damage": 1, "respawn": 60.0, "xp": 12, "tool": 0.08}
const SHADOW_WOLF := {"hp": 26, "damage": 2, "respawn": 120.0, "xp": 45, "tool": 0.25}
## Enemies in tougher regions get more health (x) and hit harder (+).
const REGION_TOUGHNESS := {"meadow": {"hp": 1.0, "damage": 0}, "forest": {"hp": 1.5, "damage": 0}}

# --- tools --------------------------------------------------------------------------------------
## power: hits taken off a tree or rock per swing; damage: sword damage; speed: swing speed.
const TIERS := [
	{"name": "Worn", "color": Color(0.58, 0.5, 0.44), "power": 2, "damage": 2, "speed": 0.85},
	{"name": "Stone", "color": Color(0.33, 0.33, 0.32), "power": 3, "damage": 3, "speed": 1.0},
	{"name": "Copper", "color": Color(0.9, 0.52, 0.3), "power": 4, "damage": 4, "speed": 1.08},
	{"name": "Iron", "color": Color(0.82, 0.86, 0.92), "power": 6, "damage": 5, "speed": 1.16},
	{"name": "Steel", "color": Color(0.55, 0.72, 0.95), "power": 8, "damage": 6, "speed": 1.24},
]
const TOOL_RECIPES := [
	{"slot": "axe", "tier": 0, "cost": {"wood": 3, "stone": 2}},
	{"slot": "pickaxe", "tier": 0, "cost": {"wood": 3, "stone": 2}},
	{"slot": "sword", "tier": 0, "cost": {"wood": 3, "stone": 2}},
	{"slot": "axe", "tier": 1, "cost": {"wood": 8, "stone": 6, "flint": 2}},
	{"slot": "pickaxe", "tier": 1, "cost": {"wood": 8, "stone": 8, "flint": 2}},
	{"slot": "sword", "tier": 1, "cost": {"wood": 6, "stone": 10, "flint": 3}},
	{"slot": "axe", "tier": 2, "cost": {"wood": 12, "copper": 12, "hide": 3}},
	{"slot": "pickaxe", "tier": 2, "cost": {"wood": 12, "copper": 14, "hide": 3}},
	{"slot": "sword", "tier": 2, "cost": {"wood": 8, "copper": 16, "hide": 4}},
	{"slot": "axe", "tier": 3, "cost": {"wood": 14, "iron": 15, "resin": 2}},
	{"slot": "pickaxe", "tier": 3, "cost": {"wood": 14, "iron": 18, "resin": 2}},
	{"slot": "sword", "tier": 3, "cost": {"wood": 10, "iron": 20, "pelt": 5, "fang": 2}},
	# Steel: only once the village Smithy is built.
	{"slot": "axe", "tier": 4, "needs": "smithy", "cost": {"pinewood": 12, "iron": 20, "shard": 3}},
	{"slot": "pickaxe", "tier": 4, "needs": "smithy", "cost": {"pinewood": 12, "iron": 22, "shard": 3}},
	{"slot": "sword", "tier": 4, "needs": "smithy", "cost": {"pinewood": 10, "iron": 24, "shadow_pelt": 3, "fang": 2}},
]
const BAGS := [
	{"name": "Pouch", "slots": 12},
	{"name": "Leather Bag", "slots": 16, "cost": {"hide": 8, "wood": 8, "flint": 4}},
	{"name": "Traveller's Pack", "slots": 22, "cost": {"pelt": 8, "hide": 8, "resin": 3, "fang": 2}},
]
## Found tools: how often chests have one, how often it's a tier up, how often it's rare.
const CHEST_TOOL := 0.4
const FOUND_TIER_UP := 0.15
const FOUND_RARE := 0.25

# --- resources: hits, seconds to grow back, reach, tool, drops [item, min, max, chance] -------
const RESOURCES := {
	"tree": {"hits": 8, "respawn": 90.0, "radius": 0.6, "tool": "axe", "verb": "Chop",
		"drops": [["wood", 2, 3, 1.0], ["resin", 1, 1, 0.08]]},
	"apple_tree": {"hits": 8, "respawn": 90.0, "radius": 0.6, "tool": "axe", "verb": "Chop",
		"drops": [["wood", 2, 2, 1.0], ["apple", 1, 3, 1.0], ["resin", 1, 1, 0.08]]},
	"pine": {"hits": 10, "respawn": 120.0, "radius": 0.6, "tool": "axe", "verb": "Chop", "min_tier": 1,
		"wood_item": "pinewood", "drops": [["pinewood", 2, 3, 1.0], ["resin", 1, 1, 0.12]]},
	"rock": {"hits": 10, "respawn": 120.0, "radius": 1.0, "tool": "pickaxe", "verb": "Mine",
		"drops": [["stone", 2, 3, 1.0], ["flint", 1, 1, 0.15], ["shard", 1, 1, 0.04]]},
	"copper_rock": {"hits": 12, "respawn": 180.0, "radius": 1.0, "tool": "pickaxe", "verb": "Mine", "min_tier": 1,
		"drops": [["copper", 2, 3, 1.0], ["stone", 1, 2, 1.0]]},
	"iron_rock": {"hits": 16, "respawn": 240.0, "radius": 1.0, "tool": "pickaxe", "verb": "Mine", "min_tier": 2,
		"drops": [["iron", 2, 3, 1.0], ["stone", 1, 2, 1.0], ["shard", 1, 1, 0.08]]},
	"mushroom": {"hits": 1, "respawn": 60.0, "radius": 0.3, "tool": "", "verb": "Pick",
		"drops": [["mushroom", 1, 1, 1.0], ["glowcap", 1, 1, 0.06]]},
	"flower": {"hits": 1, "respawn": 60.0, "radius": 0.3, "tool": "", "verb": "Pick",
		"drops": [["flower", 1, 2, 1.0]]},
	"chest": {"hits": 1, "respawn": 600.0, "radius": 0.5, "tool": "", "verb": "Open",
		"drops": [["flint", 2, 4, 1.0], ["resin", 1, 2, 0.8], ["shard", 1, 2, 0.7], ["glowcap", 1, 1, 0.5], ["fang", 1, 1, 0.3]]},
}
## Trees by size: same size = same work and wood, whatever the kind.
const TREE_STAGES := [
	{"up_to": 0.9, "name": "Young", "hits": 6, "wood": [1, 2], "resin": 0.04},
	{"up_to": 1.15, "name": "Grown", "hits": 8, "wood": [2, 3], "resin": 0.08},
	{"up_to": 99.0, "name": "Old", "hits": 12, "wood": [4, 5], "resin": 0.16},
]
const GROW_TIME := 300.0          # seconds from sapling to full size

# --- skills -------------------------------------------------------------------------------------
const MAX_LEVEL := 30
const XP_BASE := 40.0             # XP for a level: XP_BASE * (level - 1) ^ XP_POWER
const XP_POWER := 1.8
const XP_PER_GATHER_HIT := 2
const XP_PER_SWORD_HIT := 1
const SPEED_PER_LEVEL := 0.015    # gathering swings get faster per level
const LUCK_PER_LEVEL := 0.01      # extra-drop chance per level
const LEVELS_PER_DAMAGE := 10     # +1 sword damage every this many combat levels

# --- food: hearts healed, buff and its length ---------------------------------------------------
const FOODS := {
	"apple": {"heal": 1},
	"mushroom": {"heal": 1},
	"roast_meat": {"heal": 2, "buff": "strong", "secs": 90.0},
	"skewer": {"heal": 1, "buff": "swift", "secs": 90.0},
	"apple_tart": {"heal": 2, "buff": "nimble", "secs": 120.0},
	"stew": {"heal": 5, "buff": "sturdy", "secs": 120.0},
}
const COOKING := [
	{"out": "roast_meat", "cost": {"raw_meat": 1, "wood": 1}},
	{"out": "skewer", "cost": {"mushroom": 3, "wood": 1}},
	{"out": "apple_tart", "cost": {"apple": 2, "flower": 1, "wood": 1}},
	{"out": "stew", "cost": {"raw_meat": 1, "mushroom": 2, "glowcap": 1, "wood": 1}},
]
const STRONG_DAMAGE := 1          # extra sword damage
const SWIFT_SPEED := 1.2          # run speed multiplier
const NIMBLE_SPEED := 1.25        # gathering speed multiplier
const STURDY_BLOCK := 1           # damage taken off each hit (never below 1)
const MEAT_CHANCE := {"boar": 1.0, "wolf": 0.5}

# --- coins --------------------------------------------------------------------------------------
## What the trader pays for one.
const VALUES := {
	"wood": 1, "stone": 1, "apple": 2, "mushroom": 2, "flower": 1, "flint": 3, "resin": 8, "glowcap": 10,
	"shard": 12, "hide": 4, "tusk": 8, "copper": 3, "iron": 5, "pelt": 6, "fang": 12, "pinewood": 3,
	"shadow_pelt": 25, "raw_meat": 3, "roast_meat": 6, "skewer": 6, "apple_tart": 8, "stew": 15,
}
## What the trader may stock: [item, amount, price]. "tool" = a found tool with a bonus.
const STOCK_POOL := [["flint", 3, 18], ["raw_meat", 2, 15], ["glowcap", 1, 40], ["resin", 1, 30],
	["shard", 1, 50], ["stew", 1, 55], ["iron", 4, 40], ["copper", 5, 25], ["tool", 1, 150]]
const STOCK_SIZE := 4
const RESTOCK_EVERY := 900

# --- village projects and your home ------------------------------------------------------------
const PROJECTS := {"smithy": {"coins": 250, "cost": {"stone": 25, "pinewood": 15, "iron": 8}}}
## Buying a home: coins, and you must have got this far first.
const HOME := {"coins": 1200, "needs_project": "smithy", "needs_skill_total": 25}
## What you can build on your plot, and what each costs.
const HOME_PIECES := {
	"fence": {"wood": 3},
	"lantern_post": {"wood": 3, "resin": 1},
	"bench": {"wood": 6},
	"flower_bed": {"wood": 4, "flower": 4},
	"campfire": {"wood": 6, "stone": 6},
	"workbench": {"wood": 12, "stone": 8},
	"tree": {"wood": 2, "apple": 1},
	"rock": {"stone": 5},
}

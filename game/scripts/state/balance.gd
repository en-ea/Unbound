class_name Balance
extends RefCounted
## Every number that decides how the game plays, in one place: enemies, your hearts, tools, recipes,
## resources, food, prices, projects and skills. Change a number here and it changes everywhere.
##
## Targets (a steady, not-too-easy climb; tune by playing):
## - Stone tools ~5 min in, Copper ~15 min, Iron ~40 min, Steel (needs the Smithy) ~1.5 h.
## - Fights (tuned harder 30 Sep: "too easy"): a fresh player needs ~7 hits on a boar and a charge
##   takes 2 hearts, so dodging matters; a pack of 2 wolves knocks a careless player out. Forest enemies are tougher than meadow ones. Food matters for hard fights.
## - Hearts come back slowly on their own; food heals fast.
## - Coins: selling a trip's worth of loot pays ~30-60; the Smithy takes a few trips; a home much more.

# --- you ---------------------------------------------------------------------------------------
const HEARTS := 5
const REGEN_DELAY := 12.0         # seconds without a hit before hearts start coming back
const REGEN_EVERY := 9.0          # then one heart this often
## Stamina: sprinting (hold Roll), rolling and heavy attacks use it; it refills after a short pause.
## Run it empty and you are winded: no sprint, roll or heavy until it is back to `winded_until`.
const STAMINA := {"max": 100.0, "regen": 34.0, "delay": 0.6, "sprint": 20.0, "roll": 26.0, "heavy": 34.0,
	"guard": 10.0, "block": 24.0, "winded_until": 35.0}
## The Red Hand bandits (creatures/bandit.gd): hit points, damage (hearts), run speed, how far they
## circle, how often they block a hit from the front, combo length, XP and coins dropped.
const BANDITS := {
	"cutthroat": {"hp": 14, "damage": 1, "speed": 3.8, "circle": 3.0, "block": 0.3, "combo": [2, 3], "rest": [1.0, 2.2], "xp": 30, "coins": [4, 10]},
	"shield": {"hp": 20, "damage": 1, "speed": 3.1, "circle": 2.5, "block": 1.0, "combo": [1, 2], "rest": [1.4, 2.6], "xp": 35, "coins": [5, 11]},
	"archer": {"hp": 9, "damage": 1, "speed": 4.0, "range": [7.0, 13.0], "aim": 1.1, "rest": [1.6, 2.8], "xp": 25, "coins": [3, 8]},
	"leader": {"hp": 48, "damage": 2, "speed": 4.4, "circle": 2.8, "block": 0.45, "combo": [3, 4], "rest": [0.7, 1.5], "xp": 160, "coins": [40, 70]},
}
const BANDIT_TURNS := 2          # how many bandits may attack you at once (the rest circle and wait)
## Sneaking and being seen: sight range standing / sneaking, at night (times), the view cone (dot), how
## fast they notice you up close (per second), how fast they forget, how far noise carries, the shout
## that alerts the camp, and reach for a takedown from behind.
const STEALTH := {"sight": 15.0, "sight_sneak": 6.0, "night": 0.6, "fov": 0.25, "notice": 1.6, "forget": 0.3,
	"noise_walk": 4.5, "noise_run": 9.0, "noise_sprint": 14.0, "noise_fight": 12.0, "noise_sneak": 1.2,
	"shout": 22.0, "takedown": 1.9, "sneak_speed": 2.2, "give_up": 32.0}

## Parry and perfect dodge (player.gd): guard length, the perfect-parry part of it, the pause before the
## next guard, the start of a roll that counts as a perfect dodge, slow motion after one, the counter window.
const DEFENCE := {"guard": 0.55, "parry": 0.22, "guard_rest": 0.35, "perfect_dodge": 0.26, "slow": 0.3,
	"slow_secs": 0.9, "counter_secs": 2.5, "parry_stun": 1.6}
const SPRINT_SPEED := 7.6         # m/s (a run is 5.4)
const HEAVY_DAMAGE := 2.5         # a heavy attack does this many times a normal hit (rounded up)
const HEAVY_PUSH := 2.2           # and knocks the enemy back this much further

# --- enemies: health, damage per hit, seconds to come back, combat XP, found-tool chance ------
const BOAR := {"hp": 20, "damage": 2, "respawn": 60.0, "xp": 25, "tool": 0.06}
const WOLF := {"hp": 12, "damage": 1, "respawn": 60.0, "xp": 12, "tool": 0.08}
const SHADOW_WOLF := {"hp": 40, "damage": 2, "respawn": 120.0, "xp": 45, "tool": 0.25}
## How enemies fight (boar.gd, wolf.gd). The glint is always honest: it comes a fixed beat before a real
## attack; the red glow before it can be held (delay) or faked (a wolf's feint has no glint).
const FIGHT := {
	"boar_poise": 3,        # light hits in a quick row before a boar braces and counters with a tusk swipe
	"wolf_poise": 2,        # ... before a wolf leaps away (and a packmate takes the opening)
	"poise_decay": 1.1,     # seconds for one of those hits to be forgotten
	"hold_max": 0.55,       # the longest extra hold of a wind-up before the glint
	"boar_recharge": 0.6,   # chance a wounded boar (under half health) charges again straight after a miss
	"boar_daze": 2.2,       # seconds a boar is dazed after charging into a tree or wall
	"swipe_reach": 2.3,     # a boar swipes with its tusks instead of charging when you are this close in front
	"wolf_feint": 0.3,      # chance a wolf's wind-up is a fake: a hop and a snap at the air, no glint
	"wolf_dodge": 0.4,      # chance a circling wolf hops away from your swing
	"wolf_pincer": 0.35,    # chance a second wolf strikes right after the first
	"wolf_stumble": 0.65,   # seconds a wolf stumbles after a missed lunge (your opening)
}
## Enemies in tougher regions get more health (x) and hit harder (+).
const REGION_TOUGHNESS := {"meadow": {"hp": 1.0, "damage": 0}, "forest": {"hp": 1.6, "damage": 1}}

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
## Found gear: how often chests have a piece, and how often it's a tier above the best you've had.
const CHEST_TOOL := 0.4
const FOUND_TIER_UP := 0.15

# --- loot: rarities, what rolls where, bonuses, armour -----------------------------------------
## stat: multiplies the piece's main number (damage, power, defence); bonuses: how many it rolls.
const RARITIES := [
	{"name": "Common", "color": Color(0.86, 0.86, 0.82), "bonuses": 0, "stat": 1.0},
	{"name": "Uncommon", "color": Color(0.46, 0.86, 0.4), "bonuses": 1, "stat": 1.05},
	{"name": "Rare", "color": Color(0.36, 0.62, 1.0), "bonuses": 2, "stat": 1.1},
	{"name": "Epic", "color": Color(0.72, 0.42, 0.98), "bonuses": 2, "stat": 1.18},
	{"name": "Legendary", "color": Color(1.0, 0.64, 0.18), "bonuses": 3, "stat": 1.28},
	{"name": "Mythic", "color": Color(1.0, 0.3, 0.46), "bonuses": 3, "stat": 1.4},
]
## Once a source drops gear, the odds (weights) of each rarity, Common to Mythic.
const LOOT_ODDS := {
	"enemy": [55, 30, 11, 3.2, 0.7, 0.1],
	"elite": [20, 34, 28, 13, 4.2, 0.8],        # shadow wolves (later: champions)
	"chest": [28, 34, 24, 10, 3.4, 0.6],
	"trader": [0, 55, 33, 12, 0, 0],
}
## Which kind of gear a find is (weights): weapon, gathering tool, armour.
const LOOT_KINDS := {"weapon": 40, "tool": 25, "armor": 35}
## Bonuses: which gear can roll them, the value range (low at Common, high at Mythic), and the text.
## The numbers are plain stats, read by fighting, gathering and movement, whatever form those take.
const BONUSES := {
	"sharp": {"on": ["weapon"], "range": [6, 30], "text": "+%d%% damage", "adj": "Sharp", "noun": "Edges"},
	"keen": {"on": ["weapon"], "range": [4, 20], "text": "%d%% critical hits", "adj": "Keen", "noun": "Precision"},
	"vampiric": {"on": ["weapon"], "range": [3, 12], "text": "%d%% chance a hit heals", "adj": "Vampiric", "noun": "Hunger"},
	"swift": {"on": ["weapon", "tool"], "range": [5, 22], "text": "+%d%% swing speed", "adj": "Swift", "noun": "Haste"},
	"mighty": {"on": ["tool"], "range": [1, 3], "text": "+%d gathering power", "adj": "Mighty", "noun": "Might"},
	"lucky": {"on": ["tool", "armor"], "range": [6, 25], "text": "+%d%% extra drops", "adj": "Lucky", "noun": "Luck"},
	"sturdy": {"on": ["armor"], "range": [1, 4], "text": "+%d defence", "adj": "Sturdy", "noun": "Stone"},
	"fleet": {"on": ["armor"], "range": [3, 12], "text": "+%d%% move speed", "adj": "Fleet", "noun": "Wind"},
	"mending": {"on": ["armor"], "range": [10, 40], "text": "Hearts return %d%% faster", "adj": "Mending", "noun": "Life"},
}
## Armour: one tier list for helm, chest and boots; defence per piece is tier defence x the piece's share.
const ARMOR_TIERS := [
	{"name": "Padded", "defence": 1, "color": Color(0.72, 0.62, 0.46)},
	{"name": "Hide", "defence": 2, "color": Color(0.5, 0.36, 0.26)},
	{"name": "Copper", "defence": 3, "color": Color(0.9, 0.52, 0.3)},
	{"name": "Iron", "defence": 4, "color": Color(0.82, 0.86, 0.92)},
	{"name": "Steel", "defence": 6, "color": Color(0.55, 0.72, 0.95)},
]
const ARMOR_SHARE := {"helm": 1.0, "chest": 2.0, "boots": 1.0}
## Defence turns into a chance that a hit costs no heart: defence / (defence + ARMOR_HALF).
## (So 15 defence blocks 1 hit in 3.) Easy to swap for another rule if fighting changes.
const ARMOR_HALF := 30.0

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
	"tobacco": {"hits": 1, "respawn": 90.0, "radius": 0.3, "tool": "", "verb": "Pick",
		"drops": [["tobacco", 1, 2, 1.0]]},
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
	{"out": "cigarette", "n": 3, "cost": {"tobacco": 2, "wood": 1}},
]
const SMOKE_SECS := 24.0          # one cigarette, start to stub
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
	"shadow_pelt": 25, "tobacco": 2, "cigarette": 3, "raw_meat": 3, "roast_meat": 6, "skewer": 6, "apple_tart": 8, "stew": 15,
	"red_hand": 6, "stag_hide": 10, "antler": 14, "crown_antlers": 60, "duskmaw_fang": 90,
}
## Hunting (world/carcass.gd, state/hunting.gd): how long a body stays fresh, then rots away (seconds);
## scavengers; the stag; the Duskmaw that three bodies at night call up.
const HUNT := {
	"fresh_for": 180.0, "rot_time": 300.0, "max_carcasses": 6,
	"crows_after": 25.0, "wolves_after": 40.0, "wolf_smell": 40.0, "village_takes_after": 60.0,
	"drag_speed": 1.3, "carve_time": 1.2, "cart_speed": 6.0, "cart_slots": 3,
	"summon_count": 3, "summon_spread": 10.0, "summon_wait": 12.0,
}
const STAG := {"hp": 24, "damage": 2, "respawn": 90.0, "xp": 30, "sight": 16.0, "sight_sneak": 5.0, "flee_speed": 8.0}
const DUSKMAW := {"hp": 160, "damage": 3, "xp": 250, "size": 2.1}
## What the trader may stock: [item, amount, price]. "tool" = a found tool with a bonus.
const STOCK_POOL := [["flint", 3, 18], ["raw_meat", 2, 15], ["glowcap", 1, 40], ["resin", 1, 30],
	["shard", 1, 50], ["stew", 1, 55], ["iron", 4, 40], ["copper", 5, 25], ["cigarette", 5, 20], ["tool", 1, 150]]
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
## Furniture for inside your home, and what each costs (a new home comes with a few pieces).
const HOME_FURNITURE := {
	"bed": {"wood": 12, "pelt": 2},
	"table": {"wood": 8},
	"chair": {"wood": 4},
	"stool": {"wood": 2},
	"armchair": {"wood": 6, "pelt": 3},
	"bookshelf": {"wood": 10, "pinewood": 2},
	"wardrobe": {"pinewood": 8, "wood": 4},
	"dresser": {"pinewood": 6, "stone": 3},
	"trunk": {"wood": 6, "copper": 2},
	"plant": {"flower": 3, "stone": 2},
	"lamp": {"wood": 3, "resin": 1},
	"trophy": {"crown_antlers": 1, "wood": 2},
	"rug_round": {"hide": 3, "flower": 2},
	"rug_long": {"pelt": 2, "hide": 2},
}

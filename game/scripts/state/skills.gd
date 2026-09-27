extends Node
## Skills that grow as you use them (game state): woodcutting, mining and combat. Each hit gives
## a little experience, finishing a tree, rock or enemy gives more. Levels give small perks:
## faster swings and a chance of extra drops for gathering, more sword damage for combat.

signal gained(skill: String, amount: int)
signal leveled(skill: String, level: int)

const SKILLS := {"woodcutting": "Woodcutting", "mining": "Mining", "combat": "Combat"}
const MAX_LEVEL := 30
## Which skill a tool trains.
const FOR_TOOL := {"axe": "woodcutting", "pickaxe": "mining", "sword": "combat"}

var xp := {"woodcutting": 0, "mining": 0, "combat": 0}


## Total experience needed to reach a level (level 2 after about one tree).
static func xp_for(lvl: int) -> int:
	return int(15.0 * pow(lvl - 1, 1.6))


func level(skill: String) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and xp[skill] >= xp_for(lvl + 1):
		lvl += 1
	return lvl


## How far through the current level (0..1).
func progress(skill: String) -> float:
	var lvl := level(skill)
	if lvl >= MAX_LEVEL:
		return 1.0
	var lo := xp_for(lvl)
	return float(xp[skill] - lo) / float(xp_for(lvl + 1) - lo)


## The action: experience for using a skill.
func add(skill: String, amount: int) -> void:
	if not xp.has(skill) or amount <= 0:
		return
	var before := level(skill)
	xp[skill] += amount
	gained.emit(skill, amount)
	var after := level(skill)
	if after > before:
		leveled.emit(skill, after)


## Swings get 1.5% faster per level (gathering skills).
func speed_bonus(skill: String) -> float:
	return 1.0 + 0.015 * (level(skill) - 1)


## Chance of an extra drop: 1% per level (gathering skills).
func luck_bonus(skill: String) -> float:
	return 0.01 * (level(skill) - 1)


## Extra sword damage: +1 at combat level 10, +2 at 20, +3 at 30.
func damage_bonus() -> int:
	return level("combat") / 10


## One line on what the next level brings, for the Bag.
func perk_text(skill: String) -> String:
	if skill == "combat":
		return "+%d damage" % damage_bonus()
	return "+%d%% speed · +%d%% extra drops" % [roundi((speed_bonus(skill) - 1.0) * 100), roundi(luck_bonus(skill) * 100)]


func to_data() -> Dictionary:
	return xp


func load_data(data: Dictionary) -> void:
	for skill: String in SKILLS:
		xp[skill] = maxi(0, int(data.get(skill, 0)))

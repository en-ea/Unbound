extends Node
## Your class (game state, no visuals). The story starts at the standing stones: the shrine wakes
## (`awaken()`), then you pick a class (`choose()`). Only the Pyromancer is open; the other three are
## sealed until later in the story. Each class has abilities with cooldowns (`use()`); the player's
## abilities.gd does what they do. Any class can use any weapon. Saved with the game.

signal changed
signal awakened_now

const CLASSES := {
	"pyromancer": {"name": "Pyromancer", "color": Color(1.0, 0.5, 0.18),
		"blurb": "The fire under the stones chose you. Burn a path through them, then bring the sky down.",
		"abilities": ["flame_dash", "meteor", "cinderburst"]},
	"sealed_1": {"sealed": true},
	"sealed_2": {"sealed": true},
	"sealed_3": {"sealed": true},
}
## Numbers for each ability (the damage is in hits of your sword's power, see abilities.gd).
const ABILITIES := {
	"flame_dash": {"name": "Flame Dash", "short": "Dash", "cooldown": 5.0,
		"desc": "Burst through your enemies in a streak of fire. Nothing can touch you mid-dash, and all you pass through burns."},
	"meteor": {"name": "Meteor", "short": "Meteor", "cooldown": 12.0,
		"desc": "A glowing ring marks the nearest enemy, then a burning star hits it: a huge blast that throws them back and sets the ground alight."},
	"cinderburst": {"name": "Cinderburst", "short": "Burst", "cooldown": 14.0,
		"desc": "A ring of fire bursts out around you and sets everyone in it alight. Anyone who was already burning explodes, spreading the fire, and each explosion sends a spark of life back to you. Set them burning first, then pop them."},
}

## Talents: each class has branches of three, learned in order with talent points (one from the shrine,
## one per combat level). abilities.gd, fire_fx.gd and burning.gd check has_talent(). Free to reset.
const TALENT_TREES := {
	"pyromancer": [
		{"name": "Flame Dash", "talents": ["scorched_path", "second_wind", "flashpoint"]},
		{"name": "Meteor", "talents": ["greater_star", "falling_sky", "twin_stars"]},
		{"name": "Cinderburst", "talents": ["wide_ring", "feed_the_flames", "chain_reaction"]},
		{"name": "Kindling", "talents": ["slow_burn", "white_heat", "rekindle"]},
	],
}
const TALENTS := {
	"scorched_path": {"name": "Scorched Path", "desc": "The ground you dash across burns twice as long and twice as hot."},
	"second_wind": {"name": "Second Wind", "desc": "Flame Dash is ready again 30% sooner."},
	"flashpoint": {"name": "Flashpoint", "desc": "Your dash ends in a burst of fire that throws back everyone close."},
	"greater_star": {"name": "Greater Star", "desc": "Meteor's blast is a third wider."},
	"falling_sky": {"name": "Falling Sky", "desc": "Meteor is ready again 25% sooner."},
	"twin_stars": {"name": "Twin Stars", "desc": "A second, smaller star falls on another enemy."},
	"wide_ring": {"name": "Wide Ring", "desc": "Cinderburst's ring reaches much further."},
	"feed_the_flames": {"name": "Feed the Flames", "desc": "Each spark of life also refills your stamina, and up to five come back."},
	"chain_reaction": {"name": "Chain Reaction", "desc": "Enemies set alight by an explosion explode too, in a second, smaller wave."},
	"slow_burn": {"name": "Slow Burn", "desc": "Everything you set on fire burns half again as long."},
	"white_heat": {"name": "White Heat", "desc": "Your fire burns twice as hard."},
	"rekindle": {"name": "Rekindle", "desc": "Whenever a burning enemy dies, all your abilities come back 1.5 s sooner."},
}
## What a talent does to an ability's cooldown.
const COOLDOWN_TALENTS := {"flame_dash": ["second_wind", 0.7], "meteor": ["falling_sky", 0.75]}

var awakened := false
var current := ""
var talents: Array[String] = []   # learned talents
var bonus_points := 0             # extra points (the Paladin test code)
var _ready_at := {}          # ability -> time it can be used again (seconds, this run only)


## The story beat: the shrine on the hill wakes for you.
func awaken() -> void:
	if awakened:
		return
	awakened = true
	awakened_now.emit()
	changed.emit()


func choose(id: String) -> void:
	if not CLASSES.has(id) or CLASSES[id].get("sealed", false):
		return
	awakened = true
	current = id
	changed.emit()


func abilities() -> Array:
	return CLASSES[current]["abilities"] if current != "" else []


func color() -> Color:
	return CLASSES[current]["color"] if current != "" else Color.WHITE


## Seconds between uses, after talents.
func cooldown_of(ability: String) -> float:
	var cd: float = ABILITIES[ability]["cooldown"]
	if COOLDOWN_TALENTS.has(ability) and has_talent(COOLDOWN_TALENTS[ability][0]):
		cd *= COOLDOWN_TALENTS[ability][1]
	return cd


## 0 when ready, up to 1 right after use.
func cooldown_left(ability: String) -> float:
	var left: float = _ready_at.get(ability, 0.0) - _now()
	return clampf(left / cooldown_of(ability), 0.0, 1.0)


## The action: spend an ability. False (nothing happens) while it is cooling down.
func use(ability: String) -> bool:
	if not ability in abilities() or cooldown_left(ability) > 0.0:
		return false
	_ready_at[ability] = _now() + cooldown_of(ability)
	return true


## Rekindle: every ability comes back a little sooner.
func hurry_cooldowns(seconds: float) -> void:
	for a: String in _ready_at:
		_ready_at[a] -= seconds


func has_talent(id: String) -> bool:
	return id in talents


func tree() -> Array:
	return TALENT_TREES.get(current, [])


## Points earned so far: one from the shrine, one per combat level past the first, plus any bonus.
func points_total() -> int:
	return (1 + Skills.level("combat") - 1 + bonus_points) if current != "" else 0


func points_free() -> int:
	return points_total() - talents.size()


## Can be learned now: a free point, and the one before it in its branch is learned.
func can_learn(id: String) -> bool:
	if has_talent(id) or points_free() <= 0:
		return false
	for branch: Dictionary in tree():
		var list: Array = branch["talents"]
		var i := list.find(id)
		if i >= 0:
			return i == 0 or has_talent(list[i - 1])
	return false


## The action: learn a talent.
func learn(id: String) -> void:
	if can_learn(id):
		talents.append(id)
		changed.emit()


## The action: take every point back (free, so you can try other builds).
func reset_talents() -> void:
	talents.clear()
	changed.emit()


func reset() -> void:
	awakened = false
	current = ""
	talents.clear()
	_ready_at.clear()
	changed.emit()


func to_data() -> Dictionary:
	return {"awakened": awakened, "current": current, "talents": talents.duplicate(), "bonus": bonus_points}


func load_data(data: Variant) -> void:
	var d: Dictionary = data if data is Dictionary else {}
	awakened = d.get("awakened", false)
	current = d.get("current", "")
	if not CLASSES.has(current):
		current = ""
	talents.clear()
	for t: Variant in d.get("talents", []):
		if TALENTS.has(str(t)):
			talents.append(str(t))
	bonus_points = int(d.get("bonus", 0))
	changed.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

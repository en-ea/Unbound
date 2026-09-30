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

var awakened := false
var current := ""
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


## 0 when ready, up to 1 right after use.
func cooldown_left(ability: String) -> float:
	var left: float = _ready_at.get(ability, 0.0) - _now()
	return clampf(left / ABILITIES[ability]["cooldown"], 0.0, 1.0)


## The action: spend an ability. False (nothing happens) while it is cooling down.
func use(ability: String) -> bool:
	if not ability in abilities() or cooldown_left(ability) > 0.0:
		return false
	_ready_at[ability] = _now() + ABILITIES[ability]["cooldown"]
	return true


func reset() -> void:
	awakened = false
	current = ""
	_ready_at.clear()
	changed.emit()


func to_data() -> Dictionary:
	return {"awakened": awakened, "current": current}


func load_data(data: Variant) -> void:
	var d: Dictionary = data if data is Dictionary else {}
	awakened = d.get("awakened", false)
	current = d.get("current", "")
	if not CLASSES.has(current):
		current = ""
	changed.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

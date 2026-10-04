extends Node
## Your class (game state, no visuals). The story starts at the standing stones: the shrine wakes
## (`awaken()`), then you pick a class (`choose()`). The Pyromancer and the Delver are open; the other two
## are sealed until later in the story. Each class has abilities with cooldowns (`use()`); the player's
## abilities.gd does what they do. Any class can use any weapon. Saved with the game.

signal changed
signal awakened_now

const CLASSES := {
	"pyromancer": {"name": "Pyromancer", "color": Color(1.0, 0.5, 0.18),
		"blurb": "The fire under the stones chose you. Burn a path through them, then bring the sky down.",
		"trait": "Kindled: your blows land a third harder on anything burning, and at night or underground you glow with your own warm light.",
		"abilities": ["flame_dash", "meteor", "cinderburst"]},
	"delver": {"name": "Delver", "color": Color(0.36, 0.86, 0.72), "take": "Take the claws",
		"answer": "The deep earth answers you",
		"blurb": "Claws, not steel. Hunt them from below and drag the weak down with you.",
		"trait": "Cracked: your hits split their guard. Cracked foes take more from you and are easier to swallow. You also mine faster.",
		"abilities": ["burrow", "fault_line", "sinkhole"]},
	"shade": {"name": "Shade", "color": Color(0.62, 0.42, 1.0), "take": "Step into the dark",
		"answer": "Your shadow steps out to meet you",
		"blurb": "Born of the Long Night, when the sun failed and people learned to walk in their own shadows. Dance through them as shadow, leave a double to take the blows, then trade places with it.",
		"trait": "Unseen: hits from behind land half again as hard, you move quieter, and your roll is a slip through shadow.",
		"abilities": ["shadow_dance", "mirage", "switch"]},
	"sealed_3": {"sealed": true},
}
## Numbers for each ability (the damage is in hits of your sword's power, see abilities.gd).
const ABILITIES := {
	"flame_dash": {"name": "Flame Dash", "short": "Dash", "cooldown": 5.0,
		"desc": "Burst through your enemies in a streak of fire. Nothing can touch you mid-dash, and all you pass through burns."},
	"meteor": {"name": "Meteor", "short": "Meteor", "cooldown": 12.0,
		"desc": "A glowing ring marks the nearest enemy, then a burning star hits it: a huge blast that throws them back and sets the ground alight."},
	"burrow": {"name": "Burrow", "short": "Burrow", "cooldown": 8.0,
		"desc": "Sink into the ground and move fast, untouchable. Attack to erupt and throw everyone near into the air, or Drag the nearest foe under: the weak are swallowed whole, the rest stuck."},
	"fault_line": {"name": "Fault Line", "short": "Fault", "cooldown": 9.0,
		"desc": "A crack races ahead and stone spikes burst up along it, throwing and cracking everyone in its path."},
	"sinkhole": {"name": "Sinkhole", "short": "Sinkhole", "cooldown": 18.0,
		"desc": "The ground under a group caves in: it pulls them in and holds them, swallows the weak, then slams shut."},
	"shadow_dance": {"name": "Shadow Dance", "short": "Dance", "cooldown": 11.0,
		"desc": "Melt into shadow and flash from enemy to enemy, four cuts, each from a new side; a lone enemy takes all four. Nothing can touch you while you dance, and the last cut is the deepest."},
	"mirage": {"name": "Mirage", "short": "Mirage", "cooldown": 14.0,
		"desc": "A double of you, made of shadow, steps out where you stand as you slip back. Enemies near it go for it, and it fights them. When it's hit enough or its time runs out, it bursts in shadow."},
	"switch": {"name": "Switch", "short": "Switch", "cooldown": 9.0,
		"desc": "Trade places with your double, shadow bursting where you both stood. With no double out, you burst and vanish: enemies lose you for a moment."},
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
	"delver": [
		{"name": "Burrow", "talents": ["deep_runner", "ambush", "hungry_earth"]},
		{"name": "Fault Line", "talents": ["long_fault", "aftershock", "split_earth"]},
		{"name": "Sinkhole", "talents": ["wide_pit", "undertow", "earths_maw"]},
		{"name": "Claws", "talents": ["sharp_claws", "rend", "ore_heart"]},
	],
	"shade": [
		{"name": "Shadow Dance", "talents": ["deep_step", "quick_shadow", "assassin"]},
		{"name": "Mirage", "talents": ["lingering", "perfect_likeness", "twin_mirage"]},
		{"name": "Switch", "talents": ["wide_burst", "rebound", "nightfall"]},
		{"name": "Unseen", "talents": ["soft_steps", "knife_work", "shroud"]},
	],
}
const TALENTS := {
	"deep_step": {"name": "Long Dance", "desc": "Shadow Dance reaches half again as far and makes one more cut."},
	"quick_shadow": {"name": "Quick Shadow", "desc": "Shadow Dance is ready again 30% sooner."},
	"assassin": {"name": "Assassin", "desc": "The last cut of the dance lands three times as hard."},
	"lingering": {"name": "Lingering", "desc": "Your double lasts half again as long and takes two more hits."},
	"perfect_likeness": {"name": "Perfect Likeness", "desc": "Your double looks exactly like you. Enemies twice as far away are fooled."},
	"twin_mirage": {"name": "Twin Mirage", "desc": "Mirage makes two doubles, one either side of you."},
	"wide_burst": {"name": "Wide Burst", "desc": "Switch's bursts reach a third further."},
	"rebound": {"name": "Rebound", "desc": "Switch is ready again 30% sooner."},
	"nightfall": {"name": "Nightfall", "desc": "Switch's bursts hit twice as hard."},
	"soft_steps": {"name": "Soft Steps", "desc": "You sneak a third faster."},
	"knife_work": {"name": "Knife Work", "desc": "Hits from behind land three quarters harder instead of half."},
	"shroud": {"name": "Shroud", "desc": "At night and in caves, your abilities are ready 20% sooner."},
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
	"deep_runner": {"name": "Deep Runner", "desc": "Stay under twice as long, and dig faster."},
	"ambush": {"name": "Ambush", "desc": "Erupting hits twice as hard and leaves everyone it throws cracked for longer."},
	"hungry_earth": {"name": "Hungry Earth", "desc": "The earth swallows foes at half health (even more if they're cracked)."},
	"long_fault": {"name": "Long Fault", "desc": "Fault Line runs half again as far and is ready 25% sooner."},
	"aftershock": {"name": "Aftershock", "desc": "The spikes burst up a second time a moment later."},
	"split_earth": {"name": "Split Earth", "desc": "Fault Line splits three ways, in a fan."},
	"wide_pit": {"name": "Wide Pit", "desc": "Sinkhole opens a third wider."},
	"undertow": {"name": "Undertow", "desc": "Sinkhole holds them longer, pulls harder, and is ready 20% sooner."},
	"earths_maw": {"name": "Earth's Maw", "desc": "When the pit closes, stone jaws bite: twice the slam, and every cracked foe in it is swallowed."},
	"sharp_claws": {"name": "Sharp Claws", "desc": "Every third claw swipe cracks what it hits."},
	"rend": {"name": "Rend", "desc": "Cracked foes take twice the extra damage from you."},
	"ore_heart": {"name": "Ore Heart", "desc": "Each foe the earth swallows gives you two hearts back, and Burrow is ready again at once."},
}
## What a talent does to an ability's cooldown.
const COOLDOWN_TALENTS := {"flame_dash": ["second_wind", 0.7], "meteor": ["falling_sky", 0.75],
	"fault_line": ["long_fault", 0.75], "sinkhole": ["undertow", 0.8],
	"shadow_dance": ["quick_shadow", 0.7], "switch": ["rebound", 0.7]}

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
	if id != current:
		talents.clear()                 # talents belong to a class: switching gives the points back
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
	if current == "shade" and has_talent("shroud") and is_dark():
		cd *= 0.8
	return cd


## Night, or down in a cave (the Shade's Shroud, the Pyromancer's glow).
func is_dark() -> bool:
	var dn := get_tree().current_scene.get_node_or_null("WorldEnvironment") if get_tree().current_scene else null
	return dn != null and (float(dn.get("night")) > 0.5 or dn.get("cave") == true)


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


## Starts an ability's cooldown now (Burrow counts from when you come back up), or sets `seconds` left.
func start_cooldown(ability: String, seconds := -1.0) -> void:
	_ready_at[ability] = _now() + (cooldown_of(ability) if seconds < 0.0 else seconds)


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

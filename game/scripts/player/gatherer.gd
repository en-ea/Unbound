extends Node
## Finds the gatherable thing in reach and, on the action button, swings at it: faces it,
## plays the tool animation, and lands the hit (WorldResources.hit_node) mid-swing.

signal target_changed(verb: String)    # "Chop" / "Mine" / "Pick", or "" when nothing is in reach

const REACH := 1.1
## Per tool: animation, playback speed, seconds until the hit lands, total swing time.
## TreeChopping (Quaternius UAL2) loops from a wound-up pose; starting at 0.55 s gives the
## wind-up, then the strike lands 0.17 s into the next loop. Picking uses UAL1's PickUp_Table.
const SWINGS := {
	"axe": {"anim": "TreeChopping", "speed": 1.1, "start": 0.55, "impact": 0.54, "time": 0.88, "shake": 0.05},
	"pickaxe": {"anim": "TreeChopping", "speed": 1.1, "start": 0.55, "impact": 0.54, "time": 0.88, "shake": 0.07},
	"": {"anim": "PickUp_Table", "speed": 1.3, "start": 0.0, "impact": 0.3, "time": 0.6, "shake": 0.0},
}
const BUFFER := 0.25    # a tap this close to the end of a swing queues the next one

@onready var player: CharacterBody3D = get_parent()
@onready var visual: CharacterVisual = get_parent().get_node("Visual")

var target := -1
var verb := ""
var _busy := 0.0
var _impact := -1.0
var _swing_target := -1
var _queued := false
var _shake := 0.0
var _power := 1


func is_busy() -> bool:
	return _busy > 0.0


func _physics_process(delta: float) -> void:
	if _busy > 0.0:
		_busy -= delta
		if _busy <= 0.0:
			if _queued:
				_queued = false
				_busy = 0.0
				act()
			if _busy <= 0.0:
				visual.show_tool("")
	if _impact >= 0.0:
		_impact -= delta
		if _impact < 0.0 and _swing_target >= 0:
			WorldResources.hit_node(_swing_target, _power)
			if _shake > 0.0:
				visual.hit_stop()
				get_tree().call_group("camera_rig", "shake", _shake)
	var found := WorldResources.nearest(player.global_position, REACH)
	var new_verb: String = WorldResources.type_info(found)["verb"] if found >= 0 else ""
	target = found
	if new_verb != verb:
		verb = new_verb
		target_changed.emit(verb)


## The action button: one swing at the target in reach.
func act() -> void:
	if _busy > 0.0:
		_queued = _busy < BUFFER      # remember a tap made just before the swing ends
		return
	if target < 0 or Controls.locked:
		return
	var info := WorldResources.type_info(target)
	var tool: String = info["tool"]
	var swing: Dictionary = SWINGS[tool]
	var pace := Gear.speed(tool) if tool != "" else 1.0
	_power = Gear.power(tool) if tool != "" else 2      # bare hands pick flowers, open chests
	if tool != "" and Gear.tier(tool) < info.get("min_tier", 0):
		_power = 0                     # too hard for this pickaxe: it just glances off
		get_tree().call_group("hud", "hint", "Needs a %s" % Gear.tool_name(tool, info["min_tier"]))
	var at: Vector3 = WorldResources.get_node_data(target)["pos"]
	var to := at - player.global_position
	visual.rotation.y = atan2(to.x, to.z)
	visual.show_tool(tool)
	visual.play_action(swing["anim"], swing["speed"] * pace, swing["start"])
	_busy = swing["time"] / pace
	_impact = swing["impact"] / pace
	_swing_target = target
	_shake = swing["shake"]

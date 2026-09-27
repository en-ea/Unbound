extends Node
## Finds the gatherable thing in reach and, on the action button, swings at it: faces it,
## plays the tool animation, and lands the hit (WorldResources.hit_node) mid-swing.

signal target_changed(verb: String)    # "Chop" / "Mine" / "Pick", or "" when nothing is in reach

const REACH := 1.1
## Per tool: animation, playback speed, seconds until the hit lands, total swing time.
## (Chop / Mine / Gather are ours: tools-src/blender/make_anims.py; hits land on frame 13 / 13 / 10.)
const SWINGS := {
	"axe": {"anim": "Chop", "speed": 1.15, "impact": 0.377, "time": 0.8, "shake": 0.05},
	"pickaxe": {"anim": "Mine", "speed": 1.15, "impact": 0.377, "time": 0.8, "shake": 0.07},
	"": {"anim": "Gather", "speed": 1.2, "impact": 0.28, "time": 0.6, "shake": 0.0},
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
			WorldResources.hit_node(_swing_target)
			if _shake > 0.0:
				visual.hit_stop()
				get_tree().call_group("camera_rig", "shake", _shake)
	var found := WorldResources.nearest(player.global_position, REACH)
	var new_verb: String = WorldResources.type_info(found)["verb"] if found >= 0 else ""
	target = found
	if new_verb != verb:
		verb = new_verb
		target_changed.emit(verb)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_E, KEY_SPACE]:
		act()


## The action button: one swing at the target in reach.
func act() -> void:
	if _busy > 0.0:
		_queued = _busy < BUFFER      # remember a tap made just before the swing ends
		return
	if target < 0 or Controls.locked:
		return
	var info := WorldResources.type_info(target)
	var swing: Dictionary = SWINGS[info["tool"]]
	var at: Vector3 = WorldResources.get_node_data(target)["pos"]
	var to := at - player.global_position
	visual.rotation.y = atan2(to.x, to.z)
	visual.show_tool(info["tool"])
	visual.play_action(swing["anim"], swing["speed"])
	_busy = swing["time"]
	_impact = swing["impact"]
	_swing_target = target
	_shake = swing["shake"]

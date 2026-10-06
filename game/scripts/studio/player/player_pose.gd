extends Node
## The player's body answering Body's prepared intent (E3/B6; the animation specialist's studio adapter). Hands
## (studio/player/hands.gd) emits intent_changed every frame: a finger's prepared or cancelled verb with its strength
## (drag 0..1), a one-frame release, or idle with the live load, guard and crouch. This turns it into pose.gd layers on
## the player's own skeleton (CharacterVisual), one named layer per shape so shapes cross-fade:
##   strike   the right arm drawn back, the chest turned away, the fist closed - coiled further the further the drag
##   heavy    both hands up over the right shoulder, leaning back into it
##   shove    palms drawn back to the chest; released, they thrust out for a moment
##   guard    forearms up before the face, fists closed, chin down (also while the guard is held, idle)
##   grip     bent low, both hands down and forward (lift / lower)
##   use      a hand out before them;  power:*  a casting hand raised forward
##   carry    idle with a person on the back: both hands up at the chest holding them (a carcass is haul_pose.gd's)
## Cancelled shapes ease out; a strike or heavy releases at once into Enea's own swing clip. Presentation only: it
## reads no input, accepts nothing, saves nothing and decides nothing; the verbs are Body's.
## Active time: while the game is not active (Controls.locked or VillageSession.background, the rule residents, the
## player and the fighter use) nothing here moves - no fade, spring or thrust timer - and intents are not taken. On
## resume an unfinished thrust is dropped, never replayed, and the pose is reconciled from Hands' live preview (a held
## guard, a carried person, a finger still down).
##   PlayerPose.attach(hands)   one line where Hands is made (ui/hud.gd show_title, Body's studio hook)
##   show_intent(intent)        what intent_changed carries (a board or a check may call it directly)

const POSE := preload("res://scripts/studio/people/pose.gd")
const SHAPES := {
	"strike": {"reach_r": {"bone": "", "at": Vector3(-0.32, 1.42, -0.14), "pole": Vector3(-0.7, -0.3, -0.4), "priority": 3},
		"spine": Vector3(0.0, 0.0, -0.32), "fist_r": 1.0, "shoulders": 0.05},
	"heavy": {"reach_r": {"bone": "", "at": Vector3(-0.2, 1.82, -0.12), "pole": Vector3(-0.8, 0.0, -0.3), "priority": 3},
		"reach_l": {"bone": "", "at": Vector3(-0.06, 1.76, -0.06), "pole": Vector3(0.6, -0.2, -0.3), "priority": 3},
		"spine": Vector3(-0.16, 0.0, -0.42), "fist": 1.0},
	"shove": {"reach_l": {"bone": "", "at": Vector3(0.2, 1.3, 0.14), "pole": Vector3(0.7, -0.5, -0.2), "priority": 3},
		"reach_r": {"bone": "", "at": Vector3(-0.2, 1.3, 0.14), "pole": Vector3(-0.7, -0.5, -0.2), "priority": 3},
		"spine": Vector3(-0.08, 0.0, 0.0)},
	"guard": {"reach_l": {"bone": "", "at": Vector3(0.1, 1.52, 0.27), "pole": Vector3(0.8, -0.4, 0.0), "priority": 3},
		"reach_r": {"bone": "", "at": Vector3(-0.12, 1.46, 0.3), "pole": Vector3(-0.8, -0.4, 0.0), "priority": 3},
		"fist": 1.0, "head": Vector3(0.15, 0.0, 0.0), "spine": Vector3(0.12, 0.0, 0.0), "shoulders": 0.08},
	"grip": {"reach_l": {"bone": "", "at": Vector3(0.2, 0.72, 0.48), "priority": 3},
		"reach_r": {"bone": "", "at": Vector3(-0.2, 0.72, 0.48), "priority": 3}, "spine": Vector3(0.85, 0.0, 0.0),
		"head": Vector3(-0.25, 0.0, 0.0)},
	"use": {"reach_r": {"bone": "", "at": Vector3(-0.15, 1.05, 0.46), "priority": 3}},
	"power": {"reach_r": {"bone": "", "at": Vector3(-0.22, 1.55, 0.42), "priority": 3},
		"reach_l": {"bone": "", "at": Vector3(0.12, 1.2, 0.2), "priority": 3}, "spine": Vector3(-0.08, 0.0, 0.0)},
	"carry": {"reach_l": {"bone": "spine_03", "at": Vector3(0.2, 0.12, 0.2), "priority": 3},
		"reach_r": {"bone": "spine_03", "at": Vector3(-0.2, 0.12, 0.2), "priority": 3}},
	"thrust": {"reach_l": {"bone": "", "at": Vector3(0.2, 1.3, 0.55), "priority": 3},
		"reach_r": {"bone": "", "at": Vector3(-0.2, 1.3, 0.55), "priority": 3}, "spine": Vector3(0.15, 0.0, 0.0)},
}
const FULL := ["guard", "grip", "carry", "thrust"]   # shown whole; the others grow with the drag
const THRUST := 0.22                                  # seconds a released shove's palms stay out

var visual: Node3D              # the player's CharacterVisual (its basis is the player's own frame)
var player: Node                # read only for its visual
var _pose: SkeletonModifier3D
var _showing := ""
var _thrust_left := 0.0
var _was_active := true


static func attach(hands: Node) -> Node:
	var adapter: Node = (load("res://scripts/studio/player/player_pose.gd") as GDScript).new()
	adapter.player = hands.get("player")
	hands.add_child(adapter)
	hands.connect("intent_changed", Callable(adapter, "show_intent"))
	return adapter


func show_intent(intent: Dictionary) -> void:
	if not active() or not _ready_pose():
		return
	var phase := str(intent.get("phase", "idle"))
	var verb := str(intent.get("verb", ""))
	var s := clampf(float(intent.get("strength", 0.0)), 0.0, 1.0)
	if verb.begins_with("power:"):
		verb = "power"
	match phase:
		"prepared":
			_show(verb if SHAPES.has(verb) else "", s)
		"released":
			if verb == "shove":
				_thrust_left = THRUST
				_show("thrust", 1.0, 0.06)
			elif verb in ["guard", "crouch"]:
				pass                          # (a held guard stays: idle says so from the next frame)
			else:
				_show("", 0.0, 0.08)          # (the swing, the lift: Enea's clips take it from here)
		"cancelled":
			_show("", 0.0, 0.25)
		_:
			if _thrust_left > 0.0:
				return
			if str(intent.get("load", "")) == "person":
				_show("carry", 1.0)
			elif bool(intent.get("guard", false)):
				_show("guard", 1.0)
			else:
				_show("", 0.0)


func showing() -> String:
	return _showing


## Whether the game's active clock runs (the availability residents freeze their acts by).
static func active() -> bool:
	return not (Controls.locked or VillageSession.background)


func _process(delta: float) -> void:
	if not active():
		_was_active = false
		return                          # the presentation stands still with the game
	if not _was_active:
		_was_active = true
		_resume()
	if _thrust_left > 0.0:
		_thrust_left -= delta
		if _thrust_left <= 0.0:
			_show("", 0.0, 0.2)
	if _pose != null:
		_pose.step(delta)


## Back from inactive time: a release that happened before it is over (no thrust replayed), and what is live now -
## the guard still held, the person still carried, a finger still down - shows again.
func _resume() -> void:
	_thrust_left = 0.0
	if _pose == null:
		return
	var hands := get_parent()
	if hands != null and hands.has_method("preview"):
		show_intent(hands.preview())
	if _showing == "thrust":
		_show("", 0.0, 0.2)


func _show(shape: String, s: float, fade := 0.15) -> void:
	if shape != _showing and _showing != "":
		_pose.clear_layer("player:" + _showing, fade)
	_showing = shape
	if shape != "":
		_pose.set_layer("player:" + shape, SHAPES[shape], 1.0 if shape in FULL else 0.3 + 0.7 * s, fade)


func _ready_pose() -> bool:
	if _pose != null and is_instance_valid(_pose):
		return true
	if visual == null and is_instance_valid(player):
		visual = player.get("visual")
	if visual == null:
		return false
	var sk: Skeleton3D = visual.get("_skeleton")
	if sk == null:
		return false
	_pose = POSE.new()
	_pose.name = "PlayerPose"
	_pose.body = visual
	sk.add_child(_pose)
	return true

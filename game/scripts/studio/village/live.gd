extends Node
## Region presentation only. The persistent session admits actions and owns every consequence.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Stage := preload("res://scripts/studio/village/stage.gd")
const Residents := preload("res://scripts/studio/village/residents.gd")
var registry: Node3D
var _stage: Node3D
var _event := -1
var _revision := -1
var _label: Label
var _player: Node3D
var _feedback := ""
var _feedback_until := 0

static func on_device(_tree: SceneTree) -> void:
	pass # main attaches the same normal-game authority and bridge for this launch argument

func _ready() -> void:
	registry = Residents.new()
	add_child(registry)
	_player = get_tree().get_first_node_in_group("player")
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.position = Vector2(210, 98)
	_label.size = Vector2(820, 74)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 21)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_label)

func _process(_delta: float) -> void:
	var v = VillageSession.village
	if v == null:
		return
	var now := int(v.runtime.now)
	if _stage != null:
		var e := Runtime.event_by_id(v, _event)
		if e.is_empty() or e.phase == "cancelled" or now >= int(e.end):
			_close()
		else:
			var st := Runtime.staging(v, _event)
			_stage.external_minute = float(now - int(st.day) * 1440) + float(v.runtime.fraction)
			if int(e.revision) != _revision:
				_revision = int(e.revision)
				if e.outcome == "rescued":
					_stage.show_rescue()
	if _stage == null:
		for e: Dictionary in v.runtime.events:
			if not Runtime.terminal(e) and now >= int(e.from) - 20 and now < int(e.deadline):
				_open(e)
				break
	_update_cue(now)

func _open(e: Dictionary) -> void:
	var v = VillageSession.village
	var st := Runtime.staging(v, int(e.id))
	if st.is_empty():
		return
	_stage = Stage.new()
	_stage.resident_registry = registry
	_stage.external_clock = true
	add_child(_stage)
	_event = int(e.id)
	_revision = int(e.revision)
	var people := []
	for person: Dictionary in st.people:
		var p = v.people[int(person.id)]
		if p.alive and p.present:
			people.append(person)
	_stage.play(st, people)
	var minute := float(int(v.runtime.now) - int(st.day) * 1440)
	# Preparation can start before the first beat without fast-forwarding the event clock.
	_stage._clock = (minf(minute, float(st.start)) - float(st.start)) * 0.5
	_stage.external_minute = minute
	if minute > float(st.start):
		_stage._player = null # restoration cannot invent player contacts from historical projectiles
		_stage.skip_to(minute)
		_stage._player = _player
	_stage.action_authority = _act

func _act(verb: String, parameters: Dictionary) -> Dictionary:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	if e.is_empty() or _stage == null or _stage._victim == null or Controls.locked:
		return {"accepted": false, "reason": "unavailable"}
	var pos: Vector2 = _stage._victim.pos
	var distance := Vector2(_player.global_position.x, _player.global_position.z).distance_to(pos)
	var req := {"action_id": "%s:%d:%s" % [v.runtime.village, _event, verb], "player_id": "player:local",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "event_id": _event, "verb": verb, "parameters": parameters}
	var result := Runtime.act(v, req, {"distance_dm": int(ceil(distance * 10.0))})
	_feedback = "Free! I'll hide in the far woods. I won't forget you." if result.accepted else "Too late to intervene." if result.reason == "window closed" else result.reason
	_feedback_until = int(v.runtime.now) + 20
	if result.accepted:
		SaveGame.save_game() # accepted state and existing inventory share the normal atomic save
	return result

func _update_cue(now: int) -> void:
	if now < _feedback_until:
		_label.text = _feedback
		return
	var v = VillageSession.village
	var nearest := -1
	var distance := 6.0
	for id: int in registry.bodies:
		var body: Node3D = registry.bodies[id]
		if not body.visible or not v.people[id].alive or not v.people[id].present:
			continue
		var d := _player.global_position.distance_to(body.global_position)
		if d < distance:
			nearest = id; distance = d
	_label.text = ""
	if nearest >= 0:
		var p = v.people[nearest]
		var memory: Dictionary = v.runtime.residents.get(str(nearest), {})
		_label.text = "%s · %s" % [p.name, "You cut me loose. Thank you." if memory.has("rescued_by") else p.role.capitalize()]
	if _stage != null and _player.global_position.distance_to(Vector3(_stage.place_at().x, _player.global_position.y, _stage.place_at().y)) < 12.0:
		var e := Runtime.event_by_id(v, _event)
		var name: String = v.people[int(e.victim)].name
		_label.text = "%s · %s" % [name, "Approach the restraint to Free; stand between a thrower and the victim to shield." if not Runtime.terminal(e) else e.outcome.capitalize()]

func _close() -> void:
	if _stage != null:
		_stage.action_authority = Callable()
		_stage.clear()
		_stage.queue_free()
		_stage = null
	_event = -1

func _exit_tree() -> void:
	# Scene teardown frees both registry and stage; no reparenting or delayed state callbacks.
	if is_instance_valid(_stage):
		_stage.action_authority = Callable()
		_stage.set_process(false)

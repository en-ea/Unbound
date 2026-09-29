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
var _choices: HBoxContainer
var _buttons := {}
var _traces := {}
var _storm_props := {}
const Props := preload("res://scripts/studio/village/props.gd")
const StageProps := preload("res://scripts/studio/village/stage_props.gd")
const UseSpot := preload("res://scripts/world/use_spot.gd")

static func on_device(_tree: SceneTree) -> void:
	pass # main attaches the same normal-game authority and bridge for this launch argument

func _ready() -> void:
	if not VillageSession.recovery_notice.is_empty():
		_feedback = VillageSession.recovery_notice
		_feedback_until = int(VillageSession.village.runtime.now) + 30
		VillageSession.recovery_notice = ""
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
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 21)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_label)
	_choices = HBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_choices.position = Vector2(300, 510)
	_choices.add_theme_constant_override("separation", 8)
	layer.add_child(_choices)
	for verb: String in ["listen", "testify", "bribe", "inspect", "plant", "offer"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(132, 50)
		button.add_theme_font_size_override("font_size", 19)
		button.text = {"listen": "Listen", "testify": "Testify", "bribe": "Offer 5 coins", "inspect": "Inspect trace", "plant": "Plant 1 wood", "offer": "Gesture: 1 wood"}[verb]
		button.pressed.connect(_choose.bind(verb))
		_choices.add_child(button)
		_buttons[verb] = button

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
			for actor in _stage._actors:
				if actor == _stage._victim and Runtime.terminal(e):
					continue # the committed fall or departure remains visible briefly
				if not v.people[actor.id].alive or not v.people[actor.id].present:
					actor.gone = true
					actor.pending.clear()
					if actor.body != null:
						_stage._hide(actor, true)
			_stage.external_minute = float(now - int(st.day) * 1440) + float(v.runtime.fraction)
			if int(e.revision) != _revision:
				_revision = int(e.revision)
				if e.outcome in ["rescued", "spared"]:
					_stage.show_rescue()
				elif e.type == "hearing" and Runtime.terminal(e):
					_stage.show_verdict(e.outcome)
				elif Runtime.terminal(e):
					var resident = v.people[int(e.victim)]
					_stage.show_outcome(e.outcome, resident.alive, resident.present)
	if _stage == null:
		for e: Dictionary in v.runtime.events:
			if not Runtime.terminal(e) and now >= int(e.from) - 20 and now < int(e.deadline):
				_open(e)
				break
	_update_cue(now)
	_update_choices()
	_update_traces()
	_update_storms()

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
	if e.is_empty() or _stage == null or _stage._victim == null or Controls.locked or VillageSession.background or _player._down > 0.0:
		return {"accepted": false, "reason": "unavailable"}
	var pos := _action_at(verb, parameters)
	var distance := Vector2(_player.global_position.x, _player.global_position.z).distance_to(pos)
	var req := {"action_id": "%d:%s:%s" % [_event, verb, JSON.stringify(parameters)], "player_id": "player:local",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "event_id": _event, "verb": verb, "parameters": parameters}
	var witnesses := []
	for id: int in registry.bodies:
		var body: Node3D = registry.bodies[id]
		if body.visible and body.global_position.distance_to(_player.global_position) < 7.0:
			witnesses.append(id)
	var context := {"distance_dm": int(ceil(distance * 10.0)), "coins": Money.coins, "wood": Inventory.count("wood"),
		"witnesses": witnesses, "intercepted": parameters.get("intercepted", false)}
	var result := Runtime.act(v, req, context)
	_feedback = str(result.outcome) if result.accepted else str(result.reason)
	if result.accepted and result.outcome in ["rescued", "spared"]:
		_feedback = "Free! I'll hide in the far woods. I won't forget you."
	elif result.accepted and result.has("clue"):
		var clue: Dictionary = result.clue
		_feedback = "Trace points to %s." % v.people[int(clue.culprit)].name if clue.via == "trace" else "%s's account names %s. One source, even when retold." % [v.people[int(clue.speaker)].name, v.people[int(clue.culprit)].name]
	_feedback_until = int(v.runtime.now) + 20
	if result.accepted and not result.get("duplicate", false):
		if int(result.get("coins", 0)) > 0:
			Money.spend(int(result.coins))
		if int(result.get("wood", 0)) > 0:
			Inventory.remove("wood", int(result.wood))
		if int(result.get("damage", 0)) > 0:
			_player.take_damage(int(result.damage))
		SaveGame.save_game() # accepted state and existing inventory share the normal atomic save
	return result

func _actor_at(id: int) -> Vector2:
	if registry.bodies.has(id):
		var body: Node3D = registry.bodies[id]
		return Vector2(body.global_position.x, body.global_position.z)
	return Vector2.INF

func _action_at(verb: String, params: Dictionary) -> Vector2:
	if _stage == null:
		return Vector2.INF
	if verb == "listen":
		return _actor_at(int(params.get("speaker", -1)))
	if verb in ["inspect", "plant"]:
		return registry.place(params.get("place", ""))
	if verb in ["testify", "bribe", "offer"] and _stage._authority != null:
		return _stage._authority.pos
	return _stage._victim.pos

func _parameters(verb: String) -> Dictionary:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	if e.is_empty():
		return {}
	if verb == "listen":
		var best := -1
		var distance := 2.5
		var player_at := Vector2(_player.global_position.x, _player.global_position.z)
		for id in e.witnesses:
			var d := player_at.distance_to(_actor_at(int(id)))
			if d < distance:
				best = int(id); distance = d
		return {"speaker": best}
	if e.type == "hearing":
		var cs = v.cases[e.source.case_id]
		var crime = v.crimes[cs.crime]
		if verb == "inspect":
			return {"place": v.place_names[crime.trace_at] if crime.trace_at >= 0 else ""}
		if verb == "plant":
			return {"place": v.households[v.people[int(e.victim)].household].home}
		if verb == "testify":
			var account: Dictionary = v.runtime.players.get("player:local", {})
			for clue: Dictionary in account.get("knowledge", []):
				if int(clue.crime) == cs.crime and not e.testimony.has(clue.origin):
					return {"origin": clue.origin}
	return {}

func _choose(verb: String) -> void:
	_act(verb, _parameters(verb))

func _update_choices() -> void:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	for verb: String in _buttons:
		var button: Button = _buttons[verb]
		button.visible = false
		if e.is_empty() or Runtime.terminal(e) or Controls.locked:
			continue
		if (verb in ["testify", "bribe", "inspect", "plant"] and e.type != "hearing") or (verb == "offer" and e.type != "rite"):
			continue
		if verb == "listen" and e.type == "rite":
			continue # distant speech: a visible gesture/offer is the available social action
		var params := _parameters(verb)
		if verb in ["inspect", "plant"] and params.get("place", "").is_empty():
			continue
		var at := _action_at(verb, params)
		button.visible = Vector2(_player.global_position.x, _player.global_position.z).distance_to(at) <= 2.5
		button.disabled = (verb == "testify" and not params.has("origin")) or (verb == "bribe" and (Money.coins < 5 or not str(e.bribe).is_empty())) or (verb in ["plant", "offer"] and Inventory.count("wood") < 1)
	_choices.position.x = (get_viewport().get_visible_rect().size.x - _choices.size.x) * 0.5
	_choices.position.y = get_viewport().get_visible_rect().size.y - 210
	_label.position.x = (get_viewport().get_visible_rect().size.x - _label.size.x) * 0.5

func _update_traces() -> void:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	if e.is_empty() or e.type != "hearing":
		return
	var params := _parameters("inspect")
	var place: String = params.get("place", "")
	if not place.is_empty() and not _traces.has(place):
		var trace := StageProps.wood()
		add_child(trace)
		var at: Vector2 = registry.place(place)
		trace.position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
		_traces[place] = trace
	for t: Dictionary in v.runtime.get("traces", []):
		var key := "planted:%s" % t.event
		if _traces.has(key):
			continue
		var trace := StageProps.wood()
		add_child(trace)
		var at: Vector2 = registry.place(t.place)
		trace.position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
		_traces[key] = trace

func _update_storms() -> void:
	var v = VillageSession.village
	for storm in v.storms:
		if not storm.active:
			if _storm_props.has(storm.id):
				_storm_props[storm.id].queue_free()
				_storm_props.erase(storm.id)
			continue
		if _storm_props.has(storm.id):
			continue
		var prop := Props.shrine()
		add_child(prop)
		var at: Vector2 = registry.place(v.households[storm.household].home) + Vector2(1.5, 0.0)
		prop.position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
		_storm_props[storm.id] = prop

func _update_cue(now: int) -> void:
	_label.visible = not Controls.locked and not VillageSession.background
	if not _label.visible:
		return
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
		var detail: String = "You cut me loose. Thank you." if memory.has("rescued_by") else p.role.capitalize()
		if p.ancestor >= 0:
			detail = "Forebear of %s · unfamiliar words, familiar faces" % v.lineages[p.lineage].name
		elif p.stress > 200:
			detail = "There is grief in our house."
		elif p.hunger > 400:
			detail = "The cupboard is bare."
		_label.text = "%s · %s" % [p.name, detail]
	if _stage != null and _player.global_position.distance_to(Vector3(_stage.place_at().x, _player.global_position.y, _stage.place_at().y)) < 12.0:
		var e := Runtime.event_by_id(v, _event)
		var name: String = v.people[int(e.victim)].name
		var cue: String = "Approach the restraint to Free; stand in a throw's path to shield."
		if e.type == "hearing":
			var cs = v.cases[e.source.case_id]
			cue = "Accused of %s. Hear witnesses; inspect the doorstep trace; speak to the elder before judgment." % v.crimes[cs.crime].act
		elif e.type == "rite":
			cue = "A captive at the old stone. Cut the rope before dawn, or offer wood by gesture."
		_label.text = "%s · %s" % [name, cue if not Runtime.terminal(e) else e.outcome.capitalize()]

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

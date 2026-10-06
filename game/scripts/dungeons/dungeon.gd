extends Node3D
## A dungeon you go down into (from its entrance, sites.gd). Built from blocks when you go in and taken down
## when you leave, far below the map like Glimmerdeep (world/cave.gd):
##   layout.gd (the rooms and tunnels, from a seed)  rock.gd (the rock round them)  themes.gd (the look, props,
##   foes)  templates.gd (what it's about: a rescue, a hoard)  props.gd  foes.gd
## So a new dungeon is a line in sites.gd: a place, a theme and a template. Each time you clear one, the next
## visit is a new layout (and, for a rescue, someone new taken).
## It also runs a clan's fight the way the Red Hand camp does (request_turn, raise_alarm...: creatures/bandit.gd).
## Saving waits while you're down here (it saved at the entrance), as in the cave.

const Layout := preload("res://scripts/dungeons/layout.gd")
const Rock := preload("res://scripts/dungeons/rock.gd")
const Themes := preload("res://scripts/dungeons/themes.gd")
const Templates := preload("res://scripts/dungeons/templates.gd")
const Props := preload("res://scripts/dungeons/props.gd")
const Foes := preload("res://scripts/dungeons/foes.gd")
const Sites := preload("res://scripts/dungeons/sites.gd")
const UseSpot := preload("res://scripts/world/use_spot.gd")
const DOOR_SOUND := preload("res://assets/kenney_impact/impactWood_medium_002.ogg")
const AT := Vector3(300, -300, 0)        # far east of the map and far below it
const KIDS := ["Wenna", "Hob", "Tilly", "Pip", "Ansel", "Maud", "Jory", "Ilse"]

static var _cleared := {}                # site id -> times cleared (each clear brings a new layout)

var player: CharacterBody3D
var day_night: Node
var treasure: Node                       # chests (world/treasure.gd)
var active := false
var built: Node3D                        # everything down here, placed at AT
var rock: Rock

var _site := {}
var _layout := {}
var _template := {}
var _rng := RandomNumberGenerator.new()
var _door_out := Vector3.ZERO
var _torch: OmniLight3D
var _leaving := false
var _first_node := -1
var _captive: Node3D
var _captive_name := ""
var _goal_foes: Array[Node3D] = []
var _done := false
var _audio: AudioStreamPlayer
# the clan's fight (like bandit_camp.gd)
var _turns: Array[Node] = []
var _bodies: Array = []
var _alarm_at := -100.0


func _ready() -> void:
	add_to_group("dungeon")
	_audio = AudioStreamPlayer.new()
	_audio.stream = DOOR_SOUND
	_audio.volume_db = -6.0
	add_child(_audio)


## The action: go down into dungeon `id` (sites.gd), coming back out at `door`.
func enter(id: String, door: Vector3) -> void:
	if active or not Sites.SITES.has(id):
		return
	_site = Sites.SITES[id].duplicate()
	_site["id"] = id
	_door_out = door
	SaveGame.save_game()
	_audio.play()
	Region.fade_through(_go_in)


func leave() -> void:
	if not active or _leaving:
		return
	_leaving = true
	_audio.play()
	Region.fade_through(_go_out)


## Dev (--dungeon=id:goal): stand at the way into the first room of `role`.
func jump_to(role: String) -> void:
	for room: Dictionary in Layout.rooms_of(_layout, role):
		player.global_position = world(room.at + Vector2(0, float(room.r) * 0.7), 0.3)
		return


## A local floor spot (x, z) as a world position.
func world(p: Vector2, lift := 0.0) -> Vector3:
	return AT + rock.spot(p, lift)


func _go_in() -> void:
	SaveGame.paused = true
	_build()
	active = true
	day_night.set_cave(true)
	player.global_position = AT + (_layout.entry as Vector3)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = PI
	_torch = OmniLight3D.new()                   # you carry a little warm light
	_torch.light_color = Color(1.0, 0.74, 0.46)
	_torch.light_energy = 2.4
	_torch.omni_range = 9.0
	_torch.position = Vector3(0.3, 2.3, 0.4)
	player.add_child(_torch)
	get_tree().call_group("camera_rig", "enter_cave")
	get_tree().call_group("hud", "set_cave", true)
	var title: String = (_template.title as String).replace("{who}", _captive_name)
	Banner.show_now(get_tree().get_first_node_in_group("hud"), String(_site.name).to_upper(), title, Themes.get_theme(_site.theme).light)


func _go_out() -> void:
	_back_outside()
	player.global_position = _door_out
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = 0.0
	get_tree().call_group("camera_rig", "snap")


func _back_outside() -> void:
	active = false
	_leaving = false
	day_night.set_cave(false)
	get_tree().call_group("camera_rig", "leave_cave")
	get_tree().call_group("hud", "set_cave", false)
	if is_instance_valid(_torch):
		_torch.queue_free()
	if _first_node >= 0:
		for id in range(_first_node, WorldResources.node_count()):
			treasure.remove_chest(id)
		WorldResources.truncate(_first_node)
		_first_node = -1
	if is_instance_valid(built):
		built.queue_free()
	_turns.clear()
	_bodies.clear()
	_goal_foes.clear()
	_captive = null
	SaveGame.paused = false


func _physics_process(_delta: float) -> void:
	if not active:
		return
	if player.global_position.y > -100.0:        # knocked out and carried home
		_back_outside()
		return
	if player.global_position.z - AT.z > float(_layout.exit_z):
		leave()


func _process(_delta: float) -> void:
	if not active:
		return
	var cam := get_viewport().get_camera_3d()
	rock.material.set_shader_parameter("player_pos", player.global_position)
	if cam:
		rock.material.set_shader_parameter("camera_pos", cam.global_position)
	if not _done and _template.goal == "hoard" and not _goal_foes.is_empty() \
			and _goal_foes.all(func(f: Node3D) -> bool: return not is_instance_valid(f) or not f.is_alive()):
		_finish()


# --- building it ------------------------------------------------------------------------------

func _build() -> void:
	var visits: int = _cleared.get(_site.id, 0)
	var seed: int = int(_site.seed) + visits * 7919
	_rng.seed = seed
	_template = Templates.get_template(_site.template)
	var theme := Themes.get_theme(_site.theme)
	_layout = Layout.make(seed, int(_template.path), int(_template.sides))
	_done = false
	built = Node3D.new()
	add_child(built)
	built.global_position = AT
	rock = Rock.new()
	rock.build(built, _layout, theme, seed, AT.y)
	_build_void()
	_first_node = WorldResources.node_count()
	for room: Dictionary in _layout.rooms:
		_dress(room, theme)
		match String(room.role):
			"fight":
				var fight: Array = _template.fight
				Foes.spawn(self, theme.foes, room, _rng.randi_range(fight[0], fight[1]), false, _rng)
			"side":
				if _template.side == "chest":
					treasure.add_chest(world(room.at, 0.36), _rng.randf() * 360.0)
			"goal":
				_fill_goal(room, theme)
	var way_out := Node3D.new()                  # a soft light at the way out
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.75, 0.85, 1.0)
	glow.light_energy = 1.4
	glow.omni_range = 6.0
	way_out.add_child(glow)
	built.add_child(way_out)
	way_out.position = rock.spot(Vector2(0, 8.0), 1.5)


## Props about a room, by the theme (none in the middle, where the fighting is).
func _dress(room: Dictionary, theme: Dictionary) -> void:
	var kinds: Array = theme.props.get(room.role, [])
	for k in kinds.size():
		if kinds[k] == "cage":
			continue                              # the goal puts its own cage where the captive is
		var at := rock.by_wall(room.at, float(room.r), _rng.randf_range(0, 360), 1.6)
		Props.place(kinds[k], built, rock.spot(at), _rng)


## What waits at the end: someone in a cage with the clan round them, or a hoard and its guardian.
func _fill_goal(room: Dictionary, theme: Dictionary) -> void:
	var fight: Array = _template.fight
	_goal_foes = Foes.spawn(self, theme.foes, room, fight[1], true, _rng)
	match String(_template.goal):
		"captive":
			var at: Vector2 = room.at + Vector2(0, -float(room.r) * 0.55)
			Props.place("cage", built, rock.spot(at), _rng)
			_captive = _make_captive(world(at, 0.05))
			var free := Node3D.new()
			free.set_script(UseSpot)
			built.add_child(free)
			free.setup(world(at, 0.5), "Free " + _captive_name, func() -> void: _free(free), 2.0)
		"hoard":
			treasure.add_chest(world(room.at + Vector2(0, -float(room.r) * 0.5), 0.36), 0.0)
			treasure.add_chest(world(room.at + Vector2(-1.6, -float(room.r) * 0.4), 0.36), 25.0)


## The captive: a child of the village if there is one (Hilmi's living village), else a child of the wood.
func _make_captive(at: Vector3) -> Node3D:
	var visual := CharacterVisual.new()
	visual.is_player_look = false
	visual.merge = true
	var look := CharacterLook.new()
	_captive_name = KIDS[_rng.randi() % KIDS.size()]
	var v = VillageSession.village
	if v != null:
		var kids: Array = v.people.filter(func(p) -> bool:
			return p.alive and p.present and p.authored == "" and preload("res://scripts/studio/village/sim/village.gd").age_of(v, p) < 14)
		if not kids.is_empty():
			var kid = kids[_rng.randi() % kids.size()]
			_captive_name = str(kid.name)
			look = preload("res://scripts/studio/village/resident_talk.gd").look_of(v, kid.id)
	visual.hero_look = look
	built.add_child(visual)
	visual.global_position = at
	visual.scale = Vector3.ONE * 0.66
	visual.rotation.y = 0.0
	visual.play_motion(0.0)
	return visual


## Free the captive: the cage door gives, they thank you and run for the light. Done.
func _free(spot: Node3D) -> void:
	if _done or not is_instance_valid(_captive):
		return
	spot.queue_free()
	_finish()
	var path: Array[Vector3] = []                # back along the rooms to the way out
	var goal_at := Vector2(_captive.global_position.x - AT.x, _captive.global_position.z - AT.z)
	var rooms: Array = _layout.rooms.filter(func(r: Dictionary) -> bool: return r.role != "side")
	rooms.reverse()
	for r: Dictionary in rooms:
		if (r.at as Vector2).distance_to(goal_at) > 1.0:
			path.append(world(r.at))
	path.append(world(Vector2(0, 9.0)))
	var tween := create_tween()
	var from := _captive.global_position
	for p: Vector3 in path:
		var to := p
		tween.tween_callback(func() -> void:
			if is_instance_valid(_captive):
				_captive.rotation.y = atan2(to.x - _captive.global_position.x, to.z - _captive.global_position.z)
				_captive.play_motion(5.0))
		tween.tween_property(_captive, "global_position", to, from.distance_to(to) / 5.0)
		from = to
	tween.tween_callback(func() -> void:
		if is_instance_valid(_captive):
			_captive.visible = false)


func _finish() -> void:
	if _done:
		return
	_done = true
	_cleared[_site.id] = int(_cleared.get(_site.id, 0)) + 1
	var reward: int = int(_site.get("reward", 60))
	Money.earn(reward)
	Skills.add("combat", 40)
	var line: String = (_template.done as String).replace("{who}", _captive_name)
	Banner.show_now(get_tree().get_first_node_in_group("hud"), "CLEARED", "%s  +%d coins" % [line, reward], Color(1.0, 0.82, 0.42))


## Black under everything, so past the rock there's only darkness (no sky).
func _build_void() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	mi.mesh = plane
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.BLACK
	mi.material_override = m
	mi.position = Vector3(0, -2.5, -30)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	built.add_child(mi)


# --- the clan's fight (as the Red Hand camp runs it) ---------------------------------------------

func request_turn(b: Node) -> bool:
	_turns = _turns.filter(func(n: Node) -> bool: return is_instance_valid(n) and n.is_alive() and n.state in [Bandit.State.WINDUP, Bandit.State.ATTACK])
	if b in _turns:
		return true
	if b.kind == "leader" or _turns.size() < Balance.BANDIT_TURNS:
		_turns.append(b)
		return true
	return false


func end_turn(b: Node) -> void:
	_turns.erase(b)


func raise_alarm(at: Vector3, everyone: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _alarm_at > 20.0:
		get_tree().call_group("hud", "hint", "They've seen you!")
	_alarm_at = now
	for n in built.get_children():
		if not n is Bandit or not n.is_alive() or n.alerted:
			continue
		if everyone or (n as Node3D).global_position.distance_to(at) < Balance.STEALTH["shout"]:
			get_tree().create_timer(randf_range(0.25, 0.9)).timeout.connect(func() -> void:
				if is_instance_valid(n):
					n.hear_alarm())


func bandit_died(b: Node, quiet: bool) -> void:
	_turns.erase(b)
	_bodies.append([b, Time.get_ticks_msec() / 1000.0])
	if quiet:
		FloatText.spawn(get_tree(), (b as Node3D).global_position + Vector3(0, 1.6, 0), "Takedown", Color(0.85, 0.85, 0.95))


func body_seen_by(b: Node3D) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	for entry: Array in _bodies:
		var body: Node3D = entry[0]
		if not is_instance_valid(body) or now - entry[1] < 1.5:
			continue
		var to := body.global_position - b.global_position
		to.y = 0.0
		if to.length() < 9.0 and b._facing().dot(to.normalized()) > 0.3:
			b._last_seen = body.global_position
			return true
	return false

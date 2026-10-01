class_name Carcass
extends Node3D
## A body left by a kill (Hunting.KINDS). Walk up and "Take": carve it here (meat and hide now), drag it
## (slow, no fighting: Drop to defend yourself) or put it in the ox cart, then sell it whole at the butcher's
## rack. It rots: fresh for a while, then worth less, then gone. Crows come to a body left alone, then wolves
## (wolf.gd); either makes it rot faster. Left in the village, someone takes it. Only a few exist at once.

const DROP := preload("res://scripts/world/drop.gd")
const CROW := preload("res://scripts/world/crow.gd")
## How each kind looks dead: visual script, size, tint, and how far behind you it drags.
const LOOKS := {
	"stag": {"visual": "res://scripts/creatures/stag_visual.gd", "scale": 1.0, "tint": Color.WHITE, "drag": 1.6},
	"boar": {"visual": "res://scripts/creatures/boar_visual.gd", "scale": 1.0, "tint": Color.WHITE, "drag": 1.3},
	"wolf": {"visual": "res://scripts/creatures/wolf_visual.gd", "scale": 1.0, "tint": Color.WHITE, "drag": 1.15},
	"shadow_wolf": {"visual": "res://scripts/creatures/wolf_visual.gd", "scale": 1.3, "tint": Color(0.42, 0.38, 0.62), "drag": 1.4},
	"duskmaw": {"visual": "res://scripts/creatures/wolf_visual.gd", "scale": 2.1, "tint": Color(0.2, 0.17, 0.26), "drag": 2.3},
}
const ROT_TINT := Color(0.5, 0.47, 0.4)
const VILLAGE := Vector2(0.0, 15.0)
const VILLAGE_RADIUS := 26.0

const DRAG_LIFT := 0.2                       # radians the front end tilts up while dragged

static var shape: WorldShape                 # set by main.gd, for the ground height while dragged

var kind := "stag"
var age := 0.0
var dragged := false
var player: Node3D
var verb := "Take"
var reach := 2.6
var visual: Node3D
var _look: Dictionary
var _tick := 0.0
var _alone := 0.0              # seconds with you far away (crows, the village)
var _crows_sent := false
var _flies: CPUParticles3D
var _gone := false
var _scrape: AudioStreamPlayer3D
var _scuff := 0.0              # metres pulled since the last scrape sound


## Leaves a body where something died (keeps at most Balance.HUNT.max_carcasses; the oldest goes).
static func spawn(parent: Node, kind_: String, at: Vector3, yaw: float, player_: Node3D, age_ := 0.0) -> Node3D:
	var all := parent.get_tree().get_nodes_in_group("carcass").filter(func(c: Node) -> bool: return not c.dragged)
	if all.size() >= Balance.HUNT["max_carcasses"]:
		all.sort_custom(func(a: Node, b: Node) -> bool: return a.age > b.age)
		all[0].vanish()
	var c := Node3D.new()
	c.set_script(load("res://scripts/world/carcass.gd"))
	c.kind = kind_
	c.age = age_
	c.player = player_
	parent.add_child(c)
	c.global_position = at
	c.rotation.y = yaw
	return c


func _ready() -> void:
	add_to_group("carcass")
	add_to_group("interactable")
	_look = LOOKS[kind]
	reach = 3.2 if Hunting.KINDS[kind]["size"] == "huge" else 2.6
	visual = Node3D.new()
	visual.set_script(load(_look["visual"]))
	add_child(visual)
	visual.scale = Vector3.ONE * _look["scale"]
	visual.set("mode", "dead")
	_tint.call_deferred()
	_flies = _make_flies()
	add_child(_flies)
	_scrape = AudioStreamPlayer3D.new()
	_scrape.stream = load("res://assets/sounds/step_dirt_%d.wav" % randi_range(0, 5))
	_scrape.volume_db = -8.0
	_scrape.unit_size = 6.0
	add_child(_scrape)


func fresh() -> float:
	return Hunting.freshness(age)


## Eaten (crows, wolves): it rots faster.
func nibble(seconds: float) -> void:
	age += seconds


func interact() -> void:
	var def: Dictionary = Hunting.KINDS[kind]
	var options: Array = [{"label": "Carve here", "hint": "meat and hide now", "do": carve}]
	if def["size"] != "huge":
		options.append({"label": "Drag it", "hint": "sell it whole", "do": func() -> void: player.hauling.start_carry(self)})
	var cart := get_tree().get_first_node_in_group("ox_cart")
	if cart and cart.global_position.distance_to(global_position) < 9.0:
		options.append({"label": "Into the cart", "hint": "%d of %d full" % [Hunting.cart["load"].size(), Balance.HUNT["cart_slots"]],
			"do": func() -> void: cart.load_body(self)})
	elif def["size"] == "huge":
		options.append({"label": "Too heavy", "hint": "fetch the ox cart", "do": Callable()})
	get_tree().call_group("hud", "show_choices", self, "%s  ·  %s" % [def["name"], _fresh_word()], options)


func _fresh_word() -> String:
	var f := fresh()
	return "fresh" if f >= 0.95 else ("going off" if f > 0.5 else "rotting")


## The action: carve it where it lies. The pieces pop out and fly to you.
func carve() -> void:
	if _gone:
		return
	player.visual.play_action("Fixing_Kneeling", player.visual.animation_length("Fixing_Kneeling") / Balance.HUNT["carve_time"])
	var got: Array = Hunting.KINDS[kind]["carve"]
	var f := fresh()
	_gone = true
	remove_from_group("interactable")
	get_tree().create_timer(Balance.HUNT["carve_time"] * 0.8).timeout.connect(func() -> void:
		var items := {}
		for entry: Array in got:
			if f < 0.5 and entry[0] == "raw_meat":
				continue
			for i in int(entry[1]):
				if randf() < entry[2]:
					items[entry[0]] = items.get(entry[0], 0) + 1
		for item: String in items:
			for i in items[item]:
				var drop := Node3D.new()
				drop.set_script(DROP)
				get_parent().add_child(drop)
				var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(0.8, 1.6)
				drop.launch(item, global_position + Vector3(0, 0.6, 0), dir + Vector3(0, randf_range(3.0, 4.5), 0), global_position.y, player)
		if items.is_empty():
			get_tree().call_group("hud", "hint", "Too far gone. Nothing worth taking.")
		vanish())


## Gone: sinks into the grass (rotted away, carved, taken).
func vanish() -> void:
	_gone = true
	remove_from_group("carcass")
	remove_from_group("interactable")
	var t := create_tween()
	t.tween_property(self, "position:y", position.y - 0.9, 1.2)
	t.tween_callback(queue_free)


func start_drag() -> void:
	dragged = true
	verb = ""
	remove_from_group("interactable")


func release() -> void:
	dragged = false
	rotation.x = 0.0                           # set back down flat
	if shape:
		global_position.y = shape.height_at(global_position.x, global_position.z)
	verb = "Take"
	_alone = 0.0
	if not _gone:
		add_to_group("interactable")


func _physics_process(delta: float) -> void:
	age += delta
	if dragged and is_instance_valid(player) and not _gone:
		# Like a weight on a short rope: it only moves when you pull it taut, so it comes in heaves
		# as you step, swings round behind you on a turn and follows the way you went.
		var to: Vector3 = player.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		var rope: float = _look["drag"]
		var p := global_position
		if dist > rope:
			var pulled := dist - rope
			p += to / dist * pulled
			_scuff += pulled
			if _scuff > 0.55:                  # its hooves and flank scrape the ground
				_scuff = 0.0
				_scrape.pitch_scale = randf_range(0.5, 0.62)
				_scrape.play()
		if shape:                              # the end in your hands lifts off the ground
			p.y = shape.height_at(p.x, p.z) + sin(DRAG_LIFT) * rope * 0.45
		global_position = p
		if dist > 0.3:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(6.0 * delta, 0.0, 1.0))
		rotation.x = move_toward(rotation.x, -DRAG_LIFT, delta)
	_tick -= delta
	if _tick > 0.0 or _gone:
		return
	_tick = 0.5
	var f := fresh()
	if f <= 0.0:
		vanish()
		return
	_tint()
	_flies.emitting = f < 0.8
	if dragged or not is_instance_valid(player):
		return
	var far := player.global_position.distance_to(global_position) > 14.0
	_alone = _alone + 0.5 if far else 0.0
	var h: Dictionary = Balance.HUNT
	if not _crows_sent and _alone > h["crows_after"]:
		_crows_sent = true
		for i in 3:
			var crow := Node3D.new()
			crow.set_script(CROW)
			crow.carcass = self
			crow.player = player
			get_parent().add_child(crow)
	if Region.current == "meadow" and _alone > h["village_takes_after"] \
			and Vector2(global_position.x, global_position.z).distance_to(VILLAGE) < VILLAGE_RADIUS:
		get_tree().call_group("hud", "hint", "Someone from the village made off with the %s you left lying there." % Hunting.KINDS[kind]["name"].to_lower())
		vanish()


## Greyer as it rots.
func _tint() -> void:
	var c: Color = (_look["tint"] as Color).lerp(ROT_TINT * _look["tint"], 1.0 - fresh())
	for m in visual.get("_materials"):
		m.set_shader_parameter("albedo", c)


func _make_flies() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.4
	p.emitting = false
	p.position = Vector3(0, 0.7, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.gravity = Vector3.ZERO
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.035
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.08, 0.08, 0.06)
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

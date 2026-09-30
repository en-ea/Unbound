extends Node3D
## A piece of gear lying in the world (a tool, the weapon or armour): dropped from the Bag, or found
## in a chest or on an enemy. It shows the model in its tier colour, turning slowly in a beam of its
## rarity colour, and you pick it up by walking over it. One you dropped yourself waits until you've stepped away.

const DROP := preload("res://scripts/world/drop.gd")
const GRAVITY := 14.0
const PICK_RANGE := 1.3
const SOUND := preload("res://assets/sounds/rare.wav")
const LAND_SOUND := preload("res://assets/sounds/chest_burst.wav")

var slot := ""
var tool := {}
var _player: Node3D
var _velocity := Vector3.ZERO
var _ground_y := 0.0
var _landed := false
var _armed := false            # can be picked up yet
var _found := true             # found (a new tool) or dropped by you
var _model: Node3D
var _age := 0.0


func launch(tool_slot: String, t: Dictionary, from: Vector3, velocity: Vector3, ground_y: float, player: Node3D, found := true) -> void:
	slot = tool_slot
	tool = t
	_velocity = velocity
	_ground_y = ground_y
	_player = player
	_found = found
	global_position = from
	var armor := Armor.SLOTS.has(slot)
	_model = (load("res://assets/items/%s.glb" % (("armor_" + slot) if armor else slot)) as PackedScene).instantiate()
	var tint: Color = (Armor.TIERS if armor else Gear.TIERS)[t["tier"]]["color"]
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat and mat.resource_name == "Metal":
				var tinted := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				tinted.albedo_color = tint
				mi.set_surface_override_material(s, tinted)
	_model.scale = Vector3.ONE * 1.3
	_model.rotation_degrees = Vector3(0, 0, 0 if armor else -60)
	add_child(_model)
	add_child(DROP.make_shadow())
	# The rarer, the taller and brighter the beam.
	var r: int = t["rarity"]
	var beam := DROP.make_beam_color(Loot.rarity_color(r) if r > 0 else Color(1.0, 0.95, 0.85), 0.5 + 0.12 * r)
	beam.scale.y = 1.0 + 0.2 * r
	add_child(beam)


func _process(delta: float) -> void:
	if _player == null:
		return
	_age += delta
	if not _landed:
		_velocity.y -= GRAVITY * delta
		global_position += _velocity * delta
		if global_position.y <= _ground_y + 0.3 and _velocity.y < 0.0:
			global_position.y = _ground_y + 0.3
			_landed = true
			if _found and tool["rarity"] >= Loot.RARE:
				_land_flash(tool["rarity"])
	else:
		_model.position.y = 0.1 + sin(_age * 2.5) * 0.06
	_model.rotation.y += delta * 1.2
	var near := Vector2(global_position.x - _player.global_position.x, global_position.z - _player.global_position.z).length()
	if not _armed:
		_armed = (_found and _landed and _age > 0.6) or (not _found and near > 2.5)
	elif near < PICK_RANGE:
		_pick_up()


## Rare and better gear lands with a flash in its colour, a ring of sparks and a chime; Legendary and
## Mythic also shake the ground and call out their rarity.
func _land_flash(r: int) -> void:
	var tint := Loot.rarity_color(r)
	sparks(self, global_position, tint, 16 + 10 * r, 3.0 + r)
	var chime := AudioStreamPlayer3D.new()
	chime.stream = LAND_SOUND
	chime.unit_size = 8.0
	chime.pitch_scale = 1.0 - 0.06 * (r - Loot.RARE)
	add_child(chime)
	chime.play()
	if r >= Loot.LEGENDARY:
		get_tree().call_group("camera_rig", "shake", 0.12)
		FloatText.spawn(get_tree(), global_position + Vector3(0, 1.6, 0), Loot.rarity_name(r) + "!", tint, true)


func _pick_up() -> void:
	Gear.take(slot, tool)
	if _found:
		get_tree().call_group("hud", "found_tool", slot, tool)
	else:
		get_tree().call_group("hud", "hint", "Picked up your %s" % Gear.name_of(slot, tool))
	var sound := AudioStreamPlayer.new()
	sound.stream = SOUND
	get_parent().add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	queue_free()


## A one-off burst of glowing sparks in `tint` at `at` (gear landing, a chest opening on good gear).
static func sparks(parent: Node, at: Vector3, tint: Color, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.9
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -3, 0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = speed
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.08
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(tint.lightened(0.3) * 2.2, 1.0)
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


## Throws a tool into the world at `from` (used by chests, enemies and the player).
static func spawn(parent: Node, tool_slot: String, t: Dictionary, from: Vector3, player: Node3D, found := true) -> void:
	var d := Node3D.new()
	d.set_script(load("res://scripts/world/tool_drop.gd"))
	parent.add_child(d)
	var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(0.8, 1.6)
	d.launch(tool_slot, t, from + Vector3(0, 0.8, 0), dir + Vector3(0, randf_range(4.0, 5.0), 0), from.y, player, found)

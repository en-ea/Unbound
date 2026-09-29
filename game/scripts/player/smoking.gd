class_name Smoking
extends Node
## Smoking a cigarette (looks only, no stats): it sits in the corner of your mouth, the tip glows and
## a thin wisp of smoke curls up, now and then a proper puff. It burns down over Balance.SMOKE_SECS
## and ends with a last puff. The item is used up when you light it (Bag > Smoke).

const PUFF_EVERY := 4.5
const HALF := 0.1                        # half the cigarette model's length (0.2 m)
const SIZE := 0.42                       # model scale: a real cigarette is about 8 cm
## In the head bone's frame: the corner of the mouth, tilted a little up and out.
const MOUTH := Vector3(0.028, 0.075, 0.108)

var left := 0.0
var visual: CharacterVisual       # whose head it is (the player's, unless set: villagers who always smoke)
var endless := false
var smoke_on := true
var puff_scale := 1.0             # smaller puffs for a villager seen close up (portraits)
var _prop: Node3D
var _mesh: MeshInstance3D
var _wisp: CPUParticles3D
var _puff: CPUParticles3D
var _next_puff := 0.0
var _dot: GradientTexture2D


func is_smoking() -> bool:
	return left > 0.0


## The action: light one (uses a cigarette). False if you have none or are already smoking.
func start() -> bool:
	if is_smoking():
		get_tree().call_group("hud", "hint", "Already smoking")
		return false
	if not Inventory.remove("cigarette"):
		return false
	_build()
	left = Balance.SMOKE_SECS
	_next_puff = 1.2
	_prop.visible = true
	_wisp.emitting = true
	get_tree().call_group("hud", "hint", "Ahh, that's nice")
	return true


## For villagers: a cigarette that never burns down (world/npc.gd).
func start_endless() -> void:
	endless = true
	_build()
	left = 1.0
	_prop.visible = true
	_wisp.emitting = smoke_on
	_next_puff = randf_range(1.0, 4.0)


func stop(quiet := false) -> void:
	left = 0.0
	if _prop:
		_prop.visible = false
		_wisp.emitting = false
		if not quiet:
			_puff.restart()


func _ready() -> void:
	var player := get_parent()
	if player.has_signal("knocked_out") and visual == null:
		player.knocked_out.connect(stop.bind(true))


func _process(delta: float) -> void:
	if left <= 0.0:
		return
	if not endless:
		left -= delta
		if left <= 0.0:
			stop()
			return
	_next_puff -= delta
	if _next_puff <= 0.0:
		_next_puff = PUFF_EVERY + randf_range(-1.0, 1.5)
		if smoke_on:
			_puff.restart()
	if endless:
		return
	# It burns down: the paper shortens towards the filter (which stays at the mouth end).
	var s := lerpf(0.3, 1.0, left / Balance.SMOKE_SECS)
	_mesh.scale.x = s
	_mesh.position.x = HALF * (1.0 - s)
	_wisp.position.x = HALF - 2.0 * HALF * s


func _build() -> void:
	if _prop:
		return
	if visual == null:
		visual = get_parent().get_node("Visual") as CharacterVisual
	_prop = Node3D.new()
	_prop.position = MOUTH + Vector3(0, 0, HALF * SIZE)
	_prop.rotation_degrees = Vector3(-8.0, 90.0, 0.0)     # the glowing tip (-X in the model) points forward
	_prop.scale = Vector3.ONE * SIZE
	visual.head_attachment().add_child(_prop)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Items.mesh("cigarette")
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prop.add_child(_mesh)
	_wisp = _smoke(0.1, 2.4, 6, 0.09, 0.22)
	_wisp.position = Vector3(-HALF, 0, 0)
	_wisp.emitting = false
	_prop.add_child(_wisp)
	_puff = _smoke(0.2, 2.0, 8, 0.5, 0.9)
	_puff.one_shot = true
	_puff.emitting = false
	_puff.explosiveness = 0.85
	_puff.position = Vector3(HALF, 0, 0)         # the mouth end
	_puff.direction = Vector3(-1.0, 1.4, 0.0)
	_puff.scale_amount_min *= puff_scale
	_puff.scale_amount_max *= puff_scale
	_wisp.scale_amount_min *= puff_scale
	_wisp.scale_amount_max *= puff_scale
	_prop.add_child(_puff)
	_prop.visible = false


## Soft grey-white puffs that drift up and thin out.
func _smoke(size: float, life: float, count: int, speed_min: float, speed_max: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.7))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.92, 0.92, 0.94, 0.5))
	ramp.set_color(1, Color(0.8, 0.82, 0.86, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size / SIZE      # the prop is scaled by SIZE
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _soft_dot()
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		_dot = GradientTexture2D.new()
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot.gradient = g
		_dot.width = 32
		_dot.height = 32
	return _dot

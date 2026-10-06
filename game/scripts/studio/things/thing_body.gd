extends RefCounted
## Graphics S4: one thing's body (render/thing_state.gd makes one per thing). Body's runtime (people/body_elements.gd,
## given things/elements/) reconciles the thing's facts with the element modules there, exactly as it does a
## person's; this plays the named layers they post:
##   surface {soot, char, wet, wear, ember}   0..1 each; the strongest of all layers shows
##   fx {kind: flames | smoke | steam, size := 1.0}   the people's own effect (villager_body.make_fx), on the thing
##   flash int        a brief brighten each time the value changes
##   shake {n: int, force 0..1}   a shudder each time n changes
##   broken true      the thing is gone and its debris lies there
## A key that disappears takes its effect with it. Channels go to the thing's column of the state texture: no material
## or draw call changes, except the effects and the debris themselves.

const BodyElements := preload("res://scripts/studio/people/body_elements.gd")
const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")
const FOLDER := "res://scripts/studio/things/elements/"
const FLASH_S := 0.2               # struck: a brief brighten (Hilmi, 5 Oct: "a brief brighten rather than full white")
const FLASH_PEAK := 1.0             # (the shader lifts by 45 % at 1)
const SHAKE_S := 0.4
const DEBRIS := 7
const WOOD := Color(0.36, 0.25, 0.16)
const CHAR := Color(0.05, 0.045, 0.04)


class Still extends RefCounted:      # things never move or take a posture (Body's runtime asks a mover)
	var constraints := {}
	func can_posture(_name: String) -> bool:
		return false


static var _pool: Array[MultiMeshInstance3D] = []      # debris, reused

var state: Node                      # the ThingState
var id := ""
var kind := ""
var root: Node3D
var runner
var box := AABB()                    # the thing's own bounds, in its root's space
var _facts := {}
var _base := {}
var _tick := -1
var _fx := {}                        # layer key -> CPUParticles3D
var _flash_n := {}
var _shake_n := {}
var _flash := 0.0
var _shake := 0.0
var _shake_force := 0.0
var _debris: MultiMeshInstance3D
var _last := {}


func _init(owner: Node, thing_id: String, thing_kind: String, thing_root: Node3D) -> void:
	state = owner
	id = thing_id
	kind = thing_kind
	root = thing_root
	runner = BodyElements.new(FOLDER)
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b: AABB = root.global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	_base = {"body": root, "mover": Still.new(), "visible": true, "hints": {}, "size": box.size,
		"emit": func(_kind: String, _fields: Dictionary) -> void: pass,
		"announce": func(_kind: String, _fact: Dictionary, _transition := false) -> bool: return false,
		"vocal": func(_kind: String, _strength: float) -> void: pass,
		"current": func(fact: Dictionary) -> Dictionary: return _current(str(fact.get("kind", ""))),
		"live": func(fact: Dictionary) -> bool: return _live(fact),
		"has": func(fact_kind: String) -> bool: return _facts.has(fact_kind)}


func _current(fact_kind: String) -> Dictionary:
	return _facts.get(fact_kind, {})


func _live(fact: Dictionary) -> bool:
	var now: Dictionary = _facts.get(str(fact.get("kind", "")), {})
	if now.is_empty():
		return false
	for f in ["id", "deed", "revision"]:
		if str(now.get(f, "")) != str(fact.get(f, "")):
			return false
	return not now.has("until_tick") or int(now.until_tick) > _tick


## Each frame, from ThingState: the thing's facts ({kind: fact}), the facts' clock, active seconds.
func drive(facts: Dictionary, tick: int, dt: float) -> void:
	if facts.is_empty() and _facts.is_empty() and runner.playing.is_empty() and runner.layers.is_empty() \
			and runner.completed.is_empty() and _flash <= 0.0 and _shake <= 0.0:
		_tick = tick
		return                       # (a neutral thing costs one comparison a frame)
	var hydrate := _tick < 0 or absi(tick - _tick) > 1000
	_tick = tick
	_facts = facts
	_base.tick = tick
	runner.reconcile(_base, facts, tick, hydrate)
	runner.update(dt)
	apply(runner.layers, dt)


## The layers as they stand: channels, effects, flash, shake and debris.
func apply(layers: Dictionary, dt: float) -> void:
	var ch := {}
	var broken := false
	for key: String in layers:
		var f: Dictionary = layers[key]
		var surf: Dictionary = f.get("surface", {})
		for c: String in surf:
			ch[c] = maxf(float(ch.get(c, 0.0)), float(surf[c]))
		if f.has("flash") and _flash_n.get(key) != f.flash:
			_flash_n[key] = f.flash
			_flash = 1.0
		var sh: Dictionary = f.get("shake", {})
		if not sh.is_empty() and _shake_n.get(key) != sh.get("n"):
			_shake_n[key] = sh.get("n")
			_shake = 1.0
			_shake_force = clampf(float(sh.get("force", 0.5)), 0.0, 1.0)
		broken = broken or bool(f.get("broken", false))
		_effect(key, f.get("fx", {}))
	for key: String in _fx.keys():
		if not layers.has(key):
			_effect(key, {})
	for key: String in _flash_n.keys():
		if not layers.has(key):
			_flash_n.erase(key)
			_shake_n.erase(key)
	if _flash > 0.0:
		ch["flash"] = _flash * FLASH_PEAK
		_flash = maxf(0.0, _flash - dt / FLASH_S)
	if _shake > 0.0:
		ch["shake"] = _shake * _shake_force
		_shake = maxf(0.0, _shake - dt / SHAKE_S)
	if broken:
		ch["broken"] = 1.0
	_set_debris(broken, float(ch.get("char", 0.0)))
	if ch != _last:
		state.set_channels(id, ch)
		_last = ch


func _effect(key: String, fx: Dictionary) -> void:
	var had: CPUParticles3D = _fx.get(key)
	if had != null and (fx.is_empty() or str(had.get_meta("kind")) != str(fx.get("kind", ""))):
		had.queue_free()
		_fx.erase(key)
		had = null
	if fx.is_empty() or had != null:
		return
	# The people's effect is sized for a body (about 0.35 x 0.8 m): scaled out to the thing's own footprint.
	var size := float(fx.get("size", 1.0))
	# More of them over a wider piece, set as it is made (an amount changed later left a dark quad at the centre).
	var many := clampf(box.size.x * box.size.z / 0.3, 1.0, 3.0)
	var p: CPUParticles3D = VillagerBody.make_fx(str(fx.get("kind", "flames")), size, many)
	p.set_meta("kind", str(fx.get("kind", "flames")))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(box.size.x * 0.45, box.size.y * 0.3, box.size.z * 0.45)
	p.position = box.get_center()
	root.add_child(p)
	p.emitting = true
	_fx[key] = p


func _set_debris(on: bool, char_amount: float) -> void:
	if on == (_debris != null):
		if _debris != null:
			(_debris.material_override as StandardMaterial3D).albedo_color = WOOD.lerp(CHAR, char_amount)
		return
	if not on:
		_debris.get_parent().remove_child(_debris)
		_pool.append(_debris)
		_debris = null
		return
	_debris = _pool.pop_back() if not _pool.is_empty() else _make_debris()
	var mm := _debris.multimesh
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var plank := Vector3(maxf(box.size.x, box.size.z) * 0.38, 0.1, 0.15)
	for i in DEBRIS:
		var s := plank * Vector3(rng.randf_range(0.5, 1.1), 1.0, rng.randf_range(0.7, 1.3))
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
		var at := Vector3(box.get_center().x + rng.randf_range(-0.5, 0.5) * box.size.x,
			box.position.y + 0.03 + 0.05 * float(i % 3), box.get_center().z + rng.randf_range(-0.5, 0.5) * box.size.z)
		mm.set_instance_transform(i, Transform3D(b.scaled(s), at))
	(_debris.material_override as StandardMaterial3D).albedo_color = WOOD.lerp(CHAR, char_amount)
	root.add_child(_debris)


static func _make_debris() -> MultiMeshInstance3D:
	var n := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = DEBRIS
	n.multimesh = mm
	var m := StandardMaterial3D.new()
	m.roughness = 0.95
	n.material_override = m
	n.name = "StudioDebris"
	return n


## The thing is gone from the world (freed or rebuilt): its effects and debris go with it.
func stop() -> void:
	runner.stop()
	for key: String in _fx.keys():
		if is_instance_valid(_fx[key]):
			(_fx[key] as Node).queue_free()
	_fx.clear()
	if _debris != null:
		if _debris.get_parent() != null:
			_debris.get_parent().remove_child(_debris)
		_pool.append(_debris)
		_debris = null

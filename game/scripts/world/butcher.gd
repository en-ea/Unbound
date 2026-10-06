extends Node3D
## The butcher's rack at the edge of the village: a frame of poles with meat hanging, a chopping block with
## a cleaver, and a coin box. Drag a whole body here ("Sell"), or bring the ox cart close ("Sell load"):
## Hunting.sell() pays coins and the good parts. Built from simple shapes.

const AT := Vector2(-19.0, 26.0)
const CART_NEAR := 11.0

var player: Node3D
var verb := ""
var reach := 3.4


func build(shape: WorldShape) -> void:
	add_to_group("interactable")
	global_position = Vector3(AT.x, shape.height_at(AT.x, AT.y), AT.y)
	rotation.y = PI * 0.5
	var wood := _mat(Color(0.5, 0.35, 0.22))
	var dark := _mat(Color(0.32, 0.22, 0.15))
	var meat := _mat(Color(0.72, 0.3, 0.28))
	var fat := _mat(Color(0.93, 0.85, 0.75))
	for x in [-1.3, 1.3]:                                              # the frame
		_piece(CylinderMesh.new(), Vector3(0.14, 2.6, 0.14), Vector3(x, 1.3, 0), dark, Vector3(0, 0, 0.06 * signf(x)))
	_piece(CylinderMesh.new(), Vector3(0.12, 3.0, 0.12), Vector3(0, 2.45, 0), wood, Vector3(0, 0, PI * 0.5))
	for i in 3:                                                        # hanging cuts
		var x := -0.8 + i * 0.8
		_piece(CylinderMesh.new(), Vector3(0.02, 0.4, 0.02), Vector3(x, 2.2, 0), dark)
		_piece(SphereMesh.new(), Vector3(0.36, 0.6, 0.24), Vector3(x, 1.75, 0), meat)
		_piece(SphereMesh.new(), Vector3(0.2, 0.18, 0.14), Vector3(x, 2.0, 0), fat)
	_piece(CylinderMesh.new(), Vector3(0.8, 0.7, 0.8), Vector3(1.9, 0.35, 1.1), wood)          # chopping block
	_piece(BoxMesh.new(), Vector3(0.36, 0.03, 0.2), Vector3(1.9, 0.72, 1.1), _mat(Color(0.7, 0.72, 0.76)), Vector3(0.0, 0.5, 0.2))
	_piece(BoxMesh.new(), Vector3(0.5, 0.4, 0.4), Vector3(-1.9, 0.2, 1.0), dark)                 # the coin box
	var sign := Label3D.new()
	sign.text = "BUTCHER"
	sign.font_size = 64
	sign.outline_size = 12
	sign.pixel_size = 0.006
	sign.position = Vector3(0, 3.0, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(1.0, 0.9, 0.75)
	add_child(sign)
	preload("res://scripts/studio/world/fit_colliders.gd").add(self, "butcher")   # studio: the frame's posts, the block and the coin box are solid (note 233349)
	set_meta("map_size", Vector2(3, 2))
	add_to_group("map_building")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var h: Variant = player.hauling
	if h.carrying:
		verb = "Sell"
	elif _cart_load() > 0:
		verb = "Sell load"
	else:
		verb = "Butcher"


func interact() -> void:
	var h: Variant = player.hauling
	var coins := 0
	var parts := {}
	if h.carrying:
		var body: Node3D = h.carrying
		h.let_go_of(body)
		var r := Hunting.sell(body.kind, Hunting.freshness(body.age))
		coins += r["coins"]
		_add(parts, r["items"])
		body.queue_free()
	elif _cart_load() > 0:
		for b: Dictionary in Hunting.cart["load"]:
			if b["kind"] != "_":
				var r := Hunting.sell(b["kind"], Hunting.freshness(b["age"]))
				coins += r["coins"]
				_add(parts, r["items"])
		Hunting.cart["load"] = []
		Hunting.changed.emit()
	else:
		get_tree().call_group("hud", "hint", "The butcher buys whole bodies: drag one here, or bring the ox cart.")
		return
	var bits: Array[String] = []
	for item: String in parts:
		bits.append("%d %s" % [parts[item], Items.name_of(item)])
	get_tree().call_group("hud", "hint", "The butcher pays %d coins%s." % [coins, (" and " + ", ".join(bits)) if not bits.is_empty() else ""])
	FloatText.spawn(get_tree(), global_position + Vector3(0, 2.6, 0), "+%d" % coins, Color(1.0, 0.85, 0.35), true)


func _cart_load() -> int:
	var cart := get_tree().get_first_node_in_group("ox_cart") as Node3D
	if cart == null or cart.global_position.distance_to(global_position) > CART_NEAR:
		return 0
	return Hunting.cart["load"].filter(func(b: Dictionary) -> bool: return b["kind"] != "_").size()


func _add(into: Dictionary, items: Dictionary) -> void:
	for k: String in items:
		into[k] = into.get(k, 0) + items[k]


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _piece(mesh: PrimitiveMesh, size: Vector3, at: Vector3, mat: Material, turn := Vector3.ZERO) -> void:
	if mesh is CylinderMesh:
		mesh.top_radius = size.x * 0.5
		mesh.bottom_radius = size.x * 0.5
		mesh.height = size.y
		mesh.radial_segments = 7
		mesh.rings = 1
	elif mesh is SphereMesh:
		mesh.radius = size.x * 0.5
		mesh.height = size.y
		mesh.radial_segments = 7
		mesh.rings = 4
	elif mesh is BoxMesh:
		mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = turn
	add_child(mi)

extends Node3D
## Loading-screen warm-up (core/warmup.gd) for the class abilities: shows each fire and earth effect once,
## with the flash of light a blast makes, so the phone prepares their shaders behind the loading cover
## instead of freezing for a moment the first time an ability is used in a fight.

var _nodes: Array[Node] = []


func _ready() -> void:
	add_to_group("warmup")


func warm(at: Vector3) -> void:
	if "--nowarm" in OS.get_cmdline_user_args():    # dev: compare with and without the warm-up
		return
	var p := at + Vector3(0, 0, -3)
	_keep(FireFX.flames(self, p + Vector3(0, 0.5, 0), 0.4, 8, 0.6))
	_keep(FireFX.flames(self, p + Vector3(0.6, 0.5, 0), 0.4, 8, 0.6, true, 0.9))
	FireFX.blast(self, p, 2.0)                     # flames, a light, the shockwave ring (frees itself)
	var light := OmniLight3D.new()                 # a burning patch's steady light
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 1.2
	light.omni_range = 6.0
	_keep(light)
	light.global_position = p + Vector3(0, 0.8, 0)
	var star := MeshInstance3D.new()               # the meteor and its warning ring
	var ball := SphereMesh.new()
	ball.radius = 0.3
	ball.height = 0.6
	star.mesh = ball
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.25, 0.1, 0.05)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.45, 0.1)
	star.material_override = sm
	_keep(star)
	star.global_position = p + Vector3(-0.8, 1.0, 0)
	var claw := MeshInstance3D.new()               # the Delver's claw metal
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.05
	spike.height = 0.3
	spike.radial_segments = 3
	claw.mesh = spike
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.42, 0.44, 0.47)
	iron.metallic = 0.5
	iron.roughness = 0.35
	claw.material_override = iron
	_keep(claw)
	claw.global_position = p + Vector3(0.8, 1.0, 0)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.05
	ring.mesh = disc
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(1.0, 0.4, 0.1, 0.5)
	ring.material_override = rm
	_keep(ring)
	ring.global_position = p + Vector3(0, 0.1, 0.5)
	EarthFX.spike(self, p + Vector3(1.0, 0, 0), 1.0, Vector3.ZERO, 0.3)   # (frees itself)
	EarthFX.dirt(self, p, 0.3, 6)
	var mound := EarthFX.mound(self)
	_keep(mound)
	mound.global_position = p + Vector3(-1.2, 0, 0)
	var pit := EarthFX.pit(self, p + Vector3(0, 0, -1.5), 1.0)
	_keep(pit)
	var holder := Node3D.new()
	_keep(holder)
	holder.global_position = p
	EarthFX.shards(holder)


func unwarm() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func _keep(n: Node) -> void:
	if n.get_parent() == null:
		add_child(n)
	_nodes.append(n)

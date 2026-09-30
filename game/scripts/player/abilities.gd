class_name Abilities
extends Node
## What your class's abilities do (Classes holds which you have and their cooldowns).
## Pyromancer:
## - Flame Dash: a burst forward (through an enemy if one is ahead), untouchable while it lasts (like a
##   roll: time it as a blow lands for a perfect dodge). Whatever you pass through burns, and the ground
##   behind you stays on fire for a moment.
## - Meteor: a glowing ring marks the nearest enemy (or the ground ahead), and a burning star falls on
##   it: a big blast that throws enemies back (breaks shield guards), sets them alight and leaves the
##   ground burning.

const DASH_DISTANCE := 7.5
const DASH_TIME := 0.3
const DASH_WIDTH := 1.7
const DASH_POWER := 2.0          # times a normal sword hit
const METEOR_RADIUS := 4.2
const METEOR_POWER := 5.0
const METEOR_WARN := 0.9         # the ring glows this long before the star lands
const METEOR_REACH := 16.0
const SOUNDS := {
	"burst": preload("res://assets/sounds/fire_burst.wav"),
	"cast": preload("res://assets/sounds/fire_cast.wav"),
	"thud": preload("res://assets/sounds/tree_thud.wav"),
}

@onready var player: CharacterBody3D = get_parent()


## The action: an ability button.
func use(ability: String) -> void:
	if player.is_down() or Controls.locked or player.is_rolling():
		return
	if not Classes.use(ability):
		return
	match ability:
		"flame_dash":
			_flame_dash()
		"meteor":
			_meteor()


func _flame_dash() -> void:
	var dir := Vector3.ZERO
	var m := Controls.get_move()
	if m.length() > 0.2:
		dir = Vector3(m.x, 0, m.y).normalized()
	else:
		dir = Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	var foe: Node3D = _nearest(8.0, dir)                  # an enemy ahead: go straight through it
	if foe:
		var to := foe.global_position - player.global_position
		to.y = 0.0
		dir = to.normalized()
	var start := player.global_position
	player.dash(dir, DASH_DISTANCE / DASH_TIME, DASH_TIME)
	_play("burst", 1.25, -3.0)
	var trail := FireFX.flames(player, player.global_position + Vector3(0, 0.9, 0), 0.4, 26, 0.5, false, 0.55)
	trail.local_coords = false
	get_tree().create_timer(DASH_TIME + 0.02).timeout.connect(func() -> void:
		trail.emitting = false
		get_tree().create_timer(0.7).timeout.connect(trail.queue_free)
		var end := player.global_position
		var hit_any := false
		for e in get_tree().get_nodes_in_group("enemy"):
			if not e.is_alive():
				continue
			var p: Vector3 = (e as Node3D).global_position
			if _dist_to_segment(p, start, end) < DASH_WIDTH:
				var dmg: int = Gear.hit_damage(DASH_POWER)[0]
				e.take_burn(dmg)
				FireFX.ignite(e, 3.0)
				hit_any = true
		for k in 3:                                        # the ground you crossed keeps burning
			var at := start.lerp(end, (k + 0.5) / 3.0)
			FireFX.burning_ground(player.get_parent(), at, 1.2, 2.5, 1)
		if hit_any:
			get_tree().call_group("camera_rig", "shake", 0.1))


func _meteor() -> void:
	var foe: Node3D = _nearest(METEOR_REACH, Vector3.ZERO)
	var facing := Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	var target: Vector3 = foe.global_position if foe else player.global_position + facing * 7.0
	if foe:
		var to := foe.global_position - player.global_position
		player.visual.rotation.y = atan2(to.x, to.z)
	player.visual.play_action("Spell_Simple_Shoot", 1.2)
	_play("cast", 1.0, -2.0)
	var root := player.get_parent()
	# The warning ring on the ground: it tracks the target for most of the wait, then holds still.
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = METEOR_RADIUS * 0.8
	disc.bottom_radius = METEOR_RADIUS * 0.8
	disc.height = 0.05
	disc.radial_segments = 28
	ring.mesh = disc
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(1.0, 0.4, 0.1, 0.0)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	ring.global_position = target + Vector3(0, 0.08, 0)
	var rt := ring.create_tween()
	rt.tween_property(rm, "albedo_color:a", 0.55, METEOR_WARN * 0.5)
	rt.tween_property(rm, "albedo_color:a", 0.25, METEOR_WARN * 0.25)
	rt.tween_property(rm, "albedo_color:a", 0.7, METEOR_WARN * 0.25)
	var follow := func() -> void:
		if is_instance_valid(foe) and foe.is_alive() and is_instance_valid(ring):
			ring.global_position = foe.global_position + Vector3(0, 0.08, 0)
	for i in 6:
		get_tree().create_timer(METEOR_WARN * 0.1 * (i + 1)).timeout.connect(follow)
	# The star: a glowing rock with a tail of fire, falling in from high up.
	var star := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.7
	ball.height = 1.4
	ball.radial_segments = 8
	ball.rings = 5
	star.mesh = ball
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.25, 0.1, 0.05)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.45, 0.1)
	sm.emission_energy_multiplier = 2.5
	star.material_override = sm
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.visible = false
	root.add_child(star)
	var tail := FireFX.flames(star, Vector3.ZERO, 0.5, 40, 0.5, false, 0.8)
	tail.local_coords = false
	tail.emitting = false
	get_tree().create_timer(METEOR_WARN * 0.45).timeout.connect(func() -> void:
		var land: Vector3 = ring.global_position if is_instance_valid(ring) else target
		star.global_position = land + Vector3(-7.0, 26.0, -5.0)
		star.visible = true
		tail.emitting = true
		var ft := star.create_tween()
		ft.tween_method(func(k: float) -> void:
			var land_now: Vector3 = ring.global_position if is_instance_valid(ring) else land
			star.global_position = (land_now + Vector3(-7.0, 26.0, -5.0)).lerp(land_now, k * k), 0.0, 1.0, METEOR_WARN * 0.55)
		ft.tween_callback(func() -> void:
			var at: Vector3 = star.global_position
			star.queue_free()
			if is_instance_valid(ring):
				ring.queue_free()
			_meteor_lands(at)))


func _meteor_lands(at: Vector3) -> void:
	var root := player.get_parent()
	FireFX.blast(root, at, METEOR_RADIUS)
	_play("burst", 0.7, 2.0)
	_play("thud", 0.5, 0.0)
	get_tree().call_group("camera_rig", "shake", 0.35)
	var hit := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive():
			continue
		var d: float = (e as Node3D).global_position.distance_to(at)
		if d > METEOR_RADIUS:
			continue
		var dmg := maxi(1, roundi(Gear.hit_damage(METEOR_POWER)[0] * lerpf(1.0, 0.5, d / METEOR_RADIUS)))
		e.take_hit(at, dmg, 2.5)
		FloatText.spawn(get_tree(), (e as Node3D).global_position + Vector3(0, 1.6, 0), str(dmg) + "!", Color(1.0, 0.55, 0.2), true)
		FireFX.ignite(e, 4.0)
		hit = true
	FireFX.burning_ground(root, at, METEOR_RADIUS * 0.65, 4.0, 1)
	if hit:
		Engine.time_scale = 0.1
		get_tree().create_timer(0.09, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


## The closest living enemy within `reach`; if `ahead` is given, only ones roughly that way.
func _nearest(reach: float, ahead: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive():
			continue
		var to: Vector3 = (e as Node3D).global_position - player.global_position
		to.y = 0.0
		if ahead != Vector3.ZERO and to.normalized().dot(ahead) < 0.6:
			continue
		if to.length() < best_d:
			best_d = to.length()
			best = e
	return best


func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector3(b.x - a.x, 0, b.z - a.z)
	var ap := Vector3(p.x - a.x, 0, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (ap - ab * t).length()


func _play(sound: String, pitch: float, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = SOUNDS[sound]
	p.pitch_scale = pitch
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

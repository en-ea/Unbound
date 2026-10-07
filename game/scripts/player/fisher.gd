class_name Fisher
extends Node
## Fishing: stand at the water's edge and press Fish (world/fishing_spots.gd, or the pool in the cave).
## You cast; the bobber floats and twitches at nibbles; when it plunges, tap Hook in time. Then the
## fight: hold Reel to pull in, let go to give line. The fish surges now and then; keep the line's
## tension in the green band to bring it in, too tight and it snaps, too slack and it slips the hook.
## Rare fish pull harder and the band is narrower. Walking away (or Stop) ends it.
## Fish and sizes: state/fish_data.gd. The screen: ui/fishing_ui.gd.

signal message(text: String)
signal caught(id: String, size: int, note: String)

enum Phase { OFF, CASTING, WAITING, BITE, REEL, LANDED }

const SOUNDS := {"cast": preload("res://assets/sounds/fish_cast.wav"), "plop": preload("res://assets/sounds/fish_plop.wav"),
	"splash": preload("res://assets/sounds/fish_splash.wav"), "reel": preload("res://assets/sounds/fish_reel.wav"),
	"caught": preload("res://assets/sounds/fish_caught.wav"), "rare": preload("res://assets/sounds/rare.wav")}
const ROD_TIP := Vector3(0, 1.3, 0)        # in the rod model, from the grip
const BAND_MID := 0.55                     # the middle of the safe tension band
const REEL_UP := 0.8                       # tension a second while you hold Reel
const SLACK_DOWN := 0.95                   # and while you let go
const SLACK_LIMIT := 1.4                   # seconds slack before it slips off

static var grip := Vector3(-70, 0, 0)     # how the rod sits in the hand (dev: --rodgrip=x,y,z)

var player: CharacterBody3D
var phase := Phase.OFF
var water := ""
var fish := ""
var size := 0
var tension := 0.3
var progress := 0.0
var reeling := false                       # the Reel button is held (fishing_ui.gd)
var band := Vector2(0.35, 0.75)            # the safe tension band for this fish
var _timer := 0.0
var _nibble := 0.0
var _surge := 0.0                          # seconds left in this surge
var _calm := 0.0                           # seconds to the next surge
var _slack := 0.0
var _pull := 0.0
var _rate := 0.0
var _bob := 0.0
var _target := Vector3.ZERO                # where the bobber floats
var _shore := Vector3.ZERO                 # the edge you stand at
var _rod: MeshInstance3D
var _hand: Node3D                          # the right hand (a bone attachment)
var _bobber: Node3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _audio: AudioStreamPlayer3D
var _reel_tick := 0.0


func is_fishing() -> bool:
	return phase != Phase.OFF


## The hooked fish is pulling hard right now (ease off!).
func surging() -> bool:
	return phase == Phase.REEL and _surge > 0.0


## The action: start fishing into `water` ("meadow", "forest", "cave"), the bobber landing at `target`.
func start(water_id: String, target: Vector3) -> void:
	if is_fishing() or player.is_down() or player.hauling.carrying or player.hauling.riding:
		return
	water = water_id
	_target = target
	_shore = player.global_position
	_build()
	get_tree().call_group("hud", "open_fishing", self)
	cast()


## The action: stop (walked away, pressed Stop, knocked out).
func stop() -> void:
	if not is_fishing():
		return
	phase = Phase.OFF
	reeling = false
	player.visual.idle_anim = ""
	player.visual.stop_action()
	player.visual.show_tool("")
	if is_instance_valid(_hand):
		_hand.queue_free()
	for n: Node in [_rod, _bobber, _line]:
		if is_instance_valid(n):
			n.queue_free()
	get_tree().call_group("hud", "close_fishing")


## The action: cast the line (also again after a catch or a lost fish).
func cast() -> void:
	phase = Phase.CASTING
	progress = 0.0
	tension = 0.3
	var to := _target - player.global_position
	player.visual.rotation.y = atan2(to.x, to.z)
	player.visual.play_action("OverhandThrow", 1.2)
	_play("cast", 1.0)
	_bobber.visible = false
	_timer = 0.55
	message.emit("")


## The big button was tapped: hook a biting fish (too early just spooks them), or cast again.
func tap() -> void:
	match phase:
		Phase.WAITING:
			message.emit("Too soon! Wait for it to go under")
			_timer = randf_range(2.5, 5.0)
			_nibble = randf_range(0.8, 2.0)
			_dip(0.08)
		Phase.BITE:
			_hook()
		Phase.LANDED:
			cast()


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	player.knocked_out.connect(stop)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 8.0
	add_child(_audio)


func _build() -> void:
	var held: Node3D = player.visual.hold_prop("rod", grip, Vector3(0, 0.06, 0.02))    # only for the hand's position
	held.visible = false
	_hand = held.get_parent()
	_rod = MeshInstance3D.new()                     # the rod itself, aimed from the hand out over the water
	_rod.mesh = Items.mesh("rod")
	_rod.top_level = true
	player.add_child(_rod)
	player.visual.show_tool("")
	player.visual.idle_anim = "Spell_Simple_Idle"
	_bobber = Node3D.new()
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.radial_segments = 8
	sphere.rings = 4
	ball.mesh = sphere
	ball.material_override = _mat(Color(0.9, 0.18, 0.12))
	_bobber.add_child(ball)
	var cap := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.045
	cyl.height = 0.08
	cyl.radial_segments = 6
	cap.mesh = cyl
	cap.material_override = _mat(Color(0.95, 0.94, 0.88))
	cap.position.y = 0.11
	_bobber.add_child(cap)
	_bobber.top_level = true
	player.add_child(_bobber)
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.95, 0.9, 0.8)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child(_line)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


func _process(delta: float) -> void:
	if phase == Phase.OFF:
		return
	if Controls.get_move().length() > 0.35 or player.is_down():
		stop()
		return
	_bob += delta
	match phase:
		Phase.CASTING:
			_timer -= delta
			if _timer <= 0.0:
				_land_bobber()
		Phase.WAITING:
			_wait(delta)
		Phase.BITE:
			_timer -= delta
			_bobber.global_position = _target + Vector3(0, -0.12 + sin(_bob * 30.0) * 0.02, 0)
			if _timer <= 0.0:
				message.emit("It got away… wait for the next one")
				_bobber.global_position = _target
				_enter_wait()
		Phase.REEL:
			_reel(delta)
	_aim_rod()
	_draw_line()


## The rod from your hand out towards the bobber, its tip pulled down while a fish fights.
func _aim_rod() -> void:
	if not is_instance_valid(_hand):
		return
	var grip := _hand.global_position
	var fwd := Vector3(sin(player.visual.rotation.y), 0.0, cos(player.visual.rotation.y))
	var dip := 0.0
	if phase == Phase.REEL:
		dip = tension * 0.7 + (0.25 if _surge > 0.0 else 0.0)
	elif phase == Phase.BITE:
		dip = 0.4
	var tip := player.global_position + fwd * (1.35 + dip * 0.2) + Vector3(0, 2.2 - dip, 0)
	var dir := tip - grip
	var length := dir.length()
	_rod.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir / length)) * Basis.from_scale(Vector3(1, length / ROD_TIP.y, 1)), grip)


func _land_bobber() -> void:
	_bobber.visible = true
	var from := _tip()
	var t := _bobber.create_tween()  # studio: merge - the cast tween dies with the bobber (Stop during the 0.45 s cast errored every frame)
	t.tween_method(func(k: float) -> void:
		_bobber.global_position = from.lerp(_target, k) + Vector3(0, sin(k * PI) * 1.4, 0), 0.0, 1.0, 0.45)
	t.tween_callback(func() -> void:
		_play("plop", 1.0)
		_splash(_target, 6, 0.6))
	_enter_wait()


func _enter_wait() -> void:
	phase = Phase.WAITING
	_timer = randf_range(3.0, 8.0) + 0.45
	_nibble = randf_range(1.2, 2.5)
	message.emit("Waiting for a bite…")


func _wait(delta: float) -> void:
	_timer -= delta
	_nibble -= delta
	if _nibble <= 0.0 and _timer > 1.0:          # a nibble: a little twitch to keep you watching
		_nibble = randf_range(1.0, 2.6)
		_dip(0.05)
		_play("plop", 1.5, -14.0)
	_bobber.global_position.y = lerpf(_bobber.global_position.y, _target.y + sin(_bob * 2.2) * 0.025, 0.2)
	if _timer <= 0.0:
		var roll := FishData.roll(water, _night())
		fish = roll[0]
		size = roll[1]
		var f: Dictionary = FishData.FISH[fish]
		phase = Phase.BITE
		_timer = 0.85 if f["pull"] < 0.6 else 0.65
		_play("plop", 0.8)
		_splash(_target, 10, 1.0)
		message.emit("Something's biting! HOOK IT!")


func _dip(depth: float) -> void:
	var t := create_tween()
	t.tween_property(_bobber, "global_position:y", _target.y - depth, 0.08)
	t.tween_property(_bobber, "global_position:y", _target.y, 0.25)


func _hook() -> void:
	var f: Dictionary = FishData.FISH[fish]
	var heft := FishData.heft(fish, size)
	_pull = f["pull"] * lerpf(0.85, 1.25, heft)
	_rate = f["rate"] * lerpf(1.1, 0.85, heft)
	band = Vector2(BAND_MID - f["zone"] * 0.5, BAND_MID + f["zone"] * 0.5)
	tension = BAND_MID
	progress = 0.08
	_slack = 0.0
	_surge = 0.0
	_calm = randf_range(0.6, 1.4)
	phase = Phase.REEL
	player.visual.play_action("Sword_Block", 1.4)
	_play("splash", 1.1)
	_splash(_target, 14, 1.2)
	message.emit("Hold Reel — keep the line in the green")


func _reel(delta: float) -> void:
	if _surge > 0.0:                                  # it fights: a sudden yank on the line
		_surge -= delta
		tension += _pull * 1.7 * delta
		if randf() < delta * 6.0:
			_splash(_bobber.global_position, 3, 0.5)
	else:
		_calm -= delta
		if _calm <= 0.0:
			_surge = randf_range(0.35, 0.6 + _pull * 0.6)
			_calm = randf_range(0.7, 2.2 - _pull)
			_play("splash", randf_range(1.1, 1.4), -8.0)
	tension += (REEL_UP if reeling else -SLACK_DOWN) * delta
	tension = clampf(tension, 0.0, 1.05)
	var inside := tension >= band.x and tension <= band.y
	if inside:
		progress += _rate * delta * (1.0 if reeling else 0.3)
	else:
		progress -= 0.06 * delta
	progress = clampf(progress, 0.0, 1.0)
	if reeling:
		_reel_tick -= delta
		if _reel_tick <= 0.0:
			_reel_tick = 0.5
			_play("reel", 0.9 + progress * 0.3, -6.0)
	_slack = _slack + delta if tension <= 0.04 else 0.0
	# The bobber comes in towards you as you win, and thrashes while it surges.
	var near := _target.lerp(Vector3(_shore.x, _target.y, _shore.z), progress * 0.75)
	var thrash := Vector3(sin(_bob * 23.0), 0, cos(_bob * 19.0)) * (0.12 if _surge > 0.0 else 0.03)
	_bobber.global_position = near + thrash + Vector3(0, -0.05, 0)
	if tension >= 1.0:
		_play("splash", 0.8)
		message.emit("Snap! The line broke")
		_lost()
	elif _slack > SLACK_LIMIT:
		message.emit("Too slack, it slipped off the hook")
		_lost()
	elif progress >= 1.0:
		_land()


func _lost() -> void:
	reeling = false
	cast_later(1.4)


func cast_later(seconds: float) -> void:
	phase = Phase.LANDED
	_bobber.visible = false
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if phase == Phase.LANDED:
			cast())


## Landed: it leaps out of the water to you, into the Bag.
func _land() -> void:
	phase = Phase.LANDED
	reeling = false
	_bobber.visible = false
	var from := _bobber.global_position
	_splash(from, 18, 1.4)
	_play("splash", 1.0)
	var body := MeshInstance3D.new()
	body.mesh = Items.mesh(fish)
	body.top_level = true
	body.scale = Vector3.ONE * lerpf(1.6, 3.2, FishData.heft(fish, size))
	player.add_child(body)
	var to := player.global_position + Vector3(0, 1.2, 0)
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		body.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 1.6, 0)
		body.rotation = Vector3(sin(k * 9.0) * 0.6, k * TAU * 1.5, 0), 0.0, 1.0, 0.7)
	t.tween_interval(0.5)
	t.tween_callback(body.queue_free)
	Inventory.add(fish)
	var note := FishData.record(fish, size)
	var rare: bool = Items.DEFS[fish]["rarity"] >= Items.Rarity.RARE
	_play("rare" if rare else "caught", 1.0)
	player.visual.play_action("Farm_Harvest", 1.5)
	caught.emit(fish, size, note)
	message.emit("")


func _tip() -> Vector3:
	return _rod.global_transform * ROD_TIP if is_instance_valid(_rod) else player.global_position + Vector3(0, 1.8, 0)


## The line from the rod tip to the bobber, sagging when slack and straight when tight.
func _draw_line() -> void:
	_line_mesh.clear_surfaces()
	if not _bobber.visible:
		return
	var a := _tip()
	var b := _bobber.global_position + Vector3(0, 0.1, 0)
	var sag := 0.5 if phase != Phase.REEL else lerpf(0.45, 0.02, clampf(tension, 0.0, 1.0))
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 11:
		var k := i / 10.0
		_line_mesh.surface_add_vertex(a.lerp(b, k) - Vector3(0, sin(k * PI) * sag, 0))
	_line_mesh.surface_end()


func _splash(at: Vector3, amount: int, scale_by: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.5 * scale_by
	p.initial_velocity_max = 3.0 * scale_by
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 4
	drop.rings = 2
	p.mesh = drop
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.82, 0.92, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	p.top_level = true
	player.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _night() -> bool:
	var dn := get_tree().get_first_node_in_group("day_night")
	if dn == null:
		dn = player.get_parent().get_node_or_null("WorldEnvironment")
	return dn != null and dn.get("night") != null and float(dn.get("night")) > 0.5


func _play(id: String, pitch: float, db := -2.0) -> void:
	_audio.stream = SOUNDS[id]
	_audio.pitch_scale = pitch
	_audio.volume_db = db
	_audio.global_position = _bobber.global_position if is_instance_valid(_bobber) and _bobber.visible else player.global_position
	_audio.play()

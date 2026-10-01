class_name Delver
extends Node
## What the Delver's abilities do (Classes holds the cooldowns; Abilities hands the buttons over).
## - Burrow: you sink into the ground and move fast beneath it, untouchable, a mound of earth showing
##   where you are. Attack (the button says Erupt) bursts out in a claw uppercut that throws everyone near
##   into the air. Burrow again (it says Drag) drags the nearest foe under: the weak are swallowed whole,
##   the rest are stuck waist-deep (you stay down, so you can erupt right under them).
## - Fault Line: a crack races ahead and stone spikes burst up along it, throwing and cracking all in the way.
## - Sinkhole: the ground under the nearest group caves in: everyone is pulled to the middle and held, the
##   weak are swallowed, then it slams shut in a ring of stone.
## The class trait: Cracked foes (EarthFX.crack) take more from you and are swallowed at higher health.

const CLAW_POWER := 0.8          # claws hit a little lighter than a sword, but faster (fighter.gd)
const BURROW_TIME := 5.0
const BURROW_SPEED := 7.0
const ERUPT_RADIUS := 3.4
const ERUPT_POWER := 2.5         # times a normal claw hit
const DRAG_REACH := 4.5
const STUCK_TIME := 2.6
const FAULT_LENGTH := 10.0
const FAULT_WIDTH := 1.5
const FAULT_POWER := 2.2
const FAULT_SPACING := 1.1
const PIT_RADIUS := 4.2
const PIT_REACH := 14.0
const PIT_HOLD := 2.4
const PIT_PULL := 2.2            # metres a second towards the middle
const PIT_POWER := 3.5
const WEAK := 0.35               # the earth swallows a foe at or under this share of its health
const CRACK_WEAK := 0.25         # more when it's cracked
const CRACK_TIME := 6.0
const CRACK_BONUS := 0.3         # cracked foes take this much more from you (Rend: twice)
const SOUNDS := {
	"thud": preload("res://assets/sounds/tree_thud.wav"),
	"burst": preload("res://assets/sounds/fire_burst.wav"),
}

var under := false
var dragged_this_dive := false
var _left := 0.0
var _down_for := 0.0
var _mound: Node3D
var _held := {}                  # enemy -> its visual's resting height, while the earth holds it

@onready var player: CharacterBody3D = get_parent().get_parent()


## Extra damage on a cracked foe (any of your hits).
static func bonus(enemy: Node) -> float:
	if not EarthFX.is_cracked(enemy):
		return 1.0
	return 1.0 + CRACK_BONUS * (2.0 if Classes.has_talent("rend") else 1.0)


static func cracked_damage(enemy: Node, damage: int) -> int:
	return maxi(1, roundi(damage * bonus(enemy)))


func burrow_speed() -> float:
	return BURROW_SPEED * (1.3 if Classes.has_talent("deep_runner") else 1.0)


# --- Burrow -----------------------------------------------------------------------------------

func burrow() -> void:
	under = true
	dragged_this_dive = false
	_left = BURROW_TIME * (2.0 if Classes.has_talent("deep_runner") else 1.0)
	_down_for = 0.0
	var root := player.get_parent()
	EarthFX.dirt(root, player.global_position, 0.6, 26, 6.0)
	_play("thud", 0.6, 0.0)
	player.visual.play_action("Jump_Start", 2.0)
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if under:
			player.visual.visible = false)
	_mound = EarthFX.mound(root)
	_mound.global_position = player.global_position
	get_tree().call_group("camera_rig", "shake", 0.08)


func _physics_process(delta: float) -> void:
	if not under:
		return
	_left -= delta
	_down_for += delta
	if is_instance_valid(_mound):
		var at := player.global_position
		_mound.global_position = _mound.global_position.lerp(at, clampf(18.0 * delta, 0.0, 1.0))
		_mound.rotation.y = player.visual.rotation.y
		_mound.scale = Vector3.ONE * (1.0 + sin(_down_for * 14.0) * 0.06)
	if _left <= 0.0 or player.is_down():
		erupt()


## Burst out of the ground (Attack while burrowed, or when your breath runs out).
func erupt() -> void:
	if not under:
		return
	under = false
	Classes.start_cooldown("burrow")
	var root := player.get_parent()
	var here := player.global_position
	if is_instance_valid(_mound):
		_mound.queue_free()
	player.visual.visible = true
	var foe: Node3D = _nearest(ERUPT_RADIUS + 1.0)
	if foe:
		var to := foe.global_position - here
		player.visual.rotation.y = atan2(to.x, to.z)
	player.visual.play_action("Melee_Hook", 0.8)
	var vis: Node3D = player.visual
	var pop := vis.create_tween()                    # a leap up out of the hole
	pop.tween_property(vis, "position:y", 1.0, 0.16).set_ease(Tween.EASE_OUT)
	pop.tween_property(vis, "position:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	EarthFX.dirt(root, here, 0.8, 40, 9.0)
	for i in 6:
		var a := TAU * i / 6.0 + randf() * 0.4
		EarthFX.spike(root, here + Vector3(cos(a), 0, sin(a)) * 1.6, randf_range(1.0, 1.5), Vector3(cos(a), 0, sin(a)), 0.5)
	_play("thud", 0.5, 2.0)
	_play("burst", 0.6, -6.0)
	get_tree().call_group("camera_rig", "shake", 0.25)
	var power := ERUPT_POWER * (2.0 if Classes.has_talent("ambush") else 1.0)
	var hit := false
	for e in _enemies_near(here, ERUPT_RADIUS):
		_strike(e, here, power, 3.0)
		_toss(e, 2.2)
		EarthFX.crack(e, CRACK_TIME * (2.0 if Classes.has_talent("ambush") else 1.0))
		hit = true
	if hit:
		_hit_stop(0.1)


## The Burrow button while under: pull the nearest foe into the ground. Once a dive.
func drag_under() -> void:
	if not under or dragged_this_dive:
		return
	var foe: Node3D = _nearest(DRAG_REACH)
	if foe == null:
		get_tree().call_group("hud", "hint", "Nobody close enough to drag under.")
		return
	dragged_this_dive = true
	var root := player.get_parent()
	EarthFX.dirt(root, foe.global_position, 0.7, 30, 5.0)
	_play("thud", 0.45, 1.0)
	get_tree().call_group("camera_rig", "shake", 0.15)
	if can_swallow(foe):
		swallow(foe)
	else:
		var dmg := cracked_damage(foe, Gear.hit_damage(1.5)[0])
		foe.take_hit(player.global_position, dmg, 0.1)
		FloatText.spawn(get_tree(), foe.global_position + Vector3(0, 1.4, 0), str(dmg), Color(0.75, 0.95, 0.85))
		EarthFX.crack(foe, CRACK_TIME)
		hold(foe, 0.75)
		get_tree().create_timer(STUCK_TIME).timeout.connect(release.bind(foe))
		get_tree().call_group("hud", "hint", "Stuck! Erupt under it now.")


# --- Fault Line -------------------------------------------------------------------------------

func fault_line() -> void:
	var facing := Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	var m := Controls.get_move()
	if m.length() > 0.3:
		facing = Vector3(m.x, 0, m.y).normalized()
	var foe: Node3D = _nearest(12.0, facing)
	if foe:
		var to := foe.global_position - player.global_position
		to.y = 0.0
		facing = to.normalized()
	player.visual.rotation.y = atan2(facing.x, facing.z)
	player.visual.play_action("Sword_Attack", 1.6)
	var dirs: Array[Vector3] = [facing]
	if Classes.has_talent("split_earth"):
		dirs.append(facing.rotated(Vector3.UP, 0.45))
		dirs.append(facing.rotated(Vector3.UP, -0.45))
	var start := player.global_position
	get_tree().create_timer(0.36).timeout.connect(func() -> void:
		_play("thud", 0.55, 2.0)
		get_tree().call_group("camera_rig", "shake", 0.18)
		EarthFX.dirt(player.get_parent(), start + facing * 0.8, 0.5, 20, 6.0)
		for d in dirs:
			_run_fault(start, d, 1.0)
		if Classes.has_talent("aftershock"):
			get_tree().create_timer(0.9).timeout.connect(func() -> void:
				for d in dirs:
					_run_fault(start, d, 0.5)))


## One crack: spikes burst up one after another from `start` along `dir`; each hits those beside it once.
func _run_fault(start: Vector3, dir: Vector3, power: float) -> void:
	var length := FAULT_LENGTH * (1.5 if Classes.has_talent("long_fault") else 1.0)
	var count := int(length / FAULT_SPACING)
	var struck := {}
	for i in count:
		get_tree().create_timer(0.045 * i).timeout.connect(func() -> void:
			var at := _ground(start + dir * FAULT_SPACING * (i + 1), start)
			var side := dir.cross(Vector3.UP) * randf_range(-0.3, 0.3)
			EarthFX.spike(player.get_parent(), at + side, randf_range(1.2, 1.9) * (0.7 if power < 1.0 else 1.0), dir * 0.6 + side)
			for e in _enemies_near(at, FAULT_WIDTH):
				if struck.has(e):
					continue
				struck[e] = true
				_strike(e, at - dir, FAULT_POWER * power, 2.4)
				_toss(e, 1.6 * power)
				EarthFX.crack(e, CRACK_TIME)
				if power >= 1.0:
					_hit_stop(0.05))


# --- Sinkhole ---------------------------------------------------------------------------------

func sinkhole() -> void:
	var facing := Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	var foe: Node3D = _nearest(PIT_REACH)
	var centre: Vector3 = player.global_position + facing * 6.0
	if foe:
		var group := _enemies_near(foe.global_position, 4.0)   # the middle of the bunch round it
		centre = Vector3.ZERO
		for e in group:
			centre += (e as Node3D).global_position
		centre /= group.size()
		var to := centre - player.global_position
		player.visual.rotation.y = atan2(to.x, to.z)
	centre = _ground(centre, player.global_position)
	player.visual.play_action("Sword_Attack", 1.3)
	var radius := PIT_RADIUS * (1.33 if Classes.has_talent("wide_pit") else 1.0)
	var hold_for := PIT_HOLD * (1.5 if Classes.has_talent("undertow") else 1.0)
	var pull := PIT_PULL * (1.6 if Classes.has_talent("undertow") else 1.0)
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		var pit := EarthFX.pit(player.get_parent(), centre, radius)
		EarthFX.dirt(player.get_parent(), centre, radius * 0.6, 40, 7.0)
		_play("thud", 0.4, 3.0)
		get_tree().call_group("camera_rig", "shake", 0.3)
		var clock := {"tick": 0.0}                # lambdas copy plain locals, so the tick lives in a dictionary
		var step := func(delta: float) -> void:
			clock["tick"] -= delta
			var tick: float = clock["tick"]
			for e in _enemies_near(centre, radius * 1.1):
				if not _held.has(e):
					hold(e, 0.0)
				var n := e as Node3D
				var to := centre - n.global_position
				to.y = 0.0
				if to.length() > 0.4:
					n.global_position += to.normalized() * minf(pull * delta, to.length())
				var vis: Node3D = e.visual
				vis.position.y = lerpf(vis.position.y, _held[e] - 0.9, 2.0 * delta)
				if tick <= 0.0:
					if can_swallow(e):
						swallow(e)
					else:
						var dmg := cracked_damage(e, Gear.hit_damage(0.4)[0])
						e.take_burn(dmg)
			if tick <= 0.0:
				clock["tick"] = 0.5
		var ticker := Timer.new()
		ticker.wait_time = 1.0 / 30.0
		ticker.timeout.connect(func() -> void: step.call(1.0 / 30.0))
		pit.add_child(ticker)
		ticker.start()
		get_tree().create_timer(hold_for).timeout.connect(func() -> void:
			ticker.stop()
			_close_pit(pit, centre, radius)))


## The pit slams shut: a ring of stone, everyone in it thrown out and cracked (Earth's Maw: stone jaws
## bite, twice as hard, and swallow every cracked foe).
func _close_pit(pit: Node3D, centre: Vector3, radius: float) -> void:
	var root := player.get_parent()
	var maw := Classes.has_talent("earths_maw")
	var n := 12 if maw else 8
	for i in n:
		var a := TAU * i / n
		var out := Vector3(cos(a), 0, sin(a))
		EarthFX.spike(root, centre + out * radius * 0.85, randf_range(1.6, 2.4) * (1.3 if maw else 1.0), -out * (1.4 if maw else 0.5), 0.6)
	EarthFX.spike(root, centre, 2.6, Vector3.ZERO, 0.6)
	EarthFX.dirt(root, centre, radius * 0.5, 50, 10.0)
	EarthFX.close_pit(pit)
	_play("thud", 0.35, 4.0)
	_play("burst", 0.5, -4.0)
	get_tree().call_group("camera_rig", "shake", 0.4)
	var hit := false
	for e in _held.keys():
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if (e as Node3D).global_position.distance_to(centre) > radius * 1.3:
			continue
		if maw and EarthFX.is_cracked(e) and not _too_big(e):
			swallow(e)
			continue
		release(e)
		_strike(e, centre, PIT_POWER * (2.0 if maw else 1.0), 3.0)
		hit = true
		if can_swallow(e):                    # the slam left it weak: the closing earth takes it
			swallow(e)
			continue
		_toss(e, 2.6)
		EarthFX.crack(e, CRACK_TIME)
	if hit:
		_hit_stop(0.1)


# --- The earth holding and swallowing foes ----------------------------------------------------

## Weak enough for the earth to take whole (bosses and the bandit leader never are).
func can_swallow(e: Node) -> bool:
	if not e.is_alive() or _too_big(e):
		return false
	var share := WEAK + (0.15 if Classes.has_talent("hungry_earth") else 0.0)
	if EarthFX.is_cracked(e):
		share += CRACK_WEAK + (0.15 if Classes.has_talent("hungry_earth") else 0.0)
	return float(e.health) <= e.max_health * share


func _too_big(e: Node) -> bool:
	return e.get("duskmaw") == true or e.get("kind") == "leader"


## Freezes a foe in the ground (it can't act), sunk `depth` metres.
func hold(e: Node, depth: float) -> void:
	if not _held.has(e):
		_held[e] = (e.visual as Node3D).position.y
		e.set_physics_process(false)
	if depth > 0.0:
		var vis: Node3D = e.visual
		vis.create_tween().tween_property(vis, "position:y", _held[e] - depth, 0.25).set_ease(Tween.EASE_OUT)


## Lets it go: it climbs back out.
func release(e: Node) -> void:
	if not is_instance_valid(e) or not _held.has(e):
		return
	var rest: float = _held[e]
	_held.erase(e)
	e.set_physics_process(true)
	var vis: Node3D = e.visual
	vis.create_tween().tween_property(vis, "position:y", rest, 0.3)


## Pulls it all the way down: it's gone (no body left), and the earth spits out whatever it carried.
func swallow(e: Node) -> void:
	if not e.is_alive():
		return
	if not _held.has(e):
		hold(e, 0.0)
	var vis: Node3D = e.visual
	var rest: float = _held[e]
	var at := (e as Node3D).global_position
	EarthFX.dirt(player.get_parent(), at, 0.6, 30, 4.0)
	FloatText.spawn(get_tree(), at + Vector3(0, 1.6, 0), "Swallowed!", EarthFX.ORE, true)
	var t := vis.create_tween()
	t.tween_property(vis, "position:y", rest - 2.4, 0.7).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(vis, "rotation:y", vis.rotation.y + PI, 0.7)
	t.tween_callback(func() -> void:
		if not is_instance_valid(e):
			return
		_held.erase(e)
		e.set_physics_process(true)
		if e.is_alive():
			e.take_burn(e.health)
		Skills.add("combat", Balance.XP_PER_SWORD_HIT * 3)
		for c in get_tree().get_nodes_in_group("carcass"):    # it took the body down with it
			if (c as Node3D).global_position.distance_to(at) < 1.5 and c.age < 0.5:
				c.vanish()
		vis.visible = false
		_restore_when_back(e, vis, rest)
		if Classes.has_talent("ore_heart"):
			player.heal(2)
			Classes.start_cooldown("burrow", 0.0)
			player.get_node("Effects").glow_burst(EarthFX.ORE, 30))
	_play("thud", 0.35, 2.0)


## Swallowed foes that come back later (wolves and boars respawn) climb out looking normal again.
func _restore_when_back(e: Node, vis: Node3D, rest: float) -> void:
	var watch := Timer.new()
	watch.wait_time = 1.0
	watch.timeout.connect(func() -> void:
		if not is_instance_valid(e):
			return
		if e.is_alive():
			vis.position.y = rest
			vis.visible = true
			watch.queue_free())
	e.add_child(watch)
	watch.start()


# --- Helpers ----------------------------------------------------------------------------------

## A hit from the earth: claw-scaled damage (more on cracked foes), thrown back by `push`.
func _strike(e: Node, from: Vector3, power: float, push: float) -> void:
	if not e.is_alive():
		return
	var dmg := cracked_damage(e, maxi(1, roundi(Gear.hit_damage(power)[0] * CLAW_POWER)))
	e.take_hit(from, dmg, push)
	FloatText.spawn(get_tree(), (e as Node3D).global_position + Vector3(0, 1.6, 0), str(dmg) + "!", Color(0.75, 0.98, 0.88), true)
	Skills.add("combat", Balance.XP_PER_SWORD_HIT)


## Throws a foe's body up into the air and back down (its visual; the creature itself stays on the ground).
func _toss(e: Node, height: float) -> void:
	if not is_instance_valid(e) or not e.is_alive() or _held.has(e):
		return
	var vis: Node3D = e.visual
	var rest := vis.position.y
	var t := vis.create_tween()
	t.tween_property(vis, "position:y", rest + height, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(vis, "position:y", rest, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Enemies within `radius` of a spot, measured flat (a little up or down hill still counts).
func _enemies_near(at: Vector3, radius: float) -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool:
		var to: Vector3 = (e as Node3D).global_position - at
		return e.is_alive() and Vector2(to.x, to.z).length() < radius and absf(to.y) < 3.0)


## The ground under `p`, following the terrain's rise and fall from `from` (works on any floor, the lab too).
func _ground(p: Vector3, from: Vector3) -> Vector3:
	var shape := Carcass.shape
	if shape:
		p.y = from.y + shape.height_at(p.x, p.z) - shape.height_at(from.x, from.z)
	else:
		p.y = from.y
	return p


func _nearest(reach: float, ahead := Vector3.ZERO) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive():
			continue
		var to: Vector3 = (e as Node3D).global_position - player.global_position
		to.y = 0.0
		if ahead != Vector3.ZERO and to.length() > 0.5 and to.normalized().dot(ahead) < 0.5:
			continue
		if to.length() < best_d:
			best_d = to.length()
			best = e
	return best


func _hit_stop(seconds: float) -> void:
	Engine.time_scale = 0.08
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _play(sound: String, pitch: float, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = SOUNDS[sound]
	p.pitch_scale = pitch
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

class_name Tidecaller
extends Node
## The Tidecaller's abilities (Classes holds the cooldowns; abilities.gd calls cast()). Studio: water class.
## - Drown: a sphere of water swallows the marked enemy and lifts it into the air. It thrashes and chokes,
##   losing health in small ticks, then the water slams it into the ground and splashes those near (wet).
## - Tempest: clouds gather round you. Rain stings everyone under it, soaks things and puts out fires;
##   lightning strikes enemies hard, the wet ones first, and can leap once to a wet foe close by.
## - Rime Wave: frost rolls out ahead of you. The wet (in the last 15 s) freeze solid and the next weapon
##   hit on them lands three times as hard and cracks the ice; the dry are only chilled.
## Passive (Tidebound): blows land harder on anything wet, your water puts out any fire it touches, and your roll
## leaves a puddle that wets whoever steps in it.
## On villagers every effect is a checked act through the one door (studio/water/water_people.gd).
## "Wet" is one fact with one clock: enemies in studio/water/wet.gd, villagers' doused fact, things' soaked fact.

const Wet := preload("res://scripts/studio/water/wet.gd")
const WaterPeople := preload("res://scripts/studio/water/water_people.gd")
const DROWN_REACH := 12.0
const DROWN_RING := 1.4
const DROWN_PICK := 2.6          # how near the aimed point a foe must stand to be taken
const DROWN_HOLD := 5.0          # seconds in the air (Undertow: 7)
const DROWN_LIFT := 1.8          # metres up
const DROWN_TICK := 0.5          # a trickle of harm every half second
const DROWN_TRICKLE := 0.2       # each trickle, in hits of your sword's power (at least 1)
const SLAM_POWER := 2.0
const SLAM_SPLASH := 3.2         # the landing wets everyone this near (Riptide: further)
const DROWNED_AT := 0.4          # Drowned: a foe held the whole time at or under this share of health drowns
const SOUNDS := {"splash": preload("res://assets/sounds/fish_splash.wav"), "plop": preload("res://assets/sounds/fish_plop.wav"),
	"thud": preload("res://assets/sounds/tree_thud.wav"), "cast": preload("res://assets/sounds/fish_cast.wav")}
const TEMPEST_RADIUS := 6.0      # Downpour: a third wider
const TEMPEST_SECS := 8.0
const RAIN_TICK := 1.0           # rain stings (1) and soaks everyone under the cloud each second
const BOLT_EVERY := 1.4
const BOLT_POWER := 2.5          # in hits of your sword's power (Conductive: x1.5 on the wet)
const CHAIN_REACH := 4.5         # lightning leaps once to a wet foe this near
const THINGS_EVERY := 2.0        # rain on the village's things (fences, crates), through the checked door
const SPRING_EVERY := 3.0        # Spring: a heart back this often while you stand in your rain
const Contact := preload("res://scripts/studio/village/contact.gd")
const Things := preload("res://scripts/studio/village/things.gd")
const ThingActions := preload("res://scripts/studio/village/sim/thing_actions.gd")
const ThingFacts := preload("res://scripts/studio/village/sim/thing_facts.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const RIME_REACH := 9.0
const RIME_ANGLE := 70.0         # degrees, the cone's full width
const RIME_SPEED := 18.0         # metres a second: the wave reaches the far ones a moment later
const RIME_POWER := 0.5          # the cold's own bite, in hits of your sword's power
const FROZEN_SECS := 3.5         # Deep Freeze: twice
const CHILL_SECS := 2.0          # the dry are slowed (half speed) this long
const SHATTER_MULT := 3          # the next weapon hit on the frozen (Brittle: abilities too)
const WET_MULT := 1.25           # Tidebound: your blows on anything wet
const PUDDLE_SECS := 3.0         # Flood: longer and twice as wide
const PUDDLE_RADIUS := 1.4

@onready var player: CharacterBody3D = get_parent().get_parent()

var _held := {}                  # enemy -> {rest: its visual's resting height, by: {reason: true}} (the Delver's hold)
var _audio: AudioStreamPlayer


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	add_child(_audio)


## The action, from abilities.gd: `aim` is the arc row's captured aim ({at, dir, press_id}) or empty (keys).
func cast(ability: String, aim: Dictionary = {}) -> void:
	match ability:
		"drown":
			drown(aim)
		"tempest":
			tempest(aim)
		"rime_wave":
			rime_wave(aim)


# --- Drown --------------------------------------------------------------------------------------

## The foe Drown takes: the one nearest the aimed point (the arc row's ring), or with no aim the nearest ahead.
func drown_target(aim: Dictionary) -> Node3D:
	var here := player.global_position
	var at: Vector3 = aim.get("at", here + _facing() * 6.0)
	var pick := DROWN_PICK if aim.has("at") else DROWN_REACH
	var best: Node3D = null
	var best_d := INF
	for e in foes():
		var n := e as Node3D
		if n.global_position.distance_to(here) > DROWN_REACH or _held.has(n):
			continue
		var d := _flat(n.global_position, at)
		if d < pick and d < best_d:
			best = n
			best_d = d
	return best


## The person Drown takes instead, if one stands nearer the aimed point than any foe: {id, at} or {}.
func drown_person(aim: Dictionary, foe: Node3D) -> Dictionary:
	var at: Vector3 = aim.get("at", player.global_position + _facing() * 6.0)
	if player.global_position.distance_to(at) > DROWN_REACH:
		return {}
	var rows := WaterPeople.reached(get_tree(), player, at, DROWN_PICK if aim.has("at") else 6.0, Vector3.ZERO, 0.35, true)
	if rows.is_empty():
		return {}
	var row: Dictionary = rows[0]
	if foe != null and _flat(foe.global_position, at) <= _flat(row.at, at):
		return {}
	return row


func drown(aim: Dictionary) -> void:
	var foe := drown_target(aim)
	var held := drown_person(aim, foe)
	if not held.is_empty():
		_drown_person(held, aim)
		return
	_face(foe.global_position if foe else aim.get("at", player.global_position + _facing()))
	player.visual.play_action("Spell_Simple_Shoot", 1.2)
	_play("cast", 0.8, -4.0)
	if foe == null:
		WaterFX.splash(player.get_parent(), aim.get("at", player.global_position + _facing() * 4.0), 1.5, 24)
		get_tree().call_group("hud", "hint", "No one there to drown")
		Classes.start_cooldown("drown", 1.0)
		return
	var hold := DROWN_HOLD + (2.0 if Classes.has_talent("long_hold") else 0.0)
	Wet.mark(foe)
	_hold(foe, "drown")
	var vis: Node3D = foe.visual
	var rest: float = _held[foe].rest
	var lift := vis.create_tween()
	lift.tween_property(vis, "position:y", rest + DROWN_LIFT, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var sphere := WaterFX.sphere(foe, Vector3(0, DROWN_LIFT + 0.9, 0), 1.15)
	_play("splash", 0.7, -2.0)
	var t := 0.0
	var tick := DROWN_TICK
	var full := true
	while t < hold:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if not is_instance_valid(foe) or not foe.is_alive():
			full = false
			break
		Wet.mark(foe)                                    # soaked the whole time, so the clock starts at the slam
		vis.position.y = rest + DROWN_LIFT + sin(t * 3.1) * 0.12
		vis.rotation.z = sin(t * 13.0) * 0.22 * (1.0 - t / hold)      # thrashing, weaker as the air runs out
		tick -= dt
		if tick <= 0.0 and t > 0.5:
			tick = DROWN_TICK
			foe.take_burn(maxi(1, roundi(Gear.hit_damage(DROWN_TRICKLE)[0] * _brittle(foe))))
			if foe.is_alive():
				WaterFX.bubble_burst(sphere)
	if is_instance_valid(sphere):
		WaterFX.burst_sphere(sphere)
	if not is_instance_valid(foe):
		return
	vis.rotation.z = 0.0
	var fall := vis.create_tween()
	fall.tween_property(vis, "position:y", rest, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await fall.finished
	if not is_instance_valid(foe):
		return
	_release(foe, "drown")
	_slam(foe, full)


## The water lets go: the foe is slammed down, those near are soaked and knocked back.
func _slam(foe: Node3D, full: bool) -> void:
	var at := foe.global_position
	var riptide := Classes.has_talent("riptide")
	var radius := SLAM_SPLASH * (1.5 if riptide else 1.0)
	WaterFX.splash(player.get_parent(), at, radius, 56)
	WaterFX.ripple(player.get_parent(), at, radius)
	_play("thud", 0.55, 2.0)
	_play("splash", 0.9, 0.0)
	get_tree().call_group("camera_rig", "shake", 0.22)
	if foe.is_alive():
		var hp: Variant = foe.get("health")
		var mx: Variant = foe.get("max_health")
		var weak: bool = hp != null and mx != null and float(hp) <= float(mx) * DROWNED_AT
		if full and Classes.has_talent("drowned") and weak:
			FloatText.spawn(get_tree(), at + Vector3(0, 2.0, 0), "Drowned", Color(0.6, 0.85, 1.0), true)
			foe.take_hit(player.global_position, maxi(int(hp), 1) * 3, 3.0)
		else:
			var dmg := maxi(1, roundi(Gear.hit_damage(SLAM_POWER)[0] * _brittle(foe)))
			foe.take_hit(foe.global_position + (player.global_position - foe.global_position).normalized(), dmg, 3.0 if riptide else 2.2)
			FloatText.spawn(get_tree(), at + Vector3(0, 1.8, 0), str(dmg) + "!", Color(0.55, 0.85, 1.0), true)
	for e in foes():
		if (e as Node3D).global_position.distance_to(at) < radius:
			Wet.mark(e)
			if e != foe:
				_toss(e, 0.6)


func _drown_person(row: Dictionary, aim: Dictionary) -> void:
	var at: Vector3 = row.at
	_face(at)
	player.visual.play_action("Spell_Simple_Shoot", 1.2)
	_play("cast", 0.8, -4.0)
	var press := str(aim.get("press_id", "drown:%d" % Time.get_ticks_usec()))
	var hold := DROWN_HOLD + (2.0 if Classes.has_talent("long_hold") else 0.0)
	var r := WaterPeople.hold(get_tree(), player, int(row.id), at, hold, Classes.has_talent("drowned"), press)
	last_person = r
	if not r.get("accepted", false):
		WaterFX.splash(player.get_parent(), at, 1.5, 24)
		get_tree().call_group("hud", "hint", "The water slips off them")
		Classes.start_cooldown("drown", 1.0)
		return
	_play("splash", 0.7, -2.0)
	await get_tree().create_timer(hold + 0.15).timeout
	if not is_instance_valid(player):
		return
	var radius := SLAM_SPLASH * (1.5 if Classes.has_talent("riptide") else 1.0)
	WaterFX.splash(player.get_parent(), at, radius, 56)
	WaterFX.ripple(player.get_parent(), at, radius)
	_play("thud", 0.55, 2.0)
	for e in foes():
		if (e as Node3D).global_position.distance_to(at) < radius:
			Wet.mark(e)
	WaterPeople.wet(get_tree(), player, at, radius, "tide", press + ":spray")


var last_person := {}            # the last act on a person (the probe reads the door's answer)


# --- Tempest ------------------------------------------------------------------------------------

var storm: Node3D                # the cloud while it lasts (one at a time: a new one replaces it)
var storm_at := Vector3.ZERO
var bolts := 0                   # strikes this storm (the probe reads it)
var struck: Array[Node] = []     # who the bolts hit this storm, in order (chains included)
var chains := 0


func tempest(aim: Dictionary) -> void:
	var root := player.get_parent()
	if is_instance_valid(storm):
		WaterFX.end_cloud(storm)
	var radius := tempest_radius()
	storm_at = player.global_position
	storm = WaterFX.cloud(root, storm_at, radius)
	bolts = 0
	chains = 0
	struck.clear()
	var mine := storm
	var press := str(aim.get("press_id", "storm:%d" % Time.get_ticks_usec()))
	player.visual.play_action("Spell_Simple_Shoot", 0.9)
	_play("cast", 0.6, -2.0)
	get_tree().call_group("camera_rig", "shake", 0.08)
	var t := 0.0
	var rain := 1.0                  # the first bolt (0.6 s) falls before the rain has soaked anyone: it seeks the already wet
	var bolt := 0.6
	var things := 0.2
	var spring := SPRING_EVERY
	var n := 0
	while t < TEMPEST_SECS and is_instance_valid(mine) and storm == mine:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if Classes.has_talent("eye_of_storm"):
			storm_at = storm_at.lerp(player.global_position, clampf(4.0 * dt, 0.0, 1.0))
			mine.global_position = storm_at
		rain -= dt
		bolt -= dt
		things -= dt
		spring -= dt
		if rain <= 0.0:
			rain = RAIN_TICK
			for e in under_cloud():
				Wet.mark(e)
				e.take_burn(1)
		if bolt <= 0.0:
			bolt = BOLT_EVERY
			_lightning()
		if things <= 0.0:
			things = THINGS_EVERY
			n += 1
			rain_on_things("%s:%d" % [press, n])
			WaterPeople.rain(get_tree(), player, storm_at, radius, "%s:r%d" % [press, n])
			WaterPeople.wet(get_tree(), player, storm_at, radius, "rain", "%s:w%d" % [press, n])
		if spring <= 0.0:
			spring = SPRING_EVERY
			if Classes.has_talent("spring") and _flat(player.global_position, storm_at) < radius:
				player.heal(1)
	if is_instance_valid(mine):
		WaterFX.end_cloud(mine)
	if storm == mine:
		storm = null


## His enemies under the cloud.
func under_cloud() -> Array:
	var r := tempest_radius()
	return foes().filter(func(e: Node) -> bool: return _flat((e as Node3D).global_position, storm_at) < r)


## A bolt from the cloud: a wet foe first, then any under it; it can leap once to a wet foe close by.
## Never the caster: it only ever picks from his enemies.
func _lightning() -> void:
	var under := under_cloud()
	if under.is_empty():
		_bolt_person()
		return
	var wet := under.filter(func(e: Node) -> bool: return Wet.is_wet(e))
	var pool := wet if not wet.is_empty() else under
	var foe: Node3D = pool[randi() % pool.size()]
	var top := Vector3(foe.global_position.x, storm_at.y + 6.0, foe.global_position.z)
	_bolt_hit(foe, top, 1.0)
	var best: Node3D = null
	var best_d := CHAIN_REACH
	for e in foes():
		var d := (e as Node3D).global_position.distance_to(foe.global_position)
		if e != foe and Wet.is_wet(e) and d < best_d:
			best = e
			best_d = d
	if best and Wet.is_wet(foe):
		chains += 1
		_bolt_hit(best, foe.global_position + Vector3(0, 1.0, 0), 0.5)


func _bolt_hit(foe: Node3D, from: Vector3, share: float) -> void:
	bolts += 1
	struck.append(foe)
	var at := foe.global_position
	WaterFX.bolt(player.get_parent(), from, at + Vector3(0, 0.9, 0))
	var power := BOLT_POWER * share * (1.5 if Classes.has_talent("conductive") and Wet.is_wet(foe) else 1.0)
	var dmg := maxi(1, roundi(Gear.hit_damage(power)[0] * _brittle(foe)))
	foe.take_hit(at + (player.global_position - at).normalized(), dmg, 1.8)
	FloatText.spawn(get_tree(), at + Vector3(0, 2.0, 0), str(dmg) + "!", Color(0.85, 0.9, 1.0), share >= 1.0)
	_play("thud", 1.6, 1.0)
	get_tree().call_group("camera_rig", "shake", 0.12 * share)


## With no foe under the cloud, lightning strikes only a villager who is fighting you (squared up: the one
## hostile-to-you reading the people system has). Everyone else is a bystander: the bolt falls on open ground,
## so putting out a village fire with the rain never turns into a crime (desk, 6 Oct; Hilmi: "lighting strikes enemies").
func _bolt_person() -> void:
	var rows := WaterPeople.reached(get_tree(), player, storm_at, tempest_radius(), Vector3.ZERO, 0.35, true).filter(func(r: Dictionary) -> bool:
		return WaterPeople.fighting_you(get_tree(), int(r.id)) and WaterPeople.can_bolt(player, r.at))
	if rows.is_empty():
		_bolt_ground()
		return
	var wet := rows.filter(func(r: Dictionary) -> bool: return WaterPeople.is_wet(int(r.id)))
	var pool := wet if not wet.is_empty() else rows
	var row: Dictionary = pool[randi() % pool.size()]
	var at: Vector3 = row.at
	bolts += 1
	WaterFX.bolt(player.get_parent(), Vector3(at.x, storm_at.y + 6.0, at.z), at + Vector3(0, 0.9, 0))
	_play("thud", 1.6, 1.0)
	get_tree().call_group("camera_rig", "shake", 0.12)
	last_person = WaterPeople.bolt(get_tree(), player, int(row.id), at, "bolt:%d:%d" % [int(row.id), Time.get_ticks_usec()])


## A bolt on open ground under the cloud, clear of everyone (no act: nobody is struck).
func _bolt_ground() -> void:
	var r := tempest_radius()
	var people := WaterPeople.reached(get_tree(), player, storm_at, r + 2.0)
	for _try in 8:
		var a := randf() * TAU
		var at := storm_at + Vector3(cos(a), 0, sin(a)) * randf_range(r * 0.3, r * 0.9)
		at.y = player.global_position.y
		if at.distance_to(player.global_position) < 2.5 or people.any(func(p: Dictionary) -> bool: return _flat(p.at, at) < 2.5):
			continue
		ground_bolts += 1
		WaterFX.bolt(player.get_parent(), at + Vector3(0, 6.0, 0), at)
		_play("thud", 1.6, -2.0)
		return


var ground_bolts := 0            # bolts that fell on open ground this session (the probe reads it)


## The rain is the world's rain: the things under the cloud (his fences, benches, crates) are soaked and put out
## through the checked door (thing_actions.rain, one transaction, one journal line). Nothing to do costs nothing.
func rain_on_things(deed: String) -> Dictionary:
	var v = VillageSession.village
	var res := Contact.registry(get_tree())
	if res == null or v == null or v.get("thing_facts") == null or not VillageSession.active or VillageSession.background or Controls.locked:
		return {}
	var ids := []
	for row: Dictionary in Things.measure(get_tree(), storm_at, tempest_radius()):
		var id := str(row.thing)
		var soaked: Dictionary = ThingFacts.get_fact(v, id, "soaked")
		if ThingActions.has(v, id, "burning") or soaked.is_empty() or int(soaked.get("until_tick", 0)) < People.tick(v) + 5000:
			ids.append(id)
	if ids.is_empty():
		return {}
	var carriers := Things.ids(get_tree())
	return res.people_bridge.accept(func(candidate) -> Dictionary:
		ThingActions.follow(candidate, ThingFacts.advance(candidate), carriers)
		var soaked := ThingActions.rain(candidate, Contact.thing_roots, ids, "rain:" + deed)
		return {"accepted": not soaked.is_empty(), "reason": "nothing to soak", "soaked": soaked})


# --- Rime Wave ----------------------------------------------------------------------------------

var _iced := {}                  # enemy -> its ice shell, while frozen
var _chilled := {}               # enemy -> true, while slowed


## Who the wave reaches: in the cone ahead (or all round, Ring of Rime), nearest first.
func rime_targets(forward: Vector3) -> Array:
	var here := player.global_position
	var ring := Classes.has_talent("ring_of_rime")
	var cos_half := cos(deg_to_rad(RIME_ANGLE * 0.5))
	var out := foes().filter(func(e: Node) -> bool:
		var to := (e as Node3D).global_position - here
		to.y = 0.0
		return to.length() < RIME_REACH and (ring or to.length() < 0.8 or to.normalized().dot(forward) >= cos_half))
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(here) < b.global_position.distance_squared_to(here))
	return out


func rime_wave(aim: Dictionary) -> void:
	var forward: Vector3 = aim.get("dir", _facing())
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else _facing()
	_face(player.global_position + forward)
	var ring := Classes.has_talent("ring_of_rime")
	player.visual.play_action("Spell_Simple_Shoot", 1.4)
	WaterFX.frost(player.get_parent(), player.global_position, forward, RIME_REACH, 360.0 if ring else RIME_ANGLE)
	_play("splash", 1.7, -4.0)
	get_tree().call_group("camera_rig", "shake", 0.1)
	for e in rime_targets(forward):
		var delay := player.global_position.distance_to((e as Node3D).global_position) / RIME_SPEED
		get_tree().create_timer(delay).timeout.connect(_rime_reach.bind(e))
	var press := str(aim.get("press_id", "rime:%d" % Time.get_ticks_usec()))
	var cone := Vector3.ZERO if ring else forward
	for row: Dictionary in WaterPeople.reached(get_tree(), player, player.global_position, RIME_REACH, cone, cos(deg_to_rad(RIME_ANGLE * 0.5)), true):
		var delay := player.global_position.distance_to(row.at) / RIME_SPEED
		get_tree().create_timer(delay).timeout.connect(_rime_person.bind(row, press))


## The wave reaches one foe: the wet freeze, the dry are chilled.
func _rime_reach(e: Variant) -> void:           # (untyped: the foe may be gone by the time the wave arrives)
	if not is_instance_valid(e) or not e.is_alive():
		return
	var dmg := maxi(1, roundi(Gear.hit_damage(RIME_POWER)[0] * _brittle(e)))
	if Wet.is_wet(e):
		e.take_burn(dmg)
		if e.is_alive():
			freeze(e, FROZEN_SECS * (2.0 if Classes.has_talent("deep_freeze") else 1.0))
	else:
		e.take_burn(dmg)
		if e.is_alive():
			Wet.chill(e, CHILL_SECS)
			_chilled[e] = true
			FloatText.spawn(get_tree(), e.global_position + Vector3(0, 2.1, 0), "Chilled", Color(0.7, 0.9, 1.0))


## The wave reaches a person: the wet freeze (a checked act; the ice is the frozen element), the dry are chilled.
func _rime_person(row: Dictionary, press: String) -> void:
	if WaterPeople.is_wet(int(row.id)):
		var secs := FROZEN_SECS * (2.0 if Classes.has_talent("deep_freeze") else 1.0)
		last_person = WaterPeople.freeze(get_tree(), player, int(row.id), secs, "%s:%d" % [press, int(row.id)])
	else:
		FloatText.spawn(get_tree(), (row.at as Vector3) + Vector3(0, 2.1, 0), "Chilled", Color(0.7, 0.9, 1.0))


## Stopped in ice: its brain and its pose held, a shell of ice round it.
func freeze(e: Node3D, seconds: float) -> void:
	Wet.freeze(e, seconds)
	_hold(e, "ice")
	(e.visual as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
	if not _iced.has(e) or not is_instance_valid(_iced[e]):
		_iced[e] = WaterFX.ice(e)
	FloatText.spawn(get_tree(), e.global_position + Vector3(0, 2.2, 0), "Frozen", Color(0.6, 0.9, 1.0), true)


## The ice lets go: cracked by a blow (`shattered`), or its time ran out.
func thaw(e: Variant, shattered: bool) -> void:  # (untyped: called deferred, the foe may be gone)
	if not is_instance_valid(e):
		for k: Variant in _iced.keys():
			if not is_instance_valid(k):
				if is_instance_valid(_iced[k]):
					_iced[k].queue_free()
				_iced.erase(k)
		return
	Wet.thaw(e)
	if _iced.has(e):
		var shell: Node3D = _iced[e]
		_iced.erase(e)
		if is_instance_valid(shell):
			if shattered:
				WaterFX.shatter(player.get_parent(), shell.global_position)
			shell.queue_free()
	if is_instance_valid(e):
		(e.visual as Node3D).process_mode = Node.PROCESS_MODE_INHERIT
		_release(e, "ice")
	if shattered:
		_play("thud", 1.3, 0.0)
		get_tree().call_group("camera_rig", "shake", 0.14)


func is_iced(e: Node) -> bool:
	return _iced.has(e)


func _physics_process(delta: float) -> void:
	Wet.advance(delta)
	for e: Variant in _iced.keys():
		if not is_instance_valid(e):
			_iced.erase(e)
		elif not Wet.is_frozen(e) or not e.is_alive():
			thaw(e, false)
	for e: Variant in _chilled.keys():         # the chilled move at half speed: their brain runs every other step
		if not is_instance_valid(e):
			_chilled.erase(e)
		elif _held.has(e):
			continue
		elif not Wet.is_chilled(e) or not e.is_alive():
			_chilled.erase(e)
			e.set_physics_process(true)
		else:
			e.set_physics_process(Engine.get_physics_frames() % 2 == 0)


# --- Tidebound ----------------------------------------------------------------------------------

## The Tidebound roll: a puddle where you set off that soaks whoever steps in it.
func tide_roll(_time: float) -> void:
	var flood := Classes.has_talent("flood")
	var at := player.global_position
	var radius := PUDDLE_RADIUS * (2.0 if flood else 1.0)
	var secs := PUDDLE_SECS * (1.67 if flood else 1.0)
	var pool := WaterFX.puddle(player.get_parent(), at, radius, secs)
	WaterFX.splash(player.get_parent(), at, 1.0, 14)
	var press := "puddle:%d" % Time.get_ticks_usec()
	WaterPeople.wet(get_tree(), player, at, radius, "tide", press)
	var t := 0.0
	while t < secs and is_instance_valid(pool):
		for e in foes():
			if _flat((e as Node3D).global_position, at) < radius:
				Wet.mark(e)
		await get_tree().create_timer(0.25).timeout
		t += 0.25


## Your blow, Tidecaller-style (abilities.gd passive_strike): the frozen take x3 and their ice cracks; the wet
## take more (Tidebound). `hit` is [damage, critical].
static func strike(enemy: Node, hit: Array, from: Node3D) -> Array:
	var tide: Tidecaller = from.get("abilities").tidecaller if from != null and from.get("abilities") != null else null
	if Wet.is_frozen(enemy):
		if tide:
			tide.thaw(enemy, true)
		if enemy.has_method("parried"):                 # cracked out of the ice it reels (his own stagger), so it cannot block this blow
			enemy.parried(0.6)
		FloatText.spawn(enemy.get_tree(), (enemy as Node3D).global_position + Vector3(0, 2.4, 0), "Shatter!", Color(0.75, 0.95, 1.0), true)
		return [hit[0] * SHATTER_MULT, hit[1]]
	if Wet.is_wet(enemy):
		return [maxi(hit[0] + 1, roundi(hit[0] * WET_MULT)), hit[1]]
	return hit


# --- Shared ---------------------------------------------------------------------------------------

## His enemies (not the village's bodies, which go through the checked door).
func foes() -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool:
		return not e.get_meta("crowd_ignore", false) and e.is_alive())


## Brittle: the frozen take x3 from abilities too (and the ice cracks).
func _brittle(e: Node) -> float:
	if Classes.has_talent("brittle") and Wet.is_frozen(e):
		thaw.call_deferred(e, true)
		return float(SHATTER_MULT)
	return 1.0


## Hold a foe still (the Delver's pattern: its own brain paused, its body in our hands). Reasons stack.
func _hold(e: Node3D, why: String) -> void:
	if not _held.has(e):
		_held[e] = {"rest": (e.visual as Node3D).position.y, "by": {}}
		e.set_physics_process(false)
	_held[e].by[why] = true


func _release(e: Node3D, why: String) -> void:
	if not _held.has(e):
		return
	_held[e].by.erase(why)
	if _held[e].by.is_empty():
		var rest: float = _held[e].rest
		_held.erase(e)
		if is_instance_valid(e):
			(e.visual as Node3D).position.y = rest
			e.set_physics_process(true)


func is_held(e: Node) -> bool:
	return _held.has(e)


func _toss(e: Node, height: float) -> void:
	if not is_instance_valid(e) or not e.is_alive() or _held.has(e):
		return
	var vis: Node3D = e.visual
	var rest := vis.position.y
	var t := vis.create_tween()
	t.tween_property(vis, "position:y", rest + height, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(vis, "position:y", rest, 0.26).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _facing() -> Vector3:
	return Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))


func _face(at: Vector3) -> void:
	var to := at - player.global_position
	if Vector2(to.x, to.z).length() > 0.1:
		player.visual.rotation.y = atan2(to.x, to.z)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _play(id: String, pitch: float, db: float) -> void:
	_audio.stream = SOUNDS[id]
	_audio.pitch_scale = pitch
	_audio.volume_db = db
	_audio.play()


## What the arc row draws while an ability is aimed (Body 4's generic branch):
## {shape: "ring"|"cone", at, radius, angle_deg, forward}. `aim_point` is where the finger points.
func preview(ability: String, aim_point: Vector3) -> Dictionary:
	var forward := aim_point - player.global_position
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	match ability:
		"drown":
			return {"shape": "ring", "at": aim_point, "radius": DROWN_RING, "angle_deg": 360.0, "forward": forward, "reach": DROWN_REACH}
		"tempest":
			return {"shape": "ring", "at": player.global_position, "radius": tempest_radius(), "angle_deg": 360.0, "forward": forward}
		"rime_wave":
			var ring := Classes.has_talent("ring_of_rime")
			return {"shape": "ring" if ring else "cone", "at": player.global_position, "radius": RIME_REACH,
				"angle_deg": 360.0 if ring else RIME_ANGLE, "forward": forward}
	return {}


func tempest_radius() -> float:
	return TEMPEST_RADIUS * (1.33 if Classes.has_talent("downpour") else 1.0)

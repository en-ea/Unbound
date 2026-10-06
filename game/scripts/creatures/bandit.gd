class_name Bandit
extends CharacterBody3D
## A Red Hand bandit: a person on the UAL rig, dressed from our character parts. Kinds (Balance.BANDITS):
## "cutthroat" (sword), "shield" (sword and shield: blocks anything from the front until a heavy blow
## breaks the guard, so go round it), "archer" (keeps its distance and shoots) and "leader" (Varek, a
## duelist who parries a button-masher). Unaware, they stand at a post or walk a beat. They notice you by
## sight (a cone: shorter while you sneak and at night, blocked by walls) and by sound (running,
## fighting); a "?" fills over their head, then "!" and a shout that brings the camp. In a fight they
## circle, take turns (the camp hands out attack turns), wind up with the glint (always the same beat
## before a blow lands: parry or roll then), swing combos, block, and punish mashing. From behind, an
## unaware bandit can be taken down in one blow. Dead ones lie where they fell, and a bandit who sees a
## body comes to look.

enum State { POST, SUSPICIOUS, SEARCH, CIRCLE, WINDUP, ATTACK, RECOVER, AIM, STAGGER, HURT, DEAD }

const GRAVITY := 20.0
const GLINT_LEAD := 0.45        # the glint comes this long before a blow lands
const IMPACT := 0.24            # into a swing, when it lands
const SWING_GAP := 0.6          # a combo's next swing starts this long after the last
const REACH := 2.0
const SOUNDS := {
	"spotted": preload("res://assets/sounds/spotted.wav"),
	"block": preload("res://assets/sounds/block.wav"),
	"swing": preload("res://assets/sounds/swing.wav"),
	"bow": preload("res://assets/sounds/bow_shot.wav"),
	"hit": preload("res://assets/sounds/crit.wav"),
}
const DROP := preload("res://scripts/world/drop.gd")
const TOOL_DROP := preload("res://scripts/world/tool_drop.gd")
const ARROW := preload("res://scripts/creatures/arrow.gd")

var kind := "cutthroat"
var camp: Node
var player: Node3D
var day_night: Node
var post := Vector3.ZERO
var post_turn := 0.0
var beat: Array[Vector3] = []
var idle_pose := ""
var look: CharacterLook
var body_scale := 1.0

var health := 10
var max_health := 10
var state := State.POST
var aware := 0.0
var alerted := false
var visual: CharacterVisual

var _stats: Dictionary
var _t := 0.0
var _beat_i := 0
var _last_seen := Vector3.ZERO
var _side := 1.0
var _combo_left := 0
var _swing_i := 0
var _swing_hit := false
var _windup := 0.6
var _has_turn := false
var _rest_until := 0.0
var _blocked_row := 0
var _hits_row := 0.0
var _stagger_for := 0.0
var _push := Vector3.ZERO
var _lost_for := 0.0
var _phase2 := false
var _overlay: EnemyOverlay
var _audio: AudioStreamPlayer3D
var _lunge := false
var _shadow_check := 0.0
var _shadows := true


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("bandit")
	_stats = Balance.BANDITS[kind]
	max_health = _stats["hp"]
	health = max_health
	collision_layer = 1
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	visual = CharacterVisual.new()
	visual.merge = true
	visual.hero_look = look
	visual.is_player_look = false
	add_child(visual)
	visual.scale = Vector3.ONE * body_scale
	visual.rotation.y = post_turn
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 8.0
	add_child(_audio)
	_overlay = EnemyOverlay.new()
	_overlay.position = Vector3(0, 1.95 * body_scale, 0)
	add_child(_overlay)
	_arm.call_deferred()
	_enter(State.POST)


## Weapons in hand once the body is built: an iron sword (not for archers), a shield or a bow on the left.
func _arm() -> void:
	if kind != "archer":
		visual.show_tool("sword")
		visual.tint_tool("sword", Color(0.36, 0.36, 0.4) if kind != "leader" else Color(0.2, 0.18, 0.2))
	if kind == "shield":
		visual.hold_prop("bandit_shield", Vector3(0, 90, -90), Vector3(0.0, 0.06, 0.04), "hand_l")
	elif kind == "archer":
		visual.hold_prop("bandit_bow", Vector3(90, 0, 0), Vector3(0.0, 0.08, 0.0), "hand_l")
	visual.idle_anim = idle_pose
	visual.loop_animation("Sword_Idle")


func is_alive() -> bool:
	return state != State.DEAD


func is_engaged() -> bool:
	return alerted and state != State.DEAD


## Awake as a boss (the music knows): the leader, once he's fighting you.
func is_awake() -> bool:
	return kind == "leader" and is_engaged()


func is_open() -> bool:
	return state == State.STAGGER


## Unaware of you, you're close behind it: one blow finishes it (the leader only reels).
func can_be_taken_down(from: Node3D) -> bool:
	if alerted or state == State.DEAD or aware > 0.85:
		return false
	var to := from.global_position - global_position
	to.y = 0.0
	if to.length() > Balance.STEALTH["takedown"]:
		return false
	return _facing().dot(to.normalized()) < -0.15


func taken_down(from: Node3D) -> void:
	if kind == "leader":
		take_hit(from.global_position, maxi(1, max_health / 2), 2.0)
		return
	health = 0
	_play("hit", 0.7)
	_die(true)


# --- the fight -------------------------------------------------------------------------------

## The player's blow. From the front a bandit may block it (a shield always does, unless a heavy blow
## breaks the guard); hits on an unaware bandit land double and wake it.
func take_hit(from: Vector3, damage := 1, push := 1.0) -> void:
	if state == State.DEAD:
		return
	var to := from - global_position
	to.y = 0.0
	var front := _facing().dot(to.normalized()) > 0.25
	var ready := alerted and state in [State.CIRCLE, State.RECOVER, State.WINDUP, State.AIM]
	if front and ready and push <= 1.0:
		var chance: float = _stats.get("block", 0.0)
		if kind == "leader":
			chance = clampf(chance + _hits_row * 0.2, 0.0, 0.9)      # mash at him and he reads you
		if randf() < chance:
			_block(to)
			return
	if kind == "shield" and front and push > 1.0 and state != State.STAGGER:
		FloatText.spawn(get_tree(), global_position + Vector3(0, 2.1, 0), "Guard broken!", Color(1.0, 0.7, 0.3))
		_stagger(1.5)
		return
	if not alerted:
		damage *= 2
		_alert(true)
	health -= damage
	_hits_row += 1.0
	_overlay.show_health(float(health) / max_health, max_health / 3)
	visual.flash()
	_push = -to.normalized() * (2.0 if push <= 1.0 else 5.0)
	if health <= 0:
		_die(false)
		return
	if kind == "leader" and not _phase2 and health * 2 <= max_health:
		_phase2 = true
		FloatText.spawn(get_tree(), global_position + Vector3(0, 2.4, 0), "Varek is enraged!", Color(1.0, 0.3, 0.2), true)
		if camp:
			camp.raise_alarm(global_position, true)
		_stagger(0.6)
		return
	if push > 1.0 or (state != State.ATTACK and state != State.WINDUP):
		_enter(State.HURT)
		visual.play_action("Hit_Chest", 1.3)


## Fire damage (a Pyromancer's flames): no stagger, and it wakes them.
func take_burn(damage: int) -> void:
	if state == State.DEAD:
		return
	if not alerted:
		_alert(true)
	health -= damage
	visual.flash()
	_overlay.show_health(float(health) / max_health, max_health / 3)
	FloatText.spawn(get_tree(), global_position + Vector3(0, 1.8, 0), str(damage), Color(1.0, 0.55, 0.2))
	if health <= 0:
		_die(false)


func parried(seconds: float) -> void:
	_stagger(seconds)


func _stagger(seconds: float) -> void:
	_stagger_for = seconds
	_release_turn()
	_push = -_facing() * 3.0
	visual.play_action("Hit_Knockback", 1.0)
	_enter(State.STAGGER)


func _block(to_attacker: Vector3) -> void:
	_face_now(to_attacker)
	visual.play_action("Sword_Block", 1.6)
	_play("block", randf_range(0.95, 1.1))
	FloatText.spawn(get_tree(), global_position + Vector3(0, 2.0, 0), "Blocked", Color(0.75, 0.78, 0.85))
	_blocked_row += 1
	if _blocked_row >= 2 or kind == "leader":           # keep swinging into a guard and it strikes back
		_blocked_row = 0
		_start_windup(0.5, true)


func _die(quiet: bool) -> void:
	_release_turn()
	_enter(State.DEAD)
	Bounties.killed("bandit", self)
	collision_layer = 0
	_overlay.set_awareness(0.0, false)
	_overlay.show_health(0.0)
	visual.play_action("Death01", 1.0)
	Skills.add("combat", _stats["xp"])
	var coins: Array = _stats["coins"]
	Money.earn(randi_range(coins[0], coins[1]))
	for item in _loot():
		var drop := Node3D.new()
		drop.set_script(DROP)
		get_parent().add_child(drop)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(0.8, 1.6)
		drop.launch(item, global_position + Vector3(0, 0.9, 0), dir + Vector3(0, randf_range(3.5, 4.5), 0), global_position.y, player)
	if randf() < (0.6 if kind == "leader" else 0.12):
		var found := Gear.roll_found("elite" if kind == "leader" else "enemy")
		TOOL_DROP.spawn(get_parent(), found[0], found[1], global_position, player)
	if camp:
		camp.bandit_died(self, quiet)


func _loot() -> Array[String]:
	var items: Array[String] = []
	if randf() < 0.7:
		items.append("red_hand")
	if randf() < 0.3:
		items.append("roast_meat")
	return items


# --- each frame ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_hits_row = maxf(_hits_row - delta * 0.8, 0.0)
	if state == State.DEAD:
		velocity = Vector3(0, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, 0)
		move_and_slide()
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var toward := to_player / maxf(dist, 0.01)
	var want := Vector3.ZERO
	var face := Vector3.ZERO
	var speed: float = _stats["speed"] * (1.2 if _phase2 else 1.0)
	if not alerted:
		_sense(delta, dist, toward)
	elif player.is_down() or _home_dist() > Balance.STEALTH["give_up"]:
		_lost_for += delta
		if _lost_for > 5.0:
			_calm_down()
	else:
		_lost_for = 0.0
	match state:
		State.POST:
			if beat.size() > 1:
				var goal := beat[_beat_i]
				var d := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
				if d.length() < 0.5:
					if _t > 3.0:
						_beat_i = (_beat_i + 1) % beat.size()
						_t = 0.0
				else:
					want = d.normalized() * 1.1
			else:
				var d := Vector3(post.x - global_position.x, 0, post.z - global_position.z)
				if d.length() > 0.5:
					want = d.normalized() * 1.2
				else:
					visual.rotation.y = lerp_angle(visual.rotation.y, post_turn, delta * 3.0)
		State.SUSPICIOUS:
			face = _flat(_last_seen - global_position).normalized()
			if _t > 1.2:
				_enter(State.SEARCH)
		State.SEARCH:
			var d := _flat(_last_seen - global_position)
			if d.length() > 1.2 and _t < 8.0:
				want = d.normalized() * 1.6
			elif _t > 3.5:
				aware = 0.0
				_overlay.set_awareness(0.0, false)
				_enter(State.POST)
		State.CIRCLE:
			if kind == "archer":
				var rng: Array = _stats["range"]
				if dist < rng[0]:
					want = -toward * speed * 0.9
				elif dist > rng[1]:
					want = toward * speed * 0.8
				else:
					want = toward.cross(Vector3.UP) * _side * 1.4
				face = toward
				if _now() > _rest_until and dist < rng[1] + 2.0 and _t > 0.6:
					_enter(State.AIM)
			else:
				var r: float = _stats["circle"]
				var around := toward.cross(Vector3.UP) * _side
				var behind := _behind_player_side()
				if behind != 0.0:
					_side = behind
				want = (around * 0.8 + toward * clampf((dist - r) * 0.8, -1.0, 1.0) + _spread()).normalized() * speed * 0.6
				face = toward
				if _now() > _rest_until and dist < r + 1.5 and (camp == null or camp.request_turn(self)):
					_has_turn = true
					_start_windup(randf_range(0.5, 0.9) * (0.7 if _phase2 else 1.0), false)
				elif kind == "leader" and _now() > _rest_until and dist > 4.5 and dist < 8.0 and randf() < delta * 0.6:
					_has_turn = true
					_start_windup(0.75, false, true)            # a dashing lunge from range
				elif is_on_wall():
					_side = -_side
		State.WINDUP:
			face = toward
			if _lunge and dist > 1.8:
				want = Vector3.ZERO
			visual.set_warn(clampf(_t / _windup, 0.0, 1.0))
			var glint_at := _windup - (GLINT_LEAD - IMPACT)
			if _t < glint_at and _t + delta >= glint_at:
				_overlay.glint()
			if _t >= _windup:
				_swing_i = 0
				_combo_left = 1 if _lunge else randi_range(_stats["combo"][0], _stats["combo"][1])
				_start_swing(toward)
				_enter(State.ATTACK)
		State.ATTACK:
			var reach := REACH + (0.3 if kind == "leader" else 0.0)
			if _lunge and _t < IMPACT:
				want = toward * 11.0
			elif _t < IMPACT * 0.8:
				face = toward
			if not _swing_hit and _t >= IMPACT:
				_swing_hit = true
				if dist < reach + (1.2 if _lunge else 0.0) and _facing().dot(toward) > 0.3:
					var result: String = player.receive_attack(self, _stats["damage"], toward * (7.0 if _lunge else 4.5))
					if result == "parry":
						return
			if _combo_left > 1 and _t >= SWING_GAP - (GLINT_LEAD - IMPACT) and _t - delta < SWING_GAP - (GLINT_LEAD - IMPACT):
				_overlay.glint()
			if _t >= SWING_GAP:
				_combo_left -= 1
				if _combo_left > 0:
					_swing_i += 1
					_start_swing(toward)
					_t = 0.0
				else:
					_release_turn()
					_rest_until = _now() + randf_range(_stats["rest"][0], _stats["rest"][1]) * (0.6 if _phase2 else 1.0)
					_enter(State.RECOVER)
		State.RECOVER:
			face = toward
			want = -toward * 1.2
			if _t > 0.7:
				_side = -_side if randf() < 0.5 else _side
				_enter(State.CIRCLE)
		State.AIM:
			face = toward
			var aim: float = _stats["aim"]
			if _t < aim - GLINT_LEAD and _t + delta >= aim - GLINT_LEAD:
				_overlay.glint()
			if dist < 3.0:
				_rest_until = _now() + 0.5
				_enter(State.CIRCLE)                          # too close: back off first
			elif _t >= aim:
				_shoot()
				_rest_until = _now() + randf_range(_stats["rest"][0], _stats["rest"][1])
				_enter(State.RECOVER)
		State.STAGGER:
			if _t > _stagger_for:
				_enter(State.CIRCLE)
		State.HURT:
			if _t > 0.35:
				_enter(State.CIRCLE if alerted else State.SEARCH)
	want = preload("res://scripts/studio/creatures/steer_around.gd").steer(self, want, delta, state == State.ATTACK)   # studio: round structures, never in a blow's step (note 233349)
	var flat := Vector3(velocity.x, 0, velocity.z).lerp(want, clampf(10.0 * delta, 0.0, 1.0)) + _push
	_push = _push.lerp(Vector3.ZERO, clampf(8.0 * delta, 0.0, 1.0))
	velocity = Vector3(flat.x, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, flat.z)
	move_and_slide()
	if face != Vector3.ZERO:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(face.x, face.z), clampf(delta * (6.0 if kind == "shield" else 9.0), 0.0, 1.0))
	elif want.length() > 0.2:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(want.x, want.z), clampf(delta * 8.0, 0.0, 1.0))
	visual.play_motion(Vector2(velocity.x, velocity.z).length())
	_shadow_check -= delta
	if _shadow_check <= 0.0:                 # only bandits near you cast shadows (they cost a lot on the phone)
		_shadow_check = 0.5
		var near := dist < 14.0
		if near != _shadows:
			_shadows = near
			for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- noticing you ------------------------------------------------------------------------------

func _sense(delta: float, dist: float, toward: Vector3) -> void:
	var st: Dictionary = Balance.STEALTH
	var seen := _sight(dist, toward)
	var heard: float = player.noise() if player.has_method("noise") else 0.0
	if seen > 0.0:
		aware += delta * st["notice"] * seen
		_last_seen = player.global_position
	elif heard > 0.0 and dist < heard:
		aware = maxf(aware, 0.6)
		_last_seen = player.global_position
	elif camp and camp.body_seen_by(self):
		aware = maxf(aware, 0.6)
	else:
		aware = maxf(aware - delta * st["forget"], 0.0)
	if aware >= 1.0:
		_alert(true)
		return
	_overlay.set_awareness(aware, false)
	if aware > 0.45 and state == State.POST:
		_enter(State.SUSPICIOUS)


## How clearly it sees you (0 = not at all): in its view cone, within sight (less while you sneak, less
## at night), and nothing in the way. Closer is clearer; running makes you stand out.
func _sight(dist: float, toward: Vector3) -> float:
	var st: Dictionary = Balance.STEALTH
	var sneaking: bool = player.get("sneaking") == true
	var reach: float = st["sight_sneak"] if sneaking else st["sight"]
	if day_night and day_night.night > 0.5:
		reach *= st["night"]
	if dist > reach or _facing().dot(toward) < st["fov"]:
		return 0.0
	var eye := global_position + Vector3(0, 1.6 * body_scale, 0)
	var q := PhysicsRayQueryParameters3D.create(eye, player.global_position + Vector3(0, 1.0, 0))
	q.exclude = [get_rid(), (player as CollisionObject3D).get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return 0.0
	var clear := clampf(1.3 - dist / reach, 0.2, 1.0)
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	return clear * (1.6 if speed > 3.0 else 1.0)


## Spotted! It shouts (the first one plays the sting) and the camp comes.
func _alert(shout: bool) -> void:
	if alerted:
		return
	alerted = true
	aware = 1.0
	_overlay.set_awareness(1.0, true)
	_last_seen = player.global_position
	_rest_until = _now() + randf_range(0.3, 1.0)
	visual.idle_anim = "" if kind == "archer" else "Sword_Idle"
	_enter(State.CIRCLE)
	if shout and camp:
		camp.raise_alarm(global_position, false)


## Called by the camp when someone else raised the alarm.
func hear_alarm() -> void:
	if not alerted and state != State.DEAD:
		_alert(false)


func _calm_down() -> void:
	alerted = false
	aware = 0.0
	_lost_for = 0.0
	_phase2 = false
	health = max_health
	_release_turn()
	_overlay.set_awareness(0.0, false)
	visual.idle_anim = idle_pose
	_enter(State.POST)


# --- helpers ----------------------------------------------------------------------------------

func _start_windup(length: float, quick: bool, lunge := false) -> void:
	_windup = maxf(length, GLINT_LEAD - IMPACT + 0.05)
	_lunge = lunge
	if quick:
		_has_turn = true
	_enter(State.WINDUP)


func _start_swing(toward: Vector3) -> void:
	_swing_hit = false
	var anims := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]
	var anim: String = "Sword_Dash" if _lunge else anims[_swing_i % 3]
	if kind == "shield" and _swing_i == 0:
		anim = "Shield_OneShot"
	visual.play_action(anim, 1.35)
	_push = toward * (0.0 if _lunge else 2.5)
	_play("swing", randf_range(0.85, 1.0))


func _shoot() -> void:
	visual.play_action("Pistol_Shoot", 1.0)
	_play("bow", randf_range(0.95, 1.05))
	var from := global_position + Vector3(0, 1.45, 0) + _facing() * 0.5
	var target: Vector3 = player.global_position + Vector3(0, 1.0, 0) + player.velocity * 0.35
	var a := Node3D.new()
	a.set_script(ARROW)
	get_parent().add_child(a)
	a.fire(from, target, self, player, _stats["damage"])


func _release_turn() -> void:
	if _has_turn and camp:
		camp.end_turn(self)
	_has_turn = false


func _behind_player_side() -> float:
	var pf: Vector3 = Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	var from_player := _flat(global_position - player.global_position).normalized()
	if pf.dot(from_player) > 0.3:          # it's in front of you: go round the shorter way
		return 1.0 if pf.cross(from_player).y > 0.0 else -1.0
	return 0.0


func _spread() -> Vector3:
	var push := Vector3.ZERO
	for b in get_tree().get_nodes_in_group("bandit"):
		if b == self or not b.is_alive():
			continue
		var d := _flat(global_position - (b as Node3D).global_position)
		if d.length() < 2.2 and d.length() > 0.01:
			push += d.normalized() * (2.2 - d.length())
	return push * 0.6


func _facing() -> Vector3:
	return Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))


func _face_now(dir: Vector3) -> void:
	if dir.length() > 0.01:
		visual.rotation.y = atan2(dir.x, dir.z)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _home_dist() -> float:
	return _flat(post - global_position).length()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _enter(s: State) -> void:
	if state == State.WINDUP and s != State.WINDUP:
		visual.set_warn(0.0)
	state = s
	_t = 0.0
	if s == State.AIM:
		visual.play_action("Pistol_Aim_Neutral", visual.animation_length("Pistol_Aim_Neutral") / _stats["aim"])


func _play(sound: String, pitch: float) -> void:
	_audio.stream = SOUNDS[sound]
	_audio.pitch_scale = pitch
	_audio.play()


func play_spotted() -> void:
	_play("spotted", 1.0)

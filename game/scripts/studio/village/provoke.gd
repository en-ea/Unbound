extends Node
## E2 interim target shortcut: hold/square_up exposes one FightTarget to Enea's native combat.
## PlayerActs -> PeopleBridge -> checked acceptance owns intent, contact accounts and choices.
## Ordinary Heavy also reaches eligible unsquared adults through contact.gd; hold is not required.
## Native target hits and ordinary contact converge on the same S/C authority, never old witnesses().
## Body owns the future control scheme. Tap/approach talk and urgent Free/Testify remain in live/talk.
## Target ends on distance, quiet, down or region exit. Authored characters keep Enea's bodies.
const PlayerActs := preload("res://scripts/studio/village/player_acts.gd")
const FightTarget := preload("res://scripts/studio/village/fight_target.gd")
const Authored := preload("res://scripts/studio/village/sim/authored.gd")

const LEAVE_DISTANCE := 12.0   # metres: walk this far away and it is over
const QUIET_SECONDS := 20.0    # this long with no blow and it is over

## A blow from the player landed on a villager, the moment it lands (what the body shows of it listens: the motion
## watcher now, the flinch later).
signal struck(id: int)
## ... with how hard (Enea's heavy blow): the body's flinch and knock-back (residents.gd) listen.
signal struck_hard(id: int, heavy: bool)

var registry: Node
var _player: Node3D
var _target: Node3D = null     # the FightTarget, while squared up
var _id := -1
var _since_hit := 0.0


var _authored_nodes := {}      # resident id -> Enea's npc.gd node (Wren, Brakk, Morrow, the Seeker)


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	# Enea's characters are residents too (authored.gd): find their bodies, and say if his table has moved on
	var v = VillageSession.village
	for node in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if node.get("_id") is String and v != null:
			for p in v.people:
				if p.authored == node.get("_id"):
					_authored_nodes[p.id] = node
	for line in Authored.drift(Npcs.NPCS):
		push_warning("studio village: Enea's characters changed, the rules' copy needs updating: " + line)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-lively-test=") and not VillageSession.has_node("LivelyProbe"):
			var lively: Node = load("res://scripts/studio/village/lively_probe.gd").new()
			lively.name = "LivelyProbe"
			VillageSession.add_child(lively)
	if "--village-provoke-test" in OS.get_cmdline_user_args() and not VillageSession.has_node("ProvokeProbe"):
		var probe: Node = load("res://scripts/studio/village/provoke_probe.gd").new()
		probe.name = "ProvokeProbe"
		VillageSession.add_child(probe)   # (survives the region changes it makes)


## Called by the talk screen's "Pick a fight". -> the village's answer (world_actions result).
func square_up(id: int) -> Dictionary:
	var result := PlayerActs.request(_player, registry, "square_up", id)
	if result.get("accepted", false):
		_release()
		_id = id
		_target = FightTarget.new()
		_target.provoke = self
		_target.resident = id
		_target.body = registry.bodies[id]
		add_child(_target)
		_since_hit = 0.0
	return result


## A blow from Enea's fighter reached the villager (FightTarget.take_hit).
func landed(id: int, damage: int, heavy: bool, action_key := "") -> Dictionary:
	_since_hit = 0.0
	var parameters := {"damage": damage, "heavy": heavy}
	if not action_key.is_empty():
		parameters.press_id = action_key
	var result := PlayerActs.request(_player, registry, "strike", id, parameters)
	if result.get("accepted", false) and not result.get("duplicate", false):
		struck.emit(id)
		# Bridge already published the accepted body impact once.
	if result.get("down", false):
		_release()
	return result


func is_squared_up(id: int) -> bool:
	return _target != null and _id == id


## Who could see the player and this villager now: Enea's bandit sight model (Balance.STEALTH: range, night,
## sneaking, the view cone) with a line of sight clear of walls. Hearing without seeing is not identifying.
func witnesses(target: int) -> Array:
	var out := []
	var st: Dictionary = Balance.STEALTH
	var sneaking: bool = _player.get("sneaking") == true
	var reach: float = st["sight_sneak"] if sneaking else st["sight"]
	var day_night := get_tree().current_scene.get_node_or_null("WorldEnvironment")
	if day_night != null and day_night.get("night") != null and float(day_night.night) > 0.5:
		reach *= st["night"]
	var at := _player.global_position
	var space := _player.get_world_3d().direct_space_state
	var looking := {}
	for id: int in registry.bodies:
		looking[id] = registry.bodies[id]
	for id: int in _authored_nodes:
		looking[id] = _authored_nodes[id]   # (their facing is their own; treated as looking about)
	for id: int in looking:
		if id == target:
			continue
		var body: Node3D = looking[id]
		var p = VillageSession.village.people[id]
		if not body.visible or not p.alive or not p.present:
			continue
		var to := at - body.global_position
		to.y = 0.0
		var d := to.length()
		if d > reach:
			continue
		var facing := Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
		if d > 3.0 and not _authored_nodes.has(id) and facing.dot(to.normalized()) < st["fov"]:
			continue   # looking the other way (close by, a scuffle is noticed anyway)
		var q := PhysicsRayQueryParameters3D.create(body.global_position + Vector3(0, 1.6, 0), at + Vector3(0, 1.0, 0))
		q.exclude = [(_player as CollisionObject3D).get_rid()]
		q.collision_mask = 1          # walls and the world: villagers' own bodies (solid to the player) do not hide a blow
		if not space.intersect_ray(q).is_empty():
			continue   # a wall between
		out.append(id)
	return out


func _process(delta: float) -> void:
	if _target == null:
		return
	_since_hit += delta
	var v = VillageSession.village
	var body: Node3D = registry.bodies.get(_id)
	if body == null or v == null or not v.people[_id].alive or not v.people[_id].present \
			or _player.global_position.distance_to(body.global_position) > LEAVE_DISTANCE or _since_hit > QUIET_SECONDS:
		_release()


func _release() -> void:
	if _target != null:
		# Enea's fighter re-picks its target each physics step from the "enemy" group; freed before that, his
		# lock-on marker reads a freed target for a frame. Out of the group now, freed at the next physics step.
		_target.remove_from_group("enemy")
		_target.process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().physics_frame.connect(_target.queue_free, CONNECT_ONE_SHOT)
	_target = null
	_id = -1


func _exit_tree() -> void:
	_release()
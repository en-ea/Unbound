extends Node3D
## One body per resident. Events borrow it; routines resume from its actual position.
const Body := preload("res://scripts/studio/village/villager_body.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const Sites := preload("res://scripts/studio/village/sites.gd")
const Stage := preload("res://scripts/studio/village/stage.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
var bodies := {}
var borrowed := {}
var paths := {}
var destinations := {}
var _shape := WorldShape.new()
var _minute := -1
var build_usec: Array[int] = []
var frame_usec: Array[int] = []
var ready_for_play := false
var _router: Node3D
var _player: Node3D

func _ready() -> void:
	_router = Stage.new()
	add_child(_router)
	_router._build_blocks() # same existing obstacle routes as event actors, computed only on replanning
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	var v = VillageSession.village
	if v == null:
		return
	# Preparation is included in measured frame work, never subtracted from the stage's cost.
	for p in v.people:
		if p.alive and p.present and not bodies.has(p.id):
			ensure(Justice.person_entry(v, p.id))
			break
	ready_for_play = true
	var now := int(v.runtime.now)
	var replan := now != _minute
	_minute = now
	for id: int in bodies:
		if borrowed.has(id):
			continue
		var body: Body = bodies[id]
		var p = v.people[id]
		if not p.alive or not p.present:
			body.set_detail(2)
			continue
		if replan or not destinations.has(id):
			var trip := Runtime.routine(v, id)
			var offset := Vector2(cos(id * 2.4), sin(id * 2.4)) * (0.65 + (id % 4) * 0.35)
			var start := place(trip.from) + offset
			var goal := place(trip.place) + offset
			if not destinations.has(id) or destinations[id].start != trip.start or destinations[id].place != trip.place:
				destinations[id] = trip
				paths[id] = [start] + Array(_router._route(start, goal))
		var trip: Dictionary = destinations[id]
		var progress := clampf((float(now) + float(v.runtime.fraction) - float(trip.start)) / maxf(1.0, float(trip.end) - float(trip.start)), 0.0, 1.0)
		var path: Array = paths[id]
		var length := 0.0
		for j in range(1, path.size()):
			length += (path[j] as Vector2).distance_to(path[j - 1])
		var left := length * progress
		var next: Vector2 = path[-1]
		for j in range(1, path.size()):
			var segment := (path[j] as Vector2).distance_to(path[j - 1])
			if left <= segment and segment > 0.001:
				next = (path[j - 1] as Vector2).lerp(path[j], left / segment)
				break
			left -= segment
		var at := Vector2(body.position.x, body.position.z)
		body.position = Vector3(next.x, _shape.height_at(next.x, next.y), next.y)
		if at.distance_squared_to(next) > 0.00001:
			body.rotation.y = atan2(next.x - at.x, next.y - at.y)
		var moving := progress < 1.0 and length > 0.1
		var near := _player != null and _player.global_position.distance_squared_to(body.global_position) < 100.0
		body.set_detail(0 if near else 1)
		body.play_motion(1.3 if moving and not VillageSession.background and not Controls.locked else 0.0)
		if not moving and not p.locked:
			body.play_loop("Farm_Harvest" if p.role == "farmer" else "Idle_Talking" if now % 1440 >= 1080 else "Idle")
	frame_usec.append(Time.get_ticks_usec() - t0)
	if frame_usec.size() > 3600:
		frame_usec.pop_front()

func place(name: String) -> Vector2:
	if Sites.DOORS.has(name):
		return Sites.DOORS[name] # simulation homes name buildings; bodies and clues use their accessible doors
	var v = VillageSession.village
	var index: int = v.place_ids.get(name, -1)
	return Vector2(v.place_x[index], v.place_z[index]) / 10.0 if index >= 0 else Sites.at(name)

func ensure(person: Dictionary) -> Body:
	var id := int(person.id)
	if bodies.has(id):
		return bodies[id]
	var t0 := Time.get_ticks_usec()
	var body := Body.new()
	var look := CharacterLook.new()
	var outfits: Array = CharacterLook.OUTFITS.keys()
	look.set_outfit(outfits[posmod(int(person.get("outfit", 0)), outfits.size())])
	var resident = VillageSession.village.people[id]
	if resident.ancestor >= 0:
		look.set_outfit("Northlander") # existing fur/paint outfit makes the local forebears readable
	look.set_color("Hair", (id * 3) % CharacterLook.PALETTES.Hair.size())
	look.set_color("Skin", (id * 2 + 1) % CharacterLook.PALETTES.Skin.size())
	body.hero_look = look; body.is_player_look = false
	add_child(body)
	var trip := Runtime.routine(VillageSession.village, id)
	var at := place(trip.from)
	body.position = Vector3(at.x, _shape.height_at(at.x, at.y), at.y)
	bodies[id] = body
	if Rules.age_of(VillageSession.village, resident) < 14:
		body.scale = Vector3.ONE * 0.68
	build_usec.append(Time.get_ticks_usec() - t0)
	return body

func acquire(person: Dictionary, parent: Node) -> Body:
	var body := ensure(person)
	borrowed[int(person.id)] = true
	body.reparent(parent, true)
	body.process_mode = Node.PROCESS_MODE_INHERIT
	body.set_detail(1)
	return body

func release(id: int, body: Body) -> void:
	if not is_instance_valid(body):
		return
	body.release_hands()
	body.reparent(self, true)
	body.process_mode = Node.PROCESS_MODE_INHERIT
	borrowed.erase(id)
	destinations.erase(id)

func _exit_tree() -> void:
	# Only data belongs to VillageSession. This registry dies with its region scene.
	borrowed.clear()

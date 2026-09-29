extends Node3D
## One body per resident. Events borrow it; routines resume from its actual position.
const Body := preload("res://scripts/studio/village/villager_body.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const Sites := preload("res://scripts/studio/village/sites.gd")
var bodies := {}
var borrowed := {}
var paths := {}
var destinations := {}
var _shape := WorldShape.new()
var _minute := -1
var build_usec: Array[int] = []
var frame_usec: Array[int] = []
var ready_for_play := false

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
			var site := Rules.place_at(p, now % 1440)
			var name: String = v.place_names[site] if site >= 0 else v.households[p.household].home
			var memory: Dictionary = v.runtime.residents.get(str(id), {})
			if int(memory.get("refuge_until", 0)) > now:
				name = memory.destination
			var goal := place(name)
			if destinations.get(id, Vector2.INF) != goal:
				destinations[id] = goal
				var at := Vector2(body.position.x, body.position.z)
				# Shared village lane and door approaches keep everyday walks out of houses.
				paths[id] = [Vector2(2.0, at.y), Vector2(2.0, goal.y), goal]
		var path: Array = paths.get(id, [])
		var moving := not path.is_empty()
		if moving and not VillageSession.background and not Controls.locked:
			var at := Vector2(body.position.x, body.position.z)
			var goal: Vector2 = path[0]
			var next := at.move_toward(goal, delta * 1.3)
			body.position = Vector3(next.x, _shape.height_at(next.x, next.y), next.y)
			if next.distance_squared_to(goal) < 0.01:
				path.pop_front()
			if at.distance_squared_to(next) > 0.00001:
				body.rotation.y = atan2(next.x - at.x, next.y - at.y)
		body.set_detail(1)
		body.play_motion(1.3 if moving else 0.0)
		if not moving and not p.locked:
			body.play_loop("Farm_Harvest" if p.role == "farmer" else "Idle_Talking" if now % 1440 >= 1080 else "Idle")
	frame_usec.append(Time.get_ticks_usec() - t0)
	if frame_usec.size() > 3600:
		frame_usec.pop_front()

func place(name: String) -> Vector2:
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
	look.set_color("Hair", (id * 3) % CharacterLook.PALETTES.Hair.size())
	look.set_color("Skin", (id * 2 + 1) % CharacterLook.PALETTES.Skin.size())
	body.hero_look = look; body.is_player_look = false
	add_child(body)
	var at := place(person.get("home", "square"))
	body.position = Vector3(at.x, _shape.height_at(at.x, at.y), at.y)
	bodies[id] = body
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

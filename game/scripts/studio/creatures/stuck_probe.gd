extends Node
## Creatures stuck in and under structures (his note 233349; plan LIVELY-VILLAGE section 1.2), measured headless. A
## measure only: it places creatures, carcasses and the player, and watches; the audit's own feelers (collision copies
## of the drawn meshes, on a layer nothing else uses) are removed before any creature walks.
##
##   --stuck-probe[=<modes>]   modes, comma-separated (default all): audit, brakk, meal, fight
##   --stuck-only=<text>       only the buildings whose name holds it (e.g. site: the smithy's)
##
##   audit   STUCK AUDIT <json> a building within NEAR_VILLAGE of the square: what is drawn at a wolf's height (posts,
##           walls: AUDIT_HEIGHTS above the ground, CELL cells) against what is solid there (its colliders)
##             drawn_rect / solid_rect   the drawn and the solid cells' bounds (x0, z0, x1, z1)
##             open_m2                   drawn, and neither solid nor beside a solid cell: something to walk into
##             open_rect                 their bounds (where the gap is)
##             shapes                    its colliders' kinds
##   brakk   BRAKK <json>: his stand against the smithy site (its drawn and solid footprints)
##   built   the village's projects built first (the finished smithy's own colliders, audited and walked round)
##   wander  the village's own creatures (enemies.gd), WANDER_S of their own lives with two bodies lying by buildings
##           (WANDER_MEALS) and the player away (WANDER_AT): each creature's STUCK WANDER <json> (pressed, longest, inside
##           and where), then STUCK WANDER ALL
##   route   ROUTE <json>: the villagers' router (studio stage.gd) asked for walks straight across the smithy's site
##           and the butcher's rack: whether any leg of the path it gives crosses their ground (plan gap #16)
##   look    no measure: a wolf after a carcass on the far side of the smithy's site, framed from the south (the
##           player parked out of its sight), for a look board with --shot and --shotframe
##   meal    wolves after a boar carcass on the far side of each building, MEAL_PLACES round it, WATCH_MEAL s each
##   fight   the player standing FIGHT_GAP off each side of each building, wolves, a boar and a bandit after him,
##           WATCH_FIGHT s each (they circle, charge, strike and back off round the walls; the player is kept alive)
##           each: STUCK <json>
##             pressed_s / longest_s     seconds on a wall, under 0.6 m/s, in a state that wants to move
##             inside_frames             frames with its middle in a building (_inside: solid, in a drawn thing,
##                                       or on ground walled in all round); inside_how, inside_at (where) when any
##             reached / gave_up         (meal) it got to the carcass / it stopped wanting it
##             blocked_most_s            the longest SteerAround held it from its wish
## Then STUCK ALL <json> and STUCK complete.
const WOLF := preload("res://scenes/wolf.tscn")
const BOAR := preload("res://scenes/boar.tscn")
const CARCASS := preload("res://scripts/world/carcass.gd")
const STEER := preload("res://scripts/studio/creatures/steer_around.gd")
const FIT := preload("res://scripts/studio/world/fit_colliders.gd")
const MEAL_PLACES := 4
const WATCH_MEAL := 20.0
const WATCH_FIGHT := 12.0
const FAR := 25.0
const FIGHT_GAP := 1.4
const VILLAGE := Vector2(1.5, 18.0)     # the square
const NEAR_VILLAGE := 40.0
const CELL := 0.25
const WIDTH_CELLS := 1       # cells either side a creature's middle keeps from what is drawn (the slimmest, a wolf: 0.23 m)
const AUDIT_HEIGHTS := [0.3, 0.9]
const AUDIT_LAYER := 1 << 19
const MOVING := {"wolf": ["WANDER", "CIRCLE", "RETREAT"], "boar": ["WANDER", "CHARGE"], "bandit": ["SEARCH", "CIRCLE"],
	"stag": ["WALK", "FLEE"]}
const WANDER_S := 600.0      # seconds of the village's own creatures living (wander)
const WANDER_AT := Vector2(-10.0, 60.0)   # where the player waits meanwhile: 40 m and more from every creature's home
const WANDER_MEALS := [Vector2(-21.0, 12.0), Vector2(14.0, 18.0)]   # bodies by buildings: by the smithy's site (his note's
                                          # boar), by the cabin

var _sites: Array = []        # {name, node, drawn: {cell: true}, solid: {cell: true}, drawn_rect, solid_rect}
var _modes: Array = []
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--stuck-probe":
			_modes = ["audit", "brakk", "meal", "fight"]
		elif arg.begins_with("--stuck-probe="):
			_modes = Array(arg.trim_prefix("--stuck-probe=").split(",", false))
		elif arg.begins_with("--stuck-only="):
			_only = arg.trim_prefix("--stuck-only=")
	_run.call_deferred()


func _run() -> void:
	for _i in 40:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var shape := WorldShape.new()
	if "look" in _modes:
		_look(player, shape)
		return
	if "built" in _modes:                                     # (the test save only: no coins or goods asked)
		for id: String in Projects.DEFS:
			if not Projects.is_built(id):
				Projects._built[id] = true
				Projects.built.emit(id)
		for _i in 90:                                          # (its rising tween done)
			await get_tree().process_frame
	_park(player, shape)
	_sites = await _audit(shape)
	if "brakk" in _modes:
		_brakk()
	if "wander" in _modes:
		await _wander(player, shape)
	if "meal" in _modes or "fight" in _modes:
		for c: Node in get_tree().get_nodes_in_group("enemy"):
			c.queue_free()                           # (the meadow's own: they would come for the staged meals too)
		await get_tree().physics_frame
	if "route" in _modes:
		_routes()
	var all := {"runs": 0, "pressed_over_1_5s": 0, "inside_frames": 0, "worst_longest_s": 0.0, "reached": 0, "meals": 0,
		"gave_up": 0, "by_kind": {}}
	for site: Dictionary in _sites:
		if "meal" in _modes:
			var mid: Vector2 = (site.drawn_rect as Rect2).get_center()
			var half: Vector2 = (site.drawn_rect as Rect2).size * 0.5
			for k in MEAL_PLACES:
				var a := TAU * (k + 0.5) / MEAL_PLACES
				var dir := Vector2(cos(a), sin(a))
				var r := await _meal(player, shape, _clear_spot(mid + dir * FAR, dir), _clear_spot(mid - dir * (half.length() + 1.6), -dir))
				r.site = site.name
				_count(all, r, "wolf")
		if "fight" in _modes:
			var rect: Rect2 = site.solid_rect if (site.solid_rect as Rect2).has_area() else site.drawn_rect
			for side in 4:
				var stand := _beside(rect, side)
				for kind: String in ["wolf", "boar", "bandit"]:
					var r := await _fight(player, shape, kind, stand, rect.get_center())
					r.site = site.name
					r.side = side
					_count(all, r, kind)
	print("STUCK ALL %s" % JSON.stringify(all))
	print("STUCK complete")
	get_tree().quit()


func _count(all: Dictionary, r: Dictionary, kind: String) -> void:
	print("STUCK %s" % JSON.stringify(r))
	all.runs += 1
	all.pressed_over_1_5s += 1 if float(r.longest_s) > 1.5 else 0
	all.inside_frames += int(r.inside_frames)
	all.worst_longest_s = maxf(float(all.worst_longest_s), float(r.longest_s))
	if r.has("reached"):
		all.meals += 1
		all.reached += 1 if r.reached else 0
		all.gave_up += 1 if r.gave_up else 0
	var k: Dictionary = (all.by_kind as Dictionary).get_or_add(kind, {"runs": 0, "pressed": 0, "inside_frames": 0})
	k.runs += 1
	k.pressed += 1 if float(r.longest_s) > 1.5 else 0
	k.inside_frames += int(r.inside_frames)


func _park(player: CharacterBody3D, shape: WorldShape) -> void:
	player.global_position = Vector3(60.0, shape.height_at(60.0, -60.0) + 0.2, -60.0)    # far off: no creature sees them


# ---------- the audit ----------

## Every village building's drawn cells at a wolf's height against its solid cells.
func _audit(shape: WorldShape) -> Array:
	var out: Array = []
	var space := get_viewport().get_world_3d().direct_space_state
	for b: Node in get_tree().get_nodes_in_group("map_building"):
		var n := b as Node3D
		if n == null or Vector2(n.global_position.x, n.global_position.z).distance_to(VILLAGE) > NEAR_VILLAGE:
			continue
		var name := ("site:" if n.get_script() != null and str((n.get_script() as Script).resource_path).ends_with("project_site.gd") else "house:") + str(n.name)
		if _only != "" and not name.contains(_only):
			continue
		var feelers: Array[Node] = []
		var bounds := AABB()
		var first := true
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree() or _under_station(mi, n) or mi.mesh == null:
				continue
			var box := mi.global_transform * mi.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			var body := StaticBody3D.new()                      # (a copy of what is drawn, to feel it: removed below)
			body.collision_layer = AUDIT_LAYER
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			cs.shape = mi.mesh.create_trimesh_shape()
			body.add_child(cs)
			mi.add_child(body)
			feelers.append(body)
		if first:
			continue
		await get_tree().physics_frame                          # (the copies in the space)
		await get_tree().physics_frame
		var shapes := {}
		for cs: CollisionShape3D in n.find_children("*", "CollisionShape3D", true, false):
			if cs.shape != null and not (cs.get_parent() in feelers):
				shapes[cs.shape.get_class()] = int(shapes.get(cs.shape.get_class(), 0)) + 1
		var drawn := {}
		var solid := {}
		var x0 := floori((bounds.position.x - 0.5) / CELL)
		var x1 := ceili((bounds.end.x + 0.5) / CELL)
		var z0 := floori((bounds.position.z - 0.5) / CELL)
		var z1 := ceili((bounds.end.z + 0.5) / CELL)
		var pq := PhysicsPointQueryParameters3D.new()
		pq.collision_mask = 1
		for cx in range(x0, x1):
			for cz in range(z0, z1):
				var x := (cx + 0.5) * CELL
				var z := (cz + 0.5) * CELL
				var ground := shape.height_at(x, z)
				for h: float in AUDIT_HEIGHTS:
					var y := ground + h
					if not drawn.has(Vector2i(cx, cz)):
						for d: Vector3 in [Vector3(CELL * 0.5, 0, 0), Vector3(0, 0, CELL * 0.5)]:
							var rq := PhysicsRayQueryParameters3D.create(Vector3(x, y, z) - d, Vector3(x, y, z) + d, AUDIT_LAYER)
							rq.hit_back_faces = true
							var hit := space.intersect_ray(rq)
							if not hit.is_empty():
								drawn[Vector2i(cx, cz)] = str((hit.collider as Node).get_parent().name)   # (the mesh it is)
								break
					if not solid.has(Vector2i(cx, cz)):
						pq.position = Vector3(x, y, z)
						for hit: Dictionary in space.intersect_point(pq, 8):
							if hit.collider is Node and n.is_ancestor_of(hit.collider):
								solid[Vector2i(cx, cz)] = true
								break
		for f in feelers:
			f.queue_free()
		var open := 0
		var open_rect := Rect2()
		var open_meshes := {}
		for c: Vector2i in drawn:
			if solid.has(c):
				continue
			var near := false
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if solid.has(c + Vector2i(dx, dz)):
						near = true
			if near:
				continue
			var r := Rect2(c.x * CELL, c.y * CELL, CELL, CELL)
			open_rect = r if open == 0 else open_rect.merge(r)
			open += 1
			var what := str(drawn[c])
			var mr: Rect2 = open_meshes.get(what, r)
			open_meshes[what] = mr.merge(r)
		var site := {"name": name, "node": n, "drawn": drawn, "solid": solid, "drawn_rect": _rect_of(drawn), "solid_rect": _rect_of(solid)}
		site.walled = _walled(site)
		if "bake" in _modes:                                  # what fit_colliders.gd should add: the open cells as boxes,
			var opened := {}                                  # in the building's own frame
			for c: Vector2i in drawn:
				if not solid.has(c):
					var near := false
					for dx in range(-1, 2):
						for dz in range(-1, 2):
							near = near or solid.has(c + Vector2i(dx, dz))
					if not near:
						opened[c] = true
			var rects: Array = []
			for r: Rect2 in _merge(opened):
				var lo := n.to_local(Vector3(r.position.x, n.global_position.y, r.position.y))
				var hi := n.to_local(Vector3(r.end.x, n.global_position.y, r.end.y))
				rects.append([snappedf(minf(lo.x, hi.x), 0.05), snappedf(minf(lo.z, hi.z), 0.05), snappedf(maxf(lo.x, hi.x), 0.05), snappedf(maxf(lo.z, hi.z), 0.05)])
			var dl := n.to_local(Vector3(site.drawn_rect.position.x, n.global_position.y, site.drawn_rect.position.y))
			var dh := n.to_local(Vector3(site.drawn_rect.end.x, n.global_position.y, site.drawn_rect.end.y))
			print("STUCK BAKE %s" % JSON.stringify({"name": name, "mesh": _first_mesh(n), "open": rects,
				"frame": [snappedf(minf(dl.x, dh.x), 0.05), snappedf(minf(dl.z, dh.z), 0.05), snappedf(maxf(dl.x, dh.x), 0.05), snappedf(maxf(dl.z, dh.z), 0.05)]}))
		out.append(site)
		if "audit" in _modes or "brakk" in _modes:
			print("STUCK AUDIT %s" % JSON.stringify({"name": name, "drawn_rect": _r(site.drawn_rect), "solid_rect": _r(site.solid_rect),
				"drawn_m2": snappedf(drawn.size() * CELL * CELL, 0.1), "solid_m2": snappedf(solid.size() * CELL * CELL, 0.1),
				"open_m2": snappedf(open * CELL * CELL, 0.1), "open_rect": _r(open_rect) if open > 0 else [], "shapes": shapes,
				"at": [snappedf(n.global_position.x, 0.1), snappedf(n.global_position.z, 0.1)], "turn": snappedf(rad_to_deg(n.global_rotation.y), 1.0),
				"script": str((n.get_script() as Script).resource_path).get_file() if n.get_script() != null else "",
				"parent": str(n.get_parent().name), "open_by_mesh": _rects(open_meshes)}))
	await get_tree().physics_frame
	return out


static func _under_station(mi: Node, stop: Node) -> bool:
	var p := mi.get_parent()
	while p != null and p != stop:
		if p.get_script() != null and str((p.get_script() as Script).resource_path).ends_with("station.gd"):
			return true                                      # (a notice board: a thing of its own, with its own collider)
		p = p.get_parent()
	return false


## Cells merged into rectangles: runs along x in each row, then runs of the same span down the rows.
static func _merge(cells: Dictionary) -> Array:
	var rows := {}
	for c: Vector2i in cells:
		(rows.get_or_add(c.y, []) as Array).append(c.x)
	var spans := {}                                          # Vector2i(x0, x1) -> Array of z rows
	for z: int in rows:
		var xs: Array = rows[z]
		xs.sort()
		var start: int = xs[0]
		var last: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and int(xs[i]) == last + 1:
				last = xs[i]
				continue
			(spans.get_or_add(Vector2i(start, last), []) as Array).append(z)
			if i < xs.size():
				start = xs[i]
				last = xs[i]
	var out: Array = []
	for sp: Vector2i in spans:
		var zs: Array = spans[sp]
		zs.sort()
		var z0: int = zs[0]
		var zl: int = zs[0]
		for i in range(1, zs.size() + 1):
			if i < zs.size() and int(zs[i]) == zl + 1:
				zl = zs[i]
				continue
			out.append(Rect2(sp.x * CELL, z0 * CELL, (sp.y - sp.x + 1) * CELL, (zl - z0 + 1) * CELL))
			if i < zs.size():
				z0 = zs[i]
				zl = zs[i]
	return out


static func _first_mesh(n: Node) -> String:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		return str(mi.name)
	return ""


static func _rects(by: Dictionary) -> Dictionary:
	var out := {}
	for k: String in by:
		out[k] = _r(by[k])
	return out


static func _rect_of(cells: Dictionary) -> Rect2:
	var r := Rect2()
	var first := true
	for c: Vector2i in cells:
		var cr := Rect2(c.x * CELL, c.y * CELL, CELL, CELL)
		r = cr if first else r.merge(cr)
		first = false
	return r


static func _r(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.end.x, 0.1), snappedf(r.end.y, 0.1)]


## Where a creature's middle is in a structure: "solid" (in its colliders), "drawn" (in something drawn at its height,
## not solid: a post, a plank, a table's top), "walled" (ground walled in all round by what is drawn: no way out at a
## creature's width). Ground under a roof between posts, open to one side (a porch), is open ground: plan 1.2 keeps a
## roof's overhang open. "" when it is in none.
func _inside(p: Vector2) -> String:
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for site: Dictionary in _sites:
		if (site.solid as Dictionary).has(c):
			return "solid"
		if (site.drawn as Dictionary).has(c):
			return "drawn"
		if (site.walled as Dictionary).has(c):
			return "walled"
	return ""


## The open cells of a site that are walled in: within its drawn bounds, and not reached by a creature's width
## (WIDTH_CELLS clear cells side by side) from outside them. A flood from a ring round the bounds.
static func _walled(site: Dictionary) -> Dictionary:
	var dr: Rect2 = site.drawn_rect
	var out := {}
	if not dr.has_area():
		return out
	var x0 := floori(dr.position.x / CELL) - 2
	var z0 := floori(dr.position.y / CELL) - 2
	var x1 := ceili(dr.end.x / CELL) + 2
	var z1 := ceili(dr.end.y / CELL) + 2
	var blocked := func(c: Vector2i) -> bool:          # a creature's middle cannot be here: something within its width
		for dx in range(-WIDTH_CELLS, WIDTH_CELLS + 1):
			for dz in range(-WIDTH_CELLS, WIDTH_CELLS + 1):
				var k := c + Vector2i(dx, dz)
				if (site.drawn as Dictionary).has(k) or (site.solid as Dictionary).has(k):
					return true
		return false
	var seen := {}
	var todo: Array[Vector2i] = []
	for x in range(x0, x1 + 1):
		for z in [z0, z1]:
			todo.append(Vector2i(x, z))
	for z in range(z0, z1 + 1):
		for x in [x0, x1]:
			todo.append(Vector2i(x, z))
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if seen.has(c) or c.x < x0 or c.x > x1 or c.y < z0 or c.y > z1 or blocked.call(c):
			continue
		seen[c] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			todo.append(c + d)
	for x in range(x0 + 1, x1):
		for z in range(z0 + 1, z1):
			var c := Vector2i(x, z)
			if not seen.has(c) and not blocked.call(c):      # (room for a creature's middle, and no way in from outside;
				out[c] = true                                 # the strip beside a wall is contact, not "in")
	return out


# ---------- the runs ----------

func _meal(player: CharacterBody3D, shape: WorldShape, from: Vector2, meal_at: Vector2) -> Dictionary:
	_park(player, shape)
	var region := player.get_parent()
	var meal: Node3D = CARCASS.spawn(region, "boar", Vector3(meal_at.x, shape.height_at(meal_at.x, meal_at.y), meal_at.y), 0.0, player, 60.0)
	var wolf := WOLF.instantiate()
	wolf.player = player
	wolf.home = Vector3(from.x, shape.height_at(from.x, from.y), from.y)
	region.add_child(wolf)
	wolf.global_position = wolf.home + Vector3(0, 0.6, 0)
	var r := await _watch(wolf, "wolf", WATCH_MEAL, player, true, meal)
	r.from = [snappedf(from.x, 0.1), snappedf(from.y, 0.1)]
	r.meal = [snappedf(meal_at.x, 0.1), snappedf(meal_at.y, 0.1)]
	if is_instance_valid(meal):
		meal.queue_free()
	return r


## `p`, or the first spot along `away` from it (0.5 m steps, 12 m at most) where a creature stands clear: no building's
## cells (solid, drawn or walled) within a metre, nothing solid round its knee and back (a tree, a rock, a cart).
func _clear_spot(p: Vector2, away: Vector2) -> Vector2:
	var space := get_viewport().get_world_3d().direct_space_state
	var dir := away.normalized() if away.length() > 0.01 else Vector2(1, 0)
	var shape := WorldShape.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	var pq := PhysicsShapeQueryParameters3D.new()
	pq.shape = sphere
	pq.collision_mask = 1
	for k in 25:
		var q := p + dir * (0.5 * k)
		var free := true
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				if free and _inside(q + Vector2(dx, dz) * CELL) != "":
					free = false
		if free:
			pq.transform = Transform3D(Basis(), Vector3(q.x, shape.height_at(q.x, q.y) + 0.9, q.y))
			free = space.intersect_shape(pq, 1).is_empty()
		if free:
			return q
	return p


## The player stands beside a wall (side 0-3: west, east, north, south of `rect`), and one creature comes for him.
func _fight(player: CharacterBody3D, shape: WorldShape, kind: String, stand: Vector2, mid: Vector2) -> Dictionary:
	player.global_position = Vector3(stand.x, shape.height_at(stand.x, stand.y) + 0.2, stand.y)
	player.set("velocity", Vector3.ZERO)
	var region := player.get_parent()
	var away := (stand - mid).normalized()
	var at := _clear_spot(stand + away * 7.0 + away.orthogonal() * 2.0, away)
	var c: CharacterBody3D
	match kind:
		"wolf":
			c = WOLF.instantiate()
			c.player = player
			c.home = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
		"boar":
			c = BOAR.instantiate()
			c.player = player
			c.home = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
		"bandit":
			c = Bandit.new()
			c.kind = "cutthroat"
			c.player = player
			c.post = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
			c.post_turn = atan2(-away.x, -away.y)
			c.look = BanditLooks.make(0, 7)
	region.add_child(c)
	c.global_position = Vector3(at.x, shape.height_at(at.x, at.y) + 0.6, at.y)
	var r := await _watch(c, kind, WATCH_FIGHT, player, false)
	r.stand = [snappedf(stand.x, 0.1), snappedf(stand.y, 0.1)]
	return r


func _watch(c: CharacterBody3D, kind: String, watch: float, player: Node3D, meal: bool, meal_node: Node3D = null) -> Dictionary:
	var t := 0.0
	var pressed := 0.0
	var spell := 0.0
	var longest := 0.0
	var inside := 0
	var reached := false
	var wanted := false
	var blocked_most := 0.0
	var states := {}
	var inside_how := {}
	var inside_at: Array = []
	var closest := INF
	while t < watch:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if not is_instance_valid(c):
			break
		if player.has_method("heal_full"):
			player.call("heal_full")
		var st := _state(c)
		states[st] = int(states.get(st, 0)) + 1
		var eating := false
		if meal:
			var m = c.get("_meal")
			eating = str(c.visual.get("mode")) == "eat"
			wanted = wanted or is_instance_valid(m)
			if is_instance_valid(meal_node):
				closest = minf(closest, Vector2(c.global_position.x - meal_node.global_position.x, c.global_position.z - meal_node.global_position.z).length())
			reached = reached or eating
		var v: Vector3 = c.velocity
		var moving_state: bool = st in MOVING.get(kind, [])
		var stuck: bool = c.is_on_wall() and Vector2(v.x, v.z).length() < 0.6 and not eating and moving_state
		if stuck:
			pressed += dt
			spell += dt
			longest = maxf(longest, spell)
		else:
			spell = 0.0
		var how := _inside(Vector2(c.global_position.x, c.global_position.z))
		if how != "":
			inside += 1
			inside_how[how] = int(inside_how.get(how, 0)) + 1
			var at := [snappedf(c.global_position.x, 0.25), snappedf(c.global_position.z, 0.25)]
			if inside_at.size() < 6 and not at in inside_at:
				inside_at.append(at)
		blocked_most = maxf(blocked_most, STEER.blocked_for(c))
	var r := {"kind": kind, "pressed_s": snappedf(pressed, 0.1), "longest_s": snappedf(longest, 0.1), "inside_frames": inside,
		"blocked_most_s": snappedf(blocked_most, 0.1), "states": states}
	if inside > 0:
		r.inside_how = inside_how
		r.inside_at = inside_at
	if meal:
		r.closest_m = snappedf(closest, 0.1)
		if is_instance_valid(c):
			r.end = [snappedf(c.global_position.x, 0.1), snappedf(c.global_position.z, 0.1)]
		r.reached = reached
		r.wanted = wanted
		r.gave_up = wanted and is_instance_valid(c) and not is_instance_valid(c.get("_meal")) and not reached
	if is_instance_valid(c):
		c.remove_from_group("enemy")                 # (out of the lock's choosing, and the lock let go, as a death does)
		var fighter: Node = player.get("fighter")
		if fighter != null and fighter.get("target") == c:
			fighter.set("target", null)
		await get_tree().physics_frame
		c.queue_free()
	for _i in 3:
		await get_tree().physics_frame
	return r


static func _state(c: Node) -> String:
	var s = c.get("state")
	var e = c.get_script().get_script_constant_map().get("State") if c.get_script() != null else null
	if s == null or e == null:
		return "?"
	for k: String in e:
		if int(e[k]) == int(s):
			return k
	return "?"


static func _beside(rect: Rect2, side: int) -> Vector2:
	var mid := rect.get_center()
	match side:
		0: return Vector2(rect.position.x - FIGHT_GAP, mid.y)
		1: return Vector2(rect.end.x + FIGHT_GAP, mid.y)
		2: return Vector2(mid.x, rect.position.y - FIGHT_GAP)
		_: return Vector2(mid.x, rect.end.y + FIGHT_GAP)


# ---------- the villagers' router ----------

func _routes() -> void:
	var router: Node = load("res://scripts/studio/village/stage.gd").new()
	add_child(router)
	router.call("_build_blocks")
	for n: Node in get_tree().get_nodes_in_group("map_building"):
		var path := str((n.get_script() as Script).resource_path) if n.get_script() != null else ""
		if not (path.ends_with("project_site.gd") or path.ends_with("butcher.gd")):
			continue
		var ground: Rect2 = FIT.ground_of(n as Node3D)
		var mid := ground.get_center()
		var crossed := 0
		var walks := 0
		for a: Vector2 in [Vector2(-1, 0), Vector2(0, -1), Vector2(-1, -1).normalized(), Vector2(1, -1).normalized()]:
			var from: Vector2 = mid + a * (ground.size.length() * 0.5 + 4.0)
			var to: Vector2 = mid - a * (ground.size.length() * 0.5 + 4.0)
			var way: PackedVector2Array = router.call("_route", from, to)
			walks += 1
			var p := from
			for q: Vector2 in way:
				if _crosses(ground, p, q):
					crossed += 1
					break
				p = q
		print("ROUTE %s" % JSON.stringify({"what": path.get_file(), "ground": _r(ground), "walks": walks, "crossing": crossed}))
	router.queue_free()


## Whether the segment a-b passes through the rectangle (sampled every 0.1 m).
static func _crosses(r: Rect2, a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, ceili(a.distance_to(b) / 0.1))
	for i in n + 1:
		if r.grow(-0.05).has_point(a.lerp(b, float(i) / n)):
			return true
	return false


# ---------- the village's own creatures ----------

func _wander(player: CharacterBody3D, shape: WorldShape) -> void:
	player.global_position = Vector3(WANDER_AT.x, shape.height_at(WANDER_AT.x, WANDER_AT.y) + 0.2, WANDER_AT.y)
	var region := player.get_parent()
	var meals: Array = []
	for at: Vector2 in WANDER_MEALS:
		meals.append(CARCASS.spawn(region, "boar", Vector3(at.x, shape.height_at(at.x, at.y), at.y), 0.0, player, 60.0))
	var rows := {}                                   # creature -> its measures
	var t := 0.0
	while t < WANDER_S:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if player.has_method("heal_full"):
			player.call("heal_full")
		for c: Node in get_tree().get_nodes_in_group("enemy"):
			var b := c as CharacterBody3D
			if b == null or not b.is_inside_tree():
				continue
			var kind := "wolf" if b.get("_meal") != null or str(b.scene_file_path).ends_with("wolf.tscn") else (
				"boar" if str(b.scene_file_path).ends_with("boar.tscn") else ("stag" if b.is_in_group("stag") else "bandit"))
			var r: Dictionary = rows.get_or_add(b.get_instance_id(), {"kind": kind, "pressed_s": 0.0, "longest_s": 0.0, "spell": 0.0,
				"inside_frames": 0, "inside_at": [], "longest_at": [], "near_village_s": 0.0, "states": {}})
			var st := _state(b)
			r.states[st] = int(r.states.get(st, 0)) + 1
			var p := Vector2(b.global_position.x, b.global_position.z)
			if p.distance_to(VILLAGE) < NEAR_VILLAGE:
				r.near_village_s = float(r.near_village_s) + dt
			var v := b.velocity
			if b.is_on_wall() and Vector2(v.x, v.z).length() < 0.6 and st in MOVING.get(kind, []):
				r.pressed_s = float(r.pressed_s) + dt
				r.spell = float(r.spell) + dt
				if float(r.spell) > float(r.longest_s):
					r.longest_s = r.spell
					r.longest_at = [snappedf(p.x, 0.5), snappedf(p.y, 0.5)]
			else:
				r.spell = 0.0
			var how := _inside(p)
			if how != "":
				r.inside_frames = int(r.inside_frames) + 1
				var at := [snappedf(p.x, 0.25), snappedf(p.y, 0.25), how]
				if (r.inside_at as Array).size() < 6 and not at in r.inside_at:
					(r.inside_at as Array).append(at)
	var all := {"creatures": 0, "near_village": 0, "pressed_over_1_5s": 0, "worst_longest_s": 0.0, "inside_frames": 0,
		"seconds": WANDER_S}
	for id: int in rows:
		var r: Dictionary = rows[id]
		r.erase("spell")
		r.pressed_s = snappedf(float(r.pressed_s), 0.1)
		r.longest_s = snappedf(float(r.longest_s), 0.1)
		r.near_village_s = snappedf(float(r.near_village_s), 0.1)
		print("STUCK WANDER %s" % JSON.stringify(r))
		all.creatures += 1
		all.near_village += 1 if float(r.near_village_s) > 0.0 else 0
		all.pressed_over_1_5s += 1 if float(r.longest_s) > 1.5 else 0
		all.worst_longest_s = maxf(float(all.worst_longest_s), float(r.longest_s))
		all.inside_frames += int(r.inside_frames)
	for m: Variant in meals:
		if is_instance_valid(m):
			(m as Node).queue_free()
	print("STUCK WANDER ALL %s" % JSON.stringify(all))


# ---------- a look ----------

## A wolf east of the smithy's site and a boar's carcass west of it: the straight way runs through the frame.
func _look(player: CharacterBody3D, shape: WorldShape) -> void:
	var site: Vector2 = Projects.DEFS["smithy"]["at"]
	var stand := site + Vector2(0.0, 20.0)                  # 20 m south: out of its sight (wolf.gd SIGHT 10)
	player.global_position = Vector3(stand.x, shape.height_at(stand.x, stand.y) + 0.2, stand.y)
	var rig := get_tree().current_scene.get_node_or_null("CameraRig")
	if rig != null:
		rig.call("set_view", 24.0, 50.0, Vector3(site.x - stand.x, 0.0, site.y - stand.y), 0.01, 35.0)
	var region := player.get_parent()
	var meal_at := site + Vector2(-8.0, 0.0)
	CARCASS.spawn(region, "boar", Vector3(meal_at.x, shape.height_at(meal_at.x, meal_at.y), meal_at.y), 0.0, player, 60.0)
	var from := site + Vector2(8.0, 0.0)
	var wolf := WOLF.instantiate()
	wolf.player = player
	wolf.home = Vector3(from.x, shape.height_at(from.x, from.y), from.y)
	region.add_child(wolf)
	wolf.global_position = wolf.home + Vector3(0, 0.6, 0)


# ---------- Brakk ----------

const SITES := preload("res://scripts/studio/village/sites.gd")


## Metres between two rectangles (negative: they overlap, by the smaller of the two overlaps).
static func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var dz := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	if dx < 0.0 and dz < 0.0:
		return maxf(dx, dz)
	return Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()

## Brakk's stand against the smithy site's drawn and solid footprints.
func _brakk() -> void:
	for n: Node in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if str(n.get("_id")) != "brakk":         # (Enea's characters are world/npc.gd nodes with their id in _id)
			continue
		var b := n as Node3D
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree():
				continue
			var a := mi.global_transform * mi.get_aabb()
			box = a if first else box.merge(a)
			first = false
		var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		var hits: Array = []
		for site: Dictionary in _sites:
			if (site.drawn_rect as Rect2).intersects(foot) or (site.solid_rect as Rect2).intersects(foot):
				hits.append(site.name)
		var gap := INF                                    # metres from his footprint to the nearest site's (< 0: in it)
		for site: Dictionary in _sites:
			for r: Rect2 in [site.drawn_rect, site.solid_rect]:
				if r.has_area():
					gap = minf(gap, _rect_gap(foot, r))
		# anything solid where he stands (not his own, not the ground), and the crowds whose slots fall in his stand
		var solid: Array = []
		var q := PhysicsShapeQueryParameters3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(foot.size.x, 1.0, foot.size.y)
		q.shape = box_shape
		var c := foot.get_center()
		q.transform = Transform3D(Basis(), Vector3(c.x, WorldShape.new().height_at(c.x, c.y) + 0.9, c.y))
		for hit: Dictionary in b.get_world_3d().direct_space_state.intersect_shape(q, 16):
			var col := hit.collider as Node
			if col != null and not b.is_ancestor_of(col) and col != b:
				solid.append(str(col.get_parent().name) + "/" + str(col.name))
		var crowds := {}
		for place: String in SITES.PLACES:
			for k in 25:                                  # (the first two rows of a crowd)
				for at: Vector2 in [SITES.arc(place, k), SITES.slot(place, k)]:
					if foot.grow(0.3).has_point(at):
						crowds[place] = true
		print("BRAKK %s" % JSON.stringify({"node": str(b.name), "at": [snappedf(b.global_position.x, 0.1), snappedf(b.global_position.z, 0.1)],
			"footprint": _r(foot), "overlaps": hits, "gap_m": snappedf(gap, 0.05), "solid_here": solid, "crowds_here": crowds.keys()}))
		return
	print("BRAKK %s" % JSON.stringify({"error": "not found"}))

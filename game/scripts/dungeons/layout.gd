extends RefCounted
## A dungeon's shape from a seed (pure data, no nodes; the same seed always gives the same dungeon): a winding
## main path of round rooms leading away from the way in, a side room or two off it, and the tunnels that join
## them. Each room has a role a template fills (templates.gd): "entry", "fight", "goal", "side".
##   make(seed, path_rooms, side_rooms) -> {rooms: [{at, r, role}], tunnels: [[a, b, half width]],
##                                          corner, size, entry, exit_z}
## The way in is a tunnel south from the entry room (walk out down it to leave).

const MARGIN := 6.0


static func make(seed: int, path_rooms: int, side_rooms: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rooms: Array = [{"at": Vector2.ZERO, "r": 4.5, "role": "entry"}]
	var tunnels: Array = [[Vector2(0, 2), Vector2(0, 9.5), 2.0]]     # the way in, from the south
	var heading := -PI / 2.0                                          # on north, away from the way in
	for k in path_rooms:
		var last: bool = k == path_rooms - 1
		var r := 7.5 if last else rng.randf_range(4.8, 6.8)
		var prev: Dictionary = rooms[-1]
		for attempt in 12:                                            # wind about, but never back on itself
			heading = clampf(-PI / 2.0 + rng.randf_range(-1.0, 1.0), -PI * 0.9, -PI * 0.1)
			var at: Vector2 = prev.at + Vector2.from_angle(heading) * (float(prev.r) + r + rng.randf_range(4.0, 7.5))
			if _clear(rooms, at, r) or attempt == 11:
				rooms.append({"at": at, "r": r, "role": "goal" if last else "fight"})
				tunnels.append([prev.at, at, rng.randf_range(1.8, 2.4)])
				break
	for s in side_rooms:                                              # off a room on the path, left or right
		for attempt in 16:
			var base: Dictionary = rooms[1 + rng.randi() % maxi(rooms.size() - 2, 1)]
			if base.role != "fight":
				continue
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var r := rng.randf_range(3.4, 4.6)
			var dir := Vector2(side, rng.randf_range(-0.4, 0.4)).normalized()
			var at: Vector2 = base.at + dir * (float(base.r) + r + rng.randf_range(3.5, 6.0))
			if _clear(rooms, at, r):
				rooms.append({"at": at, "r": r, "role": "side"})
				tunnels.append([base.at, at, rng.randf_range(1.6, 2.0)])
				break
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for room: Dictionary in rooms:
		lo = lo.min(room.at - Vector2.ONE * float(room.r))
		hi = hi.max(room.at + Vector2.ONE * float(room.r))
	hi.y = maxf(hi.y, 9.5)
	lo -= Vector2.ONE * MARGIN
	hi += Vector2.ONE * MARGIN
	var corner := lo.floor()
	return {"rooms": rooms, "tunnels": tunnels, "corner": corner,
		"size": Vector2i(int(ceil(hi.x - corner.x)) + 1, int(ceil(hi.y - corner.y)) + 1),
		"entry": Vector3(0, 0.3, 5.0), "exit_z": 7.6}


## The rooms of a role, in path order.
static func rooms_of(layout: Dictionary, role: String) -> Array:
	return layout.rooms.filter(func(r: Dictionary) -> bool: return r.role == role)


static func _clear(rooms: Array, at: Vector2, r: float) -> bool:
	for other: Dictionary in rooms:
		if at.distance_to(other.at) < r + float(other.r) + 2.5:
			return false
	return true

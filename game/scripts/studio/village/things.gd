extends RefCounted
## Things in the world his acts can reach (Body, world-things): a yard's fence and bench, a bandit camp's crates and
## rack. Found by their model, the same carriers render/thing_state.gd draws; each one's id is its kind and where it
## stands ("<kind>@<x dm>,<z dm>"), so the same thing has the same id on every load. Contact measures them as targets
## beside people; their facts and rules are thing_actions.gd.
const ThingActions := preload("res://scripts/studio/village/sim/thing_actions.gd")
const CARRIERS := {
	"res://assets/props/fence.glb": "fence",
	"res://assets/props/bench.glb": "bench",
	"res://assets/camp/camp_crates.glb": "crates",
	"res://assets/camp/camp_rack.glb": "rack",
}
const REACH_PAD := 0.5              # a thing is reached at its edge, about half a metre from its middle

static var _found := {}             # id -> Node3D (pruned as nodes go)
static var _scanned_frame := -1


## Every carrier standing in the scene now: {id: node}. Scanned at most once a frame.
static func found(tree: SceneTree) -> Dictionary:
	if Engine.get_process_frames() != _scanned_frame:
		_scanned_frame = Engine.get_process_frames()
		_found.clear()
		if tree.current_scene != null:
			_scan(tree.current_scene)
	return _found


static func _scan(node: Node) -> void:
	if node is Node3D and CARRIERS.has(node.scene_file_path) and (node as Node3D).is_visible_in_tree():
		var at := (node as Node3D).global_position
		_found[ThingActions.id_of(CARRIERS[node.scene_file_path], at.x, at.z)] = node
		return
	for child in node.get_children():
		_scan(child)


static func ids(tree: SceneTree) -> Array:
	var out := found(tree).keys()
	out.sort()
	return out


## Things within reach of a contact (a point, or a swept segment from origin to end), facing forward when given:
## [{thing, at, origin, distance_dm}], nearest first.
static func measure(tree: SceneTree, origin: Vector3, reach: float, forward := Vector3.ZERO, end := Vector3.INF, aperture := 0.35) -> Array:
	var start2 := Vector2(origin.x, origin.z)
	var end2 := start2 if end == Vector3.INF else Vector2(end.x, end.z)
	var out := []
	for id: String in found(tree):
		var node: Node3D = _found[id]
		var at := node.global_position
		var travel := end2 - start2
		var t := clampf((Vector2(at.x, at.z) - start2).dot(travel) / travel.length_squared(), 0, 1) if travel.length_squared() > 0.000001 else 0.0
		var point := start2 + travel * t
		var to := Vector2(at.x, at.z) - point
		var gap := maxf(0.0, to.length() - REACH_PAD)
		if gap > reach:
			continue
		if end == Vector3.INF and forward.length_squared() > 0.001 and to.length() > 0.9 and to.normalized().dot(Vector2(forward.x, forward.z).normalized()) < aperture:
			continue
		out.append({"thing": id, "at": at, "origin": Vector3(point.x, origin.y, point.y), "distance_dm": roundi(gap * 10.0)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance_dm < b.distance_dm or (a.distance_dm == b.distance_dm and a.thing < b.thing))
	return out

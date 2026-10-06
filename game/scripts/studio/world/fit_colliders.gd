extends RefCounted
## Colliders for what is drawn at a creature's height but stands outside a structure's own box (plan LIVELY-VILLAGE 1.2;
## his note 233349: "enemies get stuck in and under structures so much, its not good."): the fences, posts, barrels
## and steps round Enea's houses, the scaffold's frame, the butcher's rack. Measured, not guessed: the boxes below are
## `--stuck-probe=audit,bake` (studio creatures/stuck_probe.gd) - every cell drawn at 0.3 or 0.9 m above the ground
## that is neither solid nor beside a solid cell, merged into rectangles, in the structure's own frame (x0, z0, x1,
## z1, metres). The scaffold's is its whole frame, so nothing walks in among its posts. A roof's overhang is open
## ground and stays (it is above the measured heights).
## Enea's files call add() in one marked line each: world/village.gd (the houses), world/project_site.gd (the scaffold),
## world/butcher.gd, world/workbench.gd. Re-bake after a model changes; the audit's open_m2 says when one has (the
## finished smithy: --stuck-probe=audit,built,bake).
const HEIGHT := 1.2          # metres: up to a creature's back and a little over (the camera passes above)
const BAKED := {
	"house_cottage": [[-4.0, -1.0, -3.5, -0.75], [-4.0, 0.75, -3.5, 1.0], [-3.5, 0.25, -3.25, 0.75], [-3.5, 1.25, -3.25, 1.5], [-3.5, 1.0, -3.0, 1.25], [-3.25, -0.5, -2.75, -0.25], [-3.25, -0.25, -3.0, 0.25], [-2.5, 4.25, -2.25, 4.5], [-1.5, 4.25, -1.25, 4.5], [1.25, 4.25, 2.0, 4.5], [2.25, 4.25, 2.5, 4.5], [-1.0, 2.75, -0.75, 3.0], [0.5, 2.75, 0.75, 3.0], [-0.75, 2.0, -0.5, 2.25]],
	"house_cabin": [[-3.25, -0.25, -2.5, 0.0], [-3.25, 0.5, -2.5, 0.75], [-3.25, 0.75, -3.0, 1.0], [-3.0, 0.0, -2.5, 0.5], [-2.25, -2.25, -2.0, -2.0], [-2.25, 3.25, -2.0, 3.5], [2.0, -2.25, 2.25, -2.0], [-0.5, 3.25, -0.25, 3.5], [1.0, 3.25, 1.25, 3.5], [1.75, 3.25, 2.0, 3.5], [2.5, -1.0, 2.75, -0.75]],
	"house_round": [[-2.0, 2.5, -1.75, 2.75]],
	"house_hill": [[-4.0, -0.5, -3.75, 0.0], [-3.5, -1.75, -3.25, -1.5], [-3.5, -0.5, -3.25, 0.0], [-3.5, 1.0, -3.25, 1.5], [-3.75, -1.5, -3.5, -1.25], [-3.75, 0.75, -3.5, 1.0], [-3.75, -1.25, -3.25, -0.5], [-3.75, 0.0, -3.25, 0.75], [3.5, -1.0, 3.75, -0.75], [3.25, -1.75, 3.5, -1.5], [3.25, -0.75, 3.5, -0.5], [-2.25, -3.0, -2.0, -2.75], [-1.75, -3.0, -1.25, -2.75], [1.25, -3.0, 1.75, -2.75], [2.0, -3.0, 2.25, -2.75], [-2.0, -3.25, -1.5, -3.0], [-1.25, -3.25, 1.25, -3.0], [1.5, -3.25, 2.0, -3.0], [-1.5, -3.5, 1.5, -3.25], [-1.0, 2.75, 1.0, 3.0], [1.75, 3.75, 2.0, 4.0]],
	"house_lodge": [[-3.0, -2.75, -2.75, 2.75], [2.75, -2.0, 3.0, -1.75], [-2.5, -3.0, -2.25, -2.75], [2.25, -3.0, 2.5, -2.75], [-2.25, 2.75, -1.75, 3.0], [1.75, 2.75, 2.25, 3.0], [-2.25, 3.0, -2.0, 3.25], [1.75, 3.0, 2.0, 3.25]],
	"windmill": [[0.5, -2.5, 0.75, -2.25], [0.75, 2.25, 1.25, 2.5], [1.5, 2.25, 1.75, 2.5], [2.25, -0.5, 2.5, -0.25]],
	"house_loaf": [[1.0, 2.0, 1.25, 2.25]],
	"scaffold": [[-2.25, -2.75, 2.0, 1.75]],
	"smithy": [[-4.25, -0.75, -4.0, -0.25], [-3.75, -0.75, -3.5, -0.5], [3.5, -0.5, 4.25, -0.25], [-4.0, -1.0, -3.75, -0.75], [-3.5, -2.0, -3.25, -1.5], [3.5, -1.75, 3.75, -1.5], [3.5, -0.25, 3.75, 0.25], [-2.0, -3.0, -1.75, -2.5], [-1.5, -3.0, -1.25, -2.75], [0.0, -3.25, 0.25, -2.75], [2.0, -3.0, 2.25, -2.75], [1.75, -2.75, 2.0, -2.25], [-1.75, -3.25, -1.5, -3.0], [0.25, -3.5, 0.5, -3.25]],
	"workbench": [[-2.0, 0.0, -1.5, 0.25], [-2.0, 0.25, -1.75, 0.5], [-1.75, -0.25, -1.5, 0.0], [-1.5, -0.5, -1.25, -0.25]],
	"butcher": [[1.25, -0.25, 1.5, 0.0], [-1.5, -0.25, -1.25, 0.0], [1.75, 0.5, 2.0, 0.75], [2.0, 0.75, 2.25, 1.0], [1.5, 0.75, 1.75, 1.0], [-2.25, 0.75, -1.75, 1.0], [2.0, 1.25, 2.25, 1.5], [-1.75, 0.75, -1.5, 1.25], [2.25, 1.0, 2.5, 1.25]],
}


## The ground a structure's box colliders cover (all of them under `node`: its own, ours, a board's), in world x and z:
## their bounds, a turned box by its corners. For a router that goes round it (studio stage.gd _build_blocks). An
## empty Rect2 when it has none.
static func ground_of(node: Node3D) -> Rect2:
	var out := Rect2()
	var first := true
	for cs: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
		var box := cs.shape as BoxShape3D
		if box == null or cs.disabled:
			continue
		var h := box.size * 0.5
		for c: Vector3 in [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]:
			var w := cs.global_transform * c
			if first:
				out = Rect2(Vector2(w.x, w.z), Vector2.ZERO)
				first = false
			else:
				out = out.expand(Vector2(w.x, w.z))
	return out


## Adds `key`'s boxes to `node` (one static body; none when nothing is baked for it).
static func add(node: Node3D, key: String) -> void:
	var rects: Array = BAKED.get(key, [])
	if rects.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "StudioFit"
	for r: Array in rects:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(r[2]) - float(r[0]), HEIGHT, float(r[3]) - float(r[1]))
		cs.shape = box
		cs.position = Vector3((float(r[0]) + float(r[2])) * 0.5, HEIGHT * 0.5, (float(r[1]) + float(r[3])) * 0.5)
		body.add_child(cs)
	node.add_child(body)

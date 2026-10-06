extends RefCounted
## UNROUTED 5 Oct (the desk, 18:03 UTC: a fixture of facts lives in proof or check files, never in the game's runtime
## path). Kept, not deleted: graphics S4's web smoke at d2b169b ran it (evidence s4/web/). It was: dev-only
## --studio-things-demo (with --studio-things=on) built the four carriers in front of the camera, as Enea's builders
## build them, and stood in for Body's thing facts with one state each: the fence burning, the bench scorched and
## soaked, the crates scorched, the rack broken. Nothing calls it now.

const MODELS := ["res://assets/props/fence.glb", "res://assets/props/bench.glb", "res://assets/camp/camp_crates.glb",
	"res://assets/camp/camp_rack.glb"]
const TREASURE := preload("res://scripts/world/treasure.gd")


static func wanted() -> bool:
	return "--studio-things-demo" in OS.get_cmdline_user_args()


static func build(things: Node) -> void:
	var main := things.get_parent()
	var player: Node3D = main.get_node_or_null("Player")
	if player == null:
		return
	var holder := Node3D.new()
	holder.name = "ThingDemo"
	main.add_child(holder)
	var roots: Array[Node3D] = []
	var cam := main.get_viewport().get_camera_3d()
	for i in MODELS.size():
		var m := TREASURE._solid((load(MODELS[i]) as PackedScene).instantiate())
		holder.add_child(m)
		var at := player.global_position + Vector3((float(i) - 1.5) * 2.4 + 3.0, 0.0, 4.0)
		if cam != null:                          # in view of whatever camera shows the world (the title's included)
			var ahead := -cam.global_basis.z
			ahead.y = 0.0
			at = cam.global_position + ahead.normalized() * 6.0 + cam.global_basis.x * (float(i) - 1.5) * 2.2
		var space := (main as Node3D).get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at - Vector3.UP * 30.0))
		m.global_position = hit.position if not hit.is_empty() else at
		roots.append(m)
	var start := Time.get_ticks_msec()
	things.set("facts_source", func() -> Dictionary:
		var out := {}
		for i in roots.size():
			if not is_instance_valid(roots[i]) or not roots[i].has_meta("studio_thing"):
				continue
			var id: String = roots[i].get_meta("studio_thing")
			var f := func(kind: String, fields: Dictionary) -> Dictionary:
				var d := {"kind": kind, "id": kind + ":" + id, "deed": "demo", "cause_id": "demo", "revision": 1,
					"since_tick": start - 6000, "strength": 1000, "at": [0.0, 0.0]}
				d.merge(fields, true)
				return d
			match i:
				0: out[id] = {"burning": f.call("burning", {"heat": 900}), "scorched": f.call("scorched", {"level": 500})}
				1: out[id] = {"scorched": f.call("scorched", {"level": 600}), "soaked": f.call("soaked", {"method": "water"})}
				2: out[id] = {"scorched": f.call("scorched", {"level": 800})}
				3: out[id] = {"broken": f.call("broken", {"by": "blow"}), "scorched": f.call("scorched", {"level": 300})}
		return out)

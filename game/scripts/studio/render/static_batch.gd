class_name StaticBatch
extends Node
## Graphics S1 (studio plan GRAPHICS-STAGES-2026-10-04.md): the region's still meshes drawn merged, a few per 60 m
## cell instead of one per prop or plant. One pass after the region is built (main.gd's marked line) finds them wherever
## they came from, so Enea's current and future content is covered without touching his builders.
##
##   props: a MeshInstance3D under the region, shown, opaque, unskinned, with no overlay or transparency, uniformly
##     scaled, every surface on a material the merge can carry (below); not inside a character, an interactable, an
##     AnimationPlayer's scene or the group studio_no_batch; and still for the first frames after the region is built.
##   scatter: every multimesh of the Scatter that holds no tree and no gatherable (those are chopped, mined and faded
##     one instance at a time, so they stay as they are). Each instance is baked with its own tint.
##   materials: Enea's solid shader, drawn by render/batched_solid.gdshader (a copy of his that takes the colour, his
##     albedo times the instance's tint, and each vertex's sway from the vertex, so it looks and moves exactly as his;
##     glowing surfaces on their own surface); a flat-coloured StandardMaterial3D (alike
##     materials share one surface, each colour baked per vertex); any other opaque StandardMaterial3D as itself.
##   merged: per cell (the scatter's own 60 m grid), shadow mode and visibility range, one mesh, one surface per
##     material. LODs: a level at every edge length a part has, each part at its own coarsest LOD for that level.
##   lights: a cell meeting more than 6 point, 6 spot or 1 shadowed light (lit or not) is split in four, down to 15 m.
##   originals: kept, hidden by render layers (0), so collision, groups, scripts and his own show and hide keep working.
##     A member that is hidden, freed or moved (props are checked every frame, after everything else) is given back
##     its layers at once and its cell re-merges a moment later.
## Switch: project setting studio/render/batch_static (on when absent), or the dev argument --studio-batch=off|on.
## Off: nothing is added; today's scene exactly.

const SETTING := "studio/render/batch_static"
const CELL := 60.0
const MIN_CELL := 15.0
const SETTLE_FRAMES := 10        # a prop must stand still this long after the region is built; the gather that follows
                                 # runs while the game's loading cover (Warmup, its first 14 frames) still hides the scene
const REMERGE_AFTER := 0.4       # seconds a dirty cell waits before it re-merges
const MERGE_BUDGET_MS := 4.0     # merging spends about this much of a frame, then waits for the next
## Baked vertices one scatter multimesh may become. Instancing draws a dense plant (the two tall grasses, about 5,500
## each per cell) with a fraction of the memory a baked copy takes, so those stay instanced (measured 5 Oct: all free
## scatter baked cost 24 MB of buffers for 18 draw calls).
const SCATTER_BAKE_MAX := 2500
const MAX_OMNI := 6
const MAX_SPOT := 6
const MAX_SHADOWED := 1
const SOLID := preload("res://shaders/foliage_solid.gdshader")
const BATCHED := preload("res://scripts/studio/render/batched_solid.gdshader")
const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")
const SKIP_TOPS := ["Player", "Enemies", "VillageLive", "HUD", "CameraRig", "Terrain", "Scatter", "ResourceVisuals"]

var region: Node3D
var frozen := false               # the draw probe's measurements: its own hiding is not the game's, so it is ignored
var skipped := {}                 # why candidates were not batched: reason -> count
var stats := {}
var _members := {}                # instance id -> {node, layers, xf, cell, multi}
var _cells := {}                  # cell key -> {members: Array[int], mesh, size, lights, bytes}
var _dirty := {}                  # cell key -> seconds until re-merge
var _solid_mat: ShaderMaterial
var _glow_mat: ShaderMaterial
var _flats := {}                  # signature -> the shared flat-colour material
var _signatures := {}             # material instance id -> signature
var _shown_originals := false
var _animated := {}               # instance ids of nodes with an AnimationPlayer child: their scenes move


static func enabled() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--studio-batch=off":
			return false
		if arg == "--studio-batch=on":
			return true
	return bool(ProjectSettings.get_setting(SETTING, true))


## main.gd's marked line, once the region is built.
static func attach(main: Node3D) -> void:
	ThingState.attach(main)      # graphics S4, behind its own switch (on when absent, Hilmi 5 Oct): things that burn, soak, break
	HouseVariety.attach(main)    # graphics S5, behind its own switch (preset when absent): the village's houses from the grammar
	if not enabled() or main.has_node("StudioBatch"):
		return
	var b := StaticBatch.new()
	b.name = "StudioBatch"
	b.region = main
	main.add_child(b)


func _ready() -> void:
	process_priority = 1000     # after everything else in the frame: a prop that moved is caught before drawing
	_solid_mat = ShaderMaterial.new()
	_solid_mat.shader = BATCHED
	_glow_mat = _solid_mat.duplicate() as ShaderMaterial
	_glow_mat.set_shader_parameter("glow", 1.2)
	set_process(false)
	var still := {}
	for mi: MeshInstance3D in region.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree() and mi.get_viewport() == region.get_viewport():
			still[mi.get_instance_id()] = [mi, mi.global_transform, mi.is_visible_in_tree()]
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var cover = region.get_node_or_null("Warmup")      # his loading cover; read only
	var rect = cover.get("_cover") if cover != null else null
	stats["under_cover"] = rect != null and is_instance_valid(rect) and rect is CanvasItem and (rect as CanvasItem).modulate.a >= 0.999
	for ap in region.find_children("*", "AnimationPlayer", true, false):
		_animated[(ap as Node).get_parent().get_instance_id()] = true
	for id: int in still:
		var e: Array = still[id]
		if not is_instance_valid(e[0]):      # (the live village frees and rebuilds some meshes in its first frames)
			_count("freed while settling")
			continue
		var mi: MeshInstance3D = e[0]
		var why := _ineligible(mi)
		if why == "" and (mi.is_visible_in_tree() != e[2] or not mi.global_transform.is_equal_approx(e[1])):
			why = "moved or toggled while settling"
		_count(why)
		if why == "":
			_join(mi, false)
	for mmi in _scatter_candidates():
		_join(mmi, true)
	for key: String in _cells.keys():
		_split_for_lights(key)
	stats["gather_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	# Cells merge a few a frame within a small budget, so no frame hitches; until its cell merges, a member draws itself.
	var worst := 0.0
	var total := 0.0
	var spent := 0.0
	for key: String in _cells.keys():
		var t := Time.get_ticks_usec()
		_merge(key)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		total += ms
		worst = maxf(worst, ms)
		spent += ms
		if spent >= MERGE_BUDGET_MS:
			spent = 0.0
			await get_tree().process_frame
	stats["merge_ms"] = total
	stats["worst_cell_ms"] = worst
	stats["build_ms"] = stats["gather_ms"] + total
	set_process(true)


func _count(why: String) -> void:
	if why != "":
		skipped[why] = int(skipped.get(why, 0)) + 1


## Why a prop stays as it is ("" when it can be batched).
func _ineligible(mi: MeshInstance3D) -> String:
	if mi.mesh == null:
		return "no mesh"
	if mi.skin != null:
		return "skinned"
	if mi.material_overlay != null or mi.transparency > 0.0 or mi.layers == 0:
		return "overlay, transparency or no layers"      # (a material_override is the material its surfaces draw with)
	var s := mi.global_basis.get_scale()
	if absf(s.x - s.y) > 1e-3 * absf(s.y) or absf(s.z - s.y) > 1e-3 * absf(s.y):
		return "scaled unevenly"          # his shader lights by the model matrix: only a uniform scale bakes exactly
	var a: Node = mi
	while a != null and a != region:
		if a.get_parent() == region and str(a.name) in SKIP_TOPS:
			return "under " + str(a.name)
		if a.is_in_group("studio_no_batch"):
			return "group studio_no_batch"
		if a.is_in_group("interactable"):
			return "interactable"
		if _animated.has(a.get_instance_id()):
			return "animated scene"
		var sc: Script = a.get_script()
		if sc != null and sc.resource_path.ends_with("character_visual.gd"):
			return "a character"
		a = a.get_parent()
	for i in mi.mesh.get_surface_count():
		if _format(mi.mesh, i) & Mesh.ARRAY_FORMAT_BONES or _primitive(mi.mesh, i) != Mesh.PRIMITIVE_TRIANGLES:
			return "bones or not triangles"
		if _surface_key(mi.get_active_material(i), mi.mesh, i) == "":
			return "material " + _describe(mi.get_active_material(i))
	return ""


## The Scatter's multimeshes that hold no tree and no gatherable.
func _scatter_candidates() -> Array:
	var scatter := region.get_node_or_null("Scatter")
	if scatter == null:
		return []
	var locked := {}
	for list_name in ["trees", "gatherables"]:
		var list = scatter.get(list_name)
		if list is Array:
			for e: Dictionary in list:
				if e.get("multimesh") != null:
					locked[(e["multimesh"] as Object).get_instance_id()] = true
	var out := []
	for n in scatter.get_children():
		if not n is MultiMeshInstance3D:
			continue
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		var why := ""
		if mm == null or mm.mesh == null or mm.instance_count == 0:
			why = "scatter: empty"
		elif locked.has(mm.get_instance_id()):
			why = "scatter: holds a tree or a gatherable"
		elif mm.instance_count * _vertex_count(mm.mesh) > SCATTER_BAKE_MAX:
			why = "scatter: too dense to bake (instancing is cheaper)"
		elif not mmi.is_visible_in_tree() or mmi.layers == 0 or mmi.material_override != null \
				or mmi.material_overlay != null or mmi.transparency > 0.0 or mm.transform_format != MultiMesh.TRANSFORM_3D:
			why = "scatter: hidden, overridden or 2D"
		else:
			for i in mm.mesh.get_surface_count():
				if _primitive(mm.mesh, i) != Mesh.PRIMITIVE_TRIANGLES or _surface_key(mm.mesh.surface_get_material(i), mm.mesh, i) == "":
					why = "scatter: material " + _describe(mm.mesh.surface_get_material(i))
					break
		_count(why)
		if why == "":
			out.append(mmi)
	return out


static func _vertex_count(mesh: Mesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		n += int(RenderingServer.mesh_get_surface(mesh.get_rid(), i).get("vertex_count", 0))
	return n


## "solid", "glow", "flat:<format>:<signature>", "std:<id>:<format>" or "" (not mergeable).
func _surface_key(m: Material, mesh: Mesh, i: int) -> String:
	if m is ShaderMaterial and (m as ShaderMaterial).shader == SOLID:
		var sm := m as ShaderMaterial
		if float(_param(sm, "flash", 0.0)) != 0.0 or float(_param(sm, "warn", 0.0)) != 0.0:
			return ""
		var fmt := _format(mesh, i)
		if not (fmt & Mesh.ARRAY_FORMAT_TEX_UV) or not (fmt & Mesh.ARRAY_FORMAT_TEX_UV2):
			return ""
		var glow := float(_param(sm, "glow", 0.0))
		if glow == 0.0:
			return "solid"            # swaying or not: the batched shader carries each vertex's sway
		return "glow" if is_equal_approx(glow, 1.2) else ""
	if m is StandardMaterial3D:
		var std := m as StandardMaterial3D
		if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or std.normal_enabled or std.cull_mode != BaseMaterial3D.CULL_BACK:
			return ""
		var fmt := _format(mesh, i) & (Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2)
		if std.albedo_texture == null and not std.vertex_color_use_as_albedo:
			return "flat:%d:%s" % [fmt, _signature(std)]
		return "std:%d:%d" % [std.get_instance_id(), fmt]
	return ""


func _describe(m: Material) -> String:
	if m is ShaderMaterial:
		return "shader " + ((m as ShaderMaterial).shader.resource_path.get_file() if (m as ShaderMaterial).shader else "none")
	return m.get_class() if m != null else "none"


## Every stored property of a material but its albedo colour (and its name), so alike materials share a key.
func _signature(m: Material) -> String:
	var id := m.get_instance_id()
	if not _signatures.has(id):
		var parts: PackedStringArray = []
		for prop: Dictionary in m.get_property_list():
			var n: String = prop["name"]
			if not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE) or n in ["albedo_color", "resource_name", "resource_path",
					"resource_local_to_scene", "script"]:
				continue
			parts.append("%s=%s" % [n, var_to_str(m.get(n))])
		_signatures[id] = str(hash(",".join(parts)))
	return _signatures[id]


func _param(sm: ShaderMaterial, p: String, fallback: Variant) -> Variant:
	var v = sm.get_shader_parameter(p)
	return v if v != null else fallback


## A surface's format and primitive, for any Mesh (an imported ArrayMesh, or a box, cylinder or sphere).
static func _format(mesh: Mesh, i: int) -> int:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_format(i)
	return int(RenderingServer.mesh_get_surface(mesh.get_rid(), i).get("format", 0))


static func _primitive(mesh: Mesh, i: int) -> int:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_primitive_type(i)
	return int(RenderingServer.mesh_get_surface(mesh.get_rid(), i).get("primitive", Mesh.PRIMITIVE_TRIANGLES))


func _bounds(node: GeometryInstance3D) -> AABB:
	if node is MultiMeshInstance3D:
		return node.global_transform * (node as MultiMeshInstance3D).multimesh.get_aabb()
	return node.global_transform * (node as MeshInstance3D).get_aabb()


func _cell_key(node: GeometryInstance3D, size: float) -> String:
	var p := _bounds(node).get_center()
	return "%d|%.0f|%d|%d|%d" % [node.cast_shadow, node.visibility_range_end, floori(p.x / size), floori(p.z / size), int(size)]


func _join(node: GeometryInstance3D, multi: bool) -> void:
	var key := _cell_key(node, CELL)
	if not _cells.has(key):
		_cells[key] = {"members": [], "mesh": null, "size": CELL}
	var id := node.get_instance_id()
	var cb := _left.bind(id)
	_members[id] = {"node": node, "layers": node.layers, "xf": node.global_transform, "cell": key, "multi": multi, "cb": cb}
	(_cells[key]["members"] as Array).append(id)
	node.visibility_changed.connect(cb)
	node.tree_exiting.connect(cb)


## Lights a cell's bounds meet, lit or not: Vector3i(point, spot, shadowed).
var _light_nodes: Array = []
func _lights(aabb: AABB) -> Vector3i:
	var n := Vector3i.ZERO
	if _light_nodes.is_empty():
		_light_nodes = region.find_children("*", "Light3D", true, false)
	for l in _light_nodes:
		if l is DirectionalLight3D or not is_instance_valid(l):
			continue
		var reach: float = float(l.get("omni_range")) if l is OmniLight3D else float(l.get("spot_range"))
		if aabb.grow(reach).has_point((l as Node3D).global_position):
			if l is OmniLight3D:
				n.x += 1
			else:
				n.y += 1
			if (l as Light3D).shadow_enabled:
				n.z += 1
	return n


func _aabb(ids: Array) -> AABB:
	var box := AABB()
	for k in ids.size():
		var b := _bounds(_members[ids[k]]["node"])
		box = b if k == 0 else box.merge(b)
	return box


func _split_for_lights(key: String) -> void:
	if not _cells.has(key):
		return
	var c: Dictionary = _cells[key]
	var n := _lights(_aabb(c["members"]))
	c["lights"] = n
	var size: float = c["size"]
	if (n.x <= MAX_OMNI and n.y <= MAX_SPOT and n.z <= MAX_SHADOWED) or size / 2.0 < MIN_CELL:
		return
	_cells.erase(key)
	var made: Array[String] = []
	for id: int in c["members"]:
		var k := _cell_key(_members[id]["node"], size / 2.0) + "|s"
		if not _cells.has(k):
			_cells[k] = {"members": [], "mesh": null, "size": size / 2.0}
			made.append(k)
		(_cells[k]["members"] as Array).append(id)
		_members[id]["cell"] = k
	for k in made:
		_split_for_lights(k)


## The material a member's surface draws with.
func _material(id: int, i: int) -> Material:
	var m: Dictionary = _members[id]
	if m["multi"]:
		return (m["node"] as MultiMeshInstance3D).multimesh.mesh.surface_get_material(i)
	return (m["node"] as MeshInstance3D).get_active_material(i)


func _mesh_of(id: int) -> Mesh:
	var m: Dictionary = _members[id]
	return (m["node"] as MultiMeshInstance3D).multimesh.mesh if m["multi"] else (m["node"] as MeshInstance3D).mesh


## Builds (or rebuilds) one cell's merged mesh from its members and hides them.
func _merge(key: String) -> void:
	var c: Dictionary = _cells[key]
	var ids: Array = c["members"]
	if c["mesh"] != null:
		(c["mesh"] as Node).queue_free()
		c["mesh"] = null
	if ids.is_empty():
		_cells.erase(key)
		return
	var groups := {}     # material key -> [[member id, surface index]]
	for id: int in ids:
		var mesh := _mesh_of(id)
		for i in mesh.get_surface_count():
			var mk := _surface_key(_material(id, i), mesh, i)
			if not groups.has(mk):
				groups[mk] = []
			groups[mk].append([id, i])
	var out_mesh := ArrayMesh.new()
	var bytes := 0
	var keys := groups.keys()
	keys.sort()
	for mk: String in keys:
		bytes += _add_surface(out_mesh, groups[mk], mk)
		var src := _material(groups[mk][0][0], groups[mk][0][1])
		var mat: Material = src
		if mk == "solid":
			mat = _solid_mat
		elif mk == "glow":
			mat = _glow_mat
		elif mk.begins_with("flat:"):
			mat = _flat_material(src as StandardMaterial3D)
		out_mesh.surface_set_material(out_mesh.get_surface_count() - 1, mat)
	var first: GeometryInstance3D = _members[ids[0]]["node"]
	var out := MeshInstance3D.new()
	out.name = "Batch_" + key.replace("|", "_")
	out.mesh = out_mesh
	out.cast_shadow = first.cast_shadow
	out.visibility_range_end = first.visibility_range_end
	out.visibility_range_end_margin = first.visibility_range_end_margin
	out.visibility_range_fade_mode = first.visibility_range_fade_mode
	out.top_level = true
	add_child(out)
	out.global_transform = Transform3D.IDENTITY
	out.visible = not _shown_originals
	c["mesh"] = out
	c["bytes"] = bytes
	for id: int in ids:
		var m: Dictionary = _members[id]
		(m["node"] as GeometryInstance3D).layers = 0 if not _shown_originals else int(m["layers"])


## One surface: every member's surface of this material, each instance baked into world space. Returns its bytes.
## Whole arrays are transformed and filled by the engine; only index offsets are added one by one.
func _add_surface(mesh: ArrayMesh, parts: Array, mk: String) -> int:
	var solid := mk == "solid" or mk == "glow"
	var flat := mk.begins_with("flat:")
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var colors := PackedColorArray()
	var sway_x := PackedVector3Array()
	var sway_z := PackedVector3Array()
	var heights := PackedFloat32Array()
	var index := PackedInt32Array()
	var placed := []
	var edges := {}
	for p: Array in parts:
		var id: int = p[0]
		var i: int = p[1]
		var member: Dictionary = _members[id]
		var mesh_in := _mesh_of(id)
		var mat := _material(id, i)
		var a := mesh_in.surface_get_arrays(i)
		var src_v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var src_n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var n := src_v.size()
		var src_i: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else _sequence(n)
		var lods := _lods(mesh_in, i)
		var albedo := Color.WHITE
		var sway := 0.0
		var h := PackedFloat32Array()
		if solid:
			var sm := mat as ShaderMaterial
			albedo = _param(sm, "albedo", Color(0.4, 0.58, 0.3))
			sway = float(_param(sm, "sway", 0.06))
			var sway_h := float(_param(sm, "sway_height", 6.0))
			h.resize(n)
			for k in n:          # his height factor, once per surface: clamp(y / sway_height)^2
				var f := clampf(src_v[k].y / sway_h, 0.0, 1.0)
				h[k] = f * f
		var instances := []      # [transform, tint]: a prop is one; a multimesh is every instance with its own tint
		if member["multi"]:
			var mmi: MultiMeshInstance3D = member["node"]
			var mm := mmi.multimesh
			for j in mm.instance_count:
				var tint := mm.get_instance_custom_data(j) if mm.use_custom_data else Color(0, 0, 0)
				if tint.r == 0.0 and tint.g == 0.0 and tint.b == 0.0:
					tint = Color.WHITE            # his shader: no custom data means no tint
				instances.append([mmi.global_transform * mm.get_instance_transform(j), tint])
		else:
			instances.append([(member["node"] as Node3D).global_transform, Color.WHITE])
		var fill := PackedColorArray()
		fill.resize(n)
		var fill3 := PackedVector3Array()
		fill3.resize(n)
		for inst: Array in instances:
			var xf: Transform3D = inst[0]
			var base := verts.size()
			verts.append_array(xf * src_v)
			normals.append_array(Transform3D(xf.basis.orthonormalized(), Vector3.ZERO) * src_n)
			if a[Mesh.ARRAY_TEX_UV] != null:
				uv.append_array(a[Mesh.ARRAY_TEX_UV])
			if a[Mesh.ARRAY_TEX_UV2] != null:
				uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
			if solid:
				fill.fill(albedo * (inst[1] as Color))
				colors.append_array(fill)
				fill3.fill(xf.basis.x * sway)
				sway_x.append_array(fill3)
				fill3.fill(xf.basis.z * sway * 0.5)
				sway_z.append_array(fill3)
				heights.append_array(h)
			elif flat:
				fill.fill((mat as StandardMaterial3D).albedo_color)
				colors.append_array(fill)
			elif a[Mesh.ARRAY_COLOR] != null:
				colors.append_array(a[Mesh.ARRAY_COLOR])
			index.append_array(_shifted(src_i, base))
			placed.append([base, src_i, lods])
			for lod: Array in lods:
				edges[lod[0]] = true
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if uv.size() == verts.size():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if uv2.size() == verts.size():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	if colors.size() == verts.size():
		arrays[Mesh.ARRAY_COLOR] = colors
	var flags := 0
	if solid:
		arrays[Mesh.ARRAY_CUSTOM0] = sway_x.to_byte_array().to_float32_array()
		arrays[Mesh.ARRAY_CUSTOM1] = sway_z.to_byte_array().to_float32_array()
		arrays[Mesh.ARRAY_CUSTOM2] = heights
		flags = (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	arrays[Mesh.ARRAY_INDEX] = index
	var levels := edges.keys()
	levels.sort()
	var lod_arrays := {}
	var lod_bytes := 0
	for edge: float in levels:
		var level := PackedInt32Array()
		for pl: Array in placed:
			var chosen: PackedInt32Array = pl[1]
			for lod: Array in pl[2]:
				if lod[0] <= edge:
					chosen = lod[1]
			level.append_array(_shifted(chosen, pl[0]))
		lod_arrays[edge] = level
		lod_bytes += level.size() * 4
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lod_arrays, flags)
	return verts.size() * 40 + colors.size() * 16 + sway_x.size() * 24 + heights.size() * 4 + index.size() * 4 + lod_bytes


## A surface's LODs, coarsest last: [[edge length in the mesh's own units, indices]].
func _lods(mesh: Mesh, i: int) -> Array:
	var out := []
	var sd: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), i)
	var count: int = sd.get("index_count", 0)
	var width := 2 if count > 0 and (sd["index_data"] as PackedByteArray).size() == count * 2 else 4
	for lod: Dictionary in sd.get("lods", []):
		out.append([float(lod["edge_length"]), VillagerBody._indices(lod["index_data"], width)])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	return out


## The shared material of a flat-colour surface: the first member's, reading its albedo from the vertex colours (as
## sRGB, the way albedo_color is given), so each part keeps its own colour.
func _flat_material(src: StandardMaterial3D) -> StandardMaterial3D:
	var key := _signature(src)
	if not _flats.has(key):
		var m := src.duplicate() as StandardMaterial3D
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		_flats[key] = m
	return _flats[key]


static func _shifted(indices: PackedInt32Array, by: int) -> PackedInt32Array:
	var out := indices.duplicate()
	if by != 0:
		for i in out.size():
			out[i] += by
	return out


static func _sequence(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		out[i] = i
	return out


## A member was hidden or shown by its own code, freed, or moved: it draws itself again, and its cell re-merges soon.
func _left(id: int) -> void:
	if frozen or not _members.has(id):
		return
	var m: Dictionary = _members[id]
	_members.erase(id)
	if is_instance_valid(m["node"]):
		var node: GeometryInstance3D = m["node"]
		node.layers = int(m["layers"])
		if node.visibility_changed.is_connected(m["cb"]):
			node.visibility_changed.disconnect(m["cb"])
		if node.tree_exiting.is_connected(m["cb"]):
			node.tree_exiting.disconnect(m["cb"])
	var key: String = m["cell"]
	if _cells.has(key):
		(_cells[key]["members"] as Array).erase(id)
		_dirty[key] = REMERGE_AFTER
	stats["left"] = int(stats.get("left", 0)) + 1


func _process(delta: float) -> void:
	if frozen:
		return
	for id: int in _members.keys():
		var m: Dictionary = _members[id]
		if m["multi"]:
			continue          # scatter does not move; a multimesh that is hidden or freed signals
		if not is_instance_valid(m["node"]) or not (m["node"] as Node3D).global_transform.is_equal_approx(m["xf"]):
			_left(id)
	for key: String in _dirty.keys():
		_dirty[key] -= delta
		if _dirty[key] <= 0.0:
			_dirty.erase(key)
			if _cells.has(key):
				_merge(key)


## Checks only: the originals drawn instead of the batches (true), or the batches (false), in place.
func show_originals(on: bool) -> void:
	_shown_originals = on
	for id: int in _members:
		var m: Dictionary = _members[id]
		(m["node"] as GeometryInstance3D).layers = int(m["layers"]) if on else 0
	for key: String in _cells:
		if _cells[key]["mesh"] != null:
			(_cells[key]["mesh"] as MeshInstance3D).visible = not on


## A member given back to its own drawing for good, as if it had moved (graphics S4: a thing with state draws itself).
func release(node: Node) -> void:
	if node != null and _members.has(node.get_instance_id()):
		_left(node.get_instance_id())


## For the checks: members by kind, per cell its members, surfaces, bytes and the lights its bounds meet.
func report() -> Dictionary:
	var cells := []
	var bytes := 0
	var props := 0
	for id: int in _members:
		if not _members[id]["multi"]:
			props += 1
	for key: String in _cells:
		var c: Dictionary = _cells[key]
		var mesh: MeshInstance3D = c["mesh"]
		var l: Vector3i = c.get("lights", Vector3i.ZERO)
		bytes += int(c.get("bytes", 0))
		cells.append({"key": key, "members": (c["members"] as Array).size(),
			"surfaces": mesh.mesh.get_surface_count() if mesh != null else 0, "bytes": c.get("bytes", 0),
			"lights": [l.x, l.y, l.z]})
	return {"members": _members.size(), "props": props, "scatter": _members.size() - props, "cells": cells,
		"bytes": bytes, "build_ms": stats.get("build_ms", 0.0), "gather_ms": stats.get("gather_ms", 0.0),
		"merge_ms": stats.get("merge_ms", 0.0), "worst_cell_ms": stats.get("worst_cell_ms", 0.0), "left": stats.get("left", 0),
		"skipped": skipped, "done": is_processing(), "under_cover": stats.get("under_cover", false)}

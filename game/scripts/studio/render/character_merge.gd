class_name CharacterMerge
extends Node
## Graphics S2 (studio plan GRAPHICS-STAGES-2026-10-04.md): a CharacterVisual's shown parts drawn as one merged
## mesh, the way villagers already draw. Enea's CharacterVisual draws each outfit part as its own MeshInstance3D
## (about 20 for the player, each casting its own shadow: 43 draws for the player at noon, S0); merged, the body is one
## surface (two when the look has glowing parts) and its shadow.
##
## The merge is the villager merge (village/villager_body.gd merged_mesh): one path, cached by model and look and
## shared with every villager wearing the same look. Nothing here builds a mesh.
##
## Wiring: CharacterVisual.apply_hero_look() calls after_look(self) (one marked proposal line). The adapter waits
## for the end of the frame, so it reads what apply_hero_look decided (which parts it showed, the colour it gave each
## slot) and never repeats his rules. Every CharacterVisual gets it alike: the player, Enea's NPCs (Morrow, Brakk,
## the Seeker, Wren ...), the talk screen's portrait, the build lab.
## Not merged: tools, the sword on the back, claws and held props (their own nodes, not the model's parts).
## Enea's own merge (CharacterVisual.merge = true: villagers, bandits, the merchant; his main since 5 Oct) is left to
## him: a visual his merge_parts joins is never merged twice, so this path takes the looks that change (the player,
## the portrait, the picker, his named characters without merge).
## Material effects: his flash() and set_warn() write uniforms on his slot materials. Each frame the adapter carries
## the flash value and the warn uniform to the merged mesh, on its own copies of the materials while either is on
## (the shared ones stay unlit for everyone else wearing the look).
## Switch: project setting studio/render/merge_characters (on when absent), or the dev argument --studio-merge=off|on.
## Off: nothing is added and every part stays as his code sets it: today's scene exactly.

const SETTING := "studio/render/merge_characters"
const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")

var visual: Node3D
var merged: MeshInstance3D       # the body, under the visual's skeleton
var _queued := false
var _probe: ShaderMaterial       # one of his slot materials: set_warn writes the same value to all of them
var _own: Array[ShaderMaterial] = []   # this body's material copies while it flashes or glows red
var _hidden: Array[MeshInstance3D] = []  # the parts apply_hero_look showed, hidden behind the merged body


static func enabled() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--studio-merge=off":
			return false
		if arg == "--studio-merge=on":
			return true
	return bool(ProjectSettings.get_setting(SETTING, true))


## CharacterVisual.apply_hero_look's first line. Merges at the end of this frame, after the function has run.
static func after_look(v: Node3D) -> void:
	if enabled():
		merge(v)


## The merge itself, switch or not (after_look, and the checks in character_merge_check.gd).
static func merge(v: Node3D) -> void:
	if v == null:
		return
	var m := v.get_node_or_null("StudioMerge") as CharacterMerge
	if m == null:
		m = CharacterMerge.new()
		m.name = "StudioMerge"
		m.visual = v
		v.add_child(m)
	if not m._queued:
		m._queued = true
		m._merge.call_deferred()


func _merge() -> void:
	_queued = false
	if not is_instance_valid(visual):
		return
	if visual.get("merge") == true or visual.get("_merged") == true:
		return              # Enea's own merge (CharacterVisual.merge_parts, his fixed looks) already drew it as one mesh
	var skeleton := visual.get("_skeleton") as Skeleton3D
	var parts: Array = visual.get("_parts")
	if skeleton == null or parts.is_empty():
		return              # before the visual's _ready: its own call there comes next
	var model: String = visual.get("body_model")
	if model == "":
		model = CharacterVisual.HERO
	var names: Array[String] = []
	var colors := {}        # slot -> the colour his slot material holds
	var shown: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in parts:
		if not mi.visible:
			continue
		shown.append(mi)
		names.append(String(mi.name))
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var slot := src.resource_name if src else ""
			var over := mi.get_surface_override_material(s) as ShaderMaterial
			colors[slot] = over.get_shader_parameter("albedo") if over != null else Color.WHITE
			if over != null:
				_probe = over
	if shown.is_empty():
		return
	if merged == null:
		merged = MeshInstance3D.new()
		merged.name = "StudioMerged"
		skeleton.add_child(merged)
		merged.skeleton = NodePath("..")
		merged.skin = VillagerBody.model_parts(model)["skin"]
	merged.cast_shadow = shown[0].cast_shadow     # a far bandit's parts cast none (bandit.gd); the body follows them
	_drop_own()                                   # copies of the last look's materials
	merged.mesh = VillagerBody.merged_mesh(model, names, colors)
	merged.visible = true
	for mi in shown:
		mi.visible = false
	_hidden = shown
	_carry()


## Checks only: his parts back on and the merged body off (true), or the merge as built (false), in place, so the
## same frame can be drawn both ways.
func show_parts(on: bool) -> void:
	for mi in _hidden:
		mi.visible = on
	if merged != null:
		merged.visible = not on


## The parts drawn behind the merged body, and what they hold, for the checks: names, vertices, surfaces.
func shown_parts() -> Array[MeshInstance3D]:
	return _hidden


func _process(_delta: float) -> void:
	if merged != null:
		_carry()


## The flash and the warn glow, from his visual to the merged body.
func _carry() -> void:
	var flash := float(visual.get("_flash"))
	var warn := 0.0
	if _probe != null:
		var w = _probe.get_shader_parameter("warn")
		warn = float(w) if w != null else 0.0
	if flash <= 0.0 and warn <= 0.0:
		_drop_own()
		return
	if _own.is_empty():
		for i in merged.mesh.get_surface_count():
			var copy := merged.mesh.surface_get_material(i).duplicate() as ShaderMaterial
			_own.append(copy)
			merged.set_surface_override_material(i, copy)
	for m in _own:
		m.set_shader_parameter("flash", flash)
		m.set_shader_parameter("warn", warn)


func _drop_own() -> void:
	if _own.is_empty():
		return
	for i in merged.get_surface_override_material_count():
		merged.set_surface_override_material(i, null)
	_own.clear()

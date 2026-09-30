class_name FloatText
extends Label3D
## A number or word that pops up over something in the world and floats away: damage on enemies
## (white, gold and bigger for a critical), "Parried!", "Blocked", "!" when spotted.
## FloatText.spawn(tree, position, "12", Color.WHITE)

var _life := 0.0
var _rise := Vector3.ZERO
const LIFE := 0.85


static func spawn(tree: SceneTree, at: Vector3, text_: String, tint := Color.WHITE, big := false) -> void:
	var f := FloatText.new()
	f.text = text_
	f.modulate = tint
	f.font_size = 64 if big else 44
	f.outline_size = 14
	f.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	f.pixel_size = 0.006
	f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.no_depth_test = true
	f.fixed_size = false
	f.render_priority = 5
	f.top_level = true
	f._rise = Vector3(randf_range(-0.5, 0.5), 1.6, randf_range(-0.5, 0.5))
	tree.current_scene.add_child(f)
	f.global_position = at + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
	f.scale = Vector3.ONE * (0.5 if big else 0.7)


func _process(delta: float) -> void:
	_life += delta
	var k := _life / LIFE
	global_position += _rise * delta * (1.0 - k)
	var pop := 1.35 if font_size > 50 else 1.0
	scale = Vector3.ONE * pop * (minf(_life * 9.0, 1.0) * (1.0 - 0.3 * k))
	modulate.a = 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
	if _life >= LIFE:
		queue_free()

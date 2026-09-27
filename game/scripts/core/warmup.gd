extends CanvasLayer
## Loading cover. While it's up, every effect is shown once near the camera (with and without
## sun shadows), so the phone prepares their shaders now instead of skipping a frame later.

@export var effects_root: Node        # searched for particle effects
@export var landmark: Node3D
@export var sun: DirectionalLight3D
@export var focus: Node3D

const WARM_FRAMES := 14

var _frame := 0
var _cover: ColorRect
var _landmark_home: Vector3
var _homes := {}          # particle -> its original local position


func _ready() -> void:
	layer = 50
	_cover = ColorRect.new()
	_cover.color = Color(0.08, 0.1, 0.21)
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	var title := Label.new()
	title.text = "Unbound"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 0.85))
	_cover.add_child(title)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 1:
		_landmark_home = landmark.global_position
		for p: CPUParticles3D in _particles():
			_homes[p] = p.position
	if _frame <= WARM_FRAMES:
		landmark.global_position = focus.global_position + Vector3(0, 0, -4)
		for p in _particles():
			p.emitting = true
			p.global_position = focus.global_position + Vector3(0, 1, 0)
		sun.shadow_enabled = _frame * 2 <= WARM_FRAMES
	elif _frame == WARM_FRAMES + 1:
		landmark.global_position = _landmark_home
		for p: CPUParticles3D in _particles():
			p.position = _homes.get(p, p.position)
			p.restart()
			p.emitting = false
		var fade := create_tween()
		fade.tween_property(_cover, "modulate:a", 0.0, 0.6)
		fade.tween_callback(queue_free)


func _particles() -> Array[Node]:
	return effects_root.find_children("*", "CPUParticles3D", true, false)

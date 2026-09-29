extends CanvasLayer
## Keeps the test phone's screen awake between device-lab runs without changing any phone setting: the
## game holds the screen on while it is in front (Godot's keep_screen_on), so this mode shows a dark
## screen with 3D switched off, at 2 frames a second, and a small label that drifts so nothing burns in.
## Dev argument --studio=keeper (debug builds). The device lab stops it before a test and starts it after.

var _label: Label
var _t := 0.0


static func on_device(tree: SceneTree) -> void:
	var keeper: CanvasLayer = (load("res://scripts/studio/keeper.gd") as GDScript).new()
	tree.root.add_child.call_deferred(keeper)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 2
	get_viewport().disable_3d = true
	get_tree().paused = true
	var dark := ColorRect.new()
	dark.color = Color.BLACK
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	_label = Label.new()
	_label.text = "studio device lab - keeping the screen awake"
	_label.modulate = Color(1, 1, 1, 0.25)
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	var size := get_viewport().get_visible_rect().size
	_label.position = Vector2((sin(_t * 0.05) * 0.4 + 0.5) * (size.x - 400.0), (cos(_t * 0.037) * 0.4 + 0.5) * (size.y - 40.0))

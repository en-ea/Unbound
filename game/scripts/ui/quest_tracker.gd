extends PanelContainer
## The quest you are on, small, in the top-left corner: its name and what to do next. Hidden with no quest.

var _title: Label
var _step: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.07, 0.1, 0.55)
	box.set_corner_radius_all(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	_title = UIStyle.label(column, "", 18)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_step = UIStyle.label(column, "", 16)
	Quests.changed.connect(_refresh)
	Classes.changed.connect(_refresh)
	Inventory.changed.connect(func(_i: String, _c: int) -> void: _refresh.call_deferred())
	_refresh()


func _refresh() -> void:
	var ids := Quests.active()
	if not Classes.awakened:                  # the story's first beat, before any quest
		visible = true
		_title.text = "A Strange Hum"
		_step.text = "The standing stones on the meadow hill are humming. Go and see (follow the beams of light)."
		return
	visible = not ids.is_empty()
	if visible:
		_title.text = Quests.DEFS[ids[0]]["name"]
		_step.text = Quests.step_text(ids[0])

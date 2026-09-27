extends Control
## Pickup feed: small pills under the FPS text ("● Wood  +3"). Repeat pickups of the same item
## merge into one pill and bump its count; pills fade out after a moment.

const INVENTORY_PANEL := preload("res://scripts/ui/inventory_panel.gd")
const LIFETIME := 2.6
const MAX_ROWS := 5
const TOP_LEFT := Vector2(64, 92)

var _rows := {}              # item -> {node: PanelContainer, amount: int, age: float, label: Label}
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.position = TOP_LEFT
	_box.add_theme_constant_override("separation", 6)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	Inventory.added.connect(_on_added)


func _on_added(item: String, amount: int) -> void:
	if _rows.has(item):
		var row: Dictionary = _rows[item]
		row["amount"] += amount
		row["age"] = 0.0
		row["label"].text = "+%d" % row["amount"]
		var pill: PanelContainer = row["node"]
		pill.modulate.a = 1.0
		pill.scale = Vector2(1.08, 1.08)
		pill.create_tween().tween_property(pill, "scale", Vector2.ONE, 0.15)
		return
	if _rows.size() >= MAX_ROWS:
		_remove(_oldest())
	_rows[item] = _make_row(item, amount)


func _process(delta: float) -> void:
	for item: String in _rows.keys():
		var row: Dictionary = _rows[item]
		row["age"] += delta
		var fade := clampf((LIFETIME - row["age"]) / 0.5, 0.0, 1.0)
		row["node"].modulate.a = fade
		if row["age"] >= LIFETIME:
			_remove(item)


func _make_row(item: String, amount: int) -> Dictionary:
	var rare := Items.rarity_of(item) != Items.Rarity.COMMON
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.12, 0.62)
	box.set_corner_radius_all(18)
	box.content_margin_left = 12
	box.content_margin_right = 16
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	if rare:
		box.border_color = Items.RARITY_COLORS[Items.rarity_of(item)]
		box.set_border_width_all(2)
	pill.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pill.add_child(h)
	h.add_child(INVENTORY_PANEL.item_icon(item, 34))
	var name_label := UIStyle.label(h, Items.name_of(item), 20)
	if rare:
		name_label.add_theme_color_override("font_color", Items.RARITY_COLORS[Items.rarity_of(item)])
	var amount_label := UIStyle.label(h, "+%d" % amount, 20, true)
	_box.add_child(pill)
	pill.pivot_offset = Vector2(0, 16)
	pill.modulate.a = 0.0
	pill.create_tween().tween_property(pill, "modulate:a", 1.0, 0.15)
	return {"node": pill, "amount": amount, "age": 0.0, "label": amount_label}


func _oldest() -> String:
	var oldest := ""
	var age := -1.0
	for item: String in _rows:
		if _rows[item]["age"] > age:
			age = _rows[item]["age"]
			oldest = item
	return oldest


func _remove(item: String) -> void:
	_rows[item]["node"].queue_free()
	_rows.erase(item)

extends PanelContainer
## The quest you follow, small, in the top-left corner: Story or Job, its name, what to do next and how
## far it is (the guide beam and the minimap diamond point the way). Tap it for the quest log, where you
## pick which quest to follow; the – folds it down to a small tab. Hidden with no quest.

const TAG_COLORS := {"story": Color(1.0, 0.78, 0.35), "job": Color(0.55, 0.8, 1.0)}

var hidden_for_talk := false     # the HUD hides it while the talk screen's portrait is up

var _full: VBoxContainer
var _tab: HBoxContainer
var _tags: Array[Label] = []
var _title: Label
var _tab_title: Label
var _count: Label
var _step: Label
var _where: Label
var _tick := 0.0


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.07, 0.1, 0.55)
	box.set_corner_radius_all(12)
	box.content_margin_left = 12
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", box)
	_full = VBoxContainer.new()
	_full.add_theme_constant_override("separation", 2)
	add_child(_full)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	_full.add_child(top)
	_tags.append(_chip(top))
	_title = UIStyle.label(top, "", 18)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = UIStyle.label(top, "", 14, true)
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fold_button(top, "–").pressed.connect(func() -> void: _fold(true))
	_step = UIStyle.label(_full, "", 16)
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step.custom_minimum_size.x = 320
	_where = UIStyle.label(_full, "", 14, true)
	_where.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 0.85))
	_tab = HBoxContainer.new()
	_tab.add_theme_constant_override("separation", 8)
	add_child(_tab)
	_tags.append(_chip(_tab))
	_tab_title = UIStyle.label(_tab, "", 16)
	_tab_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fold_button(_tab, "+").pressed.connect(func() -> void: _fold(false))
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			get_tree().call_group("hud", "open_quests"))
	Quests.changed.connect(refresh)
	Inventory.changed.connect(func(_i: String, _c: int) -> void: refresh.call_deferred())
	refresh()


func refresh() -> void:
	var id := Quests.tracked_quest()
	visible = id != "" and not hidden_for_talk
	if id == "":
		return
	var small := Settings.tracker_small
	_full.visible = not small
	_tab.visible = small
	var type := Quests.type_of(id)
	for tag in _tags:
		tag.text = Quests.TYPE_NAMES[type].to_upper()
		(tag.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = TAG_COLORS[type]
	_title.text = Quests.DEFS[id]["name"]
	_tab_title.text = _title.text
	var list := Quests.active()
	_count.visible = list.size() > 1
	_count.text = "%d of %d" % [list.find(id) + 1, list.size()]
	_step.text = Quests.step_text(id)
	_update_where()
	_shrink.call_deferred()


## Fit the box to its text (a wrapped label only knows its height after a layout pass).
func _shrink() -> void:
	size = get_combined_minimum_size()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0 and visible and _full.visible:
		_tick = 0.5
		_update_where()


## How far the next spot is, or which way out of this region it lies.
func _update_where() -> void:
	var g := Quests.guide_point(Quests.tracked_quest())
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_where.visible = not g.is_empty() and player != null
	if not _where.visible:
		return
	if g["gate"]:
		_where.text = "Follow the beam to the way into the %s" % Region.NAMES[g["to"]]
		return
	var d := Vector2(player.global_position.x, player.global_position.z).distance_to(g["at"])
	_where.text = "You're here" if d < 8.0 else "Follow the beam: %d m" % roundi(d)


func _fold(small: bool) -> void:
	Settings.set_tracker_small(small)
	refresh()


## The small coloured STORY / JOB tag.
func _chip(parent: Node) -> Label:
	var chip := UIStyle.label(parent, "", 12)
	chip.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 6
	bg.content_margin_right = 6
	bg.content_margin_top = 1
	bg.content_margin_bottom = 1
	chip.add_theme_stylebox_override("normal", bg)
	return chip


func _fold_button(parent: Node, text: String) -> Button:
	var b := UIStyle.button(parent, text, Vector2(40, 34), 20)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return b

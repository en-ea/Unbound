class_name WorldMap
extends Control
## The big map (tap the minimap, Menu > Map, or M; or Travel at a waystone): a region painted from its
## WorldShape, with its waystone, villages, places, bounty board, gates, your home, the Red Hand camp, where
## your quest wants you (gold) and you (the arrow). The regions are listed on the right: tap one to look at
## it. Opened at a woken waystone (`travel` true), each woken waystone has a Travel button (Waystones.travel).

signal closed

const PX := 180                       # the painted ground's pixels (it covers MinimapSPAN metres)
const SPAN := 200.0
const GREENS := {"meadow": Vector2(-1.0, 18.0)}
const WAY := Color(0.5, 0.95, 1.0)
const GOLD := Color(1.0, 0.8, 0.3)
const CREAM := Color(1.0, 0.96, 0.88)

static var _painted := {}             # region -> ImageTexture (painted once a session)

var travel := false                   # opened at a waystone: you can travel from here
var player: Node3D
var _region := ""
var _map: Control
var _list: VBoxContainer
var _title: Label


## The ground of a region as a picture: grass lighter on high ground, water, the path, clearings, trees,
## the land outside the walls darker. North (-z) is up. Used by the minimap too.
static func paint_ground(shape: WorldShape, trees: Array[Vector2], px: int, span: float) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			var p := (Vector2(x + 0.5, y + 0.5) / px - Vector2(0.5, 0.5)) * span
			var h := shape.height_at(p.x, p.y)
			var c := Color(0.4, 0.6, 0.3).lightened(clampf(h * 0.05, 0.0, 0.3))
			if h < WorldShape.WATER_Y:
				c = Color(0.36, 0.58, 0.78)
			elif shape.path_distance(p) < 1.6:
				c = Color(0.82, 0.72, 0.52)
			elif shape.in_clearing(p):
				c = Color(0.62, 0.66, 0.4)
			if maxf(absf(p.x), absf(p.y)) > WorldShape.PLAY_HALF:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	for t in trees:
		var m := Vector2i(((t + Vector2.ONE * span * 0.5) / span * px).floor())
		img.fill_rect(Rect2i(m, Vector2i(2, 2)), Color(0.18, 0.34, 0.16))
	return ImageTexture.create_from_image(img)


## A region's ground (painted the first time it's asked for). Other regions borrow their WorldShape for a
## moment, then the current one is put back.
static func ground(region: String) -> ImageTexture:
	if _painted.has(region):
		return _painted[region]
	var shape := WorldShape.new()
	WorldShape.use(region)
	shape._noise.seed = WorldShape.REGIONS[region]["seed"]
	var tex := paint_ground(shape, [] as Array[Vector2], PX, SPAN)
	WorldShape.use(Region.current)
	_painted[region] = tex
	return tex


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = get_tree().get_first_node_in_group("player")
	_region = Region.current
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 70
	row.offset_right = -70
	row.offset_top = 24
	row.offset_bottom = -24
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	_map = Control.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_stretch_ratio = 1.6
	_map.draw.connect(_draw_map)
	row.add_child(_map)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	var top := HBoxContainer.new()
	side.add_child(top)
	_title = UIStyle.label(top, "Map", 30)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.button(top, "Close", Vector2(110, 46), 20).pressed.connect(_close)
	UIStyle.label(side, "Travel from any woken waystone to another." if travel else
		"Wake the waystones (walk up to them), then travel between them from any one.", 15, true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	side.add_child(_list)
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for r: String in Region.NAMES:
		if not Waystones.STONES.has(r):             # the open sea has no waystone
			continue
		var card := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.12 if r == _region else 0.05)
		box.border_color = Color(1.0, 0.86, 0.5, 0.9) if r == _region else Color(1, 1, 1, 0.1)
		box.set_border_width_all(2)
		box.set_corner_radius_all(14)
		box.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", box)
		_list.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var name_row := HBoxContainer.new()
		v.add_child(name_row)
		var look := UIStyle.button(name_row, Region.NAMES[r] + ("  (you)" if r == Region.current else ""), Vector2(0, 44), 18)
		look.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		look.pressed.connect(func() -> void:
			_region = r
			_refresh())
		var stone: Dictionary = Waystones.STONES[r]
		var found := Waystones.is_found(r)
		var line := HBoxContainer.new()
		v.add_child(line)
		var l := UIStyle.label(line, (stone["name"] if found else "Waystone not woken yet"), 15, not found)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if found:
			l.add_theme_color_override("font_color", WAY)
		if travel and found:
			var here := r == Region.current
			var go := UIStyle.button(line, "You're here" if here else "Travel", Vector2(120, 42), 17)
			go.disabled = here
			go.pressed.connect(func() -> void:
				var why := Waystones.can_travel(player)
				if why != "":
					get_tree().call_group("hud", "hint", why)
					return
				_close()
				Waystones.travel(r, player))
	_map.queue_redraw()


func _process(_delta: float) -> void:
	if _region == Region.current:
		_map.queue_redraw()                  # you move (the arrow)


## Region metres -> a spot on the map.
func _to_map(rect: Rect2, at: Vector2) -> Vector2:
	return rect.position + (at / SPAN + Vector2(0.5, 0.5)) * rect.size


func _draw_map() -> void:
	var side := minf(_map.size.x, _map.size.y)
	var rect := Rect2(Vector2((_map.size.x - side) * 0.5, (_map.size.y - side) * 0.5), Vector2(side, side))
	_map.draw_rect(rect.grow(4.0), Color(0.86, 0.78, 0.6))
	_map.draw_texture_rect(ground(_region), rect, false)
	var font := get_theme_default_font()
	# Gates: an arrow at the edge and where it leads.
	for g: Dictionary in Region.GATES.get(_region, []):
		var p := _to_map(rect, g["at"])
		var inward := (rect.get_center() - p).normalized()
		_map.draw_colored_polygon(PackedVector2Array([p - inward * 10.0, p + inward * 6.0 + inward.orthogonal() * 8.0,
			p + inward * 6.0 - inward.orthogonal() * 8.0]), CREAM)
		_label(font, p + inward * 26.0, "To " + Region.NAMES[g["to"]], CREAM)
	# Places, villages, the board, the camp, your home.
	for pl: Dictionary in preload("res://scripts/world/places.gd").PLACES.get(_region, []):
		_mark(font, rect, pl["at"], pl["name"], Color(0.86, 0.62, 0.42), 5.0)
	if GREENS.has(_region):
		_mark(font, rect, GREENS[_region], "Village", Color(0.95, 0.7, 0.45), 8.0)
	if Bounties.BOARDS.has(_region):
		_mark(font, rect, Bounties.BOARDS[_region], "Bounties", Color(0.9, 0.82, 0.55), 4.0, Vector2(0, 16))
	if BanditCamp.CAMPS.has(_region):
		_mark(font, rect, BanditCamp.CAMPS[_region]["at"], BanditCamp.CAMPS[_region]["name"], Color(0.9, 0.3, 0.25), 7.0)
	if _region == "meadow":
		_mark(font, rect, Home.PLOT_CENTER, "Home" if Home.owned() else "Plot for sale", Color(0.55, 0.85, 0.55), 6.0)
	# The waystone: a glowing rune when woken, grey when not.
	var stone: Dictionary = Waystones.STONES[_region]
	var sp := _to_map(rect, stone["at"])
	var woke := Waystones.is_found(_region)
	_map.draw_circle(sp, 11.0, Color(0.05, 0.08, 0.12, 0.9))
	_map.draw_circle(sp, 8.0, WAY if woke else Color(0.55, 0.58, 0.62))
	_map.draw_circle(sp, 3.0, Color(0.05, 0.08, 0.12))
	_label(font, sp + Vector2(0, -20), "Waystone", WAY if woke else Color(0.8, 0.82, 0.85))
	# Where your quest wants you.
	var t := Quests.target(Quests.tracked_quest()) if Quests.tracked_quest() != "" else {}
	if not t.is_empty() and t["region"] == _region:
		var q := _to_map(rect, t["at"])
		var k := 9.0
		var diamond := PackedVector2Array([q + Vector2(0, -k), q + Vector2(k, 0), q + Vector2(0, k), q + Vector2(-k, 0)])
		_map.draw_colored_polygon(diamond, GOLD)
		_map.draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(0.2, 0.12, 0.05), 2.0)
	# You.
	if _region == Region.current and is_instance_valid(player):
		var me := _to_map(rect, Vector2(player.global_position.x, player.global_position.z))
		var yaw: float = player.visual.rotation.y
		var fwd := Vector2(sin(yaw), cos(yaw))
		var s := fwd.orthogonal()
		var arrow := PackedVector2Array([me + fwd * 12.0, me - fwd * 7.0 + s * 8.0, me - fwd * 3.0, me - fwd * 7.0 - s * 8.0])
		_map.draw_colored_polygon(arrow, Color.WHITE)
		_map.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.1, 0.1, 0.15), 2.0)
	_map.draw_string(font, rect.position + Vector2(10, 28), Region.NAMES[_region], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)


func _mark(font: Font, rect: Rect2, at: Vector2, text: String, color: Color, r: float, offset := Vector2(0, -14)) -> void:
	var p := _to_map(rect, at)
	_map.draw_circle(p, r + 2.0, Color(0.1, 0.08, 0.06, 0.85))
	_map.draw_circle(p, r, color)
	_label(font, p + offset - Vector2(0, r * 0.5), text, CREAM)


func _label(font: Font, at: Vector2, text: String, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_map.draw_string_outline(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.75))
	_map.draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)


func _close() -> void:
	closed.emit()
	queue_free()

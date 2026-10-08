extends Node
## Which region of the land you are in, and travel between regions. Each region is the same main
## scene built from a different WorldShape (see WorldShape.use). Travelling saves, fades to black,
## rebuilds the scene for the new region and fades back in with the region's name.

signal leaving(to: String, arrive: Vector2)

const NAMES := {"meadow": "Home Meadow", "forest": "Whispering Wood", "highlands": "Stonecrest Highlands",
	"sands": "Sunreach", "sea": "The Open Sea"}
## Regions on the second land (Sunreach). The rest are the mainland. "sea" is the voyage between them.
const SECOND_LAND := ["sands"]
## Gates: region -> [{to, at (x, z) of the gate trigger, arrive (x, z) in the other region, radius}].
const GATES := {
	"meadow": [{"to": "forest", "at": Vector2(-0.4, 93.5), "arrive": Vector2(-0.2, -86.0), "radius": 3.0}],
	"forest": [{"to": "meadow", "at": Vector2(2.0, -93.5), "arrive": Vector2(1.5, 86.0), "radius": 3.0},
		{"to": "highlands", "at": Vector2(18.0, 93.5), "arrive": Vector2(16.0, -86.0), "radius": 3.0}],
	"highlands": [{"to": "forest", "at": Vector2(16.5, -93.5), "arrive": Vector2(18.5, 86.0), "radius": 3.0},
		{"to": "sea", "at": Vector2(40.0, 93.5), "arrive": Vector2.INF, "radius": 3.0}],
	"sands": [{"to": "sea", "at": Vector2(12.0, 87.0), "arrive": Vector2.INF, "radius": 2.6}],
}
## Where the voyage puts you ashore.
const HARBOURS := {"sands": Vector2(12.0, 63.0), "highlands": Vector2(40.0, 86.0)}

var current := "meadow"
var arrive := Vector2.INF       # where to stand after a trip (INF = the saved spot or the spawn)
var voyage_to := "sands"        # where the ship is bound while you're at sea (world/voyage.gd)
var _busy := false
var _fade: ColorRect
var _title: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.05, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 90.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_title.add_theme_constant_override("outline_size", 10)
	_title.modulate.a = 0.0
	layer.add_child(_title)
	# Dev runs can start in another region: --region=forest
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--region="):
			current = arg.trim_prefix("--region=")


## The action: go through a gate to another region.
func travel(to: String, arrive_at: Vector2) -> void:
	if _busy or not NAMES.has(to):
		return
	if to == "sea":
		voyage_to = "highlands" if current in SECOND_LAND else "sands"
	if SaveGame.save_game()!=OK: # studio: park captured memories/load location before locking or disposing bodies
		return
	_busy = true
	Controls.locked = true
	leaving.emit(to, arrive_at)          # what comes along (a dragged body, the ox cart you ride)
	# studio: checked save above owns this acceptance; no second write after the availability flip.
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.45)
	await t.finished
	current = to
	arrive = arrive_at
	WorldResources.reset()
	get_tree().reload_current_scene()


## A short fade to black and back, running `middle` while the screen is dark (going in or out of
## a house). Returns false if a trip is already under way.
func fade_through(middle: Callable) -> bool:
	if _busy:
		return false
	_busy = true
	Controls.locked = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.28)
	await t.finished
	middle.call()
	await get_tree().process_frame
	Controls.locked = false
	_busy = false
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.42)
	return true


## Called by main once the region is built: fade in and show its name.
func arrived(show_name: bool) -> void:
	_busy = false
	arrive = Vector2.INF
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.6)
	if show_name:
		_title.text = NAMES[current]
		var n := create_tween()
		n.tween_property(_title, "modulate:a", 1.0, 0.6)
		n.tween_interval(1.8)
		n.tween_property(_title, "modulate:a", 0.0, 0.9)

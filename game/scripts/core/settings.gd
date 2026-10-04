extends Node
## Player settings (frame cap, stats overlay, sound, music, camera zoom, render scale), saved on the device.

signal changed

const PATH := "user://settings.cfg"
const FPS_CAPS := [30, 40, 60]
const ZOOMS := {0.8: "Close", 1.0: "Normal", 1.25: "Far"}     # camera distance multiplier

var fps_cap := 30
var show_stats := true
var show_map := true
var sound_on := true
var music_on := true
var zoom := 1.0
var render_scale := 0.8
var tracker_small := false      # the quest tracker folded down to a small tab
var compact_controls := false   # fewer buttons: flick Attack up for Heavy, left to Parry
var sword_in_hand := false      # keep the sword drawn (otherwise it rides on your back outside fights)
var button_spots := {}          # button id -> its centre from the bottom-right corner, where the player moved it
var button_scale := 1.0         # all touch buttons bigger or smaller
var slide_buttons := false      # slide a thumb from one fight button onto another to press it (no lifting)


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		fps_cap = cfg.get_value("video", "fps_cap", fps_cap)
		show_stats = cfg.get_value("video", "show_stats", show_stats)
		show_map = cfg.get_value("video", "show_map", show_map)
		sound_on = cfg.get_value("audio", "sound_on", sound_on)
		music_on = cfg.get_value("audio", "music_on", music_on)
		zoom = cfg.get_value("video", "zoom", zoom)
		tracker_small = cfg.get_value("ui", "tracker_small", tracker_small)
		compact_controls = cfg.get_value("controls", "compact", compact_controls)
		sword_in_hand = cfg.get_value("controls", "sword_in_hand", sword_in_hand)
		button_spots = cfg.get_value("controls", "button_spots", button_spots)
		button_scale = cfg.get_value("controls", "button_scale", button_scale)
		slide_buttons = cfg.get_value("controls", "slide_buttons", slide_buttons)
	apply()


func set_fps_cap(value: int) -> void:
	fps_cap = value
	_save_and_apply()


func next_fps_cap() -> void:
	set_fps_cap(FPS_CAPS[(FPS_CAPS.find(fps_cap) + 1) % FPS_CAPS.size()])


func set_show_map(value: bool) -> void:
	show_map = value
	_save_and_apply()


func set_show_stats(value: bool) -> void:
	show_stats = value
	_save_and_apply()


func set_sound_on(value: bool) -> void:
	sound_on = value
	_save_and_apply()


func set_music_on(value: bool) -> void:
	music_on = value
	_save_and_apply()


func set_compact_controls(value: bool) -> void:
	compact_controls = value
	_save_and_apply()


func set_sword_in_hand(value: bool) -> void:
	sword_in_hand = value
	_save_and_apply()


## Where a touch button sits: moved by the player, or its default.
func button_spot(id: String, fallback: Vector2) -> Vector2:
	return button_spots.get(id, fallback)


func set_button_layout(spots: Dictionary, scale: float) -> void:
	button_spots = spots
	button_scale = scale
	_save_and_apply()


func set_slide_buttons(value: bool) -> void:
	slide_buttons = value
	_save_and_apply()


func set_tracker_small(value: bool) -> void:
	tracker_small = value
	_save_and_apply()


func next_zoom() -> void:
	var keys := ZOOMS.keys()
	zoom = keys[(keys.find(zoom) + 1) % keys.size()]
	_save_and_apply()


func apply() -> void:
	Engine.max_fps = fps_cap
	Engine.physics_ticks_per_second = fps_cap
	get_viewport().scaling_3d_scale = render_scale
	AudioServer.set_bus_mute(0, not sound_on)
	changed.emit()


func _save_and_apply() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "fps_cap", fps_cap)
	cfg.set_value("video", "show_stats", show_stats)
	cfg.set_value("video", "show_map", show_map)
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("video", "zoom", zoom)
	cfg.set_value("ui", "tracker_small", tracker_small)
	cfg.set_value("controls", "compact", compact_controls)
	cfg.set_value("controls", "sword_in_hand", sword_in_hand)
	cfg.set_value("controls", "button_spots", button_spots)
	cfg.set_value("controls", "button_scale", button_scale)
	cfg.set_value("controls", "slide_buttons", slide_buttons)
	cfg.save(PATH)
	apply()

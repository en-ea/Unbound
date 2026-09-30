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
	cfg.save(PATH)
	apply()

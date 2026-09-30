extends Node
## Player settings (frame cap, stats overlay, sound, music, camera zoom, render scale), saved on the device.

signal changed

const SafeFile := preload("res://scripts/core/safe_file.gd")
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
var living_village := true   # studio: the simulated villagers, their day and their events (off: Enea's village only)
var tracker_small := false      # the quest tracker folded down to a small tab
var compact_controls := false   # fewer buttons: flick Attack up for Heavy, left to Parry
var sword_in_hand := false      # keep the sword drawn (otherwise it rides on your back outside fights)


func _ready() -> void:
	var cfg := ConfigFile.new()
	if SafeFile.load_config(cfg, PATH) == OK:
		fps_cap = cfg.get_value("video", "fps_cap", fps_cap)
		show_stats = cfg.get_value("video", "show_stats", show_stats)
		show_map = cfg.get_value("video", "show_map", show_map)
		sound_on = cfg.get_value("audio", "sound_on", sound_on)
		music_on = cfg.get_value("audio", "music_on", music_on)
		zoom = cfg.get_value("video", "zoom", zoom)
		living_village = cfg.get_value("studio", "living_village", living_village)
		tracker_small = cfg.get_value("ui", "tracker_small", tracker_small)
		compact_controls = cfg.get_value("controls", "compact", compact_controls)
		sword_in_hand = cfg.get_value("controls", "sword_in_hand", sword_in_hand)
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


func set_living_village(value: bool) -> void:   # studio
	living_village = value
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
	# Studio device gate: this Mali-G76 GLES driver exhausts native memory with 3D MSAA.
	# The otherwise identical no-MSAA arrival stays near 190 MB native heap. Keep the
	# renderer/bodies and other devices' AA settings; avoid the failing allocation path here.
	if OS.get_name() == "Android" and RenderingServer.get_current_rendering_method() == "gl_compatibility" and RenderingServer.get_video_adapter_name().contains("Mali-G76"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
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
	cfg.set_value("studio", "living_village", living_village)
	cfg.set_value("ui", "tracker_small", tracker_small)
	cfg.set_value("controls", "compact", compact_controls)
	cfg.set_value("controls", "sword_in_hand", sword_in_hand)
	SafeFile.save_config(cfg, PATH)
	apply()

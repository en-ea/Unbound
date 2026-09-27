extends Node
## Player settings (frame cap, render scale), saved on the device.

const PATH := "user://settings.cfg"

var fps_cap := 30
var render_scale := 0.8


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		fps_cap = cfg.get_value("video", "fps_cap", fps_cap)
	apply()


func set_fps_cap(value: int) -> void:
	fps_cap = value
	apply()
	var cfg := ConfigFile.new()
	cfg.set_value("video", "fps_cap", fps_cap)
	cfg.save(PATH)


func apply() -> void:
	Engine.max_fps = fps_cap
	Engine.physics_ticks_per_second = fps_cap
	get_viewport().scaling_3d_scale = render_scale

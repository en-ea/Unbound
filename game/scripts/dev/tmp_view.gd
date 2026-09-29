extends Node3D
var frames := 0
func _ready():
	var layer := CanvasLayer.new(); add_child(layer)
	var bg := ColorRect.new(); bg.color = Color(0.35, 0.5, 0.35); bg.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	if OS.get_environment("GV_MODE") == "body":
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.3, 0.36, 0.3)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.72, 0.74, 0.86)
		env.ambient_light_energy = 0.9
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var we := WorldEnvironment.new(); we.environment = env; add_child(we)
		var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 35, 0); l.light_energy = 1.5; add_child(l)
		var v := Npcs.make_visual(OS.get_environment("GV_NPC")); add_child(v)
		Npcs.dress_visual(OS.get_environment("GV_NPC"), v)
		var cam := Camera3D.new(); cam.fov = 40; add_child(cam)
		var a := deg_to_rad(float(OS.get_environment("GV_ANGLE")) if OS.get_environment("GV_ANGLE") != "" else 20.0)
		var dist := float(OS.get_environment("GV_DIST")) if OS.get_environment("GV_DIST") != "" else 6.5
		cam.position = Vector3(sin(a) * dist, 1.9, cos(a) * dist)
		cam.look_at(Vector3(0, 1.4, 0))
		layer.visible = false
		return
	var p := Control.new(); p.set_script(load("res://scripts/ui/dialogue_panel.gd"))
	p.npc = OS.get_environment("GV_NPC") if OS.get_environment("GV_NPC") != "" else "wren"
	layer.add_child(p)
func _process(_d):
	frames += 1
	if frames == 90:
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/s/gv.png")
		get_tree().quit()

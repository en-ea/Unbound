extends SceneTree
## C1 gate (desk, 6 Oct): his HUD's draw calls, before and after each controls unit. Dev-only; nothing in the game calls it.
## Starts the real main scene (a fresh test save), waits for play with the controls up, then reads the root viewport's
## canvas pass (the HUD and every 2D control) for 90 frames, and again with the HUD hidden; the HUD's own cost is the
## difference. Rendered only (the dummy renderer counts nothing):
##   xvfb-run -a -s "-screen 0 1560x720x24" godot --rendering-driver opengl3 --fixed-fps 30 --resolution 1560x720 \
##     --path game --script res://scripts/studio/player/hud_draws.gd -- --test-save=<fresh> [--hud-bow]
## --hud-bow takes the bow out first (his Attack draws it). --hud-each: each HUD child's own cost. --hud-native: his
## buttons drawn his own way (no button_skin), for an A/B. --hud-shot=<png>: the frame measured. --hud-class=<id>: a class. Prints "HUD DRAWS ..." and "HUD DRAWS complete".
const CANVAS := 2 # Viewport.RENDER_INFO_TYPE_CANVAS


func _initialize() -> void:
	if "--hud-native" in OS.get_cmdline_user_args(): # A/B: his buttons drawn his own way
		load("res://scripts/studio/player/button_skin.gd").set("off", true)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _sample(n: int) -> Array[int]:
	var out: Array[int] = []
	for _i in n:
		await process_frame
		out.append(root.get_render_info(CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	out.sort()
	return out


func _run() -> void:
	var hud: CanvasLayer = null
	for _i in 1800:
		await process_frame
		hud = get_first_node_in_group("hud") as CanvasLayer
		if hud != null and hud.get("_hands") != null and (hud.get("_hands") as Control).is_visible_in_tree():
			break
	if hud == null:
		print("HUD DRAWS FAIL no play")
		quit(3)
		return
	if "--hud-bow" in OS.get_cmdline_user_args():
		root.get_node("Gear").set("has_bow", true)
		root.get_node("Gear").set("weapon", "bow")
		root.get_node("Gear").emit_signal("changed")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-class="): # a class, so the power arcs (and their cooldowns) are on screen
			root.get_node("Classes").call("choose", arg.trim_prefix("--hud-class="))
	await _wait(240)
	var shown := await _sample(90)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-shot="):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.trim_prefix("--hud-shot="))
	hud.visible = false
	var hidden := await _sample(90)
	hud.visible = true
	var mid := func(a: Array[int]) -> int: return a[a.size() / 2]
	print("HUD DRAWS canvas shown min=%d median=%d max=%d; hidden min=%d median=%d max=%d; HUD own median=%d (%d..%d)" % [
		shown[0], mid.call(shown), shown[-1], hidden[0], mid.call(hidden), hidden[-1],
		mid.call(shown) - mid.call(hidden), shown[0] - hidden[-1], shown[-1] - hidden[0]])
	var up := []
	for c in hud.get_children():
		if c is CanvasItem and (c as CanvasItem).visible:
			up.append(str(c.get("id")) if c.get("home_radius") != null else (c.get_script() as Script).resource_path.get_file().get_basename() if c.get_script() != null else c.get_class())
	print("HUD DRAWS shown items: %s (locked %s, title %s)" % [", ".join(PackedStringArray(up)), str(root.get_node("Controls").get("locked")), str(hud.get("_title") != null)])
	if "--hud-each" in OS.get_cmdline_user_args(): # what each of the HUD's own children costs, hidden one at a time
		var whole: int = mid.call(await _sample(20))
		for c in hud.get_children():
			if c is CanvasItem and (c as CanvasItem).visible:
				(c as CanvasItem).visible = false
				var without: int = mid.call(await _sample(12))
				(c as CanvasItem).visible = true
				await _sample(4)
				var sc: Script = c.get_script()
				var label := "%s %s" % [c.name, sc.resource_path.get_file() if sc != null else c.get_class()]
				if c.get("home_radius") != null:
					label += " " + str(c.get("id"))
				print("HUD DRAWS each %-48s %d" % [label, whole - without])
	print("HUD DRAWS complete")
	quit()

extends Node
## --controlstest: switch Settings > Controls both ways through the real Settings screen and print what shows.


func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var hud := get_tree().get_first_node_in_group("hud")
	for want: bool in [true, false]:   # ends on the default (buttons)
		var panel: Control = hud._modal(hud.SETTINGS_PANEL)
		await get_tree().process_frame
		Settings.set_thumb_controls(want)
		await get_tree().process_frame
		panel.closed.emit()
		panel.queue_free()
		await get_tree().process_frame
		print("CONTROLS thumb=", want, " hands=", hud._hands.visible, " action=", hud._action.visible, " roll=", hud._roll.visible)
	get_tree().quit()

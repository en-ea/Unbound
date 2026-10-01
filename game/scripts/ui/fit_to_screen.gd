class_name FitToScreen
extends Node
## Keeps a screen's panels inside the phone screen: a centred panel that grows taller (or wider) than the
## screen, say with a long list, is shrunk to fit, so its buttons (Done, Close) can always be reached.
## `FitToScreen.watch(screen)` once; it checks every frame, so it also works as the content changes.

const MARGIN := 10.0


static func watch(screen: Control) -> void:
	var f := FitToScreen.new()
	f.name = "FitToScreen"
	screen.add_child(f)


func _process(_delta: float) -> void:
	var screen := get_parent() as Control
	var view := screen.get_viewport_rect().size
	for c in screen.get_children():
		var panel := c as Control
		if panel == null or not panel.visible or panel.anchor_right - panel.anchor_left >= 1.0:
			continue                              # full-screen layers (the shade) are already fitted
		var s := panel.size
		if s.x <= 0.0 or s.y <= 0.0:
			continue
		var k := minf(1.0, minf((view.y - MARGIN * 2.0) / s.y, (view.x - MARGIN * 2.0) / s.x))
		panel.pivot_offset = s / 2.0
		if not is_equal_approx(panel.scale.x, k):
			panel.scale = Vector2(k, k)

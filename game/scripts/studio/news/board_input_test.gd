extends RefCounted
## Brief 5.0: exercise Enea's actual camera duck type and both touch exclusions.
const Board := preload("res://scripts/studio/news/board.gd")
const CameraDrag := preload("res://scripts/ui/camera_drag.gd")


static func report() -> PackedStringArray:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := Control.new()
	tree.root.add_child(hud)
	var board := Board.new()
	hud.add_child(board)
	board.position = Vector2(20, 30)
	board.size = Vector2(330, 90)
	board.show()
	var camera := CameraDrag.new()
	hud.add_child(camera)
	var inside := Vector2(40, 50)
	var outside := Vector2(700, 300)
	var out := PackedStringArray()
	out.append(_check(camera._on_button(inside) and Board.blocks_stick(tree, inside),
		"board touch blocks camera and stick through their actual contracts"))
	out.append(_check(not camera._on_button(outside) and not Board.blocks_stick(tree, outside),
		"world touch remains available"))
	board.hide()
	out.append(_check(not camera._on_button(inside) and not Board.blocks_stick(tree, inside),
		"hidden board releases both inputs"))
	hud.free()
	return out


static func _check(ok: bool, what: String) -> String:
	return ("PASS " if ok else "FAIL ") + what

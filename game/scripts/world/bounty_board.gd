extends Node3D
## The region's bounty board (Bounties.BOARDS): a notice board with papers pinned to it. Look at it to
## take and claim bounties (ui/bounty_panel.gd).

const BOARD := preload("res://assets/props/site_board.glb")
const STATION := preload("res://scripts/world/station.gd")


func build(shape: WorldShape) -> void:
	if not Bounties.BOARDS.has(Region.current):
		return
	var at: Vector2 = Bounties.BOARDS[Region.current]
	var board := Node3D.new()
	board.set_script(STATION)
	add_child(board)
	board.setup(Vector3(at.x, shape.height_at(at.x, at.y), at.y), "Bounties", {"mode": "bounty"}, BOARD, Vector3(1.4, 1.6, 0.3))
	board.add_child(SignLabel.make("Bounties"))
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.93, 0.88, 0.74)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.72, 0.18, 0.14)
	# Notices on the back, and a red WANTED sheet on the front beside the board's own papers.
	for p in [[Vector3(-0.32, 1.2, -0.05), 0.08, paper], [Vector3(0.05, 1.12, -0.05), -0.12, red], [Vector3(0.36, 1.25, -0.05), 0.15, paper],
			[Vector3(0.42, 1.36, 0.06), -0.1, red]]:
		var sheet := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.24, 0.3, 0.01)
		sheet.mesh = box
		sheet.material_override = p[2]
		sheet.position = p[0]
		sheet.rotation.z = p[1]
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board.add_child(sheet)
	board.add_to_group("map_building")
	board.set_meta("map_size", Vector2(1.4, 0.6))

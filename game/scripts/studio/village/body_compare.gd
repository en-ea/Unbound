extends Node
## Look check for VillagerBody against CharacterVisual: six looks, each built both ways and held in the
## same pose (one animation frame, paused).
##   1. Machine check. The six looks stand in a row and are drawn three times at the same spots, with
##      the world paused: CharacterVisuals, then VillagerBodies, then CharacterVisuals again. The two
##      CharacterVisual frames give the noise floor (shader time still moves grass and water); the
##      VillagerBody frame should differ from the first by no more than that. Measured inside the
##      characters' box on screen; STUDIO lines give the numbers. Saved next to the shot: the two
##      frames, and _diff.png (the box: CharacterVisual above, VillagerBody, the difference x8 below).
##   2. For eyes. The pairs then stand side by side, CharacterVisual on the left, VillagerBody on the
##      right, for the screenshot the game's own --shot takes (its frame 180, then it quits; its count
##      stands still while the world is paused, so it lands about 40 frames later here).
## Run: --studio=village/body_compare --frame=fight --at=2,24 --shot=C:/path/body_compare.png
## Add --compare-near for a close view of three of the pairs (faces, marks, glasses).

const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")
const OUTFITS := ["Knight", "Mage", "Smith", "Alchemist", "Ranger", "Northlander"]
const POSE := "Idle"
const POSE_AT := 0.5          # seconds into POSE
const PAIR_GAP := 1.9         # metres between looks
const SIDE := 0.42            # each of a pair stands this far left or right of its spot
const OVER := 12              # a channel difference (of 255) counted as a visible one

var _frame := 0
var _near := false
var _shot := ""
var _player: Node3D
var _spots: Array[Vector3] = []
var _visuals: Array[Node3D] = []
var _bodies: Array[Node3D] = []
var _cv_a: Image
var _vb: Image
var _box: Rect2i           # the characters on screen (and their shadows)
var _lines := PackedStringArray()


static func on_device(tree: SceneTree) -> void:
	var probe: Node = (load("res://scripts/studio/village/body_compare.gd") as GDScript).new()
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # keeps running while it pauses the world for the captures
	var args := OS.get_cmdline_user_args()
	_near = args.has("--compare-near")
	for arg in args:
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		8:
			_build()        # the player has been placed (dev_args moves it on frame 2)
		12:
			_pose()
		96:
			get_tree().paused = true   # by now the title has faded and the camera has settled
			_show(true, false)
		110:
			_cv_a = _grab()
			_show(false, true)
		122:
			_vb = _grab()
			_show(true, false)
		134:
			_compare(_grab())
			get_tree().paused = false
			_side_by_side()
		240:
			if _shot == "":
				get_tree().quit()   # no --shot: nothing else ends the run
		400:
			get_tree().quit()   # the shot should have ended it long ago


func _build() -> void:
	_player = get_tree().current_scene.get_node("Player") as Node3D
	_player.visible = false
	var shape := WorldShape.new()
	var looks := _looks()
	var count := looks.size()
	for i in count:
		var at := _player.global_position + Vector3((i - (count - 1) / 2.0) * PAIR_GAP, 0.0, 0.0)
		at.y = shape.height_at(at.x, at.z)
		_spots.append(at)
		var v := CharacterVisual.new()
		v.hero_look = looks[i]
		v.is_player_look = false
		add_child(v)
		v.global_position = at
		_visuals.append(v)
		var b := VillagerBody.new()
		b.hero_look = looks[i]
		b.is_player_look = false
		add_child(b)
		b.global_position = at
		_bodies.append(b)
	var rig := get_tree().current_scene.get_node("CameraRig")
	if _near:
		rig.set_view(3.3, -4.0, Vector3(0.0, 0.45, 0.0), 0.01)     # upper bodies of three pairs
	else:
		rig.set_view(7.2, -8.0, Vector3(0.0, -0.1, 0.0), 0.01)     # all six pairs, head to toe


## Six looks: ready-made outfits covering helm and armour (metal), bare arms (jerkin), hats over hair,
## a hood over ears, glasses, marks, beards and braids; eyes vary as in the game's own --lineup.
func _looks() -> Array[CharacterLook]:
	var names: Array = OUTFITS if not _near else ["Mage", "Alchemist", "Northlander"]
	var looks: Array[CharacterLook] = []
	for i in names.size():
		var look := CharacterLook.new()
		look.set_outfit(names[i])
		look.parts["eyes"] = ["calm", "happy", "fierce", "bright", "sleepy", "narrow"][i % 6]
		look.parts["ears"] = ["round", "pointed", "long"][i % 3]
		look.colors["Skin"] = i % CharacterLook.PALETTES["Skin"].size()
		look.colors["Hair"] = (i * 3) % CharacterLook.PALETTES["Hair"].size()
		looks.append(look)
	return looks


## Every character in the same frame of the same animation, paused there.
func _pose() -> void:
	for n: Node3D in _visuals + _bodies:
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play(POSE)
		ap.seek(POSE_AT, true)
		ap.pause()


func _show(visuals: bool, bodies: bool) -> void:
	for v in _visuals:
		v.visible = visuals
	for b in _bodies:
		b.visible = bodies


func _grab() -> Image:
	return get_viewport().get_texture().get_image()


## The VillagerBody frame against the first CharacterVisual frame, beside the noise floor (the two
## CharacterVisual frames against each other), inside the characters' box.
func _compare(cv_b: Image) -> void:
	_box = _characters_box()
	for image in [_cv_a, _vb, cv_b]:
		image.convert(Image.FORMAT_RGB8)
	var a := _cv_a.get_region(_box)
	var noise := _difference(a, cv_b.get_region(_box), null)
	var diff := Image.create(_box.size.x, _box.size.y, false, Image.FORMAT_RGB8)
	var bodies := _difference(a, _vb.get_region(_box), diff)
	_lines.append("look check (%s): %d looks, pose %s at %.1f s, box %s" % ["near" if _near else "full", _spots.size(), POSE, POSE_AT, _box])
	_lines.append("noise floor (CharacterVisual vs itself, 24 frames apart): %s" % noise)
	_lines.append("VillagerBody vs CharacterVisual (12 frames apart): %s" % bodies)
	if _shot != "":
		var base := _shot.get_basename()
		_cv_a.save_png(base + "_cv.png")
		_vb.save_png(base + "_vb.png")
		var board := Image.create(_box.size.x, _box.size.y * 3, false, Image.FORMAT_RGB8)
		board.blit_rect(a, Rect2i(Vector2i.ZERO, _box.size), Vector2i.ZERO)
		board.blit_rect(_vb.get_region(_box), Rect2i(Vector2i.ZERO, _box.size), Vector2i(0, _box.size.y))
		board.blit_rect(diff, Rect2i(Vector2i.ZERO, _box.size), Vector2i(0, _box.size.y * 2))
		board.save_png(base + "_diff.png")
		_lines.append("saved: %s_cv.png, %s_vb.png, %s_diff.png" % [base, base, base])
	for line in _lines:
		print("STUDIO ", line)


## The screen rectangle holding every character, from its feet (and shadow) to above its head.
func _characters_box() -> Rect2i:
	var cam := get_viewport().get_camera_3d()
	var size := get_viewport().get_visible_rect().size
	var r := Rect2(cam.unproject_position(_spots[0]), Vector2.ZERO)
	for at in _spots:
		for corner: Vector3 in [Vector3(-0.8, -0.1, -0.8), Vector3(0.8, -0.1, 0.8), Vector3(-0.8, 2.1, 0.0), Vector3(0.8, 2.1, 0.0)]:
			r = r.expand(cam.unproject_position(at + corner))
	r = r.intersection(Rect2(Vector2.ZERO, size))
	return Rect2i(r.position.floor(), r.size.ceil())


## Mean and largest channel difference of two RGB8 images, and how many pixels differ visibly (a
## channel over OVER).
## When `out` is given it receives the difference, amplified 8x so small shifts show.
func _difference(a: Image, b: Image, out: Image) -> String:
	var da := a.get_data()
	var db := b.get_data()
	var dd := PackedByteArray()
	if out:
		dd.resize(da.size())
	var total := 0
	var worst := 0
	var visible := 0
	for i in range(0, da.size(), 3):
		var d := maxi(maxi(absi(da[i] - db[i]), absi(da[i + 1] - db[i + 1])), absi(da[i + 2] - db[i + 2]))
		total += d
		worst = maxi(worst, d)
		if d > OVER:
			visible += 1
		if out:
			dd[i] = mini(absi(da[i] - db[i]) * 8, 255)
			dd[i + 1] = mini(absi(da[i + 1] - db[i + 1]) * 8, 255)
			dd[i + 2] = mini(absi(da[i + 2] - db[i + 2]) * 8, 255)
	if out:
		out.set_data(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8, dd)
	var pixels := da.size() / 3
	return "mean %.3f, max %d, pixels over %d: %d of %d" % [float(total) / pixels, worst, OVER, visible, pixels]


## Pairs side by side for the eye check: CharacterVisual left, VillagerBody right.
func _side_by_side() -> void:
	var shape := WorldShape.new()
	for i in _spots.size():
		for pair: Array in [[_visuals[i], -SIDE], [_bodies[i], SIDE]]:
			var n: Node3D = pair[0]
			var at: Vector3 = _spots[i] + Vector3(pair[1], 0.0, 0.0)
			at.y = shape.height_at(at.x, at.z)
			n.global_position = at
			n.visible = true

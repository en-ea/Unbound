extends SceneTree
## Look board, second half: converts each <name>.png from capture.sh into <name>.jpg and lays them
## out as sheet.jpg, one row per framing and one column per variant, in shot-list order.
## Row and column come from the shot name, "<row>-<column>" (e.g. explore-compat-day).
## Usage: godot --headless --script sheet.gd -- <out_dir> <shots.txt>

const THUMB_W := 520
const QUALITY := 0.82


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var names: Array[String] = []
	for line in FileAccess.get_file_as_string(args[1]).split("\n"):
		var t := line.strip_edges()
		if t != "" and not t.begins_with("#"):
			names.append(t.split(" ")[0])
	if names.is_empty():
		print("sheet.gd: no shots in ", args[1])
		quit(1)
		return
	var rows: Array[String] = []
	var cols: Array[String] = []
	for n in names:
		var r := n.get_slice("-", 0)
		var c := n.substr(r.length() + 1)
		if not rows.has(r):
			rows.append(r)
		if not cols.has(c):
			cols.append(c)
	var thumb_h := 0
	var sheet: Image = null
	for n in names:
		var img := Image.load_from_file(out.path_join(n + ".png"))
		if img == null or img.is_empty():
			print("missing ", n)
			continue
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join(n + ".jpg"), QUALITY)
		if sheet == null:
			thumb_h = int(THUMB_W * img.get_height() / float(img.get_width()))
			sheet = Image.create(THUMB_W * cols.size(), thumb_h * rows.size(), false, Image.FORMAT_RGB8)
			sheet.fill(Color(0.08, 0.08, 0.08))
		img.resize(THUMB_W, thumb_h, Image.INTERPOLATE_LANCZOS)
		var r := n.get_slice("-", 0)
		sheet.blit_rect(img, Rect2i(0, 0, THUMB_W, thumb_h), Vector2i(cols.find(n.substr(r.length() + 1)) * THUMB_W, rows.find(r) * thumb_h))
	if sheet:
		sheet.save_jpg(out.path_join("sheet.jpg"), QUALITY)
		print("sheet.jpg: rows ", rows, " columns ", cols)
	quit()

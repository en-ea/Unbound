extends RefCounted
## Unbound's note button: a round button in the HUD's top-right corner, in the HUD's own style, with a pencil drawn
## in code (no image file). One marked line in ui/hud.gd puts it there. A press opens the note (note_flow.gd) on
## what UnboundNotes.capture keeps; closing says so through the HUD's hint.
##
## For Enea, at a merge: built for the Android build; his iPhone web build may need adapting (the browser decides
## rotation, and notes are pulled from an Android phone over the cable: toolbox/device-lab/phone_notes.sh).

const UIStyle := preload("res://scripts/ui/ui_style.gd")
const NoteFlow := preload("res://scripts/studio/notes/note_flow.gd")
const UnboundNotes := preload("res://scripts/studio/notes/unbound_notes.gd")

const SAID := {"saved": "Note saved.", "discarded": "Note discarded.", "draft": "Note kept as a draft.", "failed": "The note could not be written."}


static func add_to(corner: Container) -> Button:
	var b := UIStyle.icon_button(corner, "star")
	b.icon = _pencil()
	b.tooltip_text = "Note"
	corner.move_child(b, 0)                    # leftmost: the menu and settings stay where they were
	b.pressed.connect(func() -> void: press(b.get_tree()))
	return b


static func press(tree: SceneTree) -> void:
	var viewport := tree.root
	NoteFlow.open(tree, func() -> Dictionary: return UnboundNotes.capture(viewport),
		func(status: String) -> void: tree.call_group("hud", "hint", SAID.get(status, "")))


## A white pencil on a clear square, slanted like a hand holds it.
static func _pencil() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var a := Vector2(46, 14)                   # the end
	var b := Vector2(18, 42)                   # where the wood starts
	for i in 41:
		var p := a.lerp(b, i / 40.0)
		img.fill_rect(Rect2i(int(p.x) - 5, int(p.y) - 5, 10, 10), Color.WHITE)
	for i in 12:                               # the point, narrowing
		var p := b.lerp(Vector2(10, 50), i / 11.0)
		var r := int(lerpf(5.0, 1.0, i / 11.0))
		img.fill_rect(Rect2i(int(p.x) - r, int(p.y) - r, r * 2, r * 2), Color.WHITE)
	return ImageTexture.create_from_image(img)

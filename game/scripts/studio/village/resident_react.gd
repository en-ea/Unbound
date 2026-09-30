extends RefCounted
## What a resident shows without a menu: a short speech bubble over their head (the style of Enea's npc.gd
## bubble: outlined text, faces the camera, fades), and the name tag over whoever the action button would
## talk to. Nothing else of the village's is ever drawn over the game.
##
##   React.say(body, "Free! I won't forget you.")    # a bubble over that body for a few seconds
##   React.tag(...)                                    # (residents.gd) the name over the person in reach
const BUBBLE_HEIGHT := 2.35          # metres over the feet, at full size (a child's is scaled down with them)
const BUBBLE_WIDTH := 420.0          # pixels before the words wrap
const NAME := "SpeechBubble"
const SECONDS_PER_WORD := 0.45
const MIN_SECONDS := 2.6


## A speech bubble over `body` (a Node3D standing on the ground), replacing any it already has. It stays
## as long as the words take to read, then fades and frees itself.
static func say(body: Node3D, text: String, seconds := 0.0) -> Label3D:
	if not is_instance_valid(body) or text.is_empty():
		return null
	var old := body.get_node_or_null(NAME)
	if old != null:
		old.free()
	var bubble := Bubble.new()
	bubble.name = NAME
	bubble.text = text
	bubble.seconds = seconds if seconds > 0.0 else maxf(MIN_SECONDS, text.split(" ", false).size() * SECONDS_PER_WORD)
	var size := body.scale.y if body.scale.y > 0.0 else 1.0
	# Counter the body's own scale (a child is drawn smaller), so every bubble reads the same size, and sit it just
	# over the head: 2.35 m for a grown person, lower for a child.
	bubble.scale = Vector3.ONE / size
	bubble.position = Vector3(0.0, BUBBLE_HEIGHT * (1.0 if size >= 1.0 else 0.78) / size, 0.0)
	body.add_child(bubble)
	return bubble


## Whether a body has a bubble up (for probes).
static func has_bubble(body: Node3D) -> bool:
	return is_instance_valid(body) and body.get_node_or_null(NAME) != null


## The words of the bubble over a body ("" when none).
static func bubble_text(body: Node3D) -> String:
	var bubble := body.get_node_or_null(NAME) as Label3D if is_instance_valid(body) else null
	return bubble.text if bubble != null else ""


class Bubble extends Label3D:
	var seconds := 3.0
	var _age := 0.0

	func _init() -> void:
		billboard = BaseMaterial3D.BILLBOARD_ENABLED
		no_depth_test = true
		font_size = 40
		outline_size = 14
		pixel_size = 0.005
		width = BUBBLE_WIDTH
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modulate = Color(1.0, 0.97, 0.88, 0.0)
		outline_modulate = Color(0.08, 0.06, 0.1, 0.0)
		render_priority = 3
		outline_render_priority = 2

	func _process(delta: float) -> void:
		_age += delta
		var fade_in := clampf(_age / 0.18, 0.0, 1.0)
		var fade_out := clampf((seconds - _age) / 0.6, 0.0, 1.0)
		var a := minf(fade_in, fade_out)
		modulate.a = a
		outline_modulate.a = a * 0.85
		if _age >= seconds:
			queue_free()


## The name over the person the action button would talk to: one label, moved to whoever is in reach.
class Tag extends Label3D:
	var target: Node3D
	var height := 2.15
	var _shown := 0.0

	func _init() -> void:
		top_level = true
		billboard = BaseMaterial3D.BILLBOARD_ENABLED
		no_depth_test = true
		font_size = 48
		outline_size = 14
		pixel_size = 0.005
		modulate = Color(1.0, 0.93, 0.7, 0.0)
		outline_modulate = Color(0.1, 0.07, 0.04, 0.0)
		render_priority = 3
		outline_render_priority = 2
		visible = false

	## Point the tag at a body (or at nothing); it fades in and out.
	func aim(body: Node3D, words: String, tall: float, delta: float) -> void:
		if body != null:
			if target != body:
				target = body
				text = words
				height = tall
		_shown = move_toward(_shown, 1.0 if body != null else 0.0, delta * 5.0)
		visible = _shown > 0.01 and is_instance_valid(target)
		if not visible:
			if body == null:
				target = null
			return
		global_position = target.global_position + Vector3(0.0, height, 0.0)
		modulate.a = _shown
		outline_modulate.a = _shown * 0.85

extends Node
## Opens a note's moment again on the PC: --note-replay=<the note's folder, absolute> together with
## --test-save=<a copy of the note's save.json> (toolbox/notes/note_replay.sh makes both), headless or not.
## Once the village is up it settles for a moment, then prints, for the player and everyone circled, what the note
## says then and what the game says now, so a replay shows how close it came. Prints REPLAY lines, then
## "REPLAY complete", and quits. The replay is close, not exact: people are placed again by their day, and a
## meeting or scene in progress is not part of the save (plan/NOTE-TOOL-2026-10-01.md section 2).

const UnboundNotes := preload("res://scripts/studio/notes/unbound_notes.gd")

const SETTLE := 0.5            # s: the village clock runs on meanwhile (2 game minutes a second)

var folder := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	var then: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("state.json")))
	var note: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("note.json")))
	if not (then is Dictionary and note is Dictionary):
		print("REPLAY complete failures=1 (no note at %s)" % folder)
		tree.quit(1)
		return
	for i in 1200:
		var live := tree.current_scene.get_node_or_null("VillageLive") if tree.current_scene != null else null
		if live != null and live.get("registry") != null and live.registry.ready_for_play and not live.registry.bodies.is_empty():
			break
		await tree.process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < SETTLE * 1000.0:
		await tree.process_frame
	var now := UnboundNotes.state_now(get_viewport())
	print("REPLAY clock then %s, now %s; region then %s, now %s" % [then.world.get("clock"), now.world.get("clock"), then.world.get("region"), now.world.get("region")])
	print("REPLAY player then %s, now %s" % [then.world.get("player", {}).get("at"), now.world.get("player", {}).get("at")])
	for id in note.get("circled", []):
		print("REPLAY %s then: %s" % [_name(then, id), _brief(_person(then, id))])
		print("REPLAY %s now:  %s" % [_name(then, id), _brief(_person(now, id))])
	print("REPLAY complete failures=0")
	tree.quit(0)


static func _person(state: Dictionary, id: Variant) -> Dictionary:
	for p: Dictionary in state.get("people", []) + state.get("others", []):
		if str(p.get("id")) == str(id) or (p.get("id") is float and id is float and p.id == id):
			return p
	return {}


static func _name(state: Dictionary, id: Variant) -> String:
	return str(_person(state, id).get("name", id))


static func _brief(p: Dictionary) -> String:
	if p.is_empty():
		return "not within reach"
	var m: Dictionary = p.get("mover", {})
	return "%s; %s; at %s, %s m/s, why %s; meeting %s; looks at %s; says \"%s\"" % [p.get("driver"), p.get("activity"),
		m.get("at"), m.get("speed"), m.get("why"), p.get("meeting", {}).get("name", "-"), p.get("looks_at", {}).get("kind", "-"), p.get("says", "")]

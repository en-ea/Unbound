extends RefCounted
## B7 speech in a situation, headless: turns, priority (the one struck, then whoever steps in, then the crowd), the
## same words not said twice, two bubbles at most, none wider than a third of the screen, none off its side, none over
## another, and another system's bubble (Enea's greeting) said through the same rules.
##   godot --headless --path game --script res://scripts/studio/run.gd -- people/speech_test
const Speech := preload("res://scripts/studio/people/speech.gd")
const FRAME := 1.0 / 60.0


static func check(ok: bool, words: String) -> String:
	return ("PASS " if ok else "FAIL ") + words


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	cam.position = Vector3(0.0, 1.7, 7.0)
	cam.make_current()
	var speech := Speech.new()
	world.add_child(speech)
	speech.camera = cam
	var roles := {}
	speech.role = func(body: Node3D) -> Dictionary: return roles.get(body, {})
	var screen := root.get_visible_rect().size
	var people: Array[Node3D] = []
	for i in 6:
		var b := Node3D.new()
		world.add_child(b)
		b.position = Vector3(-2.0 + i * 0.8, 0.0, 0.0)
		people.append(b)
	var struck := people[0]
	var friend := people[1]
	var second := people[2]
	var gawker := people[3]
	var fight := 8000001
	roles[struck] = {"priority": Speech.STRUCK, "situation": fight}
	roles[friend] = {"priority": Speech.STEP_IN, "situation": fight}
	roles[second] = {"priority": Speech.STEP_IN, "situation": fight}
	roles[gawker] = {"priority": Speech.TALK, "situation": fight}

	speech.say(friend, "Leave her be!", Speech.SCENE)
	_run(speech, 0.2)
	out.append(check(speech.saying(friend), "one stepping in speaks"))
	speech.say(second, "Hands off, stranger.", Speech.SCENE)
	_run(speech, 0.2)
	out.append(check(not speech.saying(second) and speech.saying(friend), "a second one stepping in waits its turn: one voice in the situation"))
	var taken := speech.say(gawker, "Someone is arguing with their fists.", Speech.SCENE)
	_run(speech, 0.2)
	out.append(check(not speech.saying(gawker) and taken, "the crowd does not talk over whoever steps in (and its act goes on: say is true)"))
	speech.say(struck, "Was that your argument?", Speech.SCENE)
	_run(speech, 0.2)
	out.append(check(speech.saying(struck) and not speech.saying(friend), "the one struck outranks whoever steps in"))
	_run(speech, 3.5)
	out.append(check(speech.saying(second) and not speech.saying(struck), "the waiting one takes its turn when the struck one is done"))
	_run(speech, 4.0)
	speech.say(gawker, "Someone is arguing with their fists.", Speech.SCENE)
	_run(speech, 0.2)
	out.append(check(speech.saying(gawker), "the crowd speaks when the situation is quiet"))
	_run(speech, 4.0)
	var other := people[4]
	roles[other] = {"priority": Speech.TALK, "situation": fight}
	var repeat_taken := speech.say(other, "Someone is arguing with their fists.", Speech.SCENE)
	_run(speech, 0.2)
	out.append(check(not speech.saying(other) and repeat_taken, "the same words just said in a situation are not said again (say is true: no stalled act)"))

	speech.say(people[0], "One line in a conversation that goes on for a good while yet.", Speech.TALK, 11)
	speech.say(people[5], "Another, overheard.", Speech.TALK, 12)
	speech.say(people[2], "A third that would make three.", Speech.TALK, 13)
	_run(speech, 0.3)
	var shown := _shown_rects(speech, cam)
	var widest := 0.0
	for r: Rect2 in shown:
		widest = maxf(widest, r.size.x)
	out.append(check(shown.size() == Speech.MAX_BUBBLES, "two bubbles at most on screen (%d asked, %d up)" % [3, shown.size()]))
	out.append(check(widest > 0.0 and widest <= screen.x / 3.0, "no bubble wider than a third of the screen (%.0f of %.0f px)" % [widest, screen.x]))
	out.append(check(not _overlap(shown), "two bubbles apart do not overlap (%s)" % str(shown)))
	_run(speech, 6.0)
	speech.say(people[0], "One line in a conversation that goes on for a good while yet.", Speech.TALK, 14)
	speech.say(people[1], "Another, right beside it.", Speech.TALK, 15)
	var worst := false
	var t := 0.0
	while t < 2.0:
		_run(speech, 0.1)
		t += 0.1
		worst = worst or (t > 0.3 and _overlap(_shown_rects(speech, cam)))
	out.append(check(not worst, "two speakers side by side never overlap on screen (one rises or waits): %s" % str(_shown_rects(speech, cam))))
	_run(speech, 6.0)

	speech.say(people[0], "An old line about to fade away.", Speech.TALK, 16, "", 2.4)
	_run(speech, 2.05)
	speech.say(people[1], "A new one right beside it.", Speech.TALK, 17)
	var crossed := false
	var t3 := 0.0
	while t3 < 0.6:
		_run(speech, FRAME)
		t3 += FRAME
		crossed = crossed or (t3 > 2.0 * FRAME and _overlap(_shown_rects(speech, cam)))
	out.append(check(not crossed and speech.saying(people[1]), "a new line beside one fading out never overlaps it: the fading one gives way"))
	_run(speech, 6.0)

	var edge := Node3D.new()
	world.add_child(edge)
	edge.position = cam.project_position(Vector2(4.0, screen.y * 0.5), 7.0) - Vector3(0.0, 2.3, 0.0)
	speech.say(edge, "A line said at the very edge of the view, long enough to run off it.", Speech.SCENE, 21)
	_run(speech, 0.3)
	var er := Rect2()
	for l in speech._shown:
		if l.body == edge:
			er = speech._rect(cam, l)
	out.append(check(er.size != Vector2.ZERO and er.position.x >= Speech.EDGE - 1.0 and er.end.x <= screen.x, "a bubble at the screen's side is moved onto it (x %.0f..%.0f)" % [er.position.x, er.end.x]))
	_run(speech, 6.0)

	# Space in use: a bubble that would land on it moves off it, staying on screen; layers and faint things do not count.
	var spot := Node3D.new()
	world.add_child(spot)
	spot.position = Vector3(0.0, 0.0, 0.0)
	speech.say(spot, "Where the panel is.", Speech.SCENE, 51)
	_run(speech, 0.3)
	var free_r: Rect2 = _rect_of(speech, cam, spot)
	_run(speech, 6.0)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var hud := Control.new()
	hud.add_to_group("hud")
	hud.size = screen
	layer.add_child(hud)
	var panel := ColorRect.new()
	hud.add_child(panel)
	panel.position = free_r.position + Vector2(20.0, -10.0)
	panel.size = Vector2(120.0, free_r.size.y + 20.0)
	var sheet := ColorRect.new()                    # a full-screen layer (a fade): not space in use
	hud.add_child(sheet)
	sheet.size = screen
	var faint := ColorRect.new()                    # a hint faded out: not space in use
	hud.add_child(faint)
	faint.modulate.a = 0.0
	faint.position = free_r.position
	faint.size = free_r.size
	speech._hud_in = 0.0
	speech.say(spot, "Where the panel is.", Speech.SCENE, 52)
	_run(speech, 0.3)
	var moved: Rect2 = _rect_of(speech, cam, spot)
	out.append(check(free_r.size != Vector2.ZERO and free_r.intersects(panel.get_global_rect()) and not moved.intersects(panel.get_global_rect()) and Rect2(Vector2.ZERO, screen).encloses(moved) and moved.position.distance_to(free_r.position) < screen.x * 0.4, "a bubble moves off a HUD panel the least way, on screen (from %s to %s); a full-screen layer and a faded one do not count" % [str(free_r.position), str(moved.position)]))
	_run(speech, 6.0)
	panel.queue_free()
	var tag := Label3D.new()                        # a name tag where the bubble would be
	tag.text = "Oswin"
	tag.font_size = 48
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.add_to_group(Speech.OCCUPIED)
	world.add_child(tag)
	tag.global_position = cam.project_position(free_r.get_center(), 7.0)
	speech.say(spot, "Where the panel is.", Speech.SCENE, 53)
	_run(speech, 0.3)
	var off_tag: Rect2 = _rect_of(speech, cam, spot)
	out.append(check(free_r.intersects(speech._world_label_rect(cam, tag)) and off_tag.size != Vector2.ZERO and not off_tag.intersects(speech._world_label_rect(cam, tag)), "a bubble keeps off a name tag: no text on text (%s, tag %s)" % [str(off_tag), str(speech._world_label_rect(cam, tag))]))
	_run(speech, 6.0)
	tag.free()
	layer.free()

	var npc := Node3D.new()
	world.add_child(npc)
	npc.position = Vector3(1.5, 0.0, 0.5)
	var greet := Label3D.new()
	npc.add_child(greet)
	greet.text = "Good leaf this year."
	greet.modulate.a = 1.0
	speech.adopt(npc, func() -> Label3D: return greet)
	_run(speech, 0.2)
	out.append(check(not greet.visible and speech.saying(npc) and npc.get_node_or_null(Speech.NAME) != null and (npc.get_node(Speech.NAME) as Label3D).text == "Good leaf this year." and (npc.get_node(Speech.NAME) as Label3D).fixed_size, "an outside greeting is hidden and said as a capped bubble"))
	greet.modulate.a = 0.0
	_run(speech, 0.2)
	out.append(check(not speech.saying(npc), "the greeting goes when its owner lets it go"))
	speech.say(friend, "Leave her be!", Speech.SCENE)
	speech.say(people[5], "Overheard, with a place still free.", Speech.TALK, 31)
	greet.text = "Mind the stalks."
	greet.modulate.a = 1.0
	_run(speech, 0.2)
	out.append(check(speech.saying(friend), "a greeting is the crowd's: it never takes the encounter's place"))
	_run(speech, 6.0)
	var gone := Node3D.new()
	world.add_child(gone)
	speech.say(gone, "Words over someone about to go.", Speech.SCENE, 41)
	speech.say(gawker, "Waiting for a place, said over another.", Speech.STRUCK, 42)
	speech.say(gawker, "And again, sooner.", Speech.TALK, 43)
	_run(speech, 0.1)
	gone.free()
	_run(speech, 0.3)
	var stale := false
	for l in speech._shown:
		stale = stale or not is_instance_valid(l.body) or not is_instance_valid(l.label)
	out.append(check(not stale and speech.saying(gawker), "a speaker who goes takes their words; one bubble a body, the higher kept (%d up)" % speech._shown.size()))
	world.free()
	return out


static func _shown_rects(speech: Node, cam: Camera3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for l in speech._shown:
		var r: Rect2 = speech._rect(cam, l)
		if r.size != Vector2.ZERO:
			out.append(r)
	return out


static func _rect_of(speech: Node, cam: Camera3D, body: Node3D) -> Rect2:
	for l in speech._shown:
		if l.body == body:
			return speech._rect(cam, l)
	return Rect2()


static func _overlap(rects: Array[Rect2]) -> bool:
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				return true
	return false


static func _run(speech: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		speech._process(FRAME)
		t += FRAME

extends RefCounted
## C1 unit 1 (Body, 6 Oct): his buttons are the frame again, each reached with a real screen touch at its own centre
## (body_play_probe --body-play=buttons, in the live game). Sneak crouches and stands; Roll rolls on a tap; Parry
## guards on a tap and holds the guard while held; Attack's tap swings at the air with nothing in reach and its flick
## strikes the person he aims at (force from speed); Heavy reads "Knock down" facing a villager and its tap is the checked
## shove, and with nobody there it is the heavy swing; Swap takes the bow, Attack held draws it and lets go looses it,
## Heavy is his Triple Shot; Swap back (the bow before the villager: one struck may answer back). Hands keeps the powers' arcs clear of every one of his buttons. Frames
## buttons-01 .. buttons-07 (the game's own camera, so his buttons show). Unit 3: the arcs (_arcs). Unit 2: held Heavy's takedown (_takedown).
const Contact := preload("res://scripts/studio/village/contact.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")


static func _tap(p: Node, at: Vector2, finger: int, hold := 2) -> void:
	p.touch(finger, at, true)
	await p.frames(hold)
	p.touch(finger, at, false)
	await p.frames(2)


static func _settle(p: Node) -> void:
	var t := 0
	while (p.player.fighter.is_busy() or p.player.is_rolling() or p.player.fighter.aiming()) and t < 300:
		await p.frames(1)
		t += 1
	await p.active(0.3)


## Live foes (creatures, bandits; not villagers) within `reach` of `at` are set down 60 m further out, so none comes
## for him mid-proof. A fixture placement only, as the cast's.
static func _clear_foes(p: Node, at: Vector2, reach: float) -> void:
	for e in p.get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and e.has_method("is_alive") and e.is_alive() and not bool(e.get_meta("studio_villager", false)):
			var to := Vector2(e.global_position.x, e.global_position.z) - at
			if to.length() < reach:
				var far := at + (to.normalized() if to.length() > 0.1 else Vector2(1, 0)) * (reach + 60.0)
				(e as Node3D).global_position = Vector3(far.x, WorldShape.new().height_at(far.x, far.y) + 0.3, far.y)
				print("BODY BUTTONS moved foe ", e.name, " to ", far)


## B7 (unit 3's board showed a speech backing with no words): every bubble backing showing has its words showing.
static func _backings_have_words(p: Node) -> void:
	var bare := []
	for back in p.get_tree().current_scene.find_children("SpeechBacking*", "Sprite3D", true, false):
		var s := back as Sprite3D
		if not s.is_visible_in_tree() or s.modulate.a < 0.05:
			continue
		var label := s.get_parent().get_node_or_null("SpeechBubble") as Label3D
		var ok := label != null and label.is_visible_in_tree() and label.modulate.a >= 0.05 and not label.text.is_empty()
		if not ok:
			bare.append("%s back=%s a=%.2f label=%s text='%s' a=%.2f" % [s.get_parent().name, s.name, s.modulate.a, str(label != null),
				label.text if label != null else "", label.modulate.a if label != null else -1.0])
	print("BODY BACKINGS bare=", bare)
	p.check(bare.is_empty(), "every speech backing showing has its words showing (%d bare)" % bare.size())


## The killing ladder (desk, 6 Oct; Hilmi: "I do"): on a villager, Heavy's tap is the checked shove; held on one standing
## it is the knock-down blow (a strike of 750 or more, down); held on one down it is the finish (people_actions
## "finish": dead by this act, the death logged). One act a press, nothing else on them.
static func _ladder(p: Node, shoved: int, aside: Vector2) -> void:
	var player: Node3D = p.player
	var hands: Control = p.hud._hands
	var b: Dictionary = hands.buttons
	var v = VillageSession.village
	var actor: String = Contact.actor_of(player)
	await _settle(p)
	# Someone fresh (the one shoved and struck above may answer back), held where they stand, 4 m from anyone else.
	var who := -1
	for person in v.people:
		if person.id != shoved and person.alive and person.present and person.authored == "" and not person.locked and p.res.bodies.has(person.id) \
				and Rules.age_of(v, person) >= 18 and p.res._movers[person.id].can_move() and not person.body_facts.has("down"):
			who = person.id
			break
	var spot: Vector2 = p._talk_centre(who) if who >= 0 else Vector2.INF
	p.check(who >= 0 and spot != Vector2.INF, "someone fresh for the killing ladder, on open ground (%d)" % who)
	if who < 0 or spot == Vector2.INF:
		return
	p.res.owners.claim(who, "body_fixture", 2)
	p.res._movers[who].place(spot, PI)
	p.res._movers[who].hold(spot, spot + Vector2(0, -1))
	await p.active(1.0)
	await p.approach(who, 1.3)
	await p.active(0.3)
	var before: Array = v.people_facts.keys()
	var reads: String = b.heavy.verb
	p.touch(160, b.heavy.center(), true)
	await p.active(0.5)
	var held = hands.pointers.get(160)
	var knock: Dictionary = held.target.duplicate() if held != null else {}
	await p.capture("buttons-11-hold-knock-down")
	p.touch(160, b.heavy.center(), false)
	var struck: Dictionary = await p.landed(knock, "strike", who)
	await p.frames(2)
	var down: bool = v.people[who].body_facts.has("down")
	print("BODY LADDER knock stun=", player._stun, " busy=", player.fighter._busy, " heavy=", player.fighter._heavy, " severe=", knock.get("severe", {}), " struck=", struck, " held=", held != null)
	p.check(reads == "Knock down" and str(knock.get("severe", {}).get("kind", "")) == "knockdown" and struck.get("accepted", false) and int(struck.get("force", 0)) >= 750 and down,
		"held on a standing villager his Heavy is the knock-down blow: one strike at %d, down (Heavy read '%s')" % [int(struck.get("force", 0)), reads])
	await _settle(p)
	await p.active(0.4)
	await p.approach(who, 1.2)
	await p.active(0.2)
	var reads2: String = b.heavy.verb
	p.touch(161, b.heavy.center(), true)
	await p.active(0.5)
	var held2 = hands.pointers.get(161)
	var finish: Dictionary = held2.target.duplicate() if held2 != null else {}
	p.touch(161, b.heavy.center(), false)
	await p.active(0.5)
	var root: Dictionary = v.people_facts.get(p.deed(finish, "finish", who), {})
	var receipt: Dictionary = root.get("receipt", {})
	var acts := []
	for key: String in v.people_facts:
		var r = v.people_facts[key]
		if not before.has(key) and r is Dictionary and str(r.get("actor", "")) == actor and str(r.get("target", "")) == preload("res://scripts/studio/village/sim/people.gd").key(v, who):
			acts.append(str(r.get("verb", "")))
	await p.capture("buttons-12-finished")
	print("BODY LADDER stun=", player._stun, " busy=", player.fighter._busy, " knock=", knock.get("severe", {}), " finish=", finish.get("severe", {}), " receipt=", receipt)
	p.check(reads2 == "Finish" and receipt.get("accepted", false) and not v.people[who].alive and v.people[who].body_facts.has("dead") and receipt.get("death_event", null) != null and acts == ["strike", "finish"],
		"held again on them, down, his Heavy is the finish: dead by the act, the death logged, one act a press (Heavy read '%s', acts %s)" % [reads2, str(acts)])
	p.position_player(Vector3(aside.x, WorldShape.new().height_at(aside.x, aside.y) + 0.05, aside.y))
	await p.active(1.0)


## C1 unit 6 (the control map, design table 1): the rows not reached above. His light combo: three Attack taps in its
## chain window swing his 3-swing combo in order. His Compact setting: Heavy and Parry go, a flick up on Attack is the
## Heavy tap and a flick left his guard, a plain tap still uses. Burrow from its arc, its arc reads Drag under the
## ground, and Attack's tap there is Emerge (TapRule's urgent slot).
static func _map_rest(p: Node) -> void:
	var player: Node3D = p.player
	var hud: Node = p.hud
	var hands: Control = hud._hands
	var b: Dictionary = hands.buttons
	await p.active(1.5)
	var steps := []
	for i in 3:
		await _tap(p, b.attack.center(), 150 + i)
		await p.frames(1)
		steps.append(int(player.fighter._step))
		var t := 0
		while player.fighter.is_busy() and t < 60:
			await p.frames(1)
			t += 1
	p.check(steps == [0, 1, 2], "three Attack taps in his chain window swing his 3-swing combo in order (%s)" % str(steps))
	await p.active(1.5)
	var compact_was: bool = Settings.compact_controls
	Settings.compact_controls = true
	hud._show_heavy()
	await p.frames(2)
	var hidden: bool = not b.heavy.is_visible_in_tree() and not b.parry.is_visible_in_tree()
	var at: Vector2 = b.attack.center()
	p.touch(153, at, true)
	await p.frames(1)
	p.drag(153, at, at + Vector2(0, -60))
	await p.frames(2)
	p.touch(153, at + Vector2(0, -60), false)
	await p.frames(2)
	var heavy_flick: bool = player.fighter._heavy and player.fighter.is_busy()
	await _settle(p)
	await p.active(1.2)
	p.touch(154, at, true)
	await p.frames(1)
	p.drag(154, at, at + Vector2(-60, 0))
	await p.frames(2)
	var guard_flick: bool = player._guard > 0.0
	p.touch(154, at + Vector2(-60, 0), false)
	await p.active(1.2)
	await _tap(p, at, 155)
	await p.frames(1)
	var tap_swing: bool = player.fighter.is_busy()
	await _settle(p)
	Settings.compact_controls = compact_was
	hud._show_heavy()
	await p.frames(2)
	p.check(hidden and heavy_flick and guard_flick and tap_swing and b.heavy.is_visible_in_tree(), "his Compact setting: no Heavy or Parry, a flick up on Attack is the Heavy tap, left his guard, a tap still uses (hidden %s up %s left %s tap %s)" % [str(hidden), str(heavy_flick), str(guard_flick), str(tap_swing)])
	await p.active(1.2)
	Classes.choose("delver")
	await p.frames(3)
	await _tap(p, hands.surfaces()["power:burrow"], 156)
	await p.active(0.6)
	var under: bool = player.burrowed()
	var verb: String = hands.attack_verb()
	await p.capture("buttons-10-burrowed")
	await _tap(p, b.attack.center(), 157)
	await p.active(1.2)
	p.check(under and verb == "Emerge" and not player.burrowed(), "Burrow from its arc takes him under; there his Attack reads Emerge and its tap brings him up (verb '%s')" % verb)
	Classes.choose("pyromancer")
	await p.active(1.5)


## C1 unit 5: sliding between his buttons (his slide setting on). One fast move that crosses Parry between two events
## still hands the finger to Parry (sampled every 8 px; the move ends on no button); a flick armed on Attack never hands
## over to Heavy on its way; a finger slid from Parry out into a power's arc arms that power, and its lift casts it.
static func _slides(p: Node) -> void:
	var player: Node3D = p.player
	var hands: Control = p.hud._hands
	var b: Dictionary = hands.buttons
	var was: bool = Settings.slide_buttons
	Settings.slide_buttons = true
	Classes.choose("pyromancer")
	await p.active(1.5)
	var from: Vector2 = b.sneak.center()
	var to: Vector2 = from + Vector2(-144, 0) # (past Parry's 1.15 r, short of the arcs: the move ends on nothing)
	p.touch(130, from, true)
	await p.frames(2)
	p.drag(130, from, to)
	await p.frames(2)
	var crossed: bool = b.parry._held == 130 and b.sneak._held == -1
	print("BODY SLIDE from=", from, " to=", to, " sneak=", b.sneak.center(), "/", b.sneak.radius, " held ", b.sneak._held, " parry=", b.parry.center(), "/", b.parry.radius, " held ", b.parry._held, " hands=", hands.pointers.keys(), " arc_at_to='", hands.role_at(to), "' slide=", Settings.slide_buttons)
	p.touch(130, to, false)
	await p.frames(2)
	if player.sneaking:
		player.set_sneaking(false)
	var ends_on := ""
	for id: String in b:
		if (b[id] as Control).is_visible_in_tree() and to.distance_to(b[id].center()) < b[id].radius:
			ends_on = id
	p.check(crossed and ends_on == "" and hands.role_at(to) == "", "one fast move from Sneak across Parry, ending on no button and no arc, hands the finger to Parry (sampled every 8 px)")
	await p.active(1.5)
	var at: Vector2 = b.attack.center()
	var toward: Vector2 = (b.heavy.center() - at).normalized()
	p.touch(131, at, true)
	await p.frames(1)
	var last := at
	for k in 6:
		var next: Vector2 = at + toward * 30.0 * (k + 1)
		p.drag(131, last, next)
		last = next
		await p.frames(1)
	var kept: bool = b.attack._held == 131 and b.heavy._held != 131
	p.touch(131, last, false)
	await p.frames(3)
	p.check(kept, "a flick armed on Attack never hands over to Heavy on its way (Attack keeps the finger: %s)" % str(kept))
	await p.active(1.5)
	var parry: Vector2 = b.parry.center()
	var out: Vector2 = (parry - hands.arc_centre()).normalized()
	var into: Vector2 = hands.arc_centre() + out * (hands.arc_inner() + hands.arc_outer()) * 0.5
	var arc: String = hands.role_at(into)
	p.touch(132, parry, true)
	await p.frames(2)
	p.drag(132, parry, parry.lerp(into, 0.5))
	await p.frames(1)
	p.drag(132, parry.lerp(into, 0.5), into)
	await p.frames(2)
	var armed: bool = hands.pointers.has(132) and str(hands.pointers[132].role) == arc and b.parry._held == -1
	p.touch(132, into, false)
	await p.frames(4)
	var power: String = arc.trim_prefix("power:")
	p.check(arc.begins_with("power:") and armed and Classes.cooldown_left(power) > 0.0, "a finger slid from Parry into %s's arc arms it, and the lift casts it (armed %s)" % [power, str(armed)])
	Settings.slide_buttons = was
	await p.active(1.5)
	await _editor(p)


## His "Move buttons" editor moves the arc row and the stick's rest spot too: dragged by touch, Done saves them, Hands
## draws the arcs round the new spot and the stick's hint moves. The layout is put back after (his settings file).
static func _editor(p: Node) -> void:
	var hud: Node = p.hud
	var hands: Control = hud._hands
	var spots_before: Dictionary = Settings.button_spots.duplicate()
	var scale_before: float = Settings.button_scale
	var centre_before: Vector2 = hands.arc_centre()
	hud.edit_buttons()
	await p.frames(3)
	var editor: Control = null
	for c in hud.get_children():
		if c.get_script() != null and str((c.get_script() as Script).resource_path).ends_with("ui/button_editor.gd"):
			editor = c
	var items := {}
	for b in (editor.get("buttons") if editor != null else []):
		if str(b.id) in ["arcs", "stick"]:
			items[str(b.id)] = b
	var moved := {"arcs": Vector2(-120, -40), "stick": Vector2(60, -50)}
	for id: String in items:
		var at: Vector2 = items[id].center()
		p.touch(140, at, true)
		await p.frames(1)
		for k in 4:
			p.drag(140, at + moved[id] * k / 4.0, at + moved[id] * (k + 1) / 4.0)
			await p.frames(1)
		p.touch(140, at + moved[id], false)
		await p.frames(2)
	await p.capture("buttons-09-editor")
	if editor != null:
		editor.call("_done")
	await p.frames(3)
	var view: Vector2 = p.get_viewport().get_visible_rect().size
	var arcs_moved: bool = Settings.button_spots.has("arcs") and hands.arc_centre().distance_to(centre_before + moved["arcs"]) < 3.0
	var stick_moved: bool = Settings.button_spots.has("stick") and (view - Vector2(Settings.button_spots["stick"])).distance_to(Vector2(220, view.y - 190) + moved["stick"]) < 3.0
	p.check(items.size() == 2 and arcs_moved and stick_moved, "his Move buttons editor moves the power arcs and the stick's rest spot by touch, and Done keeps them (arcs %s, stick %s)" % [str(arcs_moved), str(stick_moved)])
	Settings.set_button_layout(spots_before, scale_before)
	await p.frames(3)


## C1 unit 4: stamina retired, recovery limits. After a roll lands his Roll rests 0.45 s (its rim counts it down) and a
## tap then is refused with his shake; a third roll in a row waits 1 s. The heavy swing commits him: a Roll tap during it
## is refused. Nothing spends stamina any more.
static func _until_landed(p: Node) -> void:
	var t := 0
	while p.player.is_rolling() and t < 120:
		await p.frames(1)
		t += 1


static func _recovery(p: Node) -> void:
	var player: Node3D = p.player
	var b: Dictionary = p.hud._hands.buttons
	await p.active(3.0) # (over 2 s since the last landing: a fresh chain)
	var rests := []
	var refused := false
	for i in 3:
		await _tap(p, b.roll.center(), 120 + i)
		await _until_landed(p)
		await p.frames(1)
		rests.append(snappedf(float(player._roll_rest), 0.01))
		if i == 2:
			await p.capture("buttons-08-roll-resting")
		if i == 0:
			await _tap(p, b.roll.center(), 125)
			refused = not player.is_rolling() and float(b.roll._shake) > 0.0
		var t := 0
		while float(player._roll_rest) > 0.0 and t < 90:
			await p.frames(1)
			t += 1
	p.check(absf(float(rests[0]) - 0.45) < 0.06 and absf(float(rests[1]) - 0.45) < 0.06 and absf(float(rests[2]) - 1.0) < 0.06 and refused,
		"his Roll rests 0.45 s after landing and refuses a tap then (his shake); the third roll in a row waits 1 s (rests %s, refused %s)" % [str(rests), str(refused)])
	await p.active(1.2)
	await _tap(p, b.heavy.center(), 126)
	await p.frames(3)
	await _tap(p, b.roll.center(), 127)
	var held: bool = not player.is_rolling() and player.fighter.studio_committed()
	await _settle(p)
	var t2 := 0
	while player.fighter.studio_committed() and t2 < 90:
		await p.frames(1)
		t2 += 1
	await p.frames(2)
	await _tap(p, b.roll.center(), 128)
	var free_again: bool = player.is_rolling()
	await _until_landed(p)
	p.check(held and free_again and player.stamina.value == player.stamina.max_value() and not player.stamina.winded,
		"the heavy swing commits him (a Roll tap during it is refused), then he rolls again; stamina never spent (held %s, after %s)" % [str(held), str(free_again)])
	await p.active(1.2)


## C1 unit 3: the class powers on their arcs. A tap fires at his own auto target; a drag aims, shows its preview on the
## ground (armed, its words), and the lift fires it the aimed way; Shadow Dance with nobody near says why and spends
## nothing. Pyromancer's Meteor by tap; Delver's Fault Line and Sinkhole aimed; the Shade's Mirage aimed, Switch by
## tap. Frames buttons-06-fault-aimed, buttons-07-cooling.
static func _stroke(p: Node, finger: int, at: Vector2, by: Vector2, hold_frames := 4) -> void:
	p.touch(finger, at, true)
	await p.frames(2)
	for k in 6:
		p.drag(finger, at + by * float(k) / 6.0, at + by * float(k + 1) / 6.0)
		await p.frames(1)
	await p.frames(hold_frames)


static func _arcs(p: Node) -> void:
	var hands: Control = p.hud._hands
	var player: Node3D = p.player
	Classes.choose("pyromancer")
	await p.frames(3)
	var arcs: Dictionary = hands.surfaces()
	await _tap(p, arcs["power:meteor"], 110)
	await p.frames(4)
	p.check(Classes.cooldown_left("meteor") > 0.0, "a tap on Meteor's arc casts it at his own aim (cooldown %.2f)" % Classes.cooldown_left("meteor"))
	await p.active(1.5)
	Classes.choose("delver")
	await p.frames(3)
	arcs = hands.surfaces()
	var up: Vector2 = Vector2(-60, -50) * hands.unit()
	await _stroke(p, 111, arcs["power:fault_line"], up)
	var aimed: bool = hands.pointers.has(111) and hands.pointers[111].armed and str(hands.preview().verb) == "power:fault_line"
	var forward: Vector3 = hands.pointers[111].target.get("forward", Vector3.ZERO) if hands.pointers.has(111) else Vector3.ZERO
	await p.capture("buttons-06-fault-aimed")
	p.touch(111, arcs["power:fault_line"] + up, false)
	await p.frames(4)
	var facing := Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	p.check(aimed and Classes.cooldown_left("fault_line") > 0.0 and facing.dot(forward) > 0.95,
		"Fault Line aimed by a drag shows its strip, and the lift casts it the aimed way (facing . aim %.2f)" % facing.dot(forward))
	await p.active(1.2)
	await _stroke(p, 112, arcs["power:sinkhole"], Vector2(0, -70) * hands.unit())
	var pit: bool = hands.pointers.has(112) and hands.pointers[112].armed
	p.touch(112, arcs["power:sinkhole"] + Vector2(0, -70) * hands.unit(), false)
	await p.frames(4)
	p.check(pit and Classes.cooldown_left("sinkhole") > 0.0, "Sinkhole aimed by a drag opens where it was aimed (cooldown %.2f)" % Classes.cooldown_left("sinkhole"))
	await p.capture("buttons-07-cooling")
	await p.active(3.0) # (the pit closes)
	Classes.choose("shade")
	await p.frames(3)
	arcs = hands.surfaces()
	await _stroke(p, 113, arcs["power:shadow_dance"], Vector2(0, -60) * hands.unit())
	var said: String = hands._hint_words
	p.touch(113, arcs["power:shadow_dance"] + Vector2(0, -60) * hands.unit(), false)
	await p.frames(4)
	p.check(said.begins_with("No one close enough") and Classes.cooldown_left("shadow_dance") == 0.0, "Shadow Dance with nobody near says why before release and spends nothing ('%s')" % said)
	await _stroke(p, 114, arcs["power:mirage"], Vector2(50, -40) * hands.unit())
	p.touch(114, arcs["power:mirage"] + Vector2(50, -40) * hands.unit(), false)
	await p.frames(4)
	var mirage: bool = Classes.cooldown_left("mirage") > 0.0
	await p.active(1.0)
	await _tap(p, arcs["power:switch"], 115)
	await p.frames(4)
	p.check(mirage and Classes.cooldown_left("switch") > 0.0, "the Shade's Mirage aimed by a drag and Switch by a tap both cast (mirage %s)" % str(mirage))
	# The fourth class (his sealed slot, the Tidecaller): its powers on the same arcs, its previews from its own data.
	if Classes.CLASSES.has("tidecaller"):
		Classes.choose("tidecaller")
		await p.frames(3)
		arcs = hands.surfaces()
		var tide: Node = player.abilities.get("tidecaller")
		var cone: Dictionary = tide.preview("rime_wave", player.global_position + Vector3(0, 0, 5)) if tide != null else {}
		await _stroke(p, 116, arcs.get("power:tempest", Vector2.ZERO), Vector2(0, -60) * hands.unit())
		var storm: bool = hands.pointers.has(116) and hands.pointers[116].armed and str(hands.preview().verb) == "power:tempest"
		await p.capture("buttons-13-tempest-aimed")
		p.touch(116, arcs.get("power:tempest", Vector2.ZERO) + Vector2(0, -60) * hands.unit(), false)
		await p.frames(4)
		p.check(arcs.has("power:tempest") and storm and Classes.cooldown_left("tempest") > 0.0 and str(cone.get("shape", "")) in ["cone", "ring"],
			"the Tidecaller's powers sit on the same arcs: Tempest aimed shows its own reach and casts; Rime Wave describes its %s" % str(cone.get("shape", "-")))
	Classes.choose("pyromancer")
	await p.active(1.5)


## C1 unit 2: holding Heavy is the severe act. An unaware cutthroat, his back turned 1.3 m ahead, the player crouched:
## Heavy reads "Takedown" and Attack's tap offers no takedown; held, Heavy's ring fills and at 0.35 s his stealth
## Takedown fells the bandit while still held; letting go does nothing more. Frame buttons-05-hold-takedown.
static func _takedown(p: Node, at: Vector2) -> void:
	var player: Node3D = p.player
	var hands: Control = p.hud._hands
	var b: Dictionary = hands.buttons
	p.position_player(Vector3(at.x, WorldShape.new().height_at(at.x, at.y) + 0.05, at.y))
	player.set_sneaking(true)
	var ahead := Vector3(at.x, 0, at.y + 1.3)
	ahead.y = WorldShape.new().height_at(ahead.x, ahead.z)
	var bandit := Bandit.new()
	bandit.kind = "cutthroat"
	bandit.player = player
	bandit.post = ahead
	bandit.post_turn = 0.0 # facing +z: away from him
	bandit.look = BanditLooks.make(0, 7)
	p.get_tree().current_scene.add_child(bandit)
	bandit.global_position = ahead + Vector3(0, 0.3, 0)
	var t := 0
	while str(player.fighter.verb) != "Takedown" and t < 90:
		await p.frames(1)
		t += 1
	await p.frames(3)
	var reads: String = b.heavy.verb
	var tap: Dictionary = hands.driver.tap_context()
	p.check(str(player.fighter.verb) == "Takedown" and reads == "Takedown" and str(tap.get("slot", "")) != "takedown" and hands.attack_verb() != "Takedown",
		"behind an unaware bandit his Heavy reads Takedown and his Attack's tap offers none (fighter '%s', Heavy '%s', tap %s '%s')" % [str(player.fighter.verb), reads, str(tap.get("slot", "")), hands.attack_verb()])
	p.touch(101, b.heavy.center(), true)
	await p.active(0.2)
	var early: bool = bandit.is_alive()
	await p.active(0.12)
	await p.capture("buttons-05-hold-takedown")
	await p.active(0.25)
	var felled: bool = not bandit.is_alive()
	p.touch(101, b.heavy.center(), false)
	await p.active(0.4)
	p.check(early and felled and not player.fighter._heavy, "held, his Heavy's ring fills and at 0.35 s his stealth Takedown fells the bandit, still held (alive at 0.2 s %s, felled by 0.57 s %s)" % [str(early), str(felled)])
	player.set_sneaking(false)
	if is_instance_valid(bandit):
		bandit.queue_free()
	await p.active(0.5)
	# A live foe he has targeted, freed before his next step (a despawn, a region change): nothing reads the freed one
	# (physical_input.in_reach, his lock marker; the job fails on any script error).
	var other := Bandit.new()
	other.kind = "cutthroat"
	other.player = player
	other.post = ahead
	other.post_turn = PI
	other.look = BanditLooks.make(0, 9)
	p.get_tree().current_scene.add_child(other)
	other.global_position = ahead + Vector3(0, 0.3, 0)
	var t2 := 0
	while player.fighter.target != other and t2 < 90:
		await p.frames(1)
		t2 += 1
	var targeted: bool = player.fighter.target == other
	other.free()
	await p.frames(6)
	p.check(targeted and p.hud._hands.is_visible_in_tree(), "a targeted foe freed before his next step leaves nothing reading it (targeted %s)" % str(targeted))
	await p.active(0.5)


static func run(p: Node) -> void:
	var live: Node = p.get_tree().current_scene.get_node("VillageLive")
	p.res = live.registry
	while not p.res.all_built():
		await p.get_tree().process_frame
	var hud: Node = p.hud
	var hands: Control = hud._hands
	var player: Node3D = p.player
	var b: Dictionary = hands.buttons
	var v = VillageSession.village
	var who := -1
	for person in v.people:
		if person.alive and person.present and person.authored == "" and not person.locked and p.res.bodies.has(person.id) and Rules.age_of(v, person) >= 18 and p.res._movers[person.id].can_move():
			who = person.id
			break
	p.check(who >= 0, "someone for his buttons to reach")
	if who < 0:
		return
	p.cast.append(who)
	p.res.owners.claim(who, "body_fixture", 2)
	var room: Vector2 = p._talk_centre(who)
	p.check(room != Vector2.INF, "open ground clear of his things (%s)" % str(room))
	if room == Vector2.INF:
		return
	Classes.choose("pyromancer") # (a class, so Hands has its power arcs to keep clear of his buttons)
	p.res._movers[who].place(room, PI)
	p.res._movers[who].hold(room, room + Vector2(0, -1))
	var aside := Vector2.INF # him alone, the person 8 m off, nothing to use or gather in reach
	for k in 8:
		var q := room + Vector2.from_angle(TAU * k / 8.0) * 8.0
		if not p.res._world.standable.call(q):
			continue
		p.position_player(Vector3(q.x, WorldShape.new().height_at(q.x, q.y) + 0.05, q.y))
		await p.frames(6)
		if player.call("_nearest_station") == null and str(player.gatherer.verb) == "" and str(player.fighter.verb) == "":
			aside = q
			break
	p.check(aside != Vector2.INF, "open ground 8 m from them with nothing to use or gather (%s)" % str(aside))
	if aside == Vector2.INF:
		return
	_clear_foes(p, aside, 25.0) # (a fixture arrangement: a boar grazing by the square came for him mid-proof)
	await p.active(0.5)
	var shown := true
	for id: String in ["attack", "heavy", "parry", "sneak", "roll"]:
		shown = shown and (b[id] as Control).is_visible_in_tree()
	var clear := true
	for id: String in b:
		var button: ActionButton = b[id]
		for k in 16:
			if button.is_visible_in_tree() and hands.role_at(button.center() + Vector2.from_angle(TAU * k / 16.0) * button.radius) != "":
				clear = false
	p.check(shown and clear and hands.is_visible_in_tree() and not hands.arcs().is_empty(),
		"his Attack, Heavy, Parry, Sneak and Roll show, and Hands' power arcs keep clear of every one of them")
	await p.capture("buttons-01-frame")
	# Sneak: a tap crouches, a second stands.
	await _tap(p, b.sneak.center(), 91)
	var crouched: bool = player.sneaking
	await _tap(p, b.sneak.center(), 91)
	p.check(crouched and not player.sneaking, "his Sneak: a tap crouches, another stands")
	# Roll: a tap rolls.
	await _tap(p, b.roll.center(), 92)
	var rolled: bool = player.is_rolling()
	await _settle(p)
	p.check(rolled, "his Roll: a tap rolls")
	await p.active(1.0)
	await _recovery(p)
	# Parry: a tap guards (his timing); held, the guard stays up; let go, it drops.
	await _tap(p, b.parry.center(), 93)
	var guarded: bool = player._guard > 0.0
	await p.active(1.2) # (his guard rest)
	p.touch(93, b.parry.center(), true)
	await p.active(0.6)
	var holding: bool = player._studio_guard and player._guard > 0.0
	p.touch(93, b.parry.center(), false)
	await p.frames(3)
	p.check(guarded and holding and not player._studio_guard, "his Parry: a tap guards, held it holds the guard, let go it drops")
	await p.active(1.0)
	# Attack with nothing in reach: his swing at the air.
	var verb: String = b.attack.verb
	await _tap(p, b.attack.center(), 94)
	var swung: bool = player.fighter.is_busy()
	await _settle(p)
	p.check(verb == "Attack" and swung, "his Attack with nothing in reach reads Attack and swings at the air (verb '%s')" % verb)
	# Heavy with nobody there: the heavy swing.
	await _tap(p, b.heavy.center(), 95)
	var heavy_swing: bool = player.fighter._heavy and player.fighter.is_busy()
	await _settle(p)
	p.check(b.heavy.verb == "Heavy" and heavy_swing, "his Heavy with nobody there is the heavy swing")
	# The bow (before anyone is struck: one struck may answer back): Swap takes it, Attack held draws and letting go looses, Heavy is his Triple Shot, Swap back.
	p.position_player(Vector3(aside.x, WorldShape.new().height_at(aside.x, aside.y) + 0.05, aside.y))
	Gear.has_bow = true
	Gear.weapon = "sword"
	Gear.changed.emit()
	await p.frames(3)
	await _tap(p, b.swap.center(), 98)
	var bow: bool = Gear.weapon == "bow"
	p.touch(99, b.attack.center(), true)
	await p.active(0.5)
	var drawing: bool = player.fighter.aiming()
	await p.capture("buttons-04-bow-drawn")
	p.touch(99, b.attack.center(), false)
	await p.active(0.4)
	var loosed: bool = not player.fighter.aiming()
	await _settle(p)
	await p.active(0.6)
	var panels := []
	for c in hud.get_children():
		if c is Control and (c as Control).visible and c.get_script() != null and not str((c.get_script() as Script).resource_path).ends_with("action_button.gd"):
			panels.append(str((c.get_script() as Script).resource_path).get_file())
	print("BODY BUTTONS foes=", p.get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return e is Node3D and e.has_method("is_alive") and e.is_alive() and not bool(e.get_meta("studio_villager", false))).map(func(e: Node3D) -> String: return "%s@%s" % [e.name, str(Vector2(e.global_position.x, e.global_position.z).snapped(Vector2.ONE))]))
	print("BODY BUTTONS state locked=", Controls.locked, " health=", player.health, " down=", player.is_down(), " hands=", hands.is_visible_in_tree(), " attack=", b.attack.is_visible_in_tree(), " ui=", panels)
	print("BODY BUTTONS before triple stamina=", player.stamina.value, " winded=", player.stamina.winded, " busy=", player.fighter._busy, " rest=", player.fighter._bow_rest, " draw=", player.fighter._draw, " heavy_visible=", b.heavy.is_visible_in_tree(), " weapon=", Gear.weapon, " roll=", player._roll, " stun=", player._stun)
	p.touch(100, b.heavy.center(), true)
	var triple := false
	for i in 12: # (his Triple Shot draws 0.45 s and looses by itself: seen at any frame of it)
		await p.frames(1)
		triple = triple or (bool(player.fighter.get("_triple")) and player.fighter.aiming())
	p.touch(100, b.heavy.center(), false)
	print("BODY BUTTONS after triple draw=", player.fighter._draw, " triple=", player.fighter.get("_triple"), " seen=", triple)
	await _settle(p)
	await _tap(p, b.swap.center(), 98)
	print("BODY BUTTONS end weapon=", Gear.weapon, " hands=", hands.is_visible_in_tree(), " swap=", b.swap.is_visible_in_tree(), " locked=", Controls.locked)
	p.check(bow and drawing and loosed and triple and Gear.weapon == "sword" and hands.is_visible_in_tree(),
		"his Swap takes the bow, Attack held draws it and let go looses it, Heavy is his Triple Shot, Swap gives the sword back (bow %s draw %s loose %s triple %s)" % [str(bow), str(drawing), str(loosed), str(triple)])
	await _takedown(p, aside)
	# Facing a villager: Heavy reads Shove, its tap is the checked shove at the shove's top force.
	await p.approach(who, 1.3)
	await p.active(0.3)
	var reads: String = b.heavy.verb
	await p.capture("buttons-02-heavy-reads-shove")
	p.touch(96, b.heavy.center(), true)
	await p.frames(2)
	var pressed = hands.pointers.get(96)
	var shove: Dictionary = pressed.target.duplicate() if pressed != null else {}
	var ringed: bool = hands.ring_target() == p.res.bodies[who]
	p.touch(96, b.heavy.center(), false)
	var shoved: Dictionary = await p.landed(shove, "shove", who)
	p.check(reads == "Knock down" and ringed and int(shove.get("target", -2)) == who and shoved.get("accepted", false) and int(shoved.get("force", 0)) == 700,
		"facing a villager his Heavy reads what holding does (Knock down), rings them before release, and its tap is the checked shove (force %d)" % int(shoved.get("force", 0)))
	await p.capture("buttons-03-shoved")
	await p.active(2.0)
	# Attack's flick at them: a strike with force from its speed.
	await p.approach(who, 1.3)
	await p.active(0.3)
	var at: Vector2 = b.attack.center()
	var dir: Vector3 = p.res.bodies[who].global_position - player.global_position
	var offset: Vector2 = Vector2(dir.x, dir.z).normalized().rotated(Controls.cam_yaw) * 58 * hands.unit()
	p.touch(97, at, true)
	var from := at
	for i in 3:
		var next: Vector2 = at + offset * float(i + 1) / 3.0
		p.drag(97, from, next)
		from = next
		await p.get_tree().process_frame
	await p.active(0.07)
	var flick = hands.pointers.get(97)
	var strike: Dictionary = flick.target.duplicate() if flick != null else {}
	var force: int = flick.flick_force() if flick != null else 0
	p.touch(97, from, false)
	var struck: Dictionary = await p.landed(strike, "strike", who)
	p.check(flick != null and str(flick.intent) in ["strike", "heavy"] and struck.get("accepted", false) and int(struck.get("force", 0)) == force,
		"his Attack's flick strikes the one he aims at, its force from its speed (%d)" % force)
	await _settle(p)
	await _ladder(p, who, aside)
	await _slides(p)
	await _map_rest(p)
	# Last: the powers (the Shade's double taunts every foe near, and Meteor and the pit reach the villagers).
	p.position_player(Vector3(aside.x, WorldShape.new().height_at(aside.x, aside.y) + 0.05, aside.y))
	await p.active(0.5)
	await _arcs(p)
	_backings_have_words(p)
	if p.shot_path != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		p.check(p.get_viewport().get_texture().get_image().save_png(p.shot_path) == OK, "final buttons image")

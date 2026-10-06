extends Node
## Region presentation only. The persistent session admits actions and owns every consequence.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Stage := preload("res://scripts/studio/village/stage.gd")
const Residents := preload("res://scripts/studio/village/residents.gd")
var registry: Node3D
var _stage: Node3D
var _event := -1
var _revision := -1
var _player: Node3D
var _notice := ""
var last_hint := ""
var _spots := {}                     # "inspect" / "plant": the UseSpot at the place, made when a hearing opens
var _spot_event := {}                # the event each of those was made for
var _traces := {}
var _storm_props := {}
var _rung := {}                      # town meetings the bell was rung for (sim/town_meeting.gd)
const Props := preload("res://scripts/studio/village/props.gd")
const StageProps := preload("res://scripts/studio/village/stage_props.gd")
const UseSpot := preload("res://scripts/world/use_spot.gd")
const React := preload("res://scripts/studio/village/resident_react.gd")
const Talk := preload("res://scripts/studio/village/resident_talk.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const Sites := preload("res://scripts/studio/village/sites.gd")
const BELL := preload("res://assets/sounds/village_bell.wav")
const SPOT_SIDE := 0.9                # metres either side of a door for Inspect and Plant wood
const SPOT_REACH := 1.5               # (0.9 across and 0.4 out, 1.5 reach: 2.48 m from the door at most; the rules allow 2.5)

static func on_device(tree: SceneTree) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-encounter="):
			preload("res://scripts/studio/village/encounter_probe.gd").on_device(tree)
		if arg=="--owner-play":
			load("res://scripts/studio/village/owner_play_probe.gd").on_device(tree)
		if arg.begins_with("--merge-check="): # merge-enea M1: studio/merge/<name>.gd, in the live village
			load("res://scripts/studio/merge/%s.gd" % arg.trim_prefix("--merge-check=")).on_device(tree)
	# main attaches the same normal-game authority and bridge for this launch argument;
	# --people-probe=<mode> also plays the game as a player would (people_probe.gd)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--people-probe="):
			load("res://scripts/studio/village/people_probe.gd").on_device(tree)

func _ready() -> void:
	if not VillageSession.recovery_notice.is_empty():
		# said once, on the first frame the player can read it (a hint is one short line: Enea's label does not wrap)
		_notice = "Village record damaged; items restored." if VillageSession.recovery_notice.length() > 40 else VillageSession.recovery_notice
		VillageSession.recovery_notice = ""
	registry = Residents.new()
	add_child(registry)
	var provoke: Node = preload("res://scripts/studio/village/provoke.gd").new()   # picking a fight (Pass 2, M2)
	provoke.name = "Provoke"
	provoke.registry = registry
	add_child(provoke)
	provoke.struck_hard.connect(registry.on_struck)   # a blow shows on the body: a flinch, a step back, heads turn
	# HoldToFight stays preserved; the Hand/Palm surfaces own talk/guard/contact without a fight mode.
	registry.people_bridge = preload("res://scripts/studio/village/people_bridge.gd").new(registry)
	add_child(registry.people_bridge)
	_player = get_tree().get_first_node_in_group("player")
	var news: Node = preload("res://scripts/studio/news/village_news.gd").new()   # the village's news (plan VILLAGE-LIFE-AND-NEWS)
	news.name = "VillageNews"
	add_child(news)

func _process(_delta: float) -> void:
	var v = VillageSession.village
	if v == null:
		return
	var now := int(v.runtime.now)
	# the rules count the player's eyes where deeds are done (crime.gd player_sees): tell them where the player is
	Runtime.set_player(v, _player != null and not VillageSession.background, int(_player.global_position.x * 10.0), int(_player.global_position.z * 10.0))
	if _stage != null:
		var e := Runtime.event_by_id(v, _event)
		if e.is_empty() or e.phase == "cancelled" or now >= int(e.end):
			_close()
		else:
			var st := Runtime.staging(v, _event)
			for actor in _stage._actors:
				if actor == _stage._victim and Runtime.terminal(e):
					continue # the committed fall or departure remains visible briefly
				if not v.people[actor.id].alive or not v.people[actor.id].present:
					actor.gone = true
					actor.pending.clear()
					if actor.body != null:
						_stage._hide(actor, true)
			_stage.external_minute = float(now - int(st.day) * 1440) + float(v.runtime.fraction)
			if int(e.revision) != _revision:
				_revision = int(e.revision)
				if e.outcome in ["rescued", "spared"]:
					_stage.show_rescue()
				elif e.type == "hearing" and Runtime.terminal(e):
					_stage.show_verdict(e.outcome)
				elif Runtime.terminal(e):
					var resident = v.people[int(e.victim)]
					_stage.show_outcome(e.outcome, resident.alive, resident.present)
	# one stage at a time: a hearing, public act or rite outranks a small scene (an incident gives way to it)
	var wanted := {}
	for e: Dictionary in v.runtime.events:
		if not Runtime.terminal(e) and now >= int(e.from) - 20 and now < int(e.deadline):
			if wanted.is_empty() or (wanted.type == "incident" and e.type != "incident"):
				wanted = e
	if _stage != null and not wanted.is_empty() and int(wanted.id) != _event and wanted.type != "incident":
		var shown := Runtime.event_by_id(v, _event)
		if not shown.is_empty() and shown.type == "incident":
			_close()
	if _stage == null and not wanted.is_empty():
		_open(wanted)
	_update_cue(now)
	_update_choices()
	_meeting_bells(v, now)
	_update_traces()
	_update_storms()

func _open(e: Dictionary) -> void:
	var v = VillageSession.village
	var st := Runtime.staging(v, int(e.id))
	if st.is_empty():
		return
	_stage = Stage.new()
	_stage.resident_registry = registry
	_stage.external_clock = true
	if e.type != "incident" and registry.get("village_reactions") != null:
		var eid := int(e.id)              # its end breaks up as people do (village_reactions.gd; an incident's own leaves stay)
		_stage.end_handler = func(ids: Array, at: Vector2, role: String) -> void:
			registry.village_reactions.end_of(eid, ids, at, role)
	add_child(_stage)
	_event = int(e.id)
	_revision = int(e.revision)
	var people := []
	for person: Dictionary in st.people:
		var p = v.people[int(person.id)]
		if p.alive and p.present and not p.body_facts.has("carried") and not registry.is_protected(int(person.id)):     # Enea's own characters are never borrowed
			people.append(person)
	_stage.play(st, people)
	var minute := float(int(v.runtime.now) - int(st.day) * 1440)
	# Preparation can start before the first beat without fast-forwarding the event clock.
	_stage._clock = (minf(minute, float(st.start)) - float(st.start)) * 0.5
	_stage.external_minute = minute
	if minute > float(st.start):
		_stage._player = null # restoration cannot invent player contacts from historical projectiles
		_stage.skip_to(minute)
		_stage._player = _player
	_stage.action_authority = _act
	if minute <= float(st.start) and e.type != "incident":
		_ring_bell()                            # the cue: the bell at the square, and the villagers walking there

## A town meeting gathering (sim/town_meeting.gd): the bell calls the village to the square, wherever the player is.
func _meeting_bells(v, now: int) -> void:
	for h: Dictionary in v.runtime.get("happenings", []):
		if str(h.kind) != "meeting" or _rung.has(int(h.id)):
			continue
		var gather: Array = h.phases[0]
		if now >= int(gather[1]) and now < int(gather[2]):
			_rung[int(h.id)] = true
			_ring_bell()
		elif now >= int(gather[2]):
			_rung[int(h.id)] = true             # (over before it could be rung: a loaded save)


## The village bell at the square, rung three times: something is about to happen there (a hearing, a public act,
## a rite). Sound only; the walking crowd is the rest of the cue.
func _ring_bell() -> void:
	var at := Sites.at("square")
	var bell := AudioStreamPlayer3D.new()
	bell.stream = BELL
	bell.unit_size = 22.0
	bell.max_distance = 150.0
	bell.volume_db = -3.0
	add_child(bell)
	bell.global_position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y) + 3.5, at.y)
	bell.play()
	if registry != null:
		registry.stimuli.emit("bell", at, 150.0, -1, 5.0)   # heard across the village: an edge cue with the sound off
	for stroke in [1, 2]:
		get_tree().create_timer(1.7 * stroke).timeout.connect(func() -> void:
			if is_instance_valid(bell):
				bell.play())
	get_tree().create_timer(7.0).timeout.connect(func() -> void:
		if is_instance_valid(bell):
			bell.queue_free())

func _act(verb: String, parameters: Dictionary, in_talk := false) -> Dictionary:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	# in_talk: asked from the talk screen (which locks the controls while it is open)
	if e.is_empty() or _stage == null or _stage._victim == null or (Controls.locked and not in_talk) or VillageSession.background or _player._down > 0.0:
		return {"accepted": false, "reason": "unavailable"}
	var pos := _action_at(verb, parameters)
	var distance := Vector2(_player.global_position.x, _player.global_position.z).distance_to(pos)
	var req := {"action_id": "%d:%s:%s" % [_event, verb, JSON.stringify(parameters)], "player_id": "player:local",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "event_id": _event, "verb": verb, "parameters": parameters}
	var witnesses := []
	for id: int in registry.bodies:
		var body: Node3D = registry.bodies[id]
		if body.visible and body.global_position.distance_to(_player.global_position) < 7.0:
			witnesses.append(id)
	var context := {"distance_dm": int(ceil(distance * 10.0)), "coins": Money.coins, "wood": Inventory.count("wood"),
		"witnesses": witnesses, "intercepted": parameters.get("intercepted", false)}
	if verb in ["free","testify"]:
		context.authorized=true
		context.in_talk=in_talk
		var checked := preload("res://scripts/studio/village/player_acts.gd").event_action(registry.people_bridge,_event,verb,parameters,context)
		if not in_talk:
			_respond(verb,checked,e)
		return checked
	var result := Runtime.act(v, req, context)
	if result.accepted and not result.get("duplicate", false):
		if int(result.get("coins", 0)) > 0:
			Money.spend(int(result.coins))
		if int(result.get("wood", 0)) > 0:
			Inventory.remove("wood", int(result.wood))
		if int(result.get("damage", 0)) > 0:
			_player.take_damage(int(result.damage))
		SaveGame.save_game() # accepted state and existing inventory share the normal atomic save
	if not in_talk:
		_respond(verb, result, e)
	return result

## Feedback for what the player did with the world itself (not in a talk screen): the freed one says so, over
## their head; the player's own doing is a hint.
func _respond(verb: String, result: Dictionary, e: Dictionary) -> void:
	var v = VillageSession.village
	if result.accepted and result.outcome in ["rescued", "spared"]:
		React.say(registry.bodies.get(int(e.victim)), "I'll hide in the far woods. I won't forget you.")
	elif result.accepted and verb == "shield":
		hint("You take the blow.")
	elif result.accepted and verb == "inspect" and result.has("clue"):
		hint(_trace_words(v, e, result.clue))
	elif not result.accepted and verb in ["free", "shield", "inspect", "plant", "offer"]:
		hint(_refusal(str(result.reason), true))

func _actor_at(id: int) -> Vector2:
	if registry.bodies.has(id):
		var body: Node3D = registry.bodies[id]
		return Vector2(body.global_position.x, body.global_position.z)
	return Vector2.INF

func _action_at(verb: String, params: Dictionary) -> Vector2:
	if _stage == null:
		return Vector2.INF
	if verb == "listen":
		return _actor_at(int(params.get("speaker", -1)))
	if verb in ["inspect", "plant"]:
		return registry.place(params.get("place", ""))
	if verb in ["testify", "bribe", "offer"] and _stage._authority != null:
		return _stage._authority.pos
	return _stage._victim.pos

func _parameters(verb: String) -> Dictionary:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	if e.is_empty():
		return {}
	if verb == "listen":
		var best := -1
		var distance := 2.5
		var player_at := Vector2(_player.global_position.x, _player.global_position.z)
		for id in e.witnesses:
			var d := player_at.distance_to(_actor_at(int(id)))
			if d < distance:
				best = int(id); distance = d
		return {"speaker": best}
	if e.type == "hearing":
		var cs = v.cases[e.source.case_id]
		var crime = v.crimes[cs.crime]
		if verb == "inspect":
			return {"place": v.place_names[crime.trace_at] if crime.trace_at >= 0 else ""}
		if verb == "plant":
			return {"place": v.households[v.people[int(e.victim)].household].home}
		if verb == "testify":
			var account: Dictionary = v.runtime.players.get("player:local", {})
			for clue: Dictionary in account.get("knowledge", []):
				if int(clue.crime) == cs.crime and not e.testimony.has(clue.origin):
					return {"origin": clue.origin}
	return {}

## What this person has to do with the event that is open, for their talk screen (resident_talk.gd screen):
## {} when nothing, else {part: judge | witness | accuser | accused | leader, options: [{label, do}]} - the
## verbs the buttons used to carry, now said to the right person. Each `do` sends the same verb with the same
## parameters through _act, and answers with what that person says back.
func talk_context(id: int) -> Dictionary:
	if _stage == null:
		return {}
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	if e.is_empty() or Runtime.terminal(e) or e.type == "incident":
		return {}
	var now := int(v.runtime.now)
	if now < int(e.from) or now >= int(e.deadline):
		return {}
	var options: Array = []
	var part := ""
	var roles: Dictionary = Runtime.staging(v, _event).roles
	if _stage._authority != null and id == _stage._authority.id:
		part = "leader" if e.type == "rite" else "judge"
		if e.type == "hearing":
			var params := _parameters("testify")
			if params.has("origin"):
				options.append({"label": "I have something to say", "do": func() -> Dictionary: return _ask("testify", params, id)})
			if Money.coins >= 5 and str(e.bribe).is_empty():
				options.append({"label": "A word in private... (5 coins)", "do": func() -> Dictionary: return _ask("bribe", {}, id)})
		elif e.type == "rite" and Inventory.count("wood") >= 1 and str(e.bribe).is_empty():
			options.append({"label": "I'll make an offering (1 wood)", "do": func() -> Dictionary: return _ask("offer", {}, id)})
	if e.type != "rite" and e.witnesses.has(id) and id != int(e.victim):
		if part == "":
			part = "accuser" if id == int(roles.get("accuser", -1)) else "witness"
		options.append({"label": "What did you see?", "do": func() -> Dictionary: return _ask("listen", {"speaker": id}, id)})
	if part == "" and e.type == "hearing" and id == int(e.victim):
		part = "accused"
	return {"part": part, "options": options} if part != "" else {}

## The player asks or tells (from a talk screen): the same verb through _act, and the answer as that person's words.
func _ask(verb: String, params: Dictionary, speaker: int) -> Dictionary:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	var result := _act(verb, params, true)
	var words := _reply(verb, v, result)
	if result.accepted and result.outcome in ["rescued", "spared"]:
		React.say(registry.bodies.get(int(e.victim)), "I'll hide in the far woods. I won't forget you.")
	return Talk.answer(words if not words.is_empty() else "...", "Thank you", "Yes" if result.accepted and verb != "listen" else "")

## What they say back, in their own words (never the rules' wording).
func _reply(verb: String, v, result: Dictionary) -> String:
	if not result.accepted:
		return _refusal(str(result.reason), false)
	var said := str(result.outcome)
	match verb:
		"listen":
			var clue: Dictionary = result.get("clue", {})
			if clue.is_empty():
				return "I've nothing to tell you."
			var who := _first(v.people[int(clue.culprit)].name)
			if int(clue.strength) >= 700:
				return "It was %s. I'd swear to it." % who
			if int(clue.strength) >= 450:
				return "It was %s, I'm fairly sure." % who
			return "I think it was %s. Mostly what I've heard, mind." % who
		"testify":
			match said:
				"That supports the accusation.":
					return "Hm. That fits with what we've heard."
				"That casts doubt on the accusation.":
					return "Hm. That gives me pause."
				"We already heard that account.":
					return "So I've heard already. Nothing new there."
		"bribe":
			match said:
				"I will weigh your request.":
					return "Hm. Leave it with me. Quietly."
				"Keep your coins. This is a hearing.":
					return "Put that away. This is no market."
		"offer":
			if said == "spared":
				return "Very well. Take them and go, before I think again."
			return "*They look at the wood, then turn back to the fire.*"
	return said

## A refusal in plain words: as someone's answer (spoken) or as a hint (the player's own doing).
func _refusal(reason: String, as_hint: bool) -> String:
	if reason.begins_with("Their words are unfamiliar"):
		return "*They speak, but the words slip past you. They point at the crowd.*"
	match reason:
		"I did not see it.":
			return "I didn't see it happen. Ask someone else."
		"no witness here", "no testimony":
			return "I've nothing to tell you."
		"already heard this source":
			return "You've told me that already."
		"offer already decided", "offering already decided":
			return "You've made your offer." if not as_hint else "Already offered."
		"requires 5 coins":
			return "You'd need coin for that."
		"requires 1 wood":
			return "You've no wood for that."
		"window closed", "hearing closed":
			return "Too late for that."
		"out of reach":
			return "Too far." if as_hint else "Come closer."
		"no trace here", "no open case":
			return "Nothing here."
		"trace already placed":
			return "Already done."
		"not at their doorstep":
			return "Not here."
		"participant unavailable", "no judge":
			return "That's over now."
		"unavailable":
			return ""
	return "..." if not as_hint else ""

## What the player finds at the trace: what it is, and whose door it leads to.
func _trace_words(v, e: Dictionary, clue: Dictionary) -> String:
	var crime = v.crimes[v.cases[e.source.case_id].crime]
	var trace: String = str(C.ACTS[crime.act]["trace"])
	var mild := {"body": "Marks", "bones": "Old bones", "blood": "Dark stains", "sick": "Foul traces"}
	var who := _first(v.people[int(clue.culprit)].name)
	if trace.is_empty():
		return "A trace. It leads to %s." % who
	return "%s here. It leads to %s." % [str(mild.get(trace, trace.capitalize())), who]

func _first(name: String) -> String:
	return name.split(" ")[0]

## A short message at the top of the screen (Enea's hint), for what the player's own action did.
func hint(text: String) -> void:
	if text.is_empty():
		return
	last_hint = text
	get_tree().call_group("hud", "hint", text)

## Inspect and Plant wood are places, not buttons: a spot at the trace and one at the accused's doorstep, found
## by the same action button as everything else, only while a hearing is open and the player could use them.
func _update_choices() -> void:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	var open: bool = _stage != null and not e.is_empty() and e.type == "hearing" and not Runtime.terminal(e) \
			and int(v.runtime.now) >= int(e.from) and int(v.runtime.now) < int(e.deadline)
	for verb: String in ["inspect", "plant"]:
		var spot: Node3D = _spots.get(verb)
		if spot != null and int(_spot_event.get(verb, -1)) != _event:
			spot.queue_free()
			_spots.erase(verb)
			spot = null
		var place := str(_parameters(verb).get("place", "")) if open else ""
		var want: bool = open and place != ""
		if want and verb == "plant":
			want = Inventory.count("wood") >= 1 and not _planted(v, e)
		if want and spot == null:
			spot = UseSpot.new()
			add_child(spot)
			# a step to one side of the door each (the same door can hold both: the button offers the nearer), and
			# close enough that anyone in reach of the spot is in reach of the door for the rules (2.5 m)
			var at: Vector2 = registry.place(place) + Vector2(-SPOT_SIDE if verb == "inspect" else SPOT_SIDE, 0.4)
			spot.setup(Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y), "Inspect" if verb == "inspect" else "Plant wood", _use_spot.bind(verb), SPOT_REACH)
			spot.set_meta("village_action", true)
			_spots[verb] = spot
			_spot_event[verb] = _event
		if spot != null:
			var offered := spot.is_in_group("interactable")
			if want and not offered:
				spot.add_to_group("interactable")
			elif not want and offered:
				spot.remove_from_group("interactable")

func _planted(v, e: Dictionary) -> bool:
	for t: Dictionary in v.runtime.get("traces", []):
		if int(t.event) == int(e.id):
			return true
	return false

## The player used one of those spots.
func _use_spot(verb: String) -> void:
	var result := _act(verb, _parameters(verb))
	if result.accepted and verb == "plant":
		hint("Someone saw you leave the wood." if str(result.outcome).begins_with("Someone saw") else "You leave marked wood by the door.")

func _update_traces() -> void:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, _event)
	if e.is_empty() or e.type != "hearing":
		return
	var params := _parameters("inspect")
	var place: String = params.get("place", "")
	if not place.is_empty() and not _traces.has(place):
		var trace := StageProps.wood()
		add_child(trace)
		var at: Vector2 = registry.place(place)
		trace.position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
		_traces[place] = trace
	for t: Dictionary in v.runtime.get("traces", []):
		var key := "planted:%s" % t.event
		if _traces.has(key):
			continue
		var trace := StageProps.wood()
		add_child(trace)
		var at: Vector2 = registry.place(t.place)
		trace.position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
		_traces[key] = trace

func _update_storms() -> void:
	var v = VillageSession.village
	for storm in v.storms:
		if not storm.active:
			if _storm_props.has(storm.id):
				_storm_props[storm.id].queue_free()
				_storm_props.erase(storm.id)
			continue
		if _storm_props.has(storm.id):
			continue
		var prop := Props.shrine()
		add_child(prop)
		var at: Vector2 = registry.place(v.households[storm.household].home) + Vector2(1.5, 0.0)
		prop.position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
		_storm_props[storm.id] = prop

## The one-time notice (a damaged village record was replaced): a hint, once the player can read it.
func _update_cue(_now: int) -> void:
	if _notice.is_empty() or Controls.locked or VillageSession.background:
		return
	hint(_notice)
	_notice = ""

func _close() -> void:
	if _stage != null:
		_stage.action_authority = Callable()
		_stage.end_handler = Callable()
		_stage.clear()
		_stage.queue_free()
		_stage = null
	_event = -1

func _exit_tree() -> void:
	if VillageSession.village != null:
		Runtime.set_player(VillageSession.village, false, 0, 0)   # the player has left the village
	# Scene teardown frees both registry and stage; no reparenting or delayed state callbacks.
	if is_instance_valid(_stage):
		_stage.action_authority = Callable()
		_stage.set_process(false)

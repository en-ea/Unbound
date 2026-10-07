extends Node3D
## One body per resident. Events borrow it; routines resume from its actual position.
##
## Daily life: a resident walks the day plan (Runtime.routine), and while they stand somewhere their body does
## what the plan says they are doing (resident_anims.gd: farming, chopping, chatting with someone, eating on
## the step...). At night they are indoors: hidden, costing nothing, and back at their door in the morning.
## Every resident carries a talk spot (resident_talk.gd) while the player is near; the name shows over the
## one the action button would talk to. Nothing else of the village's is drawn.
##
## What the village says a resident is doing about the player (runtime.reactions: puzzled, flee, fight_back...) is
## acted out by resident_acts.gd until it ends; then the body walks back to where its day has got to.
## Enea's own characters (protected residents: authored != "") get no body here: they keep theirs (world/npc.gd).
##
## How bodies move (Pass 3): the day plan gives each body a goal and a deadline, never a position. Each body has a
## mover (people/mover.gd: its own pace, setting off at its own moment, hurrying when late) and one crowd
## (people/crowd.gd) steps them all together, round each other, the player, Enea's people and animals and the
## houses. A body is put somewhere at once only when it first appears or the clock jumps.
##
## Where they stand at a place that is not their own home: a spot claimed as they arrive (people/spots.gd), so the
## first there stand nearest, later ones fill in on their own side behind them, and nobody stands in a wall, a tree or
## Enea's people, on a doorstep, out of sight of what they came for, or on anyone.
##
## A stay is not a statue: once there, they do what people there do in bits of their own length - work and a step to
## the next bit of it, a rest, a look at whoever passes, a short errand to the well, the merchant or a friend's yard and
## back (people/activity.gd), every spot a good one (standable, off the doorsteps, nobody's, room in front).
##
## Families walk together: household members setting off on the same trip from near each other go side by side, at
## the slowest one's pace (a child beside a parent, an old one setting the pace).
##
## People meeting people: near the player, two whose ways meet (passing, one standing as the other passes, both
## standing about, going the same way) may do something about it - a greeting, a stop for a word, walking on together,
## a quarrel, a wide berth, a grown one crouching to a child, children chasing - chosen by who they are and how they
## get on (people/encounters.gd) and played on their bodies (people/situation.gd). Then back to their day: late, they
## hurry.
const Body := preload("res://scripts/studio/village/villager_body.gd")
const Prof := preload("res://scripts/studio/people/prof.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const NPC_SCRIPT := preload("res://scripts/world/npc.gd")
const Sites := preload("res://scripts/studio/village/sites.gd")
const Stage := preload("res://scripts/studio/village/stage.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Talk := preload("res://scripts/studio/village/resident_talk.gd")
const Anims := preload("res://scripts/studio/village/resident_anims.gd")
const React := preload("res://scripts/studio/village/resident_react.gd")
const Acts := preload("res://scripts/studio/village/resident_acts.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")
const Crowd := preload("res://scripts/studio/people/crowd.gd")
const Persona := preload("res://scripts/studio/people/persona.gd")
const Spots := preload("res://scripts/studio/people/spots.gd")
const Situation := preload("res://scripts/studio/people/situation.gd")
const Activity := preload("res://scripts/studio/people/activity.gd")
const Society := preload("res://scripts/studio/people/society.gd")
const Formation := preload("res://scripts/studio/people/formation.gd")
const Look := preload("res://scripts/studio/people/look.gd")
const Speech := preload("res://scripts/studio/people/speech.gd")
const Modules := preload("res://scripts/studio/people/modules.gd")
const OFFERS := "res://scripts/studio/people/offers/"
const Lines := preload("res://scripts/studio/village/resident_lines.gd")
const Owners := preload("res://scripts/studio/people/owners.gd")
const HappeningRunner := preload("res://scripts/studio/people/happening_runner.gd")
const HappeningKinds := preload("res://scripts/studio/people/happening_kinds.gd")
const Stimuli := preload("res://scripts/studio/people/stimuli.gd")
const VillageReactions := preload("res://scripts/studio/village/village_reactions.gd")
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Happenings := preload("res://scripts/studio/village/sim/happenings.gd")
const PlayerActs := preload("res://scripts/studio/village/player_acts.gd")
const BodyElements := preload("res://scripts/studio/people/body_elements.gd")
var _elements := {}
const PeopleBody := preload("res://scripts/studio/village/sim/people.gd")
const BodyContact := preload("res://scripts/studio/village/contact.gd")
const Perception := preload("res://scripts/studio/people/perception.gd")
var _element_ticks := {}
var _element_visible := {}
var _sight := -1.0                 # villager sight (m), read once from people_bridge
var _look_node := {}               # id -> weakref of whom they watch (regard chose them on the beat)
var _element_dt := {}              # id -> seconds its elements are owed (stepped on the beat)
var _element_facts := {}           # id -> hash of the body facts its elements were last reconciled with
var _expression_hints := {}
var _expression_look := {} # Current measured gaze only; no saved tracking positions.
var _carry_nodes := {} # Physical metadata cleanup, never saved carry authority; weak actual carrier refs.
const NpcScript := "res://scripts/world/npc.gd"

const TALK_NEAR := 6.0          # metres: a talk spot exists only for a resident this close to the player
const PICKS_PER_FRAME := 3      # daily-life picks (a describe each) made in one frame: a minute's worth spread over frames
const JUMP := 2                 # game minutes: a clock that moves further than this in a frame jumped
const LEAVE_LAG := 24.0         # seconds, at most, someone talks on in a circle after their day has moved on
const OTHERS_EVERY := 0.5       # seconds between looks for Enea's people and animals near the crowd
const CHILD_SCALE := 0.68
const APPROACH := 7.0           # metres of way left when a spot at a gathering is claimed (on arrival, in arrival order)
const DOORSTEP := 1.6           # metres round a door nobody takes a spot in
const SOLID_NEAR := 10.0        # metres: bodies this near the player are solid to them (Body.set_solid)
const MEET_NEAR := 30.0         # metres from the player: people meet each other here (further off, nobody sees it)
const MEET_EVERY := 0.25        # seconds between looks for people meeting
const SIGHT_NEAR := 12.0        # metres: what a resident standing about may turn to look at
const TALK_EVERY := 1.0         # seconds between looks at who is talking with whom
const LOOK_NEAR := 11.0 * 0.8   # metres from the player: heads turn to what they look at (people/look.gd, pose.gd); and
                                # how far regard looks round a body (shorter sight, Hilmi 6 Oct: 11 m x the people's 0.8)
const LOOK_EVERY := 0.1         # seconds between the look director's choices
const SENSE_EVERY := 0.1        # seconds: a near body on screen re-senses (regard) and re-expresses (elements) at 10 Hz,
                                # staggered; it moves and animates every frame (Hilmi 6 Oct: think less often, spread out)
const SENSE_FAR := 0.5          # seconds: the same for a body off screen or beyond SENSE_NEAR
const SENSE_NEAR := 20.0        # metres from the player
const EVENT_NEAR := 14.0        # metres: a blow this near draws the eyes
const WAVE_LIKES := 30          # someone who thinks this well of the player waves as they pass (once a while)
const WAVE_AGAIN := 90.0        # seconds
const HEARD_NEAR := 16.0        # metres from the player: a conversation's voices are played (people/speech.gd)
const OVERHEAR := 5.0           # metres: this close, the player catches their words
const WORDS_EVERY := 5.0        # seconds, at least, between words overheard from one conversation
const KNOCK := 1.5              # m/s: a blow's knock-back step (the crowd eases it out)
const LEAVE_SPREAD := 0.6       # share of a trip's time to spare over which those leaving from indoors set off
const FAMILY_NEAR := 6.0        # metres: household members setting off this close together walk together
const FAMILY_MOST := 3          # abreast at most (more follow in their own time)
const VISIT_LIKES := 20         # a resident walks over to the yard of someone they like at least this much
const AWKWARD_DOOR := 1.0       # metres from a doorstep: standing on it (a measure: awkward_at)
const AWKWARD_FACE := 0.8       # metres from a wall in front: nose to it
const AWKWARD_CLOSE := 0.6      # metres between two grown people standing: on top of each other
# Who drives a body (people/owners.gd), the highest claim first: a stage's scene; the player's talk and an answer to the
# player (equal: the latest of the two wins, as before); a happening; a meeting or a conversation. Nobody: their day.
const BY_STAGE := 5
const BY_TALK := 4
const BY_ACT := 4
const BY_HAPPENING := 3
const BY_SOCIETY := 1
const RUN_NEAR := 45.0          # metres from the player: a happening the rules decided is played on the bodies (further
                                # off nobody sees it; the rules and the news have it all the same)
const ARGUE_NEAR := 12.0        # metres: those near two who start to quarrel are the rules' context (a peacemaker)

var bodies := {}
var people_bridge: Node
var owners := Owners.new()      # who drives each body now ("stage", "talk", "act", "happening", "society"; none: the day)
var stimuli := Stimuli.new()    # every sound worth turning to near the player (people/stimuli.gd): happenings give them off
var runs := {}                  # happening id -> HappeningRunner: the rules' happenings played on the bodies
var village_reactions: VillageReactions   # people answering what they see: a scene's end, an enemy, his kill (modules)
var _leave_due := {}            # id -> life seconds: their day has moved on; they leave their circle then
var shown_happenings: Array = []   # [{id, kind, at, people, life}]: those played near the player (a measure: news probe)
var _run_tried := {}            # happening id -> true: begun on the bodies, or begun too far off to be seen
var borrowed := {}              # id -> true: a stage has the body (owners: "stage")
var paths := {}
var destinations := {}
var _shape := WorldShape.new()
var _minute := -1
var build_usec: Array[int] = []
var frame_usec: Array[int] = []
var cost_parts := {}            # part of the frame's work -> [usec in all, frames, most usec in a frame] (a measure)
var ready_for_play := false
var _router: Node3D
var _player: Node3D
var _spots := {}                # id -> Talk.Spot
var _picks := {}                # id -> resident_anims.gd pick (the loop, tool, whether indoors, what to face)
var _pick_minute := {}          # id -> the minute the pick was made
var _activity := {}             # id -> view activity at that minute
var _faces := {}                # id -> the ground point a standing body looks at
var _who := {}                  # id -> {role, age_group, day}: what does not change within a day
var _tier := {}                 # id -> the detail tier last given to the body
var _applied := {}              # id -> "loop|tool" the body is playing
var _talking := -1              # the resident the player is talking to (they stand and talk until it ends)
var _talk_open := false         # a talk screen is open (what it asked for is done the frame it closes)
var _acts := {}                 # id -> Acts.Act: acting out a reaction to the player
var _movers := {}               # id -> Mover
var _fresh := {}                # id -> true: just made, put where the day says on its first plan
var _crowd: Crowd
var _world_others: Array = []   # [[Node3D, radius]]: Enea's people and animals (looked for every OTHERS_EVERY)
var _npcs: Array[Node3D] = []   # Enea's characters' bodies (world/npc.gd)
var _others_left := 0.0
var _skip := {}                 # id -> true: never given a body here (protected: Enea's own)
var _inside := {}               # id -> true: at home they stay indoors (else out in the yard)
var _at_offset := {}            # id -> the offset they stand at about the place they last went to
var _gatherings := {}           # place name -> Spots.Gathering
var _spot_of := {}              # id -> the place whose spot they hold
var _claim_due := {}            # id -> the place they will claim a spot at, on arrival
var _room: PhysicsShapeQueryParameters3D
var _age := 0.0                 # seconds this registry has run (a spot claimed in the first moments is simply taken)
var _tag: React.Tag
var _lent := {}                 # id -> true: a stage walks this borrowed body through its mover (lend_mover)
var society: Society            # who meets whom, who talks with whom (people/society.gd)
var _meet_left := 0.0
var _sense_period := {}         # id -> the period its "sense" work is registered with in Think (village/think.gd)
var _beat := {}                 # id -> true: Think ran its sense beat since the last frame (its elements reconcile)
var _bound_at := {}             # id -> _age when its regard was last bound (Mind's hints or the beat)
var _life := 0.0                # seconds of village life (the clock running)
var meetings: Array = []        # [seconds, name, a, b]: every meeting begun (society.log; motion_watch.gd reads it)
var _world := {}                # what a situation asks of the village: the way round the walls, standable ground
var _stays := {}                # id -> Activity.Stay: what they do while they stay where the day has them
var _gazes := {}                # id -> Look.Gaze: where they look (bodies near the player)
var _events: Array = []         # [world point, life seconds]: blows near the player (looked at)
var _waved := {}                # id -> life seconds of their last wave to the player
var _look_due := {}             # id -> seconds to their next look round (each on their own beat)
var speech: Speech              # every line said aloud (people/speech.gd)
var _turn_seen := {}            # a Situation -> the turn it was at, last looked
var _words_at := {}             # a Situation -> life seconds of its last words overheard
var _voice := {}                # id -> their voice (resident_talk.gd voice_of)
var _talk_left := 0.0
var _stay_for := {}             # id -> "verb|place|trip start": what the stay is for (a new one when it changes)

## The obstacles routes go round (the same as event actors'), computed only on replanning; again when a project is built.
func _refresh_blocks() -> void:
	_router._build_blocks()
	_crowd.blocks.clear()
	for r: Rect2 in _router._blocks:
		_crowd.blocks.append(r.grow(-0.25))     # the walls themselves (routes keep a body's width off them)


func _ready() -> void:
	_router = Stage.new()
	add_child(_router)
	_player = get_tree().get_first_node_in_group("player")
	_tag = React.Tag.new()
	_tag.add_to_group(Speech.OCCUPIED)   # B7: no bubble over the name of whoever the tap would reach
	add_child(_tag)
	_crowd = Crowd.new()
	_crowd.name = "Crowd"
	_crowd.focus = _player
	_crowd.others = _others
	_refresh_blocks()
	Projects.built.connect(func(_id: String) -> void: _refresh_blocks())     # (the smithy's site changes its ground)
	Projects.unbuilt.connect(func(_id: String) -> void: _refresh_blocks())
	add_child(_crowd)
	speech = Speech.new()
	speech.name = "Speech"
	add_child(speech)
	React.speech = speech
	speech.role = _speech_role
	_world = {"route": func(a: Vector2, b: Vector2) -> PackedVector2Array: return _router._route(a, b), "standable": _standable, "passable": _passable,
		"good": _good_spot, "open": _open_ahead}
	society = Society.new(_society_director())
	meetings = society.log
	_crowd.spaces = society.spaces
	village_reactions = VillageReactions.new(self)
	add_child(village_reactions)
	for node in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if node.get_script() != null and (node.get_script() as Script).resource_path == NpcScript:
			_npcs.append(node)
			# B7: his greeting is said through speech.gd (capped, in turn, never over the encounter); his label stays.
			speech.adopt(node, func() -> Label3D: return node.get("_bubble") as Label3D)
			# Observe Enea's existing bodies without acquiring or moving them.
			for p in VillageSession.village.people:
				if p.authored==node.get("_id"):
					node.set_meta("people_actor","res:%d:%d" % [VillageSession.village.seed,p.id])

## B7: who a speaker is in what is happening, for speech.gd's turns. The one it happened to (struck, burning, given
## to) answers first, then whoever steps in, then the crowd (not the one it happened to, and an offer whose roles
## include "observer"). One situation per person it happened to (every blow, gift or flame on them, and all who answer
## it, take turns), else per deed. {} for someone with no plan: their line keeps the caller's priority.
func _speech_role(body: Node3D) -> Dictionary:
	var v = VillageSession.village
	if v == null or not is_instance_valid(body):
		return {}
	var id := PeopleBody.resident(v, str(body.get_meta("people_actor", "")))
	if id < 0 or id >= v.people.size():
		return {}
	var m = v.people[id].mind
	var plan: Dictionary = m.plan
	var deed := str(plan.get("deed", ""))
	if deed.is_empty():
		return {}
	var a: Variant = m.known.get(str(plan.get("account", "")), {})
	var priority := Speech.STEP_IN
	if a is Dictionary and str(a.get("target", "")) == PeopleBody.key(v, id):
		priority = Speech.STRUCK
	else:
		var offer: GDScript = Modules.discover(OFFERS).get(str(plan.get("offer", "")))
		if offer != null and Array(offer.get_script_constant_map().get("ROLES", [])).has("observer"):
			priority = Speech.TALK
	var about := str(a.get("target", "")) if a is Dictionary else ""
	if about.is_empty() or about == "unknown":
		about = deed
	return {"priority": priority, "situation": 8000000 + posmod(hash(about), 1000000)}


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	var v = VillageSession.village
	if v == null:
		return
	_age += delta
	# Preparation is included in measured frame work, never subtracted from the stage's cost.
	for p in v.people:
		if (p.alive or p.body_facts.has("dead")) and p.present and not bodies.has(p.id) and not _skip.has(p.id):
			if _is_protected(v, p):
				_skip[p.id] = true          # an authored character: their own body, their own talk
				continue
			ensure(Justice.person_entry(v, p.id))
			break
	ready_for_play = true
	var now := int(v.runtime.now)
	var replan := now != _minute
	var jumped := _minute >= 0 and absi(now - _minute) > JUMP    # a probe, a long sleep: be where the day says
	_minute = now
	if _talk_open and not Controls.locked:
		_talk_open = false
		if _talking >= 0:
			destinations.erase(_talking)   # back to their day, from where they stood talking
			owners.release(_talking, "talk")
		_talking = -1            # the talk screen closed: back to their day, and what it asked for is done
		Talk.run_pending(self, _player)
	_sync_reactions(v, now)
	var picks := PICKS_PER_FRAME
	var player_at := _player.global_position if _player != null else Vector3(INF, INF, INF)
	var controls_locked := Controls.locked
	var frozen := controls_locked or VillageSession.background
	var adelta := 0.0 if frozen else delta   # acts freeze with the clock
	_crowd.paused = frozen
	if _player != null and _player.collision_mask != 0 and _player.collision_mask & Body.PEOPLE_LAYER == 0:
		_player.collision_mask |= Body.PEOPLE_LAYER   # the player bumps into people (Enea's own code resets the mask
		                                               # when getting off the cart; riding, it is 0 and stays so)
	var clock := float(now) + float(v.runtime.fraction)
	var cam := get_viewport().get_camera_3d()
	for id: int in bodies:
		var body: Body = bodies[id]
		var mover: Mover = _movers[id]
		var p = v.people[id]
		var near2 := player_at.distance_squared_to(body.position)   # the registry and any stage sit at the origin
		var tb := Prof.now()
		body.set_solid(near2 < SOLID_NEAR * SOLID_NEAR and body.is_visible_in_tree())
		tb = Prof.add("res.solid", tb)
		var period := SENSE_EVERY if near2 < SENSE_NEAR * SENSE_NEAR and (cam == null or not body.visible
			or cam.is_position_in_frustum(body.global_position + Vector3(0.0, 1.0, 0.0))) else SENSE_FAR
		if _sense_period.get(id, -1.0) != period:      # (re-registered as it crosses a range: its slot is kept)
			_sense_period[id] = period
			Think.every(_think_owner(id), "sense", period, _sense_beat.bind(id))
		_physical(id, adelta, _beat.has(id), period == SENSE_EVERY)
		_beat.erase(id)
		tb = Prof.add("res.physical", tb)
		if not frozen:
			_follow_look(id)
		Prof.add("res.bind_expression", tb)
		var by := owners.owner(id)
		if by == "carry":
			mover.active = false
			_show(id,body,0 if near2<100.0 else 1)
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if not mover.can_move() and not mover.can_posture("upright"):
			mover.active = true
			_show(id,body,0 if near2<100.0 else 1)
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if by == "stage":
			mover.active = _lent.has(id)    # a stage walking it on plain ground: the crowd steps it
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if not p.alive or not p.present:
			mover.active = false
			_show(id,body,(0 if near2<100.0 else 1) if p.present and p.body_facts.has("dead") else 2)
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if by == "society" and replan and not _leave_due.has(id) and (society.in_sit[id] as Situation).name == "talk":
			var trip_now := Runtime.routine(v, id)
			if destinations.has(id) and (destinations[id].start != trip_now.start or destinations[id].place != trip_now.place):
				_leave_due[id] = _age + LEAVE_LAG * float(absi(hash([id, now])) % 1000) / 1000.0   # (each finishes
				                                     # their sentence: a work bell does not end every circle at once)
		if by == "society" and _leave_due.has(id) and _age >= float(_leave_due[id]):
			_leave_due.erase(id)
			var sit: Situation = society.in_sit.get(id)
			if sit != null:
				var staying: Array = sit.who.filter(func(o: int) -> bool: return o != id)
				_leave_situation(id)             # their day moves on: out of the conversation, and on their way
				village_reactions.parting(id, sit.centre, staying)    # (a word and a wave first: goodbye.gd)
				by = owners.owner(id)
		elif by != "society":
			_leave_due.erase(id)
		if by == "society":
			mover.active = true              # meeting someone: the situation moves them (their day waits)
			_show(id, body, 0 if near2 < 100.0 else 1)
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if by == "happening":
			mover.active = true              # in a happening, or come to watch one: its runner moves them (their day waits)
			_show(id, body, 0 if near2 < 100.0 else 1)
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if by != "" and by not in ["talk", "act"]:
			# A claimed external owner supplies the existing mover. The day must not overwrite an
			# unfamiliar owner name; new physical controllers need no registry branch.
			mover.active = not mover.indoors or mover.walking()   # answering what they saw (village_reactions.gd);
			_show(id, body, 2 if mover.indoors else (0 if near2 < 100.0 else 1))   # in at their door: hidden
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if replan or not destinations.has(id):
			var trip := Runtime.routine(v, id)
			if jumped or not destinations.has(id) or destinations[id].start != trip.start or destinations[id].place != trip.place:
				_plan(v, id, trip, clock, jumped)
		var act: Acts.Act = _acts.get(id)
		if act != null and act.done(now):
			_end_act(id, act)
			act = null
		if act != null:
			mover.active = true              # the act says where to go; the mover (and the crowd) moves the body
			act.update(adelta, now)
			_show(id, body, 2 if act.hidden else (0 if near2 < 100.0 else 1))
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		# what they are doing now: made once a minute for each, a few a frame
		if _pick_minute.get(id, -1) != now and picks > 0:
			picks -= 1
			_choose(v, id, now)
		var pick: Dictionary = _picks.get(id, {})
		var moving := mover.walking()
		if mover.indoors:
			mover.active = moving          # waiting to step out: the crowd counts their wait and lets them out when the
			_show(id, body, 2)             # step is clear; in at home: nothing to do
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if pick.get("hidden", false) and not moving:
			mover.active = false
			_show(id, body, 2)         # indoors: asleep, or away
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		mover.active = true
		_show(id, body, 0 if near2 < 100.0 else 1)
		if _claim_due.has(id) and (not moving or mover._left() < APPROACH):
			if not (_verb_there(v, id) == "chatting" and owners.is_free(id) and _join_talk(v, id)):
				_claim(id, mover)
			moving = mover.walking()
			if owners.held(id, "society"):
				_offer_talk(id, body, p, near2, controls_locked)
				continue
		var stay: Activity.Stay = _stays.get(id)
		if stay != null and _stay_for.get(id, "") != _stay_key(id):
			_drop_stay(id)                    # what the day has them doing changed (the well: water, then a chat)
			stay = null
		var talking := by == "talk"
		if stay == null and not moving and not p.locked and not talking and not pick.is_empty():
			stay = _make_stay(v, id, pick, clock)
		if stay != null:
			if not p.locked and not talking and not frozen:
				stay.until = (_stay_end(v, id) - clock) * 0.5      # real seconds (a game minute is half a second)
				stay.update(delta)
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if moving:
			if _applied.has(id):
				_applied.erase(id)
				body.show_tool("")
		elif not p.locked and not talking and not pick.is_empty() and mover.at_rest():
			var key := "%s|%s" % [pick.loop, pick.tool]
			if _applied.get(id, "") != key or not body.holding():      # (a nudge breaks a pose: taken up again)
				_applied[id] = key
				body.play_loop(pick.loop, 0.25, 1.0, id * 0.37)
				body.show_tool(pick.tool)
			mover.face(_faces.get(id, Vector2.INF))
		_offer_talk(id, body, p, near2, controls_locked)
	var t := _part("people", t0)
	if not frozen:
		_life += delta
		society.update(delta)
		stimuli.update(delta)
		_happenings(v, delta)
		t = _part("situations", t)
		_talk_left -= delta
		if _talk_left <= 0.0:
			_talk_left = TALK_EVERY
			_talk_scan(v)
		t = _part("talk_scan", t)
		_meet_left -= delta
		if _meet_left <= 0.0:
			_meet_left = MEET_EVERY
			_meet_scan(v, now)
		t = _part("meet_scan", t)
	if not frozen:
		_looks(v, delta)
	t = _part("looks", t)
	if not frozen:
		_voices(v)
	t = _part("voices", t)
	_name_tag(v, delta)
	_part("name_tag", t)
	_part("crowd", Time.get_ticks_usec() - _crowd.cost_usec)
	frame_usec.append(Time.get_ticks_usec() - t0 + _crowd.cost_usec)   # with the crowd's step (last frame's)
	if frame_usec.size() > 3600:
		frame_usec.pop_front()


## Counts a part of the frame's work (cost_parts), from `since`; returns now.
func _part(part: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	var c: Array = cost_parts.get(part, [0, 0, 0])
	c[0] += now - since
	c[1] += 1
	c[2] = maxi(c[2], now - since)
	cost_parts[part] = c
	Prof.add("res." + part, since)
	return now


## Plans a trip: where they stand about the destination, the way there, and the mover told to walk it by the trip's
## end. A crowd stands on a sunflower spiral (a metre or so apart); at their own home in the daytime they are indoors
## (hidden at the door) or about a chore in the yard, spread round the house, never all at the door. A body that is
## drawn walks from where it is; one just made, indoors, or caught by a jump of the clock is put where the day says.
func _plan(v, id: int, trip: Dictionary, clock: float, jumped := false) -> void:
	_drop_stay(id)
	var m0: Mover = _movers[id]
	m0.lead = null                       # (a family walk is over with the trip)
	m0.pace_cap = INF
	if m0.group != 0 and not owners.held(id, "society"):
		m0.group = 0
	var who := _who_of(v, id)
	var leaving: String = _spot_of.get(id, "")         # standing in a crowd: they keep their spot until they step off it
	_claim_due.erase(id)
	if leaving == "" or leaving != str(trip.from) or jumped:
		leaving = ""
		_release_spot(id)
	var offset := Vector2.ZERO
	var inside := false
	var gathering := ""
	if Sites.HOMES.has(trip.place) and trip.place == who.home:
		inside = Anims.stays_in(id, int(trip.start) % 1440, int(trip.start) / 1440)
		offset = Vector2.ZERO if inside else _yard(id, trip.place) - place(trip.place)
	else:
		gathering = trip.place
	_inside[id] = inside
	var from_offset: Vector2 = _at_offset.get(id, Vector2.ZERO) if destinations.has(id) and destinations[id].place == trip.from else Vector2.ZERO
	var origin := place(trip.from) + from_offset
	if from_offset == Vector2.ZERO and Sites.DOORS.has(trip.from):
		origin = doorstep(trip.from)            # out of the door, clear of the wall
	if gathering != "":                  # on their side, outside the crowd, until they claim a spot on arrival
		var g := _gathering(gathering)
		var side := origin - g.focus
		offset = g.focus + (side.normalized() if side.length() > 0.1 else Vector2(0.0, 1.0)) * (g.first + 1.5 * Spots.GAP) - place(trip.place)
		_claim_due[id] = gathering
	var goal := place(trip.place) + offset
	if inside:
		goal = doorstep(trip.place)             # in at the door, from a step clear of the wall
	_at_offset[id] = offset
	destinations[id] = trip
	var mover: Mover = _movers[id]
	var body: Body = bodies[id]
	var span := float(trip.end) - float(trip.start)
	var progress := clampf((clock - float(trip.start)) / span, 0.0, 1.0) if span > 0.0 else 1.0
	var start := mover.pos
	var initial := _fresh.erase(id)
	var anchored: bool=v.people[id].body_facts.has("down") or v.people[id].body_facts.has("dead") or v.people[id].body_facts.has("carried") or v.people[id].body_facts.has("burning")
	var put: bool=(initial or jumped or not body.visible) and not anchored
	if put:
		if gathering != "" and (progress >= 1.0 or span <= 0.0) and _take_spot(id, origin):
			goal = place(trip.place) + _at_offset[id]          # there already: on their spot
		var way: Array = [origin] + Array(_router._route(origin, goal))
		start = _along(way, progress)
		mover.place(start)
		if progress >= 1.0 or span <= 0.0:
			paths[id] = way
			mover.hold(goal, _faces.get(id, Vector2.INF))
			if leaving != "" and _spot_of.get(id, "") == leaving:
				_release_spot(id)
			return
	if gathering != "" and start.distance_to(goal) < APPROACH and _take_spot(id, start):
		goal = place(trip.place) + _at_offset[id]              # nearly there already: their spot now
	var path: PackedVector2Array = _router._route(start, goal)
	paths[id] = [start] + Array(path)
	if span <= 0.0 or start.distance_to(goal) < 0.1 or path.is_empty():
		mover.hold(goal, _faces.get(id, Vector2.INF))
		mover.indoors = inside               # (at the door of a home they stay in: in)
		if leaving != "" and _spot_of.get(id, "") == leaving:
			_release_spot(id)
		return
	var left := (float(trip.end) - clock) * 0.5                  # real seconds: a game minute is half a real second
	var delay := 0.0 if progress > 0.05 or mover.vel.length() > 0.3 else Persona.delay(mover.m, int(trip.start))
	var from_indoors: bool=put and progress <= 0.05 and from_offset == Vector2.ZERO and Sites.DOORS.has(trip.from)
	if from_indoors and delay > 0.0:
		# a household does not leave on the minute: each sets off in their own time within the time to spare (the day
		# says by when they are there, not when they leave), so a holy day's crowd trickles in rather than arriving as one
		var walk := 0.0
		for k in path.size():
			walk += path[k].distance_to(start if k == 0 else path[k - 1])
		var spare := left - walk / maxf(Persona.speed(mover.m, "walk"), 0.5) * 1.2 - delay
		if spare > 0.0:
			delay += spare * LEAVE_SPREAD * Persona._noise(int(mover.m.key) * 53 + int(trip.start), 11)
	mover.face_at = Vector2.INF              # (what they faced here is not what they face there)
	mover.go(path, maxf(left, 0.0), "", delay)
	if put and progress > 0.05:
		mover.under_way_already()            # put partway along their way: walking it already
	# leaving from indoors: they stay inside until their moment and a clear doorstep (one at a time, never a heap);
	# going in: in as they reach the door
	mover.indoors = from_indoors
	mover.enters = inside
	_family_walk(v, id, trip)
	if leaving != "" and _spot_of.get(id, "") == leaving:   # out of a crowd: once nobody standing is in their way
		var g: Spots.Gathering = _gatherings[leaving]
		var toward: Vector2 = path[0] if path.size() == 1 or path[0].distance_to(start) > 1.0 else path[1]
		mover.gate = func() -> bool:
			if g.may_leave(id, toward):
				g.release(id)
				if _spot_of.get(id, "") == leaving:
					_spot_of.erase(id)
				return true
			return false


## The point `fraction` of the way along a path.
static func _along(way: Array, fraction: float) -> Vector2:
	var length := 0.0
	for j in range(1, way.size()):
		length += (way[j] as Vector2).distance_to(way[j - 1])
	var left := length * fraction
	for j in range(1, way.size()):
		var segment := (way[j] as Vector2).distance_to(way[j - 1])
		if left <= segment and segment > 0.001:
			return (way[j - 1] as Vector2).lerp(way[j], left / segment)
		left -= segment
	return way[-1]


## The spots of a place people gather at (made on the first claim, once the physics world is there to ask).
func _gathering(place_name: String) -> Spots.Gathering:
	var g: Spots.Gathering = _gatherings.get(place_name)
	if g == null:
		g = Spots.Gathering.new(focus(place_name), _standable, _sees)
		g.open = _open_ahead
		for door: Vector2 in Sites.DOORS.values():
			g.keep_clear.append([door, DOORSTEP])
		_gatherings[place_name] = g
	return g


## Takes `id`'s spot at the place they are due at, arriving from `from`. False while the physics world is not there
## to ask yet (the first frames): they stay due.
func _take_spot(id: int, from: Vector2) -> bool:
	if Engine.get_physics_frames() < 3:
		return false
	var place_name: String = _claim_due.get(id, "")
	_claim_due.erase(id)
	if place_name == "":
		return false
	var spot := _gathering(place_name).claim(id, from)
	_spot_of[id] = place_name
	_at_offset[id] = spot - place(place_name)
	return true


## On arrival: takes their spot and sends them there, by the trip's end (put there at once if they are not on show
## yet: just made, or in the first moments).
func _claim(id: int, mover: Mover) -> void:
	if not _take_spot(id, mover.pos):
		return
	var spot: Vector2 = place(_spot_of[id]) + _at_offset[id]
	var face: Vector2 = _faces.get(id, Vector2.INF)
	if not mover.walking() and (_age < 1.0 or not (bodies[id] as Body).visible):
		mover.place(spot)
		mover.hold(spot, face)
		return
	var path: PackedVector2Array = _router._route(mover.pos, spot)
	paths[id] = [mover.pos] + Array(path)
	mover.go(path, mover.seconds if mover.walking() else INF, mover.style if mover.walking() else "", mover.wait)


func _release_spot(id: int) -> void:
	if _spot_of.has(id):
		(_gatherings[_spot_of[id]] as Spots.Gathering).release(id)
		_spot_of.erase(id)


## A body can stand here with room round it: not in a house (the routing blocks, grown to the room) nor in anything
## solid of the world (trees, the well, Enea's people: the colliders the player bumps into).
func _standable(p: Vector2) -> bool:
	for r: Rect2 in _router._blocks:
		if r.grow(maxf(Spots.ROOM - Stage.BODY_RADIUS, 0.0)).has_point(p):
			return false
	if _room == null:
		_room = PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = Spots.ROOM
		capsule.height = 1.2
		_room.shape = capsule
		_room.collision_mask = 1
	if _player != null:
		_room.exclude = [(_player as CollisionObject3D).get_rid()]
	_room.transform = Transform3D(Basis(), Vector3(p.x, ground(p) + 1.0, p.y))
	return get_world_3d().direct_space_state.intersect_shape(_room, 1).is_empty()


## Whether someone can pass through p on the way somewhere: as _standable, except that one of Enea's villagers
## standing there (world/npc.gd's body) is a person to step round, not a wall (merge-enea: his villagers now stand on
## the green, across the people's straight routes).
func _passable(p: Vector2) -> bool:
	for r: Rect2 in _router._blocks:
		if r.grow(maxf(Spots.ROOM - Stage.BODY_RADIUS, 0.0)).has_point(p):
			return false
	if _room == null:
		_standable(p)
	_room.transform = Transform3D(Basis(), Vector3(p.x, ground(p) + 1.0, p.y))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(_room, 6):
		var owner_node: Node = (hit.collider as Node).get_parent() if hit.collider is Node else null
		if owner_node != null and owner_node.get_script() == NPC_SCRIPT:
			continue
		return false
	return true


## Nothing solid between two points (what is looked at may be a building itself: its own walls do not count).
func _sees(a: Vector2, b: Vector2) -> bool:
	for r: Rect2 in _router._blocks:
		if not r.has_point(b) and Stage._crosses(a, b, r.grow(-0.02)):
			return false
	return true

## A spot in the yard of a home, clear of walls, a different side for each of the household.
func _yard(id: int, home: String) -> Vector2:
	var centre: Vector2 = Sites.HOMES[home]
	var half := 2.5
	for h: Dictionary in Stage.Houses.HOUSES:
		if (h["at"] as Vector2).distance_to(centre) < 0.5:
			half = Vector2(h["size"].x, h["size"].z).length() * 0.5
	var rank := 0
	for other: int in destinations:
		if other < id and destinations[other].place == home:
			rank += 1
	var physics := Engine.get_physics_frames() >= 3
	for k in 12:
		var angle := float(rank + k) * 1.7 + id * 0.9
		var spot := centre + Vector2(cos(angle), sin(angle)) * (half + 1.5 + float((rank + k) % 3) * 0.6)
		if not _router._blocked(spot) and (not physics or _good_spot(spot)):
			return spot
	return place(home)

## Makes a body drawn (tier 0 or 1) or indoors (2). Indoors is not drawn at all; a body a stage had hidden
## shows again as soon as its day says so.
func _show(id: int, body: Body, tier: int) -> void:
	if _tier.get(id, -1) != tier:
		_tier[id] = tier
		body.set_detail(tier)
	var drawn := tier < 2
	if body.visible != drawn:
		body.visible = drawn

## The day's pick for one resident: the loop and tool for what they are doing, who they chat with, and where
## they look.
func _choose(v, id: int, now: int) -> void:
	var day := now / 1440
	var who := _who_of(v, id)
	var activity: Dictionary = View.activity(v, id)
	_pick_minute[id] = now
	_activity[id] = activity
	var partner := _partner_of(id, activity)
	var pick := Anims.pick(activity.verb, who.role, who.age_group, id, now, partner, _inside.get(id, false))
	_picks[id] = pick
	var target := Vector2.INF
	match pick.face:
		"partner":
			if bodies.has(partner):
				target = Vector2((bodies[partner] as Body).position.x, (bodies[partner] as Body).position.z)
		"place":
			target = focus(activity.place)
		"home":
			target = Sites.HOMES.get(activity.place, Vector2.INF)
	if target == Vector2.INF:
		_faces.erase(id)
	else:
		_faces[id] = target

## What does not change within a day about a resident: their trade, age, home, and whether they are Enea's.
func _who_of(v, id: int) -> Dictionary:
	var who: Dictionary = _who.get(id, {})
	var day := int(v.runtime.now) / 1440
	if int(who.get("day", -1)) != day:
		var d := View.describe(v, id)          # who they are changes at most with the years: asked once a day
		who = {"role": d.role, "age_group": d.age_group, "home": d.home, "day": day}
		_who[id] = who
	return who

func _is_protected(_v, p) -> bool:
	return p.authored != ""   # Enea's own characters (sim/authored.gd)

## Whether a resident is one of Enea's own characters (no body here; an event never borrows them).
func is_protected(id: int) -> bool:
	return _skip.has(id) or _is_protected(VillageSession.village, VillageSession.village.people[id])

## Whether every resident who should have a body here has one (probes wait on this).
func all_built() -> bool:
	var v = VillageSession.village
	for p in v.people:
		if p.alive and p.present and not bodies.has(p.id) and not _skip.has(p.id):
			return false
	return true

## Who a resident chats with: the residents chatting in the same place, paired by id order.
func _partner_of(id: int, activity: Dictionary) -> int:
	if activity.verb != "chatting":
		return -1
	var mates: Array[int] = []
	for other: int in _activity:
		var a: Dictionary = _activity[other]
		if a.verb == "chatting" and a.place == activity.place and bodies.has(other) and not owners.held(other, "stage"):
			mates.append(other)
	mates.sort()
	var i := mates.find(id)
	if mates.size() < 2 or i < 0:
		return -1
	var j := i ^ 1
	return mates[j] if j < mates.size() else mates[i - 1]

## Where a place's work is done: its focus (the sails of the mill), else the place itself.
func focus(place_name: String) -> Vector2:
	if Sites.PLACES.has(place_name):
		return Sites.PLACES[place_name]["focus"]
	return place(place_name)

## The talk spot of a resident is in the player's reach group only while it can be used: the resident is
## near the player, drawn, and not held for an event. (near2: squared metres to the player.)
func _offer_talk(id: int, body: Body, p, near2: float, controls_locked: bool) -> void:
	var spot: Talk.Spot = _spots.get(id)
	if spot == null:
		return
	# A ported one of his (sim/ported.gd) is talked to through his npc.gd node: no second "Talk" at the same place.
	var want: bool = near2 < TALK_NEAR * TALK_NEAR and not controls_locked and body.visible and p.alive and not _ported_person(id)
	if want != spot.offered:
		spot.offered = want
		if want:
			spot.add_to_group("interactable")
		else:
			spot.remove_from_group("interactable")

## Whether this resident is one of his ported people (their talk is his npc.gd node's).
func _ported_person(id: int) -> bool:
	var v = VillageSession.village
	if v == null or v.runtime.is_empty():
		return false
	for entry: Dictionary in v.runtime.get("ported", []):
		if int(entry.get("person", -1)) == id:
			return true
	return false

## The name over whoever the action button would talk to (the player's own choice of station), else nothing.
func _name_tag(v, delta: float) -> void:
	var aimed: Body = null
	var who := -1
	var height := 2.15
	if _player != null and not Controls.locked:
		var station: Variant = _player.get("_station")   # (a freed one is not an Object to assign)
		if is_instance_valid(station) and station is Talk.Spot and bodies.has((station as Talk.Spot).resident):
			who = (station as Talk.Spot).resident
			aimed = bodies[who]
			height = 2.15 * aimed.scale.y
			if React.has_bubble(aimed):
				aimed = null          # they are speaking: the words are over their head, the name would sit on them
				who = -1
	_tag.aim(aimed, str(v.people[who].name) if who >= 0 else "", height, delta)

## The village is talking to this resident: they stop what they are doing, turn to the player and talk until
## the screen closes. (A body an event holds keeps to the event.)
func begin_talk(id: int, player: Node3D) -> void:
	_talk_open = true
	# the talk has them: a meeting lets them go; an answer to the player stops, and they talk from where they stand
	if not bodies.has(id) or not owners.claim(id, "talk", BY_TALK, _talk_lost):
		return
	if _talking >= 0 and _talking != id:
		owners.release(_talking, "talk")
	_talking = id
	_drop_stay(id)
	var body: Body = bodies[id]
	var mover: Mover = _movers[id]
	mover.hold(mover.pos, Vector2(player.global_position.x, player.global_position.z))   # they stop, and turn to the player
	body.play_motion(0.0)
	body.play_loop("Idle_Talking", 0.2, 1.0, 0.0)
	_applied.erase(id)

## ---- what resident_acts.gd asks of the registry ------------------------------------------------------------

func ground(p: Vector2) -> float:
	return _shape.height_at(p.x, p.y)

func route(a: Vector2, b: Vector2) -> PackedVector2Array:
	return _router._route(a, b)

func player() -> Node3D:
	return _player

func player_xz() -> Vector2:
	return Vector2(_player.global_position.x, _player.global_position.z) if _player != null else Vector2.ZERO

func player_can_be_hit() -> bool:
	return _player != null and _player.can_be_targeted()

func body_xz(id: int) -> Vector2:
	return Vector2((bodies[id] as Body).position.x, (bodies[id] as Body).position.z) if bodies.has(id) else player_xz()

func hurt_of(id: int) -> int:
	return int(VillageSession.village.people[id].hurt)

## Their door (where they run to when it is too much).
func door_of(id: int) -> Vector2:
	var home: String = _who_of(VillageSession.village, id).home
	return doorstep(home) if not home.is_empty() else place("square")


## Where someone stands to go in at a door, or comes out of it: the door (Sites.DOORS) moved clear of the house's
## walls by a body's width (some doors are drawn on the wall line).
func doorstep(name: String) -> Vector2:
	var at := place(name)
	return _router._outside(at) if Sites.DOORS.has(name) else at

## Someone to run to for help: a grown person nearby, drawn and free, the household first.
func helper_for(id: int) -> int:
	var v = VillageSession.village
	var mine := body_xz(id)
	var home: String = _who_of(v, id).home
	var best := -1
	var best_score := 40.0
	for other: int in bodies:
		if other == id or owners.held(other, "stage") or not (bodies[other] as Body).visible:
			continue
		var q = v.people[other]
		if not q.alive or not q.present or q.locked or q.down_until > int(v.runtime.now):
			continue
		var who := _who_of(v, other)
		if who.age_group == "child":
			continue
		var score := mine.distance_to(body_xz(other)) - (12.0 if who.home == home else 0.0)   # kin count as nearer
		if score < best_score:
			best_score = score
			best = other
	return best

## Who was struck at the minute an onlooker's answer began (only the struck give some answers).
func struck_of(since: int) -> int:
	var reactions: Dictionary = VillageSession.village.runtime.get("reactions", {})
	for key: String in reactions:
		# Migrated contacts cannot revive the retired victim/witness decision route.
		if not VillageSession.village.people[int(key)].mind.known.is_empty():
			continue
		var r: Dictionary = reactions[key]
		if int(r.since) == since and str(r.state) in Acts.STRUCK_ONLY:
			return int(key)
	return -1

## Starts acting out any new answer the village has written (runtime.reactions); an answer that has run its
## time is ended in the loop.
func _sync_reactions(v, now: int) -> void:
	var reactions: Dictionary = v.runtime.get("reactions", {})
	if reactions.is_empty():
		return
	for key: String in reactions:
		if not v.people[int(key)].mind.known.is_empty():
			continue
		var r: Dictionary = reactions[key]
		if int(r.until) <= now:
			continue
		var id := int(key)
		if not bodies.has(id) or _skip.has(id) or not owners.can_claim(id, BY_ACT):
			continue
		var old: Acts.Act = _acts.get(id)
		if old != null and old.since == int(r.since) and old.state == str(r.state):
			continue
		var p = v.people[id]
		if not p.alive or not p.present:
			continue
		var act := Acts.Act.new()
		act.id = id
		act.state = str(r.state)
		act.since = int(r.since)
		act.until = int(r.until)
		act.reg = self
		act.body = bodies[id]
		act.mover = _movers[id]
		var struck := struck_of(act.since)
		act.onlooker = act.state in ["intervene", "shout", "back_away", "watch"] \
				or (act.state == "flee" and ((struck >= 0 and struck != id) or _who_of(v, id).age_group == "child"))
		if old != null:
			old.cleanup()
		owners.claim(id, "act", BY_ACT, _act_lost)    # the talk, a meeting or a happening lets them go
		_drop_stay(id)
		_movers[id].active = true
		act.start()
		_acts[id] = act
		_applied.erase(id)

## An answer has run its time: the body is handed back, and walks from where it stands to where the day has got to.
func _end_act(id: int, act: Acts.Act) -> void:
	act.cleanup()
	_acts.erase(id)
	owners.release(id, "act")
	_applied.erase(id)
	_tier.erase(id)
	var mover: Mover = _movers[id]
	mover.backing = false
	mover.active = true
	if mover.walking() and not mover.indoors:
		mover.hold(mover.pos, Vector2.INF)    # (planned again next frame from where they are)
	destinations.erase(id)               # planned again next frame: the way back is simply walked

func place(name: String) -> Vector2:
	if Sites.DOORS.has(name):
		return Sites.DOORS[name] # simulation homes name buildings; bodies and clues use their accessible doors
	var v = VillageSession.village
	var index: int = v.place_ids.get(name, -1)
	return Vector2(v.place_x[index], v.place_z[index]) / 10.0 if index >= 0 else Sites.at(name)

func ensure(person: Dictionary) -> Body:
	var id := int(person.id)
	if bodies.has(id):
		return bodies[id]
	var t0 := Time.get_ticks_usec()
	var body := Body.new()
	var resident = VillageSession.village.people[id]
	body.hero_look = Talk.look_of(VillageSession.village, id)
	Body.dress_his(body, VillageSession.village, id) # studio Animation: one of Enea's seven wears his own look and build (npcs.gd)
	body.is_player_look = false
	add_child(body)
	var trip := Runtime.routine(VillageSession.village, id)
	var at := place(trip.from)
	body.position = Vector3(at.x, _shape.height_at(at.x, at.y), at.y)
	bodies[id] = body
	var age := Rules.age_of(VillageSession.village, resident)
	if age < 14:
		body.scale = Vector3.ONE * CHILD_SCALE
	var C = Rules.C
	var mover := Mover.new(body, Persona.motion({"key": id, "age": age, "bold": resident.traits[C.BOLD],
		"temper": resident.traits[C.TEMPER], "sociable": resident.traits[C.SOCIABLE], "alert": resident.traits[C.ALERT],
		"scale": body.scale.x}))
	mover.ground = ground
	_movers[id] = mover
	mover.actor_key = "res:%d:%d" % [VillageSession.village.seed, id]
	body.set_meta("people_actor",mover.actor_key)
	_elements[id] = BodyElements.new()
	if body.get("voice")!=null:
		body.set("voice",voice_of(id))
	_fresh[id] = true
	_crowd.add(mover)
	mover.reroute = _router._route
	var spot := Talk.Spot.new()
	spot.name = "TalkSpot"
	spot.resident = id
	body.add_child(spot)
	_spots[id] = spot
	build_usec.append(Time.get_ticks_usec() - t0)
	return body

func acquire(person: Dictionary, parent: Node) -> Body:
	var body := ensure(person)
	owners.claim(int(person.id), "stage", BY_STAGE)   # an event needs them: a meeting, an answer, the talk let go
	_drop_stay(int(person.id))
	borrowed[int(person.id)] = true
	_movers[int(person.id)].active = false   # the stage moves them now
	body.reparent(parent, true)
	body.process_mode = Node.PROCESS_MODE_INHERIT
	body.set_detail(1)
	_applied.erase(int(person.id))
	_tier.erase(int(person.id))
	return body

## A stage that walks a borrowed body on plain ground (no device to climb) moves it through its mover: the crowd keeps
## stepping it round everyone else, at the person's own pace and turn; the stage says where, how and what to face.
func lend_mover(id: int) -> Mover:
	_lent[id] = true
	var mover: Mover = _movers[id]
	var body: Body = bodies[id]
	var at := Vector2(body.position.x, body.position.z)
	if at.distance_to(mover.pos) > 0.05:
		mover.place(at, body.rotation.y)     # (only if something else moved it: placing stops it dead)
	mover.hold(mover.pos, Vector2.INF)       # they stop as people do, until the stage says where
	return mover

func release(id: int, body: Body) -> void:
	Think.forget(_think_owner(id))
	_sense_period.erase(id)
	var lent := _lent.has(id)
	_lent.erase(id)
	if not is_instance_valid(body):
		return
	body.release_hands()
	body.walk_clip = ""
	body.reparent(self, true)
	body.process_mode = Node.PROCESS_MODE_INHERIT
	borrowed.erase(id)
	_movers[id].constraints.erase("restraint")
	owners.release(id, "stage")
	destinations.erase(id)
	if not lent:                         # the stage moved it itself: the mover takes it up from there (a stage that
		_movers[id].place(Vector2(body.position.x, body.position.z), body.rotation.y)   # walked it, carries on as is)
	_applied.erase(id)
	_tier.erase(id)
	_pick_minute.erase(id)

## ---- people meeting people (people/society.gd: meetings in passing, conversations) ------------------------------

## What the society asks of the village (people/society.gd).
func _society_director() -> Dictionary:
	return {
		"mover": func(id: int) -> Mover: return _movers[id],
		"body": func(id: int) -> Node3D: return bodies[id],
		"world": _world,
		"role": func(id: int, other: int) -> Dictionary: return _meeting_self(VillageSession.village, id, other),
		"affinity": _affinity,
		"voice": func(id: int) -> float: return float(VillageSession.village.people[id].traits[Rules.C.SOCIABLE]) / 100.0,
		"good": _good_spot,
		"busy": _busy_other,
		"doorstep": _by_a_door,
		"together": _chatting_together,
		"taken": _society_took,
		"back": _society_back,
		"ended": _society_ended,
		"parted": func(id: int, centre: Vector2, staying: Array) -> void: village_reactions.parting(id, centre, staying),
		"instead": _instead,
	}


## The society has them: for good (a conversation: what they were doing and their spot are let go) or a while (a
## meeting in passing: what they were doing waits).
func _society_took(id: int, for_good: bool) -> void:
	if not owners.claim(id, "society", BY_SOCIETY, _society_lost):
		push_warning("the society took %d while %s had them" % [id, owners.owner(id)])   # never: it is offered only the free
	_applied.erase(id)
	if for_good:
		_drop_stay(id)
		_release_spot(id)
		_claim_due.erase(id)


## The society is done with them: back to what they were doing (carry_on), else planned afresh from where they stand,
## by the trip's end (late: a hurry).
func _society_back(id: int, carry_on: bool) -> void:
	owners.release(id, "society")
	var stay: Activity.Stay = _stays.get(id)
	if carry_on and stay != null:
		stay.resume()                    # (to their own area first, if led off)
		return
	destinations.erase(id)
	_applied.erase(id)
	_pick_minute.erase(id)


func _society_ended(sit: Situation) -> void:
	if speech != null:
		speech.hush(sit.key)
	_turn_seen.erase(sit)
	_words_at.erase(sit)


## Someone in a meeting is wanted elsewhere (an answer to the player, a talk, an event): out of it (a circle talks on).
func _leave_situation(id: int) -> void:
	society.leave(id)


## Someone with a higher claim has taken `id` (people/owners.gd): whoever had them lets go of what it was doing.
func _society_lost(id: int, _by: String) -> void:
	society.leave(id)                     # out of the meeting (a circle talks on without them)


func _talk_lost(id: int, _by: String) -> void:
	if _talking == id:
		_talking = -1


func _act_lost(id: int, _by: String) -> void:
	var act: Acts.Act = _acts.get(id)
	if act != null:                       # the answer to the player is over (they talk, or an event needs them)
		act.cleanup()
		_acts.erase(id)


## Those near the player free to meet someone (not in a scene, an answer, a talk; not at prayer or a chat; out and
## about on their own), for the society to look at.
func _meet_scan(v, now: int) -> void:
	if _player == null:
		return
	var eye := player_xz()
	var free: Array[int] = []
	for id: int in bodies:
		if not owners.is_free(id) or not society.available(id) \
				or _stay_verb(v, id) in ["praying", "chatting"]:
			continue
		var mv: Mover = _movers[id]
		if not mv.active or mv.indoors or mv.wait > 0.0 or mv.exact or mv.lead != null or mv.group != 0 \
				or not (bodies[id] as Body).visible:
			continue
		if mv.pos.distance_squared_to(eye) > MEET_NEAR * MEET_NEAR:
			continue
		var p = v.people[id]
		if not p.alive or not p.present or p.locked:
			continue
		free.append(id)
	society.meet(free, now)


func _by_a_door(p: Vector2) -> bool:
	for door: Vector2 in Sites.DOORS.values():
		if p.distance_squared_to(door) < (DOORSTEP + 0.6) * (DOORSTEP + 0.6):
			return true
	return false


## Two at the same chat already (talking together: they do not meet as strangers).
func _chatting_together(a: int, b: int) -> bool:
	var va: Dictionary = _activity.get(a, {})
	var vb: Dictionary = _activity.get(b, {})
	return va.get("verb", "") == "chatting" and vb.get("verb", "") == "chatting" and va.get("place", "") == vb.get("place", "")


## What the catalogue needs to know of `id` meeting `other`.
func _meeting_self(v, id: int, other: int) -> Dictionary:
	var who := _who_of(v, id)
	var p = v.people[id]
	var C = Rules.C
	var likes := float(Rules.opinion(v, id, other))
	if Happenings.wary(v, id, other):
		likes = minf(likes, -40.0)           # they argued today: they keep clear of each other (sim/happenings.gd)
	return {"age": who.age_group, "sociable": float(p.traits[C.SOCIABLE]) / 100.0, "bold": float(p.traits[C.BOLD]) / 100.0,
		"temper": float(p.traits[C.TEMPER]) / 100.0, "likes": likes,
		"kin": who.home == _who_of(v, other).home}


## A household member setting off on the same trip as one of theirs already on the way, near them: they walk beside
## them (the one ahead leads, at the slower one's pace), leaving when the leader does.
func _family_walk(v, id: int, trip: Dictionary) -> void:
	var mover: Mover = _movers[id]
	if not mover.walking() or mover.indoors or not destinations.has(id):
		return
	var home: String = _who_of(v, id).home
	var leader := -1
	var abreast := 0
	for other: int in destinations:
		if other == id or not _movers.has(other) or not owners.is_free(other):
			continue
		var t: Dictionary = destinations[other]
		if t.start != trip.start or t.place != trip.place or t.from != trip.from or _who_of(v, other).home != home:
			continue
		var om: Mover = _movers[other]
		if om.lead != null or not om.walking() or om.indoors or om.pos.distance_to(mover.pos) > FAMILY_NEAR:
			continue
		abreast = 1
		for k: int in _movers:
			if (_movers[k] as Mover).lead == om:
				abreast += 1
		if abreast < FAMILY_MOST:
			leader = other
			break
	if leader < 0:
		return
	var lm: Mover = _movers[leader]
	mover.lead = lm
	mover.lead_side = abreast                        # 1: their left, 2: their right
	mover.wait = lm.wait                             # they leave together
	lm.pace_cap = minf(minf(lm.pace_cap, float(lm.m.pace)), float(mover.m.pace))
	if lm.group == 0:
		lm.group = 2000000 + leader                  # together in the crowd: no room kept from each other
	mover.group = lm.group


## ---- talking together (an evening's chat: people/groups.gd, formation.gd, situation.gd) ------------------------

## The verb the day will have them at where they are going (sim/view.gd), arrived or not.
func _verb_there(v, id: int) -> String:
	var trip: Dictionary = destinations.get(id, {})
	if trip.is_empty():
		return ""
	return View._verb_at(v, v.people[id], str(trip.place), int(trip.end) % 1440)


## How well a gets on with b, for who talks with whom: the rules' opinion, kin warmer, children with children.
func _affinity(a: int, b: int) -> float:
	var v = VillageSession.village
	var f := float(Rules.opinion(v, a, b))
	var wa := _who_of(v, a)
	var wb := _who_of(v, b)
	if (wa.age_group == "child") != (wb.age_group == "child"):
		f -= 25.0                            # grown people talk with grown people, children with children
	return f


## Takes `id` (arriving at, or standing at, an evening's chat) into a conversation there (people/society.gd talk).
## False if nobody there would have them yet.
func _join_talk(v, id: int) -> bool:
	var trip: Dictionary = destinations.get(id, {})
	if trip.is_empty():
		return false
	var place_name := str(trip.place)
	return society.talk(place_name, id, _lone_talkers(v, place_name, id))


## Those standing about at a place's chat with nobody to talk to (arrived, free), not counting `but`.
func _lone_talkers(v, place_name: String, but := -1) -> Array[int]:
	var out: Array[int] = []
	for id: int in bodies:
		if id == but or not owners.is_free(id):
			continue
		var trip: Dictionary = destinations.get(id, {})
		var mv: Mover = _movers[id]
		if trip.is_empty() or str(trip.place) != place_name or mv.walking() or mv.indoors or not (bodies[id] as Body).visible:
			continue
		if _stay_verb(v, id) == "chatting":
			out.append(id)
	return out


## Someone not among `members` stands within r of p (or is on their way there).
func _busy_other(p: Vector2, r: float, members: Array) -> bool:
	for other: int in _movers:
		if members.has(other):
			continue
		var m: Mover = _movers[other]
		if not m.active or m.indoors or not (bodies[other] as Body).visible:
			continue
		if m.pos.distance_squared_to(p) < r * r:
			return true
		var goal: Vector2 = m.path[-1] if m.walking() and not m.path.is_empty() else m.hold_at
		if goal != Vector2.INF and goal.distance_squared_to(p) < r * r and not society.in_sit.has(other):   # (a slot of theirs: the society's own record,
			# which takes a joiner in a moment after they are handed over)
			return true
	return false


## Every TALK_EVERY, at each place with a chat (or conversations still going): those on their own there find company,
## circles mingle, one down to one ends (people/society.gd tend).
func _talk_scan(v) -> void:
	var places := {}
	for id: int in bodies:
		var trip: Dictionary = destinations.get(id, {})
		if not trip.is_empty() and _stay_verb(v, id) == "chatting":
			places[str(trip.place)] = true
	for place_name: String in society.places():
		places[place_name] = true
	for place_name: String in places:
		society.tend(place_name, _lone_talkers(v, place_name))


## The conversations going on (a measure: motion_watch.gd groups_source).
func talking_groups() -> Array:
	return society.groups()


## ---- staying somewhere (people/activity.gd) --------------------------------------------------------------------

## What a stay is for: the verb and place the day has them at, and the trip (a new trip, a new stay).
func _stay_key(id: int) -> String:
	var trip: Dictionary = destinations.get(id, {})
	return "%s|%s|%s" % [_stay_verb(VillageSession.village, id), trip.get("place", ""), str(trip.get("start", ""))]


## What they do where they are: the day's verb, or - there early, the trip not over yet - the verb they will have
## there (sim/view.gd), so nobody stands about waiting for the clock.
func _stay_verb(v, id: int) -> String:
	var a: Dictionary = _activity.get(id, {})
	var verb := str(a.get("verb", ""))
	if verb == "walking" or a.get("moving", false):
		var trip: Dictionary = destinations.get(id, {})
		if trip.is_empty() or (_movers[id] as Mover).walking():
			return "walking"
		verb = View._verb_at(v, v.people[id], str(trip.place), int(trip.end) % 1440)
	return verb


## A stay for someone who has got where the day has them (none for a chat: the talkers run that, nor indoors).
func _make_stay(v, id: int, pick: Dictionary, clock: float) -> Activity.Stay:
	var trip: Dictionary = destinations.get(id, {})
	if trip.is_empty() or not _activity.has(id) or _inside.get(id, false):
		return null
	var verb := _stay_verb(v, id)
	var who := _who_of(v, id)
	var kind := Activity.kind_for(verb, who.age_group == "child")
	if kind == "":
		return null
	var mover: Mover = _movers[id]
	var p = v.people[id]
	var C = Rules.C
	var area := -1.0
	if _spot_of.has(id):
		area = minf(float(Activity.PROFILES[kind].area), 2.0)    # a spot in a gathering: about it, not across it
	var world := _world.duplicate()
	world["busy"] = _busy_near.bind(id)
	world["sights"] = _sights.bind(id)
	world["errands"] = _errands.bind(id, who)
	var stay := Activity.Stay.new(kind, mover, bodies[id], {"at": mover.hold_at if mover.hold_at != Vector2.INF else mover.pos,
		"face": _work_face(verb, str(trip.place)), "area": area}, world,
		{"key": id * 7 + int(trip.start), "restless": (float(p.traits[C.TEMPER]) + float(p.traits[C.ALERT])) / 200.0,
		"sociable": float(p.traits[C.SOCIABLE]) / 100.0, "child": who.age_group == "child"})
	stay.until = (_stay_end(v, id) - clock) * 0.5
	_stays[id] = stay
	_stay_for[id] = _stay_key(id)
	_applied.erase(id)
	(bodies[id] as Body).show_tool(str(pick.get("tool", "")))
	return stay


## What the work of a verb at a place faces: the work (the field, the well, the shrine), the house (about it), or INF.
func _work_face(verb: String, place_name: String) -> Vector2:
	if verb in Anims.FACES_WORK:
		return focus(place_name)
	if verb in ["at_home", "eating", "visiting"]:
		return Sites.HOMES.get(place_name, Vector2.INF)
	return Vector2.INF


func _drop_stay(id: int) -> void:
	if _stays.erase(id):
		_stay_for.erase(id)
		_applied.erase(id)
		if bodies.has(id):
			(bodies[id] as Body).show_tool("")


## The minute (of the whole clock) their present stay ends: the end of the day plan's block they are in.
func _stay_end(v, id: int) -> float:
	var p = v.people[id]
	var now := int(v.runtime.now)
	var minute := now % 1440
	for i in range(0, p.plan.size(), 3):
		if minute >= p.plan[i] and minute < p.plan[i + 1]:
			return float(now - minute + p.plan[i + 1])
	return float(now + 60)


## A spot one can stand on: room round it (no wall, tree, prop or one of Enea's people) and off every doorstep.
func _good_spot(p: Vector2) -> bool:
	for door: Vector2 in Sites.DOORS.values():
		if p.distance_squared_to(door) < DOORSTEP * DOORSTEP:
			return false
	return _standable(p)


## Nothing solid (a house) within Activity.OPEN_AHEAD of a spot, in the direction `dir`.
func _open_ahead(p: Vector2, dir: Vector2) -> bool:
	if dir.length_squared() < 0.0001:
		return true
	return not _router._blocked(p + dir.normalized() * maxf(Activity.OPEN_AHEAD - Stage.BODY_RADIUS, 0.05))


## Someone other than `id` stands within r of p, or is on their way to a spot there.
func _busy_near(p: Vector2, r: float, id: int) -> bool:
	var r2 := r * r
	for other: int in _movers:
		if other == id:
			continue
		var m: Mover = _movers[other]
		if not m.active or m.indoors or not (bodies[other] as Body).visible:
			continue
		if m.pos.distance_squared_to(p) < r2:
			return true
		var goal: Vector2 = m.path[-1] if m.walking() and not m.path.is_empty() else m.hold_at
		if goal != Vector2.INF and goal.distance_squared_to(p) < r2:
			return true
	return false


## What someone standing at p might look at: the player near, people walking by, a meeting going on (a quarrel most of
## all), children at play. [[point, weight], ...]
func _sights(p: Vector2, id: int) -> Array:
	var out: Array = []
	var near2 := SIGHT_NEAR * SIGHT_NEAR
	if _player != null:
		var eye := player_xz()
		if eye.distance_squared_to(p) < 100.0 and _sees(p, eye):
			out.append([eye, 3.0])
	for other: int in _movers:
		if other == id:
			continue
		var m: Mover = _movers[other]
		if not m.active or m.indoors or not (bodies[other] as Body).visible:
			continue
		var d2 := m.pos.distance_squared_to(p)
		if d2 > near2 or d2 < 0.5 or not _sees(p, m.pos):
			continue
		var w := 0.0
		var sit: Situation = society.in_sit.get(other)
		if sit != null:
			w = 4.0 if sit.name == "quarrel" else 1.5
		elif m.vel.length() > 0.5:
			w = 1.0 + (1.0 if m.vel.length() > 2.5 else 0.0)
		if w > 0.0:
			out.append([m.pos, w / (1.0 + sqrt(d2) / 6.0)])
	return out


## The sights near p for a glance (_sights), at eye height.
func _sights_seen(p: Vector2, id: int) -> Array:
	var out: Array = []
	for s: Array in _sights(p, id):
		var at: Vector2 = s[0]
		out.append([Vector3(at.x, ground(at) + 1.5, at.y), s[1]])
	return out


## Short errands from p for `id` (a grown one about the house; a child, to other children): water from the well, a word
## at the merchant's, a friend's yard, a quick prayer.
func _errands(p: Vector2, id: int, who: Dictionary) -> Array:
	var out: Array = []
	var v = VillageSession.village
	if who.age_group == "child":
		for other: int in _stays:
			var s: Activity.Stay = _stays[other]
			if other != id and s.kind == "child_about" and s.mover.pos.distance_to(p) < Activity.ERRAND_FAR:
				var at := _spot_by(s.mover.pos, 1.6, p, id)
				if at != Vector2.INF:
					out.append({"at": at, "face": s.mover.pos, "clips": ["Dance", "Jump"], "seconds": 4.0, "weight": 2.0})
		return out
	var well := focus("well")
	var at_well := _spot_by(well, 1.7, p, id)
	if at_well != Vector2.INF:
		out.append({"at": at_well, "face": well, "clips": ["Farm_Watering", "Interact"], "seconds": 7.0, "weight": 1.0})
	var stall: Vector2 = Sites.PLACES["merchant"]["at"]
	var at_stall := _spot_by(stall, 1.5, p, id)
	if at_stall != Vector2.INF:
		out.append({"at": at_stall, "face": stall, "clips": ["Idle_Talking", "Yes", "Interact"], "seconds": 8.0, "weight": 0.8})
	var shrine := focus("shrine")
	var at_shrine := _spot_by(shrine, 2.6, p, id)
	if at_shrine != Vector2.INF:
		var pious := float(v.people[id].traits[Rules.C.PIETY]) / 100.0
		out.append({"at": at_shrine, "face": shrine, "clips": ["Spell_Simple_Idle"], "seconds": 8.0, "weight": 0.6 * pious})
	for other: int in _stays:
		var s: Activity.Stay = _stays[other]
		if other == id or s.kind != "about_the_house" or s.mover.pos.distance_to(p) > Activity.ERRAND_FAR:
			continue
		if _who_of(v, other).home == who.home or Rules.opinion(v, id, other) < VISIT_LIKES:
			continue
		var at := _spot_by(s.mover.pos, 1.3, p, id)
		if at != Vector2.INF:
			out.append({"at": at, "face": s.mover.pos, "clips": ["Idle_Rail_Call"], "seconds": 2.0, "weight": 1.6,
				"meet": _visit.bind(id, other)})
	return out


## Where an onlooker of a blow at `centre` stands: on a ring round it, the bold nearer (Formation.RING_NEAR) and the
## timid further (RING_FAR), on their own side of it, never on the side the camera looks from (they would hide it),
## on good ground with nobody there, in sight of it.
func onlooker_spot(id: int, centre: Vector2) -> Vector2:
	var v = VillageSession.village
	var mover: Mover = _movers[id]
	var bold := float(v.people[id].traits[Rules.C.BOLD]) / 100.0
	var r := lerpf(Formation.RING_FAR, Formation.RING_NEAR, bold)
	var mine := mover.pos - centre
	var a0 := atan2(mine.y, mine.x) if mine.length_squared() > 0.01 else Activity.noise(id, 5) * TAU
	var open := atan2(Sites.ARC_OPEN_TOWARDS.y, Sites.ARC_OPEN_TOWARDS.x)
	var off := angle_difference(open, a0)
	if absf(off) < Formation.RING_OPEN:
		a0 = open + signf(off if off != 0.0 else 1.0) * Formation.RING_OPEN     # to the edge of the open side
	for k in 11:
		var a := a0 + 0.3 * ((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)
		if absf(angle_difference(open, a)) < Formation.RING_OPEN:
			continue
		for ring: float in [r, r + 0.7]:
			var c := centre + Vector2(cos(a), sin(a)) * ring
			if _good_spot(c) and not _busy_near(c, 0.9, id) and _sees(c, centre):
				return c
	return mover.pos


## A visit's arrival: the friend stops what they are doing for a word (if they are free), as a meeting.
func _visit(id: int, friend: int) -> void:
	if not owners.is_free(id) or not owners.is_free(friend):
		return
	var v = VillageSession.village
	var k := hash([id, friend, int(_life)])
	society.start("gossip" if Activity.noise(k, 3) < 0.6 else "show_something", id, friend, k)


## A good free spot `r` from `target`, on the side facing `from` if it can (else round it). INF: none.
func _spot_by(target: Vector2, r: float, from: Vector2, id: int) -> Vector2:
	var side := from - target
	var a0 := atan2(side.y, side.x) if side.length_squared() > 0.01 else 0.0
	for k in 7:
		var a := a0 + (0.45 * ((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0))
		var c := target + Vector2(cos(a), sin(a)) * r
		if _good_spot(c) and not _busy_near(c, Activity.KEEP_APART, id):
			return c
	return Vector2.INF


## ---- heads and blows (people/look.gd, pose.gd) ------------------------------------------------------------------

## Where everyone near the player looks, ten times a second: whoever talks to them, a blow near, their conversation's
## speaker, the player passing, what passes. Further off, heads face ahead (no modifier at all).
func _looks(v, delta: float) -> void:
	var eye := player_xz()
	var head := _player.global_position + Vector3(0.0, 1.6, 0.0) if _player != null else Vector3.INF
	var moving: bool = _player != null and (_player as CharacterBody3D).velocity.length() > 0.5
	while not _events.is_empty() and _life - float(_events[0][1]) > Look.EVENT_FOR:
		_events.pop_front()
	for id: int in bodies:
		var body: Body = bodies[id]
		var mv: Mover = _movers[id]
		if _expression_look.get(id,Vector3.INF)!=Vector3.INF:
			continue # One gaze target: Mind's current measured expression takes precedence.
		var near: bool = body.visible and _tier.get(id, 2) == 0 and mv.pos.distance_squared_to(eye) < LOOK_NEAR * LOOK_NEAR
		if not near or owners.held(id, "stage"):
			if _gazes.erase(id):
				body.look_at_point(Vector3.INF)
			continue
		var gaze: Look.Gaze = _gazes.get(id)
		if gaze == null:
			gaze = Look.Gaze.new(id * 31, float(v.people[id].traits[Rules.C.ALERT]) / 100.0)
			_gazes[id] = gaze
			_look_due[id] = Look.Gaze.noise(id, 77) * LOOK_EVERY     # each on their own beat: the work spread over frames
		_look_due[id] = float(_look_due.get(id, 0.0)) - delta
		if _look_due[id] > 0.0:
			continue
		_look_due[id] = float(_look_due[id]) + LOOK_EVERY
		var ctx := {"eye": body.global_position + Vector3(0.0, 1.6 * body.scale.y, 0.0), "forward": body.global_basis.z,
			"player": head, "player_near": mv.pos.distance_to(eye), "player_moving": moving}
		if owners.held(id, "talk") or (owners.held(id, "act") and not (_acts[id] as Acts.Act).onlooker):
			ctx["addressed"] = head
		var sit: Situation = society.in_sit.get(id)
		if sit != null:
			var i := sit.who.find(id)
			var to := sit.looks_to(i)
			if sit.shape() == "circle":
				if to >= 0:
					ctx["speaker"] = _head_of(sit.who[to])
				var others: Array = []
				for other: int in sit.who:
					if other != id and (to < 0 or other != sit.who[to]):
						others.append(_head_of(other))
				ctx["others"] = others
			elif sit.shape() == "beside":
				if to >= 0:
					ctx["speaker"] = _head_of(sit.who[to])
			elif to >= 0:
				ctx["addressed"] = _head_of(sit.who[to])
		if not _events.is_empty():
			var last: Vector3 = _events[-1][0]
			if Vector2(last.x, last.z).distance_squared_to(mv.pos) < EVENT_NEAR * EVENT_NEAR:
				ctx["event"] = last
		ctx["sights"] = _sights_seen.bind(mv.pos, id)     # (worked out only when a glance is due)
		var was := gaze.kind
		var at := gaze.update(LOOK_EVERY, ctx)
		body.look_at_point(at)
		if gaze.kind == "player" and was != "player" and _life - float(_waved.get(id, -INF)) > WAVE_AGAIN \
				and not _acts.has(id) and View.toward_player(v, id).feeling >= WAVE_LIKES:
			_waved[id] = _life
			body.wave(1.6)                   # someone who likes them: a wave as they pass


## Conversations near the player are heard: each new turn the speaker's voice murmurs (people/speech.gd); close by, the
## player catches a few words now and then - a line, and a word back.
func _voices(v) -> void:
	if speech == null or _player == null:
		return
	if not is_instance_valid(speech.camera):
		var rig := get_tree().current_scene.get_node_or_null("CameraRig")
		if rig != null and rig.get("camera") != null:
			speech.camera = rig.camera
		speech.listener = _player
	var eye := player_xz()
	for sit: Situation in society.situations:
		if sit.phase != "beats" or not sit.shape() in ["circle", "pair", "crouch", "beside"]:
			continue
		var s := sit.speaker()
		if s < 0 or int(_turn_seen.get(sit, -1)) == sit._beat:
			continue
		_turn_seen[sit] = sit._beat
		var who: int = sit.who[s]
		var mv: Mover = _movers[who]
		var far := mv.pos.distance_to(eye)
		if far > HEARD_NEAR:
			continue
		var body: Body = bodies[who]
		if far < OVERHEAR and _life - float(_words_at.get(sit, -INF)) > WORDS_EVERY:
			_words_at[sit] = _life
			var d := View.describe(v, who)
			speech.say(body, Lines.overheard(d, int(v.runtime.now) / 1440, int(v.runtime.now) % 1440, sit.key + sit._beat),
				Speech.TALK, sit.key, voice_of(who), 3.2)
		elif far < OVERHEAR and _life - float(_words_at.get(sit, -INF)) < 3.0:
			speech.say(body, Lines.reply(sit.key + sit._beat), Speech.TALK, sit.key, voice_of(who), 1.8)
		else:
			speech.murmur(body, sit.key, voice_of(who), maxf(sit._beat_left, 1.0) * 0.8)


## Someone's voice (resident_talk.gd: by age and sex), asked once.
func voice_of(id: int) -> String:
	if not _voice.has(id):
		_voice[id] = Talk.voice_of(View.describe(VillageSession.village, id))
	return _voice[id]


func _head_of(id: int) -> Vector3:
	var b: Body = bodies[id]
	return b.global_position + Vector3(0.0, 1.55 * b.scale.y, 0.0)


## B6 receipt feedback after checked publication. No injury or second action here.
func play_contact(id: int, receipt: Dictionary) -> void:
	Think.now(_think_owner(id), "sense", "contact")     # struck, shoved: they sense it at once
	if not bodies.has(id) or receipt.get("duplicate",false):
		return
	var body: Body=bodies[id]
	var point: Array=receipt.get("from",[body.global_position.x,body.global_position.z+1.0])
	var from := Vector3(float(point[0])-body.global_position.x,0.0,float(point[1])-body.global_position.z)
	var fact := {"from":from,"force":int(receipt.get("force",0)),"deed":str(receipt.get("action_id","")),
		"since_tick":PeopleBody.tick(VillageSession.village),"kind":"impact"}
	_elements[id].play("impact",element_port(id),float(fact.force)/1000.0,fact)
	_events.append([_head_of(id),_life])

## Unmigrated authored combat compatibility; new checked contact calls play_contact.
func on_struck(id: int, heavy: bool) -> void:
	if not bodies.has(id):
		return
	var at: Vector3=_player.global_position if is_instance_valid(_player) else bodies[id].global_position+Vector3.FORWARD
	play_contact(id,{"force":850 if heavy else 450,"from":[at.x,at.z]})

## Actual fact lookup, including identity/revision/removal. A copied expiration is never authority.
func _body_fact(id: int, fact: Dictionary) -> Dictionary:
	var v=VillageSession.village
	if v==null or id>=v.people.size():
		return {}
	var current: Dictionary=v.people[id].body_facts.get(str(fact.get("kind",fact.get("id",""))),{})
	if current.is_empty() or str(current.get("deed",""))!=str(fact.get("deed","")) or int(current.get("revision",0))!=int(fact.get("revision",0)):
		return {}
	if current.has("until_tick") and int(current.until_tick)<=PeopleBody.tick(v):
		return {}
	return current

func element_port(id: int) -> Dictionary:
	var v=VillageSession.village
	return {"body":bodies[id],"mover":_movers[id],"source":_movers[id].actor_key,
		"visible":bodies[id].is_visible_in_tree(),"hints":_expression_hints[id] if _expression_hints.has(id) else PeopleBody.hints(v.people[id].mind),
		"current":func(fact: Dictionary) -> Dictionary: return _body_fact(id,fact),
		"live":func(fact: Dictionary) -> bool: return not _body_fact(id,fact).is_empty(),
		"emit":func(kind: String, fields: Dictionary) -> void:
			stimuli.emit(kind,_movers[id].pos,float(fields.get("loud",0)),id,2.0,fields),
		"announce":func(kind: String, fact: Dictionary, transition := false) -> bool:
			if people_bridge==null or _body_fact(id,fact).is_empty():
				return false
			return people_bridge.announce(_movers[id].actor_key,{"kind":kind,"subject":_movers[id].actor_key,
				"deed":fact.get("deed",""),"fact_id":fact.get("id",fact.get("kind","")),
				"revision":int(fact.get("revision",0)),"transition":transition}),
		"vocal":func(kind: String, strength: float) -> void:
			if bodies[id].has_method("vocal"):
				bodies[id].call("vocal",kind,clampf(strength,0,1))}

## S5 presentation consumer. Integration supplies Mind's current projected expression here.
## regard/attention identities match current visible P4 bodies through Bridge.appearance.
## keep_m is preferred centre distance, not a flight goal. Named attention never follows stale saved at.
func express_body(id: int, hints: Dictionary) -> void:
	var tx := Prof.now()
	_expression_hints[id]=hints.duplicate(true)
	if not bodies.has(id):
		return
	var body: Body=bodies[id]
	_bind_expression(id)
	if body.has_method("express"):
		body.call("express",hints)
	Prof.add("bridge.express_body", tx)

## S5 physical consumer. Uses the existing apparent identity fold, recognition policy and ONE nearby grid.
## No belief is written here; hidden/unfamiliar/departed bodies yield no match. Masks remain appearances.
func _regard(id: int, hints: Dictionary) -> Dictionary:
	var out := {"space":{},"look":Vector3.INF,"node":null}
	if not bodies.has(id) or people_bridge==null or _crowd==null:
		return out
	var body: Body=bodies[id]
	if not body.is_visible_in_tree() or (is_instance_valid(_player) and body.global_position.distance_to(_player.global_position)>_sight_m()):
		return out
	var attention: Dictionary=hints.get("attention",{})
	var identity := str(attention.get("identity","unknown"))
	var rows: Array=hints.get("regard",[]).slice(0,3)
	if rows.is_empty() and attention.is_empty():
		return out
	var at: Array=attention.get("at",[])
	var watch := 0.0
	# Anonymous attention may orient to the measured occurrence, never an alleged actor.
	if identity in ["","unknown"] and at.size()==2 and float(attention.get("watch",0))>0:
		out.look=Vector3(float(at[0]),body.global_position.y+1.4,float(at[1]))
		watch=float(attention.get("watch",0))
	var v=VillageSession.village
	var observer: String=_movers[id].actor_key
	var origin := body.global_position
	var seen := {}
	for row: Dictionary in _crowd.nearby.query(Vector2(origin.x,origin.z),LOOK_NEAR):
		var found: Variant=row.get("body")
		if not is_instance_valid(found):   # studio: Foundations, merge-enea - a body freed this frame (a slain foe) may still be in the crowd's index: assigning it to a typed var errored
			continue
		var other: Node3D=found
		if other==body or seen.has(other.get_instance_id()) or not other.is_visible_in_tree():
			continue
		seen[other.get_instance_id()]=true
		var current := other.global_position
		var direction := current-origin
		direction.y=0
		if direction.length()>LOOK_NEAR or (direction.length()>3.0 and body.global_basis.z.dot(direction.normalized())<float(Balance.STEALTH.fov)):
			continue
		var actor := str(row.key)
		var named: bool=PeopleBody.resident(v,actor)>=0 or actor=="player:local" or actor==observer or observer in Array(other.get_meta("people_recognized_by",[]))
		var shown: Dictionary=Perception.recognized(people_bridge.appearance(actor),"seen",named)
		var key := str(shown.get("key","unknown"))
		if key in ["","unknown"]:
			continue
		if key!=identity and not rows.any(func(item: Dictionary) -> bool: return str(item.get("identity","unknown"))==key):
			continue   # nothing asked about them: no sight line worked out (the ray is the dear part)
		if not BodyContact.clear(body,origin,current):
			continue
		var own_watch := float(attention.get("watch",0)) if identity==key else 0.0
		for item: Dictionary in rows:
			if str(item.get("identity","unknown"))==key:
				out.space[other.get_instance_id()]=clampf(float(item.get("keep_m",1.4)),0.6,4.0)
				own_watch=maxf(own_watch,clampf(float(item.get("watch",0)),0,1))
		if own_watch>watch:
			out.look=current+Vector3(0,1.4,0)
			out.node=other
			watch=own_watch
	return out

## Think's "sense" work for one body (village/think.gd, staggered, within the frame's think budget; at once on an
## event: Think.now): whom they regard is worked out again, unless Mind's hints just did (express_body), and their
## elements are reconciled in this frame's _physical.
func _sense_beat(_elapsed: float, id: int) -> void:
	if not bodies.has(id):
		Think.forget(_think_owner(id))
		_sense_period.erase(id)
		return
	_beat[id] = true
	if Controls.locked or VillageSession.background:
		return
	if people_bridge != null and people_bridge.has_method("expression_for"):
		# Mind's hints on Body's beat (the bridge's own every-3-frames loop retired): every beat rebinds, so a hint that
		# changes outside an event (attention decaying) never outlives itself by more than one beat. Events still bind
		# at once through express_body.
		express_body(id, people_bridge.call("expression_for", id))
	elif _age - float(_bound_at.get(id, -INF)) >= float(_sense_period.get(id, SENSE_EVERY)) * 0.8:
		_bind_expression(id)


static func _think_owner(id: int) -> String:
	return "resident:%d" % id

## Between sense beats, a head watching someone follows where they are now (who to watch is chosen on the beat).
func _follow_look(id: int) -> void:
	if not _look_node.has(id):
		return
	var node: Node3D=_look_node[id].get_ref()
	if not is_instance_valid(node) or _expression_look.get(id,Vector3.INF)==Vector3.INF:
		_look_node.erase(id)
		return
	var at := node.global_position+Vector3(0,1.4,0)
	_expression_look[id]=at
	bodies[id].look_at_point(at)

## A villager's sight in metres (people_bridge.villager_sight_m: 12 by day): regard attends only within it.
func _sight_m() -> float:
	if _sight < 0.0 and people_bridge != null and people_bridge.has_method("villager_sight_m"):
		_sight = float(people_bridge.call("villager_sight_m"))
	return _sight if _sight >= 0.0 else 12.0

func _bind_expression(id: int) -> void:
	if not _movers.has(id):
		return
	_bound_at[id]=_age
	var v=VillageSession.village
	var hints: Dictionary=_expression_hints.get(id,{}) if v!=null and v.people[id].alive else {}
	var tr := Prof.now()
	var sensed := _regard(id,hints)
	Prof.add("res.bind.regard", tr)
	_movers[id].regard=sensed.space
	var prior: Vector3=_expression_look.get(id,Vector3.INF)
	_expression_look[id]=sensed.look
	if sensed.node!=null:
		_look_node[id]=weakref(sensed.node)   # (followed every frame between beats: _follow_look)
	else:
		_look_node.erase(id)
	if sensed.look!=Vector3.INF or prior!=Vector3.INF:
		bodies[id].look_at_point(sensed.look)

## Every frame: what holds the body (restraint, carrying), and its elements' steps while it is `seen` (near and on screen;
## else on the beat too, unless an element is moving it). On its sense beat, or at once when its facts change or it is
## shown again: the elements reconciled with its facts and Mind's hints, and its expression.
func _physical(id: int, dt: float, beat := true, seen := true) -> void:
	if not _elements.has(id):
		return
	var v=VillageSession.village
	var p=v.people[id]
	var mover: Mover=_movers[id]
	var body: Body=bodies[id]
	var th := Prof.now()
	# Restore semantic location first; a live carrier then anchors from its actual position.
	if not _element_ticks.has(id) and (p.body_facts.has("down") or p.body_facts.has("dead") or p.body_facts.has("carried")):
		var fact: Dictionary=p.body_facts.get("location",p.body_facts.get("dead",p.body_facts.get("down",{})))
		var at: Array=fact.get("at",[])
		if at.size()==2:
			mover.place(Vector2(float(at[0]),float(at[1])))
			body.position=Vector3(mover.pos.x,ground(mover.pos),mover.pos.y)
	if not mover.active or body.hands_held():
		mover.pos=Vector2(body.global_position.x,body.global_position.z) # Measure a stage-held body's actual contact location.
		mover.vel=Vector2.ZERO
	if body.hands_held():
		mover.constraints["restraint"]={"move":false,"postures":["upright"]}
	else:
		mover.constraints.erase("restraint")
	if p.body_facts.has("carried"):
		mover.constraints["carried"]={"move":false,"indoors":false}
		if owners.claim(id,"carry",8,Callable(),true):
			_drop_stay(id)
			var carrier: Node3D=people_bridge.actor_node(str(p.body_facts.carried.carrier)) if people_bridge!=null else null
			if is_instance_valid(carrier) and not body.hands_held():
				var visual: Node3D=carrier.get_node_or_null("Visual")
				var yaw := visual.rotation.y if visual!=null else carrier.rotation.y
				var behind := Vector3(sin(yaw),0,cos(yaw))*-0.8
				body.global_position=carrier.global_position+behind+Vector3(0,0.8,0)
				mover.pos=Vector2(body.position.x,body.position.z)
				mover.vel=Vector2.ZERO
				carrier.set_meta("studio_people_load",id)
				_carry_nodes[id]=weakref(carrier)
	else:
		if owners.held(id,"carry") or owners.suspended(id,"carry"):
			var actual := Vector2(body.position.x,body.position.z)
			mover.place(actual,body.rotation.y)
			body.position.y=ground(actual)
			mover.constraints.erase("carried")
			owners.release(id,"carry")
			if _carry_nodes.has(id):
				var carrier: Node3D=_carry_nodes[id].get_ref()
				if is_instance_valid(carrier) and int(carrier.get_meta("studio_people_load",-1))==id:
					carrier.remove_meta("studio_people_load")
				_carry_nodes.erase(id)
			if people_bridge!=null:
				for row: Dictionary in _crowd.nearby.rows:
					var found: Variant=row.get("body")   # studio: Foundations, merge-enea - a freed body is skipped before its typed use
					if not is_instance_valid(found):continue
					var carrier: Node3D=found
					if int(carrier.get_meta("studio_people_load",-1))==id:
						carrier.remove_meta("studio_people_load")
		mover.constraints.erase("carried")
	th = Prof.add("res.phys.hold", th)
	var tick := PeopleBody.tick(v)
	var hydrate: bool=not _element_ticks.has(id) or absi(tick-int(_element_ticks.get(id,tick)))>1000 or (_element_visible.get(id,false)==false and body.is_visible_in_tree())
	_element_ticks[id]=tick
	_element_visible[id]=body.is_visible_in_tree()
	var runner = _elements[id]
	var facts_now: int = p.body_facts.hash()
	th = Prof.add("res.phys.hash", th)
	var owed: float = _element_dt.get(id, 0.0) + dt   # elements' time since their last step
	if not beat and not hydrate and int(_element_facts.get(id, 0)) == facts_now:
		if not seen and not _moving_element(runner):
			_element_dt[id] = owed       # far or off screen: the elements step on the beat with the time owed
			return
		runner.update(owed)              # seen (a flail, a run for water), or a blow or a fall moving it: every frame
		_element_dt[id] = 0.0
		th = Prof.add("res.phys.off_update", th)
		if body.has_method("apply_elements"):
			body.call("apply_elements",runner.layers)
		Prof.add("res.phys.off_apply", th)
		return
	_element_facts[id]=facts_now
	dt = owed
	_element_dt[id] = 0.0
	var tp := Prof.now()
	var port := element_port(id)
	tp = Prof.add("res.phys.port", tp)
	runner.reconcile(port,p.body_facts,tick,hydrate)
	tp = Prof.add("res.phys.reconcile", tp)
	runner.express(port,port.hints)
	tp = Prof.add("res.phys.runner_express", tp)
	runner.update(dt)
	tp = Prof.add("res.phys.runner_update", tp)
	if body.has_method("apply_elements"):
		body.call("apply_elements",runner.layers)
	tp = Prof.add("res.phys.apply_elements", tp)
	if body.has_method("express"):
		body.call("express",port.hints)
	Prof.add("res.phys.body_express", tp)

## Whether an element is moving the body now (a blow; falling or getting up): stepped every frame, not on the beat.
static func _moving_element(runner) -> bool:
	if runner.playing.has("impact"):
		return true
	var down: Dictionary = runner.playing.get("down", {})
	return not down.is_empty() and str(down.state.get("phase", "")) != "lie"

## ---- measures (motion_watch.gd) -------------------------------------------------------------------------------

## What they are about, for a measure's notes: "<stay kind>/<bit>" while they stay, else why they have no stay.
func doing_of(id: int) -> String:
	var stay: Activity.Stay = _stays.get(id)
	if stay != null:
		var spot := ""
		if _spot_of.has(id):
			var at: Vector2 = place(_spot_of[id]) + _at_offset.get(id, Vector2.ZERO)
			spot = ", spot (%.1f, %.1f)" % [at.x, at.y]
		return "%s/%s, anchor (%.1f, %.1f)%s" % [stay.kind, stay.doing, stay.anchor.x, stay.anchor.y, spot]
	var mv: Mover = _movers.get(id)
	var why := engaged(id)
	if why != "":
		return why
	if mv != null and mv.walking():
		return "on the way"
	var a: Dictionary = _activity.get(id, {})
	return "no stay: %s at %s (%s)" % [a.get("verb", "?"), a.get("place", "?"), _stay_verb(VillageSession.village, id) if _activity.has(id) else "-"]


## What has `id` busy with someone: "meeting", "talk", "act", "scene", or "" (their own day).
func engaged(id: int) -> String:
	return {"society": "meeting", "talk": "talk", "act": "act", "stage": "scene", "happening": "happening"}.get(owners.owner(id), "")


## Why the spot `id` stands on would look wrong to an eye, "" if it looks fine, "-" if they are not standing on a spot
## of their own (walking; a scene or a reaction moves them):
##   in_wall      inside a house
##   doorstep     on a doorstep, neither going in nor coming out
##   facing_wall  nose to a wall (a house within AWKWARD_FACE in front)
##   on_someone   closer than AWKWARD_CLOSE to someone else standing (two grown bodies all but touching)
func awkward_at(id: int) -> String:
	var mv: Mover = _movers.get(id)
	if mv == null or not mv.active or mv.walking() or mv.indoors or owners.held(id, "stage"):
		return "-"
	var p := mv.pos
	if _crowd.in_wall(p):
		return "in_wall"
	for door: Vector2 in Sites.DOORS.values():
		if p.distance_squared_to(door) < AWKWARD_DOOR * AWKWARD_DOOR:
			return "doorstep"
	var ahead := p + Vector2(sin(mv.yaw), cos(mv.yaw)) * maxf(AWKWARD_FACE - Stage.BODY_RADIUS, 0.05)
	if _router._blocked(ahead):
		return "facing_wall"
	var size := (bodies[id] as Body).scale.x
	for other: int in _movers:
		if other == id:
			continue
		var om: Mover = _movers[other]
		if not om.active or om.walking() or om.indoors or not (bodies[other] as Body).is_visible_in_tree():
			continue
		var near := AWKWARD_CLOSE * (size + (bodies[other] as Body).scale.x) * 0.5
		if om.pos.distance_squared_to(p) < near * near:
			return "on_someone"
	return ""


## Everything else on foot the crowd steers round: the player, bodies a scene or a reaction is moving, Enea's people
## and animals.
func _others() -> Array:
	var out := []
	if _player != null:
		out.append([_player, 0.35])
	for id: int in bodies:
		var body: Body = bodies[id]
		if not (_movers[id] as Mover).active and body.is_visible_in_tree():
			out.append([body, 0.25 * body.scale.x])
	_others_left -= get_process_delta_time()
	if _others_left <= 0.0:
		_others_left = OTHERS_EVERY
		_world_others.clear()
		var seen := {}
		for group: String in ["enemy", "stag", "ox_cart"]:
			for n: Node in get_tree().get_nodes_in_group(group):
				if n is Node3D and not seen.has(n) and not n.has_meta("crowd_ignore") and (n as Node3D).is_visible_in_tree():
					seen[n] = true
					_world_others.append([n, 1.2 if group == "ox_cart" else 0.5])
		for npc in _npcs:
			if is_instance_valid(npc) and npc.is_visible_in_tree() and not npc.has_meta("crowd_ignore"): # (Mind's port marks his node of a ported one)
				_world_others.append([npc, 0.4])
	out.append_array(_world_others)
	return out


func _exit_tree() -> void:
	for id: int in _sense_period:
		Think.forget(_think_owner(id))
	_sense_period.clear()
	for id: int in _carry_nodes:
		var carrier: Node3D=_carry_nodes[id].get_ref()
		if is_instance_valid(carrier) and int(carrier.get_meta("studio_people_load",-1))==id:
			carrier.remove_meta("studio_people_load")
	_carry_nodes.clear()
	# Only data belongs to VillageSession. This registry dies with its region scene.
	for runner: RefCounted in _elements.values():runner.stop()
	_elements.clear()
	_element_ticks.clear()
	_element_facts.clear()
	_element_dt.clear()
	_look_node.clear()
	_element_visible.clear()
	_expression_hints.clear()
	_expression_look.clear()
	borrowed.clear()



## ---- happenings: what the rules decided, played on the bodies (people/happening_runner.gd) ------------------------

## Starts any happening the rules have decided near the player (the director's quarrel, a meeting turned argument) and
## plays those going on; those over hand their people back to their day.
func _happenings(v, dt: float) -> void:
	var now := int(v.runtime.now)
	for h: Dictionary in View.happenings(v):
		var hid := int(h.id)
		if _run_tried.has(hid) or runs.has(hid) or int(h.ends) <= now:
			continue
		var meta: Dictionary = HappeningKinds.meta(str(h.kind))
		var first := int(h.phases[0][1])
		if now < first - int(meta.get("lead", 0)):
			continue                            # not yet: its cast set off a little before it begins
		var at := _happening_at(v, h)
		var near := _player != null and at.distance_to(player_xz()) <= float(meta.get("run_near", RUN_NEAR))
		if not near:
			if now >= first and not meta.get("late", false):
				_run_tried[hid] = true          # begun while the player was elsewhere: not played
			continue
		if meta.get("late", false) and now >= int(h.phases[h.phases.size() - 1][1]):
			_run_tried[hid] = true              # only its end is left
			continue
		_run_tried[hid] = true
		var run := HappeningRunner.new(h, _happening_director(v, at))
		if run.phase == "done":
			continue
		runs[hid] = run
		shown_happenings.append({"id": hid, "kind": str(h.kind), "at": at, "people": 2, "life": _life})
	for hid: int in runs.keys():
		var run: HappeningRunner = runs[hid]
		var over := run.update(dt)
		for shown: Dictionary in shown_happenings:
			if int(shown.id) == hid:
				shown.people = maxi(int(shown.people), run.people_seen)
		if over:
			runs.erase(hid)
	while shown_happenings.size() > 200:
		shown_happenings.pop_front()


func _happening_at(v, h: Dictionary) -> Vector2:
	var at: Array = h.get("at", [])
	if at.size() == 2:
		return Vector2(float(at[0]), float(at[1])) / 10.0
	return place(str(v.place_names[int(h.place)]))


## What a happening's runner asks of the village (people/happening_runner.gd).
func _happening_director(_v, at: Vector2) -> Dictionary:
	return {
		"mover": func(id: int) -> Mover: return _movers[id],
		"body": func(id: int) -> Node3D: return bodies[id],
		"claim": _happening_claim,
		"holds": func(id: int) -> bool: return owners.held(id, "happening"),
		"release": _happening_release,
		"clock": func() -> float: return float(VillageSession.village.runtime.now) + float(VillageSession.village.runtime.fraction),
		"at": at,
		"world": _world,
		"sees": _sees,
		"stimuli": stimuli,
		"watchers": _watchers,
		"out": _out_of_door,
		"say": _happening_say,
		"player": func() -> Vector2: return player_xz(),
		"end": func(h: Dictionary, ids: Array, where: Vector2) -> void:
			var path: Array = h.get("path", [])
			village_reactions.cue({"kind": "end:happening:%s:%s" % [str(h.kind), str(path.back()) if not path.is_empty() else ""],
				"subject": int(h.get("a", -1)), "other": int(h.get("b", -1)), "place": where, "who": ids}, ids),
	}


func _happening_claim(id: int, keep := false) -> bool:
	if not bodies.has(id) or _skip.has(id):
		return false
	var p = VillageSession.village.people[id]
	if not p.alive or not p.present or p.locked:
		return false
	if not owners.claim(id, "happening", BY_HAPPENING, _happening_lost, keep):
		return false
	owners.resumed["happening"] = _happening_resumed
	_applied.erase(id)
	return true


## Done with them: back to what they were doing (their stay, from where they stand), else planned afresh.
func _happening_release(id: int) -> void:
	release_to_day(id, "happening")


## `by` is done with them (a happening, a reaction): back to what they were doing (their stay, from where they stand),
## else planned afresh.
func release_to_day(id: int, by: String) -> void:
	if not owners.held(id, by):
		owners.release(id, by)               # (kept under someone higher: withdrawn; theirs to hand back to the day)
		return
	owners.release(id, by)
	if owners.owner(id) != "":
		return                               # (someone kept under them has them back)
	_applied.erase(id)
	var v = VillageSession.village
	if (_movers[id] as Mover).indoors and str(Runtime.routine(v, id).get("place", "")) != _who_of(v, id).home:
		_show(id, bodies[id], 0)             # gone in at their door, wanted elsewhere: out of it again, walked from there
	var stay: Activity.Stay = _stays.get(id)
	if stay != null and not _inside.get(id, false):
		stay.resume()
		return
	destinations.erase(id)
	_pick_minute.erase(id)


## Back from something higher, to a happening that keeps its cast (a town meeting): to their place in it - or, if it
## ended meanwhile, back to their day.
func _happening_resumed(id: int) -> void:
	for hid: int in runs:
		var run: HappeningRunner = runs[hid]
		if run.has(id):
			run.resume(id)
			return
	_happening_release(id)


## Someone higher took them (the talk, an answer, a scene): out of the happening (one of its two: over on the bodies).
func _happening_lost(id: int, _by: String) -> void:
	for hid: int in runs.keys():
		var run: HappeningRunner = runs[hid]
		if run.has(id):
			run.drop(id)


## Who may come to watch: free (or only in a meeting), grown or a bold child, near enough to hear it - indoors, the
## walls take most of it - nearest first. -> [[id, metres], ...]
func _watchers(at: Vector2, loud: float, most: int, those: Array, come := "bold") -> Array:
	var v = VillageSession.village
	var out: Array = []
	for id: int in bodies:
		if those.has(id) or _skip.has(id) or not owners.can_claim(id, BY_HAPPENING):
			continue
		var p = v.people[id]
		if not p.alive or not p.present or p.locked or p.down_until > int(v.runtime.now):
			continue
		var bold := float(p.traits[Rules.C.BOLD]) / 100.0
		var child: bool = _who_of(v, id).age_group == "child"
		if come == "all":
			bold = 1.0                       # the bell calls everyone grown (children come only if bold)
			if child and float(p.traits[Rules.C.BOLD]) < 50.0:
				continue
		if child and bold < 0.5:
			continue                         # the timid children stay away
		if bold < 0.2:
			continue
		var m: Mover = _movers[id]
		var hidden: bool = m.indoors or not (bodies[id] as Body).visible
		var reach := loud * (0.6 + 0.6 * bold) * (0.5 if hidden else 1.0)
		var d := m.pos.distance_to(at)
		if d <= reach:
			out.append([id, d])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[1] < y[1] or (x[1] == y[1] and x[0] < y[0]))
	return out.slice(0, most)


## Someone indoors comes out of their door to see (the runner asks as they set off).
func _out_of_door(id: int) -> void:
	var m: Mover = _movers[id]
	var body: Body = bodies[id]
	if not m.indoors and body.visible:
		return
	m.place(door_of(id), 0.0)
	m.indoors = false
	m.enters = false
	_inside[id] = false
	_show(id, body, 0)


func _happening_say(id: int, kind: String) -> void:
	if not bodies.has(id):
		return
	var text := Lines.bark(kind, id, hash([kind, int(VillageSession.village.runtime.now)]))
	if not text.is_empty():
		speech.say(bodies[id], text, Speech.SCENE, 7000000 + id, voice_of(id), 2.4)


## The society met two who dislike each other and would have them quarrel: the rules decide (sim/happenings.gd, through
## the request path): an argument, played by a runner; else, they keep clear of each other.
func _instead(name: String, a: int, b: int, _k: int) -> String:
	if name != "quarrel":
		return name
	var v = VillageSession.village
	var middle: Vector2 = ((_movers[a] as Mover).pos + (_movers[b] as Mover).pos) * 0.5
	var near: Array = []
	for id: int in bodies:
		if id != a and id != b and (bodies[id] as Body).visible and (_movers[id] as Mover).pos.distance_to(middle) <= ARGUE_NEAR:
			near.append(id)
	var req := {"action_id": "argue:%d:%d:%d" % [a, b, int(v.runtime.now)], "player_id": "player:local",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "verb": "argue", "target": a,
		"parameters": {"other": b, "at": [int(round(middle.x * 10.0)), int(round(middle.y * 10.0))], "near": near}}
	# One checked batch (merge-enea, 6 Oct): the quarrel writes the runtime, the chronicle and both people, so it goes
	# through the people's checked door like any act, never straight onto the live village.
	if people_bridge == null or not people_bridge.available():
		return "keep_clear"
	var result: Dictionary = people_bridge.accept(func(candidate) -> Dictionary:
		VillageImage.touch_person(-1) # the rules' quarrel may change anyone
		return WorldActions.act(candidate, req, {"distance_dm": 0}))
	if result.get("accepted", false):
		return ""                            # the runner takes them (next frame, _happenings)
	return "keep_clear"


## The player taps one of two arguing: they step between them (the rules decide what that does). true: the tap was
## that (no talk screen opens); false: an ordinary talk.
func step_in(id: int, player: Node3D) -> bool:
	for hid: int in runs:
		var run: HappeningRunner = runs[hid]
		if str(run.record.kind) != "argument" or (int(run.record.a) != id and int(run.record.b) != id):
			continue
		if run.phase not in ["coming", "words", "heated"]:
			return false
		var result := PlayerActs.request(player, self, "step_in", id, {"happening": hid})
		if result.get("accepted", false):
			get_tree().call_group("hud", "hint", "You step between them.")
			_happening_say(int(run.record.a), "parted_by_you")
		else:
			get_tree().call_group("hud", "hint", "Too far to step in." if str(result.get("reason", "")) == "out of reach" else "They will not hear it.")
		return true
	return false

extends RefCounted
## The village's state as small typed classes. The reference builds these as object literals (createVillage
## and addPerson in village.mjs, addCrime and giveBelief in crime.mjs, logEvent in events.mjs, the schedule
## items in village.mjs, director.mjs and justice.mjs); here each shape is a class, because GDScript
## Dictionary access is slow on a 2019 phone. Field names follow the reference in snake_case.
##
## JS "undefined" conventions used by the port (each is never a real value of that field):
## - ids, event ids, case ids, place ids: -1 means undefined (every real one is >= 0);
## - Person.locked_at -1: not set (the reference reads `lockedAt ?? "pillory"`).
##
## Places are interned: a place is an int id into Village.place_names (built from the layout in
## create_village), so plans and sightings compare ints. The staging and event data still carry the names.


class Belief:
	var crime := 0
	var culprit := 0
	var strength := 0
	var origin := 0
	var via := 0
	var from := -1
	var day := 0
	var event := -1   # undefined until a rumour event is logged for it


class Person:
	var id := 0
	var name := ""
	var lineage := -1
	var household := -1
	var sex := 0
	var born := 0
	var alive := true
	var died := -1
	var death_cause := ""
	var present := true
	var cleared_day := -1
	var role := "child"
	var era := 0
	var traits := PackedInt32Array()
	var values := PackedInt32Array()   # tradition, faith, law, mercy (content.gd V_*)
	var hunger := 0
	var stress := 0
	var guilt := 0
	var offences := 0
	var spouse := -1
	var father := -1
	var mother := -1
	# rel: Map(person -> opinion), insertion ordered (the order matters: it is iterated). Two parallel
	# arrays; Array (not Packed) so writes through a Person reference change it in place.
	var rel_k: Array[int] = []
	var rel_v: Array[int] = []
	var rel_abs: Array[int] = []   # (port) |rel_v|, kept alongside so the weakest feeling is found natively
	# grudges: Map(person -> event), insertion ordered, at most 4
	var grudge_k: Array[int] = []
	var grudge_v: Array[int] = []
	var beliefs: Array[Belief] = []
	var marks := {}   # name -> count, insertion ordered ("pilloried", "branded")
	var epithets := PackedStringArray()
	var epithet_log := []   # [[epithet, day]]
	var plan := PackedInt32Array()   # [from, to, place] triples
	var locked := false
	var locked_at := -1
	var secret: Array[int] = []
	var outsider := false
	var eaten := false
	var exiled_for := -1
	var exiled_day := -1
	# time storms (storm.gd): the storm an ancestor came with, the storm a villager is lost in (-1: none)
	var ancestor := -1
	var lost_to_storm := -1
	var faded := false


class Household:
	var id := 0
	var lineage := 0
	var home := ""
	var home_place := -1   # (port) the interned place id of home
	var members := PackedInt32Array()
	var food := 40
	var geese := 0


class Lineage:
	var id := 0
	var name := ""
	var age := 0
	var feuds := {}          # lineage -> sum of shame
	var feud_logged := {}    # lineage -> 1 (the reference keeps these as "_logged" + b inside feuds)
	var deeds := []
	var past_names := PackedStringArray()
	var outsider := false


class Crime:
	var id := 0
	var act := ""
	var culprit := -1
	var household := -1
	var victim := -1
	var day := 0
	var minute := 0
	var place := -1   # place id
	var item := ""
	var discovered := false
	var closed := false
	var witnesses: Array[int] = []
	var trace_at := -1   # place id; -1 is the reference's ""
	var false_accusation := false
	var event := -1
	var discovery_event := -1
	var death_event := -1
	var case_open := false
	var punished := -1
	var punish_event := -1
	var wrongful_punishment := false
	var exonerated := false
	var reopen_day := -1   # set when a confession reopens it (-1: undefined, the cold-case clock runs from day)


class Case:
	var id := 0
	var crime := 0
	var accuser := -1
	var accused := -1
	var evidence := 0
	var event := -1
	var day := 0


class Event:
	var id := 0
	var day := 0
	var type := ""
	var who := -1
	var other := -1
	var data := {}
	var causes := PackedInt32Array()
	var cue := ""


## A schedule item. The reference's items carry different fields per kind; absent ones keep these defaults.
class Sched:
	var day := 0
	var kind := ""
	var case_id := -1   # s.case (-1: undefined)
	var who := -1
	var other := -1
	var name := ""
	var act := ""
	var causes := PackedInt32Array()
	var minute := -1
	var confessed := false
	var vetoed := false
	var hold := false
	var waited := 0
	var storm := -1   # a rite's storm
	var seq := 0   # (port) position in today's list, the sort's final tie-break

	func copy() -> Sched:
		var s := Sched.new()
		s.day = day; s.kind = kind; s.case_id = case_id; s.who = who; s.other = other; s.name = name
		s.act = act; s.causes = causes; s.minute = minute; s.confessed = confessed; s.vetoed = vetoed
		s.hold = hold; s.waited = waited; s.storm = storm
		return s


## A public act made and staged, waiting to be applied (justice.gd public_act, resolve_public, apply_public).
## In the live village it waits in V.pending for the stage; headless it is applied at once.
class PublicAct:
	var cue := ""
	var s: Sched = null
	var cs := 0   # case id
	var kind := ""
	var victim := -1
	var attend: Array[int] = []
	var anger := {}   # person -> anger, insertion ordered
	var sympathy := {}   # person -> sympathy
	var throwing: Array[int] = []
	var level := 0
	var outcome := ""
	var lethal_by_stones := false
	var n := 0
	var causes := PackedInt32Array()
	var staging := -1   # staging id


## How the village remembers the player (a stranger, id -2 in events).
class Stranger:
	var standing := 0
	var enemies: Array[int] = []


## A time storm (storm.gd).
class Storm:
	var id := 0
	var household := 0
	var from := 0
	var until := 0
	var lost: Array[int] = []
	var ancestors: Array[int] = []
	var event := -1
	var active := true
	var offered := false


class Director:
	var on := false
	var until := 0
	var lethal := 0
	var cooldown := 0
	var last := PackedStringArray()
	var cycles := 0
	var last_act := 0   # the day of the last public act (note_act)
	var pressure := 0   # days past the focus gap (director.gd focus_day)


class Village:
	# Versioned action/clock state. Empty for historical chronicle/conformance runs.
	var runtime := {}
	var seed := 0
	var base := 0
	var day := 0
	var age := 1
	var pace := 1
	var tier := "private"
	var name := "Wenbrook"
	# the layout, interned (village.gd make_places)
	var homes := PackedStringArray()
	var place_names := PackedStringArray()
	var place_ids := {}   # name -> id
	var place_x := PackedInt32Array()
	var place_z := PackedInt32Array()
	var place_has_pos := PackedByteArray()
	var place_pen := PackedByteArray()   # the name starts with "pen"
	var place_rank := PackedInt32Array()   # position of the name in string order
	var dist2 := PackedInt32Array()   # squared distance between places, n x n
	var n_places := 0
	var pl_square := -1
	var pl_shrine := -1
	var pl_pillory := -1
	var pl_home_word := -1   # the literal place "home" (absent from the meadow layout)
	var pl_far_woods := -1
	var pl_road := -1
	var pl_woods := -1
	var pl_well := -1
	var role_work := {}   # role -> its work place id (-1: "home")
	var people: Array[Person] = []
	var households: Array[Household] = []
	var lineages: Array[Lineage] = []
	var authority := -1
	var priest := -1
	var hardship := 0
	var fear := 0
	var harvest := 100
	var events: Array[Event] = []
	var ev_hash := 2166136261
	var crimes: Array[Crime] = []
	var cases: Array[Case] = []
	var schedule: Array[Sched] = []
	var stagings: Array[Dictionary] = []
	var staging_count := 0
	var outlaws: Array[int] = []
	var shrines := []
	var director := Director.new()
	var stats := {"crimes": 0, "cases": 0, "trials": 0, "acts": {}, "outcomes": {}, "deaths": 0, "violentDeaths": 0,
		"births": 0, "famines": 0, "omens": 0, "festivals": 0, "exonerations": 0, "mobs": 0}
	var culture := {}
	var lang := PackedInt32Array()   # (port) content.gd LANG_DISTANCE flattened: [speaker era * 3 + listener era]
	var omen_event := -1
	# time storms (storm.gd): an anchored story village is exempt; storm_plan is the kernel's stand-in for tests,
	# [day, household, days] triples
	var storms: Array[Storm] = []
	var storm_plan := PackedInt32Array()
	var anchored := false
	# the live game (live.gd): public acts wait on the stage for the player (justice.gd resolve_public)
	var live := false
	var pending: Array[PublicAct] = []
	var stranger := Stranger.new()
	# focus: this is the village the player is in (the live game's director paces it by play time, director.gd)
	var focus := false

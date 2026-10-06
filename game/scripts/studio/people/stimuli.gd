extends RefCounted
## What draws attention (the people architecture's P1, the stimulus door; plan VILLAGE-LIFE-AND-NEWS section 5, #5):
## a shout, a scream, the bell, a blow, someone running. One record for every sound worth turning to, given off by
## anything through one call; whoever listens - an onlooker deciding to come and look, the player's edge cues, the news
## - asks what carries to where they are. Generic: points on the ground, loudness and time, not villages.
##
##   var stimuli := Stimuli.new()
##   stimuli.emit(kind, at, loud, source := -1, seconds := 2.0, data := {}) -> int    an id
##       at     Vector2 on the ground
##       loud   metres it carries in the open (a word 4, raised voices 18, a shout 28, a scream 40, the bell 120)
##   stimuli.update(dt)                          time passes; those over are forgotten
##   stimuli.heard(at, hearing := 1.0) -> Array  those that carry to `at`, the strongest there first
##   stimuli.near(at, radius) -> Array           those given off within `radius` of `at`, however quiet
##   stimuli.carry(s, at, hearing := 1.0) -> float   how strongly `s` reaches `at`: 1 at the source, 0 at its edge
##   stimuli.muffle = func(a, b) -> float        optional: what lies between two points lets this share through
##                                               (1 open air; the village's walls: a house between, about half)
##   stimuli.all                                 those going on (a record: {id, kind, at, loud, source, born, until, data})
##   stimuli.given                               every one given off so far (a count, for measures)

var all: Array = []
var muffle := Callable()
var given := 0
var _life := 0.0
var _next := 1
const Modules := preload("res://scripts/studio/people/modules.gd")
signal accepted_event(record: Dictionary)
## A source's declarative NOTICE is validated here; the bridge validates root/fact/revision/geometry.
func notice(source_id: String, folder := "res://scripts/studio/people/sources/") -> Dictionary:
	var sources := Modules.discover(folder)
	if not sources.has(source_id):return {}
	var row: Dictionary=sources[source_id].get_script_constant_map().get("NOTICE",{}).duplicate(true)
	if not row.get("facts") is Array or row.facts.is_empty():return {}
	for kind: Variant in row.facts:
		if not kind is String or str(kind).is_empty():return {}
	return {"facts":row.facts.duplicate(),"transition":bool(row.get("transition",false)),
		"posture":str(row.get("posture","")),"persistent":bool(row.get("persistent",false))}

## P1 make(source_id,actor,subject,at metres,fields,folder?)->normalised record or {}.
## {kind,source emitter,actor alleged doer or "",subject,target,at,reach metres,strength 0..1000,
## window_ms,features,evidence,heard,hearing_reach?}. Source truth is private to live sensing.
## One module file/ID through normal discovery; make is pure. P2 exclusively bounds observed accounts.
## publish(record) requires an accepted opaque deed and follows ONE checked save; it never saves.
## Legacy emit/heard/near is transient sound presentation, with no action/fact/choice authority.
func make(source_id: String, actor: String, target: String, at: Array, fields: Dictionary, folder := "res://scripts/studio/people/sources/") -> Dictionary:
	var sources := Modules.discover(folder)
	if not sources.has(source_id) or at.size()!=2 or not is_finite(float(at[0])) or not is_finite(float(at[1])):
		return {}
	var row: Dictionary=sources[source_id].new().make(actor,target,at,fields)
	if row.is_empty() or str(row.get("kind","")).is_empty() or not is_finite(float(row.get("reach",0))) or float(row.get("reach",0))<0:
		return {}
	row.actor=str(row.get("actor",row.get("source",actor)))
	row.source=str(row.get("source",actor))
	row.subject=str(row.get("subject",row.get("target",target)))
	row.target=row.subject
	row.at=at.duplicate()
	row.strength=clampi(int(row.get("strength",1000)),0,1000)
	row.window_ms=clampi(int(row.get("window_ms",600)),1,30000)
	row.features=(row.get("features",{}) as Dictionary).duplicate(true)
	row.evidence=(row.get("evidence",{}) as Dictionary).duplicate(true)
	row.heard=(row.get("heard",{}) as Dictionary).duplicate(true)
	return row
func publish(record: Dictionary) -> void:
	if str(record.get("deed","")).is_empty():
		push_error("people stimulus publication needs an accepted deed")
		return
	accepted_event.emit(record.duplicate(true))


func emit(kind: String, at: Vector2, loud: float, source := -1, seconds := 2.0, data := {}) -> int:
	var s := {"id": _next, "kind": kind, "at": at, "loud": loud, "source": source, "born": _life, "until": _life + seconds,
		"data": data}
	_next += 1
	given += 1
	all.append(s)
	return int(s.id)


func update(dt: float) -> void:
	_life += dt
	for i in range(all.size() - 1, -1, -1):
		if float(all[i].until) <= _life:
			all.remove_at(i)


func carry(s: Dictionary, at: Vector2, hearing := 1.0) -> float:
	var reach := float(s.loud) * hearing
	if muffle.is_valid():
		reach *= float(muffle.call(s.at, at))
	if reach <= 0.0:
		return 0.0
	return clampf(1.0 - (s.at as Vector2).distance_to(at) / reach, 0.0, 1.0)


func heard(at: Vector2, hearing := 1.0) -> Array:
	var out: Array = []
	for s: Dictionary in all:
		var c := carry(s, at, hearing)
		if c > 0.0:
			out.append([c, s])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] or (x[0] == y[0] and int(x[1].id) < int(y[1].id)))
	return out.map(func(x: Array) -> Dictionary: return x[1])


func near(at: Vector2, radius: float) -> Array:
	return all.filter(func(s: Dictionary) -> bool: return (s.at as Vector2).distance_to(at) <= radius)


func life() -> float:
	return _life

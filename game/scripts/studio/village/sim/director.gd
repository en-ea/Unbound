extends RefCounted
## Port of tools-src/studio/village-reference/director.mjs.
## The pacing director (RimWorld's storyteller): the village alternates quiet and eventful cycles of keyed
## length. Blood is rationed (at most one lethal public act per eventful cycle, and a cooldown after any
## killing); quiet cycles carry festivals; omens arrive rarely, likelier in hard times, and raise the fear
## that finds scapegoats. The director never forces an act: it only permits, withholds and paces.

const R := preload("res://scripts/studio/village/sim/rng.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")

const FEASTS := {22: "Midsummer", 44: "Harvest Home", 57: "Midwinter"}


static func director_day(V: S.Village) -> void:
	var d := V.director
	var k := R.key(R.key(V.base, Village.P_CYCLE), V.day)
	if V.day >= d.until:
		d.on = not d.on
		d.until = V.day + (12 + R.pick(k, 10) if d.on else 25 + R.pick(R.key(k, 1), 20))
		d.lethal = 0
		d.cycles += 1
	var doy := V.day % Village.YEAR
	if FEASTS.has(doy):
		var s := S.Sched.new()
		s.day = V.day; s.kind = "festival"; s.name = FEASTS[doy]; s.who = -1; s.other = -1
		V.schedule.append(s)
	# omens: rare; hardship makes them likelier (a hungry village reads signs everywhere)
	if R.chance(R.key(k, 2), (2200 + R.idiv(V.hardship, 2) * 8) * V.pace):
		var omen: String = C.OMENS[R.pick(R.key(k, 3), C.OMENS.size())]
		V.fear = clampi(V.fear + 460, 0, 1000)
		V.stats["omens"] += 1
		V.omen_event = E.log_event(V, "omen", -1, -1, {"omen": omen}, PackedInt32Array(), omen)


static func lethal_allowed(V: S.Village) -> bool:
	return V.director.on and V.director.lethal < 1 and V.day >= V.director.cooldown


static func note_act(V: S.Village, kind: String) -> void:
	var d := V.director
	d.last.append(kind)
	if d.last.size() > 5:
		d.last.remove_at(0)
	if C.PUBLIC.has(kind) and C.PUBLIC[kind]["lethal"]:
		d.lethal += 1
		d.cooldown = V.day + 15

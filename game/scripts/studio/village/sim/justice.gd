extends RefCounted
## Port of tools-src/studio/village-reference/justice.mjs.
## Justice: trials (witnesses, the confession trade, ordeals, trial by combat), the law choosing a public
## act, the director's veto on bloodshed, the crowd as a threshold cascade (Granovetter) that decides how
## far pelting goes and whether the crowd turns, the aftermath (marks, exile, feuds, funerals), the guilty
## conscience that can make a saint of the wrongly hanged, and the stagings the stage plays.

const R := preload("res://scripts/studio/village/sim/rng.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Crime := preload("res://scripts/studio/village/sim/crime.gd")
const Director := preload("res://scripts/studio/village/sim/director.gd")
const Storm := preload("res://scripts/studio/village/sim/storm.gd")


static func authority_capacity(V: S.Village) -> int:
	if V.authority < 0:
		return 0
	var e := V.people[V.authority]
	if not e.alive or not e.present:
		return 0
	var sum := 0
	var n := 0
	for q in V.people:
		if not q.alive or not q.present or q.id == e.id or Village.age_of(V, q) < 16:
			continue
		sum += Village.opinion(V, q.id, e.id)
		n += 1
	var respect := R.idiv(sum * 10 + 1000 * n, 2 * n) if n > 0 else 500  # opinion -100..100 -> 0..1000
	return clampi(R.idiv(respect * 3 + e.traits[C.BOLD] * 10, 4), 0, 1000)


static func schedule_trial(V: S.Village, cs: S.Case) -> void:
	var s := S.Sched.new()
	s.day = V.day + 1; s.kind = "trial"; s.case_id = cs.id; s.causes = PackedInt32Array([cs.event])
	V.schedule.append(s)


static func schedule_mob(V: S.Village, cs: S.Case) -> void:
	V.stats["mobs"] += 1
	var s := S.Sched.new()
	s.day = V.day; s.kind = "public"; s.act = "mob"; s.case_id = cs.id; s.causes = PackedInt32Array([cs.event]); s.minute = 1200
	V.schedule.append(s)


# ---------- today's scheduled events ----------
const ORDER := ["unlock", "funeral", "trial", "public", "wedding", "festival", "rite"]  # (a "return" is not listed: it sorts first, index -1)


static func run_scheduled(V: S.Village) -> void:
	# due today or overdue (a mob raised after today's schedule ran gathers the next day)
	var today: Array[S.Sched] = []
	var later: Array[S.Sched] = []
	for s in V.schedule:
		if s.day <= V.day:
			today.append(s)
		else:
			later.append(s)
	V.schedule = later
	# (the final tie-break is the order they were scheduled in: ports must not rely on a stable sort)
	for i in today.size():
		today[i].seq = i
	today.sort_custom(func(a: S.Sched, b: S.Sched) -> bool: return _schedule_before(a, b))
	for s in today:
		if s.kind == "trial":
			trial(V, s)
		elif s.kind == "public":
			public_act(V, s)
		elif s.kind == "funeral":
			funeral(V, s)
		elif s.kind == "wedding":
			gathering(V, "wedding", s)
		elif s.kind == "festival":
			gathering(V, "festival", s)
		elif s.kind == "unlock":
			V.people[s.who].locked = false
		elif s.kind == "return":
			come_home(V, s)
		elif s.kind == "rite":
			Storm.rite_act(V, s)


## ORDER.indexOf(kind) (-1 for an unlisted kind: a "return" sorts first), then (case ?? who ?? 0), then the
## order scheduled.
static func _schedule_before(a: S.Sched, b: S.Sched) -> bool:
	var oa := ORDER.find(a.kind)
	var ob := ORDER.find(b.kind)
	if oa != ob:
		return oa < ob
	var ka := a.case_id if a.case_id >= 0 else a.who
	var kb := b.case_id if b.case_id >= 0 else b.who
	if ka != kb:
		return ka < kb
	return a.seq < b.seq


# ---------- the trial ----------
static func trial(V: S.Village, s: S.Sched) -> void:
	var cs := V.cases[s.case_id]
	var c := V.crimes[cs.crime]
	var accused := V.people[cs.accused]
	if not accused.alive or not accused.present:
		c.closed = true
		return
	var k := R.key(R.key(V.base, Village.P_TRIAL), cs.id)
	V.stats["trials"] += 1
	var guilty := cs.accused == c.culprit and not c.false_accusation
	var judge := V.authority if V.authority != cs.accused else (V.priest if V.priest != cs.accused else -1)
	var bench := "priest" if judge >= 0 and judge == V.priest and judge != V.authority else "elder"
	var trial_ev := E.log_event(V, "trial", judge, cs.accused, {"case": cs.id, "act": c.act, "bench": bench}, PackedInt32Array([cs.event]), "the %s's bench carried into the square" % bench)
	var causes := PackedInt32Array([trial_ev])
	var verdict := "guilty"
	var confessed := false
	var via := "witnesses"
	# the confession trade (Salem): confess and be spared the worst; the guilty and the terrified confess
	var pressure := R.idiv(cs.evidence, 20) + R.idiv(V.fear, 20)
	var confess_odds := 0
	if guilty:
		confess_odds = (accused.traits[C.HONESTY] + accused.traits[C.PIETY]) * 1500 + pressure * 2000
	elif V.fear > 600 and accused.traits[C.BOLD] < 30:
		confess_odds = (100 - accused.traits[C.BOLD]) * 1200
	if R.chance(R.key(k, 1), confess_odds):
		confessed = true; via = "confession"
		causes.append(E.log_event(V, "confession", cs.accused, V.authority, {"case": cs.id, "true": guilty}, PackedInt32Array([trial_ev]),
			"%s on their knees before the elder" % E.name_of(V, cs.accused)))
		earn(V, cs.accused, "confessed")
	elif V.age == C.VILLAGE and (c.act == "sorcery" or cs.evidence < 1000) and c.act != "murder":
		# the ordeal: the millpond. Most who went in came out 'innocent' (Várad: 62.5%)
		via = "ordeal"
		var acquit := R.chance(R.key(k, 2), 600000)
		causes.append(E.log_event(V, "ordeal", cs.accused, V.authority, {"case": cs.id, "acquit": acquit}, PackedInt32Array([trial_ev]),
			"%s sinking, then hauled out: innocent" % E.name_of(V, cs.accused) if acquit else "%s floating on the millpond: guilty" % E.name_of(V, cs.accused)))
		if acquit:
			verdict = "acquitted"
	elif V.age == C.VILLAGE and c.act == "murder" and accused.traits[C.BOLD] >= 60:
		# trial by combat: the accused against the accuser's champion (the player can be a champion)
		via = "combat"
		var champ := champion(V, cs.accuser, cs.accused)
		var won := _might(V, k, cs.accused) > _might(V, k, champ)
		causes.append(E.log_event(V, "ordeal", cs.accused, champ, {"case": cs.id, "combat": true, "won": won}, PackedInt32Array([trial_ev]),
			"steel in the square: %s against %s" % [E.name_of(V, cs.accused), E.name_of(V, champ)]))
		if won:
			verdict = "acquitted"
		else:
			Director.note_act(V, "trial_by_combat")
			finish_case(V, cs, c, "trial_by_combat", "carried_out", causes, false)
			Village.die(V, cs.accused, "combat", causes, "a body carried from the ring")
			earn(V, champ, "champion")
			return
	else:
		# judged on the witnesses: a law-minded elder needs more
		var law := V.people[judge].values[C.V_LAW] if judge >= 0 and judge < V.people.size() else 60
		var need := 500 + law * 8
		if cs.evidence < need:
			verdict = "acquitted"
	if verdict == "acquitted":
		var outcomes: Dictionary = V.stats["outcomes"]
		outcomes["acquitted"] = outcomes.get("acquitted", 0) + 1
		E.log_event(V, "verdict", V.authority, cs.accused, {"case": cs.id, "verdict": verdict, "via": via}, causes, "%s walking free, the accuser staring after" % E.name_of(V, cs.accused))
		Village.set_opinion(V, cs.accused, cs.accuser, Village.opinion(V, cs.accused, cs.accuser) - 40)
		c.closed = true
		return
	# the law's list for this act and age, lenient to harsh
	var list: Array = C.LAW[c.act][V.age]
	if list.size() == 0:
		c.closed = true
		return
	var mercy := V.people[V.authority].values[C.V_MERCY] if V.authority >= 0 else 40
	var idx := R.idiv(int(C.ACTS[c.act]["severity"]), 3) + accused.offences + R.idiv(V.hardship + V.fear, 450) - R.idiv(mercy, 45) - (1 if confessed else 0)
	idx = clampi(idx, 0, list.size() - 1)
	var act: String = list[idx]
	# variety (no act twice in a row) and the director's veto on blood
	var last := V.director.last
	if last.size() > 0 and last[last.size() - 1] == act and idx > 0 and R.chance(R.key(k, 9), 500000):
		idx -= 1
		act = list[idx]
	var vetoed := false
	var asked := act
	# the gravest crimes are not commuted for pacing: the condemned is held until the director allows blood
	var hold: bool = C.PUBLIC[act]["lethal"] and int(C.ACTS[c.act]["severity"]) >= 8
	while not hold and C.PUBLIC[act]["lethal"] and not Director.lethal_allowed(V) and idx > 0:
		idx -= 1
		act = list[idx]
		vetoed = true
	if not hold and C.PUBLIC[act]["lethal"] and not Director.lethal_allowed(V):
		act = "exile"; vetoed = true
	var v_ev := E.log_event(V, "verdict", V.authority, cs.accused, {"case": cs.id, "verdict": verdict, "via": via, "act": act, "vetoed": vetoed, "asked": asked if vetoed else ""}, causes,
		"the elder, weary of blood, names a lesser sentence" if vetoed else "the elder naming the sentence: %s" % _replace_first(act, "_", " "))
	if vetoed:
		earn(V, V.authority, "merciful")
	accused.offences += 1
	# a kinsman may try a rescue the night before a killing (headless stand-in for the player's rescue window)
	var p := S.Sched.new()
	p.day = V.day + 1; p.kind = "public"; p.act = act; p.case_id = cs.id; p.causes = PackedInt32Array([v_ev])
	p.confessed = confessed; p.vetoed = vetoed; p.hold = hold; p.waited = 0
	V.schedule.append(p)
	if hold:
		accused.locked = true
		accused.locked_at = V.pl_pillory


static func _might(V: S.Village, k: int, id: int) -> int:
	var q := V.people[id]
	var strong: bool = C.ROLES[q.role]["strong"] if C.ROLES.has(q.role) else false
	return q.traits[C.BOLD] + (40 if strong else 0) + R.pick(R.key(k, 3 + id), 60)


## JS String.replace with a string pattern replaces the first match only.
static func _replace_first(s: String, what: String, with: String) -> String:
	var i := s.find(what)
	return s if i < 0 else s.substr(0, i) + with + s.substr(i + what.length())


static func champion(V: S.Village, accuser: int, accused: int) -> int:
	var best := accuser
	var s := -1
	for q in V.people:
		if not q.alive or not q.present or q.id == accused or not Village.is_kin(V, q.id, accuser) or Village.age_of(V, q) < 18:
			continue
		var strong: bool = C.ROLES[q.role]["strong"] if C.ROLES.has(q.role) else false
		var m := q.traits[C.BOLD] + (40 if strong else 0)
		if m > s:
			s = m; best = q.id
	return best


# close kin: household, spouse, parents and children, siblings (not the whole lineage)
static func close_kin(V: S.Village, a: int, b: int) -> bool:
	var pa := V.people[a]
	var pb := V.people[b]
	return pa.household == pb.household or pa.spouse == b or pa.father == b or pa.mother == b or pb.father == a or pb.mother == a \
		or (pa.father >= 0 and pa.father == pb.father) or (pa.mother >= 0 and pa.mother == pb.mother)


# a grudge remembers the event that made it (the tales follow it; revenge cites it); at most 4 kept
static func remember(p: S.Person, o: int, ev: int) -> void:
	var i := p.grudge_k.find(o)
	if i >= 0:
		p.grudge_k.remove_at(i)
		p.grudge_v.remove_at(i)
	p.grudge_k.append(o)
	p.grudge_v.append(ev)
	if p.grudge_k.size() > 4:
		p.grudge_k.remove_at(0)
		p.grudge_v.remove_at(0)


# ---------- the public act and its crowd ----------
const THROWING_KINDS := ["pillory", "stocks", "stoning", "mob", "exile", "branding", "scapegoat"]
const KILLING := {"hanging": "hanged", "bonfire": "burned", "stoning": "stoned", "mob": "stoned", "sacrifice": "sacrificed"}
const ANGER_BY_RATING := [-200, -100, 0, 120, 280, 450]


static func public_act(V: S.Village, s: S.Sched) -> void:
	var cs := V.cases[s.case_id]
	var c := V.crimes[cs.crime]
	var victim := V.people[cs.accused]
	var kind := s.act
	if not victim.alive or not victim.present:
		c.closed = true
		return
	# held for the day the director allows (at most two months; then the sentence is commuted to exile)
	if s.hold and C.PUBLIC[kind]["lethal"] and not Director.lethal_allowed(V):
		if s.waited < 60:
			var again := s.copy()
			again.day = V.day + 1
			again.waited = s.waited + 1
			V.schedule.append(again)
			return
		var commuted := s.copy()
		commuted.act = "exile"; commuted.vetoed = true; commuted.hold = false
		public_act(V, commuted)
		return
	if s.hold:
		victim.locked = false
	var k := R.key(R.key(V.base, Village.P_CROWD), cs.id * 31 + V.day)
	var def: Dictionary = C.PUBLIC[kind]
	var lethal: bool = def["lethal"]
	var causes := s.causes
	# a kinsman's rescue by night before a killing (the player's window, taken by the simulation when no
	# player is there): bold, loving kin try it sometimes
	if (lethal or kind == "branding") and kind != "mob":
		for q in V.people:
			if not q.alive or not q.present or not Village.is_kin(V, q.id, victim.id) or q.id == victim.id or Village.age_of(V, q) < 16:
				continue
			var nerve := q.traits[C.BOLD] + q.traits[C.COMPASSION] - 85
			if nerve > 0 and R.chance(R.key(k, 700 + q.id), nerve * (6000 if close_kin(V, q.id, victim.id) else 2500)):
				var ev := E.log_event(V, "public_act", victim.id, q.id, {"kind": kind, "outcome": "rescued", "case": cs.id}, causes,
					"an empty cell at dawn, a rope cut, %s missing from their bed" % E.name_of(V, q.id))
				earn(V, q.id, "rescuer")
				exile(V, victim.id, PackedInt32Array([ev]), true, c.id)
				finish_case(V, cs, c, kind, "rescued", PackedInt32Array([ev]), false)
				return
	# the crowd: everyone old enough comes, except kin who cannot bear to watch
	var attend: Array[int] = []
	for q in V.people:
		if not q.alive or not q.present or q.id == victim.id or q.locked:
			continue
		if V.tier == "store" and Village.age_of(V, q) < 12 and lethal:
			continue
		if Village.is_kin(V, q.id, victim.id) and q.traits[C.COMPASSION] > 70:
			continue
		attend.append(q.id)
	var n := attend.size()
	var anger := {}
	var sympathy := {}
	var severity: int = C.ACTS[c.act]["severity"]
	var norms: Array = C.ACTS[c.act]["norms"]
	var shame_def: int = def["shame"]
	for id in attend:
		var q := V.people[id]
		var rating: int = norms[q.era]
		var o := Village.opinion(V, id, victim.id)
		var a: int = ANGER_BY_RATING[rating] + maxi(0, -o) * 3 + R.idiv(V.hardship + V.fear, 6) + q.traits[C.TEMPER]
		var sy := maxi(0, o) * 4 + q.traits[C.COMPASSION] * 2 + (500 if Village.is_kin(V, id, victim.id) else 0) + (150 if cs.evidence < 1000 else 0)
		if q.secret.has(c.id):
			sy += 400  # the real culprit, watching someone else pay
		sy += maxi(0, shame_def * 50 - severity * 70)  # too much for too little (a brand for a goose)
		if victim.cleared_day >= 0:
			sy += 150  # wronged once before
		if not s.confessed and cs.evidence < 1200:
			sy += 120  # they never admitted it, and the case was thin
		if Village.is_kin(V, id, cs.accuser):
			a += 150
		anger[id] = a
		sympathy[id] = sy
	var total_a := 0
	var total_s := 0
	for id in attend:
		total_a += anger[id]
		total_s += sympathy[id]
	var turned := n > 0 and total_s * 10 > total_a * 11 and not (kind == "mob" and V.fear > 800)
	# the cascade: each joins once enough others already throw (threshold from their own balance)
	# (children watch, but never throw)
	var wants: Array[int] = []
	for id in attend:
		if anger[id] > sympathy[id] and Village.age_of(V, V.people[id]) >= 14:
			wants.append(id)
	var thr := {}
	for id in wants:
		thr[id] = clampi(R.idiv((int(sympathy[id]) - int(anger[id]) + 700) * n, 1400), 0, n)
	var throwing: Array[int] = []
	for _round in n + 1:
		var next: Array[int] = []
		for id in wants:
			if thr[id] <= throwing.size():
				next.append(id)
		if next.size() == throwing.size():
			break
		throwing = next
	var mean_a := R.idiv(total_a, n) if n > 0 else 0
	var level := 0
	if throwing.size() == 0:
		level = 0
	elif throwing.size() * 100 >= 50 * n and mean_a > 550:
		level = 3
	elif throwing.size() * 100 >= 30 * n and mean_a > 350:
		level = 2
	else:
		level = 1
	if not THROWING_KINDS.has(kind) and level > 1:
		level = 1
	# outcome
	# the ending: the crowd can turn; a confession or the director's veto is a spared or commuted ending
	var outcome := "confessed_spared" if s.confessed else ("commuted" if s.vetoed else "carried_out")
	if turned and kind != "fine":
		outcome = "crowd_turned"
	var lethal_by_stones := (kind == "pillory" or kind == "stocks") and level == 3 and Director.lethal_allowed(V) and R.chance(R.key(k, 5), 250000)
	var staging := make_staging(V, cs, c, kind, attend, throwing, level, outcome, lethal_by_stones, anger, sympathy, k)
	var ev := E.log_event(V, "public_act", victim.id, cs.accuser, {"kind": kind, "outcome": outcome, "case": cs.id, "level": level, "throwers": throwing.size(), "crowd": n, "staging": staging["id"]},
		causes, staging["cue"])
	var acts: Dictionary = V.stats["acts"]
	acts[kind] = acts.get(kind, 0) + 1
	var outcomes: Dictionary = V.stats["outcomes"]
	outcomes[outcome] = outcomes.get(outcome, 0) + 1
	Director.note_act(V, kind)
	if throwing.size() > 0 and (lethal or lethal_by_stones):
		earn(V, throwing[0], "mob_leader")
	if outcome == "crowd_turned":
		E.log_event(V, "crowd_turned", victim.id, cs.accuser, {"case": cs.id}, PackedInt32Array([ev]), "the crowd closing round the condemned instead of the stones")
		for id in attend:
			if sympathy[id] > anger[id]:
				Village.set_opinion(V, id, cs.accuser, Village.opinion(V, id, cs.accuser) - 25)
		finish_case(V, cs, c, kind, outcome, PackedInt32Array([ev]), false)
		return
	# the effects of each act
	var shame: int = C.PUBLIC[kind]["shame"]
	for id in attend:
		Village.set_opinion(V, id, victim.id, Village.opinion(V, id, victim.id) - shame * 3)
	if kind == "fine":
		V.households[victim.household].food -= 10
	if kind == "pillory" or kind == "stocks":
		victim.stress = clampi(victim.stress + 120, 0, 400)
		victim.marks["pilloried"] = victim.marks.get("pilloried", 0) + 1
		if victim.marks["pilloried"] >= 2:
			earn(V, victim.id, "pilloried")
		if level == 3 and not lethal_by_stones:
			earn(V, victim.id, "survivor")
	if kind == "branding":
		victim.marks["branded"] = 1
		earn(V, victim.id, "branded")
	if kind == "exile" or kind == "scapegoat":
		exile(V, victim.id, PackedInt32Array([ev]), false, c.id)
	# the punished's close kin never forgive the accuser (and blame the elder): the root of revenge
	if not (kind == "fine" or kind == "ordeal"):
		for q in V.people:
			if not q.alive or not q.present or q.id == victim.id or Village.age_of(V, q) < 14 or not close_kin(V, q.id, victim.id):
				continue
			if cs.accuser != q.id:
				Village.set_opinion(V, q.id, cs.accuser, Village.opinion(V, q.id, cs.accuser) - shame * 9)
				remember(q, cs.accuser, ev)
			if V.authority >= 0 and V.authority != q.id:
				Village.set_opinion(V, q.id, V.authority, Village.opinion(V, q.id, V.authority) - shame * 4)
	var killing: String = KILLING.get(kind, "")
	if killing != "" or lethal_by_stones:
		Village.die(V, victim.id, killing if killing != "" else "stoned", PackedInt32Array([ev]),
			"smoke over the field at dusk" if kind == "bonfire" else ("a shape turning on the gallows" if kind == "hanging" else "stones in the dust"))
		if killing == "hanged":
			earn(V, victim.id, "hanged")
		if killing == "burned":
			earn(V, victim.id, "burned")
	finish_case(V, cs, c, kind, outcome, PackedInt32Array([ev]), killing != "" or lethal_by_stones or kind == "exile" or kind == "branding")


static func finish_case(V: S.Village, cs: S.Case, c: S.Crime, kind: String, outcome: String, causes: PackedInt32Array, grave: bool) -> void:
	c.closed = true
	c.punished = cs.accused
	c.punish_event = causes[0]
	var wrongful := cs.accused != c.culprit or c.false_accusation
	# the real culprit carries it if someone else paid (guilt grows; it can break them)
	if wrongful and not c.false_accusation and outcome != "crowd_turned" and outcome != "rescued":
		var real := V.people[c.culprit]
		if real.alive and real.present:
			real.guilt = maxi(real.guilt, 1)
		c.wrongful_punishment = true
	if c.false_accusation and outcome != "crowd_turned" and outcome != "rescued":
		c.wrongful_punishment = true
		# no one did it: the accuser may come to doubt what they 'saw' (Ann Putnam's apology, 1706)
		var acc := V.people[cs.accuser]
		if acc.alive and acc.present and acc.traits[C.COMPASSION] >= 55:
			acc.guilt = maxi(acc.guilt, 1)
			acc.secret.append(c.id)
	# kin resent a grave punishment: a feud between the lineages, passed down
	if grave:
		var a := V.people[cs.accused].lineage
		var b := V.people[cs.accuser].lineage
		if a != b and a >= 0 and b >= 0:
			var lin_a := V.lineages[a]
			lin_a.feuds[b] = lin_a.feuds.get(b, 0) + int(C.PUBLIC[kind]["shame"])
			if lin_a.feuds[b] >= 12 and not lin_a.feud_logged.has(b):
				lin_a.feud_logged[b] = 1
				E.log_event(V, "feud", a, b, {"lineages": [a, b]}, causes, "the %s turning their backs on the %s at the well" % [V.lineages[a].name, V.lineages[b].name])
			for q in V.people:
				if q.alive and q.lineage == a:
					for r in V.people:
						if r.alive and r.lineage == b:
							Village.set_opinion(V, q.id, r.id, Village.opinion(V, q.id, r.id) - 12)


static func exile(V: S.Village, id: int, causes: PackedInt32Array, fled: bool, crime: int) -> void:
	var p := V.people[id]
	p.exiled_for = crime
	p.present = false; p.locked = false
	p.exiled_day = V.day
	V.outlaws.append(id)
	earn(V, id, "exiled")
	E.log_event(V, "exile", id, -1, {"fled": fled}, causes, "footprints leading into the woods" if fled else "%s walking out of the south gate with one bundle" % E.name_of(V, id))


# ---------- conscience: the real culprit breaks, and the wronged are honoured ----------
static func confess_guilt(V: S.Village, pid: int, deathbed: bool = false) -> void:
	var p := V.people[pid]
	p.guilt = 0
	for cid in p.secret:
		var c := V.crimes[cid]
		if not c.wrongful_punishment or c.exonerated:
			continue
		c.exonerated = true
		V.stats["exonerations"] += 1
		var recant := c.false_accusation
		var conf_causes := PackedInt32Array([c.event])
		if c.punish_event >= 0:
			conf_causes.append(c.punish_event)
		var conf := E.log_event(V, "confession", pid, c.punished, {"crime": cid, "late": true, "deathbed": deathbed, "recant": recant}, conf_causes,
			"the priest bending over %s's bed, then going white" % E.name_of(V, pid) if deathbed else "%s weeping at the shrine, telling the priest everything" % E.name_of(V, pid))
		var wronged := V.people[c.punished]
		# the village is ashamed: the wronged is no longer counted as an offender, and no one suspects them for years
		wronged.offences = maxi(0, wronged.offences - 1)
		wronged.cleared_day = V.day
		var ex := E.log_event(V, "exoneration", c.punished, pid, {"crime": cid}, PackedInt32Array([conf]), "the elder striking %s's name from the reckoning" % E.name_of(V, c.punished))
		# the truth wipes the wrong belief from every mind that held it
		for q in V.people:
			var kept: Array[S.Belief] = []
			var dropped := false
			for b in q.beliefs:
				if b.crime == cid and b.culprit != pid:
					dropped = true
				else:
					kept.append(b)
			if dropped:
				q.beliefs = kept
		# the wrongly exiled are sent for and come home; the wrongly killed are honoured (Girard: made sacred)
		if wronged.alive and not wronged.present and wronged.exiled_for == cid:
			var s := S.Sched.new()
			s.day = V.day + 7 + R.pick(R.key(V.base, 0x9e70 + cid), 20); s.kind = "return"; s.who = wronged.id; s.causes = PackedInt32Array([ex])
			V.schedule.append(s)
		if not wronged.alive:
			V.shrines.append({"person": wronged.id, "day": V.day})
			earn(V, wronged.id, "venerated")
			E.log_event(V, "veneration", wronged.id, -1, {"crime": cid}, PackedInt32Array([ex]), "flowers and candles at %s's grave, strangers kneeling" % E.name_of(V, wronged.id))
			for q in V.people:
				if q.alive:
					q.stress = clampi(q.stress - 20, 0, 400)
		# the accuser who pressed it falls in everyone's eyes
		var cs: S.Case = null
		for x in V.cases:
			if x.crime == cid and x.accused == c.punished:
				cs = x
				break
		if cs != null:
			earn(V, cs.accuser, "false_accuser")
			for q in V.people:
				if q.alive and q.id != cs.accuser:
					Village.set_opinion(V, q.id, cs.accuser, Village.opinion(V, q.id, cs.accuser) - 20)
		# the confessor is now tried for it: their own word, and the priest who heard it
		if deathbed:
			continue
		var hearer := V.authority if V.authority >= 0 and V.authority != pid else V.priest
		if hearer >= 0 and hearer != pid:
			Crime.give_belief(V, hearer, cid, pid, 1000, pid, 0, pid)
			Crime.give_belief(V, hearer, cid, pid, 800, V.priest if V.priest >= 0 else hearer, 1, V.priest)
			if c.household < 0 or not V.households[c.household].members.has(hearer):
				c.household = V.people[hearer].household
		c.case_open = false; c.closed = false; c.false_accusation = false; c.discovered = true; c.reopen_day = V.day
	p.secret.clear()


# The wrongly exiled come home: thinner, older, owed something; the village makes amends.
static func come_home(V: S.Village, s: S.Sched) -> void:
	var p := V.people[s.who]
	if not p.alive or p.present or p.faded:
		return
	p.present = true
	var still: Array[int] = []
	for x in V.outlaws:
		if x != p.id:
			still.append(x)
	V.outlaws = still
	var hh := V.households[p.household]
	if not hh.members.has(p.id):
		hh.members.append(p.id)
	hh.food += 20
	for q in V.people:
		if q.alive and q.present and q.id != p.id:
			Village.set_opinion(V, q.id, p.id, Village.opinion(V, q.id, p.id) + 25)
	var kept := PackedStringArray()
	for e in p.epithets:
		if e != C.EPITHETS["exiled"]:
			kept.append(e)
	p.epithets = kept
	earn(V, p.id, "returned")
	E.log_event(V, "return", p.id, -1, {}, s.causes, "%s at the south gate, thinner and older, and the village coming out to meet them" % E.name_of(V, p.id))


# ---------- gatherings that are not punishments: funerals, weddings, festivals ----------
static func funeral(V: S.Village, s: S.Sched) -> void:
	var mourners: Array[S.Person] = []
	for q in V.people:
		if q.alive and q.present and (Village.is_kin(V, q.id, s.who) or Village.opinion(V, q.id, s.who) > 30):
			mourners.append(q)
	for q in mourners:
		q.stress = clampi(q.stress - 70, 0, 400)
	E.log_event(V, "funeral", s.who, -1, {"mourners": mourners.size()}, s.causes, "a slow line of %d to the shrine behind %s" % [mourners.size(), E.name_of(V, s.who)])


static func gathering(V: S.Village, kind: String, s: S.Sched) -> void:
	var k := R.key(R.key(V.base, Village.P_FESTIVAL), V.day)
	var folk: Array[S.Person] = []
	for q in Village.living(V):
		if not q.locked:
			folk.append(q)
	for q in folk:
		q.stress = clampi(q.stress - (60 if kind == "festival" else 30), 0, 400)
	if kind == "festival":
		V.fear = clampi(V.fear - 120, 0, 1000)
	# a festival warms old grudges a little: pairs dance, drink, and some make peace
	for i in folk.size():
		var a := folk[i].id
		var b := folk[R.pick(R.key(k, i), folk.size())].id
		if a != b:
			Village.set_opinion(V, a, b, Village.opinion(V, a, b) + 6)
			Village.set_opinion(V, b, a, Village.opinion(V, b, a) + 6)
	if kind == "festival":
		V.stats["festivals"] += 1
	var feast := s.name if s.name != "" else "the feast"
	E.log_event(V, "wedding" if kind == "wedding" else "festival", s.who, s.other, {"name": s.name}, s.causes,
		"fiddles and a ring of dancers in the square" if kind == "wedding" else "garlands, a bonfire of the good kind, dancing for %s" % feast)
	if kind == "festival":
		make_festival_staging(V, folk, feast, k)


# ---------- stagings: what the stage plays (staging.gd contract) ----------
const PROP_BY_LEVEL := [[], ["cabbage", "turnip"], ["mud"], ["stone"]]
const STAGE_KIND := {"stocks": "pillory", "fine": "trial", "branding": "trial", "ordeal": "trial", "scapegoat": "exile"}
const LOCKING_KINDS := ["pillory", "stocks", "hanging", "bonfire", "sacrifice"]


static func stance_anim(a: int, sy: int) -> String:
	return "Idle_No" if a > sy + 200 else ("Idle_Talking" if sy > a + 200 else "Idle_FoldArms")


static func _beat(beats: Array[Dictionary], at: int, who: int, d: String, slot: int = -1, target: int = -1, anim: String = "", prop: String = "") -> void:
	beats.append({"at": at, "who": who, "do": d, "slot": slot, "target": target, "anim": anim, "prop": prop, "seq": beats.size()})


## Sorts by (at, who, the order made) and drops the order.
static func _sort_beats(beats: Array[Dictionary]) -> void:
	beats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["at"] != b["at"]:
			return a["at"] < b["at"]
		if a["who"] != b["who"]:
			return a["who"] < b["who"]
		return a["seq"] < b["seq"])
	for b in beats:
		b.erase("seq")


# walking takes time: 1.3 m/s is 2.6 m (26 dm) per game minute; each arrives, then takes a stance
static func _walk_min(V: S.Village, id: int, to: int) -> int:
	var p := V.people[id]
	var from := (p.locked_at if p.locked_at >= 0 else V.pl_pillory) if p.locked else V.households[p.household].home_place
	return 2 + R.idiv(absi(V.place_x[from] - V.place_x[to]) + absi(V.place_z[from] - V.place_z[to]), 26)


static func make_staging(V: S.Village, cs: S.Case, c: S.Crime, kind: String, attend: Array[int], throwing: Array[int], level: int, outcome: String,
		lethal_by_stones: bool, anger: Dictionary, sympathy: Dictionary, _k: int) -> Dictionary:
	var def: Dictionary = C.PUBLIC[kind]
	var lethal: bool = def["lethal"]
	var minutes: int = def["minutes"]
	var place: String = def["place"]
	var to := Village.place_id(V, place)
	var start := 720 if kind == "bonfire" else (1200 if kind == "mob" else 480)
	var victim := cs.accused
	var beats: Array[Dictionary] = []
	var elder := V.authority
	# the elder escorts the condemned: both leave together from the condemned's door
	var v_walk := _walk_min(V, victim, to)
	if elder >= 0 and elder != victim:
		_beat(beats, start, elder, "walk_to", -1, victim, "Walk_Formal")
	_beat(beats, start, victim, "walk_to", -1, -1, "Walk")
	var gather_end := start + v_walk + 2
	if LOCKING_KINDS.has(kind):
		_beat(beats, start + v_walk + 2, victim, "lock", -1, -1, "Idle" if kind == "hanging" else "Crouch_Idle")
	# the crowd leaves home one by one in id order, arrives at its slot and takes its stance
	var sorted_attend: Array[int] = attend.duplicate()
	sorted_attend.sort()
	var crowd: Array[int] = []
	for id in sorted_attend:
		if id != elder and crowd.size() < 40:
			crowd.append(id)
	for i in crowd.size():
		var id := crowd[i]
		var t0 := start + 5 + i
		var t1 := t0 + _walk_min(V, id, to) + 1
		_beat(beats, t0, id, "walk_to", i, -1, "Walk")
		_beat(beats, t1, id, "stand", i, -1, stance_anim(anger.get(id, 0), sympathy.get(id, 0)))
		gather_end = maxi(gather_end, t1)
	# the act begins once the crowd has gathered, and runs its length
	var act_start := maxi(start + 60, gather_end + 5)
	var end := act_start + minutes - 60
	# the work of the act: wood carried to the stake, the gallows built, the priest's words
	if kind == "bonfire":
		for i in mini(4, crowd.size()):
			_beat(beats, act_start - 20 + i * 20, crowd[i], "carry", i, -1, "Walk_Carry", "wood")
	if kind == "hanging":
		for i in mini(2, crowd.size()):
			_beat(beats, act_start - 20 + i * 30, crowd[i], "gesture", i, -1, "Fixing_Kneeling")
	if V.priest >= 0 and V.priest != victim and (lethal or kind == "exile"):
		_beat(beats, act_start, V.priest, "gesture", -1, -1, "Spell_Simple_Idle")
	# pelting, wave by wave; the first stone is thrown by the one with the lowest threshold (throwing[0])
	var slot_of := {}
	for i in crowd.size():
		slot_of[crowd[i]] = i
	var waves := mini(level, 3)
	for w in range(1, waves + 1):
		var who: Array[int] = []
		for id in throwing:
			if slot_of.has(id) and who.size() < 4 + w * 2:
				who.append(id)
		var props: Array = PROP_BY_LEVEL[w]
		for j in who.size():
			var id := who[j]
			var at := act_start + (w - 1) * R.idiv(minutes - 90, 3) + j * 7
			_beat(beats, at, id, "throw", slot_of[id], victim, "OverhandThrow", props[j % props.size()])
			_beat(beats, at + 1, victim, "react", -1, id, "Hit_Head" if w == 3 else "Hit_Chest")
	if kind == "bonfire":
		for i in mini(3, crowd.size()):
			_beat(beats, end - 60 + i, crowd[i], "stand", slot_of[crowd[i]], -1, "Idle_Torch", "torch")
	var dies := outcome == "carried_out" and (lethal or lethal_by_stones)
	if outcome == "crowd_turned":
		_beat(beats, end - 30, crowd[0] if crowd.size() > 0 else elder, "release", -1, victim, "Interact")
		_beat(beats, end - 25, victim, "leave", -1, -1, "Walk")
	elif dies:
		_beat(beats, end - 10, victim, "fall", -1, -1, "Death01")
	else:
		if kind == "pillory" or kind == "stocks":
			# (the reference's crowd[0] is undefined when there is no elder and no crowd; the port writes -1)
			_beat(beats, end - 10, elder if elder >= 0 else (crowd[0] if crowd.size() > 0 else -1), "release", -1, victim, "Interact")
		_beat(beats, end - 5, victim, "walk_to" if (kind == "exile" or kind == "scapegoat") else "leave", -1, -1, "Walk")
	for i in crowd.size():
		_beat(beats, end + i, crowd[i], "leave", -1, -1, "Walk")
	_sort_beats(beats)
	var people := []
	var listed: Array[int] = []
	for id: int in [victim, elder, V.priest] + crowd:
		if id >= 0 and not listed.has(id):
			listed.append(id)
			people.append(person_entry(V, id))
	var nm := E.name_of(V, victim)
	var cue := kind
	match kind:
		"pillory":
			cue = ("stones in the square, %s bleeding in the pillory" % nm) if level >= 3 else (("mud and jeers at %s in the pillory" % nm) if level >= 2 else "%s in the pillory, the crowd muttering" % nm)
		"stocks": cue = "%s in the stocks" % nm
		"fine": cue = "coins counted out on the elder's bench"
		"branding": cue = "the smell of burnt skin in the square"
		"exile": cue = "%s led to the south gate" % nm
		"hanging": cue = "the gallows built by lantern light"
		"bonfire": cue = "wood piled round the stake"
		"stoning": cue = "a ring of villagers with stones in their hands"
		"mob": cue = "torches in the lane, a door kicked in"
		"sacrifice": cue = "a procession to the stone at dawn"
		"scapegoat": cue = "a goat and a woman driven into the woods"
		"trial_by_combat": cue = "a ring marked in the dust"
		"ordeal": cue = "the millpond"
	var cause := []
	for id: int in [c.event, cs.event]:
		if id >= 0:
			cause.append("%s: %s" % [V.events[id].type, V.events[id].cue])
	var staging := {
		"id": V.staging_count, "kind": STAGE_KIND.get(kind, kind), "place": place, "start": start, "end": end + crowd.size() + 5,
		"phases": [
			{"name": "gather", "from": start, "to": act_start, "rescue": true},
			{"name": kind, "from": act_start, "to": end - 10, "rescue": not dies or kind != "stoning"},
			{"name": "end", "from": end - 10, "to": end + crowd.size() + 5, "rescue": false},
		],
		"roles": {"victim": victim, "accuser": cs.accuser, "authority": elder, "crowd": crowd},
		"beats": beats, "outcome": "carried_out" if dies else ("crowd_turned" if outcome == "crowd_turned" else outcome), "cause": cause, "cue": cue, "day": V.day, "people": people,
	}
	V.staging_count += 1
	V.stagings.append(staging)
	if V.stagings.size() > 300:
		V.stagings.remove_at(0)
	return staging


static func make_festival_staging(V: S.Village, folk: Array[S.Person], name: String, _k: int) -> void:
	var ids: Array[int] = []
	for q in folk:
		ids.append(q.id)
	ids.sort()
	var crowd: Array[int] = []
	for id in ids:
		if crowd.size() < 30:
			crowd.append(id)
	var beats: Array[Dictionary] = []
	for i in crowd.size():
		var id := crowd[i]
		_beat(beats, 1080 + i, id, "walk_to", i, -1, "Walk", "")
		_beat(beats, 1110 + i, id, "stand", i, -1, "Idle_Talking" if i % 3 == 0 else "Dance", "")
		_beat(beats, 1300 + i, id, "leave", -1, -1, "Walk", "")
	_sort_beats(beats)
	var people := []
	for id in crowd:
		people.append(person_entry(V, id))
	V.stagings.append({"id": V.staging_count, "kind": "festival", "place": "square", "start": 1080, "end": 1340, "phases": [{"name": "feast", "from": 1080, "to": 1300, "rescue": false}],
		"roles": {"victim": -1, "accuser": -1, "authority": V.authority, "crowd": crowd}, "beats": beats, "outcome": "carried_out", "cause": [name], "cue": "dancing in the square", "day": V.day,
		"people": people})
	V.staging_count += 1


static func person_entry(V: S.Village, id: int) -> Dictionary:
	var p := V.people[id]
	var marks := []
	for m: String in p.marks:
		if p.marks[m]:
			marks.append(m)
	return {"id": id, "name": p.name, "outfit": R.key(R.key(V.base, 77), id) % 13, "home": V.households[p.household].home, "role": p.role, "marks": marks}


static func earn(V: S.Village, id: int, epithet_key: String) -> void:
	var e: String = C.EPITHETS.get(epithet_key, "")
	if e == "" or id < 0 or id >= V.people.size():
		return
	var p := V.people[id]
	if p.epithets.has(e):
		return
	p.epithets.append(e)
	p.epithet_log.append([e, V.day])
	E.log_event(V, "epithet", id, -1, {"epithet": e}, PackedInt32Array(), "")

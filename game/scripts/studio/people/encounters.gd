extends RefCounted
## People meeting people (Pass 3, stage 3; Hilmi: "more variation in the interaction types with eachother so that life
## feels more natural and spontaneous"). A catalogue of what two people do when their ways meet, as data, and the
## choice of one from who they are. Pure and keyed: the same two, meeting the same way at the same moment, do the same
## thing. Generic: it knows people (ages, temperament, how they get on), not villages. A new interaction is an entry.
##
##   Encounters.choose(a, b, how, k, fresh) -> entry name, or "" (they simply pass)
##       a, b   {"age": "child" | "adult" | "elder", "sociable", "bold", "temper" (0..1), "likes" (a's feeling for b,
##              -100..100: 0 a neighbour neither liked nor disliked, as most are; kin about 50), "kin" (same household)}
##       how    "pass"      walking, their ways cross or meet
##              "near"      one stands about, the other passes close
##              "still"     both stand about near each other (not already talking)
##              "same_way"  both walking the same way, side by side or one behind
##       k      a key (the moment and the two)
##       fresh  optional: entry name -> how much of that kind was seen lately close by: a count of meetings, each
##              fading with time (1: one just now). Each sighting makes the kind REPEAT less likely (two just now: a
##              sixteenth as likely), so the kind seen most and most lately is held back most: the same thing twice
##              running is what looks scripted. It changes which kind, never whether they meet
##
## An entry (CATALOGUE[name]):
##   how       the meetings it can come from
##   ages      [a's, b's] age groups ("any", "child", "grown": adult or elder)
##   likes     [lowest, highest] feeling a has for b (and b for a, if "both")
##   weight    how often, among the entries that fit (scaled by sociability where "social")
##   shape     what the two do with their bodies (situation.gd): "pair" stop face to face; "crouch" a grown one
##             crouches to a child; "beside" walk on together; "berth" one gives the other a wide berth; "chase" one
##             runs off, the other after; "apart" a look and a gesture from where they are; "glance" nobody stops:
##             a look and a nod or a wave in passing
##   seconds   [least, most] it lasts
##   beats     what each does: "turns" (they take turns to talk, the other nods and listens), or a list of
##             [role, clip, seconds] played in order ("a" or "b" or "both")
##   end       a last gesture from each as they part ("" none)

const CATALOGUE := {
	"stop_for_a_word": {"how": ["pass", "near"], "ages": ["grown", "grown"], "likes": [-5, 100], "both": true,
		"weight": 3.0, "social": true, "shape": "pair", "seconds": [5.0, 11.0], "beats": "turns", "end": "Yes"},
	"gossip": {"how": ["still"], "ages": ["grown", "grown"], "likes": [-5, 100], "both": true, "weight": 3.0,
		"social": true, "shape": "pair", "seconds": [8.0, 16.0], "beats": "turns", "end": ""},
	"greet": {"how": ["pass", "near"], "ages": ["any", "any"], "likes": [-20, 100], "weight": 1.4, "shape": "glance",
		"seconds": [1.6, 2.6], "beats": [["both", "@nod", 1.2], ["a", "@nod", 1.0]], "end": ""},
	"wave_across": {"how": ["near", "still"], "ages": ["any", "any"], "likes": [10, 100], "weight": 1.0, "shape": "glance",
		"seconds": [1.8, 2.6], "beats": [["a", "@wave", 1.2], ["b", "@wave", 1.2]], "end": ""},
	"call_over": {"how": ["near", "still"], "ages": ["grown", "any"], "likes": [25, 100], "weight": 1.5, "social": true,
		"shape": "pair", "seconds": [6.0, 10.0], "beats": [["a", "@wave", 0.1], ["a", "Idle_Rail_Call", 1.6], ["both", "turns", 0.0]], "end": "Yes"},
	"nod_drawing_level": {"how": ["same_way"], "ages": ["any", "any"], "likes": [-5, 100], "weight": 1.2,
		"shape": "glance", "seconds": [1.4, 2.2], "beats": [["a", "@nod", 1.0], ["b", "@nod", 0.8]], "end": ""},
	"walk_together": {"how": ["same_way"], "ages": ["any", "any"], "likes": [0, 100], "both": true, "weight": 3.0,
		"social": true, "shape": "beside", "seconds": [12.0, 30.0], "beats": [], "end": ""},
	"quarrel": {"how": ["pass", "near", "still"], "ages": ["grown", "grown"], "likes": [-100, -30], "weight": 2.5,
		"temper": true, "shape": "pair", "seconds": [4.0, 8.0],
		"beats": [["a", "Spell_Simple_Shoot", 1.0], ["b", "Idle_No", 1.6], ["a", "Idle_Talking", 1.8], ["b", "Spell_Simple_Shoot", 1.0],
			["a", "Idle_No", 1.4]], "end": ""},
	"keep_clear": {"how": ["pass", "near"], "ages": ["any", "any"], "likes": [-100, -20], "weight": 3.0, "shape": "berth",
		"seconds": [3.0, 5.0], "beats": [], "end": ""},
	"crouch_to_child": {"how": ["pass", "near", "still"], "ages": ["grown", "child"], "likes": [-5, 100], "weight": 2.5,
		"shape": "crouch", "seconds": [5.0, 9.0], "beats": [["b", "Idle_Talking", 2.0], ["a", "Yes", 1.5], ["b", "Dance", 2.0]],
		"end": ""},
	"show_something": {"how": ["still", "near"], "ages": ["grown", "grown"], "likes": [0, 100], "weight": 1.5,
		"shape": "pair", "seconds": [5.0, 8.0], "beats": [["a", "Interact", 1.4], ["b", "Yes", 1.5], ["a", "Idle_Talking", 2.5]],
		"end": "Yes"},
	"chase": {"how": ["still", "near", "pass"], "ages": ["child", "child"], "likes": [-20, 100], "weight": 3.0,
		"shape": "chase", "seconds": [6.0, 12.0], "beats": [], "end": ""},
	"talk": {"how": [], "ages": ["any", "any"], "likes": [-100, 100], "weight": 0.0, "shape": "circle", "seconds": [INF, INF],
		"beats": "turns", "end": ""},      # a conversation the director starts (at an evening's chat), not a meeting
	"play": {"how": ["still", "near"], "ages": ["child", "child"], "likes": [0, 100], "weight": 2.0, "shape": "pair",
		"seconds": [5.0, 9.0], "beats": [["both", "Dance", 2.5], ["a", "Jump", 1.0], ["b", "OverhandThrow", 1.2], ["both", "Idle_Talking", 1.5]],
		"end": ""},
}
const CHANCE := {"pass": 0.55, "near": 0.45, "still": 0.3, "same_way": 0.5}   # that they do anything at all
const REPEAT := 0.85          # a kind seen just now close by is this much less likely (about a seventh as likely), compounding


## What a and b do, meeting `how` (see above); "" if nothing (they pass as strangers do).
static func choose(a: Dictionary, b: Dictionary, how: String, k: int, fresh := {}) -> String:
	if _noise(k, 1) >= float(CHANCE.get(how, 0.0)) * (0.6 + 0.8 * maxf(float(a.get("sociable", 0.5)), float(b.get("sociable", 0.5)))):
		return ""
	var fits: Array = []
	var total := 0.0
	for name: String in CATALOGUE:
		var w := weight(name, a, b, how) * pow(1.0 - REPEAT, maxf(float(fresh.get(name, 0.0)), 0.0))
		if w > 0.0:
			fits.append([name, w])
			total += w
	if fits.is_empty():
		return ""
	var pick := _noise(k, 2) * total
	for f: Array in fits:
		pick -= float(f[1])
		if pick <= 0.0:
			return f[0]
	return fits[-1][0]


## How likely an entry is for these two (0: it does not fit).
static func weight(name: String, a: Dictionary, b: Dictionary, how: String) -> float:
	var e: Dictionary = CATALOGUE[name]
	if not (e.how as Array).has(how):
		return 0.0
	if not _age_fits(str(e.ages[0]), str(a.get("age", "adult"))) or not _age_fits(str(e.ages[1]), str(b.get("age", "adult"))):
		return 0.0
	var likes := float(a.get("likes", 0.0))
	if e.get("both", false):
		likes = minf(likes, float(b.get("likes", 0.0)))
	if likes < float(e.likes[0]) or likes > float(e.likes[1]):
		return 0.0
	var w := float(e.weight)
	if e.get("social", false):
		w *= 0.4 + 1.2 * (float(a.get("sociable", 0.5)) + float(b.get("sociable", 0.5))) * 0.5
	if e.get("temper", false):
		w *= 0.2 + 1.6 * maxf(float(a.get("temper", 0.5)), float(b.get("temper", 0.5)))
	if a.get("kin", false) and name in ["greet", "call_over"]:
		w *= 0.3                      # kin do not greet each other in passing as neighbours do
	return w


static func _age_fits(want: String, age: String) -> bool:
	match want:
		"any":
			return true
		"grown":
			return age == "adult" or age == "elder"
	return age == want


## How long it lasts, keyed.
static func seconds(name: String, k: int) -> float:
	var span: Array = CATALOGUE[name].seconds
	return lerpf(float(span[0]), float(span[1]), _noise(k, 3))


static func _noise(key: int, salt: int) -> float:
	return float(posmod(hash(key * 7919 + salt * 104729), 100000)) / 100000.0

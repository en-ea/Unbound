extends RefCounted
## What residents say, checked headless (run.gd -- village/lines_test): every line is short and in-world,
## the choice is repeatable, unknown memory tokens change nothing, and neighbours do not all say the same.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Lines := preload("res://scripts/studio/village/resident_lines.gd")

## Words a line must never contain: a rule, a number or a system by name; a threat to a child; a counting word.
const SYSTEM := ["source", "evidence", "case", "origin", "system", "rule", "rules", "score", "level", "quest", "stat", "token", "percent", "memory"]
const COUNTING := ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "twice", "thrice",
	"hundred", "thousand", "dozen"]
const HARM := ["kill", "hurt", "beat", "die", "dead", "blood", "knife", "stab", "strike", "struck", "hit", "slap"]


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var fails := 0
	var checks: Array = []
	# 1. every line: short, plain
	var long_lines: Array[String] = []
	var banned: Array[String] = []
	var all := Lines.all_lines()
	for text in all:
		if Lines.words(text) > Lines.MAX_WORDS:
			long_lines.append(text)
		for word in _words_of(text):
			if word in SYSTEM or word in COUNTING or word.is_valid_int():
				banned.append("%s (%s)" % [word, text])
	checks.append([long_lines.is_empty(), "all %d lines are %d words or fewer %s" % [all.size(), Lines.MAX_WORDS, long_lines.slice(0, 3)]])
	checks.append([banned.is_empty(), "no line names a rule, a number or a system %s" % [banned.slice(0, 3)]])
	var harm: Array[String] = []
	for text in _flatten(Lines.CHILD):
		for word in _words_of(text):
			if word in HARM:
				harm.append(text)
	checks.append([harm.is_empty(), "no child line touches harm %s" % [harm.slice(0, 3)]])
	# 2. on a real village
	var v := Runtime.create(7)
	Runtime.advance(v, int(v.runtime.now) + 300)
	var people: Array = []
	for p in v.people:
		if p.alive and p.present:
			people.append(p.id)
	var stable := true
	var unknown_ignored := true
	var memory_ok := true
	var day := int(v.runtime.now) / 1440
	for id: int in people:
		var d := View.describe(v, id)
		var a := Lines.line(d, day, int(v.runtime.now) % 1440)
		if a != Lines.line(View.describe(v, id), day, int(v.runtime.now) % 1440):
			stable = false
		var odd := d.duplicate(true)
		(odd.toward_player.memories as Array).append("some_token_from_the_future")
		if Lines.line(odd, day, int(v.runtime.now) % 1440) != a:
			unknown_ignored = false
		if d.age_group != "child" and not d.forebear:
			var freed := d.duplicate(true)
			(freed.toward_player.memories as Array).append("freed_by_you")
			if not Lines.FREED.has(Lines.line(freed, day, 600).replace(d.name, "{name}")):
				memory_ok = false
	checks.append([stable, "the same person says the same thing the same day (%d residents)" % people.size()])
	checks.append([unknown_ignored, "an unknown memory token changes nothing"])
	checks.append([memory_ok, "being freed by the player is remembered by every adult"])
	# 3. the day changes what one person says
	var farmer := -1
	for id: int in people:
		if View.describe(v, id).role == "midwife":
			farmer = id
			break
	var seen := {}
	for dd in 14:
		var dn := View.describe(v, farmer)
		seen[Lines.line(dn, day + dd, 600)] = true
	checks.append([seen.size() >= 3, "one resident says %d different things over 14 days" % seen.size()])
	# 4. neighbours: people at the same place at the same moment (the ones a player meets in one visit)
	var pairs := 0
	var same := 0
	var triples := 0
	var triples_distinct := 0
	var village_share := 0.0
	var samples := 0
	for minute in [420, 600, 720, 900, 1080, 1200]:
		var target: int = int(v.runtime.now) / 1440 * 1440 + minute
		Runtime.advance(v, target if target > int(v.runtime.now) else target + 1440)
		var by_place := {}
		var said := {}
		for id: int in people:
			var d := View.describe(v, id)
			var text := Lines.line(d, int(v.runtime.now) / 1440, int(v.runtime.now) % 1440)
			var key: String = d.activity.place
			if not by_place.has(key):
				by_place[key] = []
			(by_place[key] as Array).append(text)
			said[text] = int(said.get(text, 0)) + 1
		var clashes := 0
		for text: String in said:
			if int(said[text]) > 1:
				clashes += int(said[text])
		village_share += float(clashes) / float(people.size())
		samples += 1
		for key: String in by_place:
			var group: Array = by_place[key]
			for i in group.size():
				for j in range(i + 1, group.size()):
					pairs += 1
					same += 1 if group[i] == group[j] else 0
					for k in range(j + 1, group.size()):
						triples += 1
						triples_distinct += 1 if group[i] != group[k] and group[j] != group[k] and group[i] != group[j] else 0
	var rate := float(same) / float(maxi(pairs, 1))
	checks.append([rate < 0.08, "%.1f%% of pairs standing in the same place say the same line (%d pairs; limit 8%%; whole village %.0f%% share one)" % [rate * 100.0, pairs, village_share / samples * 100.0]])
	checks.append([float(triples_distinct) / float(maxi(triples, 1)) > 0.93, "%d of %d visits to three villagers in one place gave three different lines" % [triples_distinct, triples]])
	for c: Array in checks:
		out.append(("PASS " if c[0] else "FAIL ") + c[1])
		fails += 0 if c[0] else 1
	out.append("LINES: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	return out


static func _words_of(text: String) -> PackedStringArray:
	var clean := ""
	for ch in text.to_lower():
		clean += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "'" else " "
	return clean.split(" ", false)


static func _flatten(node: Variant) -> Array[String]:
	var out: Array[String] = []
	Lines._collect(node, out)
	return out

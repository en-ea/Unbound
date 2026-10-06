extends RefCounted
## What the village does over a day, by the half hour: how many are at each place doing what (sim/view.gd activity).
## The census the stage 3 life work is sized from (where people stand about, alone or together, and for how long).
## Run: godot --headless --path game --script res://scripts/studio/run.gd -- village/day_census [seed]

const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")


static func report() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	var v = Runtime.create(seed)
	var out := PackedStringArray()
	var stays := {}               # verb -> [count, minutes]: how long a stay at one thing lasts
	var last := {}                # id -> [verb|place, since]
	var day := int(v.runtime.now) / 1440
	for minute in range(420, 1380, 5):
		Runtime.advance(v, day * 1440 + minute)
		var at := {}
		for p in v.people:
			var a: Dictionary = View.activity(v, p.id)
			var key := "%s@%s" % [a.verb, a.place]
			if a.verb not in ["sleeping", "away"]:
				at[key] = int(at.get(key, 0)) + 1
			var was: Array = last.get(p.id, ["", minute])
			if was[0] != key:
				if was[0] != "":
					var verb := str(was[0]).split("@")[0]
					var s: Array = stays.get_or_add(verb, [0, 0])
					s[0] += 1
					s[1] += minute - int(was[1])
				last[p.id] = [key, minute]
		if minute % 30 == 0:
			var keys := at.keys()
			keys.sort()
			var line := "%02d:%02d " % [minute / 60, minute % 60]
			for k: String in keys:
				line += " %s %d" % [k, at[k]]
			out.append(line)
	out.append("people %d" % v.people.size())
	for verb: String in stays:
		var s: Array = stays[verb]
		out.append("stay %s: %d stays, mean %.0f game minutes" % [verb, s[0], float(s[1]) / maxi(s[0], 1)])
	return out

extends RefCounted
## The save budget (CONTRACTS, "The save"): a 150-game-day village under 100 KB, 1,000 days under 250 KB.
## Villages are driven the way the game drives them (Runtime.create, then Runtime.advance in chunks, nothing
## resolved by hand) and the payload measured is what SaveGame writes: the JSON text of Save.to_data.
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/save_budget [seeds=3] [days=1000]
## Also printed: the same village with every field readable (no compression), the first codec's size,
## the milliseconds a save and a load take on this machine, and where the bytes are.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")

const SEEDS := [1, 16838, 48514, 7, 99, 4242, 31337, 2]
const BUDGET_KB := {150: 100, 1000: 250}


static func _kb(bytes: int) -> String:
	return "%.1f KB" % (bytes / 1000.0)


static func _bytes(data: Variant) -> int:
	return JSON.stringify(data).to_utf8_buffer().size()


static func _measure(v: S.Village, days: int, out: PackedStringArray) -> bool:
	var t := Time.get_ticks_usec()
	var data := Save.to_data(v)
	var save_ms := (Time.get_ticks_usec() - t) / 1000.0
	var text := JSON.stringify(data)
	var size := text.to_utf8_buffer().size()
	var readable := _bytes(Save.to_data(v, false))
	var first := _bytes(Save.to_data_v1(v))
	var disk: Dictionary = JSON.parse_string(text)
	t = Time.get_ticks_usec()
	var loaded := Save.from_data(disk) if Save.valid(disk) else null
	var load_ms := (Time.get_ticks_usec() - t) / 1000.0
	var ok := loaded != null and size < int(BUDGET_KB[days]) * 1000
	var parts := []
	for name: String in data.state.fields:
		parts.append([_bytes(data.state.fields[name]), name])
	parts.sort()
	parts.reverse()
	var top := []
	for part: Array in parts.slice(0, 4):
		top.append("%s %s" % [part[1], _kb(part[0])])
	var living := 0
	for p in v.people:
		if p.alive and p.present:
			living += 1
	out.append("  day %d (%d people, %d living, %d events, %d crimes): %s on disk (budget %d KB), %s readable, first codec %s; save %.0f ms, load %.0f ms; %s [%s]" % [
		days, v.people.size(), living, v.events.size(), v.crimes.size(), _kb(size), int(BUDGET_KB[days]), _kb(readable), _kb(first),
		save_ms, load_ms, "PASS" if ok else "FAIL", ", ".join(top)])
	return ok


static func report() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[1]) if args.size() > 1 else 3
	var last := int(args[2]) if args.size() > 2 else 1000
	var out := PackedStringArray()
	var ok := true
	for i in mini(seeds, SEEDS.size()):
		var seed: int = SEEDS[i]
		var v := Runtime.create(seed)
		out.append("seed %d" % seed)
		var t0 := Time.get_ticks_msec()
		for days: int in [150, 1000]:
			if days > last:
				break
			while int(v.runtime.now) < days * 1440:
				Runtime.advance(v, mini(days * 1440, int(v.runtime.now) + 1440))
			ok = _measure(v, days, out) and ok
		out.append("  (%.1f s to drive it)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	out.append("SAVE BUDGET: %s" % ("PASS" if ok else "FAIL"))
	return out

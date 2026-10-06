extends Node
## Is anything happening near the player? (Pass 2, M1): --studio=village/live --village-lively-test=<minutes>
## --test-save=<unique>. The player stands in the square (a real body, no input) while the game runs at 4x;
## the probe counts what the village showed within sight: small scenes (incidents), hearings, public acts, rites.
## Pass: at least one small scene within the first 10 minutes of play, and nothing broken.
const SPEED := 4.0
var _minutes := 10.0
var _t := 0.0
var _started := false
var _seen := {}          # event id -> [type, kind, real minute seen]
var _first_scene := -1.0
var _clock0 := -1               # village minutes when play began (a failure says why: did time run, was the player seen?)
var _present_s := 0.0
var _locked_s := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-lively-test="):
			_minutes = float(arg.trim_prefix("--village-lively-test="))


func _process(delta: float) -> void:
	var live := get_tree().current_scene.get_node_or_null("VillageLive")
	if live == null or VillageSession.village == null:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not _started:
		_started = true
		Engine.time_scale = SPEED
		var sq: Vector2 = live.registry.place("square")
		player.global_position = Vector3(sq.x + 2.0, player.global_position.y + 0.5, sq.y + 2.0)
		return
	_t += delta / SPEED   # real play minutes are measured without the speed-up
	var v = VillageSession.village
	if _clock0 < 0:
		_clock0 = int(v.runtime.now)
	if v.runtime.get("player", {}).get("present", false):
		_present_s += delta / SPEED
	if Controls.locked or VillageSession.background:
		_locked_s += delta / SPEED
	for e: Dictionary in v.runtime.events:
		if _seen.has(int(e.id)) or e.phase != "active":
			continue
		var st: Dictionary = VillageSession.Runtime.staging(v, int(e.id))
		_seen[int(e.id)] = [e.type, st.get("kind", ""), _t / 60.0 * SPEED]
		if e.type == "incident" and _first_scene < 0.0:
			_first_scene = _t / 60.0 * SPEED
	if _t * SPEED >= _minutes * 60.0:
		Engine.time_scale = 1.0
		var counts := {}
		for id: int in _seen:
			var key: String = "%s:%s" % [_seen[id][0], _seen[id][1]]
			counts[key] = counts.get(key, 0) + 1
		print("LIVELY %.0f minutes of play in the square: %s; first small scene at %.1f min" % [_minutes, JSON.stringify(counts), _first_scene])
		print("LIVELY village clock %d -> %d (%d game minutes); player seen as present %.0f%% of the time; controls locked or in the background %.0f%%; quiet since %d; last scene %s" % [
			_clock0, int(v.runtime.now), int(v.runtime.now) - _clock0, 100.0 * _present_s / maxf(_t, 0.001), 100.0 * _locked_s / maxf(_t, 0.001),
			int(v.runtime.get("quiet_since", -1)), str(v.runtime.get("last_scene", ""))])
		var ok := _first_scene >= 0.0 and _first_scene <= 10.0
		print(("PASS" if ok else "FAIL") + " lively: a small scene within 10 minutes of play near the player")
		get_tree().quit(0 if ok else 1)
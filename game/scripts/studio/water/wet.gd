extends RefCounted
## The enemies' water states (studio: water class): one small store keyed by the enemy, one clock.
## Wet is one fact for everything: villagers carry it as the doused body fact (people_actions), things as the
## soaked fact (thing_facts); his creatures and bandits carry it here. Frost, Conductive and Tidebound read it
## from these three places only, never a private flag.
##   wet      until (s)   a soaking lasts WET_SECS (Still Water: STILL_SECS); fire on a wet enemy goes out
##   frozen   until (s)   held in ice; the next weapon hit lands x3 and cracks it (Tidecaller.strike)
##   chilled  until (s)   slowed a moment (the dry caught by Rime Wave)
## Times are game seconds (scaled by his hit-stop and slow motion, paused with the game), the time his own enemy
## effects count down in (burning.gd, cracked.gd use delta). Tidecaller._physics_process advances the clock.

const WET_SECS := 15.0
const STILL_SECS := 20.0

static var _rows := {}           # instance id -> {wet, frozen, chilled}
static var _clock := 0.0


static func now() -> float:
	return _clock


static func advance(delta: float) -> void:
	_clock += delta


static func wet_secs() -> float:
	return STILL_SECS if Classes.has_talent("still_water") else WET_SECS


## The action: soak an enemy (puts out its fire, his Burning node). Returns true if it was burning.
static func mark(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	_row(enemy).wet = now() + wet_secs()
	var fire := enemy.get_node_or_null("Burning")
	if fire:
		fire.queue_free()
		return true
	return false


static func is_wet(enemy: Node) -> bool:
	return _until(enemy, "wet") > now()


## Seconds of wet left (0 when dry).
static func wet_left(enemy: Node) -> float:
	return maxf(0.0, _until(enemy, "wet") - now())


static func freeze(enemy: Node, seconds: float) -> void:
	if is_instance_valid(enemy):
		_row(enemy).frozen = now() + seconds


static func is_frozen(enemy: Node) -> bool:
	return _until(enemy, "frozen") > now()


## The ice cracks (the x3 hit, or its time ran out).
static func thaw(enemy: Node) -> void:
	if is_instance_valid(enemy) and _rows.has(enemy.get_instance_id()):
		_rows[enemy.get_instance_id()].frozen = 0.0


static func chill(enemy: Node, seconds: float) -> void:
	if is_instance_valid(enemy):
		_row(enemy).chilled = now() + seconds


static func is_chilled(enemy: Node) -> bool:
	return _until(enemy, "chilled") > now()


static func clear() -> void:
	_rows.clear()


static func _until(enemy: Node, key: String) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	return float(_rows.get(enemy.get_instance_id(), {}).get(key, 0.0))


static func _row(enemy: Node) -> Dictionary:
	var id := enemy.get_instance_id()
	if not _rows.has(id):
		if _rows.size() > 64:                    # forget the gone and the long dry
			var t := now()
			for k: int in _rows.keys():
				var r: Dictionary = _rows[k]
				if not is_instance_id_valid(k) or maxf(r.wet, maxf(r.frozen, r.chilled)) < t:
					_rows.erase(k)
		_rows[id] = {"wet": 0.0, "frozen": 0.0, "chilled": 0.0}
	return _rows[id]

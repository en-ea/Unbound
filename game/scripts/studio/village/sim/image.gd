extends RefCounted
## Step 4 (5 Oct, plan/STEP4-SAVE-STALL-2026-10-05.md section 3): the image of the live village as last written, so a
## checked acceptance never copies or encodes the whole village.
## - Acceptance runs prepare on the live village. begin() first takes in any change made outside acceptance (the
##   clock, behaviour phases), so the image is exactly the village before prepare; changes() then finds what prepare
##   touched; restore() puts those parts back from the image into the same objects (exact rollback); stage() encodes
##   only those parts, and anything not yet on disk, as one journal line; commit() after the line is written.
## - The image holds village fields and people as native copies, and each mind as the bytes the line wrote
##   (var_to_bytes of each small field, of each known and appraised entry, and of the episodes' values): a commit copies
##   nothing, a rollback restores exact native values, and the guard compares bytes. Mind entries travel in the line
##   as those bytes; the checkpoint worker and the loader encode them (save.gd apply_line), off the action path.
##   Encoding and stringifying 228 KB of receipts measured 41 ms here against 6 ms for the bytes.
## - Change finding is cheap first, exact second. The cheap pass hashes each field and person (order-sensitive; an
##   object counts by identity; maps key by key, lists item by item) and gates each mind on the identity of its
##   attention record (People.learn and admit always replace it), the sizes of its maps and lists, its generation,
##   last_tick and plan (the only fields decide and the live phase advance change). A mind that moved is compared by
##   field hashes; its accounts, receipts and episodes change only in People.learn, which stamps last_tick, so they
##   are compared only after a learn could have run: known accounts by identity (learn replaces an account, never
##   edits it), appraised receipts by hash (decay edits older receipts in place), episodes by identity and hash. Content hashing
##   every mind measured 8-15 ms per acceptance on the cloud VM (plan section 1), over rule 7's budget.
## - Safety nets for what that cannot see (a 32-bit collision, an object or account edited in place): sweep() checks
##   one more part every frame and puts any difference in the next line; in tests, the guard compares the whole
##   village with the image, minds encoded, after every acceptance and fails the run on any difference.
## - Field reads go through accessors generated from state.gd's layout at start, so a new field is never skipped.
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Events := preload("res://scripts/studio/village/sim/events.gd")
const MAPS: Array[StringName] = [&"known", &"appraised"] # mind fields kept and written entry by entry
const KEYED := ["people_facts", "people_notices"] # written only inside acceptance, by the code that names its keys
## runtime keys no batch writes: the session's clock (fraction every frame, now every game minute), the news desk's
## state (rebuilt from its own memory every few seconds) and where the player is (the live village, every frame). A
## rollback leaves them live; every batch compares them, so they are written whenever they move.
const RUNTIME_LIVE := ["fraction", "now", "news", "player"]

static var village = null # the live village this image describes
static var fields := {} # village field -> copy as written
static var persons := [] # i -> the person's values (mind left out), copies
static var minds := [] # i -> {small field -> bytes; episodes -> encoded; known and appraised -> {key -> bytes}}
static var hashes := [] # i -> {small field -> hash, &"episodes" -> [refs, hashes], map -> {key -> hash}}
static var known := [] # i -> the live known map's accounts, by identity, as written
static var attention := [] # i -> the live attention record, by identity, as written
static var twin_f := {} # field -> hash as written (cheap pass)
static var twin_k := {} # dictionary field -> {key -> hash} as written; list field -> [hash of each item] (cheap pass)
static var twin_p := [] # i -> hash of the person's values as written (cheap pass)
static var twin_m := [] # i -> [pending array by identity (Mind replaces it whenever flush touches it), known size, appraised size, episodes size, last_tick,
	# generation, pending size, hash of the plan, hash of the modifiers]
static var _now := 0 # the active tick of the village being compared
static var disk_n := 0 # people on disk
static var places := 0 # place names on disk
static var kept := [] # staging ids on disk
static var unwritten := {} # parts taken into the image but not yet on disk (a diff)
static var staged = null # {"line": journal village delta, "diff": parts it carries, "enc": mind bytes it holds}
static var stale := true # disk does not hold this image's village: the next save is a full one
static var guard := false # tests: verify image == live after every acceptance
## What a batch says it touched (step 4, 5 Oct): {"m": {person i}, "keys": {KEYED field: {key}}}; null when the batch
## named nothing, and then every mind and keyed field is compared. The bridge, people_actions and player_acts name
## the observers whose minds People.flush/admit may change, the people whose plan they clear and the facts and
## notices they write, so ordinary work compares only those (plus every field and person, cheaply).
static var hints = null
static var _drift := {} # minds changed outside acceptance by a known source (the bridge's live phase advance)
static var _last_event = null # the last chronicle event as written (the chronicle only grows)
static var swept := 0 # parts the sweeper found changed since the image (outside changes, or a miss)
static var _sweep := 0
static var _fields: Array = [] # [name, kind, class] written for this layout
static var _field_at := {} # field name -> its index in _fields
static var _small: Array[StringName] = [] # mind fields compared as one array
## The small mind fields something other than People.learn changes: admit (attention, pending), decide (plan,
## generation), modifiers and temperament by their owners. A mind no learn reached is compared at these only.
static var _outside: Array[StringName] = [&"attention", &"pending", &"plan", &"generation", &"modifiers", &"temperament"]
static var _person: Array[StringName] = [] # person field names except mind
static var _mind: Dictionary = {} # mind field -> [kind, class]
static var _acc: GDScript = null # generated field accessors
static var _person_objects: Array[int] = [] # person fields that hold objects (copied object by object)
static var _schemas := {} # class -> its field names, as a line writes them


static func _names() -> void:
	if not _fields.is_empty():
		return
	Codec._class_map()
	var layout: Dictionary = Codec._layout("Village")
	for i in layout.names.size():
		var name := String(layout.names[i])
		if name != "people":
			_field_at[name] = _fields.size()
			_fields.append([name, layout.kinds[i], layout.classes[i]])
	var mind: Dictionary = Codec._layout("Mind")
	for i in mind.names.size():
		_mind[mind.names[i]] = [mind.kinds[i], mind.classes[i]]
		if not MAPS.has(mind.names[i]) and mind.names[i] != &"episodes":
			_small.append(mind.names[i])
	var person: Dictionary = Codec._layout("Person")
	for i in person.names.size():
		if person.names[i] != &"mind":
			if person.kinds[i] == Codec.K.AOBJ or person.kinds[i] == Codec.K.OBJ:
				_person_objects.append(_person.size())
			_person.append(person.names[i])
	_acc = _accessors()


## Typed direct field access, generated from the layout: reading 34 people through Object.get measured 3-5x slower.
static func _accessors() -> GDScript:
	var lines := PackedStringArray(["extends RefCounted", "const S = preload(\"res://scripts/studio/village/sim/state.gd\")"])
	var village: Array = _fields.map(func(row: Array) -> String: return row[0])
	for row: Array in [["person", "S.Person", "p", _person], ["mind", "S.Mind", "m", _small], ["episode", "S.Episode", "e", Codec._layout("Episode").names], ["village", "S.Village", "v", village]]:
		var reads := PackedStringArray()
		var writes := PackedStringArray()
		for i in row[3].size():
			reads.append("%s.%s" % [row[2], row[3][i]])
			writes.append("\t%s.%s = values[%d]" % [row[2], row[3][i], i])
		lines.append("static func %s(%s: %s) -> Array:" % [row[0], row[2], row[1]])
		lines.append("\treturn [%s]" % ", ".join(reads))
		lines.append("static func set_%s(%s: %s, values: Array) -> void:" % [row[0], row[2], row[1]])
		lines.append("\n".join(writes))
	var script := GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	var error := script.reload()
	assert(error == OK, "image accessors")
	return script


static func _written(v, name: String) -> bool:
	return not (Codec._derived(name) and Codec._rebuilt_count(v) >= 0)


# ---------- binding ----------

## The image becomes the village as it is now; `on_disk` when a full save of exactly this state was just written.
static func rebase(v, on_disk: bool) -> void:
	_names()
	village = v
	fields = {}
	twin_f = {}
	twin_k = {}
	for row: Array in _fields:
		if _written(v, row[0]):
			fields[row[0]] = Codec._copy(v.get(row[0]))
			_twin(row[0], v.get(row[0]))
	persons = []
	twin_p = []
	for list: Array in [minds, hashes, known, attention, twin_m]:
		list.clear()
	for i in v.people.size():
		var p = v.people[i]
		persons.append(_copy_person(p))
		twin_p.append(hash(_acc.person(p)))
		for list: Array in [minds, hashes, known, attention, twin_m]:
			list.append(null)
		_mind_all(i, p.mind)
	disk_n = v.people.size()
	places = v.place_names.size()
	kept = _kept(v)
	unwritten = {}
	staged = null
	stale = not on_disk
	_sweep = 0


static func bound(v) -> bool:
	return v != null and is_same(village, v)


static func _twin(name: String, live: Variant) -> void:
	twin_f[name] = hash(live)
	if name == "events":
		_last_event = live.back() if not live.is_empty() else null
	if live is Dictionary:
		var each := {}
		for k: Variant in live:
			each[k] = hash(live[k])
		twin_k[name] = each
	elif live is Array:
		var each := PackedInt64Array()
		for item: Variant in live:
			each.append(hash(item))
		twin_k[name] = each


static func _copy_person(p) -> Array:
	var values: Array = _acc.person(p).duplicate(true) # containers copied natively, objects still shared ...
	for j: int in _person_objects:
		values[j] = Codec._copy(values[j]) # ... until copied here
	return values


static func _kept(v) -> Array:
	var ids: Array = Codec._kept_stagings(v).keys()
	ids.sort()
	return ids


static func _enc(m, name: StringName) -> Variant:
	return Codec._enc_field(m.get(name), _mind[name][0], _mind[name][1])


## A mind field as the image and the line hold it: episodes encoded (they are objects), anything else as bytes.
static func _form(m, name: StringName) -> Variant:
	if name == &"episodes": # each episode as its values in layout order (save.gd encodes them as Episode rows)
		var rows := []
		for e: S.Episode in m.episodes:
			rows.append(_acc.episode(e))
		return var_to_bytes(rows)
	return var_to_bytes(m.get(name))


static func _episodes(m) -> Array:
	var refs := []
	var sums := []
	for e: S.Episode in m.episodes:
		refs.append(e)
		sums.append(hash(_acc.episode(e)))
	return [refs, sums]


## The episodes' encoding and their hashes from one pass over the rows: [bytes, [refs, sums]].
static func _episode_parts(m) -> Array:
	var rows := []
	var refs := []
	var sums := []
	for e: S.Episode in m.episodes:
		var row: Array = _acc.episode(e)
		rows.append(row)
		refs.append(e)
		sums.append(hash(row))
	return [var_to_bytes(rows), [refs, sums]]


## Mind i as it is now, every field.
static func _mind_all(i: int, m) -> void:
	var image := {}
	var sums := {}
	for name: StringName in _small:
		image[name] = _form(m, name)
		sums[name] = hash(m.get(name))
	image[&"episodes"] = _form(m, &"episodes")
	sums[&"episodes"] = _episodes(m)
	for name: StringName in MAPS:
		var map: Dictionary = m.get(name)
		var entries := {}
		var each := {}
		for k: Variant in map:
			entries[k] = var_to_bytes(map[k])
			each[k] = hash(map[k])
		image[name] = entries
		sums[name] = each
	minds[i] = image
	hashes[i] = sums
	_mind_marks(i, m)


static func _mind_marks(i: int, m, accounts := true) -> void:
	if accounts:
		known[i] = m.known.duplicate(false)
	attention[i] = m.attention
	twin_m[i] = [m.pending, m.known.size(), m.appraised.size(), m.episodes.size(), m.last_tick, m.generation, m.pending.size(), hash(m.plan),
		hash(m.modifiers)] # modifiers: their owners write them outside People.learn (merge-enea, 6 Oct: a modifier alone was missed)


# ---------- what a batch names ----------

static func hinting() -> void:
	if hints == null:
		hints = {"m": {}, "keys": {}, "p": {}, "f": {"runtime": true}, "logged": Events.logged, "k": {}}


static func touch(id: int) -> void:
	if hints != null and id >= 0:
		hints.m[id] = true


static func touch_actor(v, actor: String) -> void:
	if hints != null:
		var id := People.resident(v, actor)
		if id < 0:
			touch_field("actor_minds") # a generic observer's mind lives in that field
		touch(id)


## A person whose own fields the batch may change (hurt, body facts); -1: any person (a death, a rules act).
static func touch_person(id: int) -> void:
	if hints != null:
		if id < 0:
			hints.p_all = true
			hints.f_all = true # a death or a rules act may change any field too
		else:
			hints.p[id] = true


## A fact (deed:observer) the batch may teach that observer: its known account is compared at these keys only, plus
## the accounts People.learn compacts when an episode is evicted.
static func touch_fact(v, observer: String, fact: String) -> void:
	if hints != null:
		var id := People.resident(v, observer)
		if id >= 0:
			((hints.k as Dictionary).get_or_add(id, {}) as Dictionary)[fact] = true


## A village field the batch writes (households on a gift); the runtime's plain values are always compared, its
## containers at the keys named with touch_key("runtime", key).
static func touch_field(name: String) -> void:
	if hints != null:
		hints.f[name] = true


static func touch_key(field: String, key: Variant) -> void:
	if hints != null:
		(hints.keys.get_or_add(field, {}) as Dictionary)[key] = true


## Outside acceptance: a known source changed this mind (taken in at the next begin).
static func drifted(id: int) -> void:
	_drift[id] = true


static var _synced_now: Variant = null # the rules clock at the last whole check of fields and people


# ---------- comparing ----------

## Deep equality of live state and its copy: objects field by field, dictionaries with their key order at each level
## that is not natively equal. Natively equal containers hold the same objects, so the fast path is exact.
static func same(a: Variant, b: Variant) -> bool:
	var t := typeof(a)
	if t != typeof(b):
		return false
	match t:
		TYPE_OBJECT:
			if a == null or b == null or is_same(a, b):
				return is_same(a, b)
			var script: Variant = a.get_script()
			if script != b.get_script() or not Codec._names.has(script):
				return false
			for name: StringName in Codec._layout(Codec._names[script]).names:
				if not same(a.get(name), b.get(name)):
					return false
			return true
		TYPE_DICTIONARY:
			if a.size() != b.size():
				return false
			var keys: Array = a.keys()
			if keys != b.keys():
				return false
			if a == b:
				return true
			for k: Variant in keys:
				if not same(a[k], b[k]):
					return false
			return true
		TYPE_ARRAY:
			if a.size() != b.size():
				return false
			if a == b:
				return true
			for i in a.size():
				if not same(a[i], b[i]):
					return false
			return true
	return a == b


## A map's changes from its image: {"del": {k}, "set": {k}}, true when only a whole write keeps its order, null when
## none. `changed(k)` says whether a key both hold differs.
static func _map_diff(live: Dictionary, image: Dictionary, changed: Callable) -> Variant:
	var del := {}
	var put := {}
	for k: Variant in image:
		if not live.has(k):
			del[k] = true
	var added := []
	for k: Variant in live:
		if not image.has(k):
			put[k] = true
			added.append(k)
		elif changed.call(k):
			put[k] = true
	if del.is_empty() and added.is_empty():
		if live.keys() != image.keys():
			return true
		return null if put.is_empty() else {"del": del, "set": put}
	var order := []
	for k: Variant in image:
		if not del.has(k):
			order.append(k)
	order.append_array(added)
	if order != live.keys():
		return true
	return {"del": del, "set": put}


static func _field_diff(v, row: Array, exact := true) -> Variant:
	var name: String = row[0]
	var live: Variant = v.get(name)
	var image: Variant = fields.get(name)
	if name == "stagings":
		return true if not same(live, image) or _kept(v) != kept else null
	if not exact and name == "events" and live is Array:
		var count: int = twin_k[name].size()
		if live.size() >= count and (count == 0 or is_same(live[count - 1], _last_event)):
			return {"at": count} if live.size() > count else null
	if not exact and twin_k.has(name):
		var each: Variant = twin_k[name]
		if live is Dictionary and image is Dictionary:
			return _map_diff(live, image, func(k: Variant) -> bool: return hash(live[k]) != each.get(k))
		if live is Array and row[1] != Codec.K.AOBJ and live.size() >= each.size(): # an object hashes by reference
			for j in each.size():
				if hash(live[j]) != each[j]:
					return true
			return {"at": each.size()} if live.size() > each.size() else null
		if not (live is Array and row[1] == Codec.K.AOBJ):
			return true
	if same(live, image):
		return null
	if live is Dictionary and image is Dictionary:
		return _map_diff(live, image, func(k: Variant) -> bool: return not same(live[k], image[k]))
	if live is Array and image is Array and live.size() >= image.size() and same(live.slice(0, image.size()), image):
		return {"at": image.size()}
	return true


## Mind i's changes from its image, {field: true | map diff}; {} when none. `exact` compares bytes and encodings.
static func _mind_diff(i: int, m, exact: bool, facts: Variant = null, receipts: Variant = null) -> Dictionary:
	var twin: Array = twin_m[i]
	# A mind that wrote a receipt learned (Mind records every learn's own receipt), whatever its sizes and tick say:
	# two learns in one frame keep last_tick and can keep every size.
	var wrote: bool = receipts is Dictionary and not receipts.is_empty()
	if not exact and not wrote and is_same(m.attention, attention[i]) and is_same(m.pending, twin[0]) and m.known.size() == twin[1] and m.appraised.size() == twin[2] and m.episodes.size() == twin[3] and m.last_tick == twin[4] and m.generation == twin[5] and m.pending.size() == twin[6] and hash(m.plan) == twin[7] and hash(m.modifiers) == twin[8]:
		return {}
	var image: Dictionary = minds[i]
	var sums: Dictionary = hashes[i]
	var out := {}
	var small := {}
	var learned: bool = exact or wrote or not (m.last_tick == twin[4] and m.last_tick < _now and m.known.size() == twin[1] and m.appraised.size() == twin[2] and m.episodes.size() == twin[3])
	for name: StringName in (_small if learned else _outside):
		if exact:
			if _form(m, name) != image[name]:
				out[name] = true
		else:
			var h := hash(m.get(name))
			if h != sums[name]:
				out[name] = true
				small[name] = h
	if not small.is_empty():
		out[&"#s"] = small # the hashes just taken, reused when the image takes these fields
	if not learned:
		return out # no learn since the image: accounts, receipts, episodes and what only learn sets are as written
	if not exact or _form(m, &"episodes") != image[&"episodes"]:
		out[&"episodes"] = true # People.learn writes the learned fact's episode: a learning mind's episodes are written
	var accounts: Dictionary = m.known
	var refs: Dictionary = known[i]
	var d: Variant = _known_at(m, i, facts) if not exact and facts != null else false # false: compare the whole map
	if d is bool and d == false:
		d = _map_diff(accounts, image[&"known"], (func(k: Variant) -> bool: return var_to_bytes(accounts[k]) != image[&"known"][k]) if exact
			else (func(k: Variant) -> bool: return not is_same(accounts[k], refs.get(k))))
	if d != null:
		out[&"known"] = d
	var each: Dictionary = sums[&"appraised"]
	var fresh := {}
	d = _receipts_at(m, i, receipts, fresh) if not exact and receipts != null else false # false: compare every receipt
	if d is bool and d == false:
		var live: Dictionary = m.appraised
		d = _map_diff(live, image[&"appraised"], (func(k: Variant) -> bool: return var_to_bytes(live[k]) != image[&"appraised"][k]) if exact
			else (func(k: Variant) -> bool:
				var h := hash(live[k])
				fresh[k] = h
				return h != each.get(k)))
	if d is Dictionary:
		d.h = fresh
	if d != null:
		out[&"appraised"] = d
	return out


## Known accounts at the named facts and at the episodes People.learn evicted (it compacts their accounts); false
## when the map changed in a way those keys do not explain (then the whole map is compared).
static func _known_at(m, i: int, facts: Dictionary) -> Variant:
	var image: Dictionary = minds[i][&"known"]
	var refs: Dictionary = known[i]
	var keys := facts.duplicate()
	var live_episodes: Array = m.episodes
	for e: S.Episode in hashes[i][&"episodes"][0]:
		if not live_episodes.has(e):
			keys[e.key] = true
	var live: Dictionary = m.known
	var del := {}
	var put := {}
	var added := []
	for k: Variant in keys:
		if live.has(k):
			if not image.has(k):
				put[k] = true
				added.append(k)
			elif not is_same(live[k], refs.get(k)):
				put[k] = true
		elif image.has(k):
			del[k] = true
	if live.size() != image.size() + added.size() - del.size():
		return false
	if not added.is_empty():
		var order: Array = live.keys()
		var tail: Array = order.slice(order.size() - added.size())
		for k: Variant in added:
			if not tail.has(k):
				return false
		added = tail
	if del.is_empty() and put.is_empty():
		return null
	return {"del": del, "set": put, "new": added}


## Receipts at the keys Mind recorded writing (People.written); false when the map changed in a way those keys do
## not explain (then every receipt is compared). `fresh` receives the hashes taken.
static func _receipts_at(m, i: int, keys: Dictionary, fresh: Dictionary) -> Variant:
	var image: Dictionary = minds[i][&"appraised"]
	var each: Dictionary = hashes[i][&"appraised"]
	var live: Dictionary = m.appraised
	var del := {}
	var put := {}
	var added := []
	for k: Variant in keys:
		if live.has(k):
			var h := hash(live[k])
			fresh[k] = h
			if not image.has(k):
				put[k] = true
				added.append(k)
			elif h != each.get(k):
				put[k] = true
		elif image.has(k):
			del[k] = true
	if live.size() != image.size() + added.size() - del.size():
		return false
	if not added.is_empty():
		var order: Array = live.keys()
		var tail: Array = order.slice(order.size() - added.size())
		for k: Variant in added:
			if not tail.has(k):
				return false
	if del.is_empty() and put.is_empty():
		return null
	return {"del": del, "set": put}


## What differs from the image: {"f": {field: true | map diff | {"at"}}, "p": {i}, "m": {i: mind diff}}.
## `scope`: null compares everything; else {"m": {i}, "keys": {field: {key}}, "p": {i} (absent: every person),
## "p_all", "f": [field] (absent: every field)} limits the minds, keyed maps, people and fields compared.
## begin passes the drift marks, no keys, and when the rules clock has not moved, only the runtime field and no
## people (the rules change people and fields on their clock; the news writes into runtime every frame).
static func changes(v, exact := false, scope: Variant = null) -> Dictionary:
	var out := {"f": {}, "p": {}, "m": {}}
	_now = People.tick(v)
	var values: Array = _acc.village(v)
	var only: Variant = scope.get("f") if scope != null else null
	for j: int in (_fields.size() if only == null else _indices(only)): # a scoped pass visits its named fields only
		var row: Array = _fields[j]
		if fields.has(row[0]):
			if not exact:
				var live: Variant = values[j]
				if scope != null and scope.has("rt") and row[0] == "runtime":
					var d: Variant = _runtime_diff(v, row, scope.rt)
					if d != null:
						out.f[row[0]] = d
					continue
				if scope != null and KEYED.has(row[0]):
					var d: Variant = _keyed_diff(live, row[0], scope.keys.get(row[0], {}))
					if d != null:
						out.f[row[0]] = d
					continue
				if row[0] == "events" and live.size() == twin_k[row[0]].size() and (live.is_empty() or is_same(live.back(), _last_event)):
					continue # the chronicle only grows: same length, same last event (an edit in place is the sweeper's)
				if live is Dictionary and twin_k.has(row[0]) and row[0] != "actor_minds":
					var d: Variant = _field_diff(v, row, false) # one pass, key by key (the clock moves runtime every frame)
					if d != null:
						out.f[row[0]] = d
					continue
				# An array of objects hashes by reference, so an object edited in place (a household's food, a case's
				# phase) keeps its hash: those fields, like a single object, are compared by value.
				var deep: bool = live is Object or row[0] == "actor_minds" or (row[1] == Codec.K.AOBJ and not live.is_empty())
				if hash(live) == twin_f[row[0]] and (not deep or same(live, fields[row[0]])):
					continue
			var d: Variant = _field_diff(v, row, exact or row[0] == "actor_minds")
			if d != null:
				out.f[row[0]] = d
	var rt: Variant = out.f.get("runtime")
	# Which stagings are written follows the runtime, the pending acts and the clock (an event's staging is kept until
	# its end), and the clock moves outside acceptance (WorldClock, his bed, the sky's set_time): so every batch, named
	# or not, checks the kept set and the list's length, not only one that moved the rules (merge-enea 6 Oct: the
	# intermittent "field stagings" guard line after a clock jump in Mind's port probe).
	if not exact and not out.f.has("stagings") and fields.has("stagings") and (_kept(v) != kept or v.stagings.size() != (fields.stagings as Array).size()):
		out.f["stagings"] = true
	var n: int = v.people.size()
	for i in n:
		if i >= persons.size():
			out.p[i] = true
			continue
		var p = v.people[i]
		var people: Variant = scope.get("p") if scope != null and not scope.get("p_all", false) else null
		if (people == null or people.has(i)) and ((not same(_acc.person(p), persons[i])) if exact else hash(_acc.person(p)) != twin_p[i]):
			out.p[i] = true
		if scope != null and not scope.m.has(i):
			continue
		var d := _mind_diff(i, p.mind, exact, scope.get("k", {}).get(i, {}) if scope != null and scope.has("k") else null,
			scope.r.get(i, {}) if scope != null and scope.has("r") else null)
		if not d.is_empty():
			out.m[i] = d
	if n != persons.size():
		out.n = true
	if v.place_names.size() != places:
		out.x = true
	return out


## The _fields indices of the named fields, in layout order.
static func _indices(names: Variant) -> Array:
	var at := {}
	for name: Variant in names:
		if _field_at.has(name):
			at[_field_at[name]] = true
	var out: Array = at.keys()
	out.sort()
	return out


## The runtime after a batch that named what it wrote: plain values compared directly, containers only at the keys
## the batch named (touch_key("runtime", key)) and the live ones; a changed key set or order falls back to the whole pass. A batch that
## runs rules acts names every field (touch_person(-1)), so this applies to the people's own batches only.
static func _runtime_diff(v, row: Array, names: Dictionary) -> Variant:
	var live: Dictionary = v.runtime
	var image: Dictionary = fields["runtime"]
	if live.size() != image.size() or live.keys() != image.keys():
		return _field_diff(v, row, false)
	var each: Dictionary = twin_k["runtime"]
	var put := {}
	for k: Variant in live:
		var x: Variant = live[k]
		var t := typeof(x)
		if t == TYPE_DICTIONARY or t == TYPE_ARRAY or t == TYPE_OBJECT:
			if (names.has(k) or RUNTIME_LIVE.has(k)) and hash(x) != each.get(k):
				put[k] = true
		elif typeof(image[k]) != t or image[k] != x:
			put[k] = true
	return {"del": {}, "set": put} if not put.is_empty() else null


## A keyed map's changes at the named keys only, against the per-key hashes.
static func _keyed_diff(live: Dictionary, name: String, keys: Dictionary) -> Variant:
	if keys.is_empty():
		return null
	var image: Dictionary = fields[name]
	var each: Dictionary = twin_k[name]
	var del := {}
	var put := {}
	var added := []
	for k: Variant in keys:
		if not live.has(k):
			if image.has(k):
				del[k] = true
		elif not image.has(k):
			put[k] = true
			added.append(k)
		elif hash(live[k]) != each.get(k):
			put[k] = true
	if del.is_empty() and put.is_empty():
		return null
	if not added.is_empty():
		var order: Array = live.keys() # new keys must be the last ones, in this order, for a delta to keep it
		var tail: Array = order.slice(order.size() - added.size())
		added.sort_custom(func(a: Variant, b: Variant) -> bool: return order.rfind(a) < order.rfind(b))
		if tail != added:
			return true
	return {"del": del, "set": put}


static func empty(diff: Dictionary) -> bool:
	return diff.f.is_empty() and diff.p.is_empty() and diff.m.is_empty() and not diff.has("n") and not diff.has("x")


# ---------- moving parts between live and image ----------

## Copies the parts of a diff from the live village into the image. `enc` holds mind encodings stage() already made.
static func _take(v, diff: Dictionary, enc := {}) -> void:
	for name: String in diff.f:
		var d: Variant = diff.f[name]
		var live: Variant = v.get(name)
		if d is Dictionary and d.has("set"):
			var image: Dictionary = fields[name]
			for k: Variant in d.del:
				image.erase(k)
			for k: Variant in live:
				if d.set.has(k):
					image[k] = Codec._copy(live[k])
		elif d is Dictionary and d.has("at"):
			var image: Array = fields[name]
			image.resize(int(d.at)) # a merged diff may start before what the image already took
			for item: Variant in live.slice(int(d.at)):
				image.append(Codec._copy(item))
		else:
			fields[name] = Codec._copy(live)
		_twin_take(name, live, d)
	if diff.f.has("stagings"):
		kept = _kept(v)
	var n: int = v.people.size()
	for list: Array in [persons, twin_p, minds, hashes, known, attention, twin_m]:
		list.resize(mini(list.size(), n))
	var order: Array = diff.p.keys()
	order.sort()
	for i: int in order:
		var p = v.people[i]
		if i < persons.size():
			persons[i] = _copy_person(p)
			twin_p[i] = hash(_acc.person(p))
		else:
			persons.append(_copy_person(p))
			twin_p.append(hash(_acc.person(p)))
			for list: Array in [minds, hashes, known, attention, twin_m]:
				list.append(null)
			_mind_all(i, p.mind)
	for i: int in diff.m:
		if i < minds.size():
			_mind_take(i, v.people[i].mind, diff.m[i], enc.get(i, {}))


static func _mind_take(i: int, m, d: Dictionary, enc: Dictionary) -> void:
	var image: Dictionary = minds[i]
	var sums: Dictionary = hashes[i]
	for name: StringName in d:
		var part: Variant = d[name]
		if MAPS.has(name):
			var live: Dictionary = m.get(name)
			var entries: Dictionary = image[name]
			var each: Dictionary = sums[name]
			var made: Dictionary = enc.get(name, {})
			var fresh: Dictionary = enc.get(&"#h", part.get("h", {}) if part is Dictionary else {}) if name == &"appraised" else {}
			if part is Dictionary:
				for k: Variant in part.del:
					entries.erase(k)
					each.erase(k)
				for k: Variant in _set_order(live, part, entries):
					if live.has(k):
						entries[k] = made[k] if made.has(k) else var_to_bytes(live[k])
						each[k] = fresh[k] if fresh.has(k) else hash(live[k])
						if name == &"known":
							known[i][k] = live[k]
				if name == &"known":
					for k: Variant in part.del:
						known[i].erase(k)
			else:
				entries.clear()
				each.clear()
				for k: Variant in live:
					entries[k] = made[k] if made.has(k) else var_to_bytes(live[k])
					each[k] = hash(live[k])
				if name == &"known":
					known[i] = live.duplicate(false)
		elif name != &"#s":
			image[name] = enc[name] if enc.has(name) else _form(m, name)
			var small: Dictionary = d.get(&"#s", {})
			sums[name] = (enc[&"#e"] if enc.has(&"#e") else _episodes(m)) if name == &"episodes" else (small[name] if small.has(name) else hash(m.get(name)))
	_mind_marks(i, m, false)


static func _twin_take(name: String, live: Variant, d: Variant) -> void:
	twin_f[name] = -1 if live is Dictionary else hash(live) # maps are followed key by key; their whole hash is not kept
	if name == "events":
		_last_event = live.back() if not live.is_empty() else null
	if d is Dictionary and d.has("set") and twin_k.get(name) is Dictionary:
		var each: Dictionary = twin_k[name]
		for k: Variant in d.del:
			each.erase(k)
		for k: Variant in live:
			if d.set.has(k):
				each[k] = hash(live[k])
	elif d is Dictionary and d.has("at") and twin_k.get(name) is PackedInt64Array:
		var each: PackedInt64Array = twin_k[name]
		each.resize(int(d.at))
		for item: Variant in live.slice(int(d.at)):
			each.append(hash(item))
		twin_k[name] = each
	else:
		_twin(name, live)


## Puts the parts of a diff back from the image into the live village, into the same objects.
static func restore(v, diff: Dictionary) -> void:
	for name: String in diff.f:
		var d: Variant = diff.f[name]
		var live: Variant = v.get(name)
		var image: Variant = fields[name]
		if d is Dictionary and d.has("set") and live is Dictionary:
			if name == "runtime":
				d = {"del": d.del, "set": d.set.duplicate()}
				for k: String in RUNTIME_LIVE:
					d.set.erase(k) # not the batch's: stays live, written by the next line
			for k: Variant in d.set:
				if not image.has(k):
					live.erase(k)
			for k: Variant in d.del:
				live[k] = Codec._copy(image[k])
			for k: Variant in d.set:
				if image.has(k):
					live[k] = Codec._copy(image[k])
			if live.keys() != image.keys():
				v.set(name, Codec._copy(image))
		elif d is Dictionary and d.has("at") and live is Array:
			live.resize(int(d.at))
		else:
			v.set(name, Codec._copy(image))
		_twin(name, v.get(name))
	if diff.f.get("runtime") is Dictionary and diff.f.runtime.has("set"):
		var clock := {}
		for k: String in RUNTIME_LIVE:
			if v.runtime.has(k) and not same(v.runtime[k], fields.runtime.get(k)):
				clock[k] = true
		if not clock.is_empty():
			_absorb(v, {"f": {"runtime": {"del": {}, "set": clock}}, "p": {}, "m": {}}) # live clock: image now, disk next line
	var n: int = persons.size()
	if v.people.size() > n:
		v.people.resize(n)
	for i: int in diff.p:
		if i >= n:
			continue
		var p = v.people[i]
		_acc.set_person(p, Codec._copy(persons[i]))
		twin_p[i] = hash(_acc.person(p))
	for i: int in diff.m:
		if i < n:
			_mind_restore(i, v.people[i].mind, diff.m[i])


static func _mind_restore(i: int, m, d: Dictionary) -> void:
	var image: Dictionary = minds[i]
	var sums: Dictionary = hashes[i]
	for name: StringName in d:
		if name == &"#s":
			continue
		var part: Variant = d[name]
		if MAPS.has(name):
			var live: Dictionary = m.get(name)
			var entries: Dictionary = image[name]
			var each: Dictionary = sums[name]
			var keys: Array = part.set.keys() + part.del.keys() if part is Dictionary else live.keys() + entries.keys()
			for k: Variant in keys:
				if entries.has(k):
					live[k] = bytes_to_var(entries[k])
					each[k] = hash(live[k])
				else:
					live.erase(k)
			if live.keys() != entries.keys():
				var ordered := {}
				for k: Variant in entries:
					ordered[k] = live[k]
				m.set(name, ordered)
		elif name == &"episodes":
			var episodes: Array[S.Episode] = []
			for values: Array in bytes_to_var(image[name]):
				var e := S.Episode.new()
				_acc.set_episode(e, values)
				episodes.append(e)
			m.episodes = episodes
			sums[name] = _episodes(m)
		else:
			var value: Variant = bytes_to_var(image[name])
			var typed: Variant = m.get(name)
			if typed is Array and typed.is_typed():
				typed = typed.duplicate()
				typed.assign(value)
				value = typed
			m.set(name, value)
			sums[name] = hash(m.get(name))
	_mind_marks(i, m)


## Two diffs as one; a map change with new or removed keys, or a whole write, stays whole.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {"f": {}, "p": a.p.duplicate(), "m": {}}
	out.p.merge(b.p)
	for name: Variant in a.f.keys() + b.f.keys():
		out.f[name] = _merge_part(a.f.get(name), b.f.get(name))
	for i: Variant in a.m.keys() + b.m.keys():
		var x: Dictionary = a.m.get(i, {})
		var y: Dictionary = b.m.get(i, {})
		var part := {}
		for name: Variant in x.keys() + y.keys():
			if name != &"#s":
				part[name] = _merge_part(x.get(name), y.get(name))
		out.m[i] = part
	for flag: String in ["n", "x"]:
		if a.has(flag) or b.has(flag):
			out[flag] = true
	return out


static func _merge_part(x: Variant, y: Variant) -> Variant:
	if x == null:
		return y
	if y == null:
		return x
	if x is Dictionary and y is Dictionary and x.has("set") and y.has("set"):
		var del: Dictionary = x.del.duplicate()
		del.merge(y.del)
		var put: Dictionary = x.set.duplicate()
		put.merge(y.set)
		return {"del": del, "set": put}
	if x is Dictionary and y is Dictionary and x.has("at") and y.has("at"):
		return {"at": mini(int(x.at), int(y.at))}
	return true


## Parts changed outside acceptance join the image now and the next line later. A map change with new or removed
## keys is marked whole for that line, so it never assumes disk shares the image's order.
static func _absorb(v, diff: Dictionary) -> void:
	if empty(diff):
		return
	var later := {"f": {}, "p": diff.p.duplicate(), "m": {}}
	for name: String in diff.f:
		var d: Variant = diff.f[name]
		later.f[name] = d if d is Dictionary and (d.has("at") or (d.del.is_empty() and d.set.keys().all(func(k: Variant) -> bool: return fields[name].has(k)))) else true
	for i: int in diff.m:
		var part := {}
		for name: StringName in diff.m[i]:
			if name == &"#s":
				continue
			var d: Variant = diff.m[i][name]
			part[name] = d if d is Dictionary and d.del.is_empty() and d.set.keys().all(func(k: Variant) -> bool: return minds[i][name].has(k)) else true
		later.m[i] = part
	for flag: String in ["n", "x"]:
		if diff.has(flag):
			later[flag] = true
	_take(v, diff)
	unwritten = merge(unwritten, later) if not unwritten.is_empty() else later


# ---------- the acceptance steps ----------

## Before prepare: bind (a village the image does not describe is taken whole, once) and take in outside changes.
static func begin(v) -> void:
	hints = null
	People.clear_written() # receipts this batch changes (People.written, Mind M5) are named from here
	if not bound(v):
		rebase(v, false)
		_drift.clear()
		return
	var scope := {"m": _drift.duplicate(), "keys": {}}
	_drift.clear()
	var clock: Variant = v.runtime.get("now")
	if clock == _synced_now:
		scope.f = [] # the rules did not run: only the clock and the news moved, and a rollback leaves those live
		scope.p = {}
	_synced_now = clock
	var diff := changes(v, false, scope)
	if guard:
		var all := changes(v)
		for i: int in all.m:
			if not diff.m.has(i):
				print("FAIL save-image guard: mind %d changed outside acceptance without a mark (%s)" % [i, str(all.m[i].keys())])
		for name: String in all.f:
			var clock_only: bool = name == "runtime" and all.f[name] is Dictionary and all.f[name].has("set") and all.f[name].del.is_empty() and all.f[name].set.keys().all(func(k: Variant) -> bool: return RUNTIME_LIVE.has(k))
			if KEYED.has(name) or (scope.has("f") and not diff.f.has(name) and not clock_only):
				print("FAIL save-image guard: field %s changed outside acceptance (or with the clock still)" % name)
		for i: int in all.p:
			if not diff.p.has(i):
				print("FAIL save-image guard: person %d changed outside acceptance with the clock still" % i)
	_absorb(v, diff)


## After prepare: what it changed, limited to what it named when it named anything.
static func batch_changes(v) -> Dictionary:
	if hints != null and not hints.get("f_all", false):
		var only: Array = hints.f.keys() + KEYED
		if Events.logged != hints.logged:
			only.append_array(["events", "ev_hash"])
		hints.f = only # keyed maps are compared at their named keys only
		hints.rt = hints.keys.get("runtime", {}) # and the runtime's containers at the keys the batch named
	elif hints != null:
		hints.erase("f")
	if hints != null:
		hints.r = _receipts_written(v) # receipts are compared at the keys Mind recorded writing, for every mind
		for i: int in hints.r:
			hints.m[i] = true # and a mind that learned is compared, named or not
	return changes(v, false, hints)


## People.written() by person index: {i: {fact: true}} (Mind records every receipt it writes during play).
static func _receipts_written(v) -> Dictionary:
	var by_mind: Dictionary = People.written()
	var out := {}
	if by_mind.is_empty():
		return out
	for i in v.people.size():
		var keys: Variant = by_mind.get(v.people[i].mind.get_instance_id())
		if keys != null:
			out[i] = keys
	return out


## The journal line for a diff plus everything not yet on disk; kept in `staged` until commit() or unstage().
static func stage(v, diff: Dictionary) -> Dictionary:
	var all := merge(diff, unwritten) if not unwritten.is_empty() else diff
	Codec._used = {}
	var line := {"n": v.people.size()}
	var made := {}
	for i: int in all.p:
		if i < v.people.size():
			_put(line, "p", str(i), Codec.person_row(v.people[i]))
	for i in range(disk_n, v.people.size()):
		_put(line, "p", str(i), Codec.person_row(v.people[i]))
		_put(line, "mn", str(i), Codec.mind_row(v.people[i].mind))
	for i: int in all.m:
		if i >= disk_n or i >= v.people.size():
			continue
		var m = v.people[i].mind
		var change := {}
		var encodings := {}
		var batch: Dictionary = diff.m.get(i, {}) # parts this batch changed; the rest of `all` is as the image took it
		for name: StringName in all.m[i]:
			if name == &"#s":
				continue
			var d: Variant = all.m[i][name]
			if d is Dictionary:
				var entries := {}
				var part: Variant = batch.get(name)
				(change.get_or_add("d", {}) as Dictionary)[String(name)] = _map_line(m.get(name), d, entries, minds[i][name], true,
					part.set if part is Dictionary else ({} if part == null else null))
				encodings[name] = entries
			else:
				var value: Variant = null
				if not batch.has(name):
					value = minds[i][name] # as the image took it: its hashes stand too
					if name == &"episodes":
						encodings[&"#e"] = hashes[i][&"episodes"]
				elif name == &"episodes":
					var parts := _episode_parts(m)
					value = parts[0]
					encodings[&"#e"] = parts[1] # the hashes commit stores, from the same rows
				else:
					value = _form(m, name)
				encodings[name] = value
				(change.get_or_add("f", {}) as Dictionary)[String(name)] = value
		var scanned: Variant = diff.m.get(i, {}).get(&"appraised")
		if scanned is Dictionary and scanned.has("h"):
			encodings[&"#h"] = scanned.h # receipt hashes the scan just took, valid until commit
		made[i] = encodings
		if not change.is_empty():
			_put(line, "m", str(i), change)
	for row: Array in _fields:
		var name: String = row[0]
		if not all.f.has(name):
			continue
		var d: Variant = all.f[name]
		var live: Variant = v.get(name)
		if d is Dictionary and d.has("set"):
			_put(line, "fd", name, _map_line(live, d, {}, fields[name]))
		elif d is Dictionary and d.has("at"):
			var tail: Array = live.slice(int(d.at))
			var enc: Variant = Codec._enc_field(tail, row[1], row[2]) if row[1] == Codec.K.AOBJ else Codec._enc_any(tail)
			_put(line, "fa", name, {"at": int(d.at), "add": enc})
		elif name == "stagings":
			var keep := Codec._kept_stagings(v)
			_put(line, "f", name, Codec._enc_any(v.stagings.filter(func(st: Dictionary) -> bool: return keep.has(int(st.id)))))
		else:
			_put(line, "f", name, Codec._enc_field(live, row[1], row[2]))
	if all.has("x") or v.place_names.size() != places:
		var rebuilt := Codec._rebuilt_count(v)
		line.x = Array(v.place_names.slice(rebuilt)) if rebuilt >= 0 else []
	var schemas := {}
	for cls_name: String in Codec._used:
		if not _schemas.has(cls_name):
			_schemas[cls_name] = Codec._layout(cls_name).names.map(func(n: StringName) -> String: return String(n))
		schemas[cls_name] = _schemas[cls_name]
	line.schemas = schemas
	staged = {"line": line, "diff": all, "enc": made}
	return line


static func _put(line: Dictionary, part: String, key: String, value: Variant) -> void:
	(line.get_or_add(part, {}) as Dictionary)[key] = value


## A map delta for a line; `entries` receives each written value (native key -> bytes, or encoded when not `raw`).
## `changed`: the keys this batch changed when the rest were taken into the image unchanged since (their bytes are
## reused); null encodes every key.
static func _map_line(live: Dictionary, d: Dictionary, entries: Dictionary, image: Dictionary, raw := false, changed: Variant = null) -> Dictionary:
	var put := []
	for k: Variant in _set_order(live, d, image):
		if live.has(k):
			var value: Variant = (var_to_bytes(live[k]) if changed == null or changed.has(k) or not image.has(k) else image[k]) if raw else Codec._enc_any(live[k])
			entries[k] = value
			put.append([Codec._enc_any(k), value])
	var del := []
	for k: Variant in d.del.keys() + d.set.keys():
		if not live.has(k):
			del.append(Codec._enc_any(k))
	return {"del": del, "set": put}


## A delta's set keys in an order that keeps the map's: keys the image holds first, then new keys, which a map
## appends, in live order (the last keys of the live map); a delta reaching here adds keys of this batch only.
static func _set_order(live: Dictionary, d: Dictionary, image: Dictionary) -> Array:
	var old := []
	var fresh := {}
	for k: Variant in d.set:
		if image.has(k):
			old.append(k)
		else:
			fresh[k] = true
	if fresh.is_empty():
		return old
	var keys: Array = live.keys()
	var tail: Array = keys.slice(keys.size() - fresh.size())
	if tail.all(func(k: Variant) -> bool: return fresh.has(k)):
		old.append_array(tail)
		return old
	var order := []
	for k: Variant in live:
		if d.set.has(k):
			order.append(k)
	return order


## After the staged line is on disk: the image takes the written parts and nothing is left unwritten.
static func commit(v) -> void:
	if staged == null:
		return
	_take(v, staged.diff, staged.enc)
	disk_n = v.people.size()
	places = v.place_names.size()
	unwritten = {}
	staged = null


static func unstage() -> void:
	staged = null


# ---------- safety nets ----------

## Every frame: one more part compared (a mind by its hashes, not its encoding, to stay well inside a frame), so a
## change the cheap pass cannot see joins the next line.
static func sweep(v) -> void:
	if not bound(v) or staged != null:
		return
	var parts: int = _fields.size() + v.people.size()
	if parts <= 0:
		return
	_sweep = (_sweep + 1) % parts
	var diff := {"f": {}, "p": {}, "m": {}}
	if _sweep < _fields.size():
		var row: Array = _fields[_sweep]
		if not fields.has(row[0]):
			return
		var d: Variant = _field_diff(v, row)
		if d == null:
			return
		diff.f[row[0]] = d
	else:
		var i: int = _sweep - _fields.size()
		if i >= persons.size():
			return
		if not same(_acc.person(v.people[i]), persons[i]):
			diff.p[i] = true
		var d := _swept_mind(i, v.people[i].mind)
		if not d.is_empty():
			diff.m[i] = d
		if empty(diff):
			return
	swept += 1
	_absorb(v, diff)


## A mind against its stored hashes: every field and every entry, whatever the cheap gate says.
static func _swept_mind(i: int, m) -> Dictionary:
	var sums: Dictionary = hashes[i]
	var out := {}
	for name: StringName in _small:
		if hash(m.get(name)) != sums[name]:
			out[name] = true
	if _episodes(m) != sums[&"episodes"]:
		out[&"episodes"] = true
	for name: StringName in MAPS:
		var live: Dictionary = m.get(name)
		var each: Dictionary = sums[name]
		var d: Variant = _map_diff(live, minds[i][name], func(k: Variant) -> bool: return hash(live[k]) != each.get(k))
		if d != null:
			out[name] = d
	return out


## Tests: the image must equal the live village exactly (minds compared encoded); returns what differs.
static func verify(v) -> Array:
	if not bound(v):
		return ["unbound"]
	var diff := changes(v, true)
	var out := []
	for name: String in diff.f:
		var d: Variant = diff.f[name]
		out.append("field " + name + (" " + str(d.del.keys() + d.set.keys()) if d is Dictionary and d.has("set") else ""))
	for i: int in diff.p:
		out.append("person %d" % i)
	for i: int in diff.m:
		out.append("mind %d %s" % [i, str(diff.m[i].keys())])
	for flag: String in ["n", "x"]:
		if diff.has(flag):
			out.append(flag)
	return out

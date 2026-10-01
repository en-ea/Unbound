extends RefCounted
## The village's save: a closed, versioned codec that keeps what the future needs and nothing else
## (docs/studio/pass2/CONTRACTS.md, "The save"). It never deserializes executable objects or resources.
##
## Format 2 (written now):
## - Only the stagings that an open runtime event, pending act, hearing or rite refers to. Past ones are
##   scripts the stage already played.
## - No layout tables (`homes, place_*, dist2, n_places, pl_*, role_work`): after decode they are rebuilt with
##   Village.rebuild_places (make_places from the meadow layout, and the spots the rules add on attach). A village
##   on any other layout keeps its tables in the save.
## - Dead and faded people keep who they were but no beliefs, feelings, grudges or plan.
## - Compact: each class is written once as a field-name list ("schemas") and every object as a positional
##   array, trailing defaults dropped. Classes are found by reflection over state.gd, so a field the rules
##   add is carried without touching this file, and a save written before it still loads (missing means default).
## - A top-level field over BLOB_MIN characters is stored as a compressed blob {"z", "n", "m"}.
## - The Village stays a named `{"type": "Village", "fields": {...}}`, so a damaged field is one edit away.
## Format 1 (the first codec, `{"type", "fields"}` and `{"pairs"}` wrappers) still loads; to_data_v1 writes it.
##
## Numbers in untyped positions are canonical: a whole float is written as an int, so a village that went
## through JSON (all numbers floats) writes the same bytes as one that did not.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")

const VERSION := 2
const BLOB_MIN := 2048
const BLOB_MODE := FileAccess.COMPRESSION_ZSTD
const BLOB_NAME := "zstd"
const MAX_BLOB := 67108864
const MAX_DEPTH := 40
const EVENT_TYPES := ["public", "hearing", "rite", "incident"]
const PHASES := ["prepared", "active", "resolved", "cancelled"]
const TERMINAL := ["resolved", "cancelled"]
# Person fields a dead or faded person no longer needs (nothing reads them: plan_day clears the plan of
# anyone absent, minds() and gossip only visit the living and present).
const SLIM_PERSON := ["rel_k", "rel_v", "rel_abs", "grudge_k", "grudge_v", "beliefs", "plan"]
const DERIVED_NAMES := ["homes", "dist2", "n_places", "role_work"]

enum K { INT, STR, FLOAT, BOOL, PINT, PBYTE, PSTR, AINT, AOBJ, ADICT, OBJ, ANY }   # the first three are written as they are

static var _classes := {}      # name -> GDScript (every class in state.gd)
static var _names := {}        # GDScript -> name
static var _layouts := {}      # name -> {names, kinds, classes, slim, defaults}
static var _verified_sig := -1   # the place tables (and what they depend on) last shown to be a rebuild's, and how many places that was
static var _verified_count := 0
static var _used := {}         # class names met while encoding
static var _bad := false       # set by the decoder at the first thing that is not what it should be
static var _header := {}       # class name -> position in the array -> field index in the layout (-1: unknown)
static var _cache_in: Dictionary = {}
static var _cache_out: S.Village = null


# ---------- classes and layouts (by reflection over state.gd) ----------

static func _class_map() -> Dictionary:
	if _classes.is_empty():
		var source: GDScript = S
		var map := source.get_script_constant_map()
		for key: Variant in map:
			if map[key] is GDScript:
				_classes[String(key)] = map[key]
				_names[map[key]] = String(key)
		for cls_name: String in _classes:   # every layout now, so encoding never builds one (and never marks a class used)
			_layout(cls_name)
	return _classes


static func _layout(cls_name: String) -> Dictionary:
	if _layouts.has(cls_name):
		return _layouts[cls_name]
	var cls: GDScript = _class_map()[cls_name]
	var probe: Object = cls.new()
	var names: Array[StringName] = []
	var kinds := PackedInt32Array()
	var classes := PackedStringArray()
	var slim := PackedByteArray()
	for p: Dictionary in probe.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = probe.get(p.name)
		var kind := K.ANY
		var target := ""
		match int(p.type):
			TYPE_INT: kind = K.INT
			TYPE_STRING: kind = K.STR
			TYPE_BOOL: kind = K.BOOL
			TYPE_FLOAT: kind = K.FLOAT
			TYPE_PACKED_INT32_ARRAY: kind = K.PINT
			TYPE_PACKED_BYTE_ARRAY: kind = K.PBYTE
			TYPE_PACKED_STRING_ARRAY: kind = K.PSTR
			TYPE_ARRAY:
				var list: Array = value
				if list.is_typed() and list.get_typed_builtin() == TYPE_INT:
					kind = K.AINT
				elif list.is_typed() and list.get_typed_builtin() == TYPE_OBJECT and _names.has(list.get_typed_script()):
					kind = K.AOBJ
					target = _names[list.get_typed_script()]
				elif list.is_typed() and list.get_typed_builtin() == TYPE_DICTIONARY:
					kind = K.ADICT
			TYPE_OBJECT:
				if value != null and _names.has(value.get_script()):
					kind = K.OBJ
					target = _names[value.get_script()]
		names.append(StringName(p.name))
		kinds.append(kind)
		classes.append(target)
		slim.append(1 if cls_name == "Person" and SLIM_PERSON.has(String(p.name)) else 0)
	var layout := {"names": names, "kinds": kinds, "classes": classes, "slim": slim, "defaults": []}
	_layouts[cls_name] = layout
	var defaults := []
	for i in names.size():
		defaults.append(_enc_field(probe.get(names[i]), kinds[i], classes[i]))
	layout["defaults"] = defaults
	return layout


static func _slim(o: Object, cls_name: String) -> bool:
	return cls_name == "Person" and (not o.alive or o.faded)


# ---------- encode ----------

static func _enc_obj(o: Object, cls_name: String) -> Array:
	return _enc_list([o], cls_name)[0]


## Every object of one class, positional (the layout is looked up once for the list).
static func _enc_list(items: Array, cls_name: String) -> Array:
	_used[cls_name] = true
	var layout := _layout(cls_name)
	var names: Array = layout.names
	var kinds: PackedInt32Array = layout.kinds
	var classes: PackedStringArray = layout.classes
	var slim: PackedByteArray = layout.slim
	var defaults: Array = layout.defaults
	var count := names.size()
	var person := cls_name == "Person"
	var rows := []
	for o: Object in items:
		var thin: bool = person and (not o.alive or o.faded)
		var row := []
		for i in count:
			if thin and slim[i] == 1:
				row.append(defaults[i])
				continue
			var value: Variant = o.get(names[i])
			var kind := kinds[i]
			if kind <= K.FLOAT:
				row.append(value)
			elif kind == K.BOOL:
				row.append(1 if value else 0)
			else:
				row.append(_enc_field(value, kind, classes[i]))
		while not row.is_empty() and row[-1] == defaults[row.size() - 1]:   # trailing defaults are implied
			row.pop_back()
		rows.append(row)
	return rows


static func _enc_field(value: Variant, kind: int, target: String) -> Variant:
	match kind:
		K.BOOL:
			return 1 if value else 0
		K.PINT, K.PBYTE, K.PSTR:
			return Array(value)
		K.AINT:
			return value.duplicate()
		K.AOBJ:
			return _enc_list(value, target)
		K.OBJ:
			return _enc_obj(value, target)
		K.ADICT, K.ANY:
			return _enc_any(value)
	return value   # INT, STR, FLOAT


static func _enc_any(value: Variant) -> Variant:
	var kind := typeof(value)
	if kind == TYPE_INT or kind == TYPE_STRING or kind == TYPE_BOOL or kind == TYPE_NIL:
		return value
	match kind:
		TYPE_FLOAT:
			var f: float = value
			if f == floorf(f) and absf(f) < 9007199254740992.0:
				return int(f)
			return f
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var out := []
			for item: Variant in value:
				var t := typeof(item)
				out.append(item if t == TYPE_INT or t == TYPE_STRING else _enc_any(item))
			return out
		TYPE_DICTIONARY:
			# A JSON object comes back with its keys sorted (JSON.stringify sorts them), and order is state here (the
			# oldest receipt is the first key; the rules walk dictionaries in order). So a plain object only when the
			# keys already are in that order; otherwise the ordered pairs.
			var plain: bool = not (value.has("@o") or value.has("@d"))
			if plain:
				var prev := ""
				var first := true
				for k: Variant in value:
					if not k is String or (not first and not (prev < k)):
						plain = false
						break
					prev = k
					first = false
			if plain:
				var out := {}
				for k: String in value:
					var item: Variant = value[k]
					var t := typeof(item)
					out[k] = item if t == TYPE_INT or t == TYPE_STRING else _enc_any(item)
				return out
			var flat := []
			for k: Variant in value:
				flat.append(_enc_any(k))
				flat.append(_enc_any(value[k]))
			return {"@d": flat}
		TYPE_OBJECT:
			assert(_names.has(value.get_script()), "unsupported village value")
			var cls_name: String = _names[value.get_script()]
			return {"@o": [cls_name] + _enc_obj(value, cls_name)}
	return value


## The stagings something still needs: an open (or still playing) runtime event, a pending act, a hearing, a rite.
static func _kept_stagings(v: S.Village) -> Dictionary:
	var keep := {}
	for a: Variant in v.pending:
		keep[int(a.staging)] = true
	for list: String in ["hearings", "rites"]:
		for a: Dictionary in v.runtime.get(list, []):
			keep[int(a.staging)] = true
	var now := int(v.runtime.get("now", 0))
	for e: Dictionary in v.runtime.get("events", []):
		if not TERMINAL.has(e.phase) or int(e.end) > now:
			keep[int(e.get("staging", e.id))] = true
	return keep


## Rebuilds the layout tables of a decoded village: the meadow layout and what the rules add when a runtime is
## attached (Enea's characters' spots: authored.gd).
static func _rebuild_places(v: S.Village) -> void:
	Village.rebuild_places(v)


## Everything the rebuild could depend on, folded to one number: the tables as they are, and which people are authored.
static func _place_signature(v: S.Village) -> int:
	var authored := []
	for p in v.people:
		var who: Variant = p.get(&"authored")
		if who is String and not who.is_empty():
			authored.append([p.id, who])
	return hash([v.place_names, v.place_x, v.place_z, v.place_has_pos, v.homes, authored])


## How many of this village's places a rebuild recreates, or -1 when its tables are not a rebuild's (another
## layout: nothing to rebuild them from, so they are saved). Places the rules added on the fly (named, at
## [0, 0]) may follow. The answer is remembered until the tables change, so a save pays for the rebuild once.
static func _rebuilt_count(v: S.Village) -> int:
	var sig := _place_signature(v)
	if sig == _verified_sig:
		return _verified_count
	var probe := S.Village.new()
	var layout := _layout("Village")
	for i in layout.names.size():   # what a load hands the rebuild: every field but the derived ones
		if not _derived(String(layout.names[i])):
			probe.set(layout.names[i], v.get(layout.names[i]))
	_rebuild_places(probe)
	var n := probe.place_names.size()
	var same := v.place_names.size() >= n and v.homes == probe.homes
	if same:
		for i in n:
			if v.place_names[i] != probe.place_names[i] or v.place_x[i] != probe.place_x[i] or v.place_z[i] != probe.place_z[i] or v.place_has_pos[i] != probe.place_has_pos[i]:
				same = false
				break
	if same:
		for i in range(n, v.place_names.size()):
			if v.place_x[i] != 0 or v.place_z[i] != 0 or v.place_has_pos[i] != 0:
				same = false
				break
	if not same:
		return -1
	_verified_sig = sig
	_verified_count = n
	return n


static func _derived(name: String) -> bool:
	return name.begins_with("pl_") or name.begins_with("place_") or DERIVED_NAMES.has(name)


static func _pack(enc: Variant, compress: bool) -> Variant:
	if not compress or not (enc is Array or enc is Dictionary):
		return enc
	var text := JSON.stringify(enc)
	if text.length() < BLOB_MIN:
		return enc
	var raw := text.to_utf8_buffer()
	var packed := raw.compress(BLOB_MODE)
	if packed.is_empty():
		return enc
	return {"z": Marshalls.raw_to_base64(packed), "n": raw.size(), "m": BLOB_NAME}


## The village as JSON-safe data. `compress` false keeps every field readable (the tests compare that form).
static func to_data(v: S.Village, compress: bool = true) -> Dictionary:
	_class_map()
	_used = {}
	var layout := _layout("Village")
	var names: Array = layout.names
	var kinds: PackedInt32Array = layout.kinds
	var classes: PackedStringArray = layout.classes
	var rebuilt := _rebuilt_count(v)
	var meadow := rebuilt >= 0
	var keep := _kept_stagings(v)
	var fields := {}
	for i in names.size():
		var name := String(names[i])
		if meadow and _derived(name):
			continue
		var enc: Variant
		if name == "stagings":
			var kept: Array = v.stagings.filter(func(st: Dictionary) -> bool: return keep.has(int(st.id)))
			enc = _enc_any(kept)
		else:
			enc = _enc_field(v.get(names[i]), kinds[i], classes[i])
		fields[name] = _pack(enc, compress)
	var schemas := {}
	for cls_name: String in _used:
		schemas[cls_name] = _layout(cls_name).names.map(func(n: StringName) -> String: return String(n))
	var data := {"version": VERSION, "layout": "meadow" if meadow else "saved", "schemas": schemas,
		"state": {"type": "Village", "fields": fields}}
	if meadow and v.place_names.size() > rebuilt:
		data["extra_places"] = Array(v.place_names.slice(rebuilt))
	return data


## The player's home village is the same for everyone: HOME_SEED, in every new game (Hilmi, 1 Oct). Other seeds are
## for testing (--village-seed=N, or --village-seed=random for a fresh one each run) and, later, for the villages the
## player finds on the map (each its own seed). The save keeps the seed with the village either way.
const HOME_SEED := 1

static func new_seed(args: PackedStringArray) -> int:
	for arg in args:
		if arg.begins_with("--village-seed="):
			var asked := arg.trim_prefix("--village-seed=")
			return maxi(1, randi()) if asked == "random" else int(asked)
	return HOME_SEED


## The first codec's format, kept so a test can write an old save and prove it still loads.
static func to_data_v1(v: S.Village) -> Dictionary:
	return {"version": 1, "state": _encode_v1(v)}


# ---------- decode ----------

static func _int(d: Variant) -> int:
	if d is int:
		return d
	if d is float and is_finite(d) and d == floorf(d) and absf(d) < 9007199254740992.0:
		return int(d)
	_bad = true
	return 0


static func _set_field(o: Object, name: StringName, kind: int, target: String, d: Variant, depth: int) -> void:
	match kind:
		K.INT:
			o.set(name, _int(d))
		K.STR:
			if d is String:
				o.set(name, d)
			else:
				_bad = true
		K.BOOL:
			if d is bool:
				o.set(name, d)
			elif d is int or d is float:
				o.set(name, d != 0)
			else:
				_bad = true
		K.FLOAT:
			if d is int or d is float:
				o.set(name, float(d))
			else:
				_bad = true
		K.PINT, K.PBYTE, K.PSTR:
			if not d is Array:
				_bad = true
				return
			if kind == K.PSTR:
				var strings := PackedStringArray()
				for item: Variant in d:
					if item is String:
						strings.append(item)
					else:
						_bad = true
				o.set(name, strings)
			elif kind == K.PBYTE:
				var bytes := PackedByteArray()
				for item: Variant in d:
					var n := _int(item)
					if n < 0 or n > 255:
						_bad = true
					bytes.append(n)
				o.set(name, bytes)
			else:
				var ints := PackedInt32Array()
				for item: Variant in d:
					ints.append(_int(item))
				o.set(name, ints)
		K.AINT, K.AOBJ, K.ADICT:
			if not d is Array:
				_bad = true
				return
			var list: Array = o.get(name)
			for item: Variant in d:
				if kind == K.AINT:
					list.append(_int(item))
				elif kind == K.AOBJ:
					var made: Object = _dec_obj(item, target, depth + 1)
					if made == null:
						return
					list.append(made)
				elif item is Dictionary:
					list.append(_dec_any(item, depth + 1))
				else:
					_bad = true
					return
		K.OBJ:
			var made: Object = _dec_obj(d, target, depth + 1)
			if made != null:
				o.set(name, made)
		_:
			o.set(name, _dec_any(d, depth + 1))


static func _dec_obj(d: Variant, cls_name: String, depth: int) -> Object:
	if not d is Array or depth > MAX_DEPTH or not _class_map().has(cls_name):
		_bad = true
		return null
	var map: Array = _header.get(cls_name, [])
	if d.size() > map.size():
		_bad = true
		return null
	var layout := _layout(cls_name)
	var names: Array = layout.names
	var kinds: PackedInt32Array = layout.kinds
	var classes: PackedStringArray = layout.classes
	var o: Object = _classes[cls_name].new()
	for i in d.size():
		var at: int = map[i]
		if at >= 0:
			_set_field(o, names[at], kinds[at], classes[at], d[i], depth)
		if _bad:
			return null
	return o


static func _dec_any(d: Variant, depth: int) -> Variant:
	if depth > MAX_DEPTH:
		_bad = true
		return null
	if d is Dictionary:
		if d.has("@o"):
			var tagged: Variant = d["@o"]
			if not tagged is Array or tagged.is_empty() or not tagged[0] is String:
				_bad = true
				return null
			return _dec_obj(tagged.slice(1), tagged[0], depth + 1)
		if d.has("@d"):
			var flat: Variant = d["@d"]
			if not flat is Array or flat.size() % 2 != 0:
				_bad = true
				return null
			var pairs := {}
			for i in range(0, flat.size(), 2):
				pairs[_dec_any(flat[i], depth + 1)] = _dec_any(flat[i + 1], depth + 1)
			return pairs
		var out := {}
		for k: Variant in d:
			out[k] = _dec_any(d[k], depth + 1)
		return out
	if d is Array:
		var list := []
		for item: Variant in d:
			list.append(_dec_any(item, depth + 1))
		return list
	if d is float and is_finite(d) and d == floorf(d) and absf(d) < 9007199254740992.0:
		return int(d)
	return d


static func _unpack(d: Variant) -> Variant:
	if not (d is Dictionary and d.size() == 3 and d.get("m") == BLOB_NAME and d.get("z") is String and (d.get("n") is int or d.get("n") is float)):
		return d
	var n := _int(d.n)
	if n < 0 or n > MAX_BLOB:
		_bad = true
		return null
	var raw := Marshalls.base64_to_raw(d.z).decompress(n, BLOB_MODE)
	if raw.size() != n:
		_bad = true
		return null
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK:
		_bad = true
		return null
	return parser.data


## Format 2 to a Village, or null when the data is not what it should be. Structure only; see _semantic.
static func _decode(data: Dictionary) -> S.Village:
	_bad = false
	_header = {}
	_class_map()
	var schemas: Variant = data.get("schemas")
	var state: Variant = data.get("state")
	if not schemas is Dictionary or not state is Dictionary or state.get("type") != "Village" or not state.get("fields") is Dictionary:
		return null
	for cls_name: Variant in schemas:
		var listed: Variant = schemas[cls_name]
		if not cls_name is String or not listed is Array or not _class_map().has(cls_name):
			return null
		var known: Array = _layout(cls_name).names
		var map := []
		for field_name: Variant in listed:
			map.append(known.find(StringName(field_name)) if field_name is String else -1)
		_header[cls_name] = map
	var fields: Dictionary = state.fields
	var layout := _layout("Village")
	var names: Array = layout.names
	var kinds: PackedInt32Array = layout.kinds
	var classes: PackedStringArray = layout.classes
	var meadow: bool = data.get("layout", "meadow") == "meadow"
	var v := S.Village.new()
	for i in names.size():
		var name := String(names[i])
		if not fields.has(name) or (meadow and _derived(name)):
			continue
		_set_field(v, names[i], kinds[i], classes[i], _unpack(fields[name]), 0)
		if _bad:
			return null
	if meadow:
		_rebuild_places(v)
		var extras: Variant = data.get("extra_places", [])
		if not extras is Array:
			return null
		for extra: Variant in extras:
			if not extra is String:
				return null
			Village.place_id(v, extra)
	return v


# ---------- one door in, one out ----------

static func from_data(data: Dictionary) -> S.Village:
	if is_same(data, _cache_in) and _cache_out != null:   # valid() has just decoded this very payload
		var made := _cache_out
		_cache_in = {}
		_cache_out = null
		return made
	var v := _load(data)
	return v


## Decodes and checks; null when the data is unusable. Leaves the result in a one-slot cache so that the
## valid() and from_data() a load makes back to back decode once.
static func _load(data: Dictionary) -> S.Village:
	var version: Variant = data.get("version")
	if not (version is int or version is float):
		return null
	var v: S.Village = null
	if version == 1:
		if not _valid_v1(data):
			return null
		v = _decode_v1(data.state) as S.Village
		if not v is S.Village or v.people.is_empty():
			return null
		# Migrate the first continuation snapshot without discarding accepted rescues.
		var defaults := {"hearings": [], "rites": [], "traces": [], "resolving": false, "challenge": false, "storm_cycle": 0}
		for key: String in defaults:
			if not v.runtime.has(key):
				v.runtime[key] = defaults[key]
		for e: Dictionary in v.runtime.events:
			for key: String in {"actors": [int(e.victim)], "testimony": [], "bribe": "", "challenge": 0, "source": null}:
				if not e.has(key):
					e[key] = {"actors": [int(e.victim)], "testimony": [], "bribe": "", "challenge": 0, "source": null}[key]
	elif version == VERSION:
		var fields: Variant = data.get("state", {}).get("fields") if data.get("state") is Dictionary else null
		if not fields is Dictionary:
			return null
		for required: String in ["runtime", "people", "households", "lineages"]:
			if not fields.has(required):
				return null
		v = _decode(data)
		if v == null or v.people.is_empty():
			return null
	else:
		return null
	if not _semantic(v, version == VERSION):
		return null
	return v


static func valid(data: Dictionary) -> bool:
	var v := _load(data)
	if v == null:
		return false
	_cache_in = data
	_cache_out = v
	return true


## What the rules rely on once a village is decoded: the clock, ids in range, plans over real places, events
## the runtime can act on. `strict` (format 2) also checks that every act waiting has its staging.
static func _semantic(v: S.Village, strict: bool) -> bool:
	var r := v.runtime
	if r.get("version") != 1:
		return false
	for key: String in ["version", "now", "fraction", "sequence"]:
		if not (r.get(key) is int or r.get(key) is float) or not is_finite(float(r[key])):
			return false
	if r.now < 0 or r.fraction < 0 or r.fraction >= 1 or not r.get("village") is String:
		return false
	if not r.get("events") is Array:
		return false
	for key: String in ["receipts", "residents", "players"]:
		if not r.get(key) is Dictionary:
			return false
	for i in v.people.size():
		var p := v.people[i]
		if p.id != i or p.household < 0 or p.household >= v.households.size() or p.lineage < 0 or p.lineage >= v.lineages.size() or p.plan.size() % 3 != 0:
			return false
		for j in range(2, p.plan.size(), 3):
			if p.plan[j] < 0 or p.plan[j] >= v.place_names.size():
				return false
	for e: Variant in r.events:
		if not e is Dictionary:
			return false
		for key: String in ["id", "victim", "from", "deadline", "end", "revision"]:
			if not (e.get(key) is int or e.get(key) is float):
				return false
		if int(e.victim) < 0 or int(e.victim) >= v.people.size() or not e.get("phase") in PHASES:
			return false
		if not e.get("type") in EVENT_TYPES or not e.get("shields") is Array:
			return false
		if e.type in ["hearing", "rite"] and not e.get("source") is S.Sched:
			return false
		if e.type == "incident" and e.get("source") != null and not e.source is S.Sched:
			return false
	if not strict:
		return true
	# format 2: whatever waits for the stage must have its staging, and a village needs its authority
	var have := {}
	for st: Dictionary in v.stagings:
		have[int(st.get("id", -1))] = true
	for a: S.PublicAct in v.pending:
		if a.s == null or not have.has(a.staging):
			return false
	for list: String in ["hearings", "rites"]:
		if not r.get(list) is Array:
			return false
		for a: Variant in r[list]:
			if not a is Dictionary or not a.get("s") is S.Sched or not have.has(int(a.get("staging", -1))):
				return false
	for e: Dictionary in r.events:   # (an incident is the lead's to define: its staging is not demanded here)
		if e.type != "incident" and (not TERMINAL.has(e.phase) or int(e.end) > int(r.now)):
			if not have.has(int(e.get("staging", e.id))):
				return false
	return v.authority < v.people.size() and v.priest < v.people.size()


# ---------- format 1 (the first codec), unchanged in what it reads and writes ----------

static func _encode_v1(value: Variant) -> Variant:
	if value is Object:
		var tag := ""
		_class_map()
		if _names.has(value.get_script()):
			tag = _names[value.get_script()]
		assert(not tag.is_empty(), "unsupported village value")
		var fields := {}
		for p: Dictionary in value.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				fields[p.name] = _encode_v1(value.get(p.name))
		return {"type": tag, "fields": fields}
	if value is Dictionary:
		var pairs := []
		for k: Variant in value:
			pairs.append([_encode_v1(k), _encode_v1(value[k])])
		return {"pairs": pairs}
	if value is Array or value is PackedInt32Array or value is PackedByteArray or value is PackedStringArray:
		var items := []
		for item: Variant in value:
			items.append(_encode_v1(item))
		return items
	return value


static func _decode_v1(data: Variant, template: Variant = null) -> Variant:
	if data is Dictionary and data.has("type"):
		if not _class_map().has(data.type) or not data.get("fields") is Dictionary:
			return null
		var obj: RefCounted = _classes[data.type].new()
		for p: Dictionary in obj.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and data.fields.has(p.name):
				obj.set(p.name, _decode_v1(data.fields[p.name], obj.get(p.name)))
		return obj
	if data is Dictionary and data.has("pairs"):
		var out := {}
		for pair: Array in data.pairs:
			var k: Variant = _decode_v1(pair[0])
			if k is float and k == floor(k):
				k = int(k)
			out[k] = _decode_v1(pair[1])
		return out
	if data is Array:
		if template is PackedInt32Array:
			return PackedInt32Array(data)
		if template is PackedByteArray:
			return PackedByteArray(data)
		if template is PackedStringArray:
			return PackedStringArray(data)
		var out: Array = template.duplicate() if template is Array else []
		out.clear()
		for item: Variant in data:
			var decoded: Variant = _decode_v1(item)
			if out.is_typed() and out.get_typed_builtin() == TYPE_INT:
				decoded = int(decoded)
			out.append(decoded)
		return out
	if template is int:
		return int(data)
	return data


static func _valid_v1(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("state") is Dictionary or data.state.get("type") != "Village":
		return false
	var fields: Variant = data.state.get("fields")
	if not fields is Dictionary or not fields.get("people") is Array or fields.people.is_empty():
		return false
	if not _valid_value_v1(data.state, null, 0):
		return false
	for required: String in ["runtime", "people", "households", "lineages", "place_names", "place_ids"]:
		if not fields.has(required):
			return false
	return true


static func _valid_value_v1(data: Variant, template: Variant, depth: int) -> bool:
	if depth > MAX_DEPTH:
		return false
	if data is Dictionary:
		if template != null and not (template is Object or template is Dictionary):
			return false
		if data.has("type"):
			if not _class_map().has(data.type) or not data.get("fields") is Dictionary:
				return false
			var obj: RefCounted = _classes[data.type].new()
			for p: Dictionary in obj.get_property_list():
				if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and data.fields.has(p.name):
					if not _valid_value_v1(data.fields[p.name], obj.get(p.name), depth + 1):
						return false
			return true
		if not data.get("pairs") is Array:
			return false
		for pair: Variant in data.pairs:
			if not pair is Array or pair.size() != 2 or not (pair[0] is String or pair[0] is int or pair[0] is float):
				return false
			if not _valid_value_v1(pair[1], null, depth + 1):
				return false
		return true
	if data is Array:
		for item: Variant in data:
			if template is PackedInt32Array or template is PackedByteArray or (template is Array and template.is_typed() and template.get_typed_builtin() == TYPE_INT):
				if not (item is int or item is float) or not is_finite(float(item)) or float(item) != floor(float(item)):
					return false
			if template is PackedStringArray and not item is String:
				return false
			if not _valid_value_v1(item, null, depth + 1):
				return false
			if template is Array and template.is_typed() and template.get_typed_builtin() == TYPE_OBJECT:
				if not item is Dictionary or not _class_map().has(item.get("type", "")) or _classes[item.type] != template.get_typed_script():
					return false
		return template == null or template is Array or template is PackedInt32Array or template is PackedByteArray or template is PackedStringArray
	if template is int:
		return (data is int or data is float) and is_finite(float(data)) and float(data) == floor(float(data))
	if template is String:
		return data is String
	if template is bool:
		return data is bool
	if template is Array or template is Dictionary or template is PackedInt32Array or template is PackedByteArray or template is PackedStringArray or template is Object:
		return false
	return data == null or data is String or data is int or data is float or data is bool

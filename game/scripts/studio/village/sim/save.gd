extends RefCounted
## A closed, versioned codec for simulation data, preserving ordered dictionaries and typed arrays.
## Never deserializes executable objects or resources from a save.
const S := preload("res://scripts/studio/village/sim/state.gd")
const TYPES := {"Village": S.Village, "Person": S.Person, "Belief": S.Belief, "Household": S.Household,
	"Lineage": S.Lineage, "Crime": S.Crime, "Case": S.Case, "Event": S.Event, "Sched": S.Sched,
	"PublicAct": S.PublicAct, "Stranger": S.Stranger, "Storm": S.Storm, "Director": S.Director}

static func encode(value: Variant) -> Variant:
	if value is Object:
		var tag := ""
		for name: String in TYPES:
			if value.get_script() == TYPES[name]:
				tag = name
		assert(not tag.is_empty(), "unsupported village value")
		var fields := {}
		for p: Dictionary in value.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				fields[p.name] = encode(value.get(p.name))
		return {"type": tag, "fields": fields}
	if value is Dictionary:
		var pairs := []
		for k: Variant in value:
			pairs.append([encode(k), encode(value[k])])
		return {"pairs": pairs}
	if value is Array or value is PackedInt32Array or value is PackedByteArray or value is PackedStringArray:
		var items := []
		for item: Variant in value:
			items.append(encode(item))
		return items
	return value

static func decode(data: Variant, template: Variant = null) -> Variant:
	if data is Dictionary and data.has("type"):
		if not TYPES.has(data.type) or not data.get("fields") is Dictionary:
			return null
		var obj: RefCounted = TYPES[data.type].new()
		for p: Dictionary in obj.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and data.fields.has(p.name):
				obj.set(p.name, decode(data.fields[p.name], obj.get(p.name)))
		return obj
	if data is Dictionary and data.has("pairs"):
		var out := {}
		for pair: Array in data.pairs:
			var k: Variant = decode(pair[0])
			if k is float and k == floor(k):
				k = int(k)
			out[k] = decode(pair[1])
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
			var decoded: Variant = decode(item)
			if out.is_typed() and out.get_typed_builtin() == TYPE_INT:
				decoded = int(decoded)
			out.append(decoded)
		return out
	if template is int:
		return int(data)
	return data

static func to_data(v: S.Village) -> Dictionary:
	return {"version": 1, "state": encode(v)}

static func from_data(data: Dictionary) -> S.Village:
	if not valid(data):
		return null
	var value: Variant = decode(data.state)
	if not value is S.Village or value.people.is_empty() or value.runtime.get("version") != 1:
		return null
	# Migrate the first continuation snapshot without discarding accepted rescues.
	var defaults := {"hearings": [], "rites": [], "traces": [], "resolving": false, "challenge": false, "storm_cycle": 0}
	for key: String in defaults:
		if not value.runtime.has(key):
			value.runtime[key] = defaults[key]
	for e: Dictionary in value.runtime.events:
		for key: String in {"actors": [int(e.victim)], "testimony": [], "bribe": "", "challenge": 0, "source": null}:
			if not e.has(key):
				e[key] = {"actors": [int(e.victim)], "testimony": [], "bribe": "", "challenge": 0, "source": null}[key]
	return value

static func valid(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("state") is Dictionary or data.state.get("type") != "Village":
		return false
	var fields: Variant = data.state.get("fields")
	if not fields is Dictionary or not fields.get("people") is Array or fields.people.is_empty():
		return false
	if not _valid_value(data.state, null, 0):
		return false
	for required: String in ["runtime", "people", "households", "lineages", "place_names", "place_ids"]:
		if not fields.has(required):
			return false
	var v: S.Village = decode(data.state)
	var r := v.runtime
	for key: String in ["version", "now", "fraction", "sequence"]:
		if not (r.get(key) is int or r.get(key) is float) or not is_finite(float(r[key])):
			return false
	if r.version != 1 or r.now < 0 or r.fraction < 0 or r.fraction >= 1 or not r.get("village") is String:
		return false
	for key: String in ["events"]:
		if not r.get(key) is Array:
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
		if int(e.victim) < 0 or int(e.victim) >= v.people.size() or not e.get("phase") in ["prepared", "active", "resolved", "cancelled"]:
			return false
		if not e.get("type") in ["public", "hearing", "rite"] or not e.get("shields") is Array:
			return false
		if e.type != "public" and not e.get("source") is S.Sched:
			return false
	return true

static func _valid_value(data: Variant, template: Variant, depth: int) -> bool:
	if depth > 40:
		return false
	if data is Dictionary:
		if template != null and not (template is Object or template is Dictionary):
			return false
		if data.has("type"):
			if not TYPES.has(data.type) or not data.get("fields") is Dictionary:
				return false
			var obj: RefCounted = TYPES[data.type].new()
			for p: Dictionary in obj.get_property_list():
				if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and data.fields.has(p.name):
					if not _valid_value(data.fields[p.name], obj.get(p.name), depth + 1):
						return false
			return true
		if not data.get("pairs") is Array:
			return false
		for pair: Variant in data.pairs:
			if not pair is Array or pair.size() != 2 or not (pair[0] is String or pair[0] is int or pair[0] is float):
				return false
			if not _valid_value(pair[1], null, depth + 1):
				return false
		return true
	if data is Array:
		for item: Variant in data:
			if template is PackedInt32Array or template is PackedByteArray or (template is Array and template.is_typed() and template.get_typed_builtin() == TYPE_INT):
				if not (item is int or item is float) or not is_finite(float(item)) or float(item) != floor(float(item)):
					return false
			if template is PackedStringArray and not item is String:
				return false
			if not _valid_value(item, null, depth + 1):
				return false
			if template is Array and template.is_typed() and template.get_typed_builtin() == TYPE_OBJECT:
				if not item is Dictionary or not TYPES.has(item.get("type", "")) or TYPES[item.type] != template.get_typed_script():
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

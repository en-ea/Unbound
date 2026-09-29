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
	if data.get("version") != 1 or not data.get("state") is Dictionary:
		return null
	var value: Variant = decode(data.state)
	if not value is S.Village or value.people.is_empty() or value.runtime.get("version") != 1:
		return null
	return value

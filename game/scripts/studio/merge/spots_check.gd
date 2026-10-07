extends RefCounted
## merge-enea M1: the village's spots are read from Enea's buildings (studio/village/sites.gd), headless:
##   godot --headless --path game --script res://scripts/studio/run.gd -- merge/spots_check
## Every home, door, pen and public place is listed; no place, door or pen stands inside one of his buildings, each
## home is his house's own spot and each door is his door_of.
const Sites := preload("res://scripts/studio/village/sites.gd")
const Houses := preload("res://scripts/world/village.gd")


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var inside := []
	var spots := {}
	for k: String in Sites.DOORS: spots["door " + k] = Sites.DOORS[k]
	for k: String in Sites.PENS: spots[k] = Sites.PENS[k]
	for k: String in Sites.PLACES: spots["place " + k] = Sites.PLACES[k]["at"]
	for name: String in spots:
		var p: Vector2 = spots[name]
		for h: Dictionary in Houses.HOUSES:
			var half: Vector3 = h["size"] * 0.5
			var at: Vector2 = h["at"]
			if p.distance_to(at) < minf(half.x, half.z):
				inside.append("%s %s in %s" % [name, str(p), String(h["model"]).get_file()])
		if name.begins_with("place ") and name != "place merchant" and name != "place mill":
			for t: Array in Sites._his_things():
				if p.distance_to(t[0]) < float(t[1]) + Sites.CLEAR - 0.01:
					inside.append("%s %s by his thing at %s" % [name, str(p), str(t[0])])
	out.append("SPOTS homes=%s" % str(Sites.HOMES))
	out.append("SPOTS doors=%s" % str(Sites.DOORS))
	out.append("SPOTS pens=%s" % str(Sites.PENS))
	out.append("SPOTS places=%s" % str(Sites.PLACES))
	var homes_ok := Sites.HOMES.size() == 6
	var doors_ok := true
	for i in Houses.HOUSES.size():
		var model := String(Houses.HOUSES[i]["model"]).get_file()
		if model.begins_with("house_"):
			var n := model.get_basename().trim_prefix("house_")
			homes_ok = homes_ok and Sites.HOMES.get(n) == Houses.HOUSES[i]["at"]
			doors_ok = doors_ok and Sites.DOORS.get(n) == Houses.door_of(i)
	out.append(("PASS" if homes_ok else "FAIL") + " spots: the six homes are his houses' own spots")
	out.append(("PASS" if doors_ok else "FAIL") + " spots: each door is his door_of")
	out.append(("PASS" if inside.is_empty() else "FAIL") + " spots: no door, pen or place stands inside one of his buildings %s" % str(inside))
	out.append(("PASS" if Sites.PLACES.has("mill") and Sites.PLACES.has("merchant") and Sites.PLACES["merchant"]["focus"] == Houses.MERCHANT_AT else "FAIL") + " spots: the mill and the merchant follow his windmill and merchant")
	return out

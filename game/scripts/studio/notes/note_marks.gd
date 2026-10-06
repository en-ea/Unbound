extends RefCounted
## What a finger drew over the frozen screen means, and how it is kept. Game-agnostic: "things" are whatever the
## game says is on screen, each {"id", "name", "screen": [x, y], "points": [[x, y], ...] (optional: feet, head)}
## in the screen's pixels; a circle round any of a thing's points names it.
##
##   NoteMarks.circled(strokes, things)    -> the ids inside a closed stroke, else the one nearest where it ended
##   NoteMarks.crop_rect(strokes, size)    -> the part of the screen the strokes cover, with a margin
##   NoteMarks.marked(screen, strokes)     -> a copy of the screen with the strokes drawn on

const CLOSED_WITHIN := 0.25    # a stroke whose ends meet within this share of its own size counts as a circle
const NEAREST_PX := 160.0      # a tap or an open stroke picks the nearest thing within this (at 1440 px high)
const MARGIN := 0.15           # of the crop's size, each side
const MIN_CROP := 240          # px, so a tap still crops something legible
const INK := Color(1.0, 0.25, 0.2)


## The ids of the things a set of strokes points at, most likely first.
static func circled(strokes: Array, things: Array, screen_h := 1440.0) -> Array:
	var inside := []
	var ends := []
	for stroke: PackedVector2Array in strokes:
		if stroke.size() >= 3 and _closed(stroke):
			for t: Dictionary in things:
				if not inside.has(t.id) and _all(t).any(func(q: Vector2) -> bool: return Geometry2D.is_point_in_polygon(q, stroke)):
					inside.append(t.id)
		elif stroke.size() > 0:
			ends.append(stroke[stroke.size() - 1])
	for end: Vector2 in ends:                  # taps and arrows: the nearest thing to where the finger lifted
		var best: Variant = null
		var best_d := NEAREST_PX * screen_h / 1440.0
		for t: Dictionary in things:
			var d: float = _all(t).map(func(q: Vector2) -> float: return q.distance_to(end)).min()
			if d < best_d:
				best_d = d
				best = t.id
		if best != null and not inside.has(best):
			inside.append(best)
	return inside


## The names of the circled `ids` among `things`. Ids are of two kinds - a resident's int, a string for Enea's people
## and creatures ("npc:brakk", "other:wolf:...") - and an int never equals a string (his note 233349 lost its names to
## that comparison).
static func names_of(ids: Array, things: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for id: Variant in ids:
		for t: Dictionary in things:
			if typeof(t.id) == typeof(id) and t.id == id:
				out.append(str(t.name))
	return out


## The rectangle around every stroke, grown by MARGIN and at least MIN_CROP, kept on the screen.
static func crop_rect(strokes: Array, size: Vector2i) -> Rect2i:
	var box := Rect2()
	var first := true
	for stroke: PackedVector2Array in strokes:
		for p in stroke:
			if first:
				box = Rect2(p, Vector2.ZERO)
				first = false
			else:
				box = box.expand(p)
	if first:
		return Rect2i()
	var grow := box.size * MARGIN
	box = box.grow_individual(grow.x, grow.y, grow.x, grow.y)
	var want := Vector2(maxf(box.size.x, MIN_CROP), maxf(box.size.y, MIN_CROP))
	want = want.min(Vector2(size))
	var corner := (box.get_center() - want * 0.5).clamp(Vector2.ZERO, Vector2(size) - want)   # moved in, not cut, at an edge
	return Rect2i(Rect2(corner, want))


## A copy of the screen with the strokes drawn in INK, about 0.4% of the screen's height thick.
static func marked(screen: Image, strokes: Array) -> Image:
	var out := screen.duplicate() as Image
	if out.get_format() != Image.FORMAT_RGB8 and out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	var r := maxi(2, int(out.get_height() * 0.004))
	for stroke: PackedVector2Array in strokes:
		for i in stroke.size():
			var a := stroke[i]
			var b := stroke[i + 1] if i + 1 < stroke.size() else a
			var steps := maxi(1, int(a.distance_to(b) / r))
			for s in steps + 1:
				var p := a.lerp(b, float(s) / steps)
				out.fill_rect(Rect2i(int(p.x) - r, int(p.y) - r, r * 2, r * 2).intersection(Rect2i(Vector2i.ZERO, out.get_size())), INK)
	return out


static func _closed(stroke: PackedVector2Array) -> bool:
	var box := Rect2(stroke[0], Vector2.ZERO)
	for p in stroke:
		box = box.expand(p)
	var span := maxf(box.size.x, box.size.y)
	return span > 0.0 and stroke[0].distance_to(stroke[stroke.size() - 1]) <= span * CLOSED_WITHIN


## A thing's main point and any others it gives ("points": its feet and head, say).
static func _all(t: Dictionary) -> Array:
	var out := [_at(t)]
	for q: Variant in t.get("points", []):
		if q is Array and q.size() >= 2:
			out.append(Vector2(q[0], q[1]))
	return out


static func _at(t: Dictionary) -> Vector2:
	var s: Variant = t.get("screen", null)
	return Vector2(s[0], s[1]) if s is Array and s.size() >= 2 else Vector2(INF, INF)

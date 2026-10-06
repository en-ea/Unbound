extends RefCounted
## P4 single nearby index. Steering owns each live snapshot; perception/offers query its same cells.
## grid(points,count,cell=5 metres)->cells indexed by numeric row; snapshot(points,rows) binds actor metadata.
## query(at,radius)->rows sorted by distance/key. Rows include {key,at,...}; render-hidden sensing rows are legal.
const CELL := 5.0
var cells := {}
var rows: Array = []
static func grid(points: PackedVector2Array, count: int, cell := CELL) -> Dictionary:
	var out := {}
	for i in count:
		var key := floori(points[i].x / cell) * 100003 + floori(points[i].y / cell)
		(out.get_or_add(key, []) as Array).append(i)
	return out
func snapshot(points: PackedVector2Array, metadata: Array) -> void:
	rows = metadata
	for i in rows.size():
		rows[i].at = points[i]
	cells = grid(points, rows.size())
func query(at: Vector2, radius: float) -> Array:
	var out: Array = []
	var cx := floori(at.x / CELL)
	var cz := floori(at.y / CELL)
	var span := ceili(radius / CELL)
	for x in range(cx - span, cx + span + 1):
		for z in range(cz - span, cz + span + 1):
			for i: int in cells.get(x * 100003 + z, []):
				if (rows[i].at as Vector2).distance_squared_to(at) <= radius * radius:
					out.append(rows[i])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := (a.at as Vector2).distance_squared_to(at)
		var db := (b.at as Vector2).distance_squared_to(at)
		return da < db or (da == db and str(a.key) < str(b.key)))
	return out

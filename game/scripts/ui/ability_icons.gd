extends RefCounted
## The class abilities' symbols for their touch buttons. `s` is about half the symbol's size, `cut` is the
## button's dark body colour (used to carve detail into the solid shapes). Returns false for an unknown id.


static func draw(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, cut: Color) -> bool:
	match id:
		"flame_dash":                          # a flame streaking right, speed lines behind it
			_flame(ci, c + Vector2(s * 0.3, 0), s * 0.95, 0.7, col, cut)
			for k in 3:
				var y := (k - 1) * s * 0.42
				var x0 := -s * (1.05 - absf(k - 1) * 0.25)
				ci.draw_line(c + Vector2(x0, y), c + Vector2(-s * 0.3, y), col, s * 0.13, true)
		"meteor":                              # a burning rock falling from the top right
			var rock := c + Vector2(-s * 0.32, s * 0.32)
			var d := Vector2(1, -1).normalized()
			var n := Vector2(-d.y, d.x)
			for k in 3:                        # three tails, the middle one longest
				var off := (k - 1) * s * 0.26
				var length := s * (1.25 if k == 1 else 0.9)
				ci.draw_colored_polygon(PackedVector2Array([rock + n * (off - s * 0.2), rock + n * (off + s * 0.2),
					rock + n * off * 1.4 + d * length]), Color(col, col.a * (1.0 if k == 1 else 0.65)))
			ci.draw_circle(rock, s * 0.46, col, true, -1.0, true)
			ci.draw_arc(rock, s * 0.3, PI * 0.2, PI * 1.05, 12, cut, s * 0.09, true)
		"cinderburst":                         # a ring of flame bursting out from a core
			for k in 8:
				var a := TAU * k / 8.0 - PI * 0.5
				var dir := Vector2(cos(a), sin(a))
				var side := Vector2(-dir.y, dir.x)
				var reach := s * (1.08 if k % 2 == 0 else 0.8)
				ci.draw_colored_polygon(PackedVector2Array([c + dir * s * 0.42 + side * s * 0.17, c + dir * reach,
					c + dir * s * 0.42 - side * s * 0.17]), col)
			ci.draw_arc(c, s * 0.42, 0.0, TAU, 32, col, s * 0.12, true)
			ci.draw_circle(c, s * 0.22, col, true, -1.0, true)
		"burrow":                              # diving down into the ground, dirt flying
			ci.draw_line(c + Vector2(0, -s * 1.0), c + Vector2(0, s * 0.05), col, s * 0.22, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.08), c + Vector2(s * 0.42, -s * 0.08),
				c + Vector2(0, s * 0.42)]), col)
			_mound(ci, c + Vector2(0, s * 0.62), s, col)
			ci.draw_circle(c + Vector2(-s * 0.78, s * 0.08), s * 0.1, col, true, -1.0, true)
			ci.draw_circle(c + Vector2(s * 0.8, s * 0.0), s * 0.12, col, true, -1.0, true)
			ci.draw_circle(c + Vector2(s * 0.62, -s * 0.32), s * 0.07, col, true, -1.0, true)
		"fault_line":                          # a crack running ahead, spikes bursting up along it
			var crack := PackedVector2Array([c + Vector2(-s * 1.0, s * 0.85), c + Vector2(-s * 0.5, s * 0.5),
				c + Vector2(-s * 0.3, s * 0.72), c + Vector2(s * 0.15, s * 0.38), c + Vector2(s * 0.32, s * 0.55),
				c + Vector2(s * 1.0, s * 0.2)])
			ci.draw_polyline(crack, col, s * 0.13, true)
			for spike: Array in [[-0.55, 0.42, 0.55], [0.05, 0.3, 0.9], [0.62, 0.3, 0.68]]:
				var foot := c + Vector2(s * spike[0], s * spike[1])
				ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-s * 0.2, 0), foot + Vector2(s * 0.04, -s * spike[2] - s * 0.15),
					foot + Vector2(s * 0.2, 0)]), col)
		"sinkhole":                            # the ground caving into a pit
			_ellipse(ci, c + Vector2(0, s * 0.1), Vector2(s * 1.0, s * 0.5), col, s * 0.13)
			_ellipse(ci, c + Vector2(0, s * 0.18), Vector2(s * 0.64, s * 0.3), Color(col, col.a * 0.8), s * 0.11)
			var pit := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				pit.append(c + Vector2(cos(a) * s * 0.3, s * 0.24 + sin(a) * s * 0.13))
			ci.draw_colored_polygon(pit, col)
			for side in [-1.0, 1.0]:           # stones tumbling in
				ci.draw_circle(c + Vector2(side * s * 0.55, -s * 0.55), s * 0.11, col, true, -1.0, true)
			ci.draw_line(c + Vector2(0, -s * 0.95), c + Vector2(0, -s * 0.4), col, s * 0.12, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.45), c + Vector2(s * 0.2, -s * 0.45),
				c + Vector2(0, -s * 0.18)]), col)
		"shadow_dance":                        # four cuts from four sides
			_slash(ci, c, PI * 0.25, s * 1.05, col)
			_slash(ci, c, PI * 0.75, s * 1.05, col)
			_slash(ci, c + Vector2(0, -s * 0.62), 0.0, s * 0.45, Color(col, col.a * 0.7))
			_slash(ci, c + Vector2(0, s * 0.62), PI, s * 0.45, Color(col, col.a * 0.7))
		"mirage":                              # you and your shadow double stepping out beside you
			_figure(ci, c + Vector2(-s * 0.42, -s * 0.02), s * 1.0, Color(col, col.a * 0.4))
			_figure(ci, c + Vector2(s * 0.34, s * 0.04), s * 1.05, col)
		"switch":                              # two arrows trading places
			var r := s * 0.72
			ci.draw_arc(c, r, PI * 1.12, PI * 1.88, 18, col, s * 0.17, true)
			ci.draw_arc(c, r, PI * 0.12, PI * 0.88, 18, col, s * 0.17, true)
			_arrow_head(ci, c, r, PI * 1.92, 1.0, s, col)
			_arrow_head(ci, c, r, PI * 0.92, 1.0, s, col)
			ci.draw_circle(c + Vector2(-s * 0.18, 0), s * 0.15, col, true, -1.0, true)
			ci.draw_circle(c + Vector2(s * 0.18, 0), s * 0.15, Color(col, col.a * 0.45), true, -1.0, true)
		"drown":                               # a sphere of water, half full, bubbles rising
			ci.draw_arc(c, s * 0.86, 0.0, TAU, 40, col, s * 0.14, true)
			var water := PackedVector2Array()
			for k in 17:                       # the surface, a gentle wave from left to right
				var t := k / 16.0
				water.append(c + Vector2(lerpf(-s * 0.66, s * 0.66, t), s * 0.08 - sin(t * TAU) * s * 0.1))
			for k in range(1, 16):             # then round the bottom of the sphere, back to the left
				var a := PI * k / 16.0
				water.append(c + Vector2(cos(a), sin(a)) * s * 0.66 + Vector2(0, s * 0.08 * (1.0 - sin(a))))
			ci.draw_colored_polygon(water, col)
			ci.draw_arc(c + Vector2(-s * 0.2, -s * 0.36), s * 0.13, 0.0, TAU, 16, col, s * 0.08, true)
			ci.draw_circle(c + Vector2(s * 0.18, -s * 0.52), s * 0.08, col, true, -1.0, true)
		"tempest":                             # a storm cloud, a bolt of lightning and rain
			var cloud := c + Vector2(0, -s * 0.3)
			ci.draw_circle(cloud + Vector2(-s * 0.42, s * 0.08), s * 0.34, col, true, -1.0, true)
			ci.draw_circle(cloud + Vector2(s * 0.02, -s * 0.12), s * 0.44, col, true, -1.0, true)
			ci.draw_circle(cloud + Vector2(s * 0.46, s * 0.1), s * 0.32, col, true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([cloud + Vector2(-s * 0.42, s * 0.1), cloud + Vector2(s * 0.46, s * 0.1),
				cloud + Vector2(s * 0.46, s * 0.42), cloud + Vector2(-s * 0.42, s * 0.42)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.12, s * 0.02), c + Vector2(-s * 0.2, s * 0.5),
				c + Vector2(s * 0.02, s * 0.5), c + Vector2(-s * 0.14, s * 1.0), c + Vector2(s * 0.34, s * 0.38),
				c + Vector2(s * 0.12, s * 0.38), c + Vector2(s * 0.3, s * 0.02)]), cut)   # the bolt cut into the cloud's foot
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.14, s * 0.12), c + Vector2(-s * 0.14, s * 0.56),
				c + Vector2(s * 0.04, s * 0.56), c + Vector2(-s * 0.1, s * 0.95), c + Vector2(s * 0.28, s * 0.42),
				c + Vector2(s * 0.1, s * 0.42), c + Vector2(s * 0.26, s * 0.12)]), col)
			for x: float in [-0.55, 0.62]:
				ci.draw_line(c + Vector2(s * x, s * 0.32), c + Vector2(s * (x - 0.14), s * 0.72), col, s * 0.1, true)
		"rime_wave":                           # a snowflake riding a wave of frost
			var flake := c + Vector2(0, -s * 0.32)
			for k in 3:
				var dir := Vector2.from_angle(PI * k / 3.0 + PI * 0.5) * s * 0.6
				ci.draw_line(flake - dir, flake + dir, col, s * 0.12, true)
				for end: Vector2 in [dir, -dir]:   # a little V at each tip
					var tip := flake + end * 0.62
					var side := end.orthogonal().normalized() * s * 0.18
					ci.draw_line(tip + end.normalized() * s * 0.18 + side, tip, col, s * 0.08, true)
					ci.draw_line(tip + end.normalized() * s * 0.18 - side, tip, col, s * 0.08, true)
			var wave := PackedVector2Array()
			for k in 25:
				var t := k / 24.0
				wave.append(c + Vector2(lerpf(-s * 1.05, s * 1.05, t), s * 0.68 - sin(t * TAU * 1.5) * s * 0.14))
			ci.draw_polyline(wave, col, s * 0.16, true)
		_:
			return false
	return true


## A teardrop flame, its tip bending `lean` towards the right.
static func _flame(ci: CanvasItem, c: Vector2, s: float, lean: float, col: Color, cut: Color) -> void:
	ci.draw_colored_polygon(_flame_points(c + Vector2(-s * 0.36, s * 0.3), s * 0.6, lean - 0.55), col)
	ci.draw_colored_polygon(_flame_points(c + Vector2(s * 0.34, s * 0.34), s * 0.52, lean + 0.35), col)
	ci.draw_colored_polygon(_flame_points(c, s, lean), col)
	ci.draw_colored_polygon(_flame_points(c + Vector2(-s * 0.02, s * 0.42), s * 0.42, lean * 0.6), cut)


static func _flame_points(c: Vector2, s: float, lean: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		var up := cos(a)                       # 1 at the tip, -1 at the base
		var x := sin(a) * pow(sin(a * 0.5), 1.4) * 0.62
		var h := (up + 1.0) * 0.5
		pts.append(c + Vector2((x + lean * h * h * 0.75) * s, -up * s * 0.95))
	return pts


static func _mound(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		pts.append(c + Vector2(lerpf(-s * 1.0, s * 1.0, t), -sin(t * PI) * s * 0.28))
	pts.append(c + Vector2(s * 1.0, s * 0.12))
	pts.append(c + Vector2(-s * 1.0, s * 0.12))
	ci.draw_colored_polygon(pts, col)


static func _ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for k in 41:
		var a := TAU * k / 40.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	ci.draw_polyline(pts, col, width, true)


## A curved blade cut through `c` along `angle`: thin at both ends, thick in the middle.
static func _slash(ci: CanvasItem, c: Vector2, angle: float, s: float, col: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var side := Vector2(-dir.y, dir.x)
	var one := PackedVector2Array()
	var two := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		var along := lerpf(-1.0, 1.0, t)
		var p := c + dir * s * along + side * s * (1.0 - along * along) * 0.22
		var w := s * 0.13 * sin(t * PI)
		one.append(p + side * w)
		two.append(p - side * w)
	two.reverse()
	ci.draw_colored_polygon(one + two, col)


## A person: a head and a body tapering to the feet.
static func _figure(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(0, -s * 0.66), s * 0.27, col, true, -1.0, true)
	var body := PackedVector2Array()
	for k in 9:                                # rounded shoulders
		var a := PI + PI * k / 8.0
		body.append(c + Vector2(cos(a) * s * 0.42, -s * 0.08 + sin(a) * s * 0.22))
	body.append(c + Vector2(s * 0.3, s * 0.95))
	body.append(c + Vector2(-s * 0.3, s * 0.95))
	ci.draw_colored_polygon(body, col)


static func _arrow_head(ci: CanvasItem, c: Vector2, r: float, at: float, turn: float, s: float, col: Color) -> void:
	var p := c + Vector2(cos(at), sin(at)) * r
	var out := Vector2(cos(at), sin(at))
	var fwd := Vector2(-sin(at), cos(at)) * turn
	ci.draw_colored_polygon(PackedVector2Array([p + fwd * s * 0.36, p + out * s * 0.3 - fwd * s * 0.05,
		p - out * s * 0.3 - fwd * s * 0.05]), col)

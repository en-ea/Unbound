// A speech bubble's backing (studio/people/speech.gd): a rounded box with a faint gold edge and a small tail
// pointing down at the speaker. Faces the camera and keeps one size on screen, like the words on it.
// The quad is the box plus the tail below it; sizes are in the label's pixels.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix;

uniform vec2 box_px = vec2(200.0, 60.0);     // the box (without the tail)
uniform float tail_px = 14.0;                 // how far the tail reaches below the box
uniform float radius_px = 18.0;
uniform vec4 fill : source_color = vec4(0.07, 0.055, 0.045, 0.86);
uniform vec4 edge : source_color = vec4(1.0, 0.82, 0.45, 0.55);
uniform float edge_px = 2.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float sc = -(MODELVIEW_MATRIX)[3].z;      // fixed size on screen
	MODELVIEW_MATRIX[0] *= sc;
	MODELVIEW_MATRIX[1] *= sc;
	MODELVIEW_MATRIX[2] *= sc;
}

float box_sdf(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 full = vec2(box_px.x, box_px.y + tail_px);
	vec2 px = UV * full;                                   // from the top left
	vec2 centre = vec2(box_px.x * 0.5, box_px.y * 0.5);
	float d = box_sdf(px - centre, box_px * 0.5, radius_px);
	// the tail: a triangle under the middle of the box
	float t = (px.y - box_px.y + 1.0) / max(tail_px, 1.0);        // 0 at the box's bottom, 1 at the tip
	float half_w = tail_px * 0.9 * (1.0 - t);
	float tail = (t >= 0.0 && t <= 1.0) ? abs(px.x - centre.x) - half_w : 1e5;
	float shape = min(d, tail);
	float aa = 1.0;
	float inside = 1.0 - smoothstep(-aa, aa, shape);
	float rim = smoothstep(-edge_px - aa, -edge_px, d) * (1.0 - smoothstep(-aa, aa, d)) * step(t, 0.0);
	vec3 col = mix(fill.rgb, edge.rgb, rim * edge.a);
	ALBEDO = col;
	ALPHA = inside * fill.a * COLOR.a / 0.8;                   // COLOR: the sprite's modulate (speech.gd fades it)
}

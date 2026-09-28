shader_type spatial;
// A quick star-shaped glint (an enemy about to strike): a bright four-point flare that turns to face
// the camera and is drawn on top. `t` runs 0..1 over its life: it flares up, spins a little, fades.
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform float t = 1.0;

void vertex() {
	float grow = sin(clamp(t, 0.0, 1.0) * 3.14159);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float a = t * 0.8;
	VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy * (0.35 + grow);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ray = exp(-abs(p.x) * 18.0) * exp(-abs(p.y) * 1.3) + exp(-abs(p.y) * 18.0) * exp(-abs(p.x) * 1.3);
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071;
	float ray2 = exp(-abs(q.x) * 30.0) * exp(-abs(q.y) * 5.0) + exp(-abs(q.y) * 30.0) * exp(-abs(q.x) * 5.0);
	float core = exp(-length(p) * 6.5) * smoothstep(1.0, 0.6, length(p));
	float fade = 1.0 - smoothstep(0.55, 1.0, t);
	ALBEDO = color.rgb * (ray * 1.8 + ray2 * 0.7 + core * 2.2) * fade * 1.8;
}

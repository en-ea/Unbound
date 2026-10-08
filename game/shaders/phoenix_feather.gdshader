shader_type spatial;
// Phoenix Wings: a fiery feather. UV.y runs root (0) to tip (1), UV.x across. Additive, flickering.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float fade = 1.0;
uniform float seed = 0.0;

void fragment() {
	float y = UV.y;
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	float flick = 0.75 + 0.25 * sin(TIME * 17.0 + seed * 7.0 + y * 9.0) * sin(TIME * 5.0 + seed * 3.0);
	float tongues = smoothstep(0.0, 0.35 + 0.15 * sin(TIME * 11.0 + y * 14.0 + seed), edge);
	vec3 hot = vec3(1.0, 0.95, 0.65);
	vec3 mid = vec3(1.0, 0.45, 0.08);
	vec3 cool = vec3(0.7, 0.08, 0.02);
	vec3 c = mix(hot, mid, smoothstep(0.0, 0.45, y));
	c = mix(c, cool, smoothstep(0.5, 1.0, y));
	c = mix(c, hot, pow(edge, 6.0) * (1.0 - y) * 0.6);
	float a = tongues * (1.0 - smoothstep(0.75, 1.0, y)) * flick * fade;
	ALBEDO = c * 1.25;
	ALPHA = clamp(a * 1.3, 0.0, 1.0);
}

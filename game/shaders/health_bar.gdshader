shader_type spatial;
// An enemy health bar drawn in one quad that always faces the camera: rounded dark frame, a red
// fill with a lighter top, a pale trail showing recent damage, and a notch per hit point.
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 1.0;    // eases down after a hit
uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform float segments = 5.0;
uniform float aspect = 7.5;                         // quad width / height

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float outer = box(p, vec2(aspect * 0.5, 0.5), 0.5);
	float inner = box(p, vec2(aspect * 0.5 - 0.16, 0.34), 0.34);
	float px = fwidth(p.y);
	float x = clamp((p.x + aspect * 0.5 - 0.16) / (aspect - 0.32), 0.0, 1.0);
	vec3 col = vec3(0.07, 0.05, 0.08);
	if (inner < 0.0) {
		col = vec3(0.2, 0.12, 0.13);
		if (x < trail) col = vec3(0.98, 0.9, 0.78);
		if (x < fill) col = mix(vec3(0.72, 0.12, 0.12), vec3(1.0, 0.42, 0.32), smoothstep(0.3, -0.3, p.y));
		float notch = abs(fract(x * segments + 0.5) - 0.5) / segments * (aspect - 0.32);
		if (x > 0.01 && x < 0.99) col *= mix(0.55, 1.0, smoothstep(0.02, 0.05, notch));
	}
	ALBEDO = col;
	ALPHA = alpha * (1.0 - smoothstep(-px, px, outer)) * 0.95;
}

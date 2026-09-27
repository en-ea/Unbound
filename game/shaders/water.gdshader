shader_type spatial;
// Pond water: darker in the middle, clear at the shore, with small moving ripples.
render_mode blend_mix, depth_draw_never, cull_back;

uniform vec4 shallow : source_color = vec4(0.42, 0.72, 0.72, 0.55);
uniform vec4 deep : source_color = vec4(0.10, 0.30, 0.42, 0.9);
uniform vec2 center;
uniform float radius = 10.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = clamp(distance(world_pos.xz, center) / radius, 0.0, 1.0);
	vec4 c = mix(deep, shallow, smoothstep(0.2, 1.0, d));
	vec2 p = world_pos.xz;
	vec2 ripple = vec2(
		sin(p.x * 1.4 + TIME * 1.1) + sin((p.x + p.y) * 2.3 + TIME * 1.7) * 0.5,
		sin(p.y * 1.7 - TIME * 0.9) + sin((p.x - p.y) * 2.1 - TIME * 1.3) * 0.5);
	vec3 n = normalize(vec3(ripple.x * 0.05, 1.0, ripple.y * 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
}

shader_type spatial;
// A thin fading ring, used for water ripples around the player's legs.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	float ring = smoothstep(0.75, 0.88, d) * smoothstep(1.0, 0.9, d);
	ALBEDO = vec3(0.9, 0.97, 1.0);
	ALPHA = ring * 0.6 * COLOR.a;
}

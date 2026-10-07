shader_type spatial;
// Studio: water class. Drown's sphere: clear in the middle, bright at the rim (looking through water), a slow wobble.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.30, 0.68, 0.95, 1.0);
uniform float wobble = 0.04;     // water wobbles; ice (the same shader, its own material) does not
uniform float core = 0.16;       // how clear the middle is

void vertex() {
	VERTEX += NORMAL * sin(TIME * 5.0 + VERTEX.y * 6.0 + VERTEX.x * 4.0) * wobble;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(tint.rgb, vec3(0.88, 0.98, 1.0), rim);
	ALPHA = mix(core, 0.9, rim);
}

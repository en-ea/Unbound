shader_type spatial;
// The stones' light for the story (story/intro.gd, story/awakening.gd): a column rooted in the ground, brightest
// at its foot, streaks running up it, fading into the sky. Additive, so it costs one cheap transparent pass.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.75, 0.95, 1.0, 1.0);
uniform float strength = 1.0;
uniform float flow = 1.0;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float edge = pow(facing, 2.2);
	float up = 1.0 - UV.y;                       // 0 at the foot, 1 at the top
	float foot = smoothstep(0.0, 0.015, up);
	float fade = foot * pow(1.0 - up, 1.6);
	float streak = 0.7 + 0.3 * sin(UV.x * 37.7 + TIME * 0.7) * sin(up * 40.0 - TIME * 6.0 * flow);
	ALBEDO = tint.rgb * strength * edge * fade * streak * (1.0 + 2.0 * (1.0 - smoothstep(0.0, 0.06, up)));
}

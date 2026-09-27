shader_type spatial;
// A soft column of light: bright in the middle, fading at the edges, top and bottom.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.65, 1.0);
uniform float strength = 0.35;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float edge = pow(facing, 3.0);
	float height = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.5, UV.y);
	float shimmer = 0.85 + 0.15 * sin(TIME * 0.9 + UV.x * 12.0);
	ALBEDO = tint.rgb * strength * edge * height * shimmer;
}

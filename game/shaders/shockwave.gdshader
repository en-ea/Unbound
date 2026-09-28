shader_type spatial;
// A heavy blow's shockwave: a bright ring on the ground that races outward and fades (t 0..1).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float t = 0.0;

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float r = 0.15 + 0.8 * (1.0 - pow(1.0 - t, 3.0));
	float w = mix(0.22, 0.08, t);
	float ring = smoothstep(r - w, r, d) * (1.0 - smoothstep(r, r + w * 0.6, d));
	float inner = (1.0 - smoothstep(0.0, r, d)) * 0.25 * (1.0 - t);
	ALBEDO = color.rgb * (ring + inner) * (1.0 - t) * 1.1;
}

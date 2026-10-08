shader_type spatial;
// The Hollow's eyes: a burning core that shows through the fog (story/hollow.gd). `open` 0..1.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.42, 0.18, 1.0);
uniform float open = 1.0;
uniform float glow = 1.0;    // 1: the eye itself; for the halo quad, a soft round falloff

void vertex() {
	// Always faces the camera, keeping the node's own width and height (an eye narrows by scaling y).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = length(c);
	float a;
	if (glow > 0.5) {
		a = pow(clamp(1.0 - d, 0.0, 1.0), 2.4) * 0.9;
	} else {
		a = smoothstep(1.0, 0.2, d);
	}
	float flick = 0.9 + 0.1 * sin(TIME * 13.0) * sin(TIME * 7.0);
	vec3 core = mix(tint.rgb, vec3(1.0, 0.95, 0.85), smoothstep(0.5, 0.0, d) * (1.0 - glow * 0.6));
	ALBEDO = core * a * open * flick * (glow > 0.5 ? 1.0 : 2.2);
}

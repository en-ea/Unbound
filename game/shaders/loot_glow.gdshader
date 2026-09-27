shader_type spatial;
// Glow for good drops. As a beam: a soft column (bright core, fading to the sides and the top)
// that turns to face the camera around its upright axis. As a disc: a soft pool of light on the ground.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform bool disc = false;
uniform float strength = 1.0;

void vertex() {
	if (!disc) {
		vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 front = normalize(cross(side, vec3(0.0, 1.0, 0.0)));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(front, 0.0), MODEL_MATRIX[3]);
	}
}

void fragment() {
	float a;
	if (disc) {
		float d = length(UV * 2.0 - 1.0);
		a = pow(max(1.0 - d, 0.0), 2.2) * 0.8;
	} else {
		float x = abs(UV.x * 2.0 - 1.0);
		float core = pow(1.0 - x, 4.0) + pow(1.0 - x, 12.0) * 0.8;
		float up = pow(UV.y, 2.0) * smoothstep(1.0, 0.94, UV.y);      // UV.y = 1 at the bottom
		a = core * up * (0.85 + 0.15 * sin(TIME * 3.0 + UV.y * 6.0));
	}
	ALBEDO = color.rgb * a * strength;
}

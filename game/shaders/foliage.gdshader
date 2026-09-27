shader_type spatial;
// Leaves, grass and flowers: the model's texture, cut-out edges and a gentle wind sway.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float alpha_cut = 0.5;
uniform float sway = 0.05;          // metres of movement at the top
uniform float sway_height = 1.0;    // model height where the sway is full

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	k *= k;
	float t = TIME * 1.4 + wp.x * 0.35 + wp.z * 0.22;
	VERTEX.x += (sin(t) * 0.7 + sin(t * 2.3) * 0.3) * sway * k;
	VERTEX.z += cos(t * 0.8) * sway * 0.5 * k;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = c.rgb * 0.35;
}

shader_type spatial;
// The Hollow and its tendrils (story/hollow.gd): living shadow. Near-black, opaque (cheap), a violet rim where it
// turns away from you, the surface slowly boiling. `lean` bends a tall part (a tendril) side to side.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(0.55, 0.32, 0.95, 1.0);
uniform float rim = 0.9;
uniform float boil = 0.05;
uniform float lean = 0.0;
uniform float base_y = -0.5;     // local height of the foot (tendrils sway more towards the tip)
uniform float tall = 1.0;

void vertex() {
	vec3 w = NODE_POSITION_WORLD;
	float t = TIME;
	float b = sin(t * 1.7 + VERTEX.y * 5.0 + VERTEX.x * 3.0 + w.x) * sin(t * 1.1 + VERTEX.z * 4.0 + w.z);
	VERTEX += NORMAL * b * boil;
	if (lean > 0.0) {
		float h = clamp((VERTEX.y - base_y) / tall, 0.0, 1.0);
		float k = h * h * lean;
		VERTEX.x += sin(t * 1.6 + w.x * 0.7 + h * 2.5) * k;
		VERTEX.z += cos(t * 1.3 + w.z * 0.7 + h * 2.0) * k;
	}
}

void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = pow(f, 3.0) * rim;
	float vein = 0.5 + 0.5 * sin(TIME * 2.0 + UV.y * 30.0 + UV.x * 12.0);
	ALBEDO = mix(vec3(0.012, 0.006, 0.02), rim_color.rgb, edge * (0.7 + 0.3 * vein));
}

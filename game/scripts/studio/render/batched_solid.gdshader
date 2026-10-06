shader_type spatial;
// Graphics S1: Enea's shaders/foliage_solid.gdshader for his solid-shaded props and scatter merged into one mesh per
// cell (a studio copy; keep in step with his). Two things his shader takes from the model and its material are baked
// per vertex by static_batch.gd instead:
//   colour: his albedo times the instance's tint, in COLOR, multiplying the shade he keeps in UV, UV2;
//   sway: he moves each vertex in the model's own x and z by its height in the model; a merged mesh has no model, so
//     CUSTOM0 holds the instance's x axis times the sway, CUSTOM1 its z axis times half the sway, and CUSTOM2.x the
//     height factor. The phase still comes from the vertex's world position, so the motion is his exactly.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform float flash = 0.0;
uniform float warn = 0.0;

varying float top_light;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 1.1 + wp.x * 0.25 + wp.z * 0.18;
	VERTEX += (CUSTOM0.xyz * (sin(t) * 0.7 + sin(t * 2.1) * 0.3) + CUSTOM1.xyz * cos(t * 0.8)) * CUSTOM2.x;
	top_light = smoothstep(-0.4, 0.9, normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y);
}

void fragment() {
	vec3 clump = vec3(UV.x, UV.y, UV2.x) * COLOR.rgb;
	ALBEDO = albedo.rgb * clump * mix(0.76, 1.02, top_light);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.92, 0.88), flash);
	ALBEDO = mix(ALBEDO, vec3(0.85, 0.16, 0.08), warn * 0.3);
	EMISSION = ALBEDO * glow + vec3(0.6) * flash + vec3(0.8, 0.14, 0.04) * warn * 0.3;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	RIM = 0.18;
	RIM_TINT = 0.7;
}

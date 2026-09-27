shader_type spatial;
// Faded copy of foliage_solid for a tree that hides the player: the same look, with a dither
// pattern cutting pixels away by `fade`. Only used on the one or two trees in the way, so the
// cost of discard stays tiny (the normal tree shader never discards).

uniform vec4 albedo : source_color = vec4(0.4, 0.58, 0.3, 1.0);
uniform float sway = 0.06;          // metres of movement at the top
uniform float sway_height = 6.0;    // model height where the sway is full
uniform float glow = 0.0;           // gentle self-light (glowing items)
uniform float fade = 1.0;           // 1 = solid, lower = more see-through

varying float top_light;
varying vec3 tint;

void vertex() {
	tint = INSTANCE_CUSTOM.rgb;
	if (tint == vec3(0.0)) {
		tint = vec3(1.0);   // not a MultiMesh instance
	}
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	k *= k;
	float t = TIME * 1.1 + wp.x * 0.25 + wp.z * 0.18;
	VERTEX.x += (sin(t) * 0.7 + sin(t * 2.1) * 0.3) * sway * k;
	VERTEX.z += cos(t * 0.8) * sway * 0.5 * k;
	// Lighter on top, darker underneath, like soft sky light on a leafy crown.
	top_light = smoothstep(-0.4, 0.9, normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y);
}

void fragment() {
	vec3 clump = vec3(UV.x, UV.y, UV2.x);
	const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	int cell = int(mod(FRAGCOORD.x, 4.0)) + int(mod(FRAGCOORD.y, 4.0)) * 4;
	if ((BAYER[cell] + 0.5) / 16.0 > fade) {
		discard;
	}
	ALBEDO = albedo.rgb * clump * tint * mix(0.76, 1.02, top_light);
	EMISSION = ALBEDO * glow;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	RIM = 0.18;
	RIM_TINT = 0.7;
}

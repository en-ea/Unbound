shader_type spatial;
// Solid leaf blobs (our own trees and bushes): soft two-tone shading, per-tree tint, wind sway.

uniform vec4 albedo : source_color = vec4(0.4, 0.58, 0.3, 1.0);
uniform float sway = 0.06;          // metres of movement at the top
uniform float sway_height = 6.0;    // model height where the sway is full

varying float top_light;

void vertex() {
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
	ALBEDO = albedo.rgb * COLOR.rgb * mix(0.7, 1.12, top_light);
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

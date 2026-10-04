shader_type spatial;
// The Shade's double (player/shadow_double.gd), and you for a moment when you slip through shadow
// (as an overlay). Near-black violet, a bright pulsing rim, glowing smoke crawling up it, and legs that
// trail off into smoke near the ground; it fades out as it ends.

render_mode blend_mix, depth_draw_always, cull_back, unshaded;

uniform vec4 body : source_color = vec4(0.04, 0.02, 0.08, 1.0);
uniform vec4 rim : source_color = vec4(0.7, 0.48, 1.0, 1.0);
uniform float fade = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// Smooth value noise.
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float n = noise(world_pos * vec3(5.0, 2.5, 5.0) + vec3(0.0, -TIME * 1.6, 0.0));
	float wisp = smoothstep(0.6, 0.92, n);
	float pulse = 0.8 + 0.2 * sin(TIME * 4.0);
	ALBEDO = body.rgb + rim.rgb * (edge * 1.2 * pulse + wisp * 0.4);
	float h = world_pos.y - NODE_POSITION_WORLD.y;
	float legs = smoothstep(0.0, 0.5, h + (n - 0.5) * 0.35);
	ALPHA = clamp((0.86 + edge * 0.14) * mix(0.15, 1.0, legs), 0.0, 1.0) * fade;
}

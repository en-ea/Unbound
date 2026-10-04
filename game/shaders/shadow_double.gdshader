shader_type spatial;
// The Shade's double (player/shadow_double.gd): you, made of shadow. Near-black violet, a thin glowing
// rim, and smoke that slowly crawls over it; it fades out as it ends.

render_mode blend_mix, depth_draw_always, cull_back, unshaded;

uniform vec4 body : source_color = vec4(0.05, 0.03, 0.09, 1.0);
uniform vec4 rim : source_color = vec4(0.62, 0.42, 1.0, 1.0);
uniform float fade = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 p = floor(world_pos * 9.0 + vec3(0.0, -TIME * 2.0, 0.0));
	float smoke = hash(p) * 0.25;
	ALBEDO = body.rgb + rim.rgb * (edge * 0.6 + smoke * 0.25);
	ALPHA = (0.82 + edge * 0.18) * fade;
}

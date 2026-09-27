shader_type spatial;
// Ground: vertex colours plus slow drifting cloud shadows.

uniform sampler2D cloud_noise : filter_linear, repeat_enable;
uniform float cloud_strength = 0.22;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float cloud = texture(cloud_noise, world_pos.xz * 0.008 + TIME * vec2(0.0035, 0.0015)).r;
	float shade = 1.0 - cloud_strength * smoothstep(0.5, 0.72, cloud);
	ALBEDO = COLOR.rgb * shade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}

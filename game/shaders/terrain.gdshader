shader_type spatial;
// Ground: faceted low-poly shading, grass/rock from vertex colours, crisp-edged dirt path and
// pond shore drawn per pixel, and slow drifting cloud shadows.

uniform sampler2D cloud_noise : filter_linear, repeat_enable;
uniform float cloud_strength = 0.22;
uniform vec2 path_points[12];
uniform int path_count = 0;
uniform vec2 pond_center;
uniform float pond_radius = 10.0;
uniform float water_y = -0.45;
uniform vec4 dirt_color : source_color = vec4(0.54, 0.44, 0.33, 1.0);
uniform vec4 sand_color : source_color = vec4(0.76, 0.69, 0.52, 1.0);
uniform vec4 mud_color : source_color = vec4(0.34, 0.37, 0.29, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float path_distance(vec2 p) {
	float best = 1e6;
	for (int i = 0; i < path_count - 1; i++) {
		vec2 a = path_points[i];
		vec2 ab = path_points[i + 1] - a;
		float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
		best = min(best, distance(p, a + ab * t));
	}
	return best;
}

void fragment() {
	// Flat (faceted) normals for the low-poly look.
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	vec3 c = COLOR.rgb;
	float wobble = texture(cloud_noise, world_pos.xz * 0.06).r - 0.5;
	float path = 1.0 - smoothstep(1.35, 1.55, path_distance(world_pos.xz) + wobble * 0.7);
	c = mix(c, dirt_color.rgb, path);
	float near_pond = 1.0 - smoothstep(pond_radius + 5.0, pond_radius + 7.0, distance(world_pos.xz, pond_center));
	float sand = (1.0 - smoothstep(water_y + 0.28, water_y + 0.36, world_pos.y + wobble * 0.15)) * near_pond;
	c = mix(c, sand_color.rgb, sand);
	c = mix(c, mud_color.rgb, (1.0 - smoothstep(water_y - 0.3, water_y - 0.1, world_pos.y)) * near_pond);
	float cloud = texture(cloud_noise, world_pos.xz * 0.008 + TIME * vec2(0.0035, 0.0015)).r;
	ALBEDO = c * (1.0 - cloud_strength * smoothstep(0.5, 0.72, cloud));
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}

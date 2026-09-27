shader_type spatial;
// Ground: grass colour with large soft patches and fine detail, soft shade baked under trees and
// rocks, a crisp-edged dirt path with darker edges, sand and wet sand at the pond, and slow
// drifting cloud shadows.

uniform sampler2D cloud_noise : filter_linear, repeat_enable;
uniform sampler2D shade_map : filter_linear, hint_default_white;   // baked soft shade (1 = open)
uniform float world_half = 80.0;
uniform float cloud_strength = 0.12;
uniform vec2 path_points[12];
uniform int path_count = 0;
uniform vec2 pond_center;
uniform float pond_radius = 10.0;
uniform float water_y = -0.45;
uniform vec4 dirt_color : source_color = vec4(0.55, 0.43, 0.31, 1.0);
uniform vec4 dirt_edge : source_color = vec4(0.42, 0.34, 0.24, 1.0);
uniform vec4 sand_color : source_color = vec4(0.8, 0.72, 0.54, 1.0);
uniform vec4 wet_sand : source_color = vec4(0.58, 0.52, 0.4, 1.0);
uniform vec4 mud_color : source_color = vec4(0.34, 0.37, 0.29, 1.0);
uniform vec4 patch_warm : source_color = vec4(0.66, 0.72, 0.36, 1.0);
uniform vec4 patch_cool : source_color = vec4(0.3, 0.5, 0.34, 1.0);

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
	vec2 p = world_pos.xz;
	vec3 c = COLOR.rgb;
	// Large soft patches: sunny yellow-greens and cooler greens.
	float big = texture(cloud_noise, p * 0.011 + vec2(0.3, 0.7)).r;
	float mid = texture(cloud_noise, p * 0.045 + vec2(0.1, 0.2)).r;
	// Clean, calm ground (Tunic-like): only broad soft colour shifts, no fine speckle.
	c = mix(c, patch_warm.rgb, smoothstep(0.55, 0.8, big) * 0.22);
	c = mix(c, patch_cool.rgb, smoothstep(0.45, 0.2, big) * 0.2);
	c *= 0.97 + 0.06 * mid;
	float fine = 0.5;

	float wobble = texture(cloud_noise, p * 0.06).r - 0.5;
	float pd = path_distance(p) + wobble * 0.7;
	float path = 1.0 - smoothstep(1.35, 1.5, pd);
	vec3 dirt = mix(dirt_color.rgb, dirt_edge.rgb, smoothstep(0.6, 1.4, pd)) * (0.92 + 0.16 * fine);
	c = mix(c, dirt, path);

	float near_pond = 1.0 - smoothstep(pond_radius + 5.0, pond_radius + 7.0, distance(p, pond_center));
	float h = world_pos.y + wobble * 0.15;
	float sand = (1.0 - smoothstep(water_y + 0.28, water_y + 0.36, h)) * near_pond;
	vec3 sand_c = mix(wet_sand.rgb, sand_color.rgb, smoothstep(water_y + 0.02, water_y + 0.14, h));
	c = mix(c, sand_c * (0.95 + 0.1 * fine), sand);
	c = mix(c, mud_color.rgb, (1.0 - smoothstep(water_y - 0.3, water_y - 0.1, world_pos.y)) * near_pond);

	// Soft shade under trees, rocks and bushes.
	float shade = texture(shade_map, (p + vec2(world_half)) / (2.0 * world_half)).r;
	c *= mix(0.6, 1.0, shade);

	float cloud = texture(cloud_noise, p * 0.008 + TIME * vec2(0.0035, 0.0015)).r;
	ALBEDO = c * (1.0 - cloud_strength * smoothstep(0.5, 0.72, cloud));
	ROUGHNESS = 1.0;
	SPECULAR = 0.12;
}

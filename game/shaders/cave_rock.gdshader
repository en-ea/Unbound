shader_type spatial;
// The cave's rock (cave.gd): per-face colours in the vertex colour (already linear), and the walls
// between the camera and you dissolve in a soft dither, so you never lose yourself behind rock.

render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec3 player_pos;
uniform vec3 camera_pos;
uniform float floor_y = 0.0;
uniform float cut_radius = 1.2;

varying vec3 world_pos;
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	if (world_pos.y > floor_y + 0.7) {
		vec3 focus = player_pos + vec3(0.0, 1.0, 0.0);
		vec3 ray = focus - camera_pos;
		float len = length(ray);
		float t = clamp(dot(world_pos - camera_pos, ray) / (len * len), 0.0, 1.0);
		float d = length(world_pos - (camera_pos + ray * t));
		float fade = 1.0 - smoothstep(cut_radius * 0.55, cut_radius, d);
		fade *= smoothstep(0.62, 0.75, t) * step(t, 0.97);   // only rock right in front of you
		ivec2 px = ivec2(FRAGCOORD.xy) % 4;
		float bayer = BAYER[px.y * 4 + px.x] / 16.0;          // an ordered dither
		if (fade > bayer + 0.02) {
			discard;
		}
	}
}

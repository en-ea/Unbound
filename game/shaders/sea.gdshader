shader_type spatial;
// Open sea (Sunreach's coast and the voyage): rolling world-space swells, turquoise shallows over the
// sand (from a baked depth map), a foam line at the shore, foam on the crests, sparkle in the sun.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 shallow : source_color = vec4(0.30, 0.86, 0.80, 0.72);
uniform vec4 mid_col : source_color = vec4(0.07, 0.55, 0.66, 0.92);
uniform vec4 deep : source_color = vec4(0.03, 0.22, 0.40, 1.0);
uniform vec4 foam : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform sampler2D depth_map : filter_linear, hint_default_black;   // r = water depth / 6 m (0 = dry land)
uniform float world_half = 128.0;
uniform bool use_depth = false;
uniform float swell = 0.35;          // wave height (the storm raises it)
uniform float wave_speed = 1.0;
uniform float darken = 0.0;          // storm gloom

varying vec3 world_pos;
varying float crest;

vec3 wave(vec2 p, vec2 dir, float len, float amp, float t) {
	float k = 6.2831 / len;
	float f = k * dot(dir, p) - t * sqrt(9.8 * k);
	return vec3(dir.x * cos(f) * amp * 0.6, sin(f) * amp, dir.y * cos(f) * amp * 0.6);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float damp = 1.0;
	if (use_depth) {
		float d = texture(depth_map, (wp.xz + vec2(world_half)) / (2.0 * world_half)).r;
		damp = smoothstep(0.0, 0.35, d) * 0.85 + 0.15;
	}
	vec3 w = wave(wp.xz, normalize(vec2(0.3, 1.0)), 23.0, swell, t)
		+ wave(wp.xz, normalize(vec2(-0.7, 0.6)), 13.0, swell * 0.55, t)
		+ wave(wp.xz, normalize(vec2(0.9, -0.2)), 7.0, swell * 0.3, t);
	w *= damp;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(w, 0.0)).xyz;
	crest = w.y / max(swell, 0.01);
	world_pos = wp + w;
}

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));      // faceted, like the land
	vec2 p = world_pos.xz;
	float depth = 1.0;
	if (use_depth) {
		depth = texture(depth_map, (p + vec2(world_half)) / (2.0 * world_half)).r;
		if (abs(p.x) > world_half || abs(p.y) > world_half) depth = 1.0;
	}
	vec4 c = mix(shallow, mid_col, smoothstep(0.02, 0.3, depth));
	c = mix(c, deep, smoothstep(0.3, 0.95, depth));
	float ripple = sin(p.x * 0.9 + TIME * 1.3) * sin(p.y * 0.7 - TIME * 1.1);
	float shore = use_depth ? (1.0 - smoothstep(0.0, 0.05 + ripple * 0.012, depth)) : 0.0;
	float cap = smoothstep(0.62, 0.95, crest + ripple * 0.15) * 0.6;
	c.rgb = mix(c.rgb, foam.rgb, max(shore * 0.85, cap));
	c.a = max(c.a, shore);
	c.rgb *= 1.0 - darken * 0.55;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}

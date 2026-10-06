shader_type spatial;
// Graphics S4: Enea's shaders/foliage_solid.gdshader for things that can burn, soak, break and be struck (a studio
// copy; keep in step with his). Identical to his while a thing's state is neutral. Each thing reads its own column of
// one shared state texture (render/thing_state.gd), picked by an instance uniform, so a change of state is a texel
// written: no material change, no draw call.
//   row 0: soot, char, wet, wear        row 1: flash (a brighten), shake, broken, ember        row 2: tint (1 - rgb), unused
// Column 0 is always neutral.

uniform vec4 albedo : source_color = vec4(0.4, 0.58, 0.3, 1.0);
uniform float sway = 0.06;
uniform float sway_height = 6.0;
uniform float glow = 0.0;
uniform float flash = 0.0;
uniform float warn = 0.0;
uniform sampler2D thing_state : filter_nearest;
instance uniform float thing_id = 0.0;

varying float top_light;
varying vec3 tint;
varying vec3 world;
varying vec4 s0;
varying vec4 s1;
varying vec3 s_tint;

void vertex() {
	int column = int(thing_id + 0.5);
	s0 = texelFetch(thing_state, ivec2(column, 0), 0);
	s1 = texelFetch(thing_state, ivec2(column, 1), 0);
	s_tint = vec3(1.0) - texelFetch(thing_state, ivec2(column, 2), 0).rgb;
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
	// Struck: a short shudder, more at the top than at the foot.
	float h = clamp(VERTEX.y * 0.6, 0.2, 1.0);
	VERTEX.x += sin(TIME * 47.0) * 0.05 * s1.g * h;
	VERTEX.z += cos(TIME * 41.0) * 0.03 * s1.g * h;
	// Broken: the whole piece is gone (its debris stands in for it).
	VERTEX *= step(s1.b, 0.5);
	top_light = smoothstep(-0.4, 0.9, normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y);
	world = wp;
}

// Cheap value noise on world position: blotches of soot and the cracks of char.
float blot(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = i.x + i.y * 57.0 + i.z * 113.0;
	vec4 a = fract(sin(vec4(n, n + 1.0, n + 57.0, n + 58.0)) * 43758.5453);
	vec4 b = fract(sin(vec4(n + 113.0, n + 114.0, n + 170.0, n + 171.0)) * 43758.5453);
	vec4 m = mix(a, b, f.z);
	vec2 e = mix(m.xy, m.zw, f.y);
	return mix(e.x, e.y, f.x);
}

void fragment() {
	vec3 clump = vec3(UV.x, UV.y, UV2.x);
	ALBEDO = albedo.rgb * clump * tint * mix(0.76, 1.02, top_light);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.92, 0.88), flash);
	ALBEDO = mix(ALBEDO, vec3(0.85, 0.16, 0.08), warn * 0.3);
	EMISSION = ALBEDO * glow + vec3(0.6) * flash + vec3(0.8, 0.14, 0.04) * warn * 0.3;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	RIM = 0.18;
	RIM_TINT = 0.7;
	// The thing's state (all zero at neutral: every line below then leaves his result exactly as it is).
	ALBEDO *= s_tint;
	float grey = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(ALBEDO, vec3(grey) * 1.12 + 0.04, s0.a * 0.6);                       // wear: bleached, worn
	float patch = blot(world * 2.3) * 0.6 + blot(world * 6.1) * 0.4;
	// Soot spreads in blotches as it grows; char follows it into dark charred wood that keeps the wood's own hue and
	// its grain's light and dark (Hilmi, 5 Oct: "dark charred wood rather than near-black"; full char the darkest).
	float sooted = min(1.0, s0.r * 2.0) * smoothstep(patch - 0.3, patch + 0.1, s0.r);
	ALBEDO = mix(ALBEDO, ALBEDO * 0.6 + vec3(0.02, 0.015, 0.01), sooted * 0.8);
	float charred = min(1.0, s0.g * 2.0) * smoothstep(patch - 0.2, patch + 0.1, s0.g);
	vec3 char_wood = (ALBEDO * vec3(0.5, 0.42, 0.36) + vec3(0.045, 0.028, 0.016)) * (0.78 + 0.44 * patch);
	ALBEDO = mix(ALBEDO, char_wood, charred);
	float ridge = abs(blot(world * 7.0) - 0.5);
	float crack = (1.0 - smoothstep(0.0, 0.045, ridge)) * charred;
	EMISSION += vec3(1.0, 0.36, 0.06) * crack * s1.a * 3.0;                            // ember: the cracks glow
	ALBEDO *= mix(1.0, 0.62, s0.b);                                                   // wet: darker
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.92, 0.96, 1.04), s0.b);                      //   and a touch cooler
	ROUGHNESS = mix(ROUGHNESS, 0.32, s0.b);                                            //   and glossy
	SPECULAR = mix(SPECULAR, 0.5, s0.b);
	EMISSION += ALBEDO * 0.45 * s1.r;                                                  // struck: a brief brighten
}

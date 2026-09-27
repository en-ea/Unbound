shader_type spatial;
// Small critters drawn in one batch (MultiMesh). Parts further than a body's width from the
// centre line are wings: they flap around the body axis. Per instance (INSTANCE_CUSTOM):
// x = phase, y = flap amount (radians), z = resting wing angle, w = fold (1 = wings tucked in).
render_mode cull_disabled, specular_disabled;

uniform float flap_speed = 16.0;
varying vec3 tint;

void vertex() {
	float ax = abs(VERTEX.x);
	float wing = smoothstep(0.012, 0.05, ax);
	float a = INSTANCE_CUSTOM.z + sin(TIME * flap_speed * (0.85 + INSTANCE_CUSTOM.x * 0.3) + INSTANCE_CUSTOM.x * 6.283) * INSTANCE_CUSTOM.y;
	float span = ax * mix(1.0, 0.35, INSTANCE_CUSTOM.w);
	VERTEX.x = mix(VERTEX.x, sign(VERTEX.x) * span * cos(a), wing);
	VERTEX.y += span * sin(a) * wing;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
}

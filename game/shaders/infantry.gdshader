shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Baked infantry mesh: COLOR.rgb albedo, COLOR.a part id, UV (metal, rough), UV2 (team, emission).
// INSTANCE_CUSTOM: x walk phase 0..1, y walk amount, z recoil, w death 0..1.
uniform vec3 team_color : source_color = vec3(0.12, 0.22, 0.52);
uniform vec3 glow_color : source_color = vec3(0.35, 0.85, 1.0);
uniform float glow_energy = 3.5;

varying vec3 v_albedo;
varying vec2 v_mr;
varying vec2 v_te;

mat2 rot2(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

void vertex() {
	float part = COLOR.a;
	vec4 cd = INSTANCE_CUSTOM;
	float phase = cd.x * 6.28318;
	float walk = cd.y;
	vec3 v = VERTEX;
	if (part > 0.15 && part < 0.6) {
		float side = part < 0.35 ? 1.0 : -1.0;
		float ang = sin(phase) * 0.6 * walk * side;
		vec2 yz = v.yz - vec2(1.0, 0.0);
		v.yz = rot2(ang) * yz + vec2(1.0, 0.0);
	}
	if (part > 0.6) {
		v.z -= cd.z * 0.16;
		v.y += cd.z * 0.03 + sin(phase * 2.0) * 0.02 * walk;
	}
	v.y += abs(sin(phase)) * 0.05 * walk;
	if (cd.w > 0.0) {
		float fall = smoothstep(0.0, 0.45, cd.w) * 1.5;
		v.yz = rot2(-fall) * v.yz;
		v.y -= smoothstep(0.55, 1.0, cd.w) * 0.7;
	}
	VERTEX = v;
	v_albedo = COLOR.rgb;
	v_mr = UV;
	v_te = UV2;
}

void fragment() {
	vec3 base = mix(v_albedo, team_color * v_albedo * 2.0, v_te.x);
	ALBEDO = mix(base, glow_color * 0.6, v_te.y);
	METALLIC = v_mr.x;
	ROUGHNESS = clamp(v_mr.y, 0.05, 1.0);
	EMISSION = glow_color * v_te.y * glow_energy;
}

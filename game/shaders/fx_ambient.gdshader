shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Looping ambient smoke (chimneys, waterfall spray). Each instance replays one puff forever;
// the per-cycle randomness comes from hashing the instance seed with the cycle number.
// MODEL_MATRIX columns: 0 = base velocity, 1 = velocity jitter, 2 = (spread xz, spread y, wind), 3 = origin.
// INSTANCE_CUSTOM = (phase, life, size start, size end). COLOR = tint and peak alpha.

uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform float soft_distance = 1.6;
uniform float drag = 0.9;
uniform vec3 wind = vec3(0.45, 0.2, 0.12);

varying float v_t;

vec4 hash4(vec2 p) {
	vec4 p4 = fract(p.xyxy * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

void vertex() {
	float life = INSTANCE_CUSTOM.y;
	float u = TIME / life + INSTANCE_CUSTOM.x;
	float cycle = floor(u);
	float t = u - cycle;
	float age = t * life;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float seed = dot(origin, vec3(0.131, 0.717, 0.373)) + INSTANCE_CUSTOM.x * 97.0;
	vec4 r = hash4(vec2(seed, cycle));
	vec4 q = hash4(vec2(cycle + 0.5, seed * 1.37));
	vec3 spread = MODEL_MATRIX[2].xyz;
	vec3 p = origin + vec3((r.x - 0.5) * 2.0 * spread.x, r.y * spread.y, (r.z - 0.5) * 2.0 * spread.x);
	vec3 v0 = MODEL_MATRIX[0].xyz + (q.xyz - 0.5) * 2.0 * MODEL_MATRIX[1].xyz;
	p += v0 * (1.0 - exp(-drag * age)) / drag + wind * spread.z * age;
	float size = mix(INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w, sqrt(t));
	float ang = r.w * TAU + (q.w - 0.5) * 0.6 * age;
	float c = cos(ang);
	float s = sin(ang);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, vec4(p, 1.0));
	v_t = t;
}

void fragment() {
	vec4 tx = texture(tex, UV);
	float fade = smoothstep(0.0, 0.08, v_t) * (1.0 - smoothstep(0.5, 1.0, v_t));
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	vp.xyz /= vp.w;
	float soft = clamp((VERTEX.z - vp.z) / soft_distance, 0.0, 1.0);
	float lit = mix(0.75, 1.15, UV.y < 0.5 ? 1.0 - UV.y : 0.5);
	ALBEDO = COLOR.rgb * tx.rgb * lit;
	ALPHA = tx.a * COLOR.a * fade * soft;
}

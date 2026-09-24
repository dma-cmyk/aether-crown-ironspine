shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/compat.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D wave_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow_color : source_color = vec3(0.10, 0.28, 0.27);
uniform vec3 deep_color : source_color = vec3(0.015, 0.06, 0.08);
uniform vec3 foam_color : source_color = vec3(0.86, 0.92, 0.93);
uniform float depth_fade = 3.2;
uniform float flow_speed = 1.8;

varying vec3 wpos;
varying vec3 flow;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow = vec3(COLOR.r * 2.0 - 1.0, 0.0, COLOR.g * 2.0 - 1.0) * COLOR.b;
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * depth_ndc(SCREEN_UV, raw);
	v.xyz /= v.w;
	float water_depth = max(0.0, (-v.z) - (-VERTEX.z));
	float d = clamp(water_depth / depth_fade, 0.0, 1.0);

	vec2 f = flow.xz * flow_speed;
	float ph0 = fract(TIME * 0.22);
	float ph1 = fract(TIME * 0.22 + 0.5);
	float mixw = abs(ph0 * 2.0 - 1.0);
	vec2 uv = wpos.xz / 8.0;
	vec3 na = texture(wave_a, uv - f * ph0 * 0.9).xyz * 2.0 - 1.0;
	vec3 nb = texture(wave_a, uv - f * ph1 * 0.9 + vec2(0.5, 0.25)).xyz * 2.0 - 1.0;
	vec3 nf = mix(na, nb, mixw);
	vec3 nd = texture(wave_b, wpos.xz / 21.0 + vec2(TIME * 0.011, -TIME * 0.008)).xyz * 2.0 - 1.0;
	vec3 tn = nf + nd * 0.55;
	vec3 wn = normalize(vec3(tn.x * 0.45, 1.0, -tn.y * 0.45));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	float speed = length(flow);
	float fa = texture(foam_noise, uv * 1.7 - f * ph0 * 0.9).r;
	float fb = texture(foam_noise, uv * 1.7 - f * ph1 * 0.9 + vec2(0.37, 0.61)).r;
	float fn = mix(fa, fb, mixw);
	float shore = 1.0 - smoothstep(0.0, 1.1, water_depth);
	float foam = smoothstep(0.6, 0.9, fn + shore * 0.45) * (shore * 0.9 + speed * 0.08);
	vec3 col = mix(shallow_color, deep_color, d);
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = mix(0.04, 0.4, foam);
	SPECULAR = 0.5;
	METALLIC = 0.1;
	ALPHA = clamp(0.35 + d * 0.62 + foam, 0.0, 1.0);
}

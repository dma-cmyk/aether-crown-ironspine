shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/compat.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 400.0;
uniform vec3 fog_color : source_color = vec3(0.03, 0.04, 0.06);

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	if (depth_is_sky(raw)) {
		discard;
	}
	vec4 ndc = depth_ndc(SCREEN_UV, raw);
	vec4 wp = INV_VIEW_MATRIX * (INV_PROJECTION_MATRIX * ndc);
	wp.xyz /= wp.w;
	vec2 uv = wp.xz / map_size + 0.5;
	float f = texture(fog_tex, uv).r;
	float outside = step(1.0, max(abs(uv.x * 2.0 - 1.0), abs(uv.y * 2.0 - 1.0)));
	f = mix(f, 0.235, outside);
	ALBEDO = fog_color;
	ALPHA = clamp((1.0 - f) * 0.85, 0.0, 0.8);
}

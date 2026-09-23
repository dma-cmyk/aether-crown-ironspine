shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform float soft_distance = 1.6;

varying float v_t;

void vertex() {
	float r = INSTANCE_CUSTOM.y;
	float c = cos(r);
	float s = sin(r);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
	v_t = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec4 tx = texture(tex, UV);
	float fade = smoothstep(0.0, 0.08, v_t) * (1.0 - smoothstep(0.5, 1.0, v_t));
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	vp.xyz /= vp.w;
	float soft = clamp((VERTEX.z - vp.z) / soft_distance, 0.0, 1.0);
	// fake top light
	float lit = mix(0.75, 1.15, UV.y < 0.5 ? 1.0 - UV.y : 0.5);
	ALBEDO = COLOR.rgb * tx.rgb * lit;
	ALPHA = tx.a * COLOR.a * fade * soft;
}

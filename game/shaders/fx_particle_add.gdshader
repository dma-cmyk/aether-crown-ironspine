shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;
uniform float energy = 2.2;

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
	float fade = 1.0 - smoothstep(0.35, 1.0, v_t);
	ALBEDO = COLOR.rgb * tx.rgb * energy;
	ALPHA = tx.a * COLOR.a * fade;
}

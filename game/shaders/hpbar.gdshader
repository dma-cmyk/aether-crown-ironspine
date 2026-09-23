shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled;

instance uniform float fill = 1.0;
instance uniform vec4 bar_color : source_color = vec4(0.35, 0.95, 0.45, 1.0);

void vertex() {
	// camera-facing billboard around the node origin
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	float edge = step(uv.x, 0.015) + step(0.985, uv.x) + step(uv.y, 0.12) + step(0.88, uv.y);
	vec3 col = uv.x < fill ? bar_color.rgb * (0.8 + 0.3 * (1.0 - uv.y)) : vec3(0.06, 0.07, 0.08);
	col = mix(col, vec3(0.02), min(edge, 1.0));
	ALBEDO = col;
	ALPHA = 0.92;
}

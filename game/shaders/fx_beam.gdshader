shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords, fog_disabled;

// Instance transform: basis.x = segment (tail -> head), origin = tail. custom.y = width, custom.z = beam flag.
varying float v_beam;

void vertex() {
	vec3 a = MODEL_MATRIX[3].xyz;
	vec3 seg = vec3(MODEL_MATRIX[0].x, MODEL_MATRIX[0].y, MODEL_MATRIX[0].z);
	vec3 mid = a + seg * 0.5;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - mid;
	vec3 side = cross(seg, to_cam);
	float sl = length(side);
	side = sl > 0.0001 ? side / sl : vec3(0.0, 1.0, 0.0);
	float w = INSTANCE_CUSTOM.y;
	VERTEX = a + seg * UV.x + side * (UV.y - 0.5) * w * 2.0;
	v_beam = INSTANCE_CUSTOM.z;
}

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float core = pow(across, 3.0);
	float along = v_beam > 0.5 ? 1.0 : mix(0.15, 1.0, UV.x);
	vec3 c = COLOR.rgb * (1.6 + core * 2.5);
	ALBEDO = c;
	ALPHA = pow(across, 1.4) * along * COLOR.a;
}

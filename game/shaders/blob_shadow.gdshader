shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p * vec2(1.0, 1.0));
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.35, 1.0, d)) * 0.35;
}

shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform float speed = 1.3;
uniform vec3 water_color : source_color = vec3(0.45, 0.60, 0.64);
uniform vec3 foam_color : source_color = vec3(0.93, 0.96, 0.98);

void vertex() {
	float w = sin(TIME * 2.7 + VERTEX.y * 1.1 + VERTEX.x * 0.7) * 0.07;
	VERTEX += NORMAL * w;
}

void fragment() {
	// UV: normalised (across, down). UV2: tiling coordinates.
	vec2 uv = UV2;
	float n1 = texture(foam_noise, vec2(uv.x * 1.3, uv.y * 0.32 - TIME * speed)).r;
	float n2 = texture(foam_noise, vec2(uv.x * 3.1 + 0.3, uv.y * 0.55 - TIME * speed * 1.45)).r;
	float streak = smoothstep(0.3, 0.8, n1 * 0.62 + n2 * 0.5);
	float bottom = smoothstep(0.55, 1.0, UV.y);
	vec3 col = mix(water_color, foam_color, clamp(streak + bottom * 0.6, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.25;
	EMISSION = col * 0.08;
	float edge = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x);
	float top = smoothstep(0.0, 0.12, UV.y);
	ALPHA = edge * top * clamp(0.55 + streak * 0.45, 0.0, 1.0);
}

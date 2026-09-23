shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

instance uniform vec4 ring_color : source_color = vec4(0.45, 1.0, 0.55, 1.0);
instance uniform float ring_width = 0.07;
instance uniform float ring_pulse = 0.0;
instance uniform float ring_fill = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float w = ring_width;
	float ring = smoothstep(1.0 - w - 0.03, 1.0 - w, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float ticks = step(0.5, fract(atan(p.y, p.x) / 6.28318 * 24.0 + TIME * 0.05));
	float inner = (1.0 - smoothstep(0.0, 1.0 - w, r)) * ring_fill * 0.18;
	float a = ring * mix(1.0, 0.55 + 0.45 * ticks, ring_pulse) + inner;
	ALBEDO = ring_color.rgb;
	ALPHA = a * ring_color.a;
}

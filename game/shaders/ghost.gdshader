shader_type spatial;
// Building placement preview: a lit hologram of the model with a bright rim and scan lines
// rising through it, green where it can be built and red where it cannot.
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

#include "res://shaders/compat.gdshaderinc"

uniform vec3 tint = vec3(0.35, 1.0, 0.55);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float lit = 0.35 + 0.65 * clamp(dot(wnorm, normalize(vec3(0.35, 0.85, 0.4))), 0.0, 1.0);
	float band = fract(wpos.y * 0.6 - TIME * 0.7);
	float scan = smoothstep(0.82, 0.97, band) * (1.0 - smoothstep(0.97, 1.0, band));
	float fine = 0.5 + 0.5 * sin(wpos.y * 18.0);
	vec3 c = tint * (0.16 + 0.3 * lit + 0.05 * fine) + tint * rim * 0.75 + mix(tint, vec3(1.0), 0.3) * scan * 0.3;
	ALBEDO = linear_out(c);
	ALPHA = clamp(0.24 + 0.12 * lit + rim * 0.5 + scan * 0.3, 0.0, 0.9);
}

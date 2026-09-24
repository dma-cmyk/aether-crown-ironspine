// Differences between the desktop renderers (Forward+/Mobile) and Compatibility, the Web build's renderer.

// Screen depth to NDC: reversed Z in 0..1 on desktop, OpenGL's -1..1 with the far plane at 1 in Compatibility.
vec4 depth_ndc(vec2 uv, float raw) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return vec4(vec3(uv, raw) * 2.0 - 1.0, 1.0);
#else
	return vec4(uv * 2.0 - 1.0, raw, 1.0);
#endif
}

bool depth_is_sky(float raw) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return raw >= 0.99999;
#else
	return raw <= 0.00001;
#endif
}

// Compatibility reads textures and source_color uniforms as sRGB and linearises ALBEDO and EMISSION
// at the end, so colours worked out in linear space (vertex and instance colours) go through these.
vec3 linear_out(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, lessThan(c, vec3(0.0031308)));
#else
	return c;
#endif
}

vec3 linear_in(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
#else
	return c;
#endif
}

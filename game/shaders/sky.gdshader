shader_type sky;

uniform vec3 zenith : source_color = vec3(0.20, 0.34, 0.58);
uniform vec3 horizon : source_color = vec3(0.70, 0.72, 0.74);
uniform vec3 ground : source_color = vec3(0.26, 0.26, 0.27);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.95, 0.88);
uniform vec3 cloud_shade : source_color = vec3(0.52, 0.56, 0.62);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_cover = 0.52;

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.5));
	col = mix(col, ground, smoothstep(0.0, -0.12, h));
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * (pow(sd, 6.0) * 0.25 + pow(sd, 64.0) * 0.4);
	if (AT_CUBEMAP_PASS == false) {
		col += LIGHT0_COLOR * pow(sd, 1500.0) * 40.0;
	}
	if (h > 0.0) {
		vec2 cuv = d.xz / (h + 0.1) * 0.28;
		float c = texture(cloud_noise, cuv).r * 0.62 + texture(cloud_noise, cuv * 2.9 + 0.37).r * 0.38;
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.3, c);
		float fade = smoothstep(0.0, 0.2, h);
		vec3 ccol = mix(cloud_shade, cloud_lit, clamp(c * 1.2 - 0.2 + pow(sd, 3.0) * 0.5, 0.0, 1.0));
		col = mix(col, ccol, cov * fade * 0.92);
	}
	COLOR = col;
}

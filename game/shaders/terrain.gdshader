shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Map-space masks (R dirt/road, G rock, B ash, A forest floor) and fog of war.
uniform sampler2D splat_map : filter_linear, repeat_disable;
uniform sampler2D fog_map : hint_default_white, filter_linear, repeat_disable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float map_size = 400.0;
uniform float grass_tile = 7.0;
uniform float dirt_tile = 6.0;
uniform float rock_tile = 8.0;
uniform float cliff_tile = 13.0;
uniform vec3 grass_tint : source_color = vec3(0.58, 0.63, 0.44);
uniform vec3 grass_dry : source_color = vec3(0.76, 0.70, 0.50);
uniform vec3 forest_tint : source_color = vec3(0.62, 0.70, 0.55);
uniform vec3 dirt_tint : source_color = vec3(0.78, 0.74, 0.68);
uniform vec3 ash_tint : source_color = vec3(0.40, 0.38, 0.37);
uniform vec3 rock_tint : source_color = vec3(1.25, 1.22, 1.2);
uniform vec3 cliff_tint_a : source_color = vec3(0.80, 0.74, 0.66);
uniform vec3 cliff_tint_b : source_color = vec3(0.62, 0.64, 0.70);
uniform float normal_strength = 0.9;
uniform float fog_strength = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

vec3 nmap(sampler2D t, vec2 uv) {
	return texture(t, uv).xyz * 2.0 - 1.0;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n0 = normalize(wnrm);
	vec2 muv = wpos.xz / map_size + 0.5;
	vec4 sp = texture(splat_map, muv);
	float macro = texture(macro_noise, wpos.xz * 0.0035).r;
	float macro2 = fract(macro * 7.13 + wpos.y * 0.05);

	float w_dirt = sp.r;
	float w_rock = sp.g;
	float w_ash = sp.b;
	float w_grass = max(0.0, 1.0 - w_dirt - w_rock - w_ash);

	vec2 guv = wpos.xz / grass_tile;
	vec3 g = texture(grass_albedo, guv).rgb;
	g *= mix(grass_tint, grass_dry, smoothstep(0.42, 0.78, macro));
	g *= mix(vec3(1.0), forest_tint, sp.a);
	vec3 col = g * w_grass;
	vec3 tn = nmap(grass_normal, guv) * w_grass;

	if (w_dirt + w_ash > 0.01) {
		vec2 duv = wpos.xz / dirt_tile;
		vec3 d = texture(dirt_albedo, duv).rgb;
		col += d * dirt_tint * w_dirt + d * ash_tint * w_ash;
		tn += nmap(dirt_normal, duv) * (w_dirt + w_ash);
	}
	if (w_rock > 0.01) {
		vec2 ruv = wpos.xz / rock_tile;
		col += texture(rock_albedo, ruv).rgb * rock_tint * w_rock;
		tn += nmap(rock_normal, ruv) * w_rock;
	}
	vec3 nrm = normalize(n0 + vec3(tn.x, 0.0, -tn.y) * normal_strength);
	vec3 albedo = col;
	float rough = 0.93;

	float slope = 1.0 - n0.y;
	float cliff = smoothstep(0.2, 0.4, slope + (macro2 - 0.5) * 0.16);
	if (cliff > 0.01) {
		vec3 bw = pow(abs(n0), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec2 ux = vec2(wpos.z, -wpos.y) / cliff_tile;
		vec2 uz = vec2(wpos.x, -wpos.y) / cliff_tile;
		vec2 uy = wpos.xz / cliff_tile;
		vec3 ccol = texture(cliff_albedo, ux).rgb * bw.x + texture(cliff_albedo, uy).rgb * bw.y
				+ texture(cliff_albedo, uz).rgb * bw.z;
		vec3 tx = nmap(cliff_normal, ux);
		vec3 ty = nmap(cliff_normal, uy);
		vec3 tz = nmap(cliff_normal, uz);
		vec3 cn = normalize(n0 + (bw.x * vec3(0.0, tx.y, tx.x) + bw.y * vec3(ty.x, 0.0, -ty.y)
				+ bw.z * vec3(tz.x, tz.y, 0.0)) * 1.2);
		float band = sin(wpos.y * 1.05 + macro2 * 5.0) * 0.5 + 0.5;
		ccol *= mix(cliff_tint_a, cliff_tint_b, band);
		albedo = mix(albedo, ccol, cliff);
		nrm = normalize(mix(nrm, cn, cliff));
		rough = mix(rough, 0.86, cliff);
	}

	float depth = smoothstep(-2.0, -24.0, wpos.y);
	albedo *= mix(1.0, 0.72, depth);
	albedo *= mix(0.86, 1.1, macro);

	float fog = texture(fog_map, muv).r;
	albedo *= mix(1.0, fog, fog_strength);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	AO = COLOR.r;
	AO_LIGHT_AFFECT = 0.55;
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
}

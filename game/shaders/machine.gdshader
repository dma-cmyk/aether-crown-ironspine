shader_type spatial;
// Gearforge machines (tools/blender/gearforge): baked painted-metal maps. The albedo holds the
// bare paint as a neutral grey where mask.r is set; it is multiplied into the side's colour here,
// so chips, grime and streaks baked into the paint show on every team's colour alike.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap;
uniform vec3 paint_color : source_color = vec3(0.16, 0.28, 0.62);
uniform vec3 glow_color : source_color = vec3(0.35, 0.85, 1.0);
uniform vec3 fire_color : source_color = vec3(1.0, 0.45, 0.14);
uniform float glow_energy = 4.0;
uniform float fire_energy = 5.0;
uniform float ao_light_affect = 0.35;

// bare paint in the albedo map: sRGB 0.5, which the desktop renderers read back linearised
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
const float PAINT_GREY = 0.5;
#else
const float PAINT_GREY = 0.214;
#endif

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	vec3 m = texture(mask_tex, UV).rgb;
	ALBEDO = mix(a, paint_color * (a / PAINT_GREY), m.r);
	AO = orm.r;
	AO_LIGHT_AFFECT = ao_light_affect;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = glow_color * m.g * glow_energy + fire_color * m.b * fire_energy;
}

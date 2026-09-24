class_name EnvRig
extends Node3D
## Sky, sun, fog and post-processing; reacts to the quality setting.

var world_env: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D


func build() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sm.set_shader_parameter("cloud_noise", MatLib.noise_texture(512, 0.006, 3, false, 5))
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = 0.95
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.66, 0.70, 0.76)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.2
	env.fog_aerial_perspective = 0.15
	env.fog_height = -15.0
	env.fog_height_density = 0.012
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.06
	if compat():
		# Compatibility (the Web build) adds shadowed sunlight in a pass of its own after tonemapping,
		# which brightens lit ground and fog; these values (and the sun below) match the desktop look
		env.tonemap_exposure = 0.95
		env.fog_density = 0.0009
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 0.8 if compat() else 1.75
	sun.rotation_degrees = Vector3(-40.0, -65.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	apply_quality()
	if Game.args.has("noshadow"):
		sun.shadow_enabled = false
	if Game.args.has("noglow"):
		env.glow_enabled = false
	if Game.args.has("noenvfog"):
		env.fog_enabled = false
	Game.settings_changed.connect(apply_quality)


func apply_quality() -> void:
	var q := Game.quality
	var vp := get_viewport()
	env.glow_enabled = not Game.args.has("noglow")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q < 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = [110.0, 150.0, 240.0][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])
	if vp:
		var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if (q < 2 and forward_plus) else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = [0.67, 0.8, 1.0][q]
		if compat():
			vp.msaa_3d = Viewport.MSAA_2X if q == 2 else Viewport.MSAA_DISABLED
		else:
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q < 2 else Viewport.SCREEN_SPACE_AA_SMAA
			vp.msaa_3d = Viewport.MSAA_DISABLED


static func compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

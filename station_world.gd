extends Node3D
## Playable North Basin assembly. Imported meshes provide the artwork.
## Collision follows the actual playable floor and large obstacles.

const RELAY := preload("res://models/ridge_hero.glb")
const STONE_SHADER := preload("res://painted_stone.gdshader")
const STONE_ATLAS := preload("res://textures/painted_stone.png")
const PLANT_SHADER := preload("res://painted_plants.gdshader")
const PLANT_ATLAS := preload("res://textures/painted_plants.png")
const RELAY_ORIGIN := Vector3(0.0, 0.0, -5.0)
const WEATHERED_GROUND := preload("res://refine_basin_ground.gdshader")
const GROUND_ATLAS := preload("res://textures/refinement_ground.png")
const GEOLOGY := preload("res://station_geology.gd")
const OUTFIT := preload("res://refine_basin_dressing.gd")
const BASIN_WATER := preload("res://refine_basin_water.gdshader")
const BASIN_SKY := preload("res://refine_basin_sky.gdshader")

@export var refinement_round := 33

var _rng := RandomNumberGenerator.new()
var _step_stone: ShaderMaterial
var _bedrock: ShaderMaterial
var _ice_stone: ShaderMaterial
var _iron: StandardMaterial3D
var _lamp: StandardMaterial3D
var _guide: StandardMaterial3D
var _signal: OmniLight3D


func _ready() -> void:
	_rng.seed = 567287
	_step_stone = _stone(Color("c5d0d2"), 7.9, 0.58, 0.83)
	_step_stone.set_shader_parameter("micro_relief", 0.005)
	_bedrock = _stone(Color("88969d"), 6.1, 0.69, 0.94)
	_ice_stone = _stone(Color("a4b6bd"), 2.9, 0.56, 0.88)
	_iron = _colored(Color("404c52"), 0.53, 0.46)
	_guide = _colored(Color("95714e"), 0.65, 0.53)
	_lamp = _colored(Color("dc7755"), 0.32, 0.0)
	_lamp.emission_enabled = true
	_lighting()
	_ground()
	_canal()
	if refinement_round >= 26:
		_spring_outfall()
	if refinement_round >= 2:
		var rocks := GEOLOGY.new()
		rocks.set("art_revision", refinement_round)
		add_child(rocks)
	else:
		_rock_field()
	_build_relay()
	_route_details()
	_plants()
	if refinement_round >= 3:
		var site := OUTFIT.new()
		site.set("style_round", refinement_round)
		add_child(site)
	set_power(false)


func review_views() -> Array:
	return [
		[Vector3(2.1, 3.12, 6.8), Vector3(0.0, 1.1, -4.5), 58.0],
		[Vector3(0.25, 15.9, 15.0), Vector3(0.32, 0.1, -1.0), 52.0],
	]


func route() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 11), Vector2(0, 2), Vector2(0, -2.35), Vector2(5.1, -2.35), Vector2(5.1, -9.2), Vector2(0, -9.2)])


func set_power(enabled: bool) -> void:
	var tint := Color("66f3e0") if enabled else Color("d57351")
	_lamp.albedo_color = tint
	_lamp.emission = tint
	_lamp.emission_energy_multiplier = 2.15 if enabled else 0.55
	_signal.light_color = tint
	_signal.light_energy = 2.6 if enabled else 0.48


func _lighting() -> void:
	var lighting := Environment.new()
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = Color("3c627d")
	sky_paint.sky_horizon_color = Color("b6c9ca")
	sky_paint.ground_horizon_color = Color("a0b4be")
	sky_paint.ground_bottom_color = Color("64717a")
	sky_paint.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_paint
	lighting.sky = sky
	lighting.background_mode = Environment.BG_SKY
	lighting.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	lighting.tonemap_exposure = 1.08
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("bfd4e9")
	lighting.ambient_light_energy = 0.74
	lighting.fog_enabled = true
	lighting.fog_mode = Environment.FOG_MODE_DEPTH
	lighting.fog_light_color = Color("819da9")
	lighting.fog_depth_begin = 19.0
	lighting.fog_depth_end = 64.0
	lighting.fog_density = 0.68
	lighting.fog_sky_affect = 0.54
	lighting.ssao_enabled = true
	lighting.ssao_intensity = 1.35
	lighting.ssao_radius = 1.7
	lighting.glow_enabled = true
	lighting.glow_bloom = 0.10
	if refinement_round >= 4:
		lighting.tonemap_exposure = 0.98
		lighting.ambient_light_color = Color("b1c6db")
		lighting.ambient_light_energy = 0.58
		lighting.fog_light_color = Color("6d8597")
		lighting.fog_depth_begin = 21.0
		lighting.fog_depth_end = 87.0
		lighting.fog_density = 0.93
		lighting.fog_sky_affect = 0.32
		lighting.ssao_intensity = 2.0
		lighting.glow_bloom = 0.075
	if refinement_round >= 5:
		lighting.glow_bloom = 0.048
		lighting.ambient_light_energy = 0.64
		lighting.fog_depth_begin = 29.0
	if refinement_round >= 7:
		sky_paint.sky_top_color = Color("425975")
		sky_paint.sky_horizon_color = Color("a4b3b4")
		lighting.fog_light_color = Color("768c99")
		lighting.fog_depth_begin = 22.0
		lighting.fog_depth_end = 75.0
		lighting.ambient_light_energy = 0.71
		lighting.glow_bloom = 0.035
	if refinement_round >= 8:
		lighting.fog_light_color = Color("78929f")
		lighting.fog_depth_begin = 24.0
		lighting.fog_depth_end = 86.0
		lighting.tonemap_exposure = 1.03
		lighting.ssao_intensity = 1.72
	if refinement_round >= 9:
		var cloud_deck := ShaderMaterial.new()
		cloud_deck.shader = BASIN_SKY
		cloud_deck.set_shader_parameter("clearing", refinement_round >= 30)
		sky.sky_material = cloud_deck
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		lighting.fog_light_color = Color("81919d")
		lighting.fog_depth_begin = 21.0
		lighting.fog_depth_end = 78.0
		lighting.ambient_light_color = Color("b3c9d9")
	if refinement_round >= 14:
		lighting.tonemap_exposure = 1.04
		lighting.ambient_light_energy = 0.74
		lighting.fog_light_color = Color("#71858d")
		lighting.fog_depth_begin = 23.0
		lighting.fog_depth_end = 96.0
		lighting.fog_density = 0.57
		lighting.volumetric_fog_enabled = true
		lighting.volumetric_fog_density = 0.006
		lighting.volumetric_fog_length = 78.0
		lighting.volumetric_fog_albedo = Color("#afbfc7")
	if refinement_round >= 24:
		lighting.tonemap_exposure = 1.00
		lighting.ambient_light_color = Color("#aabed5")
		lighting.ambient_light_energy = 0.64
		lighting.fog_light_color = Color("#788f9d")
		lighting.fog_depth_begin = 27.0
		lighting.fog_depth_end = 90.0
		lighting.fog_density = .65
	if refinement_round >= 27:
		lighting.ssr_enabled = true
		lighting.ssr_max_steps = 42
		lighting.ssr_fade_in = .18
		lighting.ssr_fade_out = 2.25
		lighting.ssr_depth_tolerance = .22
		lighting.volumetric_fog_density = .004
		lighting.fog_light_color = Color("#6d8798")
		lighting.fog_depth_begin = 25.0
		lighting.fog_depth_end = 99.0
		lighting.fog_density = .58
		lighting.ambient_light_energy = .60
	var env := WorldEnvironment.new()
	env.environment = lighting
	add_child(env)

	var light := DirectionalLight3D.new()
	light.light_color = Color("ffe7c1")
	light.light_energy = 1.33
	light.light_angular_distance = 3.2
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 46.0
	light.rotation_degrees = Vector3(-30.0, -142.0, 0.0) if refinement_round >= 4 else Vector3(-38.0, -38.0, 0.0)
	if refinement_round >= 7:
		light.rotation_degrees = Vector3(-27.0, -118.0, 0.0)
		light.light_color = Color("dfebf0")
		light.light_energy = 0.96
	if refinement_round >= 14:
		light.light_color = Color("#f5e3c7")
		light.light_energy = 1.02
		light.rotation_degrees = Vector3(-33.0, -102.0, 0.0)
		light.light_angular_distance = 5.0
		light.light_volumetric_fog_energy = 0.31
	if refinement_round >= 24:
		light.rotation_degrees = Vector3(-37.0, -137.0, 0.0)
		light.light_color = Color("#f6dbc1")
		light.light_energy = 1.18
		light.light_angular_distance = 3.6
	if refinement_round >= 27:
		light.rotation_degrees = Vector3(-30.0, -152.0, 0.0)
		light.light_color = Color("#ffe1b6")
		light.light_energy = 1.58
		light.light_angular_distance = 4.1
	if refinement_round >= 28:
		light.rotation_degrees = Vector3(-36.0, -119.0, 0.0)
		light.light_color = Color("#f4e0c6")
		light.light_energy = 1.28
		light.light_angular_distance = 4.7
	add_child(light)
	if refinement_round >= 4:
		var fill := DirectionalLight3D.new()
		fill.light_color = Color("b4c9e5")
		fill.light_energy = 0.47 if refinement_round >= 14 else 0.36
		if refinement_round >= 24:
			fill.light_energy = .32
		fill.light_volumetric_fog_energy = 0.12
		fill.rotation_degrees = Vector3(-34, -20, 0)
		add_child(fill)
	if refinement_round >= 14:
		_basin_mist()
	if refinement_round == 19:
		_cloud_break()


func _basin_mist() -> void:
	var steam := FogMaterial.new()
	steam.density = .037
	steam.albedo = Color("#8197a3")
	steam.edge_fade = .56
	steam.height_falloff = .31
	for origin in [Vector3(-10.2, .8, -20.0), Vector3(12.1, 1.25, -24.4), Vector3(-2.2, 1.3, -39.8)]:
		var mist := FogVolume.new()
		mist.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		mist.size = Vector3(16.2, 5.5, 16.0)
		mist.position = origin
		mist.material = steam
		add_child(mist)


func _cloud_break() -> void:
	var shaft := SpotLight3D.new()
	shaft.position = Vector3(2.85, 7.4, 5.0)
	shaft.light_color = Color("#efd29b")
	shaft.light_energy = 4.85
	shaft.spot_range = 23.0
	shaft.spot_angle = 27.0
	shaft.spot_angle_attenuation = 1.80
	shaft.spot_attenuation = 2.20
	shaft.light_volumetric_fog_energy = .19
	shaft.shadow_enabled = true
	add_child(shaft)
	shaft.look_at(Vector3(-2.85, .25, -3.1), Vector3.UP)


func _ground() -> void:
	# Continuous walkable deck avoids seams in movement and collision.
	var deck: Material = _bedrock
	if refinement_round >= 1:
		var ground := ShaderMaterial.new()
		ground.shader = WEATHERED_GROUND
		ground.set_shader_parameter("paint", GROUND_ATLAS)
		ground.set_shader_parameter("lane_amount", 1.0)
		var wetness := 0.80 if refinement_round >= 4 else 0.0
		if refinement_round >= 7:
			wetness = 0.38
		ground.set_shader_parameter("puddles", wetness)
		ground.set_shader_parameter("traffic_breakup", 1.0 if refinement_round >= 8 else 0.0)
		ground.set_shader_parameter("continuous_sampling", 1.0 if refinement_round >= 10 else 0.0)
		ground.set_shader_parameter("repair_weathering", 1.0 if refinement_round >= 17 else 0.0)
		ground.set_shader_parameter("service_apron", refinement_round >= 23)
		ground.set_shader_parameter("split_approach", refinement_round >= 26)
		ground.set_shader_parameter("runoff_layers", refinement_round >= 27)
		ground.set_shader_parameter("soft_sky_return", refinement_round >= 28)
		ground.set_shader_parameter("saturated_concrete", refinement_round >= 29)
		ground.set_shader_parameter("reserve_guide_glare", refinement_round >= 30)
		ground.set_shader_parameter("drained_pavement", refinement_round >= 32)
		ground.set_shader_parameter("worn_joints", refinement_round >= 33)
		ground.set_shader_parameter("tint", Color("9da9a3"))
		deck = ground
	_box(Vector3(5.0, -0.48, 0.0), Vector3(21.0, 0.96, 31.0), deck, true)
	if refinement_round >= 29:
		_cast_apron_cap(deck as ShaderMaterial)
	_box(Vector3(-14.0, -0.51, 0.0), Vector3(11.0, 0.92, 31.0), _bedrock)
	_box(Vector3(0.0, -1.0, 0.0), Vector3(86.0, 0.35, 76.0), _bedrock)
	if refinement_round == 0:
		_legacy_paths()
	_box(Vector3(5.0, 0.45, -15.10), Vector3(20.8, 0.9, 0.6), _bedrock, true)
	_box(Vector3(14.85, 0.42, 0.0), Vector3(0.55, 0.85, 30.9), _bedrock, true)
	_box(Vector3(5.0, 0.265, 15.40), Vector3(20.8, 0.53, 0.44), _bedrock, true)


func _cast_apron_cap(deck: ShaderMaterial) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[PackedVector3Array] = []
	var east := PackedFloat32Array([1.77, 2.25, 2.40, 2.07, 1.82, 2.04, 2.24, 2.11, 1.62])
	var west := PackedFloat32Array([-2.55, -2.67, -2.72, -2.45, -2.53, -2.82, -2.67, -2.55, -2.14])
	var offsets := [0.0, .16, .39, .59, .79, .94, 1.0]
	for row in range(9):
		var z := 6.4 - float(row) * 1.25
		var rise := sin(float(row) / 8.0 * PI) * (.155 + .028 * sin(float(row) * .83))
		var strip := PackedVector3Array()
		for offset: float in offsets:
			var x := lerpf(west[row], east[row], offset)
			var crown := smoothstep(.0, .25, offset) * (1.0 - smoothstep(.72, 1.0, offset))
			var crossfall := .72 + .28 * sin(offset * 2.98)
			strip.append(Vector3(x, .014 + rise * crown * crossfall, z + x * .068))
		rows.append(strip)
	for row in range(rows.size() - 1):
		for slot in range(offsets.size() - 1):
			var a := rows[row][slot]
			var b := rows[row][slot + 1]
			var c := rows[row + 1][slot + 1]
			var d := rows[row + 1][slot]
			for vertex in [a, c, b, a, d, c]:
				builder.add_vertex(vertex)
	builder.index()
	builder.generate_normals()
	var face := deck.duplicate() as ShaderMaterial
	face.set_shader_parameter("cast_cap", true)
	var cap := _mesh(builder.commit(), face, Vector3.ZERO)
	cap.create_trimesh_collision()


func _legacy_paths() -> void:
	_strip(PackedVector3Array([
		Vector3(0, .018, 15.45), Vector3(-.35, .018, 10.0), Vector3(.30, .018, 5.0),
		Vector3(0.1, .018, 0.0), Vector3(0.0, .018, -4.2),
	]), PackedFloat32Array([6.3, 5.3, 5.6, 5.4, 6.9]), _step_stone)
	_strip(PackedVector3Array([
		Vector3(2.6, .021, 8.0), Vector3(4.9, .021, 5.0), Vector3(5.20, .021, 0.0),
		Vector3(5.02, .021, -5.0), Vector3(4.1, .021, -8.9), Vector3(0.0, .021, -9.3),
	]), PackedFloat32Array([2.8, 3.2, 3.0, 2.9, 3.2, 3.2]), _step_stone)


func _canal() -> void:
	if refinement_round == 18 or refinement_round == 19:
		_jointed_banks()
	else:
		if refinement_round >= 31:
			_canal_view_opening()
		else:
			_box(Vector3(-5.45, 0.21, 0), Vector3(0.70, 0.42, 30.8), _ice_stone, true)
		if refinement_round < 29:
			_box(Vector3(-8.62, 0.19, 0), Vector3(0.65, 0.56, 30.8), _ice_stone)
	var water := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
		shader_type spatial;
		varying vec2 basin_uv;
		void vertex() { basin_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
		void fragment() {
			vec2 point = basin_uv;
			float ripple = sin(point.y * 12.5 + sin(point.x * 16.0) - TIME * 1.9);
			float broad = sin(point.y * 2.4 + point.x * 5.5 + TIME * 0.68);
			float streak = smoothstep(0.82, 0.98, ripple * 0.65 + broad * 0.52);
			ALBEDO = mix(vec3(0.024, 0.109, 0.147), vec3(0.105, 0.28, 0.29), 0.38 + broad * 0.08 + streak * 0.15);
			ROUGHNESS = 0.21 + broad * 0.046;
			SPECULAR = 0.65;
			EMISSION = vec3(0.028, 0.086, 0.105) * (0.10 + streak * 0.30);
		}
	"""
	water.shader = shader
	if refinement_round >= 7:
		water.shader = BASIN_WATER
		water.set_shader_parameter("seepage_detail", refinement_round == 18 or refinement_round == 19)
		water.set_shader_parameter("geographic_water", refinement_round >= 20)
		water.set_shader_parameter("contact_riffles", refinement_round >= 24)
		water.set_shader_parameter("spring_inflow", refinement_round >= 26)
		water.set_shader_parameter("cut_flow", refinement_round >= 27)
		water.set_shader_parameter("soft_sky_return", refinement_round >= 28)
		water.set_shader_parameter("flood_bays", refinement_round >= 29)
		water.set_shader_parameter("spillway_depth", refinement_round >= 31)
	if refinement_round >= 29:
		_cut_canal_water(water)
	else:
		var plane := PlaneMesh.new()
		plane.size = Vector2(3.08, 31.2)
		_mesh(plane, water, Vector3(-7.03, -0.47, 0.0))
	if refinement_round >= 20:
		_flow_obstacles()
	for z in [-12.7, -8.2, -3.5, 1.4, 5.9, 10.8]:
		_box(Vector3(-5.42, 0.55, z), Vector3(0.76, 0.28, 0.29), _iron)
		_box(Vector3(-5.40, 0.71, z), Vector3(0.34, 0.035, 0.17), _lamp)
	# Spillway lip and recessed channel crossings sit outside the playable line.
	for z in [-11.0, 11.0]:
		_box(Vector3(-7.0, -0.30, z), Vector3(3.8, 0.27, 0.46), _iron)
		for x in [-8.15, -7.35, -6.55]:
			_box(Vector3(x, -0.10, z), Vector3(0.18, 0.44, 1.4), _iron)


func _canal_view_opening() -> void:
	_body(Vector3(-5.45, .21, 0), Vector3(.70, .42, 30.8))
	_box(Vector3(-5.45, .21, 6.71), Vector3(.70, .42, 17.36), _ice_stone)
	_box(Vector3(-5.45, .21, -11.04), Vector3(.70, .42, 8.70), _ice_stone)
	_box(Vector3(-5.45, .085, -4.29), Vector3(.70, .17, 4.76), _ice_stone)
	_box(Vector3(-5.40, .456, -4.30), Vector3(.095, .074, 4.74), _iron)
	for z in [-6.53, -5.29, -4.06, -2.82, -2.08]:
		_box(Vector3(-5.40, .294, z), Vector3(.14, .30, .142), _iron)


func _canal_outer_x(z: float) -> float:
	return -8.56 - .99 * exp(-pow((z + 7.78) / 2.9, 2.0)) - .65 * exp(-pow((z - 3.65) / 2.2, 2.0))


func _cut_canal_water(water: ShaderMaterial) -> void:
	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floodwall := _stone(Color("617572"), 3.8, .55, .86)
	var capstone := _stone(Color("a1ada0"), 2.4, .67, .94)
	var step := 1.2
	for i in range(26):
		var z0 := -15.60 + i * step
		var z1 := z0 + step
		var outer0 := _canal_outer_x(z0)
		var outer1 := _canal_outer_x(z1)
		for point in [
			Vector3(outer0 - .07, -.47, z0), Vector3(-5.49, -.47, z0), Vector3(-5.49, -.47, z1),
			Vector3(outer0 - .07, -.47, z0), Vector3(-5.49, -.47, z1), Vector3(outer1 - .07, -.47, z1),
		]:
			fill.set_normal(Vector3.UP)
			fill.add_vertex(point)
		var yaw := atan2(outer1 - outer0, step)
		var mid := Vector3((outer1 + outer0) * .5 - .24, -.15, (z1 + z0) * .5)
		var below := exp(-pow((mid.z + 7.78) / 1.14, 2.0)) * .45
		var rise := .79 - below
		var span := Vector2(outer1 - outer0, step).length()
		var wall := _box(mid + Vector3(0.0, (rise - .79) * .5, 0.0), Vector3(.51, rise, span + .03), floodwall)
		wall.rotation.y = yaw
		var coping := _box(mid + Vector3(0.0, .39 - below, 0.0), Vector3(.56, .105, span - .023), capstone)
		coping.rotation.y = yaw
	_mesh(fill.commit(), water, Vector3.ZERO)


func _flow_obstacles() -> void:
	var wet_slate := _stone(Color("#91a198"), 2.43, .35, .73)
	wet_slate.set_shader_parameter("micro_relief", .0061)
	var shore_slate := _stone(Color("#a8a895"), 2.15, .60, .86)
	shore_slate.set_shader_parameter("micro_relief", .006)
	var islands := [
		[Vector3(-8.2, -.47, 4.8), Vector3(.94, .47, 1.26), -.14],
		[Vector3(-7.69, -.51, 4.27), Vector3(.83, .39, .97), .24],
		[Vector3(-8.39, -.51, 3.92), Vector3(.68, .35, 1.12), -.47],
		[Vector3(-5.92, -.51, -5.35), Vector3(.77, .42, .96), -.45],
		[Vector3(-6.22, -.48, -5.86), Vector3(.49, .35, .81), .40],
		[Vector3(-8.39, -.38, -10.53), Vector3(1.13, .56, 1.46), .39],
		[Vector3(-7.90, -.50, -10.73), Vector3(.82, .41, .86), -.58],
	]
	for island in islands:
		var at: Vector3 = island[0]
		var size: Vector3 = island[1]
		var stone := _mesh(_rock(size, int(2018 + absf(at.z) * 550.0)), wet_slate, at)
		stone.rotation.y = island[2]
	for bank in [
		[Vector3(-8.96, -.37, 6.0), Vector3(1.55, .64, 2.92), .36],
		[Vector3(-8.79, -.30, 4.31), Vector3(1.37, .74, 2.14), -.2],
		[Vector3(-8.87, -.30, -9.98), Vector3(1.20, .72, 2.26), .5],
	]:
		var at: Vector3 = bank[0]
		var size: Vector3 = bank[1]
		var toe := _mesh(_rock(size, int(2126 + absf(at.z) * 820.0)), shore_slate, at)
		toe.rotation.y = bank[2]


func _spring_outfall() -> void:
	var spring_tint := Color("#939c8f") if refinement_round >= 32 else Color("#636b62")
	var wetwork := _stone(spring_tint, 2.95, .44 if refinement_round >= 32 else .39, .82)
	wetwork.set_shader_parameter("micro_relief", .0055)
	var support := [
		[Vector3(-9.83, .08, -8.10), Vector3(3.30, 1.11, 2.94), -.28],
		[Vector3(-10.42, .52, -8.62), Vector3(2.10, 1.25, 2.57), .52],
		[Vector3(-10.72, 1.20, -8.92), Vector3(1.58, 1.29, 2.16), .16],
		[Vector3(-9.55, -.23, -7.35), Vector3(1.63, .62, 1.65), -.40],
		[Vector3(-8.53, -.42, -7.67), Vector3(.91, .31, .83), -.13],
	]
	for slab in support:
		var origin: Vector3 = slab[0]
		var size: Vector3 = slab[1]
		var ledge := _mesh(_rock(size, int(7771 + absf(origin.x + origin.z) * 632.0)), wetwork, origin)
		ledge.rotation.y = slab[2]
	var spill := ShaderMaterial.new()
	spill.shader = preload("res://refine_basin_outfall.gdshader")
	var streams := [
		[
			Vector3(-10.00, 1.67, -8.49), Vector3(-9.82, 1.41, -8.43), Vector3(-9.40, .92, -8.16),
			Vector3(-8.94, .29, -8.01), Vector3(-8.70, -.18, -7.94), Vector3(-8.26, -.45, -7.77),
		], [
			Vector3(-9.91, 1.60, -8.28), Vector3(-9.73, 1.31, -8.01), Vector3(-9.35, .84, -7.90),
			Vector3(-9.02, .29, -7.77), Vector3(-8.77, -.21, -7.52), Vector3(-8.37, -.46, -7.38),
		],
	]
	if refinement_round >= 31:
		spill.set_shader_parameter("aerated_fall", true)
		streams = [
			[
				Vector3(-10.06, 2.52, -8.46), Vector3(-9.93, 2.41, -8.33), Vector3(-9.67, 1.65, -8.06),
				Vector3(-9.30, .83, -7.97), Vector3(-8.82, .048, -7.84), Vector3(-8.53, -.45, -7.74),
			],
			[
				Vector3(-9.92, 2.42, -8.17), Vector3(-9.78, 2.28, -8.10), Vector3(-9.57, 1.47, -7.90),
				Vector3(-9.15, .64, -7.73), Vector3(-8.78, -.16, -7.63), Vector3(-8.43, -.46, -7.51),
			],
			[
				Vector3(-9.82, 2.18, -7.91), Vector3(-9.70, 2.08, -7.83), Vector3(-9.40, 1.42, -7.75),
				Vector3(-9.09, .62, -7.64), Vector3(-8.70, -.12, -7.46), Vector3(-8.36, -.46, -7.39),
			],
		]
	if refinement_round >= 32:
		spill.set_shader_parameter("shelf_film", true)
		streams = [
			[
				Vector3(-10.13, 2.50, -8.52), Vector3(-9.97, 2.37, -8.52), Vector3(-9.67, 1.67, -8.35),
				Vector3(-9.25, .87, -8.12), Vector3(-8.73, .032, -7.94), Vector3(-8.43, -.450, -7.65),
			],
			[
				Vector3(-9.82, 2.21, -7.88), Vector3(-9.66, 1.92, -7.78), Vector3(-9.44, 1.38, -7.56),
				Vector3(-9.16, .78, -7.42), Vector3(-8.69, .012, -7.31), Vector3(-8.28, -.455, -7.07),
			],
		]
	for ribbon in streams:
		var curtain := SurfaceTool.new()
		curtain.begin(Mesh.PRIMITIVE_TRIANGLES)
		var strip_widths := [.18, .25, .31, .36, .43, .60]
		if refinement_round >= 32:
			strip_widths = [.31, .48, .38, .64, .77, .97]
		for row in range(ribbon.size() - 1):
			var a: Vector3 = ribbon[row]
			var d: Vector3 = ribbon[row + 1]
			var side_a := Vector3(-.035, .014, float(strip_widths[row]) * .5)
			var side_d := Vector3(-.035, .014, float(strip_widths[row + 1]) * .5)
			var v := float(row) / float(ribbon.size() - 1)
			var v2 := float(row + 1) / float(ribbon.size() - 1)
			var points := [a - side_a, a + side_a, d + side_d, a - side_a, d + side_d, d - side_d]
			var uv := [Vector2(0, v), Vector2(1, v), Vector2(1, v2), Vector2(0, v), Vector2(1, v2), Vector2(0, v2)]
			for i in points.size():
				curtain.set_uv(uv[i])
				curtain.add_vertex(points[i])
		curtain.generate_normals()
		var stream := _mesh(curtain.commit(), spill, Vector3.ZERO)
		stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if refinement_round >= 31:
		var vapour := FogMaterial.new()
		vapour.density = .092
		vapour.albedo = Color("#a7bab9")
		vapour.edge_fade = 1.0
		var mist := FogVolume.new()
		mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		mist.position = Vector3(-8.5, -.03, -7.61)
		mist.size = Vector3(2.6, 1.1, 3.0)
		mist.material = vapour
		add_child(mist)
	if refinement_round >= 32:
		var ravine_fill := SpotLight3D.new()
		ravine_fill.position = Vector3(-5.80, 5.66, -3.60)
		ravine_fill.light_color = Color("#d7e7d2")
		ravine_fill.light_energy = .90
		ravine_fill.spot_angle = 24.0
		ravine_fill.spot_range = 11.4
		ravine_fill.spot_attenuation = 2.1
		ravine_fill.light_specular = .02
		if refinement_round >= 33:
			ravine_fill.light_color = Color("#eadcc4")
			ravine_fill.light_energy = 1.41
			ravine_fill.spot_attenuation = 1.64
			ravine_fill.light_volumetric_fog_energy = .075
		add_child(ravine_fill)
		ravine_fill.look_at(Vector3(-9.72, 1.00, -7.86), Vector3.UP)


func _jointed_banks() -> void:
	_body(Vector3(-5.42, 0.21, 0), Vector3(0.73, 0.42, 30.8))
	var tide_marks := _stone(Color("#625f56"), 1.92, .58, .90)
	tide_marks.set_shader_parameter("micro_relief", .0035)
	var old_coping := _stone(Color("#a39c82"), 3.68, .58, .93)
	old_coping.set_shader_parameter("micro_relief", .006)
	for side: float in [-1.0, 1.0]:
		var bank_x := -7.01 + side * 1.61
		_box(Vector3(bank_x, -.20, 0), Vector3(.75, .77, 30.8), tide_marks)
		var divider := -15.41
		var widths := [1.49, 2.10, 1.73, 2.44, 1.65, 1.93, 2.24, 1.72]
		var piece := 0
		while divider < 15.35:
			var length := minf(float(widths[(piece + int(side + 1.0)) % widths.size()]), 15.40 - divider)
			var center := divider + length * .5
			var raised := .22 + sin(float(piece) * 2.16 + side * .2) * .025
			var length_trim := .016 if piece % 6 else .036
			_box(Vector3(bank_x, raised, center), Vector3(.68, .14, length - length_trim), old_coping)
			if piece % 5 != 3:
				var shoulder := _box(Vector3(bank_x + side * .006, raised - .065, center),
					Vector3(.77, .085, length - length_trim * 2.0), tide_marks)
				shoulder.rotation.y = sin(float(piece) * 1.94) * .016
			if side < 0 and piece % 4 == 2:
				for step in range(2):
					_box(Vector3(bank_x + .33 + float(step) * .22, -.40 + .11 * float(step), center + .25),
						Vector3(.35, .26 - .08 * step, length * .63), tide_marks)
			divider += length
			piece += 1
	var erosion := [
		[Vector3(-8.17, -.43, 6.6), Vector3(.72,.37,.76)],
		[Vector3(-8.24, -.47, 1.85), Vector3(.84,.42,1.12)],
		[Vector3(-5.81, -.55, -7.8), Vector3(.61,.28,.70)],
		[Vector3(-8.09, -.41, -9.48), Vector3(.65,.29,.83)],
	]
	for piece in erosion:
		var size: Vector3 = piece[1]
		_mesh(_rock(size, _rng.randi()), tide_marks, piece[0])


func _build_relay() -> void:
	var relay := RELAY.instantiate() as Node3D
	relay.name = "BasinRelay"
	relay.position = RELAY_ORIGIN
	add_child(relay)
	_box(Vector3(0, 0.23, -5.0), Vector3(3.14, 0.46, 2.03), _bedrock, true)
	_box(Vector3(0, 0.11, -4.00), Vector3(4.45, 0.22, 0.34), _iron)
	var conduit := _mesh(CylinderMesh.new(), _iron, Vector3(-3.04, 0.085, -5.36))
	conduit.rotation.z = PI / 2.0
	conduit.scale = Vector3(0.13, 3.25, 0.13)
	_signal = OmniLight3D.new()
	_signal.position = Vector3(0.11, 1.08, -3.55)
	_signal.omni_range = 5.8
	_signal.omni_attenuation = 1.48
	add_child(_signal)
	for x in [-2.12, 2.12]:
		_box(Vector3(x, 0.41, -3.72), Vector3(0.26, 0.80, 0.27), _iron)
		_box(Vector3(x, 0.845, -3.72), Vector3(0.205, 0.055, 0.21), _lamp)
		_box(Vector3(x, 0.01, -2.38), Vector3(0.94, 0.029, 0.085), _guide)


func _route_details() -> void:
	var strips := [12.1, 8.6, 5.1, 1.55, -1.65] if refinement_round < 23 else [8.6, 1.55, -1.65]
	var guide_light: Material = _lamp
	if refinement_round >= 26:
		var shielded := _colored(Color("#829ca0"), .67, .18)
		shielded.emission_enabled = true
		shielded.emission = Color("#739398")
		shielded.emission_energy_multiplier = .36
		guide_light = shielded
	for z in strips:
		for x in [-2.56, 2.63]:
			_box(Vector3(x, 0.037, z), Vector3(0.31, 0.025, 0.52), _iron)
			_box(Vector3(x, 0.052, z), Vector3(0.15, 0.009, 0.30), guide_light)
	for z in [3.9, 0.75, -2.15, -5.25, -8.3]:
		_box(Vector3(6.45, 0.04, z), Vector3(0.16, 0.024, 0.58), _guide)
		_box(Vector3(6.45, 0.055, z), Vector3(0.09, 0.008, 0.30), guide_light)
	for z in [-10.3, -5.8, 2.55, 10.0]:
		var marker := _box(Vector3(7.56, 0.29, z), Vector3(0.46, 0.58, 1.64), _ice_stone, true)
		marker.rotation.y = _rng.randf_range(-0.12, 0.12)
		_box(Vector3(7.55, 0.594, z), Vector3(0.31, 0.029, 0.50), _guide)


func _rock_field() -> void:
	var cliffs := [
		[Vector3(-11.2, .65, -9.0), Vector3(5.5, 6.5, 4.4)],
		[Vector3(-13.7, 1.15, -.3), Vector3(7.3, 7.9, 6.8)],
		[Vector3(-11.9, .3, 7.3), Vector3(4.8, 5.1, 6.2)],
		[Vector3(10.4, .75, -10.1), Vector3(5.4, 6.3, 5.9)],
		[Vector3(10.7, .5, -3.0), Vector3(4.3, 4.6, 4.2)],
		[Vector3(12.4, .1, 4.6), Vector3(4.4, 3.6, 4.8)],
		[Vector3(-1.6, .85, -19.9), Vector3(5.9, 8.8, 6.2)],
		[Vector3(5.9, 1.2, -21.6), Vector3(7.4, 10.6, 6.5)],
	]
	for item in cliffs:
		var point: Vector3 = item[0]
		var size: Vector3 = item[1]
		_mesh(_rock(size, _rng.randi()), _bedrock, point)
		if point.x > 8.0 and point.z > -15.0:
			_body(point, Vector3(size.x * .57, size.y * .58, size.z * .61))
	for i in range(20):
		var side := -1.0 if i % 2 == 0 else 1.0
		var offset := _rng.randf_range(0.0, 1.7)
		var point := Vector3(-4.45 + offset * 0.42 if side < 0.0 else 8.6 + offset, 0.06, _rng.randf_range(-13.8, 13.9))
		var size := Vector3(_rng.randf_range(.35, 1.68), _rng.randf_range(.19, .90), _rng.randf_range(.35, 1.43))
		var debris := _mesh(_rock(size, _rng.randi()), _ice_stone, point)
		debris.rotation.y = _rng.randf_range(0.0, TAU)
	for i in range(12):
		var point := Vector3(-35.5 + float(i) * 6.3, _rng.randf_range(.8, 4.2), _rng.randf_range(-44.0, -30.5))
		var size := Vector3(_rng.randf_range(7.0, 13.5), _rng.randf_range(9.0, 19.9), _rng.randf_range(6.0, 12.0))
		_mesh(_rock(size, _rng.randi()), _bedrock, point)


func _plants() -> void:
	var fern := _plant_mat(Vector2(1, 1), Color("aec2b7"))
	var grass := _plant_mat(Vector2(0, 1), Color("bba793"))
	for i in range(57):
		var center := Vector3(-4.58 + _rng.randf_range(-.22, .67), 0, _rng.randf_range(-14.5, 14.3))
		if i % 3 != 0:
			center.x = _rng.randf_range(7.35, 11.0)
		var height := _rng.randf_range(.28, 1.06)
		var quad := QuadMesh.new()
		quad.size = Vector2(height * 1.22, height)
		var yaw := _rng.randf_range(0.0, TAU)
		for turn in [0.0, 1.13]:
			var cluster := _mesh(quad, fern if i % 4 == 0 else grass, center + Vector3(0, height * 0.5 - 0.066, 0))
			cluster.rotation.y = yaw + turn
			cluster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _strip(points: PackedVector3Array, widths: PackedFloat32Array, material: Material) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors := [Color(.74, .81, .83), Color(.95, .98, .98), Color.WHITE, Color(.92, .95, .96), Color(.68, .73, .75)]
	var cross_section := [-.5, -.39, 0.0, .37, .5]
	for span in range(points.size() - 1):
		var first := points[span]
		var last := points[span + 1]
		var first_delta := points[mini(span+1, points.size()-1)] - points[maxi(span-1, 0)]
		var last_delta := points[mini(span+2, points.size()-1)] - points[span]
		var first_right := Vector3(-first_delta.z, 0.0, first_delta.x).normalized()
		var last_right := Vector3(-last_delta.z, 0.0, last_delta.x).normalized()
		for i in range(4):
			var a := first + first_right * widths[span] * float(cross_section[i])
			var b := first + first_right * widths[span] * float(cross_section[i+1])
			var c := last + last_right * widths[span+1] * float(cross_section[i+1])
			var d := last + last_right * widths[span+1] * float(cross_section[i])
			for value in [[a, colors[i]], [c, colors[i+1]], [b, colors[i+1]], [a, colors[i]], [d, colors[i]], [c, colors[i+1]]]:
				builder.set_normal(Vector3.UP)
				builder.set_color(value[1])
				builder.add_vertex(value[0])
	_mesh(builder.commit(), material, Vector3.ZERO)


func _rock(dimensions: Vector3, seed_value: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.76
	var rows := 18
	var cols := 24
	var knots: Array[PackedVector3Array] = []
	for row in range(rows + 1):
		var polar := lerpf(-1.567, 1.567, float(row) / rows)
		var ring := PackedVector3Array()
		for column in range(cols):
			var turn := TAU * float(column) / cols
			var direction := Vector3(cos(turn) * cos(polar), sin(polar), sin(turn) * cos(polar))
			var distress := noise.get_noise_3dv(direction * 3.32)
			var ridge := sin(direction.y * 32.0 + direction.x * 9.9 + distress * 4.8) * .042
			direction.x += direction.y * 0.21
			direction.z -= direction.y * 0.09
			ring.append(direction * dimensions * (0.50 + distress * .127 + ridge))
		knots.append(ring)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows):
		for column in range(cols):
			var next := (column + 1) % cols
			for point in [knots[row][column], knots[row][next], knots[row+1][next], knots[row][column], knots[row+1][next], knots[row+1][column]]:
				mesh.set_color(Color.WHITE)
				mesh.add_vertex(point)
	mesh.index()
	mesh.generate_normals()
	return mesh.commit()


func _stone(tint: Color, scale: float, low: float, high: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STONE_SHADER
	material.set_shader_parameter("stone_atlas", STONE_ATLAS)
	material.set_shader_parameter("atlas_half", 1.0)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("texture_scale", scale)
	material.set_shader_parameter("rough_low", low)
	material.set_shader_parameter("rough_high", high)
	return material


func _plant_mat(quadrant: Vector2, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PLANT_SHADER
	material.set_shader_parameter("plant_atlas", PLANT_ATLAS)
	material.set_shader_parameter("quadrant", quadrant)
	material.set_shader_parameter("foliage_tint", tint)
	return material


func _colored(tint: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = metallic
	return material


func _box(point: Vector3, size: Vector3, material: Material, collides := false) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = size
	var visible_mesh := _mesh(geometry, material, point)
	if collides:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var hit := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		hit.shape = shape
		body.add_child(hit)
		visible_mesh.add_child(body)
	return visible_mesh


func _body(point: Vector3, size: Vector3) -> void:
	var collider := StaticBody3D.new()
	collider.collision_layer = 1
	collider.collision_mask = 0
	collider.position = point
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	hit.shape = shape
	collider.add_child(hit)
	add_child(collider)


func _mesh(geometry: Mesh, material: Material, point: Vector3) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = geometry
	result.material_override = material
	result.position = point
	add_child(result)
	return result


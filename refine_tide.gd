extends Node3D
## Tidelock Traverse. An original tidal intake built into a basalt headland.

const STONE_TEXTURE := preload("res://textures/painted_stone.png")
const STONE := preload("res://painted_stone.gdshader")
const PLANT_TEXTURE := preload("res://textures/painted_plants.png")
const PLANT := preload("res://painted_plants.gdshader")
const WATER := preload("res://refine_tide_water.gdshader")
const SKY := preload("res://refine_tide_sky.gdshader")
const GROUND_TEXTURE := preload("res://textures/refinement_ground.png")
const PAVING := preload("res://refine_tide_paving.gdshader")
const STRATA := preload("res://refine_tide_strata.gdshader")
const ALLOY := preload("res://refine_tide_alloy.gdshader")
const POCKET_WATER := preload("res://refine_tide_pocket.gdshader")
const GATE := Vector3(-3.35, 0, -8.5)

var rng := RandomNumberGenerator.new()
var rock: ShaderMaterial
var concrete: ShaderMaterial
var damp: ShaderMaterial
var strata: ShaderMaterial
var rim_metal: ShaderMaterial
var painted: ShaderMaterial
var seams: StandardMaterial3D
var warm_emission: StandardMaterial3D
var pale_emission: StandardMaterial3D
var shrubs: Array[ShaderMaterial] = []


func _ready() -> void:
	rng.seed = 51326
	rock = _stone("959d9e", 7.6, .76, .96, .018)
	concrete = _stone("b4b6aa", 8.4, .69, .91, .006)
	damp = _stone("677979", 11.7, .48, .81, .009)
	strata = ShaderMaterial.new()
	strata.shader = STRATA
	strata.set_shader_parameter("stone_atlas", STONE_TEXTURE)
	strata.set_shader_parameter("dry_basalt", Color("526267"))
	strata.set_shader_parameter("soaked_basalt", Color("283a3d"))
	strata.set_shader_parameter("ocher", Color("776c4f"))
	strata.set_shader_parameter("algae", Color("52604a"))
	rim_metal = _alloy("94724d", "b89a61", "583b2c", .54, .49)
	painted = _alloy("577475", "859c9a", "484337", .58, .37)
	seams = _color("252f35", .76, .28)
	warm_emission = _color("fac181", .38, .12, 1.9)
	pale_emission = _color("b4eef0", .36, .12, .75)
	shrubs.assign([_plant(Vector2(1, 1), "9fb49c"), _plant(Vector2(0, 1), "a69c78")])
	_set_lighting()
	_build_coast()
	_build_breakwater()
	_build_service_walk()
	_build_tide_gate()
	_build_foreshore_works()
	_build_carved_service_stop()
	_place_details()
	_build_intertidal_shelves()
	_build_cliffside_catchbasin()
	_build_pump_bay()
	_build_cove_reef()
	_build_windward_shelf()
	_build_apron_joints()
	_build_tide_monitor()
	_build_surge_mole()
	_build_route_markings()


func review_views() -> Array:
	return [
		[Vector3(8.0, 3.25, 10.4), Vector3(-2.4, 2.7, -8.4), 49.0],
		[Vector3(12, 23.5, 20.5), Vector3(-1.9, 0.4, -4.7), 48.0],
	]


func route() -> PackedVector2Array:
	return PackedVector2Array([Vector2(5, 13), Vector2(3.5, 7), Vector2(0.7, 2.5), Vector2(2.3, -3.6), Vector2(7.3, -8.4)])


func _set_lighting() -> void:
	var environment := Environment.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("becfdf")
	environment.ambient_light_energy = .64
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("8da5b1")
	environment.fog_depth_begin = 29.0
	environment.fog_depth_end = 126.0
	environment.fog_depth_curve = 1.58
	environment.fog_density = .88
	environment.fog_sky_affect = .30
	environment.ssao_enabled = true
	environment.ssao_radius = 2.5
	environment.ssao_intensity = 2.15
	environment.ssr_enabled = true
	environment.ssr_max_steps = 24
	environment.ssr_fade_in = .21
	environment.ssr_fade_out = 1.48
	environment.glow_enabled = true
	environment.glow_bloom = .065
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffddb0")
	sun.light_energy = 1.83
	sun.light_angular_distance = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	sun.rotation_degrees = Vector3(-28, -57, 0)
	add_child(sun)


func _build_coast() -> void:
	var sea := PlaneMesh.new()
	sea.size = Vector2(220, 270)
	var tide := ShaderMaterial.new()
	tide.shader = WATER
	_mesh(sea, tide, Vector3(-37, -.79, -51))
	var seaward_core := PackedVector2Array([
		Vector2(-2.4, 17), Vector2(-2.7, 12), Vector2(-2.15, 8), Vector2(-1.6, 2),
		Vector2(-2.9, -3), Vector2(-4.5, -9), Vector2(-6.5, -15), Vector2(13.8, -17),
		Vector2(14.1, -9), Vector2(13.3, -3), Vector2(14.6, 2), Vector2(14.0, 10), Vector2(12.8, 17)])
	_prism(seaward_core, -.03, -1.44, concrete, true)
	_prism(seaward_core, -.022, -.031, _paving("a6afab", 1.0))
	var submerged_ledge := PackedVector2Array([
		Vector2(-2.6, 18), Vector2(-4.0, 11), Vector2(-3.0, 5), Vector2(-2.65, 1),
		Vector2(-4.6, -7), Vector2(-6.8, -14), Vector2(9.6, -20), Vector2(9.5, 18)])
	_prism(submerged_ledge, -.43, -2.18, rock)
	var headlands := [
		[Vector3(-9.4, -1.20, -15.6), Vector3(11.5, 6.1, 13.1)],
		[Vector3(-18.6, -1.26, -25), Vector3(11.2, 6.2, 12.4)],
		[Vector3(-22.7, -2.02, -29), Vector3(12.4, 4.1, 12.4)],
	]
	for landmark in headlands:
		_bedded_cliff(landmark[0], landmark[1], -.12, strata)
	_build_escarpment()
	for shelf in [
		[Vector3(-43.5, -1.96, -42.5), Vector3(13.8, 5.22, 7.1), -.38],
		[Vector3(-39.2, -2.16, -40.0), Vector3(17.8, 4.24, 8.4), .28],
		[Vector3(-32.8, -1.49, -37.4), Vector3(16.1, 2.56, 8.9), .13],
	]:
		_bedded_cliff(shelf[0], shelf[1], shelf[2], strata)
	for headland in [
		[Vector3(-67.0, -1.9, -37.9), Vector3(32.4, 7.1, 15.2), .12],
		[Vector3(-59.2, -1.7, -39.6), Vector3(17.6, 6.5, 13.8), -.21],
		[Vector3(-52.6, -1.7, -38.5), Vector3(17.4, 4.2, 11.5), .18],
		[Vector3(-38.5, -2.4, -63.2), Vector3(34, 12.9, 16), -.27],
		[Vector3(-12.3, -2.9, -73.0), Vector3(26, 15.9, 22), .33],
		[Vector3(7.8, -2.5, -73.0), Vector3(25, 10.5, 24), .19],
		[Vector3(26.5, -3.1, -78.5), Vector3(28, 17.2, 21), -.13],
	]:
		_bedded_cliff(headland[0], headland[1], headland[2], strata)
	var toe_rubble := [
		[Vector3(13.5, -.89, -9.3), Vector3(7.4, 3.2, 6.4)],
		[Vector3(11.3, -.88, -14.1), Vector3(6.2, 2.2, 7.6)],
		[Vector3(13.9, -.65, 1.8), Vector3(6.7, 2.0, 9.2)],
		[Vector3(12.6, -.84, 5.7), Vector3(6.2, 1.7, 5.4)],
		[Vector3(-7.1, -.96, -17.0), Vector3(8.4, 2.5, 6.2)],
		[Vector3(-10.2, -.93, -11.4), Vector3(6.9, 2.0, 6.0)],
	]
	for item in toe_rubble:
		var point: Vector3 = item[0]
		var size: Vector3 = item[1]
		_cliff(point, size, rock)
	for index in range(18):
		var far_x := rng.randf_range(-11.2, -2.75)
		var z := rng.randf_range(-17.4, 16.0)
		var scale_value := rng.randf_range(.63, 2.8)
		_cliff(Vector3(far_x, -.89, z), Vector3(scale_value, scale_value * .61, scale_value * 1.2), rock)


func _build_cove_reef() -> void:
	# Sketch a submerged arm into the cove with a surveyed crest, two minor pools,
	# and traces of harder strata where erosion leaves the arm exposed.
	var sections: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(-8.8, -.55, 7.9), Vector3(-10.6, -.33, 5.35),
			Vector3(-11.63, -.48, 3.1), Vector3(-10.9, -.61, 1.18), Vector3(-8.47, -.63, .16)]),
		PackedVector3Array([Vector3(-10.5, -.68, -6.1), Vector3(-13.0, -.59, -8.32),
			Vector3(-14.38, -.55, -11.5), Vector3(-15.5, -.48, -15.4), Vector3(-17.9, -.35, -17.9)]),
		PackedVector3Array([Vector3(-32.08, -.22, -22.2), Vector3(-35.0, -.53, -21.62),
			Vector3(-38.12, -.37, -21.85), Vector3(-42.0, -.19, -22.84),
			Vector3(-45.45, -.36, -23.65), Vector3(-48.08, -.61, -25.05)]),
	]
	var sections_width := PackedFloat32Array([1.94, 2.26, 3.17])
	for section_index in sections.size():
		var section := sections[section_index]
		var section_width := sections_width[section_index]
		_reef_crest(section, section_width)
		for i in range(1, section.size() - 1):
			var crest := section[i]
			var fraction := sin(float(i) * 73.33 + section_width)
			var yaw := -.27 + fraction * .27
			var width := section_width * (1.16 + fraction * .21)
			var tall := .82 + smoothstep(-1.0, 1.0, fraction) * .59
			_bedded_cliff(crest + Vector3(-.08, -.93, .13), Vector3(width, tall, section_width * .91), yaw, strata)
			_bedded_cliff(crest + Vector3(-.96, -.67, -section_width * .63),
				Vector3(width * .77, .41, section_width * .47), yaw - .14, strata)
	_bedded_cliff(Vector3(-43.7, -.62, -21.3), Vector3(6.2, 2.14, 5.3), -.34, strata)
	_bedded_cliff(Vector3(-47.8, -.85, -22.5), Vector3(4.6, 1.45, 4.28), -.22, strata)
	_bedded_cliff(Vector3(-36.1, -.88, -21.35), Vector3(6.2, 1.28, 3.7), -.16, strata)


func _reef_crest(centerline: PackedVector3Array, width: float) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[PackedVector3Array] = []
	for i in centerline.size():
		var center := centerline[i]
		var before := centerline[maxi(0, i - 1)]
		var after := centerline[mini(centerline.size() - 1, i + 1)]
		var outward := Vector3(-(after.z - before.z), 0, after.x - before.x).normalized()
		var spread := width * (.89 + sin(float(i) * 2.15) * .16)
		var jitter := sin(float(i) * 2.33 + width) * .15
		var sides := PackedVector3Array([
			Vector3(center.x, -1.7, center.z) - outward * spread * .95,
			center - outward * spread * .64 - Vector3(0, .14, 0),
			center - outward * spread * .29 + Vector3(0, .095 + jitter, 0),
			center + outward * (.15 + jitter),
			center + outward * spread * .55 - Vector3(0, .22, 0),
			Vector3(center.x, -1.54, center.z) + outward * spread,
		])
		rows.append(sides)
	for i in range(rows.size() - 1):
		for column in range(rows[i].size() - 1):
			var tone := Color(.72, .81, .83) if column in [0, 4] else Color(.91, .96, .91)
			_quad(mesh, rows[i][column], rows[i + 1][column], rows[i + 1][column + 1], rows[i][column + 1], tone)
	mesh.generate_normals()
	_mesh(mesh.commit(), strata, Vector3.ZERO)


func _build_windward_shelf() -> void:
	# A low exposed rib divides the windward froth from the sheltered pool.
	# The centerline also places the local breaker in the sea shader.
	var rib := PackedVector3Array([
		Vector3(-13.26, -.67, -4.16), Vector3(-12.11, -.47, -3.50),
		Vector3(-11.76, -.35, -2.42), Vector3(-10.87, -.27, -1.62),
		Vector3(-10.54, -.49, -.81), Vector3(-10.06, -.64, .23),
	])
	_reef_crest(rib, 1.28)
	_bedded_cliff(Vector3(-11.9, -.94, -2.73), Vector3(2.04, .45, 1.25), .37, strata)
	_bedded_cliff(Vector3(-10.91, -.88, -1.64), Vector3(1.65, .48, 1.49), .74, strata)
	_bedded_cliff(Vector3(-12.87, -.92, -3.68), Vector3(1.54, .37, 1.81), .28, strata)
	_bedded_cliff(Vector3(-10.48, -.94, -.69), Vector3(.70, .4, 1.15), .53, strata)


func _build_escarpment() -> void:
	# Exposed beds dip through the whole headland. The crest stands behind the
	# retreating face, with two low saddles separating the exposed rock masses.
	var coast := PackedVector4Array([
		Vector4(12.61, 5.12, 2.96, 21.5), Vector4(11.47, 6.52, 5.26, 17.8),
		Vector4(10.73, 7.1, 6.18, 13.82), Vector4(10.88, 6.29, 5.82, 10.70),
		Vector4(10.64, 5.73, 4.22, 7.45), Vector4(10.07, 6.25, 6.83, 3.88),
		Vector4(10.35, 6.45, 8.16, 1.08), Vector4(11.15, 7.62, 7.29, -2.55),
		Vector4(10.63, 7.43, 6.35, -5.65), Vector4(10.37, 7.32, 8.05, -8.30),
		Vector4(9.92, 6.35, 8.73, -11.16), Vector4(9.31, 6.03, 7.36, -15.12),
		Vector4(8.65, 6.00, 5.34, -19.25), Vector4(7.31, 7.37, 6.31, -22.48),
		Vector4(5.95, 6.42, 4.33, -26.7), Vector4(6.79, 4.04, 1.62, -29.99),
		Vector4(7.81, 1.02, .05, -33.8),
	])
	# Cross sections run from submerged scree to discontinuous ledges, then
	# sweep across the crest and down the quieter landward side.
	var outline := PackedVector2Array([
		Vector2(-.37,-.32), Vector2(-.12,-.16), Vector2(.0,-.04), Vector2(.06,.09),
		Vector2(.11,.23), Vector2(.16,.31), Vector2(.33,.36), Vector2(.47,.37),
		Vector2(.50,.48), Vector2(.49,.57), Vector2(.56,.64), Vector2(.73,.67),
		Vector2(.77,.75), Vector2(.84,.86), Vector2(.99,.97), Vector2(1.14,1.00),
		Vector2(1.26,.94), Vector2(1.48,.83), Vector2(1.71,.66), Vector2(1.93,.44),
		Vector2(2.19,.07), Vector2(2.29,-.24),
	])
	var upland := strata.duplicate() as ShaderMaterial
	upland.set_shader_parameter("landward_beds", true)
	upland.set_shader_parameter("dry_basalt", Color("566068"))
	upland.set_shader_parameter("soaked_basalt", Color("263c41"))
	upland.set_shader_parameter("ocher", Color("736c58"))
	upland.set_shader_parameter("algae", Color("566151"))
	var variation := FastNoiseLite.new()
	variation.seed = 63217
	variation.frequency = .76
	var profiles: Array[PackedVector3Array] = []
	var resolution := 5
	var last := (coast.size() - 1) * resolution
	for column in range(last + 1):
		var sample := float(column) / resolution
		var index := mini(int(sample), coast.size() - 2)
		var t := sample - float(index)
		var a := coast[maxi(0, index - 1)]
		var b := coast[index]
		var c := coast[index + 1]
		var d := coast[mini(index + 2, coast.size() - 1)]
		var key := b.lerp(c, t)
		var toe := b.x + (c.x - b.x) * t
		var setback := cubic_interpolate(b.y, c.y, a.y, d.y, t)
		var crest := cubic_interpolate(b.z, c.z, a.z, d.z, t)
		var last_headland := 1.0 - smoothstep(-33.8, -30.7, key.w)
		var mid_bench := exp(-pow((key.w - 4.95) / 5.2, 2.0))
		var shoulder := exp(-pow((key.w + 11.04) / 4.6, 2.0))
		var section := PackedVector3Array()
		for row in outline.size():
			var profile := outline[row]
			var windward := clampf(profile.x, 0.0, 1.0)
			var bedrock := variation.get_noise_2d(key.w * .55 + windward * .39, profile.y * 4.35)
			var edge := variation.get_noise_2d(key.w * 1.32, profile.y * 9.1 + 2.5)
			var fault := pow(0.5 + sin(key.w * 2.41 + profile.y * 2.73) * .5, 7.0)
			var fractured := .23 + sin(key.w * .88 + .6) * .18
			var carve := (bedrock * .52 + edge * .062 + fault * fractured * .88) * (1.0 - smoothstep(.79, 1.21, profile.x))
			var washed := smoothstep(.0, .4, profile.y)
			var old_lip := exp(-pow((profile.y - .345) / .132, 2.0)) * mid_bench
			var fault_shelf := exp(-pow((profile.y - .635) / .164, 2.0)) * shoulder
			var face_x := toe + (profile.x - old_lip * .12 - fault_shelf * .094) * setback + carve * washed
			var face_y := maxf(-1.82, profile.y * crest + (bedrock * .20 - edge * .066)
				* washed + sin(key.w * .21 + profile.x) * .196 * washed)
			face_y = lerpf(face_y, -1.57, last_headland)
			var face_z := key.w + (windward * .97 - .73) * sin(key.w * .17) + edge * .07
			section.append(Vector3(face_x, face_y, face_z))
		profiles.append(section)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in profiles.size() - 1:
		var first := profiles[column]
		var second := profiles[column + 1]
		for row in first.size() - 1:
			var tone := Color(.9, .93, .92)
			if row in [0, 2, 4, 8, 12]:
				var strip := smoothstep(-.85, .67, sin(first[row].z * .22 + row * .68))
				tone = tone.lerp(Color(.68,.77,.81), strip * .52)
			_quad(mesh, first[row], second[row], second[row + 1], first[row + 1], tone)
	mesh.generate_normals()
	mesh.index()
	_mesh(mesh.commit(), upland, Vector3.ZERO)
	for index in range(1, coast.size() - 2):
		var toe := profiles[index * resolution][3]
		var skirt_grain := sin(float(index) * 1.67)
		if index % 3 != 1:
			_bedded_cliff(Vector3(toe.x -.28, -.72, toe.z),
				Vector3(1.52 + skirt_grain * .36, 1.31 + skirt_grain * .16, 2.14 + skirt_grain * .73), -.31, upland)
			_lichen_mat(Vector3(toe.x -.35, .0, toe.z + .34), .58 + index % 3 * .27)
		if index in [1, 4, 6, 7, 11]:
			var ledge := profiles[index * resolution][7]
			var hollow := ledge + Vector3(-.015, .011, .19)
			_tuft(hollow, .32, shrubs[0])
			_tuft(hollow + Vector3(.045, .035, -.09), .24, shrubs[1])
	# Chipped terrace lips and talus are distinct from the main profile.
	for point in [
		[Vector3(12.11, .097, 3.92), Vector3(2.45, .95, 2.84), .29],
		[Vector3(11.75, -.23, 5.17), Vector3(2.45, .76, 1.43), .32],
		[Vector3(11.56, -.43, 7.47), Vector3(1.49, .56, 1.58), -.13],
		[Vector3(11.07, -.36, -12.88), Vector3(2.97, 1.0, 2.93), -.42],
		[Vector3(8.83, -.78, -17.78), Vector3(3.78, 1.31, 2.48), .32],
	]:
		_bedded_cliff(point[0], point[1], point[2], upland)
	var toe_ledge := PackedVector3Array([
		Vector3(8.34, -.62, -20.4), Vector3(7.48, -.43, -22.67),
		Vector3(6.31, -.26, -24.48), Vector3(5.63, -.43, -26.28),
		Vector3(5.98, -.82, -28.47), Vector3(7.04, -1.21, -30.71),
	])
	_reef_crest(toe_ledge, 1.83)
	for point in [
		[Vector3(7.46, -.92, -22.11), Vector3(3.12, .98, 2.96), -.29],
		[Vector3(5.83, -.86, -24.90), Vector3(2.53, 1.26, 2.24), .53],
		[Vector3(5.42, -.92, -26.82), Vector3(1.48, .67, 2.1), .14],
		[Vector3(6.48, -1.01, -28.29), Vector3(1.59, .56, 2.1), .33],
	]:
		_bedded_cliff(point[0], point[1], point[2], upland)

func _lichen_mat(anchor: Vector3, span: float) -> void:
	# Each planting occupies the landward cracks between apron and stone.
	for i in range(5):
		var a := float(i) * 2.39996
		var offset := Vector3(cos(a) * span * .39, .015, sin(a) * span * .55)
		_tuft(anchor + offset, .15 + float(i % 3) * .13, shrubs[i % shrubs.size()])


func _build_service_walk() -> void:
	var lane := [Vector3(-1.4, .13, 15.5), Vector3(-1.52, .13, 10.1), Vector3(-.72, .13, 3.9),
		Vector3(-.05, .13, 1.1), Vector3(-1.31, .13, -3.8)]
	for index in range(lane.size() - 1):
		var start: Vector3 = lane[index]
		var end: Vector3 = lane[index + 1]
		_bar(start, end, Vector2(.68, .43), concrete, true)
		_bar(start + Vector3(0, .24, 0), end + Vector3(0, .24, 0), Vector2(.75, .13), painted)
	for index in range(9):
		var z := 14.8 - index * 3.28
		var x := maxf(-.1, -1.34 + (.86 * cos(z * .13)))
		_yard_post(Vector3(x, 0, z))
		if index % 2 == 0:
			_yard_post(Vector3(8.8, 0, z))
		var stripe := _cube(Vector3(7.32 - index * .13, .006, z), Vector3(.116, .012, 1.06), rim_metal, .001)
		stripe.rotation.y = -.1
	var panel_joint := _color("3f4c4c", .91)
	var short_joints := [
		[Vector2(-1.04, 13.0), Vector2(3.1, 12.96)],
		[Vector2(4.52, 12.90), Vector2(8.76, 12.9)],
		[Vector2(2.08, 9.68), Vector2(9.40, 9.68)],
		[Vector2(-.72, 7.25), Vector2(2.88, 7.30)],
		[Vector2(5.30, 5.27), Vector2(8.98, 5.16)],
		[Vector2(-.41, 3.92), Vector2(1.38, 3.92)],
		[Vector2(5.0, .35), Vector2(8.9, .29)],
		[Vector2(-.70, -2.88), Vector2(4.72, -2.91)],
		[Vector2(4.45, -6.36), Vector2(9.20, -6.36)],
	]
	for joint in short_joints:
		var a: Vector2 = joint[0]
		var b: Vector2 = joint[1]
		_bar(Vector3(a.x, .006, a.y), Vector3(b.x, .006, b.y), Vector2(.023, .012), panel_joint)
	for index in range(4):
		var inset := .39 * float(index)
		_cube(Vector3(1.23 + inset, .012, 7.6), Vector3(.18, .016, .66), painted, .003)
	_build_drainage()
	_build_service_props()


func _build_breakwater() -> void:
	var sea_beams := PackedVector2Array([
		Vector2(-34.5,-22.6), Vector2(-26.2,-23.5), Vector2(-19.0,-21.0),
		Vector2(-13.2,-16.8), Vector2(-16.0,-15.6), Vector2(-21.1,-19.0),
		Vector2(-27.5,-20.6), Vector2(-34.0,-20.6)
	])
	_prism(sea_beams, .16, -1.25, concrete)
	var moles := [Vector3(-34.8,-.92,-21.0), Vector3(-31.1,-.99,-23.0),
		Vector3(-27.9,-1.12,-22.0), Vector3(-23.7,-1.01,-20.6), Vector3(-20.1,-.94,-19.0),
		Vector3(-16.2,-1.05,-17.9)]
	for pos in moles:
		_cliff(pos, Vector3(rng.randf_range(3.8,6.0),rng.randf_range(1.0,2.8),rng.randf_range(3.4,5.0)), rock)
	var footing := Vector3(-26.2,0.31,-22.0)
	_cube(footing + Vector3(0,.42,0), Vector3(3.65,1.25,2.84), concrete, .14)
	_cube(footing + Vector3(.2,1.0,0), Vector3(2.62,.25,2.39), painted, .073)
	_cube(footing + Vector3(-.55,2.04,-.13), Vector3(.66,2.15,.67), painted, .053)
	_bar(footing + Vector3(.67,1.08,-.11), footing + Vector3(-.55,2.55,-.11), Vector2(.16,.16), seams)
	_cube(footing + Vector3(-.51,3.14,-.12), Vector3(1.29,.14,1.25), rim_metal, .026)
	_cube(footing + Vector3(-.51,3.32,-.12), Vector3(.43,.27,.39), warm_emission, .039)
	_cube(footing + Vector3(-.51,3.50,-.12), Vector3(.69,.16,.65), painted, .031)
	_bar(footing + Vector3(-.52,3.60,-.13), footing + Vector3(-.82,4.65,-.22), Vector2(.063,.062), seams)
	for offset in [-.69,.22,1.04]:
		_cube(footing + Vector3(offset,.77,1.40), Vector3(.26,.26,.14), painted, .02)


func _build_drainage() -> void:
	for bank in [Vector3(.06,.017,10.78), Vector3(-.12,.017,1.82), Vector3(1.56,.017,-5.07)]:
		_cube(bank, Vector3(1.49,.04,.86), concrete,.025)
		_cube(bank + Vector3(0,.024,0), Vector3(1.35,.035,.73), seams,.02)
		for rail in range(9):
			_cube(bank + Vector3((rail - 4)*.138,.044,0), Vector3(.045,.018,.62),
				rim_metal if rail % 4 == 0 else painted, .005)
	for index in range(7):
		var z := 8.2 - index * 2.38
		var position := Vector3(10.16 + rng.randf_range(-.15,.25), 0, z)
		_cube(position + Vector3(0,.075,0), Vector3(1.47,.20,1.15), concrete,.082)
		for patch in range(4):
			_tuft(position + Vector3(rng.randf_range(-.7,.62),.12,rng.randf_range(-.54,.55)),
				rng.randf_range(.31,.84), shrubs[patch % shrubs.size()])


func _build_service_props() -> void:
	for anchor in [Vector3(8.9,0,6.25), Vector3(9.4,0,5.15)]:
		_cube(anchor + Vector3(0,.47,0), Vector3(.95,.86,.72), painted, .05)
		_cube(anchor + Vector3(0,.91,0), Vector3(1.01,.14,.81), concrete,.035)
		for panel in range(3):
			var brace_x := (panel - 1)*.253
			_cube(anchor + Vector3(brace_x,.45,.39), Vector3(.064,.66,.07), seams, .013)
		_cube(anchor + Vector3(0,.72,.432), Vector3(.25,.055,.023), rim_metal,.009)
	var rail_base := Vector3(-1.51,0,7.99)
	_bar(rail_base, rail_base + Vector3(0,1.65,0), Vector2(.115,.109), painted)
	_cube(rail_base + Vector3(0,1.70,.03), Vector3(.28,.13,.25), concrete,.035)
	_cube(rail_base + Vector3(0,1.72,.182), Vector3(.12,.061,.013), pale_emission,.005)
	for location in [Vector3(-2.1,0,5.45), Vector3(-1.68,0,-2.2), Vector3(8.27,0,3.86),
		Vector3(10.25,0,-3.14), Vector3(8.36,0,-5.79), Vector3(6.67,0,8.23)]:
		var clump: Vector3 = location
		_reeds(clump, 36, .63)


func _build_tide_gate() -> void:
	# Armored tidal intake welded onto a seawall with counterweight cradle.
	var pedestal := _cube(GATE + Vector3(0, -.45, 0), Vector3(8.5, 2.0, 4.1), concrete, .15)
	_body(pedestal.position + Vector3(-.68, .34, .13), Vector3(7.1, 2.45, 4.01))
	_cube(GATE + Vector3(-.25, .51, 0), Vector3(8.7, .26, 4.34), painted, .075)
	for side in [-1, 1]:
		var x := float(side) * 3.39
		_cube(GATE + Vector3(x, 2.45, -.05), Vector3(1.06, 4.5, 2.8), concrete, .13)
		_cube(GATE + Vector3(x, 4.8, -.03), Vector3(1.27, .38, 3.08), painted, .066)
		_cube(GATE + Vector3(x, 2.29, 1.46), Vector3(.72, 3.69, .18), painted, .053)
		_cube(GATE + Vector3(x, 2.85, 1.56), Vector3(.13, 1.52, .06), pale_emission, .012)
		for bolt in range(6):
			_cube(GATE + Vector3(x - side * .24, 1.03 + bolt * .64, 1.60), Vector3(.15, .13, .08), seams, .020)
		var ridge := GATE + Vector3(x * .89, 4.72, -.52)
		var eave := GATE + Vector3(x * .71, 6.13, -.36)
		_bar(ridge, eave, Vector2(.41, .36), painted)
		_bar(ridge + Vector3(0,0,1.41), eave + Vector3(0,0,1.25), Vector2(.34, .31), seams)
		for tube in range(3):
			var z := GATE.z + .07 * tube - .65
			var rim_x := GATE.x + x + float(side) * (.45 + tube * .15)
			var bend := GATE.y + 3.32 - tube * .25
			_pipe(Vector3(rim_x, .6, z), Vector3(rim_x, bend, z), .067, rim_metal)
			_pipe(Vector3(rim_x, bend, z), Vector3(rim_x - side * .62, bend + .49, z), .067, rim_metal)
	_cube(GATE + Vector3(0, 5.09, -.13), Vector3(7.89, .72, 2.15), painted, .11)
	_cube(GATE + Vector3(0, 5.43, .24), Vector3(8.22, .13, 2.31), rim_metal, .048)
	_cube(GATE + Vector3(0, 5.56, 1.49), Vector3(2.25,.33,.10), seams,.031)
	var designation := Label3D.new()
	designation.text = "TIDAL INTAKE 02"
	designation.font_size = 40
	designation.pixel_size = .007
	designation.modulate = Color("dfd4b0")
	designation.outline_size = 0
	designation.position = GATE + Vector3(0, 5.56, 1.557)
	add_child(designation)
	_cube(GATE + Vector3(0, 6.16, .12), Vector3(5.0, .27, 1.65), painted, .060)
	for lug in range(7):
		var x := (lug - 3) * .66
		_cube(GATE + Vector3(x, 5.15, 1.05), Vector3(.40, .19, .14), seams, .021)
		_cube(GATE + Vector3(x, 6.35, .3), Vector3(.29, .14, .45), painted, .022)
	var center := GATE + Vector3(0, 2.86, 1.45)
	_annulus(center - Vector3(0, 0, .38), 2.52, 2.07, .71, painted, 14)
	_annulus(center + Vector3(0, 0, .051), 2.43, 2.30, .19, rim_metal, 32)
	_annulus(center + Vector3(0, 0, .056), 2.19, 2.12, .17, seams, 32)
	_annulus(center + Vector3(0, 0, -.35), 2.075, 1.89, .52, damp, 32)
	_annulus(center + Vector3(0, 0, -.35), 1.90, 1.845, .12, rim_metal, 32)
	_disk(center - Vector3(0, 0, .56), 1.905, .11, seams)
	for blade in range(-4, 5):
		var x := blade * .395
		var span := sqrt(3.42 - x * x)
		var separator := _cube(center + Vector3(x, 0, -.30), Vector3(.065, 2.0 * span, .31), painted, .022)
		separator.rotation.y = .16
	for side in [-1, 1]:
		for slot in range(3):
			var a := .48 + float(slot) * .22
			_ring_light(center, 2.266, a + (PI if side > 0 else 0), .15)
	for bolt in range(18):
		var a := float(bolt) * TAU / 18.0
		var point := center + Vector3(cos(a) * 2.33, sin(a) * 2.33, .17)
		_disk(point, .077, .073, seams, 6)
	_bar(center + Vector3(-1.84, -.74, -.29), center + Vector3(1.84, -.74, -.29), Vector2(.19, .2), painted)
	var glow := OmniLight3D.new()
	glow.position = center + Vector3(-1.0, .5, .75)
	glow.light_color = Color("ffc385")
	glow.light_energy = 1.1
	glow.omni_range = 3.1
	add_child(glow)
	_cube(GATE + Vector3(.05, .669, 2.29), Vector3(6.15, .20, .45), concrete, .052)
	var bridge_start := GATE + Vector3(2.9, 2.21, -.15)
	var bridge_end := GATE + Vector3(12.8, 2.21, -.72)
	_bar(bridge_start, bridge_end, Vector2(1.0, .26), painted)
	_bar(bridge_start + Vector3(0, .76, .48), bridge_end + Vector3(0, .76, .48), Vector2(.044, .045), rim_metal)
	_bar(bridge_start + Vector3(0, .47, .48), bridge_end + Vector3(0, .47, .48), Vector2(.029, .032), seams)
	for step_index in range(10):
		var point := bridge_start.lerp(bridge_end, float(step_index) / 9.0) + Vector3(0, 0, .48)
		_bar(point, point + Vector3(0, .78, 0), Vector2(.045, .048), rim_metal)
	var stairs_start := GATE + Vector3(12.1, .18, 1.4)
	for step_index in range(11):
		var point := stairs_start + Vector3(0, .183 * step_index, -.295 * step_index)
		_cube(point, Vector3(1.16, .18, .42), painted, .02)
	_build_intake_housing()


func _build_intake_housing() -> void:
	var wall := GATE + Vector3(-2.16, 1.12, -2.03)
	_cube(wall, Vector3(4.94, 2.17, 2.23), painted, .14)
	_cube(wall + Vector3(-.36,1.14,.03), Vector3(4.44, .31, 2.55), concrete, .099)
	var outflow := GATE + Vector3(-5.55, -.18, -2.55)
	for pipe_index in range(2):
		var offset := Vector3(0,0, pipe_index * 1.36)
		var fitting := wall + Vector3(-2.2, .25, .24) + offset
		var bend := outflow + Vector3(.84, .94, .57) + offset
		_pipe(fitting, bend, .34, painted)
		_pipe(bend, outflow + offset, .34, painted)
		_pipe(bend + Vector3(.27, .15, 0), bend - Vector3(.15, .01, 0), .42, rim_metal)
		_cube(outflow + Vector3(.38, .13, .01) + offset, Vector3(.33, .76, .93), concrete, .078)
	for support in range(2):
		var x := 6.1 + support * 1.8
		_cube(GATE + Vector3(x, 1.02, -.49), Vector3(.24, 2.17, .72), painted, .032)
		_bar(GATE + Vector3(x - .65, .21, -.48), GATE + Vector3(x, 1.64, -.48), Vector2(.19, .15), seams)


func _build_foreshore_works() -> void:
	var landing := PackedVector2Array([
		Vector2(-2.17, 6.42), Vector2(-5.46, 5.98), Vector2(-7.52, 3.28),
		Vector2(-7.18, -.24), Vector2(-5.93, -2.49), Vector2(-3.04, -3.50),
		Vector2(-2.31, -1.22), Vector2(-1.72, 2.63)
	])
	_build_settling_well(landing)
	_build_well_spillway()
	# The lower intake apron is fed by the gate. Supports are placed below
	# joints and the worn, broken end is visible at the wet edge.
	var bank: Array[Vector3] = [
		Vector3(-3.22, -.33, 6.07), Vector3(-5.26, -.33, 5.54),
		Vector3(-7.18, -.33, 3.15), Vector3(-6.95, -.33, -.17),
		Vector3(-5.91, -.33, -2.29), Vector3(-3.57, -.33, -3.16)
	]
	for index in range(bank.size() - 1):
		var left := bank[index]
		var right := bank[index + 1]
		var middle := left.lerp(right, .54)
		var shoulder := _cube(middle - Vector3(0, .36, 0), Vector3(.72, 1.07, .80), concrete, .09)
		shoulder.rotation.y = .19 - index * .12
		_bar(left, right, Vector2(.43, .33), damp)
		_bar(left + Vector3(0, .19, 0), right + Vector3(0, .19, 0), Vector2(.49, .11), concrete)
		_cube(middle + Vector3(0, .12, 0), Vector3(.68, .15, .77), painted, .065).rotation.y = -.25
		if index in [0, 1, 4]:
			for anchor in [left.lerp(right, .18), left.lerp(right, .79)]:
				var post: Vector3 = anchor
				_cube(post + Vector3(0, .32, 0), Vector3(.15, .39, .15), painted, .017)
			_bar(left.lerp(right, .18) + Vector3(0, .52, 0),
				left.lerp(right, .79) + Vector3(0, .52, 0), Vector2(.043, .058), rim_metal)
		for stone in range(2 + index % 3):
			var off := (stone - 1) * .30
			var rubble := Vector3(middle.x - .27 - off * .35, -.84, middle.z + off * 1.88)
			_cliff(rubble, Vector3(.51 + .17 * stone, .28 + .17 * (stone % 2), .48), rock)
	var intake := Vector3(-5.42, -.38, -1.32)
	_cube(intake + Vector3(0, .36, 0), Vector3(1.22, .83, 1.25), concrete, .072)
	_cube(intake + Vector3(-.64, .28, 0), Vector3(.12, .47, .79), seams, .050)
	for slat in range(5):
		_cube(intake + Vector3(-.711, .26 + slat * .071, 0), Vector3(.036, .022, .64), painted, .002)
	for line in range(2):
		var offset := float(line) * .48
		var receiver := Vector3(-5.42 + offset, -.38, -1.71)
		var footing := Vector3(-5.05 + offset, -.42, -3.41)
		var knee := Vector3(-5.05 + offset, .29, -4.16)
		var inlet := Vector3(-4.57 + offset, .34, -7.86)
		_pipe(receiver, footing, .13, painted)
		_pipe(footing, knee, .13, painted)
		_pipe(knee, inlet, .13, painted)
		_pipe(knee, knee.lerp(inlet, .11), .176, rim_metal)
		_cube(footing - Vector3(0, .22, 0), Vector3(.51, .41, .54), damp, .047)
	for step in range(4):
		var x := -2.31 - float(step) * .285
		var high := -.045 - float(step) * .089
		_cube(Vector3(x, high - .10, 4.24), Vector3(.36, .21, 1.02), concrete, .035)
	for brace in range(3):
		var z := -.24 - brace * 1.80
		var x := 11.31 + brace * .52
		_cube(Vector3(x, .35, z), Vector3(1.41, .66, 1.64), concrete, .067)
		_cube(Vector3(x - .72, .44, z), Vector3(.15, .68, 1.87), painted, .020)
		for rivet in range(3):
			_cube(Vector3(x - .812, .63, z - .51 + rivet * .52), Vector3(.08, .11, .11), rim_metal, .016)
		_reeds(Vector3(x - .52, .10, z + .9), 18, .68)
	# With the shoreline behind it, the maintenance bridge no longer ends
	# on a narrow stair. Its landing receives load into the cliff footing.
	var landing_base := GATE + Vector3(12.8, 1.08, -.72)
	_cube(landing_base, Vector3(1.58, 2.03, 2.13), concrete, .12)
	_cube(landing_base + Vector3(0, 1.11, 0), Vector3(1.75, .22, 2.32), painted, .057)
	_bar(landing_base + Vector3(.28, 1.06, -.89), landing_base + Vector3(1.22, 1.25, -1.57), Vector2(.69, .27), seams)


func _build_settling_well(landing: PackedVector2Array) -> void:
	# The lower working apron wraps around a settling chamber. The chamber
	# is open to the sky for inspection, below the dry walking surface.
	var well := PackedVector2Array([
		Vector2(-3.58, 4.22), Vector2(-4.65, 4.06), Vector2(-6.08, 2.83),
		Vector2(-5.97, 1.11), Vector2(-5.44, .19), Vector2(-4.34, -.13),
		Vector2(-3.67, .84), Vector2(-3.49, 2.54),
	])
	var lining := SurfaceTool.new()
	lining.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := SurfaceTool.new()
	rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var well_center := Vector2(-4.78, 2.22)
	for index in landing.size():
		var next := (index + 1) % landing.size()
		var toe := Vector3(landing[index].x, -.376, landing[index].y)
		var toe_next := Vector3(landing[next].x, -.376, landing[next].y)
		var inner := Vector3(well[index].x, -.376, well[index].y)
		var inner_next := Vector3(well[next].x, -.376, well[next].y)
		_quad(rim, toe, toe_next, inner_next, inner, Color.WHITE)
		_quad(lining, toe_next, toe, toe - Vector3.UP * 1.16, toe_next - Vector3.UP * 1.16, Color(.62,.69,.70))
		_quad(lining, inner, inner_next, inner_next - Vector3.UP * .72, inner - Vector3.UP * .72, Color(.63,.76,.73))
		var projection := (well[index] - well_center).normalized() * .19
		var next_projection := (well[next] - well_center).normalized() * .19
		var coping_y := .10 + .045 * sin(float(index) * 2.1)
		var next_y := .10 + .045 * sin(float(next) * 2.1)
		var cap_inner := inner + Vector3.UP * coping_y
		var cap_next := inner_next + Vector3.UP * next_y
		var cap_outer := cap_inner + Vector3(projection.x, -.026, projection.y)
		var cap_outer_next := cap_next + Vector3(next_projection.x, -.026, next_projection.y)
		_quad(cap, cap_outer, cap_outer_next, cap_next, cap_inner, Color(.88,.91,.89))
		_quad(lining, cap_inner, cap_next, inner_next, inner, Color(.66,.71,.69))
		_quad(lining, cap_outer_next, cap_outer, cap_outer - Vector3.UP * coping_y,
			cap_outer_next - Vector3.UP * next_y, Color(.76,.80,.78))
		var knuckle := (inner + inner_next) * .53 + (inner - inner_next) * .03
		var angle := atan2(inner_next.x - inner.x, inner_next.z - inner.z)
		if index in [1, 3, 5, 6]:
			var cleat := _cube(knuckle + Vector3(.086,.087,0), Vector3(.19,.18,.34), rim_metal,.018)
			cleat.rotation.y = angle
	rim.generate_normals()
	lining.generate_normals()
	cap.generate_normals()
	_mesh(rim.commit(), _paving("8f9a93", 0.0), Vector3.ZERO)
	_mesh(lining.commit(), damp, Vector3.ZERO)
	_mesh(cap.commit(), concrete, Vector3.ZERO)
	_prism(well, -1.13, -1.51, rock)
	var pool := ShaderMaterial.new()
	pool.shader = POCKET_WATER
	_prism(well, -.525, -.546, pool)
	for i in range(3):
		var z := .22 + float(i) * .221
		var step := _cube(Vector3(-4.52, -.433 - .079 * i, z),
			Vector3(.76 + .053 * i, .094, .33), painted, .017)
		step.rotation.y = -.45
	var discharge := Vector3(-5.79, -.356, .89)
	_pipe(discharge + Vector3(-.43, .19, -.33), discharge + Vector3(-.03, .04, .02), .115, painted)
	_pipe(discharge - Vector3(.16, -.092, .117), discharge, .141, rim_metal)


func _build_well_spillway() -> void:
	# The older return-sill receives runoff from the lower intake apron.
	# Its feathered overflow lands below the well's maintenance step.
	var stations := PackedVector3Array([
		Vector3(-4.33, .096, -2.89), Vector3(-4.56, .081, -2.24),
		Vector3(-4.62, -.097, -1.80), Vector3(-4.72, -.119, -1.15),
		Vector3(-4.81, -.276, -.70), Vector3(-4.89, -.28, -.24),
		Vector3(-4.92, -.49, .20), Vector3(-4.95, -.515, .47),
	])
	var lining := SurfaceTool.new()
	lining.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run := SurfaceTool.new()
	run.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(stations.size() - 1):
		var a := stations[i]
		var b := stations[i + 1]
		var across := Vector3((b - a).z, .0, -(b - a).x).normalized()
		var left := across * (.42 + .016 * i)
		var right := across * (.36 + .027 * i)
		_quad(lining, a - left, a + right, b + right, b - left, Color(.69,.74,.73))
		for side: float in [-1.0, 1.0]:
			var edge := across * side * .44
			var from := a + edge + Vector3.UP * .083
			var to := b + edge + Vector3.UP * .083
			if i < stations.size() - 2:
				_bar(from, to, Vector2(.17, .22), concrete if i in [1,3,5] else damp)
		var shallow := .24 + .014 * i
		var deep := .25 + .024 * i
		var v0 := float(i) / (stations.size() - 1)
		var v1 := float(i + 1) / (stations.size() - 1)
		var near := Vector3.UP * .018
		var strip := [a - across * shallow + near, a + across * deep + near,
			b + across * deep + near, b - across * shallow + near]
		var pattern := PackedVector2Array([Vector2(0,v0),Vector2(1,v0),Vector2(1,v1),Vector2(0,v1)])
		for point in [0,1,2,0,2,3]:
			run.set_uv(pattern[point])
			run.add_vertex(strip[point])
		if i in [0,3,5]:
			_cube((a + b) * .5 - Vector3.UP * .219, Vector3(1.13,.23,.36), damp,.04)
	lining.generate_normals()
	run.generate_normals()
	_mesh(lining.commit(), damp, Vector3.ZERO)
	var stream := ShaderMaterial.new()
	stream.shader = POCKET_WATER
	stream.set_shader_parameter("spillway", true)
	_mesh(run.commit(), stream, Vector3.ZERO)
	var grate := stations[0] - Vector3(0,.014,.31)
	_cube(grate, Vector3(.87,.21,.44), concrete,.048)
	for i in range(5):
		var bar := grate + Vector3((i - 2) * .128,.117,-.04)
		_cube(bar, Vector3(.058,.033,.27), painted,.011)
	var riser := grate + Vector3(-.57,.22,-.11)
	_pipe(riser + Vector3(-.44,.26,-.24), riser, .109, painted)
	_pipe(riser, riser + Vector3(.25,-.21,.07), .106, rim_metal)


func _build_carved_service_stop() -> void:
	# A low, diagonally braced service alcove is cut into the base of the
	# cliff where the elevated catwalk delivers to the landward stairs.
	var seat := Vector3(9.23, 2.21, -10.19)
	var lowered := seat + Vector3(.34, -.28, -.31)
	_cube(lowered, Vector3(2.45, .51, 1.91), damp,.092)
	_cube(seat + Vector3(.34, .09, -.26), Vector3(2.33,.17,1.75), painted,.044)
	_cube(seat + Vector3(.43,.92,-.86), Vector3(2.23,1.77,.43), damp,.099)
	for x: float in [-.67, 1.1]:
		var sill := seat + Vector3(x,.13,-.58)
		var crown := sill + Vector3(.10,1.59,-.022)
		_bar(sill, crown, Vector2(.21,.34), painted)
		_cube(sill + Vector3(.01,.03,0),Vector3(.38,.23,.44),concrete,.057)
		_bar(crown, crown + Vector3(.11,-.45,.40), Vector2(.12,.13), seams)
	var roof := _cube(seat + Vector3(.30,1.78,-.47), Vector3(2.51,.22,1.37), painted,.061)
	roof.rotation.z = -.089
	_cube(seat + Vector3(.25,1.80,.22),Vector3(2.45,.11,.07),rim_metal,.017).rotation.z = -.089
	var shutter := seat + Vector3(.21,.81,-.579)
	_cube(shutter, Vector3(1.34,1.09,.075), seams,.041)
	for i in range(9):
		_cube(shutter + Vector3(0,(i - 4) * .105,.058),Vector3(1.19,.045,.037),painted,.009)
	_cube(shutter + Vector3(.53,.26,.099),Vector3(.109,.39,.065),rim_metal,.012)
	_bar(seat + Vector3(1.25,.35,-.53), seat + Vector3(1.54,-.28,-.60),Vector2(.25,.28),damp)
	_pipe(seat + Vector3(1.35,.34,.16),seat + Vector3(1.39,.79,-.28),.083,painted)
	_pipe(seat + Vector3(1.39,.79,-.28),seat + Vector3(1.53,1.42,-.45),.083,rim_metal)


func _place_details() -> void:
	var clusters := [
		Vector3(-2.3, 0, 9.7), Vector3(-1.3, 0, 3.3), Vector3(-2.24, 0, -2.9),
		Vector3(-2.75, 0, -5.45), Vector3(1.3, 0, -7.0), Vector3(2.65, 0, -10.5),
		Vector3(9.16, 0, -6.2), Vector3(10.3, 0, -2.1), Vector3(10.02, 0, 3.0),
		Vector3(9.53, 0, 8.05), Vector3(11.4, 0, 13.45),
	]
	for cell in clusters:
		var anchor: Vector3 = cell
		for detail in range(rng.randi_range(3, 6)):
			var point := anchor + Vector3(rng.randf_range(-.43, .43), 0, rng.randf_range(-.42, .42))
			_tuft(point, rng.randf_range(.24, .69), shrubs[detail % shrubs.size()])
		for rubble in range(4):
			var point := anchor + Vector3(rng.randf_range(-.60, .60), -.203, rng.randf_range(-.67, .67))
			var extent := rng.randf_range(.16, .47)
			_cliff(point, Vector3(extent * rng.randf_range(.9,1.65), extent * .62, extent), concrete)
	for index in range(5):
		var x := 11.0 + float(index) * .17
		var z := 3.0 - float(index) * 2.4
		_cube(Vector3(x, .20, z), Vector3(.78, .49, .89), painted, .058)
		_cube(Vector3(x, .49, z), Vector3(.84, .09, .97), seams, .036)
		_cube(Vector3(x - .36, .37, z), Vector3(.07, .16, .28), rim_metal, .012)
	for index in range(8):
		var z := 13.1 - float(index) * 2.21
		var lip := Vector3(-1.6 + rng.randf_range(-.27,.22), .028, z)
		var cover := _cube(lip, Vector3(.83, .066, 1.36), painted, .029)
		cover.rotation.y = rng.randf_range(-.22,.13)
		for slot in range(3):
			_cube(lip + Vector3(.16 * (slot - 1), .04, 0), Vector3(.02, .011, .97), seams, .0)


func _yard_post(point: Vector3) -> void:
	_cube(point + Vector3(0,.065,0), Vector3(.40,.13,.43), concrete, .048)
	_cube(point + Vector3(0,.34,0), Vector3(.18,.60,.22), painted, .042)
	_cube(point + Vector3(0,.66,0), Vector3(.26,.15,.28), seams, .032)
	_cube(point + Vector3(0,.64,.14), Vector3(.16,.081,.025), pale_emission, .005)


func _build_intertidal_shelves() -> void:
	var mineral_shelf := _stone("899288", 4.9, .64, .92, .015)
	var wet_shelf := _stone("6a8176", 4.1, .44, .75, .012)
	var exposed_foreground := PackedVector3Array([
		Vector3(-3.26, -.28, 16.8), Vector3(-3.65, -.32, 13.7),
		Vector3(-3.41, -.24, 11.53), Vector3(-3.47, -.42, 9.1),
		Vector3(-3.25, -.41, 6.88), Vector3(-4.76, -.40, 5.78)
	])
	var outer_foreground := PackedVector3Array([
		Vector3(-10.1, -1.21, 16.1), Vector3(-10.73, -1.29, 13.42),
		Vector3(-8.23, -1.20, 10.70), Vector3(-9.06, -1.31, 8.42),
		Vector3(-7.73, -1.21, 6.51), Vector3(-7.70, -1.14, 5.61)
	])
	_tidal_rim(exposed_foreground, outer_foreground, mineral_shelf, wet_shelf)
	var exposed_middle := PackedVector3Array([
		Vector3(-6.41, -.36, -3.13), Vector3(-6.0, -.17, -6.74),
		Vector3(-6.48, -.25, -9.33), Vector3(-8.12, -.34, -11.6),
		Vector3(-9.93, -.12, -15.28), Vector3(-13.66, -.36, -18.96)
	])
	var outer_middle := PackedVector3Array([
		Vector3(-7.65, -1.22, -3.66), Vector3(-8.32, -1.24, -7.17),
		Vector3(-10.10, -1.27, -10.95), Vector3(-12.8, -1.22, -12.31),
		Vector3(-12.93, -1.29, -16.3), Vector3(-16.95, -1.20, -19.8)
	])
	_tidal_rim(exposed_middle, outer_middle, mineral_shelf, wet_shelf)
	for detail in [
		[Vector3(-6.64, -.69, 8.30), Vector3(1.65, .44, .57), -.34],
		[Vector3(-7.72, -.75, 11.81), Vector3(1.68, .39, .75), -.61],
		[Vector3(-6.72, -.39, -6.93), Vector3(1.53, .66, .59), -.37],
		[Vector3(-10.64, -.54, -11.39), Vector3(1.96, .71, .81), -.42],
		[Vector3(-13.22, -.57, -15.76), Vector3(2.51, .49, .73), -.37],
	]:
		_bedded_cliff(detail[0], detail[1], detail[2], wet_shelf)


func _tidal_rim(inside: PackedVector3Array, outside: PackedVector3Array, shelf: Material, bottom: Material) -> void:
	var dry_band := SurfaceTool.new()
	var half_wet := SurfaceTool.new()
	dry_band.begin(Mesh.PRIMITIVE_TRIANGLES)
	half_wet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections: Array[PackedVector3Array] = []
	var run: Array[float] = [0.0, .19, .33, .46, .60, .71, .86, 1.0]
	for index in range(inside.size() - 1):
		for step in range(3):
			var along := float(step) / 3.0
			sections.append(_tidal_section(inside[index].lerp(inside[index+1], along),
				outside[index].lerp(outside[index+1], along), run, float(index) + along))
	sections.append(_tidal_section(inside[-1], outside[-1], run, float(inside.size()-1)))
	for index in range(sections.size()-1):
		for band in range(run.size()-1):
			var surface := dry_band if band < 3 else half_wet
			var value := .86 + sin(float(band) * 1.84 + float(index) * .4) * .066
			var tint := Color(value, value + .035, value + .019)
			_quad(surface, sections[index][band], sections[index][band+1],
				sections[index+1][band+1], sections[index+1][band], tint)
	for layer in [dry_band, half_wet]:
		layer.generate_normals()
		_mesh(layer.commit(), shelf if layer == dry_band else bottom, Vector3.ZERO)


func _tidal_section(inside: Vector3, outside: Vector3, widths: Array[float], phase: float) -> PackedVector3Array:
	var ledges: Array[float] = [.11, .08, -.08, -.02, -.09, -.13, -.17, -.22]
	var contour := PackedVector3Array()
	for index in range(widths.size()):
		var amount := widths[index]
		var point := inside.lerp(outside, amount)
		point.x += sin(phase * 2.7 + index * 1.07) * (.08 + amount * .23)
		point.z += sin(phase * 2.1 - index * .71) * (.11 + amount * .20)
		point.y += ledges[index] + sin(phase * 2.41 + index * 1.71) * .064
		contour.append(point)
	return contour


func _build_cliffside_catchbasin() -> void:
	var foundation := _stone("827f71", 3.9, .72, .94, .013)
	var slightly_dry := _stone("a09d8e", 4.3, .68, .90, .009)
	var bronze_wear := _color("85694f", .69, .39)
	var pipe_patina := _color("475d54", .65, .42)
	var point := Vector3(9.49, 0, 5.25)
	var outline := PackedVector2Array([
		Vector2(8.46, 6.48), Vector2(8.34, 5.33), Vector2(8.55, 4.05),
		Vector2(9.84, 3.49), Vector2(10.89, 3.92), Vector2(11.20, 5.66),
		Vector2(10.52, 6.47),
	])
	_prism(outline, .118, -.16, foundation)
	_cube(point + Vector3(.26, .26, -.39), Vector3(1.78, .42, 1.84), foundation, .091).rotation.y = -.10
	_cube(point + Vector3(.31, .47, -.38), Vector3(1.98, .135, 1.91), slightly_dry, .033).rotation.y = -.10
	var recess := point + Vector3(-.29, .577, -.31)
	_cube(recess, Vector3(.57, .071, 1.14), seams, .017).rotation.y = -.12
	for grate in range(7):
		var part := _cube(recess + Vector3(0, .038, -.46 + float(grate) * .150),
			Vector3(.51, .039, .038), painted, .004)
		part.rotation.y = -.12
	var duct_start := point + Vector3(.69, .532, -.92)
	var elbow := point + Vector3(1.18, .69, -.98)
	var duct_end := point + Vector3(1.93, 1.10, -.71)
	_pipe(duct_end, elbow, .153, pipe_patina)
	_pipe(elbow, duct_start, .153, pipe_patina)
	_pipe(duct_start, duct_start.lerp(elbow, .26), .19, bronze_wear)
	_cube(point + Vector3(1.39, .38, -.82), Vector3(.26, .75, .41), foundation, .040)
	var valve := point + Vector3(.63, .72, -.80)
	_pipe(valve - Vector3(0,.24,0), valve + Vector3(0,.04,0), .084, seams)
	_annulus(valve + Vector3(0,.053,0), .18, .116, .056, bronze_wear, 16)
	var drain_begin := point + Vector3(-.92, .13, .55)
	var drain_end := point + Vector3(-.29, .13, .81)
	_bar(drain_begin, drain_end, Vector2(.24, .035), seams)
	for step in range(5):
		var cover := drain_begin.lerp(drain_end, float(step + 1) / 6.0)
		_bar(cover + Vector3(0, .022, -.10), cover + Vector3(0, .022, .10), Vector2(.027, .035), painted)
	for detail in [
		[Vector3(10.71, -.03, 6.41), Vector3(.77, .28, .72), .09],
		[Vector3(10.9, -.06, 5.97), Vector3(.82, .45, .60), -.34],
	]:
		_bedded_cliff(detail[0], detail[1], detail[2], foundation)
	_reeds(Vector3(10.79, .008, 6.46), 13, .53)


func _build_pump_bay() -> void:
	var bay := Vector3(6.45, 0.0, -.65)
	var bay_metal := _alloy("48676a", "758b86", "4d493e", .62, .34)
	var pump_fitting := _alloy("78644d", "998468", "564333", .61, .42)
	var dirty_paint := _alloy("858253", "a4a17b", "595438", .74, .18)
	var steel := _color("777a72", .49, .52)
	var seal := _color("242e33", .84)
	_cube(bay + Vector3(0, .075, 0), Vector3(2.36, .23, 3.82), concrete, .105)
	_body(bay + Vector3(.15, .56, -.05), Vector3(1.72, 1.08, 3.52))
	_cube(bay + Vector3(.11, .192, -.11), Vector3(1.83, .11, 3.44), seams, .059)
	for sill_z in [-1.30, .02, 1.28]:
		_cube(bay + Vector3(.1, .241, sill_z), Vector3(1.69, .13, .27), steel, .023)
		for x in [-.71, .92]:
			_cube(bay + Vector3(x, .31, sill_z), Vector3(.146, .052, .118), rim_metal, .025)
	var pump_start := bay + Vector3(.23, .74, -.94)
	var pump_end := bay + Vector3(.23, .74, .82)
	_pipe(pump_start, pump_end, .43, bay_metal)
	for position in range(6):
		var local := pump_start + Vector3(0, 0, .21 + float(position) * .212)
		_pipe(local, local + Vector3(0, 0, .048), .459, seal if position < 5 else steel)
	for end in [pump_start, pump_end]:
		var midpoint: Vector3 = end
		_pipe(midpoint - Vector3(0, 0, .08), midpoint + Vector3(0, 0, .08), .476, pump_fitting)
		for stud in range(6):
			var a := float(stud) * TAU / 6.0
			var offset := Vector3(cos(a) * .414, sin(a) * .414, 0)
			_cube(midpoint + offset, Vector3(.068, .074, .178), steel, .017)
	var face := bay + Vector3(-.65, .45, .82)
	_cube(face, Vector3(.62, .51, .71), bay_metal, .052)
	_cube(face + Vector3(-.32, .04, 0), Vector3(.082, .39, .56), seal, .02)
	_cube(face + Vector3(-.365, .094, -.067), Vector3(.031, .059, .26), pale_emission, .008)
	_cube(face + Vector3(-.367, -.014, .133), Vector3(.036, .07, .09), dirty_paint, .013)
	var inlet := bay + Vector3(.23, .74, -1.83)
	var elbow := bay + Vector3(.23, .37, -2.22)
	_pipe(pump_start, inlet, .256, bay_metal)
	_pipe(inlet, elbow, .255, bay_metal)
	_pipe(elbow, bay + Vector3(.23, -.05, -2.23), .253, bay_metal)
	_pipe(inlet - Vector3(0, 0, .11), inlet + Vector3(0, 0, .11), .289, pump_fitting)
	var outlet := bay + Vector3(.23, .74, 1.44)
	var return_pipe := bay + Vector3(1.01, .405, 1.44)
	_pipe(pump_end, outlet, .237, bay_metal)
	_pipe(outlet, return_pipe, .235, bay_metal)
	_pipe(return_pipe, bay + Vector3(1.01, -.08, 1.46), .229, bay_metal)
	_pipe(outlet - Vector3(0, 0, .12), outlet + Vector3(0, 0, .12), .267, pump_fitting)
	# Surface drainage shares the bay's longitudinal fall and stays clear of the walking line.
	var drain := bay + Vector3(-1.36, 0.0, .28)
	_cube(drain, Vector3(.325, .049, 4.54), steel, .017)
	_cube(drain + Vector3(0, .026, 0), Vector3(.23, .015, 4.41), seal, .012)
	for slot in range(36):
		_cube(drain + Vector3(0, .038, -2.14 + slot * .123), Vector3(.242, .018, .033), steel, .005)
	for end_z in [-2.11, 2.28]:
		for bar_index in range(5):
			var stripe := _cube(bay + Vector3(-.93 + bar_index * .26, .002, end_z),
				Vector3(.091, .018, .288), dirty_paint, .0)
			stripe.rotation.y = .58
	for anchor in [bay + Vector3(1.33, 0, -.52), bay + Vector3(.9, 0, 2.11)]:
		_lichen_mat(anchor, .51)


func _build_tide_monitor() -> void:
	var anchor := Vector3(-6.58, -.382, 2.48)
	var foundation := _cube(anchor + Vector3(0, .12, 0), Vector3(1.56, .43, 1.23), damp, .075)
	foundation.rotation.y = -.20
	var upright := anchor + Vector3(-.19, .25, .11)
	_bar(upright, upright + Vector3(-.09, 1.42, .0), Vector2(.155, .145), painted)
	var terminal := upright + Vector3(.11, 1.23, -.06)
	_cube(terminal, Vector3(.51, .39, .39), painted, .047).rotation.y = -.18
	_cube(terminal + Vector3(.065, .043, .198), Vector3(.145, .093, .039), pale_emission, .014)
	_cube(terminal + Vector3(.0, .215, .02), Vector3(.58, .082, .50), rim_metal, .019).rotation.y = -.18
	var arm := upright + Vector3(-.49, 1.56, -.14)
	_bar(upright + Vector3(-.11, 1.35, -.08), arm, Vector2(.086, .075), seams)
	_bar(arm, arm + Vector3(-.83, .015, -.12), Vector2(.093, .086), painted)
	var gauge := arm + Vector3(-.81, -.035, -.12)
	_pipe(gauge, gauge - Vector3(0, .305, 0), .071, rim_metal)
	_pipe(gauge - Vector3(0, .28, 0), gauge - Vector3(0, 1.95, 0), .024, seams)
	var mooring := anchor + Vector3(.43, .36, -.68)
	_pipe(mooring, mooring + Vector3(0, .34, 0), .085, seams)
	_pipe(mooring + Vector3(-.16, .29, 0), mooring + Vector3(.16, .29, 0), .053, painted)
	for edge in [-.46, .49]:
		_cube(anchor + Vector3(edge, .344, .44), Vector3(.14, .036, .17), rim_metal, .023)
	var feed := PackedVector3Array([
		Vector3(-.15, 1.18, -7.82), Vector3(.49, .89, -8.50), Vector3(2.15, .88, -9.61),
		Vector3(8.88, .84, -9.62), Vector3(9.59, .60, -9.09), Vector3(10.04, -.05, -8.2),
	])
	for line in range(2):
		var offset := Vector3(0, .22 * float(line), -.28 * float(line))
		for i in range(feed.size() - 1):
			var start := feed[i] + offset
			var finish := feed[i + 1] + offset
			_pipe(start, finish, .118, painted)
			var collar := start.lerp(finish, .21)
			_pipe(collar, collar.lerp(finish, .030), .158, rim_metal)
	for x in [2.16, 4.61, 7.01, 8.74]:
		var stand := Vector3(x, .15, -9.68)
		_cube(stand, Vector3(.57, .34, .48), damp, .042)
		_bar(stand + Vector3(0, .13, 0), stand + Vector3(0, .85, 0), Vector2(.137, .185), seams)
		_cube(stand + Vector3(0, .66, -.05), Vector3(.26, .11, .62), painted, .017)


func _build_surge_mole() -> void:
	# A lower apron extends from the staffed beacon to the seaward protective arm.
	var start := Vector3(-27.22, .24, -21.02)
	var end := Vector3(-36.28, -.02, -21.27)
	var walk := PackedVector2Array([
		Vector2(-27.22, -20.49), Vector2(-30.18, -20.07), Vector2(-34.62, -20.56),
		Vector2(-37.65, -21.44), Vector2(-36.53, -22.1), Vector2(-31.82, -21.35),
		Vector2(-27.17, -21.05),
	])
	_prism(walk, .085, -.94, concrete)
	_bar(start, start.lerp(end, .59), Vector2(.30, .30), damp)
	_bar(start.lerp(end, .59), end, Vector2(.34, .30), damp)
	for i in range(4):
		var location := start.lerp(end, .12 + .226 * i)
		var seaward := location + Vector3(.0, -.21, .61)
		var anchor := _cube(seaward, Vector3(.65, .76, .91), damp, .084)
		anchor.rotation.y = -.14 + i * .07
		_cube(location + Vector3(0, .18, -.23), Vector3(.29, .21, .49), painted, .028)
		if i in [0, 3]:
			_cube(location + Vector3(0, .272, -.25), Vector3(.13, .039, .20), pale_emission, .012)


func _build_route_markings() -> void:
	# The tested walkway curves around the pump and then heads across to the stair apron.
	var walkway := route()
	var waypaint := _alloy("a89873", "b3ab91", "716d57", .84, .07)
	var apron_paint := _alloy("b1aaa0", "cac2ad", "656358", .83, .05)
	for index in range(walkway.size() - 1):
		var a := walkway[index]
		var b := walkway[index + 1]
		var direction := (b - a).normalized()
		var shoulder := Vector2(-direction.y, direction.x) * 1.34
		var stripe_start := a.lerp(b, .13) + shoulder
		var stripe_end := a.lerp(b, .76) + shoulder
		var a3 := Vector3(stripe_start.x, .011, stripe_start.y)
		var b3 := Vector3(stripe_end.x, .011, stripe_end.y)
		_bar(a3, a3.lerp(b3, .55), Vector2(.068, .012), waypaint)
		_bar(a3.lerp(b3, .66), b3, Vector2(.061, .011), waypaint)
	for location in [Vector3(.72, .011, .72), Vector3(2.14, .012, -4.02), Vector3(7.93, .016, -7.39)]:
		var mark: Vector3 = location
		for line in range(2):
			var step := mark + Vector3(.0, .0, line * .29)
			var offset := Vector3(.251, 0, .12)
			_bar(step + offset, step, Vector2(.066, .012), apron_paint)
			_bar(step - Vector3(.251, 0, -.12), step, Vector2(.066, .012), apron_paint)
	var stair_foot := Vector3(8.56, -.055, -6.67)
	_cube(stair_foot, Vector3(1.71, .23, .82), concrete, .072)
	_cube(stair_foot + Vector3(0, .126, .26), Vector3(1.33, .048, .17), painted, .013)
	for tread in range(7):
		_cube(stair_foot + Vector3(-.53 + tread * .167, .158, .26), Vector3(.065, .028, .087), seams, .004)


func _build_apron_joints() -> void:
	var gasket := _color("414b4b", .89)
	var aggregate := _color("677577", .86)
	var old_paint := _alloy("85968e", "a2b2a6", "4e5956", .78, .10)
	var shoulder := [Vector3(4.88, .007, 14.9), Vector3(4.89, .007, 10.95),
		Vector3(4.87, .007, 7.54), Vector3(4.80, .007, 5.27), Vector3(4.66, .007, 2.7),
		Vector3(4.60, .007, -.15), Vector3(4.48, .007, -3.34), Vector3(4.42, .007, -6.33)]
	for i in range(shoulder.size() - 1):
		var a: Vector3 = shoulder[i]
		var b: Vector3 = shoulder[i + 1]
		_bar(a, b, Vector2(.024, .012), gasket)
		if i in [0, 2, 5]:
			_bar(a.lerp(b, .19) - Vector3(.09, 0, 0), a.lerp(b, .72) - Vector3(.09, 0, 0),
				Vector2(.058, .012), old_paint)
	var duct := [Vector3(7.55, .018, .80), Vector3(8.27, .018, -.11),
		Vector3(8.53, .018, -2.34), Vector3(9.47, .018, -3.55), Vector3(10.45, .018, -4.04)]
	for i in range(duct.size() - 1):
		var first: Vector3 = duct[i]
		var second: Vector3 = duct[i + 1]
		_bar(first, second, Vector2(.23, .034), gasket)
		_bar(first + Vector3(0, .024, 0), second + Vector3(0, .024, 0), Vector2(.17, .027), painted)
		for joint in range(2):
			_cube(first.lerp(second, .22 + .47 * joint) + Vector3(0, .040, 0),
				Vector3(.251, .032, .084), rim_metal, .013)
	for point in [Vector3(3.7, .02, 6.1), Vector3(1.84, .02, -3.96), Vector3(6.93, .02, -5.56)]:
		var lid: Vector3 = point
		_cube(lid, Vector3(.62, .044, .72), aggregate, .036)
		_cube(lid + Vector3(0, .028, 0), Vector3(.49, .020, .61), gasket, .012)
		for rail in range(5):
			_cube(lid + Vector3(-.18 + rail * .091, .042, 0), Vector3(.051, .019, .51), aggregate, .008)
		for corner in [Vector2(-.25, -.29), Vector2(.25, .29)]:
			var location: Vector2 = corner
			_cube(lid + Vector3(location.x, .046, location.y), Vector3(.052, .024, .052), rim_metal, .009)
	for a in [Vector3(.34, .004, 11.9), Vector3(.17, .004, 4.2), Vector3(-.05, .004, .46)]:
		var mark: Vector3 = a
		for stripe in range(3):
			var paint := _cube(mark + Vector3(.13 * stripe, 0, .085 * stripe),
				Vector3(.078, .010, .41), old_paint, .001)
			paint.rotation.y = .76


func _ring_light(center: Vector3, radius: float, a: float, angle_width: float) -> void:
	var start := center + Vector3(cos(a) * radius, sin(a) * radius, .16)
	var end := center + Vector3(cos(a + angle_width) * radius, sin(a + angle_width) * radius, .16)
	_bar(start, end, Vector2(.026,.049), warm_emission)


func _annulus(center: Vector3, outer: float, inner: float, depth: float, material: Material, slices: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer_front := outer * .986
	var inner_front := inner * 1.013
	for index in range(slices):
		var a := TAU * float(index) / slices
		var b := TAU * float(index + 1) / slices
		_annulus_band(tool, a, b, outer_front, inner_front, depth * .5, depth * .5)
		_annulus_band(tool, b, a, outer, inner, -depth * .5, -depth * .5)
		_annulus_band(tool, a, b, outer, outer_front, depth * .29, depth * .5)
		_annulus_band(tool, a, b, inner_front, inner, depth * .5, depth * .3)
		_annulus_band(tool, a, b, outer, outer, -depth * .5, depth * .29)
		_annulus_band(tool, b, a, inner, inner, -depth * .5, depth * .3)
	tool.generate_normals()
	_mesh(tool.commit(), material, center)


func _annulus_band(tool: SurfaceTool, a: float, b: float, out_radius: float, in_radius: float, out_z: float, in_z: float) -> void:
	var point_a := Vector3(cos(a), sin(a), 0)
	var point_b := Vector3(cos(b), sin(b), 0)
	_quad(tool, point_b * out_radius + Vector3(0,0,out_z), point_a * out_radius + Vector3(0,0,out_z),
		point_a * in_radius + Vector3(0,0,in_z), point_b * in_radius + Vector3(0,0,in_z), Color.WHITE)


func _disk(point: Vector3, radius: float, depth: float, material: Material, sides: int = 48) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = depth
	cylinder.radial_segments = sides
	_mesh(cylinder, material, point).rotation.x = PI * .5


func _prism(outline: PackedVector2Array, top: float, low: float, material: Material, blocks_walk := false) -> void:
	var vertices := PackedVector3Array()
	var floor_faces := PackedVector3Array()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in outline:
		vertices.append(Vector3(point.x, top, point.y))
	var indices := Geometry2D.triangulate_polygon(outline)
	for index in range(0, indices.size(), 3):
		var triangle := PackedVector3Array([vertices[indices[index]], vertices[indices[index + 1]], vertices[indices[index + 2]]])
		var a := triangle[0]
		var b := triangle[1]
		var c := triangle[2]
		if (b - a).cross(c - a).y > 0.0:
			triangle = PackedVector3Array([a,c,b])
		for point in triangle:
			surface.set_color(Color.WHITE)
			surface.add_vertex(point)
			floor_faces.append(point)
	for index in range(vertices.size()):
		var a := vertices[index]
		var b := vertices[(index + 1) % vertices.size()]
		var c := Vector3(b.x, low, b.z)
		var d := Vector3(a.x, low, a.z)
		_quad(surface, b, a, d, c, Color(.82,.86,.86))
	surface.generate_normals()
	_mesh(surface.commit(), material, Vector3.ZERO)
	if blocks_walk:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var hull := ConcavePolygonShape3D.new()
		hull.backface_collision = true
		hull.set_faces(floor_faces)
		collider.shape = hull
		body.add_child(collider)
		add_child(body)


func _cliff(point: Vector3, dimensions: Vector3, material: Material) -> void:
	var edges := 10
	var layer_count := 7
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = .7
	var rings: Array[PackedVector3Array] = []
	var width_steps: Array[float] = [.89, 1.00, .91, .95, .73, .69, .49]
	var height_steps: Array[float] = [0, .11, .21, .32, .57, .78, 1.0]
	var bearing := rng.randf_range(-PI, PI)
	for layer in range(layer_count):
		var outline := PackedVector3Array()
		for edge in range(edges):
			var a := bearing + float(edge) * TAU / edges
			var direction := Vector2(cos(a),sin(a))
			var irregular := .88 + noise.get_noise_2d(direction.x * 3.2, direction.y * 3.2) * .31
			var h := height_steps[layer]
			var radial := width_steps[layer] * irregular
			var tilt := noise.get_noise_3d(direction.x * 3.1, layer * .43, direction.y * 3.2)
			var height_offset := (.13 * direction.x - .11 * direction.y + tilt * .17) * clampf(float(layer) * .33, 0, 1)
			outline.append(Vector3((direction.x * radial + h * .18) * dimensions.x * .5,
				(h + height_offset) * dimensions.y, direction.y * radial * dimensions.z * .5))
		rings.append(outline)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(layer_count - 1):
		for edge in range(edges):
			var other := (edge + 1) % edges
			var tint := Color.WHITE.lerp(Color("7a898d"), .06 + .23 * float(layer_count - layer) / layer_count)
			_quad(tool, rings[layer][edge], rings[layer][other], rings[layer+1][other], rings[layer+1][edge], tint)
	for edge in range(edges):
		var center := Vector3(dimensions.x * .09, dimensions.y * .972, 0)
		_triangle(tool, center, rings[-1][edge], rings[-1][(edge+1)%edges], Color.WHITE)
	tool.generate_normals()
	_mesh(tool.commit(), material, point)


func _bedded_cliff(point: Vector3, dimensions: Vector3, yaw: float, material: Material) -> void:
	var outline := PackedVector2Array([
		Vector2(-.50, -.20), Vector2(-.37, -.43), Vector2(-.13, -.49),
		Vector2(.28, -.36), Vector2(.45, -.23), Vector2(.52, .05),
		Vector2(.41, .34), Vector2(.17, .47), Vector2(-.14, .53),
		Vector2(-.37, .38), Vector2(-.52, .16)
	])
	var heights := PackedFloat32Array([0.0, .12, .24, .27, .39, .55, .60, .65, .83, .97])
	var widths := PackedFloat32Array([1.03, 1.00, .95, .88, .84, .73, .70, .58, .51, .38])
	var tones := PackedFloat32Array([.61, .73, .76, .96, .78, .89, 1.0, .87, .95, 1.0])
	var rings: Array[PackedVector3Array] = []
	var bias := Vector2(.21 * sin(yaw * 8.0 + .7), .16 * cos(yaw * 7.0))
	for layer in range(heights.size()):
		var ring := PackedVector3Array()
		var h := heights[layer]
		for corner in range(outline.size()):
			var outline_jitter := sin(corner * 4.16 + yaw * 5.0)
			var layer_jitter := sin(corner * 1.48 + layer * .71 + yaw * 5.0)
			var source := outline[corner]
			var profile := source * (widths[layer] + .05 * outline_jitter + .035 * layer_jitter)
			profile += bias * h + Vector2(.05 * sin(layer * .68), .07 * cos(layer * .53))
			var horizontal := Vector2(profile.x * dimensions.x, profile.y * dimensions.z).rotated(yaw)
			var profile_y := h - (source.x * .19 - source.y * .21) * smoothstep(0.0, .25, h)
			profile_y += .048 * layer_jitter * smoothstep(.0, .18, h)
			ring.append(Vector3(horizontal.x, profile_y * dimensions.y, horizontal.y))
		rings.append(ring)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(rings.size() - 1):
		for corner in range(outline.size()):
			var next := (corner + 1) % outline.size()
			var tone := Color(.77, .82, .81).lerp(Color.WHITE, tones[layer])
			_quad(mesh, rings[layer][corner], rings[layer][next], rings[layer + 1][next],
				rings[layer + 1][corner], tone)
	var cap := Vector3.ZERO
	for corner in rings[-1]:
		cap += corner
	cap /= float(outline.size())
	for corner in range(outline.size()):
		_triangle(mesh, cap, rings[-1][corner], rings[-1][(corner + 1) % outline.size()], Color.WHITE)
	mesh.generate_normals()
	_mesh(mesh.commit(), material, point)


func _bar(a: Vector3, b: Vector3, cross_section: Vector2, material: Material, collision := false) -> void:
	var midpoint := (a + b) * .5
	var size := Vector3(cross_section.x, cross_section.y, a.distance_to(b))
	var instance := _cube(midpoint, size, material, minf(cross_section.x, cross_section.y) * .095)
	instance.look_at(b, Vector3.RIGHT if absf((b-a).normalized().y) > .99 else Vector3.UP)
	if collision:
		var body := _body(midpoint, size)
		body.rotation = instance.rotation


func _pipe(from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = from.distance_to(to)
	cylinder.radial_segments = 12
	var segment := _mesh(cylinder, material, (from + to) * .5)
	var direction := (to-from).normalized()
	var cross_axis := Vector3.FORWARD if absf(direction.dot(Vector3.RIGHT)) > .95 else Vector3.RIGHT
	var second_axis := direction.cross(cross_axis).normalized()
	segment.basis = Basis(direction.cross(second_axis), direction, second_axis).orthonormalized()


func _body(point: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.position = point
	return body


func _cube(point: Vector3, size: Vector3, material: Material, bevel: float) -> MeshInstance3D:
	if bevel <= .0001:
		var box := BoxMesh.new()
		box.size = size
		return _mesh(box, material, point)
	var x := size.x * .5
	var z := size.z * .5
	var outline := PackedVector2Array([Vector2(-x+bevel,-z),Vector2(x-bevel,-z),Vector2(x,-z+bevel),
		Vector2(x,z-bevel),Vector2(x-bevel,z),Vector2(-x+bevel,z),Vector2(-x,z-bevel),Vector2(-x,-z+bevel)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for layer in range(4):
		var ring := PackedVector3Array()
		var top := size.y * .5
		var heights: Array[float] = [-top, -top+bevel, top-bevel, top]
		var scale_value := .90 if layer == 0 or layer == 3 else 1.0
		for vertex in outline:
			ring.append(Vector3(vertex.x * scale_value, heights[layer], vertex.y * scale_value))
		rings.append(ring)
	for layer in range(3):
		for index in range(8):
			var next := (index + 1) % 8
			_quad(surface, rings[layer][index], rings[layer][next], rings[layer+1][next], rings[layer+1][index], Color.WHITE)
	for index in range(8):
		var next := (index + 1) % 8
		_triangle(surface, Vector3(0,size.y*.5,0), rings[-1][index], rings[-1][next], Color.WHITE)
		_triangle(surface, Vector3(0,-size.y*.5,0), rings[0][next], rings[0][index], Color.WHITE)
	surface.generate_normals()
	return _mesh(surface.commit(), material, point)


func _tuft(point: Vector3, height: float, material: Material) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(height * .81, height)
	var rotation_base := rng.randf_range(-.80,.80)
	for offset in [0.0, 1.55]:
		var stem := _mesh(mesh, material, point + Vector3(0,height * .5 - .047,0))
		stem.rotation.y = rotation_base + offset
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _reeds(point: Vector3, count: int, scale_value: float) -> void:
	var material := _color("ffffff", .88)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(count):
		var position := Vector3(rng.randf_range(-.48,.48), .008, rng.randf_range(-.44,.44))
		var length := rng.randf_range(.32,.91)*scale_value
		var θ := rng.randf_range(-PI,PI)
		var direction := Vector3(cos(θ),0,sin(θ))*.09
		var wind := Vector3(.32,0,-.25)*length + direction
		var broad := direction.cross(Vector3.UP) * rng.randf_range(.09,.22)
		var tip := position + Vector3(0, length, 0) + wind
		var middle := position + Vector3(0,length*.62,0) + wind*.45
		var tint := Color("545b42").lerp(Color("afa46d"),rng.randf())
		_quad(surface,position-broad*.60,position+broad*.60,middle+broad,middle-broad,tint)
		_triangle(surface,middle-broad,middle+broad,tip,tint.lightened(.065))
	surface.generate_normals()
	var clump := _mesh(surface.commit(),material,point)
	clump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(surface, a,b,c,color)
	_triangle(surface, a,c,d,color)


func _mesh(mesh: Mesh, material: Material, point: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = point
	add_child(instance)
	return instance


func _stone(tint: String, detail_scale: float, low: float, high: float, relief: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STONE
	material.set_shader_parameter("stone_atlas", STONE_TEXTURE)
	material.set_shader_parameter("atlas_half", 1.0)
	material.set_shader_parameter("tint", Color(tint))
	material.set_shader_parameter("texture_scale",detail_scale)
	material.set_shader_parameter("rough_low",low)
	material.set_shader_parameter("rough_high",high)
	material.set_shader_parameter("micro_relief",relief)
	return material


func _color(tint: String, roughness: float, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint)
	material.roughness = roughness
	material.metallic = metallic
	if glow > 0:
		material.emission_enabled = true
		material.emission = Color(tint)
		material.emission_energy_multiplier = glow
	return material


func _alloy(coat: String, edge: String, oxide: String, roughness: float, metal: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ALLOY
	material.set_shader_parameter("paint", Color(coat))
	material.set_shader_parameter("edge", Color(edge))
	material.set_shader_parameter("oxide", Color(oxide))
	material.set_shader_parameter("coat_roughness", roughness)
	material.set_shader_parameter("coat_metal", metal)
	return material


func _plant(quadrant: Vector2, tint: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PLANT
	material.set_shader_parameter("plant_atlas",PLANT_TEXTURE)
	material.set_shader_parameter("quadrant",quadrant)
	material.set_shader_parameter("foliage_tint",Color(tint))
	return material


func _paving(tint: String, apron: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PAVING
	material.set_shader_parameter("ground_atlas", GROUND_TEXTURE)
	material.set_shader_parameter("surface_tint", Color(tint))
	material.set_shader_parameter("apron", apron)
	return material

extends Node3D
## Jagged erosion shelves frame the spillway and keep the two traversal lanes open.

const GEOLOGY_SHADER := preload("res://station_geology_basalt.gdshader")
const PAINTED_ATLAS := preload("res://textures/painted_stone.png")

# Ground footing, width/depth/height, yaw, profile. Kicks in radius break broad
# angular faces into an eroded plinth, tilted bedding and shoulders.
const EAST_WALL := [
	[Vector3(14.7, -0.45, 12.1), Vector3(8.7, 3.8, 7.4), -0.21, 1],
	[Vector3(13.2, -0.30, 4.2), Vector3(7.5, 4.9, 7.1), 0.58, 0],
	[Vector3(13.6, -0.35, -2.6), Vector3(9.2, 6.0, 7.8), -0.39, 0],
	[Vector3(11.9, -0.30, -10.1), Vector3(7.2, 4.7, 5.9), -0.13, 1],
	[Vector3(15.5, -0.50, -13.8), Vector3(8.3, 8.2, 7.8), 0.79, 2],
]
const WEST_WALL := [
	[Vector3(-13.8, -0.55, 7.8), Vector3(8.1, 4.7, 9.3), 0.14, 2],
	[Vector3(-15.1, -0.19, 1.0), Vector3(10.8, 7.6, 9.6), -0.29, 1],
	[Vector3(-13.8, -0.29, -7.1), Vector3(9.7, 5.0, 8.0), 0.64, 0],
	[Vector3(-15.9, -0.53, -12.5), Vector3(12.1, 8.7, 7.5), -0.23, 1],
]
const EAST_FOOT := [
	[Vector3(10.5, -0.19, 7.1), Vector3(4.4, 1.4, 3.1), 0.95, 2],
	[Vector3(10.4, -0.24, 1.6), Vector3(4.9, 1.25, 4.1), 0.17, 1],
	[Vector3(9.9, -0.35, -7.5), Vector3(3.2, 1.15, 3.7), -0.21, 0],
]
const WEST_FOOT := [
	[Vector3(-10.6, -0.34, 4.4), Vector3(3.9, 1.9, 4.9), -0.19, 2],
	[Vector3(-10.7, -0.45, -2.5), Vector3(5.0, 1.4, 4.3), -0.38, 0],
]
const NORTH_PASS := [
	[Vector3(-18.0, -1.25, -22.2), Vector3(13.1, 9.2, 13.1), -0.14, 0],
	[Vector3(-8.8, -1.59, -25.5), Vector3(9.8, 5.9, 10.4), 0.50, 2],
	[Vector3(0.2, -1.43, -34.0), Vector3(11.2, 3.6, 13.2), -0.29, 1],
	[Vector3(12.1, -1.15, -25.5), Vector3(13.1, 10.4, 13.3), 0.27, 0],
	[Vector3(24.5, -1.15, -24.1), Vector3(14.4, 9.9, 12.2), 0.79, 1],
]
const HIGH_RIDGE := [
	[Vector3(-41.5, -5.0, -42.4), Vector3(21.5, 19.7, 13.2), 0.21, 0],
	[Vector3(-30.0, -5.0, -46.0), Vector3(22.4, 22.4, 18.5), -0.64, 0],
	[Vector3(-14.0, -5.0, -47.5), Vector3(24.7, 22.5, 18.2), -0.68, 1],
	[Vector3(6.1, -5.0, -45.7), Vector3(23.0, 16.2, 16.8), 0.16, 0],
	[Vector3(22.2, -5.0, -44.0), Vector3(22.5, 23.6, 19.3), -0.13, 0],
	[Vector3(36.8, -5.0, -40.7), Vector3(21.0, 17.5, 16.3), 0.64, 1],
]

var _random := RandomNumberGenerator.new()
var _dark_basalt: ShaderMaterial
var _warm_basalt: ShaderMaterial
var _distance_basalt: ShaderMaterial
var _weathered_scree: ShaderMaterial
var art_revision := 10


func _ready() -> void:
	_random.seed = 182387
	_dark_basalt = _create_material(Color("26343d"), Color("4a585d"), 0.31, 5.5, 1.84, 0.91)
	_warm_basalt = _create_material(Color("27383e"), Color("59605b"), 0.47, 6.7, 1.68, 0.85)
	_distance_basalt = _create_material(Color("394d58"), Color("526975"), 0.18, 8.4, 2.78, 0.38)
	_weathered_scree = _create_material(Color("25363d"), Color("536268"), 0.34, 2.1, 0.81, 0.92)
	if art_revision >= 23:
		_build_eroded_basin()
	elif art_revision >= 11:
		_build_folded_gorge()
	else:
		_build_wall(EAST_WALL, _dark_basalt, true)
		_build_wall(WEST_WALL, _warm_basalt)
		_build_wall(NORTH_PASS, _dark_basalt)
		_build_wall(HIGH_RIDGE, _distance_basalt)
	if art_revision < 23:
		_build_wall(EAST_FOOT, _dark_basalt, true)
		_build_wall(WEST_FOOT, _warm_basalt)
	_add_scree(Vector3(-4.29, 0.0, 10.2), 3.0, 0.55, -0.35, 15)
	_add_scree(Vector3(-4.58, 0.0, 4.7), 2.8, 0.75, 0.12, 15)
	_add_scree(Vector3(-4.30, 0.0, -3.3), 3.5, 0.85, 0.61, 20)
	_add_scree(Vector3(-4.08, 0.0, -9.2), 3.5, 1.03, -0.14, 16)
	_add_scree(Vector3(9.18, 0.0, 9.6), 3.2, 1.41, 0.29, 18)
	_add_scree(Vector3(9.01, 0.0, 1.8), 4.3, 1.30, -0.41, 20)
	_add_scree(Vector3(9.14, 0.0, -6.85), 3.2, 1.35, 0.29, 16)
	_add_scree(Vector3(6.3, 0.0, -12.55), 4.2, 1.14, 0.76, 16)


func _build_eroded_basin() -> void:
	var east_stone := _create_material(Color("303e47"), Color("89928b"), 0.50, 4.7, 1.16, 0.74)
	var west_stone := _create_material(Color("263741"), Color("778b88"), 0.52, 4.3, 0.92, 0.78)
	var middle_stone := _create_material(Color("334a58"), Color("7b9399"), 0.29, 7.2, 1.69, 0.55)
	var back_stone := _create_material(Color("415a69"), Color("8ba0a7"), 0.13, 11.3, 2.54, 0.39)
	for stone in [east_stone, west_stone, middle_stone, back_stone]:
		stone.set_shader_parameter("eroded_bluff", true)
		stone.set_shader_parameter("oxidized_stone", Color("877357"))
		stone.set_shader_parameter("lichen_stone", Color("6c7860"))
	if art_revision >= 24:
		_regrade_stone(east_stone, "27313a", "606d6c", "72614d", "596953")
		_regrade_stone(west_stone, "263740", "637c80", "74664d", "556757")
		_regrade_stone(middle_stone, "2e4250", "697d87", "655943", "586655")
		_regrade_stone(back_stone, "435a6b", "738b99", "5c625c", "626c60")
	if art_revision >= 27:
		east_stone.set_shader_parameter("fractured_cut", .82)
		west_stone.set_shader_parameter("fractured_cut", 1.0)
		middle_stone.set_shader_parameter("fractured_cut", .45)
		back_stone.set_shader_parameter("fractured_cut", .22)

	# The west bank is undercut near the canal. On the east, flat talus
	# connects two shoulders and leaves the service lane clear.
	var west := PackedVector3Array([
		Vector3(-15.4, 5.30, 22.8), Vector3(-12.8, 5.80, 16.0), Vector3(-12.1, 6.35, 11.8),
		Vector3(-11.3, 7.35, 7.5), Vector3(-10.1, 9.20, 4.4), Vector3(-10.8, 9.55, 1.6),
		Vector3(-10.1, 8.30, -0.15), Vector3(-12.45, 6.35, -3.7), Vector3(-11.7, 7.2, -6.25),
		Vector3(-10.8, 6.30, -8.10), Vector3(-11.75, 5.85, -10.7), Vector3(-14.15, 7.40, -13.45),
		Vector3(-15.4, 10.65, -17.0), Vector3(-18.4, 10.05, -20.7), Vector3(-21.2, 8.65, -26.4),
		Vector3(-26.4, 7.70, -32.2),
	])
	if art_revision >= 31:
		# Distinguish this foreground bluff's silhouette from the larger
		# watershed. A notch gathers rain above the canal outfall.
		west[3] = Vector3(-10.74, 5.96, 7.5)
		west[4] = Vector3(-9.95, 8.98, 4.4)
		west[5] = Vector3(-11.35, 10.12, 1.6)
		west[6] = Vector3(-10.42, 7.24, -.15)
		west[7] = Vector3(-12.72, 5.40, -3.7)
		west[8] = Vector3(-11.84, 6.42, -6.25)
		west[9] = Vector3(-11.52, 7.61, -8.10)
		west[10] = Vector3(-12.41, 5.26, -10.7)
	if art_revision >= 33:
		west[6] = Vector3(-10.74, 7.86, -.15)
		west[7] = Vector3(-13.44, 5.04, -3.7)
		west[8] = Vector3(-12.92, 5.23, -6.25)
		west[9] = Vector3(-12.62, 7.71, -8.10)
		west[10] = Vector3(-12.39, 7.89, -10.7)
		west[11] = Vector3(-14.02, 7.31, -13.45)
	var east := PackedVector3Array([
		Vector3(15.0, 5.7, 23.6), Vector3(12.1, 6.8, 19.8), Vector3(10.4, 6.1, 15.6),
		Vector3(9.2, 4.15, 11.4), Vector3(10.3, 4.75, 8.0), Vector3(9.75, 5.30, 5.65),
		Vector3(8.9, 7.05, 2.90), Vector3(9.35, 7.8, -0.35), Vector3(9.8, 7.4, -3.3),
		Vector3(11.65, 5.1, -6.0), Vector3(12.3, 4.05, -9.0), Vector3(13.05, 5.05, -11.45),
		Vector3(13.8, 6.85, -13.35), Vector3(13.1, 7.6, -16.2), Vector3(16.2, 8.6, -20.4),
		Vector3(20.3, 7.6, -24.5), Vector3(25.1, 6.5, -28.0),
	])
	if art_revision >= 30:
		east[4] = Vector3(11.33, 5.53, 8.0)
		east[5] = Vector3(10.96, 5.86, 5.65)
		east[6] = Vector3(9.65, 8.30, 2.90)
		east[7] = Vector3(9.48, 8.48, -0.35)
		east[8] = Vector3(10.90, 7.9, -3.3)
		east[9] = Vector3(12.76, 5.05, -6.0)
	_build_stratified_bluff("Canal Bluff", west, Vector3.LEFT, -0.86, 6.05, 1417, west_stone)
	_build_stratified_bluff("Service Lane Talus", east, Vector3.RIGHT, -0.73, 5.30, 1913, east_stone, true)

	# Nested spurs read as distinct ridges, and leave a stepped opening behind
	# the station. The farther watershed has a wider, lower central cleft.
	var middle := PackedVector3Array([
		Vector3(-60.6, 8.60, -44.0), Vector3(-45.8, 14.50, -38.4), Vector3(-34.8, 15.75, -32.7),
		Vector3(-27.0, 12.45, -30.2), Vector3(-23.2, 11.8, -26.2), Vector3(-19.8, 10.65, -24.8),
		Vector3(-16.2, 8.95, -25.4), Vector3(-12.5, 7.95, -25.15), Vector3(-9.5, 6.0, -26.1),
		Vector3(-5.35, 4.20, -32.6), Vector3(-0.18, 2.20, -38.0), Vector3(5.7, 2.6, -34.1),
		Vector3(9.65, 4.70, -29.2), Vector3(13.1, 6.0, -26.45), Vector3(18.5, 9.15, -24.9),
		Vector3(23.65, 11.2, -24.4), Vector3(28.1, 12.55, -28.55), Vector3(31.7, 12.1, -29.3),
		Vector3(38.2, 10.9, -34.1), Vector3(47.8, 9.1, -40.0), Vector3(62.1, 7.4, -47.1),
	])
	var high := PackedVector3Array([
		Vector3(-91.0, 19.1, -74.8), Vector3(-73.5, 23.3, -70.4), Vector3(-61.2, 26.1, -65.2),
		Vector3(-50.4, 30.2, -65.6), Vector3(-44.5, 26.05, -60.4), Vector3(-37.1, 25.55, -60.9),
		Vector3(-29.45, 22.2, -60.7), Vector3(-25.1, 21.6, -57.8), Vector3(-18.0, 18.1, -57.9),
		Vector3(-12.2, 14.2, -61.7), Vector3(-3.0, 10.9, -65.45), Vector3(5.8, 12.3, -64.0),
		Vector3(17.2, 14.6, -66.2), Vector3(23.8, 19.2, -63.9), Vector3(28.6, 24.5, -66.7),
		Vector3(33.65, 25.3, -66.0), Vector3(39.4, 23.3, -63.4), Vector3(44.1, 25.7, -67.1),
		Vector3(49.2, 23.2, -68.1), Vector3(57.1, 26.2, -70.2), Vector3(70.8, 21.8, -71.7),
		Vector3(89.4, 17.5, -75.3),
	])
	_build_stratified_bluff("Lower Watershed", middle, Vector3.FORWARD, -2.8, 14.2, 2467, middle_stone)
	_build_stratified_bluff("Outer Watershed", high, Vector3.FORWARD, -6.4, 20.9, 3511, back_stone)
	if art_revision >= 24:
		_build_basin_talus()
	if art_revision >= 28:
		_build_quarried_shoulders(east_stone, west_stone)

	_build_wall([
		[Vector3(9.44, -0.46, 3.8), Vector3(2.35, 1.62, 3.55), 0.14, 1],
		[Vector3(9.56, -0.39, 2.67), Vector3(1.72, 1.28, 2.4), -0.21, 1],
		[Vector3(8.98, -0.22, 2.17), Vector3(1.35, 0.61, 1.78), -0.29, 2],
		[Vector3(9.02, -0.26, -2.65), Vector3(2.35, 1.42, 2.55), -0.37, 2],
		[Vector3(8.65, -0.20, -3.22), Vector3(1.68, 0.74, 1.48), -0.09, 1],
		[Vector3(12.28, -0.22, -5.55), Vector3(2.11, 0.74, 2.15), 0.26, 0],
		[Vector3(10.07, -0.13, 10.8), Vector3(3.15, 1.67, 2.83), -0.53, 2],
		[Vector3(9.21, -0.27, 10.25), Vector3(1.88, 0.88, 1.58), -0.75, 1],
	], east_stone, true)
	_build_wall([
		[Vector3(-9.92, -0.78, 7.1), Vector3(2.79, 1.50, 3.95), -0.29, 2],
		[Vector3(-9.66, -0.75, 5.9), Vector3(2.41, 0.98, 2.89), -0.41, 0],
		[Vector3(-10.07, -0.76, -2.8), Vector3(3.0, 1.84, 4.3), 0.25, 1],
		[Vector3(-9.56, -0.67, -4.5), Vector3(2.58, 0.83, 2.81), 0.41, 2],
		[Vector3(-9.22, -0.85, -5.65), Vector3(1.84, 0.77, 3.01), 0.18, 1],
		[Vector3(-10.2, -0.50, -11.3), Vector3(3.20, 2.14, 2.81), -0.11, 2],
		[Vector3(-9.75, -0.62, -10.15), Vector3(2.45, 0.96, 2.67), -0.09, 1],
	], west_stone)


func _regrade_stone(stone: ShaderMaterial, shade: String, face: String, ochre: String, growth: String) -> void:
	stone.set_shader_parameter("jointed_talus", true)
	stone.set_shader_parameter("shadow_stone", Color(shade))
	stone.set_shader_parameter("exposed_stone", Color(face))
	stone.set_shader_parameter("oxidized_stone", Color(ochre))
	stone.set_shader_parameter("lichen_stone", Color(growth))


func _build_quarried_shoulders(east_stone: ShaderMaterial, west_stone: ShaderMaterial) -> void:
	# Low benches emerge from the exposed geological lip. Their broken
	# edges outline two slumped toes above the narrow west channel.
	var cut_shelf := PackedVector3Array([
		Vector3(-9.07, -0.62, 15.1), Vector3(-9.29, .04, 13.6),
		Vector3(-9.38, .63, 11.8), Vector3(-10.03, 1.25, 9.3),
		Vector3(-9.75, 1.13, 7.4), Vector3(-9.02, .63, 5.9),
		Vector3(-9.31, .29, 4.1), Vector3(-10.40, -.20, 2.3),
		Vector3(-10.58, .36, .5), Vector3(-9.66, .84, -1.48),
		Vector3(-9.29, 1.03, -3.52), Vector3(-9.31, .91, -5.44),
		Vector3(-10.22, 1.25, -6.89), Vector3(-10.68, 1.62, -10.75),
		Vector3(-12.08, .67, -13.04), Vector3(-13.41, -.20, -15.09),
	])
	_build_stratified_bluff("Quarried Canal Shoulder", cut_shelf, Vector3.LEFT, -.84, 2.12, 8621, west_stone)
	var ledges := [
		[Vector3(-11.38, 1.36, 3.85), Vector3(3.2, .43, 4.6), -.27, 1],
		[Vector3(-11.94, 2.43, 2.10), Vector3(2.72, .54, 4.13), -.48, 2],
		[Vector3(-11.27, .87, -4.84), Vector3(2.14, .38, 3.55), .20, 0],
		[Vector3(-10.62, .29, -5.97), Vector3(1.47, .41, 2.7), .25, 2],
		[Vector3(-9.36, -.32, 8.25), Vector3(1.44, .42, 1.84), -.13, 1],
		[Vector3(-9.43, -.35, 2.73), Vector3(1.4, .40, 1.21), .26, 2],
	]
	for ledge in ledges:
		_add_boulder(ledge[0], ledge[1], ledge[2], ledge[3], west_stone)
	for ledge in [
		[Vector3(9.66, .82, 8.8), Vector3(2.55, .45, 3.35), .12, 0],
		[Vector3(10.24, 1.34, 7.57), Vector3(2.76, .43, 3.82), .41, 2],
		[Vector3(9.31, .41, -.41), Vector3(2.96, .34, 2.94), -.33, 1],
		[Vector3(8.36, .02, 7.44), Vector3(1.34, .43, 1.63), -.30, 1],
	]:
		_add_boulder(ledge[0], ledge[1], ledge[2], ledge[3], east_stone)
	if art_revision >= 30:
		var eastern_cut := PackedVector3Array([
			Vector3(10.62, .42, 11.20), Vector3(10.11, 1.39, 9.80),
			Vector3(9.35, 2.23, 8.21), Vector3(9.00, 2.44, 6.52),
			Vector3(8.86, 2.46, 4.85), Vector3(9.22, 3.12, 3.65),
			Vector3(9.78, 4.05, 2.60), Vector3(10.24, 3.54, 1.10),
			Vector3(10.68, 2.05, -.64), Vector3(10.80, 1.28, -2.64),
			Vector3(11.52, .63, -3.91),
		])
		_build_stratified_bluff("East Abutment Exposed Shelf", eastern_cut, Vector3.RIGHT, -.46, 3.67, 4325, east_stone, true)
	if art_revision >= 31:
		var lip := [
			[Vector3(-10.81, 1.96, -7.83), Vector3(2.72, .71, 2.72), .28, 2],
			[Vector3(-10.37, 1.60, -7.97), Vector3(1.89, .44, 2.41), .18, 0],
			[Vector3(-10.23, .47, -6.49), Vector3(1.72, .54, 2.18), -.43, 1],
			[Vector3(-10.87, .58, -9.85), Vector3(2.62, .71, 2.78), -.21, 1],
		]
		for block in lip:
			_add_boulder(block[0], block[1], block[2], block[3], west_stone)
	if art_revision >= 33:
		# The newly cut shelf bridges the valley-side deposits to the
		# parent gorge. Its long, split bed is interrupted at the runnel.
		var upper_shelf := PackedVector3Array([
			Vector3(-14.27, 1.98, 1.92), Vector3(-12.63, 3.06, -.24),
			Vector3(-12.31, 3.33, -2.27), Vector3(-11.80, 2.49, -4.40),
			Vector3(-12.30, 1.63, -5.96), Vector3(-13.16, 1.28, -7.06),
		])
		var warmed_lip := west_stone.duplicate() as ShaderMaterial
		warmed_lip.set_shader_parameter("rock_sediment", .64)
		warmed_lip.set_shader_parameter("exposed_stone", Color("788880"))
		_build_stratified_bluff("Split Upper Canal Shelf", upper_shelf, Vector3.LEFT, -.42, 2.93, 1403, warmed_lip)


func _build_basin_talus() -> void:
	var talus_stone := _create_material(Color("28373c"), Color("647673"), 0.49, 3.4, 0.83, 0.85)
	talus_stone.set_shader_parameter("eroded_bluff", true)
	_regrade_stone(talus_stone, "2a363a", "677670", "797059", "677459")
	if art_revision >= 27:
		talus_stone.set_shader_parameter("fractured_cut", .91)
	var toe := PackedVector3Array([
		Vector3(11.3, 0.32, 16.75), Vector3(9.5, 1.05, 13.65), Vector3(8.66, 1.82, 11.45),
		Vector3(8.38, 2.24, 9.5), Vector3(8.43, 1.35, 7.32), Vector3(9.0, 1.12, 5.6),
		Vector3(8.27, 0.95, 4.21), Vector3(8.12, 1.42, 2.75), Vector3(8.55, 1.96, 0.8),
		Vector3(8.08, 1.2, -0.75), Vector3(8.08, 0.56, -1.95), Vector3(9.70, 0.22, -3.95),
	])
	_build_stratified_bluff("Collapsed East Talus", toe, Vector3.RIGHT, -0.46, 2.30, 1471, talus_stone, true)

	# Low rock deltas mark both shoulders behind the station. A clear stretch
	# of water survives across the original spillway at the center.
	var west_delta := PackedVector3Array([
		Vector3(-23.4, 3.85, -20.9), Vector3(-19.4, 4.19, -19.7), Vector3(-15.4, 3.26, -19.1),
		Vector3(-13.32, 2.30, -18.82), Vector3(-12.2, 1.38, -20.4), Vector3(-11.3, 0.92, -23.1),
		Vector3(-10.35, 0.40, -25.35), Vector3(-9.8, 0.14, -27.5),
	])
	var east_delta := PackedVector3Array([
		Vector3(8.45, 0.15, -26.45), Vector3(9.72, 0.45, -24.1), Vector3(10.8, 0.74, -22.2),
		Vector3(12.26, 1.24, -20.4), Vector3(14.8, 2.15, -19.16),
		Vector3(16.3, 2.68, -18.27), Vector3(19.3, 3.6, -20.25), Vector3(24.0, 4.15, -22.2),
	])
	_build_stratified_bluff("West Basin Silt", west_delta, Vector3.FORWARD, -0.64, 3.5, 1051, talus_stone)
	_build_stratified_bluff("East Basin Silt", east_delta, Vector3.FORWARD, -0.55, 3.85, 3607, talus_stone)
	_build_wall([
		[Vector3(-13.80, -0.66, -23.12), Vector3(3.86, 1.94, 2.9), 0.31, 1],
		[Vector3(-11.98, -0.69, -23.47), Vector3(2.99, 0.97, 2.7), -0.31, 2],
		[Vector3(-9.68, -0.68, -25.72), Vector3(2.54, 0.79, 1.81), 0.22, 0],
		[Vector3(12.14, -0.67, -21.27), Vector3(3.45, 1.40, 2.75), -0.44, 2],
		[Vector3(10.47, -0.55, -22.60), Vector3(2.63, 1.06, 2.70), -0.54, 1],
		[Vector3(9.21, -0.68, -24.65), Vector3(1.90, 0.74, 1.62), -0.29, 0],
	], talus_stone)


func _build_stratified_bluff(label: String, controls: PackedVector3Array, inward: Vector3,
		foot_y: float, retreat: float, seed_value: int, stone: ShaderMaterial, collidable := false) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.21
	noise.fractal_octaves = 3
	var flank := Vector3(inward.z, 0.0, -inward.x)
	var samples := PackedVector3Array()
	var interval := 0.47 if retreat < 8.0 else 0.94
	if art_revision >= 27:
		interval *= .68
	for i in range(controls.size() - 1):
		var current := controls[i]
		var next := controls[i + 1]
		var previous := controls[maxi(i - 1, 0)]
		var following := controls[mini(i + 2, controls.size() - 1)]
		var steps := maxi(1, ceili(current.distance_to(next) / interval))
		for sample in range(steps):
			samples.append(current.cubic_interpolate(next, previous, following, float(sample) / float(steps)))
	samples.append(controls[-1])

	var surfaces: Array[PackedVector3Array] = []
	var surface_colors: Array[PackedColorArray] = []
	var fixed_winding := art_revision >= 24
	var quarry_face := art_revision >= 30 and inward.x > .5 and retreat > 3.0
	const COURSES := 48
	for row in range(COURSES + 1):
		var height := float(row) / 38.0
		var positions := PackedVector3Array()
		var colors := PackedColorArray()
		for column in range(samples.size()):
			var toe := samples[column]
			var meter := toe.dot(flank)
			var fold := noise.get_noise_2d(meter * 0.60, 11.0)
			var flank_split := noise.get_noise_2d(meter * 1.22, 32.0)
			var gully := pow(clampf((flank_split + 0.15) * 1.74, 0.0, 1.0), 1.5)
			var h := minf(height, 1.0)
			var broad_shelf := smoothstep(0.15, 0.36 + fold * 0.21, h) * (1.0 - smoothstep(0.43, 0.75, h))
			var rupture_height := 0.48 + fold * 0.32 + flank_split * 0.17
			var bench := exp(-pow((h - rupture_height) / (0.095 + absf(fold) * 0.19), 2.0))
			var rib := exp(-pow((h - (0.79 - fold * 0.22)) / 0.135, 2.0))
			var local_noise := noise.get_noise_2d(meter * 1.40 + h * 4.1, height * 12.8)
			var local_flank := sin(h * PI) * (local_noise * 0.09 + (gully - 0.20) * 0.17)
			var profile := lerpf(h * h, sqrt(h), 0.45 + fold * 0.38) + broad_shelf * (0.10 + fold * 0.27)
			profile += bench * (fold * 0.19 - 0.115) + rib * (flank_split * 0.22 + 0.052) + local_flank
			profile += smoothstep(0.96, 1.0, h) * 0.055 + maxf(height - 1.0, 0.0) * 4.4
			var y_shape := h + sin(h * PI) * (fold * 0.10 + local_noise * 0.125) - pow(maxf(height - 1.0, 0.0) * 2.3, 1.40)
			if fixed_winding:
				var basin_shape := _eroded_cross_section(height, fold, flank_split, gully, local_noise)
				profile = basin_shape.x
				y_shape = basin_shape.y
			if quarry_face:
				var drape := .075 * sin(meter * .79 + flank_split)
				var foothill_lean := smoothstep(.07, .27 + fold * .15, h) * (.22 + gully * .19)
				var broad_cut := smoothstep(.34 + drape, .44 + drape, h) * (.23 + flank_split * .25)
				var upper_shoulder := smoothstep(.63 + drape, .80 + drape, h) * (.24 + fold * .13)
				profile = .47 * h + foothill_lean + broad_cut + upper_shoulder + maxf(height - 1.0, 0.0) * 3.93
				y_shape += sin(h * PI) * (.11 * fold + .065 * flank_split + .14 * drape)
			if art_revision >= 27:
				var dip := noise.get_noise_2d(meter * .51 + 8.36, 67.0) * .12
				# Split the large folds into fractured shelves. Their bedding
				# drifts with the gorge, preserving the foot and crown extent.
				var strata := h * 7.85 + dip * 4.7 + flank_split * .49
				var phase := fposmod(strata, 1.0)
				var lip := smoothstep(.16, .38, phase) * (1.0 - smoothstep(.46, .84, phase))
				var leaf := smoothstep(.09, .42, h) * (1.0 - smoothstep(.90, 1.0, h))
				var shear := smoothstep(-.42, -.10, local_noise) * (1.0 - smoothstep(-.04, .26, local_noise))
				profile += lip * (.032 + gully * .061) * leaf
				profile += shear * .035 * leaf
				y_shape += (lip * .022 + dip) * leaf
			var base := Vector3(toe.x, lerpf(foot_y, toe.y, y_shape), toe.z)
			base += inward * maxf(-0.20, profile * retreat)
			if fixed_winding and row > 0:
				var progress := (base - surfaces[row - 1][column]).dot(inward)
				base += inward * maxf(0.0, 0.012 - progress)
			elif not fixed_winding:
				base += flank * (fold * 1.9 * sin(h * PI * 0.70) + local_noise * 0.34)
			positions.append(base)
			var dryness := smoothstep(0.018, 0.44 + gully * 0.27, h)
			var exposure := clampf(0.55 + h * 0.25 + local_noise * 0.41 - gully * 0.19, 0.0, 1.0)
			colors.append(Color(exposure, dryness, gully))
		surfaces.append(positions)
		surface_colors.append(colors)

	var rock := MeshInstance3D.new()
	rock.name = label
	rock.mesh = _stratified_mesh(surfaces, surface_colors, inward, fixed_winding)
	rock.material_override = stone
	add_child(rock)
	if collidable:
		var cliff := StaticBody3D.new()
		cliff.collision_layer = 1
		cliff.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.shape = rock.mesh.create_trimesh_shape()
		cliff.add_child(collision)
		rock.add_child(cliff)


func _eroded_cross_section(height: float, fold: float, split: float, gully: float, noise_value: float) -> Vector2:
	var h := minf(height, 1.0)
	var slump := smoothstep(0.01, 0.22 + fold * 0.15, h) * (0.21 + gully * 0.15)
	var lowest_course := smoothstep(0.26 + fold * 0.18, 0.42 + fold * 0.19, h) * (0.15 + split * 0.18)
	var upper_course := smoothstep(0.53 + split * 0.30, 0.78 + split * 0.19, h) * (0.16 + fold * 0.19)
	var crown := smoothstep(0.86 + split * 0.12, 1.0, h) * (0.174 - fold * 0.13)
	var flank := pow(h, 1.38) * (0.39 + fold * 0.28) + sin(h * PI) * (gully * 0.235 + noise_value * 0.06)
	var behind := maxf(height - 1.0, 0.0)
	return Vector2(
		flank + slump + lowest_course + upper_course + crown + behind * 3.9,
		h + sin(h * PI) * (0.08 * fold + 0.05 * noise_value) - pow(behind * 2.34, 1.3)
	)


func _stratified_mesh(rows: Array[PackedVector3Array], colors: Array[PackedColorArray], inward: Vector3,
		fixed_winding: bool) -> ArrayMesh:
	var width := rows[0].size()
	var flank := Vector3(inward.z, 0.0, -inward.x)
	var forward := (rows[0][-1] - rows[0][0]).dot(flank) >= 0.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var vertex_colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row in range(rows.size()):
		for column in range(width):
			var vertical := rows[mini(row + 1, rows.size() - 1)][column] - rows[maxi(row - 1, 0)][column]
			var horizontal := rows[row][mini(column + 1, width - 1)] - rows[row][maxi(column - 1, 0)]
			var normal := vertical.cross(horizontal).normalized()
			var facing := -inward + Vector3.UP * smoothstep(20.0, 41.0, float(row))
			vertices.append(rows[row][column])
			var front := forward if fixed_winding else normal.dot(facing) >= 0.0
			normals.append(normal if front else -normal)
			vertex_colors.append(colors[row][column])
			if row == rows.size() - 1 or column == width - 1:
				continue
			var index := row * width + column
			var edge := rows[row][column + 1] - rows[row][column]
			var rise := rows[row + 1][column] - rows[row][column]
			var face_front := forward if fixed_winding else rise.cross(edge).dot(facing) >= 0.0
			if face_front:
				indices.append_array(PackedInt32Array([index, index + 1, index + width + 1, index, index + width + 1, index + width]))
			else:
				indices.append_array(PackedInt32Array([index, index + width, index + width + 1, index, index + width + 1, index + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = vertex_colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_folded_gorge() -> void:
	var near_slate := _create_material(Color("2a3a44"), Color("708186"), 0.42, 4.9, 1.36, 0.89)
	var wet_slate := _create_material(Color("273940"), Color("69746d"), 0.55, 6.3, 1.17, 0.86)
	var middle_slate := _create_material(Color("344753"), Color("627782"), 0.24, 7.1, 2.07, 0.71)
	var high_slate := _create_material(Color("435963"), Color("748891"), 0.15, 9.5, 2.61, 0.51)
	for stone in [near_slate, wet_slate, middle_slate, high_slate]:
		stone.set_shader_parameter("layered_ridge", true)

	# Y coordinates are the surveyed crest at each cut, while XZ trace the toe.
	var west := PackedVector3Array([
		Vector3(-14.4, 4.3, 24.0), Vector3(-13.5, 5.0, 15.7), Vector3(-11.7, 6.1, 9.3),
		Vector3(-11.9, 7.4, 5.6), Vector3(-12.3, 8.3, 0.7), Vector3(-13.5, 7.8, -2.1),
		Vector3(-12.6, 6.0, -6.9), Vector3(-11.4, 5.45, -9.2), Vector3(-12.5, 6.55, -11.8),
		Vector3(-14.4, 8.7, -16.7), Vector3(-16.2, 8.1, -23.2), Vector3(-21.8, 6.0, -29.2),
	])
	var east := PackedVector3Array([
		Vector3(15.5, 5.2, 25.8), Vector3(12.5, 6.3, 16.2), Vector3(12.3, 5.8, 12.8),
		Vector3(11.4, 4.1, 7.4), Vector3(10.7, 5.7, 3.2), Vector3(10.9, 7.0, -1.6),
		Vector3(11.9, 6.85, -5.4), Vector3(12.9, 4.3, -8.7), Vector3(11.9, 4.9, -12.8),
		Vector3(14.5, 6.8, -17.9), Vector3(16.9, 8.3, -21.4), Vector3(24.6, 6.15, -28.2),
	])
	_build_escarpment(west, Vector3.LEFT, -0.83, 5.5, 17.0, wet_slate)
	_build_escarpment(east, Vector3.RIGHT, -0.67, 4.8, 31.0, near_slate, true)

	# Choose two overlapping silhouettes with different rhythms at the center saddle.
	var lower := PackedVector3Array([
		Vector3(-54.0, 7.6, -38.0), Vector3(-40.7, 12.8, -33.7),
		Vector3(-31.2, 13.6, -29.4), Vector3(-24.6, 10.5, -25.8),
		Vector3(-20.1, 9.45, -24.7), Vector3(-15.8, 8.2, -22.7),
		Vector3(-9.2, 5.4, -22.9), Vector3(-5.6, 5.8, -25.1),
		Vector3(0.8, 2.25, -30.7), Vector3(7.4, 3.6, -31.2),
		Vector3(12.5, 5.4, -28.6), Vector3(18.2, 7.45, -25.7),
		Vector3(23.0, 9.8, -24.8), Vector3(28.3, 11.8, -28.8),
		Vector3(35.2, 10.5, -31.6), Vector3(45.6, 11.9, -35.2), Vector3(58.2, 8.0, -40.2),
	])
	var high := PackedVector3Array([
		Vector3(-84.2, 16.7, -66.0), Vector3(-65.1, 22.4, -64.2),
		Vector3(-52.6, 24.0, -59.8), Vector3(-44.6, 20.9, -55.8),
		Vector3(-34.0, 23.9, -58.2), Vector3(-26.1, 25.3, -56.0),
		Vector3(-18.7, 20.8, -54.1), Vector3(-10.0, 16.7, -51.8),
		Vector3(-1.9, 13.5, -59.2), Vector3(8.4, 14.1, -64.1),
		Vector3(18.1, 16.8, -63.1), Vector3(28.1, 22.6, -58.2),
		Vector3(35.2, 25.8, -63.8), Vector3(43.6, 23.2, -64.9),
		Vector3(49.8, 19.1, -61.2), Vector3(61.4, 22.4, -66.5), Vector3(83.9, 17.9, -68.0),
	])
	_build_escarpment(lower, Vector3.FORWARD, -2.6, 12.4, 53.0, middle_slate)
	_build_escarpment(high, Vector3.FORWARD, -5.7, 19.4, 101.0, high_slate)

	_build_wall([
		[Vector3(-10.7, -0.42, 1.0), Vector3(3.7, 1.9, 4.3), -0.53, 1],
		[Vector3(-11.1, -0.33, -6.8), Vector3(4.5, 2.4, 3.5), 0.34, 2],
		[Vector3(-10.5, -0.46, -12.8), Vector3(4.9, 2.9, 4.3), -0.12, 0],
	], wet_slate)
	_build_wall([
		[Vector3(10.6, -0.37, 11.5), Vector3(3.0, 2.0, 4.6), 0.32, 2],
		[Vector3(11.1, -0.40, -3.75), Vector3(4.1, 2.9, 3.3), -0.43, 1],
	], near_slate, true)


func _build_escarpment(controls: PackedVector3Array, inward: Vector3, foot_y: float,
		depth: float, seed_offset: float, stone: ShaderMaterial, collidable := false) -> void:
	var flank := Vector3(inward.z, 0.0, -inward.x)
	var broken_line := FastNoiseLite.new()
	broken_line.seed = int(seed_offset * 107.0)
	broken_line.frequency = 0.19
	var banks := [
		Vector2(0.00, 0.00), Vector2(0.07, 0.13), Vector2(0.15, 0.26),
		Vector2(0.24, 0.31), Vector2(0.30, 0.32), Vector2(0.32, 0.40),
		Vector2(0.44, 0.44), Vector2(0.54, 0.49), Vector2(0.58, 0.55),
		Vector2(0.61, 0.67), Vector2(0.73, 0.70), Vector2(0.86, 0.78),
		Vector2(0.93, 0.84), Vector2(1.00, 1.00), Vector2(0.93, 1.19),
		Vector2(0.72, 1.59), Vector2(0.36, 2.05), Vector2(0.00, 2.42),
	]
	var spacing := 1.65 if depth < 8.0 else 3.15
	var samples := PackedVector3Array()
	for i in range(controls.size() - 1):
		var left := controls[i]
		var right := controls[i + 1]
		var steps := maxi(1, ceili(left.distance_to(right) / spacing))
		for step in range(steps):
			samples.append(left.lerp(right, float(step) / float(steps)))
	samples.append(controls[-1])

	var vertices: Array[PackedVector3Array] = []
	for row in range(banks.size()):
		var course: Vector2 = banks[row]
		var ridge := PackedVector3Array()
		for i in range(samples.size()):
			var toe := samples[i]
			var meter := toe.dot(flank)
			var erosion := broken_line.get_noise_2d(meter, float(row) * 0.88)
			var chute := broken_line.get_noise_2d(meter * 1.8, 43.0)
			var apron := sin(meter * 0.19 + seed_offset) * 0.13
			var rock_spur := (erosion * 0.34 + chute * 0.17 + apron) * (0.29 + sin(course.x * PI) * 0.71)
			var slope := course.x * (1.0 + (erosion * 0.09 + chute * 0.14) * sin(course.x * PI))
			var position := Vector3(toe.x, lerpf(foot_y, toe.y, slope), toe.z)
			position += inward * (course.y + rock_spur) * depth
			position += flank * course.x * (chute * 0.91 + erosion * 0.37)
			ridge.append(position)
		vertices.append(ridge)

	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(vertices.size() - 1):
		for i in range(samples.size() - 1):
			var a := vertices[row][i]
			var b := vertices[row][i + 1]
			var c := vertices[row + 1][i + 1]
			var d := vertices[row + 1][i]
			var old := broken_line.get_noise_2d(samples[i].dot(flank), seed_offset + 13.0) * 0.16
			var course: Vector2 = banks[row]
			var damp := smoothstep(0.03, 0.62, course.x)
			var paint := Color(0.58 + old + course.x * 0.12, 0.36 + damp * 0.64, 1.0)
			var facing := Vector3.UP if row >= 13 else (-inward + Vector3.UP * 0.31).normalized()
			_escarpment_face(mesh, a, b, c, facing, paint)
			_escarpment_face(mesh, a, c, d, facing, paint)

	var rock := MeshInstance3D.new()
	rock.mesh = mesh.commit()
	rock.material_override = stone
	add_child(rock)
	if collidable:
		var cliff := StaticBody3D.new()
		cliff.collision_layer = 1
		cliff.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.shape = rock.mesh.create_trimesh_shape()
		cliff.add_child(collision)
		rock.add_child(cliff)


func _escarpment_face(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		facing: Vector3, paint: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.dot(facing) >= 0.0:
		_triangle(mesh, a, b, c, normal, paint)
	else:
		_triangle(mesh, a, c, b, -normal, paint)


func _create_material(shadow: Color, face: Color, sediment: float, texture_scale: float,
		belt: float, detail: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GEOLOGY_SHADER
	material.set_shader_parameter("painted_atlas", PAINTED_ATLAS)
	material.set_shader_parameter("shadow_stone", shadow)
	material.set_shader_parameter("exposed_stone", face)
	material.set_shader_parameter("oxidized_stone", Color("5b5340"))
	material.set_shader_parameter("lichen_stone", Color("46584c"))
	material.set_shader_parameter("rock_sediment", sediment)
	material.set_shader_parameter("pattern_scale", texture_scale)
	material.set_shader_parameter("belt_size", belt)
	material.set_shader_parameter("detail_amount", detail)
	return material


func _build_wall(wall: Array, material: ShaderMaterial, collidable: bool = false) -> void:
	for spec in wall:
		var boulder := _add_boulder(spec[0], spec[1], spec[2], spec[3], material)
		if collidable:
			var collider := StaticBody3D.new()
			collider.collision_layer = 1
			collider.collision_mask = 0
			var collision := CollisionShape3D.new()
			var hull := boulder.mesh.create_convex_shape()
			collision.shape = hull
			collider.add_child(collision)
			boulder.add_child(collider)


func _add_scree(center: Vector3, depth: float, width: float, yaw: float, count: int) -> void:
	for i in range(count):
		var local := Vector3(_random.randfn(0.0, width * 0.35), 0.0, _random.randfn(0.0, depth * 0.30))
		local.x = clampf(local.x, -width * 0.62, width * 0.62)
		local.z = clampf(local.z, -depth * 0.63, depth * 0.63)
		local = local.rotated(Vector3.UP, yaw)
		var stone_scale := _random.randf_range(0.25, 0.96) * (1.0 if i < 3 else 0.49)
		var dimensions := Vector3(stone_scale * _random.randf_range(1.0, 2.1), stone_scale * _random.randf_range(0.47, 0.92), stone_scale * _random.randf_range(0.77, 1.76))
		_add_boulder(center + local + Vector3(0.0, -0.043, 0.0), dimensions, yaw + _random.randf_range(-1.4, 1.4), 1, _weathered_scree)


func _add_boulder(ground: Vector3, dimensions: Vector3, yaw: float, profile: int, material: ShaderMaterial) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _cliff_mesh(dimensions, profile)
	instance.material_override = material
	instance.position = ground
	instance.rotation.y = yaw
	add_child(instance)
	return instance


func _cliff_mesh(dimensions: Vector3, profile: int) -> ArrayMesh:
	# Coherent, bevelled splice points extents. One wall has only four or five
	# strong folds from gameplay height even after the bevels are visible.
	var ring_count := 9 if profile != 2 else 8
	var angular := PackedFloat32Array()
	var radii := PackedFloat32Array()
	var breaks := PackedFloat32Array()
	var crack_bias := PackedFloat32Array()
	var phase := _random.randf_range(0.0, TAU)
	for segment in range(ring_count):
		angular.append(phase + TAU * float(segment) / float(ring_count) + _random.randf_range(-.23, .23))
		radii.append(_random.randf_range(.69, 1.23))
		breaks.append(_random.randf_range(-0.12, 0.14))
		crack_bias.append(_random.randf_range(-0.29, 0.20))

	var rows := [
		Vector3(-0.07, 1.00, 0.0), Vector3(0.12, 0.93, 0.008),
		Vector3(0.22, 0.89, 0.06), Vector3(0.35, 0.81, 0.10),
		Vector3(0.44, 0.80, 0.14), Vector3(0.56, 0.76, 0.11),
		Vector3(0.64, 0.72, 0.115), Vector3(0.77, 0.58, 0.17),
		Vector3(0.92, 0.44, 0.24), Vector3(1.01, 0.27, 0.24),
	]
	if profile == 1:
		rows = [
			Vector3(-0.09, 0.99, 0.0), Vector3(0.11, 0.93, 0.023),
			Vector3(0.17, 0.91, 0.066), Vector3(0.31, 0.84, 0.085),
			Vector3(0.45, 0.72, 0.14), Vector3(0.55, 0.64, 0.21),
			Vector3(0.69, 0.61, 0.315), Vector3(0.83, 0.52, 0.29),
			Vector3(0.95, 0.36, 0.26), Vector3(1.01, 0.25, 0.26),
		]
	elif profile == 2:
		rows = [
			Vector3(-0.085, 0.98, 0.0), Vector3(0.10, 1.02, -0.028),
			Vector3(0.24, 0.94, -0.095), Vector3(0.37, 0.85, -0.13),
			Vector3(0.48, 0.73, -0.11), Vector3(0.57, 0.70, -0.060),
			Vector3(0.71, 0.57, -0.01), Vector3(0.80, 0.42, 0.03),
			Vector3(0.91, 0.34, 0.06), Vector3(1.02, 0.15, 0.11),
		]

	var lean := Vector2(_random.randf_range(-0.35, 0.35), _random.randf_range(-0.28, 0.24))
	var slope := Vector2(_random.randf_range(-0.33, 0.31), _random.randf_range(-0.39, 0.36))
	var dirt := _random.randf_range(0.73, 0.99)
	var knots: Array[PackedVector3Array] = []
	for row_id in range(rows.size()):
		var row: Vector3 = rows[row_id]
		var ring := PackedVector3Array()
		for segment in range(ring_count):
			var turn := angular[segment] + sin(row.x * 2.8 + segment) * 0.056
			var crease := crack_bias[segment] * exp(-pow((row.x - .45 - breaks[segment]) * 3.6, 2.0))
			var break_signature := sin(float(row_id) * 2.17 + float(segment) * 4.14 + phase) * 0.057
			var r := radii[segment] * (row.y + crease + break_signature)
			var belt := row.x + breaks[segment] * (0.65 + row.x * 0.54)
			var x := (cos(turn) * r + lean.x * row.x + row.z) * dimensions.x * 0.5
			var z := (sin(turn) * r + lean.y * row.x) * dimensions.z * 0.5
			var y := (belt + x / dimensions.x * slope.x + z / dimensions.z * slope.y) * dimensions.y
			ring.append(Vector3(x, y, z))
		knots.append(_beveled_ring(ring))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sectors := knots[0].size()
	for row in range(knots.size() - 1):
		var altitude := float(row) / float(knots.size() - 1)
		for segment in range(sectors):
			var n := (segment + 1) % sectors
			var lower_a := knots[row][segment]
			var lower_b := knots[row][n]
			var upper_a := knots[row + 1][segment]
			var upper_b := knots[row + 1][n]
			var normal := (upper_a - lower_a).cross(lower_b - lower_a).normalized()
			var smooth_a := _normal_at(knots, row, segment)
			var smooth_b := _normal_at(knots, row, n)
			var smooth_c := _normal_at(knots, row + 1, n)
			var smooth_d := _normal_at(knots, row + 1, segment)
			var color := Color(
				clampf(dirt * (0.58 + 0.35 * altitude) + (0.09 if segment % 2 == 0 else -0.04), 0.0, 1.0),
				0.47 + smoothstep(0.0, 0.44, altitude) * 0.53,
				clampf(0.30 + crack_bias[segment % ring_count] * 0.56, 0.0, 1.0) if art_revision >= 23 else 1.0
			)
			_triangle_smooth(surface, [lower_a, lower_b, upper_b], [smooth_a, smooth_b, smooth_c], normal, color)
			_triangle_smooth(surface, [lower_a, upper_b, upper_a], [smooth_a, smooth_c, smooth_d], normal, color)
	_cap(surface, knots[0], false, Color(0.57, 1, 1))
	_cap(surface, knots[-1], true, Color(0.97, 1, 1))
	return surface.commit()


func _normal_at(knots: Array[PackedVector3Array], row: int, segment: int) -> Vector3:
	var count := knots[row].size()
	var next_ring := knots[mini(row + 1, knots.size() - 1)][segment]
	var last_ring := knots[maxi(row - 1, 0)][segment]
	var next_segment := knots[row][(segment + 1) % count]
	var last_segment := knots[row][(segment + count - 1) % count]
	return (next_ring - last_ring).cross(next_segment - last_segment).normalized()


func _triangle_smooth(surface: SurfaceTool, points: Array, normals: Array, face: Vector3, shade: Color) -> void:
	var smoothness := 0.76 if art_revision >= 23 else 0.48
	for i in range(3):
		surface.set_color(shade)
		surface.set_normal(face.lerp(normals[i], smoothness).normalized())
		surface.add_vertex(points[i])


func _beveled_ring(points: PackedVector3Array) -> PackedVector3Array:
	var surface := PackedVector3Array()
	for i in range(points.size()):
		var previous := points[(i - 1 + points.size()) % points.size()]
		var next := points[(i + 1) % points.size()]
		surface.append(points[i].lerp(previous, 0.16))
		surface.append(points[i].lerp(next, 0.15))
	return surface


func _cap(surface: SurfaceTool, ring: PackedVector3Array, is_top: bool, color: Color) -> void:
	var center := Vector3.ZERO
	for point in ring:
		center += point
	center /= float(ring.size())
	for i in range(ring.size()):
		var j := (i + 1) % ring.size()
		if is_top:
			var toward_sky := (ring[j] - center).cross(ring[i] - center).normalized()
			_triangle(surface, center, ring[i], ring[j], toward_sky, color)
		else:
			_triangle(surface, center, ring[j], ring[i], Vector3.DOWN, color)


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, shade: Color) -> void:
	for point in [a, b, c]:
		surface.set_color(shade)
		surface.set_normal(normal)
		surface.add_vertex(point)


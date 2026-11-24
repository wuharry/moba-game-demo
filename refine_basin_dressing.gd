extends Node3D

var style_round := 5
var salt := RandomNumberGenerator.new()
var steel: Material
var paint: Material
var brass: Material
var oxide: Material
var warning: Material
var gasket: Material
var stone: ShaderMaterial


func _ready() -> void:
	salt.seed = 20261123
	steel = _finish(Color("#414e54"), 0.53, 0.53)
	paint = _finish(Color("#61767a"), 0.66, 0.20)
	brass = _finish(Color("#8d6851"), 0.65, 0.58)
	oxide = _finish(Color("#a2583a"), 0.79, 0.38)
	warning = _finish(Color("#be975d"), 0.87, 0.20)
	gasket = _finish(Color("#292e31"), 0.92, 0.11)
	stone = ShaderMaterial.new()
	stone.shader = preload("res://refine_basin_ground.gdshader")
	stone.set_shader_parameter("paint", preload("res://textures/refinement_ground.png"))
	stone.set_shader_parameter("tint", Color("#c7ccbc"))
	_service_footing()
	_water_edge()
	_pump_annex(Vector3(-4.1, 0.0, -10.5), false)
	_pump_annex(Vector3(8.4, 0.0, 0.4), true)
	_fault_lines()
	if style_round >= 5:
		_set_dressing()
	if style_round >= 6:
		_retaining_intake()
	if style_round >= 8:
		_reed_margins()
	if style_round >= 10:
		if style_round < 23:
			_maintenance_terraces()
		else:
			_winch_annex()
	if style_round >= 12:
		_spillway_gate()
	if style_round >= 15:
		_embankment_growth()
		if style_round < 17:
			_road_repairs()
	if style_round >= 16:
		_service_bay()
	if style_round >= 21:
		_divider_scarp()
		_runoff_station()
	if style_round >= 22:
		_divider_grounding()
	if style_round >= 23:
		_runoff_apron()
	if style_round >= 24:
		_retention_headworks()
	if style_round >= 25:
		_shoulder_drainage()
	if style_round >= 26:
		_bypass_marker()


func _service_footing() -> void:
	for side in [-1.0, 1.0]:
		_block(Vector3(side * 1.57, 0.38, -4.75), Vector3(0.33, 0.25, 1.93), steel, 0.028)
		for z in [-5.56, -4.92, -4.32]:
			_bolt(Vector3(side * 1.58, 0.55, z), 0.037, brass)
		_block(Vector3(side * 1.99, 0.042, -4.15), Vector3(0.19, 0.081, 1.22), steel)
	var conduit := PackedVector3Array([
		Vector3(-1.46, 0.6, -5.30), Vector3(-1.89, 0.57, -5.33), Vector3(-2.25, 0.38, -5.43),
		Vector3(-2.40, 0.29, -5.61), Vector3(-3.20, 0.25, -5.83), Vector3(-4.69, 0.24, -5.83),
	])
	_conduit(conduit, 0.078, oxide)
	for index in range(4):
		var x := -4.47 + index * 0.43
		_block(Vector3(x, 0.08, -5.80), Vector3(0.18, 0.17, 0.32), steel)
		_bolt(Vector3(x, 0.17, -5.65), 0.025, brass)
	var plate := _block(Vector3(0.0, 0.022, -2.93), Vector3(1.82, 0.031, 0.91), steel, 0.027)
	plate.rotation.y = -0.033
	for index in range(7):
		_block(Vector3((index - 3) * 0.23, 0.045, -2.93), Vector3(0.044, 0.010, 0.72), paint)
	for x in [-0.76, 0.76]:
		for z in [-2.60, -3.27]:
			_bolt(Vector3(x, 0.042, z), 0.024, brass)


func _water_edge() -> void:
	_conduit(PackedVector3Array([
		Vector3(-4.80, 0.38, 8.0), Vector3(-4.80, 0.38, 2.8),
		Vector3(-4.77, 0.35, -2.15), Vector3(-4.78, 0.34, -9.75),
	]), 0.065, steel)
	for z in [-9.9, -6.2, -1.55, 2.9, 7.0]:
		_block(Vector3(-4.79, 0.165, z), Vector3(0.33, 0.29, 0.21), paint, 0.025)
		_block(Vector3(-4.75, 0.41, z), Vector3(0.22, 0.23, 0.12), oxide, 0.026)
		for step in range(4):
			var rib := _block(Vector3(-5.21, 0.44, z + (step - 1.5) * 0.16), Vector3(0.42, 0.07, 0.065), steel)
			rib.rotation.y = 0.04
	for z in [-10.1, -2.5, 1.0, 7.65]:
		var strip := _block(Vector3(-4.99, 0.46, z), Vector3(0.18, 0.012, 0.41), warning)
		strip.rotation.y = -0.18


func _pump_annex(origin: Vector3, ruined: bool) -> void:
	var height := 2.05 if ruined else 2.81
	var width := 1.76 if ruined else 1.14
	var footing := _block(origin + Vector3(0, 0.14, 0), Vector3(width + 0.37, 0.29, 1.28), stone, 0.08)
	footing.rotation.y = -0.09 if ruined else 0.02
	_block(origin + Vector3(0.02, height * 0.5, -0.1), Vector3(width, height, 0.73), stone, 0.09)
	_block(origin + Vector3(0, height * 0.56, 0.308), Vector3(width * 0.87, height * 0.87, 0.13), steel, 0.043)
	_block(origin + Vector3(0, height * 0.72, 0.404), Vector3(width * 0.73, 0.40, 0.11), gasket, 0.021)
	for index in range(8):
		_block(origin + Vector3((index - 3.5) * width * 0.087, height * 0.72, 0.48), Vector3(0.052, 0.30, 0.046), paint)
	for dx in [-0.41, 0.41]:
		for dy in [height * 0.19, height * 0.87]:
			var rivet := _bolt(origin + Vector3(dx * width, dy, 0.405), 0.036, brass)
			rivet.rotation.x = PI * 0.5
	for j in range(3):
		var x := width * (0.53 + j * 0.12)
		_conduit(PackedVector3Array([
			origin + Vector3(x, .21, .16), origin + Vector3(x, 0.63 + j * 0.11, 0.20),
			origin + Vector3(x - 0.08, 0.83 + j * 0.11, 0.26),
			origin + Vector3(x - 0.18, 0.95 + j * 0.11, 0.31),
		]), 0.042, oxide)
	if not ruined:
		_conduit(PackedVector3Array([
			origin + Vector3(-0.45, height - 0.04, 0), origin + Vector3(-0.45, height + 0.35, 0),
			origin + Vector3(-0.32, height + 0.58, 0), origin + Vector3(0.07, height + 0.58, 0),
			origin + Vector3(0.23, height + 0.37, 0), origin + Vector3(0.23, height - 0.09, 0),
		]), 0.108, steel)
	else:
		for j in range(3):
			var x := -0.49 + j * 0.32
			_conduit(PackedVector3Array([
				origin + Vector3(x, height - .04, -0.12),
				origin + Vector3(x - 0.08, height + .28 + j * 0.06, -0.14),
				origin + Vector3(x - 0.17, height + .38 + j * 0.05, -0.05),
			]), 0.022, oxide)


func _fault_lines() -> void:
	var cracks := [
		PackedVector2Array([Vector2(2.2, 1.6), Vector2(2.6, 1.89), Vector2(3.0, 1.72), Vector2(3.7, 2.04), Vector2(4.0, 2.37)]),
		PackedVector2Array([Vector2(3.02, 1.72), Vector2(3.23, 1.37), Vector2(3.72, 1.31)]),
		PackedVector2Array([Vector2(-4.2, -0.37), Vector2(-3.6, -0.35), Vector2(-3.19, -0.16), Vector2(-2.93, 0.21)]),
		PackedVector2Array([Vector2(6.2, -5.8), Vector2(6.51, -5.36), Vector2(6.9, -5.48), Vector2(7.30, -5.16)]),
	]
	var geom := SurfaceTool.new()
	geom.begin(Mesh.PRIMITIVE_TRIANGLES)
	for crack in cracks:
		for index in range(crack.size() - 1):
			var a: Vector2 = crack[index]
			var b: Vector2 = crack[index + 1]
			var edge := (b - a).orthogonal().normalized()
			var near := edge * salt.randf_range(0.013, 0.029)
			var far := edge * salt.randf_range(0.002, 0.016)
			for p in [a - near, b - far, a + near, a + near, b - far, b + far]:
				geom.add_vertex(Vector3(p.x, 0.012, p.y))
	geom.generate_normals()
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("#363d3a")
	finish.roughness = .94
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(geom.commit(), finish, Vector3.ZERO)


func _set_dressing() -> void:
	var corners := [Vector3(-4, 0, 5), Vector3(-3.95, 0, -4.85), Vector3(7.6, 0, -4.2),
		Vector3(8.3, 0, 0.05), Vector3(7.42, 0, -10.3), Vector3(-3.9, 0, -10.64)]
	for corner in corners:
		for j in range(5):
			var sx := salt.randf_range(0.12, 0.54)
			var sz := salt.randf_range(0.12, 0.72)
			var sy := salt.randf_range(0.042, 0.21)
			var point: Vector3 = corner + Vector3(salt.randf_range(-0.84, 0.63), sy * 0.43, salt.randf_range(-0.74, 0.9))
			var broken := _block(point, Vector3(sx, sy, sz), stone, minf(0.026, sy * 0.3))
			broken.rotation_degrees = Vector3(salt.randf_range(0, 16), salt.randf_range(-45, 54), salt.randf_range(-15, 19))

	var rail := PackedVector3Array([
		Vector3(3.55, 0.08, -6.12), Vector3(3.10, 0.049, -6.51),
		Vector3(2.07, 0.05, -6.90), Vector3(0.89, 0.049, -7.08),
	])
	_conduit(rail, 0.039, steel)
	for at in [Vector3(7.86, 0.06, -2.55), Vector3(-4.04, 0.025, 5.74)]:
		var flange := _block(at, Vector3(0.86, 0.095, 0.52), oxide, 0.025)
		flange.rotation.y = 0.22
		for z in [-0.12, 0.14]:
			_bolt(at + Vector3(0.31, 0.058, z), 0.048, steel)


func _retaining_intake() -> void:
	var dark_slate := _finish(Color("#37454c"), 0.83, 0.08)
	var stone_gray := _finish(Color("#6f7a76"), 0.79, 0.04)
	var inset := _finish(Color("#272e32"), 0.88, 0.34)
	for side: float in [-1.0, 1.0]:
		var x_base := -5.0 if side < 0 else 4.7
		var z_base := -12.2 if side < 0 else -13.7
		for section in range(4):
			var width := 0.94 + float(section) * 0.20
			var width_offset := float(section) * 1.24
			var x := x_base + side * width_offset
			var height := (0.55 + float(section) * 0.31) * (1.48 if side > 0 else 1.0)
			var piece := _block(Vector3(x, height * 0.5, z_base - float(section) * 0.11), Vector3(width, height, 0.73), stone, 0.09)
			piece.rotation.y += deg_to_rad(salt.randf_range(-5.0, 4.0))
			_block(Vector3(x, 0.11, z_base + 0.22), Vector3(width + 0.05, 0.23, 1.26), dark_slate)
			_block(Vector3(x+0.15, height * 0.74, z_base + 0.37), Vector3(0.13, height * 0.37, 0.08), steel)
			if section > 1:
				_bolt(Vector3(x, height + .05, z_base + .16), 0.071, oxide)

	var at := Vector3(-2.57, 0.0, -13.05)
	_block(at + Vector3(0.0, 0.19, 0), Vector3(2.52, 0.38, 1.22), stone, 0.045)
	_block(at + Vector3(0.0, 1.08, -.25), Vector3(2.32, 1.70, 0.65), stone_gray, 0.15)
	_block(at + Vector3(-0.12, 1.10, 0.138), Vector3(1.48, 1.35, .12), inset, 0.06)
	_block(at + Vector3(-0.12, 1.87, 0.148), Vector3(1.80, 0.14, .28), dark_slate, 0.06)
	for rung in range(7):
		var angled := _block(at + Vector3(-0.72 + float(rung) * 0.20, 1.08, 0.243), Vector3(0.046, 1.10, .074), steel)
		angled.rotation.z = (0.04 if rung % 2 == 0 else -0.038)
	for x in [-1.1, 1.1]:
		_block(at + Vector3(x, 0.80, .21), Vector3(.18, 1.49, .48), stone, .05)
		var detail := _block(at + Vector3(x, 1.59, .30), Vector3(.17, .07, .21), warning)
		detail.rotation.y = -0.13
	_conduit(PackedVector3Array([
		at + Vector3(1.18, .60, .1), at + Vector3(2.30, .55, .0),
		at + Vector3(2.68, .25, .22), at + Vector3(3.52, .13, .89),
	]), .108, oxide)
	_conduit(PackedVector3Array([
		Vector3(6.45, .41, -12.5), Vector3(4.20, .22, -12.18), Vector3(3.15, .12, -12.72),
	]), .126, steel)
	for step in range(6):
		var spall := _block(Vector3(7.4 + salt.randf_range(-.75, 1.4), .07, -11.6 + salt.randf_range(-.5, .74)),
			Vector3(salt.randf_range(.17, .55), salt.randf_range(.095, .17), salt.randf_range(.18, .53)), stone, .035)
		spall.rotation.y += salt.randf_range(-.28, .88)


func _reed_margins() -> void:
	var groups := [
		Vector3(-4.19, 0.0, 6.3), Vector3(-4.1, 0.0, 2.1),
		Vector3(-4.02, 0.0, -7.8), Vector3(-3.93, 0.0, -12.05),
		Vector3(6.98, 0.0, -11.22), Vector3(7.5, 0.0, -2.4),
		Vector3(7.4, 0.0, 2.95), Vector3(8.5, 0.0, 4.72),
	]
	var reed := ShaderMaterial.new()
	reed.shader = preload("res://painted_plants.gdshader")
	reed.set_shader_parameter("plant_atlas", preload("res://textures/painted_plants.png"))
	reed.set_shader_parameter("quadrant", Vector2(0, 1))
	reed.set_shader_parameter("foliage_tint", Color("#a7a995"))
	var fern := reed.duplicate() as ShaderMaterial
	fern.set_shader_parameter("quadrant", Vector2(1, 1))
	fern.set_shader_parameter("foliage_tint", Color("#9bb2a5"))
	for i in groups.size():
		for j in range(4 + i % 2):
			var h := salt.randf_range(.35, .97) * (1.25 if i == 0 or i == 7 else 1.0)
			var at: Vector3 = groups[i] + Vector3(salt.randf_range(-.28, .32), h * .49, salt.randf_range(-.63, .74))
			var leaves := QuadMesh.new()
			leaves.size = Vector2(h * 1.16, h)
			var yaw := salt.randf_range(-0.32, 1.6)
			for angle in [yaw, yaw + 1.19]:
				var card := _mesh(leaves, reed if (i + j) % 3 else fern, at)
				card.rotation.y = angle
				card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _maintenance_terraces() -> void:
	var topstone := _finish(Color("#4f5350") if style_round >= 12 else Color("#737872"), 0.84, 0.05)
	var weathered := _finish(Color("#394746") if style_round >= 12 else Color("#536064"), 0.93, 0.05)
	var slab_base := _finish(Color("#333d3e"), 0.88, 0.09)
	var base := Vector3(7.97, 0, -7.98)
	var courses := [
		[Vector3(0.43, 0.24, 0.58), Vector3(3.74, .52, 3.82)],
		[Vector3(0.82, 0.69, 0.22), Vector3(3.30, .49, 3.16)],
		[Vector3(1.23, 1.15, -.22), Vector3(2.87, .45, 2.79)],
		[Vector3(1.87, 1.75, -.69), Vector3(2.05, .78, 2.44)],
	]
	for j in courses.size():
		var center: Vector3 = courses[j][0]
		var size: Vector3 = courses[j][1]
		var wall := _block(base + center, size, weathered, 0.10)
		wall.rotation.y += -0.10 - float(j) * .036
		var cap := _block(base + center + Vector3(-.10, size.y * .49, .115),
			Vector3(size.x + .26, .136, size.z + .25), topstone, .04)
		cap.rotation.y = wall.rotation.y
		for span in range(3):
			_block(base + center + Vector3((span - 1) * size.x * .25, 0.0, size.z * .485),
				Vector3(.024, size.y * .78, .055), slab_base)

	for i in range(4):
		var x := 7.47 + i * 0.18
		var z := -6.63 + i * 0.13
		var height := 0.14 + float(i) * 0.15
		var step := _block(Vector3(x, height * .5, z), Vector3(0.46, height, .65), weathered, .043)
		step.rotation.y += salt.randf_range(-0.12, 0.19)
		_block(Vector3(x - .06, height + .024, z + .07), Vector3(.39, .055, .58), topstone, .024)

	var inspection := Vector3(7.18, .07, -4.55)
	var recess := _block(inspection, Vector3(1.27, .13, 1.01), slab_base, .027)
	recess.rotation.y += 0.15
	for rib in range(6):
		var iron_bar := _block(inspection + Vector3((rib - 2.5) * .164, .082, .01), Vector3(.038, .037, .70), steel)
		iron_bar.rotation.y = 0.22
	for at in [Vector3(-3.95, .18, 3.95), Vector3(-3.88, .19, 4.89)]:
		var rubble := _block(at, Vector3(.52, .34, .78), topstone, .09)
		rubble.rotation_degrees += Vector3(-8.0, salt.randf_range(-25.0, 17.0), 12.0)

	if style_round >= 12:
		var frame := Vector3(7.75, 1.29, -8.62)
		var cover := _block(frame, Vector3(1.57, 1.01, 0.19), paint, 0.035)
		cover.rotation.y = -0.18
		_block(frame + Vector3(.03, 0, .11), Vector3(1.31, .76, .055), gasket, .029).rotation.y = -0.18
		for i in range(7):
			_block(frame + Vector3(-.49 + float(i) * .161, -.02, .152),
				Vector3(.033, .59, .092), steel, .004).rotation.y = -.18
		for i in range(4):
			var x := 6.95 + float(i) * .35
			var z := -8.46 - float(i) * .08
			_block(Vector3(x, .64 + float(i) * .028, z), Vector3(.047, .52, .043), steel, .006)
		_conduit(PackedVector3Array([
			Vector3(6.95, .91, -8.46), Vector3(7.31, .938, -8.54),
			Vector3(7.65, .966, -8.62), Vector3(8.0, 1.0, -8.70),
		]), .037, oxide)


func _spillway_gate() -> void:
	var center := Vector3(-7.05, 0, -13.65)
	var concrete := _finish(Color("#455352"), 0.91, 0.03)
	var chipped := _finish(Color("#5b6158"), 0.94, 0.04)
	var shaft := _finish(Color("#202e33"), 0.65, 0.39)
	for side: float in [-1.0, 1.0]:
		var x := side * 1.47
		_block(center + Vector3(x, 0.18, 0), Vector3(0.72, 1.28, 1.17), concrete, 0.065)
		_block(center + Vector3(x, .86, -.04), Vector3(.79, .164, 1.14), chipped, 0.031)
		_block(center + Vector3(x, .22, .66), Vector3(.24, .74, .56), steel, .033)
		_conduit(PackedVector3Array([
			center + Vector3(x, .88, .16 * side),
			center + Vector3(x, 1.20, -.28),
			center + Vector3(x - side * .35, 1.48, -.30),
			center + Vector3(x - side * .60, 1.48, -.30),
		]), .057, oxide)
	_block(center + Vector3(0.0, 1.18, -.31), Vector3(2.74, .20, .34), steel, .04)
	_block(center + Vector3(0.0, .95, -.32), Vector3(2.60, .13, .28), shaft, .029)
	_block(center + Vector3(0.0, .47, -.34), Vector3(2.60, .15, .26), steel, .024)
	for index in range(9):
		var x := -.997 + float(index) * .248
		_block(center + Vector3(x, .276, -.28), Vector3(.066, 1.25 - float(index % 3) * .045, .145), steel, .013)
	for local in [Vector3(-1.66, .92, .26), Vector3(1.66, .92, .26)]:
		_bolt(center + local, .071, brass)
	_block(center + Vector3(-.50, 1.43, -.33), Vector3(.57, .36, .31), paint, .057)
	_bolt(center + Vector3(-.51, 1.64, -.31), .088, oxide)


func _embankment_growth() -> void:
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beds := [
		[Vector3(-4.87, 0.01, 6.05), Vector2(.50, 1.38), .76],
		[Vector3(-4.86, 0.00, 3.24), Vector2(.56, .76), .44],
		[Vector3(-4.64, 0.02, -.78), Vector2(.72, .84), .71],
		[Vector3(-4.96, 0.03, -8.64), Vector2(.37, .96), .42],
		[Vector3(2.87, 0.01, 7.48), Vector2(.32, 1.0), .64],
		[Vector3(3.23, 0.01, 3.68), Vector2(.32, .66), .38],
		[Vector3(3.07, 0.00, -.38), Vector2(.27, .58), .54],
		[Vector3(6.90, 0.00, -9.69), Vector2(.85, .39), .65],
		[Vector3(7.70, 0.02, .88), Vector2(.62, .62), .74],
	]
	for bed in beds:
		var location: Vector3 = bed[0]
		var radius: Vector2 = bed[1]
		var mean_height: float = bed[2]
		for blade in range(35):
			var tangent := salt.randf_range(-PI, PI)
			var distance := sqrt(salt.randf())
			var foot := location + Vector3(cos(tangent) * distance * radius.x, 0, sin(tangent) * distance * radius.y)
			var height := mean_height * salt.randf_range(.31, 1.19)
			var wind := Vector3(.16 + salt.randf_range(-.18, .24), 0, salt.randf_range(-.29, .27))
			var side := Vector3(cos(tangent + 1.57), .06, sin(tangent + 1.57)) * salt.randf_range(.010, .044)
			var stroke := _blade_palette(blade, false)
			for segment in range(3):
				var a := float(segment) / 3.0
				var b := float(segment + 1) / 3.0
				var begin := foot + Vector3.UP * height * a + wind * a * a
				var end := foot + Vector3.UP * height * b + wind * b * b
				var foot_w := side * (1.0 - a * .78)
				var tip_w := side * (1.0 - b * .91)
				_reed_quad(geometry, begin - foot_w, end - tip_w, end + tip_w, begin + foot_w,
					stroke.darkened((1.0 - a) * .18))
			if blade % 8 == 0:
				_seed_head(geometry, foot + Vector3.UP * height * .91 + wind * .90, tangent, _blade_palette(blade, true))
	geometry.index()
	geometry.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = style_round >= 17
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = .91
	mat.rim_enabled = true
	mat.rim = .20
	_mesh(geometry.commit(), mat, Vector3.ZERO)


func _blade_palette(index: int, seed_head: bool) -> Color:
	if seed_head:
		return Color("#8f7548").lerp(Color("#bc9b66"), salt.randf())
	if index % 5 == 0:
		return Color("#89815a").lerp(Color("#aa9262"), salt.randf())
	return Color("#405342").lerp(Color("#82875c"), salt.randf())


func _seed_head(geom: SurfaceTool, origin: Vector3, tilt: float, tint: Color) -> void:
	var width := Vector3(cos(tilt), 0, sin(tilt)) * .034
	for i in range(3):
		var center := origin + Vector3(i * .009, i * .047, 0)
		_reed_quad(geom, center - width * .6 - Vector3.UP * .028, center - width * .78 + Vector3.UP * .014,
			center + Vector3.UP * .046, center + width * .83)


func _reed_quad(geom: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint := Color("#ac9562")) -> void:
	for vertex in [a, b, c, a, c, d]:
		geom.set_color(tint)
		geom.add_vertex(vertex)


func _road_repairs() -> void:
	var repair := _finish(Color("#636a64"), .91, .02)
	var join := _finish(Color("#45504c"), .97, .01)
	var locations := [
		[Vector2(-2.73, 3.24), Vector2(1.38, 1.21), .47],
		[Vector2(-2.60, 6.47), Vector2(.96, 1.27), .13],
		[Vector2(2.63, 5.51), Vector2(.73, 1.51), -.36],
		[Vector2(4.68, -.23), Vector2(.95, 1.61), .10],
		[Vector2(-1.53, -7.14), Vector2(.87, .95), .45],
	]
	for location in locations:
		var center: Vector2 = location[0]
		var size: Vector2 = location[1]
		var yaw: float = location[2]
		var outline := [
			Vector2(-.54, -.45), Vector2(-.38, .47), Vector2(.30, .52),
			Vector2(.51, .18), Vector2(.44, -.39), Vector2(.11, -.54),
		]
		_paving_patch(center, size * 1.056, yaw, outline, join, .009)
		_paving_patch(center, size, yaw, outline, repair, .014)


func _paving_patch(center: Vector2, size: Vector2, yaw: float, outline: Array, finish: Material, elev: float) -> void:
	var geom := SurfaceTool.new()
	geom.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector2Array()
	for edge: Vector2 in outline:
		points.append(center + (edge * size).rotated(yaw))
	for i in range(1, points.size() - 1):
		for v in [points[0], points[i + 1], points[i]]:
			geom.set_normal(Vector3.UP)
			geom.add_vertex(Vector3(v.x, elev, v.y))
	_mesh(geom.commit(), finish, Vector3.ZERO)


func _service_bay() -> void:
	var foundation := _finish(Color("#4e5756"), .89, .04)
	var deck := _finish(Color("#616a62"), .91, .03)
	var gutter := _finish(Color("#354346"), .88, .12)
	var origin := Vector3(.35, 0.0, -13.65)
	_block(origin + Vector3(.22, .22, -.22), Vector3(6.76, .44, 2.57), foundation, .11)
	_block(origin + Vector3(.13, .49, -.25), Vector3(6.48, .17, 2.33), deck, .062)
	_block(origin + Vector3(-.38, .075, 1.24), Vector3(4.52, .17, .55), deck, .04)
	_block(origin + Vector3(.18, .21, 1.03), Vector3(4.66, .15, .56), foundation, .055)
	_block(origin + Vector3(.39, .367, .78), Vector3(4.75, .15, .47), deck, .039)
	for i in range(7):
		var x := -2.55 + float(i) * .77
		var pillar := _block(origin + Vector3(x, .29, -1.23), Vector3(.25, .59, .21), foundation, .035)
		pillar.rotation.y = salt.randf_range(-.058, .058)
	var bay := origin + Vector3(1.32, 0, -.16)
	_block(bay + Vector3(0, .73, .04), Vector3(1.98, .43, 1.37), gutter, .065)
	_block(bay + Vector3(.06, 1.12, -.03), Vector3(1.70, .43, 1.09), paint, .075)
	_block(bay + Vector3(.15, 1.17, .57), Vector3(1.21, .34, .14), gasket, .041)
	for rib in range(9):
		_block(bay + Vector3(-.31 + rib * .115, 1.17, .66), Vector3(.031, .25, .068), steel, .008)
	var cover := _finish(Color("#4e5a57"), .85, .21)
	_block(bay + Vector3(0, 1.40, -.06), Vector3(1.86, .126, 1.17), cover, .036)
	for offset in [-.53, .55]:
		_bolt(bay + Vector3(offset, 1.49, -.38), .068, oxide)
	_conduit(PackedVector3Array([
		Vector3(3.51, .21, -12.50), Vector3(2.83, .32, -12.57),
		Vector3(2.54, .73, -12.74), Vector3(2.53, .89, -13.01), Vector3(2.23, .92, -13.46),
	]), .098, oxide)
	var tower := Vector3(-1.55, .54, -14.13)
	_block(tower + Vector3(0, .76, 0), Vector3(.88, 1.50, .61), foundation, .071)
	_block(tower + Vector3(0, .94, .32), Vector3(.63, .74, .12), paint, .037)
	_block(tower + Vector3(0, .97, .387), Vector3(.48, .49, .065), gasket, .038)
	for line in range(3):
		_block(tower + Vector3(-.065, .864 + .104 * line, .435), Vector3(.30, .028, .015), warning)
	for x in [-1.35, -.58]:
		var railing := origin + Vector3(x, .66, .66)
		_block(railing, Vector3(.056, .42, .053), steel, .012)
	_conduit(PackedVector3Array([
		origin + Vector3(-1.52, .85, .66), origin + Vector3(-1.35, .87, .66), origin + Vector3(-.56, .87, .66)
	]), .036, steel)


func _divider_scarp() -> void:
	var slab := ShaderMaterial.new()
	slab.shader = preload("res://station_geology_basalt.gdshader")
	slab.set_shader_parameter("painted_atlas", preload("res://textures/painted_stone.png"))
	slab.set_shader_parameter("shadow_stone", Color("#374141"))
	slab.set_shader_parameter("exposed_stone", Color("#84857b"))
	slab.set_shader_parameter("oxidized_stone", Color("#686250"))
	slab.set_shader_parameter("lichen_stone", Color("#61735d"))
	slab.set_shader_parameter("detail_amount", .93)
	slab.set_shader_parameter("pattern_scale", 2.8)
	slab.set_shader_parameter("belt_size", .34)
	var points := PackedVector3Array([
		Vector3(3.15, .02, 8.34), Vector3(3.28, .12, 7.65), Vector3(3.29, .24, 7.08),
		Vector3(3.14, .17, 6.50), Vector3(2.95, .06, 5.95),
		Vector3(2.95, .14, 5.04), Vector3(3.07, .31, 4.37),
		Vector3(3.21, .28, 3.71), Vector3(3.35, .15, 2.94), Vector3(3.32, .03, 2.37),
	])
	var widths := [.24, .76, .91, .76, .57, .61, .99, .86, .55, .20]
	var forms := SurfaceTool.new()
	forms.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spans: Array[PackedVector3Array] = []
	for i in points.size():
		var center := points[i]
		var span := float(widths[i])
		var palette := [Vector3(-.54, -.004, .07), Vector3(-.33, center.y * .55, -.079),
			Vector3(-.14, center.y * .97, .04), Vector3(.17, center.y, -.075),
			Vector3(.36, center.y * .61, .05), Vector3(.54, -.005, -.04)]
		var section := PackedVector3Array()
		for point: Vector3 in palette:
			section.append(Vector3(center.x + point.x * span, point.y, center.z + point.z))
		spans.append(section)
	for i in range(spans.size() - 1):
		if style_round >= 22 and (i < 1 or i == 4 or i == 5 or i > 7):
			continue
		for edge in range(5):
			var a := spans[i][edge]
			var b := spans[i][edge + 1]
			var c := spans[i + 1][edge + 1]
			var d := spans[i + 1][edge]
			for vertex in [a, c, b, a, d, c]:
				forms.set_color(Color(.7, clampf(vertex.y * 1.7 + .42, .0, 1.0), .58))
				forms.add_vertex(vertex)
	forms.generate_normals()
	if style_round >= 22:
		slab.set_shader_parameter("exposed_stone", Color("#5e6b5c"))
		slab.set_shader_parameter("lichen_stone", Color("#647053"))
		slab.set_shader_parameter("shadow_stone", Color("#374648"))
	_mesh(forms.commit(), slab, Vector3.ZERO)
	for point: Vector3 in [Vector3(3.21, .19, 7.31), Vector3(2.97, .09, 5.38), Vector3(3.05, .22, 4.07)]:
		for shard in range(3):
			var footprint := Vector3(.19 + shard * .056, .06 + shard * .025, .35 + shard * .05)
			var chip := _block(point + Vector3(shard * .11 - .10, -.032 * shard, .13 * shard), footprint, slab, .046)
			chip.rotation_degrees = Vector3(-5.0 - shard * 5.0, 28.0 + 17.0 * shard, 8.0 + 5.4 * shard)


func _divider_grounding() -> void:
	var foliage := ShaderMaterial.new()
	foliage.shader = preload("res://painted_plants.gdshader")
	foliage.set_shader_parameter("plant_atlas", preload("res://textures/painted_plants.png"))
	foliage.set_shader_parameter("quadrant", Vector2(1, 1))
	foliage.set_shader_parameter("foliage_tint", Color("#b0aba0"))
	var stones := _finish(Color("#586559"), .92, .08)
	for site in [
		[Vector3(3.14, 0, 7.53), .74, .45],
		[Vector3(3.32, 0, 6.61), .41, -.71],
		[Vector3(3.17, 0, 4.19), .57, 1.46],
		[Vector3(3.47, 0, 3.54), .32, -.31],
		[Vector3(-4.59, 0, 4.62), .53, .74],
	]:
		var at: Vector3 = site[0]
		var size: float = site[1]
		var yaw: float = site[2]
		for j in range(3):
			var base := at + Vector3((j - 1) * .107, 0, j * .20 - .17)
			var plant := QuadMesh.new()
			var height := size * (.61 + .18 * j)
			plant.size = Vector2(height * 1.14, height)
			for turn in [0.0, 1.21]:
				var leaves := _mesh(plant, foliage, base + Vector3(0, .44 * height + .05, 0))
				leaves.rotation.y = yaw + turn + float(j) * .12
				leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var stone := _block(base + Vector3(.08, .033, -.071), Vector3(.28, .11, .33) * (.68 + j * .17), stones, .033)
			stone.rotation_degrees = Vector3(6.0 - 14.0 * j, 17.0 + j * 21.0, 5.0)


func _runoff_station() -> void:
	var base := _finish(Color("#544f42"), .82, .18)
	var station := Vector3(-4.31, .0, 3.88)
	_block(station + Vector3(0, .08, .03), Vector3(1.24, .19, 1.08), stone, .083).rotation.y = -.065
	_block(station + Vector3(-.06, .21, -.094), Vector3(.96, .29, .82), steel, .066)
	_block(station + Vector3(.051, .333, .026), Vector3(.72, .07, .57), gasket, .043)
	for rid in range(6):
		_block(station + Vector3(-.241 + rid * .113, .381, .025), Vector3(.045, .038, .52), base, .01)
	var riser := station + Vector3(-.34, 0, -.41)
	_conduit(PackedVector3Array([
		riser + Vector3(-.86, .26, -.10), riser + Vector3(-.29, .25, -.10), riser + Vector3(-.045, .37, -.087),
		riser + Vector3(.025, .72, -.061), riser + Vector3(.16, .81, -.04),
		riser + Vector3(.40, .79, -.02), riser + Vector3(.58, .68, .012),
	]), .070, oxide)
	for z in [-.28, .32]:
		_bolt(station + Vector3(.47, .198, z), .047, brass)
		_bolt(station + Vector3(-.47, .198, z), .047, brass)


func _winch_annex() -> void:
	var origin := Vector3(9.75, 0, -7.45)
	var footing := _finish(Color("#616560"), .92, .02)
	var frame := _finish(Color("#363f43"), .74, .42)
	var standing_seam := _finish(Color("#6a726c"), .81, .22)
	var copper := _finish(Color("#89543a"), .72, .50)
	# A rock-side diaphragm takes the weight. The open face exposes the
	# drum to the service approach and the cable leads towards the relay.
	_block(origin + Vector3(-.15, .08, .08), Vector3(4.12, .16, 3.63), footing, .076)
	_block(origin + Vector3(1.47, 1.29, -.13), Vector3(.73, 2.59, 3.27), stone, .095)
	for z in [-1.32, 1.32]:
		_block(origin + Vector3(-1.47, .22, z), Vector3(.64, .46, .65), footing, .065)
		_block(origin + Vector3(-1.47, 1.28, z), Vector3(.27, 2.4, .29), frame, .034)
		_block(origin + Vector3(.0, 2.47, z), Vector3(3.45, .25, .18), frame, .034)
		var brace := _block(origin + Vector3(-1.14, 2.10, z), Vector3(.21, .86, .18), steel, .021)
		brace.rotation.z = -.76
	var awning := _block(origin + Vector3(-.11, 2.79, -.19), Vector3(4.06, .19, 3.09), standing_seam, .064)
	awning.rotation.z = .16
	awning.rotation.x = -.06
	var shallow_roof := _block(origin + Vector3(-1.22, 2.53, 1.43), Vector3(2.34, .125, .96), frame, .045)
	shallow_roof.rotation.x = .21
	var fascia := _block(origin + Vector3(-.10, 2.74, 1.32), Vector3(4.16, .21, .11), steel, .03)
	fascia.rotation.z = .16
	for x in [-1.77, -1.13, -.46, .24, .91, 1.56]:
		var rib := _block(origin + Vector3(x, 2.89 + x * .16, -.19), Vector3(.047, .045, 3.11), frame, .016)
		rib.rotation.x = -.06
	var rotor := origin + Vector3(-.45, .87, .43)
	_block(rotor + Vector3(0, -.49, 0), Vector3(1.93, .45, 1.22), frame, .063)
	_conduit(PackedVector3Array([rotor + Vector3(-.89, 0, 0), rotor + Vector3(.89, 0, 0)]), .37, steel)
	for x in [-.67, .67]:
		_conduit(PackedVector3Array([rotor + Vector3(x - .065, 0, 0), rotor + Vector3(x + .065, 0, 0)]), .55, paint)
	for ring in range(13):
		var x := -.57 + float(ring) * .095
		_conduit(PackedVector3Array([rotor + Vector3(x, 0, 0), rotor + Vector3(x + .045, 0, 0)]), .398, copper)
	var cable_exit := rotor + Vector3(-.26, .37, .08)
	for offset in [0.0, .09]:
		_conduit(PackedVector3Array([
			cable_exit + Vector3(offset, 0, 0),
			origin + Vector3(-1.03 + offset, .54, .93),
			origin + Vector3(-1.87 + offset, .18, 1.83),
			origin + Vector3(-2.54 + offset, .11, 2.33),
		]), .038, copper)
	var task_light := OmniLight3D.new()
	task_light.position = origin + Vector3(-.44, 2.07, 1.11)
	task_light.light_color = Color("#ffba86")
	task_light.light_energy = .91
	task_light.omni_range = 3.3
	task_light.omni_attenuation = 1.7
	add_child(task_light)
	var work_lamp := StandardMaterial3D.new()
	work_lamp.albedo_color = Color("#cfb482")
	work_lamp.emission_enabled = true
	work_lamp.emission = Color("#efad69")
	work_lamp.emission_energy_multiplier = 1.1
	_block(task_light.position + Vector3(0, .21, .05), Vector3(.41, .07, .16), work_lamp, .021)
	var trim := _block(origin + Vector3(.46, .84, 1.03), Vector3(.67, .60, .17), frame, .06)
	trim.rotation.y = .07
	for x in [.27, .48, .68]:
		_block(origin + Vector3(x, .926, 1.129), Vector3(.09, .13, .027), warning, .018)
	# Small foundation contacts follow the same outline as the visible
	# bearings and remain away from the x = 5.1 m bypass.
	var support := StaticBody3D.new()
	add_child(support)
	support.position = origin
	for support_position: Vector3 in [Vector3(-1.47, 1.28, -1.32), Vector3(-1.47, 1.28, 1.32), Vector3(1.47, 1.29, -.13)]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(.53, 2.59, 3.27 if support_position.x > 0 else .56)
		var contact := CollisionShape3D.new()
		contact.position = support_position
		contact.shape = shape
		support.add_child(contact)


func _runoff_apron() -> void:
	var seam := _finish(Color("#454e48"), .96, .06)
	var curb := _finish(Color("#72766a"), .91, .03)
	var at := Vector3(-3.57, 0, 4.40)
	for i in range(3):
		var z := float(i) * .86 + .48
		var panel := _block(at + Vector3(-.16 + .069 * i, .017, z), Vector3(.71, .045, .79), seam, .021)
		panel.rotation.y = -.12
		for bar in range(5):
			var grate := _block(at + Vector3(-.38 + .068 * i + float(bar) * .108, .048, z), Vector3(.045, .02, .66), steel, .012)
			grate.rotation.y = -.12
		var left_lip := _block(at + Vector3(-.56 + .069 * i, .042, z), Vector3(.15, .11, .83), curb, .032)
		left_lip.rotation.y = -.12
		var right_lip := _block(at + Vector3(.25 + .069 * i, .021, z), Vector3(.16, .065, .83), curb, .023)
		right_lip.rotation.y = -.12
	_conduit(PackedVector3Array([
		at + Vector3(-.24, .02, .1), at + Vector3(-.52, .08, -.10),
		at + Vector3(-.83, .16, -.22), at + Vector3(-1.0, .18, -.26),
	]), .066, oxide)


func _retention_headworks() -> void:
	var caisson := _finish(Color("#505e5e"), .93, .03)
	var wall_top := _finish(Color("#7a8072"), .91, .07)
	var cast_iron := _finish(Color("#283638"), .74, .35)
	var wet_footing := _finish(Color("#3a4848"), .79, .12)
	var channel := ShaderMaterial.new()
	channel.shader = preload("res://refine_basin_water.gdshader")
	channel.set_shader_parameter("channel_mid", -5.27)
	channel.set_shader_parameter("channel_width", 16.0)
	channel.set_shader_parameter("retention_pool", true)
	var shoreline := PackedVector2Array([
		Vector2(-8.82, -15.10), Vector2(-10.15, -17.48), Vector2(-12.62, -19.15), Vector2(-13.54, -23.40),
		Vector2(-12.79, -27.62), Vector2(-9.49, -32.39), Vector2(-6.75, -33.16), Vector2(-4.05, -37.11),
		Vector2(1.8, -39.3), Vector2(7.55, -36.12), Vector2(10.22, -32.8), Vector2(10.63, -26.27),
		Vector2(8.29, -24.40), Vector2(8.87, -21.12), Vector2(10.76, -18.60), Vector2(7.65, -17.87),
		Vector2(4.09, -17.48), Vector2(1.39, -17.30), Vector2(-1.79, -16.53), Vector2(-4.16, -15.30),
	])
	var basin := SurfaceTool.new()
	basin.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index in Geometry2D.triangulate_polygon(shoreline):
		var location := shoreline[point_index]
		basin.set_normal(Vector3.UP)
		basin.add_vertex(Vector3(location.x, -.66, location.y))
	_mesh(basin.commit(), channel, Vector3.ZERO)
	# Tailrace walls make a stepped Y in plan, opening toward the
	# submerged intake above the existing narrow service canal.
	var throat := [
		[Vector3(-8.64, -.22, -15.07), Vector3(-8.98, -.02, -18.15)],
		[Vector3(-8.98, -.02, -18.15), Vector3(-10.2, .09, -21.47)],
		[Vector3(-5.42, -.18, -15.14), Vector3(-4.68, -.02, -17.45)],
		[Vector3(-4.68, -.02, -17.45), Vector3(-1.94, .15, -18.65)],
		[Vector3(-1.94, .15, -18.65), Vector3(4.12, .49, -18.10)],
		[Vector3(4.12, .49, -18.10), Vector3(10.59, .96, -19.16)],
	]
	for section in throat:
		var first: Vector3 = section[0]
		var last: Vector3 = section[1]
		var bearing := last - first
		var tier := (first + last) * .5
		var length := Vector2(bearing.x, bearing.z).length() + .16
		var yaw := atan2(bearing.x, bearing.z)
		_block(tier + Vector3(0, -.29, 0), Vector3(1.08, .87, length), wet_footing, .077).rotation.y = yaw
		_block(tier + Vector3(0, .26, 0), Vector3(.64, .72, length), caisson, .065).rotation.y = yaw
		_block(tier + Vector3(0, .66, 0), Vector3(.83, .12, length - .07), wall_top, .04).rotation.y = yaw
	var gate := Vector3(-5.10, -.48, -21.56)
	_block(gate + Vector3(-.02, .075, -.18), Vector3(9.12, .51, 1.35), wet_footing, .084)
	for lane in [-1.0, 1.0]:
		var opening := gate + Vector3(lane * 2.04, 1.03, .0)
		_block(opening + Vector3(0, -.12, -.12), Vector3(3.34, 1.66, .19), cast_iron, .06)
		for rib in range(7):
			var x := (float(rib) - 3.0) * .45
			_block(opening + Vector3(x, -.14, .045), Vector3(.069, 1.43, .115), steel, .012)
		_block(opening + Vector3(0, .64, .20), Vector3(3.57, .30, .36), caisson, .05)
		_block(opening + Vector3(0, .81, .13), Vector3(3.72, .11, .59), wall_top, .036)
	for unit in [-1, 0, 1]:
		var at := gate + Vector3(float(unit) * 4.02, 0, .31)
		var height := 3.01 if unit < 0 else 2.37
		_block(at + Vector3(0, height * .48, 0), Vector3(.92, height, 1.36), caisson, .16)
		var strut := _block(at + Vector3(0, .61, .83), Vector3(.66, 1.78, .60), caisson, .10)
		strut.rotation.x = .39
		_block(at + Vector3(0, height * .96 + .045, 0), Vector3(1.12, .17, 1.55), wall_top, .056)
	var sluice_house := gate + Vector3(-3.62, 2.91, -.08)
	_block(sluice_house + Vector3(0, .35, 0), Vector3(1.71, .75, 1.32), paint, .105)
	_block(sluice_house + Vector3(0, .74, .02), Vector3(1.89, .16, 1.44), steel, .045).rotation.z = .075
	_block(sluice_house + Vector3(.17, .36, .683), Vector3(.95, .31, .06), gasket, .032)
	_conduit(PackedVector3Array([
		sluice_house + Vector3(-.66, .28, .56), sluice_house + Vector3(-.91, .04, .68),
		sluice_house + Vector3(-.96, -.37, .85), sluice_house + Vector3(-.93, -1.09, .88),
	]), .079, oxide)


func _shoulder_drainage() -> void:
	var deposit := ShaderMaterial.new()
	deposit.shader = preload("res://station_geology_basalt.gdshader")
	deposit.set_shader_parameter("painted_atlas", preload("res://textures/painted_stone.png"))
	deposit.set_shader_parameter("shadow_stone", Color("#293b3c"))
	deposit.set_shader_parameter("exposed_stone", Color("#52695d"))
	deposit.set_shader_parameter("oxidized_stone", Color("#625847"))
	deposit.set_shader_parameter("lichen_stone", Color("#697957"))
	deposit.set_shader_parameter("detail_amount", .69)
	deposit.set_shader_parameter("pattern_scale", 3.42)
	deposit.set_shader_parameter("belt_size", .40)
	# Lower debris from the cliff piles against the available bank on
	# one side. The bench is sliced back where the drain meets the yard.
	var berm := SurfaceTool.new()
	berm.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crest := [
		Vector3(7.32, .08, -.72), Vector3(7.43, .49, .21), Vector3(7.77, .71, 1.16),
		Vector3(7.96, .81, 2.21), Vector3(8.58, .44, 3.29), Vector3(8.61, .19, 4.37),
		Vector3(7.91, .54, 5.70), Vector3(7.68, .68, 6.54), Vector3(7.39, .39, 7.48),
		Vector3(7.14, .19, 8.34), Vector3(7.39, .03, 9.25),
	]
	var sections: Array[PackedVector3Array] = []
	for section: Vector3 in crest:
		sections.append(PackedVector3Array([
			section + Vector3(-.78, -section.y - .012, .12),
			section + Vector3(-.47, -section.y * .65, .05),
			section + Vector3(-.21, -.14 * section.y, -.14),
			section,
			section + Vector3(1.12, .23, .19),
			section + Vector3(1.74, -section.y + .08, .25),
		]))
	for row in range(sections.size() - 1):
		for slot in range(sections[row].size() - 1):
			var a := sections[row][slot]
			var b := sections[row][slot + 1]
			var c := sections[row + 1][slot + 1]
			var d := sections[row + 1][slot]
			for vertex in [a, b, c, a, c, d]:
				berm.set_color(Color(.52, .54 + clampf(vertex.y, 0, .84) * .35, .42))
				berm.add_vertex(vertex)
	berm.generate_normals()
	var deposit_model := _mesh(berm.commit(), deposit, Vector3.ZERO)
	deposit_model.create_trimesh_collision()
	var conduit_mouth := Vector3(7.30, .0, 4.56)
	var cast := _finish(Color("#575e51"), .83, .08)
	var pit := _finish(Color("#283433"), .82, .15)
	_block(conduit_mouth + Vector3(1.04, .05, -.12), Vector3(2.67, .14, 1.13), pit, .065).rotation.y = .16
	_block(conduit_mouth + Vector3(1.63, .33, -.25), Vector3(1.69, .66, 1.11), cast, .085).rotation.y = .16
	_block(conduit_mouth + Vector3(.77, .29, -.017), Vector3(.15, .45, .65), pit, .044)
	for i in range(4):
		_block(conduit_mouth + Vector3(.685, .12 + float(i) * .106, -.018), Vector3(.055, .036, .55), steel, .014)
	for i in range(3):
		_block(conduit_mouth + Vector3(-.10 + .23 * float(i), .08, .529 - .04 * float(i)),
			Vector3(.23, .18 - .03 * float(i), .17), cast, .037)
	_block(conduit_mouth + Vector3(.64, .25, -.54), Vector3(1.12, .50, .17), cast, .066).rotation.y = .12
	for seam in [
		[Vector3(6.76, .13, 7.57), Vector3(.56, .27, 1.67), -.31],
		[Vector3(7.22, .19, 8.14), Vector3(.72, .34, 1.17), -.19],
		[Vector3(7.24, .20, .83), Vector3(.94, .35, 1.41), .41],
		[Vector3(7.28, .14, 1.89), Vector3(.52, .18, 1.12), -.15],
	]:
		var chip := _block(seam[0], seam[1], deposit, .11)
		chip.rotation.y = seam[2]
		chip.rotation.z = .18


func _bypass_marker() -> void:
	var at := Vector3(3.22, 0, 1.62)
	var oxidized := _finish(Color("#56594c"), .86, .14)
	var enamel := _finish(Color("#ad834a"), .77, .14)
	_block(at + Vector3(0, .088, 0), Vector3(.68, .19, .63), stone, .068)
	_block(at + Vector3(-.073, .46, -.057), Vector3(.16, .88, .15), oxidized, .028)
	_block(at + Vector3(0, .75, .026), Vector3(.61, .23, .10), gasket, .032)
	_block(at + Vector3(.184, .751, .089), Vector3(.094, .147, .035), enamel, .015).rotation.z = -.61
	_block(at + Vector3(.184, .693, .089), Vector3(.094, .147, .035), enamel, .015).rotation.z = .61
	_block(at + Vector3(-.066, .726, .09), Vector3(.36, .032, .031), enamel, .011)
	for x in [-.22, .22]:
		_bolt(at + Vector3(x, .185, .19), .035, oxidized)
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = Vector3(.61, .76, .55)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = .38
	body.add_child(collision)


func _cut_box(size: Vector3, bevel: float) -> ArrayMesh:
	var cut := minf(bevel, minf(size.x, size.z) * .22)
	var band := minf(cut, size.y * .31)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var loops: Array[PackedVector3Array] = []
	for shape in [
		Vector3(size.x - band, -size.y * .5, size.z - band),
		Vector3(size.x, -size.y * .5 + band, size.z),
		Vector3(size.x, size.y * .5 - band, size.z),
		Vector3(size.x - band, size.y * .5, size.z - band),
	]:
		var x: float = shape.x * .5
		var y: float = shape.y
		var z: float = shape.z * .5
		loops.append(PackedVector3Array([
			Vector3(-x + cut, y, -z), Vector3(x - cut, y, -z), Vector3(x, y, -z + cut),
			Vector3(x, y, z - cut), Vector3(x - cut, y, z), Vector3(-x + cut, y, z),
			Vector3(-x, y, z - cut), Vector3(-x, y, -z + cut),
		]))
	tool.set_smooth_group(-1)
	for height in range(3):
		for side in range(8):
			var next := (side + 1) % 8
			for point in [loops[height][side], loops[height + 1][next], loops[height + 1][side],
					loops[height][side], loops[height][next], loops[height + 1][next]]:
				tool.add_vertex(point)
	for side in range(1, 7):
		for point in [loops[0][0], loops[0][side + 1], loops[0][side],
				loops[3][0], loops[3][side], loops[3][side + 1]]:
			tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit()


func _conduit(points: PackedVector3Array, radius: float, finish: Material) -> void:
	for index in range(points.size() - 1):
		var movement := points[index + 1] - points[index]
		var pipe := CylinderMesh.new()
		pipe.top_radius = radius
		pipe.bottom_radius = radius
		pipe.height = movement.length() * 1.065
		pipe.radial_segments = 12
		var at := _mesh(pipe, finish, (points[index] + points[index + 1]) * 0.5)
		at.quaternion = Quaternion(Vector3.UP, movement.normalized())
		if index > 0:
			var joint := SphereMesh.new()
			joint.radius = radius
			joint.height = radius * 2.0
			joint.radial_segments = 12
			joint.rings = 5
			_mesh(joint, finish, points[index])


func _bolt(point: Vector3, radius: float, finish: Material) -> MeshInstance3D:
	var head := CylinderMesh.new()
	head.top_radius = radius * 0.87
	head.bottom_radius = radius
	head.height = radius * 0.66
	head.radial_segments = 6
	return _mesh(head, finish, point)


func _block(point: Vector3, size: Vector3, finish: Material, bevel := 0.0) -> MeshInstance3D:
	if style_round >= 12 and bevel > 0.0:
		return _mesh(_cut_box(size, bevel), finish, point)
	var shape: Mesh
	if bevel <= 0.0:
		var flat := BoxMesh.new()
		flat.size = size
		shape = flat
	else:
		var feet := CylinderMesh.new()
		feet.radial_segments = 8
		feet.top_radius = 1.0
		feet.bottom_radius = 1.0
		feet.height = 1.0
		shape = feet
	var part := _mesh(shape, finish, point)
	if bevel > 0.0:
		part.rotation.y = PI * 0.125
		part.scale = Vector3(size.x / 1.848, size.y, size.z / 1.848)
	return part


func _mesh(geometry: Mesh, finish: Material, point: Vector3) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = geometry
	result.material_override = finish
	result.position = point
	add_child(result)
	return result


func _finish(albedo: Color, roughness: float, metal: float) -> Material:
	if style_round >= 13:
		var painted := ShaderMaterial.new()
		painted.shader = preload("res://refine_basin_weather.gdshader")
		painted.set_shader_parameter("coating", albedo)
		painted.set_shader_parameter("dry_roughness", roughness)
		painted.set_shader_parameter("nominal_metal", metal)
		return painted
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metal
	return material

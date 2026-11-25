extends Node3D

const LAND := preload("res://refine_sunvine_ground.gdshader")
const WATER := preload("res://refine_sunvine_water.gdshader")
const SKY_PAINT := preload("res://refine_sunvine_sky.gdshader")
const CANOPY := preload("res://refine_sunvine_canopy.gdshader")
const MEADOW_GRASS := preload("res://refine_sunvine_meadow.gdshader")
const RIDGE := preload("res://refine_sunvine_ridge.gdshader")
const STRATA := preload("res://refine_sunvine_strata.gdshader")
const SUN_STONE := preload("res://refine_sunvine_stone.gdshader")
const SUN_BARK := preload("res://refine_sunvine_bark.gdshader")
const SUN_FLORA := preload("res://refine_sunvine_flora.gdshader")

const STONE_ATLAS := preload("res://textures/painted_stone.png")
const GROUND_ATLAS := preload("res://textures/refinement_ground.png")
const STONE_NH := preload("res://textures/sunvine_stone_nh.png")
const CLOUD_TEX := preload("res://textures/sunvine_clouds.png")
const FOLIAGE_CARDS := preload("res://textures/genshin_foliage_cards.png")
const LUT_SHEET := preload("res://textures/genshin_daylight_lut.png")

const ORRERY := preload("res://models/garden_hero.glb")
const BOULDER_PACK := preload("res://models/sunvine_boulders.glb")

const POND := Vector2(8.7, -1.0)
const POND_RADIUS := Vector2(6.0, 8.5)
const ORRERY_POSITION := Vector3(-7.85, 0.12, -11.4)

const RIDGE_LANDMARKS := [
	[[-52., -42., 34., 13., 11.4, .31], [-27., -39., 17., 13., 14.0, -.38], [-5., -46., 26., 11., 8.4, -.38],
		[17., -41., 35., 17., 11.6, .15], [33., -42., 23., 15., 16.2, -.50], [58., -46., 29., 10., 10.8, .48]],
	[[-81., -68., 38., 18., 23.5, -.36], [-47., -66., 42., 16., 27.0, .51], [-24., -67., 14., 13., 18.2, -.48],
		[-7., -71., 36., 15., 14.2, .19], [24., -67., 26., 15., 16.8, -.25],
		[48., -63., 38., 16., 28.0, -.46], [82., -67., 33., 15., 19.0, .36]],
	[[-103., -101., 40., 17., 29.0, .24], [-71., -103., 42., 22., 38.5, .70], [-35., -99., 34., 19., 25.0, -.64],
		[-9., -101., 42., 19., 21.8, -.30], [31., -105., 36., 19., 26.8, .51],
		[62., -108., 35., 16., 35.2, -.51], [98., -102., 42., 21., 30.5, .45]],
]

const MAIN := [
	Vector2(-0.4, 13.2), Vector2(.4, 7), Vector2(-1.15, 2.0),
	Vector2(-2.5, -3.7), Vector2(-1.25, -9.1), Vector2(.30, -13.25),
	Vector2(5.10, -13.55),
]
const GARDEN_BRANCH := [Vector2(-1.0, 3), Vector2(-4.6, 0.8), Vector2(-6.9, -2.0), Vector2(-7.35, -7.9)]
const POND_BRANCH := [
	Vector2(5.1, -13.55), Vector2(10.4, -12.3), Vector2(14.5, -9.5),
	Vector2(16.5, -4.5), Vector2(16.4, 4), Vector2(14.8, 7.5),
	Vector2(9.5, 8.9), Vector2(4.8, 7.6), Vector2(.4, 7),
]
const ORCHARD_BRANCH := [
	Vector2(.27, 8.73), Vector2(-3.52, 9.94), Vector2(-7.21, 11.0),
	Vector2(-10.25, 11.6), Vector2(-13.22, 11.10), Vector2(-15.44, 8.72),
]

var rng := RandomNumberGenerator.new()
var hills := FastNoiseLite.new()

var limestone: ShaderMaterial
var foundation: ShaderMaterial
var driftstone: ShaderMaterial
var boulder_warm: ShaderMaterial
var boulder_mossy: ShaderMaterial
var jade: ShaderMaterial
var copper: ShaderMaterial
var bark_mat: ShaderMaterial

var canopy_mats: Array[ShaderMaterial] = []
var puff_meshes: Array[ArrayMesh] = []
var sculpted_boulders: Array[Mesh] = []


func review_views() -> Array:
	return [
		[Vector3(5.4, 4.6, 15.6), Vector3(-3.6, 2.15, -8.2), 46.0],
		[Vector3(11.2, 26.2, 24.0), Vector3(-1.5, 0.7, -4.1), 45.0],
	]


func route() -> PackedVector2Array:
	return PackedVector2Array(MAIN)


func _ready() -> void:
	rng.seed = 98154
	hills.seed = 75153
	hills.frequency = 0.076
	hills.fractal_octaves = 3

	_load_boulder_pack()
	_lighting()
	_init_materials()
	_terrain()
	_water()
	_architecture()
	_court_inlay()
	_upper_gardens()
	_shore_treatment()
	_boulder_groups()
	_trees()
	_understory()
	_garden_flowers()
	_garden_edges()
	_forecourt()
	_lower_orchard()


func _load_boulder_pack() -> void:
	var root := BOULDER_PACK.instantiate()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			sculpted_boulders.append((node as MeshInstance3D).mesh)
		for child in node.get_children():
			stack.append(child)
	root.free()


func _build_lut_3d() -> ImageTexture3D:
	var img := LUT_SHEET.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	if img.get_width() != 256 or img.get_height() != 16:
		return null
	img.convert(Image.FORMAT_RGB8)
	var slices: Array[Image] = []
	for z in range(16):
		slices.append(img.get_region(Rect2i(z * 16, 0, 16, 16)))
	var tex3d := ImageTexture3D.new()
	if tex3d.create(Image.FORMAT_RGB8, 16, 16, 16, false, slices) != OK:
		return null
	return tex3d


func _lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff3d9")
	sun.light_energy = 1.12
	sun.light_angular_distance = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 72.0
	sun.shadow_blur = 0.82
	sun.rotation_degrees = Vector3(-43.0, -51.0, 0.0)
	add_child(sun)

	var sun_vec := sun.transform.basis.z.normalized()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_PAINT
	sky_mat.set_shader_parameter("cloud_tex", CLOUD_TEX)
	sky_mat.set_shader_parameter("sun_dir", sun_vec)
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_512
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Genshin High-Clarity Tone & Color Grading Pipeline
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 1.16
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.00
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.05
	var lut3d := _build_lut_3d()
	if lut3d != null:
		env.adjustment_color_correction = lut3d

	# Sky-driven hemispherical ambient & reflections (clean cool-sky / warm-bounce shadow balance!)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("a2c6e4")
	env.ambient_light_sky_contribution = 0.54
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Soft Genshin HDR Bloom (only true >1.08 HDR highlights bloom!)
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.22
	env.glow_strength = 0.88
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.08
	env.glow_hdr_scale = 1.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	# Crisp contact grounding + water reflections
	env.ssao_enabled = true
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.05
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.12

	# Luminous Aerial Perspective & Valley Mist (preserving sculpted alpine ridge facets!)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("b8e0f4")
	env.fog_light_energy = 0.98
	env.fog_sun_scatter = 0.18
	env.fog_depth_begin = 46.0
	env.fog_depth_end = 158.0
	env.fog_density = 0.52
	env.fog_aerial_perspective = 0.18
	env.fog_sky_affect = 0.04

	var scene_environment := WorldEnvironment.new()
	scene_environment.environment = env
	add_child(scene_environment)

	# Fontaine 4.0 style warm limestone indirect bounce fill at Sun-Wheel Gate courtyard
	var gate_bounce := OmniLight3D.new()
	gate_bounce.position = ORRERY_POSITION + Vector3(0.4, 2.1, 3.2)
	gate_bounce.light_color = Color("ffe6bd")
	gate_bounce.light_energy = 0.55
	gate_bounce.omni_range = 11.5
	gate_bounce.omni_attenuation = 1.6
	gate_bounce.shadow_enabled = false
	add_child(gate_bounce)


func _init_materials() -> void:
	limestone = _sun_stone(Color("f2e8d2"), 3.9, 0.44, 0.72, 0.0, 0.18, 0.35)
	foundation = _sun_stone(Color("c9c3ae"), 4.8, 0.52, 0.80, 0.0, 0.45, 0.72)
	driftstone = _sun_stone(Color("d6ceb5"), 4.2, 0.50, 0.78, 0.0, 0.62, 0.85)
	boulder_warm = _sun_stone(Color("dfd4b8"), 3.6, 0.58, 0.80, 0.0, 0.78, 0.92)
	boulder_mossy = _sun_stone(Color("c5c6ad"), 3.4, 0.58, 0.82, 0.0, 0.94, 0.95)
	jade = _sun_stone(Color("2d6e70"), 6.0, 0.18, 0.42, 0.22, 0.0, 0.0, 0.15)
	copper = _sun_stone(Color("c99c52"), 6.0, 0.16, 0.36, 0.62, 0.0, 0.0, 0.12)

	bark_mat = ShaderMaterial.new()
	bark_mat.shader = SUN_BARK

	# Species 0: Mondstadt Sage-Emerald | Species 1: Chenyu/Inazuma Pastel Sakura | Species 2: Liyue Honey-Ginkgo
	var palettes := [
		[Color("1e4d46"), Color("437f39"), Color("8ec24b"), Color("bae060"), Vector2(0.0, 0.0)],
		[Color("8c5574"), Color("e28d9e"), Color("ffd9de"), Color("fff0f2"), Vector2(1.0, 0.0)],
		[Color("84552b"), Color("d49538"), Color("f7dc72"), Color("fff09e"), Vector2(0.0, 1.0)],
	]
	for idx in range(3):
		var p: Array = palettes[idx]
		var mat := ShaderMaterial.new()
		mat.shader = CANOPY
		mat.set_shader_parameter("foliage_atlas", FOLIAGE_CARDS)
		mat.set_shader_parameter("shadow_cool", p[0])
		mat.set_shader_parameter("mid_leaf", p[1])
		mat.set_shader_parameter("sun_bright", p[2])
		mat.set_shader_parameter("sss_tint", p[3])
		canopy_mats.append(mat)
		puff_meshes.append(_build_puff_cards(p[4], 66, 4100 + idx * 97))


func _sun_stone(tint: Color, scale: float, n_str: float, rough: float, metal := 0.0, moss := 0.0, skirt := 0.0, tri := 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SUN_STONE
	mat.set_shader_parameter("stone_atlas", STONE_ATLAS)
	mat.set_shader_parameter("stone_nh", STONE_NH)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("texture_scale", scale)
	mat.set_shader_parameter("normal_strength", n_str)
	mat.set_shader_parameter("rough_base", rough)
	mat.set_shader_parameter("metallic_val", metal)
	mat.set_shader_parameter("moss_strength", moss)
	mat.set_shader_parameter("skirt_blend", skirt)
	mat.set_shader_parameter("use_triplanar", tri)
	return mat


func _build_puff_cards(quadrant: Vector2, card_count: int, seed_val: int) -> ArrayMesh:
	"""Genshin AFS-inspired volumetric leaf-card cluster with Sphericalized Crown Normals + Baked Core AO."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var local := RandomNumberGenerator.new()
	local.seed = seed_val
	var golden_angle := PI * (3.0 - sqrt(5.0))

	for i in range(card_count):
		var frac := (float(i) + 0.5) / float(card_count)
		# Distribute across 3 concentric shells: dense inner core, plush mid-shell, airy silhouette tips
		var shell_r: float
		var card_size: float
		var core_ao: float
		var flex: float
		if i < 20:
			shell_r = local.randf_range(0.20, 0.52)
			card_size = local.randf_range(0.86, 1.06)
			core_ao = local.randf_range(0.14, 0.40)
			flex = local.randf_range(0.15, 0.35)
		elif i < 48:
			shell_r = local.randf_range(0.52, 0.84)
			card_size = local.randf_range(0.76, 0.96)
			core_ao = local.randf_range(0.48, 0.82)
			flex = local.randf_range(0.40, 0.72)
		else:
			shell_r = local.randf_range(0.82, 1.04)
			card_size = local.randf_range(0.68, 0.88)
			core_ao = local.randf_range(0.82, 1.00)
			flex = local.randf_range(0.72, 1.00)

		var y_dir := 1.0 - 2.0 * frac
		# Flatten slightly into lush anime bough cushion
		var rad_xz := sqrt(maxf(0.0, 1.0 - y_dir * y_dir))
		var theta := golden_angle * float(i) + local.randf_range(-0.22, 0.22)
		var dir := Vector3(cos(theta) * rad_xz, y_dir * 0.82, sin(theta) * rad_xz).normalized()
		var center := dir * shell_r

		# Orient card tangent to puff shell with slight shingle tilt + roll so both ground & overhead cameras see full leaf faces!
		var up_ref := Vector3.UP if absf(dir.y) < 0.92 else Vector3.RIGHT
		var tang_x := up_ref.cross(dir).normalized()
		var tang_y := dir.cross(tang_x).normalized()
		var roll := local.randf() * TAU
		var rx := (tang_x * cos(roll) + tang_y * sin(roll)).normalized()
		var ry := (-tang_x * sin(roll) + tang_y * cos(roll)).normalized()
		# Shingle outward flare
		ry = (ry + dir * local.randf_range(0.18, 0.42)).normalized()

		var hs := card_size * 0.5
		var cup := dir * (card_size * 0.13)
		var card_var := local.randf()

		# Slightly domed 5-vertex (4-triangle) leaf card patch!
		var p_mid := center + cup
		var corners := [
			center - rx * hs - ry * hs,
			center + rx * hs - ry * hs,
			center + rx * hs + ry * hs,
			center - rx * hs + ry * hs,
		]
		var uvs := PackedVector2Array([
			Vector2(0.03, 0.97),
			Vector2(0.97, 0.97),
			Vector2(0.97, 0.03),
			Vector2(0.03, 0.03),
		])
		var uv_mid := (quadrant + Vector2(0.5, 0.5)) * 0.5
		var n_mid := (p_mid + Vector3(0.0, 0.34, 0.0)).normalized()
		var h_mid := clampf((p_mid.y + 0.95) / 1.90, 0.0, 1.0)

		for edge in range(4):
			var nxt := (edge + 1) % 4
			var pa: Vector3 = corners[edge]
			var pb: Vector3 = corners[nxt]
			var uva := (quadrant + uvs[edge]) * 0.5
			var uvb := (quadrant + uvs[nxt]) * 0.5
			var na := (pa + Vector3(0.0, 0.34, 0.0)).normalized()
			var nb := (pb + Vector3(0.0, 0.34, 0.0)).normalized()
			var ha := clampf((pa.y + 0.95) / 1.90, 0.0, 1.0)
			var hb := clampf((pb.y + 0.95) / 1.90, 0.0, 1.0)

			st.set_color(Color(core_ao, ha, card_var, flex))
			st.set_uv(uva)
			st.set_normal(na)
			st.add_vertex(pa)

			st.set_color(Color(core_ao, hb, card_var, flex))
			st.set_uv(uvb)
			st.set_normal(nb)
			st.add_vertex(pb)

			st.set_color(Color(minf(1.0, core_ao + 0.08), h_mid, card_var, flex * 0.85))
			st.set_uv(uv_mid)
			st.set_normal(n_mid)
			st.add_vertex(p_mid)

	return st.commit()


func _terrain() -> void:
	var ground := ShaderMaterial.new()
	ground.shader = LAND
	ground.set_shader_parameter("stone_atlas", STONE_ATLAS)
	ground.set_shader_parameter("ground_atlas", GROUND_ATLAS)
	ground.set_shader_parameter("stone_nh", STONE_NH)
	var mesh := _terrain_patch(Vector2(-43, -32), Vector2(43, 31), 160, 118, true)
	_mesh(mesh, ground, Vector3.ZERO)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Walkable garden"
	var hit := CollisionShape3D.new()
	hit.shape = mesh.create_trimesh_shape()
	floor_body.add_child(hit)
	add_child(floor_body)

	var escarpment := _solid(Color("3f7545"), 0.95)
	var valley := PlaneMesh.new()
	valley.size = Vector2(280.0, 240.0)
	_mesh(valley, escarpment, Vector3(0, -2.4, -38.0))

	var tiers := [
		[Vector2(-92., -65.), Vector2(92., -27.), Vector2i(152, 48), Color("28594e"), Color("78a36c"), Color("bce3f4"), 4.8, 0.28],
		[Vector2(-122., -92.), Vector2(122., -45.), Vector2i(176, 48), Color("376587"), Color("86b0b0"), Color("c6e8f7"), 8.2, 0.36],
		[Vector2(-150., -132.), Vector2(152., -75.), Vector2i(166, 50), Color("4d7ba8"), Color("9ec5db"), Color("d2eefb"), 13.0, 0.44],
	]
	for layer in range(tiers.size()):
		var tier: Array = tiers[layer]
		var material := ShaderMaterial.new()
		material.shader = RIDGE
		material.set_shader_parameter("pine_shadow", tier[3])
		material.set_shader_parameter("sun_rock", tier[4])
		material.set_shader_parameter("valley_mist", tier[5])
		material.set_shader_parameter("mist_height", tier[6])
		material.set_shader_parameter("mist_amount", tier[7])
		material.set_shader_parameter("detail_strength", [0.85, 0.52, 0.26][layer])
		material.set_shader_parameter("valley_floor", Color("3f7545"))
		var ridge := _mesh(_terrain_patch(tier[0], tier[1], tier[2].x, tier[2].y, false, layer), material, Vector3.ZERO)
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _terrain_patch(start: Vector2, end: Vector2, subdivisions_x: int, subdivisions_z: int, walkable: bool, ridge_tier := 0) -> ArrayMesh:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var width := subdivisions_x + 1
	for j in range(subdivisions_z + 1):
		var z := lerpf(start.y, end.y, float(j) / float(subdivisions_z))
		for i in range(width):
			var x := lerpf(start.x, end.x, float(i) / float(subdivisions_x))
			var p := Vector2(x, z)
			var y := _height(p) if walkable else _ridge_height(p, ridge_tier)
			var eps := 0.14
			var hx := _height(p + Vector2(eps, 0)) - _height(p - Vector2(eps, 0)) if walkable else _ridge_height(p + Vector2(eps, 0), ridge_tier) - _ridge_height(p - Vector2(eps, 0), ridge_tier)
			var hz := _height(p + Vector2(0, eps)) - _height(p - Vector2(0, eps)) if walkable else _ridge_height(p + Vector2(0, eps), ridge_tier) - _ridge_height(p - Vector2(0, eps), ridge_tier)
			positions.append(Vector3(x, y, z))
			normals.append(Vector3(-hx, eps * 2.0, -hz).normalized())
			var route_dist := _road_dist(p) if walkable else 40.0
			var orchard := 1.0 - smoothstep(.48, 1.45, _path_distance(p, ORCHARD_BRANCH)) if walkable else 0.0
			var track := maxf(1.0 - smoothstep(1.05, 3.05, route_dist), orchard * .86)
			var sand := 1.0 - smoothstep(0.0, 0.28, absf(_pond_math(p) - 1.0))
			colors.append(Color(track, orchard, sand))
			if i < subdivisions_x and j < subdivisions_z:
				var index := j * width + i
				indices.append_array(PackedInt32Array([index, index + 1, index + width + 1, index, index + width + 1, index + width]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _height(p: Vector2) -> float:
	var y := hills.get_noise_2dv(p) * 0.72
	var route_dist := _road_dist(p)
	var edge := smoothstep(7.4, 24.2, absf(p.x))
	y += edge * (1.2 + 3.1 * maxf(0.0, hills.get_noise_2dv(p * .53)))
	var western_fold := 1.0 - smoothstep(.12, 1.0, ((p - Vector2(-25., -9.)) / Vector2(17., 21.)).length())
	var orchard_back := 1.0 - smoothstep(.08, 1.0, ((p - Vector2(-15., -22.5)) / Vector2(27., 8.0)).length())
	y += western_fold * 3.15 + orchard_back * 2.24
	var eastern_toe := 1.0 - smoothstep(.10, 1.0, ((p - Vector2(24.0, -15.6)) / Vector2(12.4, 11.4)).length())
	var rear_toe := 1.0 - smoothstep(.08, 1.0, ((p - Vector2(3.45, -25.8)) / Vector2(22.8, 7.2)).length())
	var leeward_toe := 1.0 - smoothstep(.15, 1.0, ((p - Vector2(-23.8, -2.4)) / Vector2(10.4, 17.5)).length())
	var soil_ribs := .67 + .33 * sin(p.x * .56 + p.y * .32 + hills.get_noise_2dv(p * 1.53))
	y += (eastern_toe * 1.69 + rear_toe * .92 + leeward_toe * 1.08) * soil_ribs
	if p.x < -10.5:
		var terrace := _terrace_line(p.y)
		var gardens := smoothstep(-5.6, -3.3, p.y) * (1.0 - smoothstep(11.3, 14.2, p.y))
		y += gardens * (.30 * smoothstep(.04, .53, terrace - p.x)
			+ .39 * smoothstep(2.1, 2.62, terrace - p.x)) * (1.0 - smoothstep(7.4, 12.0, terrace - p.x))
	y += maxf(0.0, -p.y - 16.0) * 0.17
	y *= smoothstep(2.1, 5.3, route_dist)
	var pond_edge := _pond_math(p)
	var basin := smoothstep(0.75, 1.11, pond_edge)
	return lerpf(-1.18 + y * 0.22, y, basin)


func _paving_stage_height(p: Vector2) -> float:
	return lerpf(_height(p), 0.0, .70)


func _terrace_line(z: float) -> float:
	return -13.42 + 1.43 * cos((z - 4.08) * .238) - maxf(0.0, z - 9.0) * .21


func _ridge_height(p: Vector2, layer: int) -> float:
	var relief := 0.0
	var altered := p + Vector2(hills.get_noise_2dv(p * .67 + Vector2(13.0, -5.0)), hills.get_noise_2dv(p * .81)) * 3.1
	var scarp := hills.get_noise_2dv(p * Vector2(1.3, 1.72))
	var profiles: Array = RIDGE_LANDMARKS[layer]
	for i in profiles.size():
		var spec: Array = profiles[i]
		var lateral := (p.x - float(spec[0])) / float(spec[2])
		var depth := (p.y - float(spec[1])) / float(spec[3])
		if absf(lateral) > 1.39 or absf(depth) > 1.38:
			continue
		var shoulder_shape := sin(lateral * 4.7 + depth * 2.23 + float(spec[5]) * 3.0)
		var contour := Vector2(lateral + depth * float(spec[5]) + .075 * shoulder_shape,
			depth + sin(lateral * 2.61) * .24 - .061 * shoulder_shape)
		var radius := contour.length()
		var summit := [.94, 1.24, 1.62, 1.18][(i + layer) % 4] as float
		var ledge := maxf(0.0, 1.0 - pow(radius, summit))
		var spill := altered.x * (.33 + .035 * (i % 3)) + altered.y * (.32 + lateral * .081)
		var cleft := smoothstep(.51, .88, .5 + .5 * sin(spill)) * smoothstep(.06, .68, maxf(0.0, depth + .12))
		var bench := smoothstep(.36, .66, ledge) * (1.0 - smoothstep(.68, .89, ledge))
		var height := pow(ledge, 1.21) * (1.0 + scarp * .20 - cleft * .135 + bench * .08) * float(spec[4])
		var overlap := minf(relief, height)
		var merge := maxf(0.0, [1.86, 2.96, 3.90][layer] - absf(relief - height)) as float
		relief = maxf(relief, height) + merge * .22 * smoothstep(.05, 2.5, overlap)
	var front: float = [-27., -45., -75.][layer]
	var shoulder: float = [8.8, 10.0, 12.8][layer]
	relief *= smoothstep(0.0, shoulder, front - p.y)
	return -2.46 + relief + (scarp * .63 + sin(p.x * .15) * .23) * smoothstep(0.0, 5.2, relief)


func _path_distance(p: Vector2, points: Array) -> float:
	var distance := INF
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return distance


func _road_dist(p: Vector2) -> float:
	return minf(_path_distance(p, MAIN), minf(_path_distance(p, GARDEN_BRANCH) + 0.4, _path_distance(p, POND_BRANCH) + 0.45))


func _pond_math(p: Vector2) -> float:
	return ((p - POND) / POND_RADIUS + Vector2(sin(p.y * .34), sin(p.x * .61)) * .08).length()


func _water() -> void:
	var material := ShaderMaterial.new()
	material.shader = WATER
	var plane := PlaneMesh.new()
	plane.size = POND_RADIUS * 2.32
	plane.subdivide_width = 16
	plane.subdivide_depth = 20
	_mesh(plane, material, Vector3(POND.x, -0.17, POND.y)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var submerged := _sun_stone(Color("a5b28c"), 4.2, 0.35, 0.65, 0.0, 0.35, 0.0)
	var shoals := [[Vector2(4.18, 2.82), 8], [Vector2(7.53, 5.91), 6], [Vector2(12.52, -5.09), 7],
		[Vector2(4.71, -5.43), 7], [Vector2(11.56, 3.78), 6]]
	var silt := RandomNumberGenerator.new()
	silt.seed = 49518
	for shoal in shoals:
		for i in range(shoal[1]):
			var p: Vector2 = shoal[0] + Vector2(silt.randf_range(-.95, .95), silt.randf_range(-.83, .83))
			if _pond_math(p) > .94:
				continue
			var b_mesh: Mesh = sculpted_boulders[3] if not sculpted_boulders.is_empty() else SphereMesh.new()
			var piece := _mesh(b_mesh, submerged, Vector3(p.x, minf(-.31, _height(p) + .12), p.y))
			piece.scale = Vector3(1.0, 0.55, 0.9) * silt.randf_range(.38, .92)
			piece.rotation.y = silt.randf() * TAU

	# Sculpted notched 3D water-lily pads + multi-petal lotus blooms!
	var pad_mesh := _lily_pad_mesh()
	var lotus_mesh := _lotus_flower_mesh()
	var pad_mat := _sun_stone(Color("4f8c42"), 8.0, 0.12, 0.62, 0.0, 0.0, 0.0, 0.0)
	var lotus_mat := StandardMaterial3D.new()
	lotus_mat.albedo_color = Color("fff0f3")
	lotus_mat.roughness = 0.55
	lotus_mat.emission_enabled = true
	lotus_mat.emission = Color("ffdce4")
	lotus_mat.emission_energy_multiplier = 0.24

	for bed in [Vector2(4.5, 1.8), Vector2(12.2, -3.5), Vector2(9.2, -7.8), Vector2(11.2, 4.9)]:
		for i in range(9):
			var point: Vector2 = bed + _jitter(1.02)
			if _pond_math(point) > .93:
				continue
			var pad := _mesh(pad_mesh, pad_mat, Vector3(point.x, -.155, point.y))
			pad.rotation.y = rng.randf() * TAU
			pad.scale = Vector3.ONE * rng.randf_range(.68, 1.38)
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if i % 3 == 0:
				var fl := _mesh(lotus_mesh, lotus_mat, Vector3(point.x, -.138, point.y))
				fl.rotation.y = rng.randf() * TAU
				fl.scale = Vector3.ONE * rng.randf_range(0.85, 1.2)
				fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _lily_pad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 15
	# Leave a 1-segment V-notch like a real water-lily leaf!
	var span := TAU * 0.91
	for i in range(segs):
		var a0 := float(i) / float(segs) * span
		var a1 := float(i + 1) / float(segs) * span
		var r0 := 0.27 * (0.94 + 0.06 * sin(a0 * 5.0))
		var r1 := 0.27 * (0.94 + 0.06 * sin(a1 * 5.0))
		st.set_color(Color(0.55, 0.5, 0.5, 0.0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(0.85, 0.5, 0.5, 0.0))
		st.set_normal(Vector3(cos(a1) * 0.15, 0.98, sin(a1) * 0.15).normalized())
		st.add_vertex(Vector3(cos(a1) * r1, 0.014, sin(a1) * r1))
		st.set_normal(Vector3(cos(a0) * 0.15, 0.98, sin(a0) * 0.15).normalized())
		st.add_vertex(Vector3(cos(a0) * r0, 0.014, sin(a0) * r0))
	return st.commit()


func _lotus_flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(2):
		var petals := 6 if ring == 0 else 5
		var lift := 0.045 if ring == 0 else 0.085
		var reach := 0.13 if ring == 0 else 0.085
		for p in range(petals):
			var a := (float(p) + ring * 0.5) * TAU / float(petals)
			var dir := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-dir.z, 0, dir.x) * (0.042 if ring == 0 else 0.032)
			var tip := dir * reach + Vector3.UP * lift
			var mid := dir * (reach * 0.52) + Vector3.UP * (lift * 0.35)
			var n := (Vector3.UP + dir * 0.5).normalized()
			for tri in [[Vector3.ZERO, mid + side, tip], [Vector3.ZERO, tip, mid - side]]:
				for v in tri:
					st.set_normal(n)
					st.add_vertex(v)
	return st.commit()


func _upgrade_gate_materials(node: Node) -> void:
	var hero_ivory := _sun_stone(Color("f7efe0"), 4.2, 0.36, 0.68, 0.0, 0.0, 0.0)
	var hero_pale := _sun_stone(Color("fff6e5"), 4.0, 0.30, 0.60, 0.0, 0.0, 0.0)
	var hero_base := _sun_stone(Color("b6b59f"), 4.4, 0.48, 0.78, 0.0, 0.45, 0.55)
	var hero_dark := _sun_stone(Color("3d4f63"), 5.0, 0.25, 0.72, 0.08, 0.0, 0.0, 0.2)
	var hero_enamel := _sun_stone(Color("246b78"), 6.0, 0.15, 0.38, 0.28, 0.0, 0.0, 0.1)
	var hero_bronze := _sun_stone(Color("376362"), 6.0, 0.18, 0.44, 0.52, 0.0, 0.0, 0.1)
	var hero_gilt := _sun_stone(Color("e0b25c"), 6.0, 0.12, 0.30, 0.78, 0.0, 0.0, 0.08)
	var hero_glow := StandardMaterial3D.new()
	hero_glow.albedo_color = Color("ffe6a3")
	hero_glow.roughness = 0.22
	hero_glow.emission_enabled = true
	hero_glow.emission = Color("ffcf70")
	hero_glow.emission_energy_multiplier = 1.65

	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					var m := mi.mesh.surface_get_material(s)
					var mname := m.resource_name if m != null else ""
					if "Amber" in mname or "glass" in mname:
						mi.set_surface_override_material(s, hero_glow)
					elif "filigree" in mname or "gilt" in mname.to_lower():
						mi.set_surface_override_material(s, hero_gilt)
					elif "enamel" in mname.to_lower():
						mi.set_surface_override_material(s, hero_enamel)
					elif "bronze" in mname.to_lower():
						mi.set_surface_override_material(s, hero_bronze)
					elif "Deepened" in mname:
						mi.set_surface_override_material(s, hero_dark)
					elif "foundation" in mname.to_lower():
						mi.set_surface_override_material(s, hero_base)
					elif "Honey" in mname:
						mi.set_surface_override_material(s, hero_pale)
					else:
						mi.set_surface_override_material(s, hero_ivory)
		for ch in cur.get_children():
			stack.append(ch)


func _architecture() -> void:
	var gate := ORRERY.instantiate() as Node3D
	gate.position = ORRERY_POSITION
	gate.rotation.y = deg_to_rad(8.0)
	_upgrade_gate_materials(gate)
	add_child(gate)

	_box(Vector3(-7.8, -0.12, -11.4), Vector3(7.48, 0.61, 4.6), foundation)
	_collision(Vector3(-7.85, 1.15, -11.7), Vector3(6.94, 2.4, 2.85))
	for i in range(3):
		_box(Vector3(-7.83, -0.18 + i * .115, -8.58 - i * .26), Vector3(6.72 - i * .16, .23, .56), limestone)
	for wing in [[-13.0, -12.6, .20], [-2.76, -12.6, -.07]]:
		var origin := Vector3(wing[0], 0, wing[1])
		for row in range(2):
			for i in range(5):
				var x := float(i - 2) * .71 + (row * .17)
				var point := origin + Vector3(x, -.08 + row * .32, x * wing[2])
				var brick := _box(point, Vector3(.68, .31, .72), limestone if (i + row) % 3 else foundation)
				brick.rotation.y = -wing[2]
		_column(origin + Vector3(1.39, 0, 0.38), 1.22)
	for anchor in [Vector2(-4.4, 7.7), Vector2(2.42, 5.7), Vector2(-5.22, -6.4), Vector2(2.54, -10.56), Vector2(13.75, -7.9)]:
		_brazier(anchor)
	for point in [Vector2(-8.1, 6.3), Vector2(-10.5, -6.2), Vector2(13.0, 7.3), Vector2(-.74, -15.9)]:
		_garden_bench(point)


func _court_inlay() -> void:
	var at := Vector2(-.05, 6.55)
	var bedding := _sun_stone(Color("d9c49c"), 2.8, 0.25, 0.72, 0.0, 0.0, 0.0)
	var stone_ring := SurfaceTool.new()
	var brass_ring := SurfaceTool.new()
	stone_ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	brass_ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sector in range(36):
		var center := TAU * float(sector) / 36.0
		var width := TAU / 36.0
		if sector not in [1, 2, 11, 19, 20, 25, 31]:
			_inlay_panel(stone_ring, at, center - width * .48, center + width * .50, 1.35, 1.59)
		if sector not in [0, 1, 6, 15, 16, 27, 29, 30]:
			_inlay_panel(brass_ring, at, center - width * .50, center + width * .51, 1.30, 1.34)
		if sector % 6 in [0, 1] and sector != 30:
			_inlay_panel(brass_ring, at, center - width * .24, center + width * .22, 1.08, 1.22)
	for mark in range(7):
		var from_angle := TAU * mark / 7.0
		var to_angle := TAU * (mark + 1.0) / 7.0
		_inlay_panel(stone_ring, at, from_angle + .018, to_angle - .018, .30, .46)
		if mark in [0, 1, 3, 4]:
			var bearing := (from_angle + to_angle) * .5
			_inlay_panel(brass_ring, at, bearing - .035, bearing + .035, .58, 1.01)
	for pair: Array in [[stone_ring, bedding], [brass_ring, copper]]:
		pair[0].generate_normals()
		_mesh(pair[0].commit(), pair[1], Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _inlay_panel(layer: SurfaceTool, at: Vector2, left: float, right: float, inner: float, outer: float) -> void:
	var a := Vector2(cos(left), sin(left))
	var b := Vector2(cos(right), sin(right))
	var corners := [at + a * inner, at + a * outer, at + b * outer, at + b * inner]
	for index in [0, 1, 2, 0, 2, 3]:
		var p: Vector2 = corners[index]
		layer.set_color(Color(0.6, 0.5, 0.5, 0.0))
		layer.add_vertex(Vector3(p.x, _height(p) + .016, p.y))


func _upper_gardens() -> void:
	var cuts := ShaderMaterial.new()
	cuts.shader = STRATA
	cuts.set_shader_parameter("stone_atlas", STONE_ATLAS)
	cuts.set_shader_parameter("stone_nh", STONE_NH)
	var local := RandomNumberGenerator.new()
	local.seed = 280142

	var outcrops := [
		[Vector2(-19.85, -10.1), Vector3(6.9, 3.12, 6.3), -.32],
		[Vector2(-20.60, -13.8), Vector3(7.8, 4.6, 6.2), -.46],
		[Vector2(-16.99, -17.4), Vector3(7.7, 3.22, 6.35), -.27],
		[Vector2(-20.05, -4.2), Vector3(6.6, 2.28, 7.5), .24],
		[Vector2(-21.75, 1.3), Vector3(8.65, 2.7, 5.9), -.35],
		[Vector2(-18.65, 6.0), Vector3(5.2, 1.42, 4.6), .36],
		[Vector2(15.36, -22.36), Vector3(9.9, 3.97, 5.16), .20],
		[Vector2(19.5, -19.7), Vector3(9.2, 3.2, 5.4), -.30],
		[Vector2(23.7, -17.2), Vector3(9.7, 3.6, 5.7), -.53],
		[Vector2(6.65, -24.9), Vector3(8.9, 2.85, 5.8), -.09],
		[Vector2(-.3, -24.05), Vector3(8.2, 2.3, 5.2), .02],
		[Vector2(-8.1, -24.27), Vector3(10.3, 2.4, 6.3), -.19],
	]
	for index in range(outcrops.size()):
		var record: Array = outcrops[index]
		var p: Vector2 = record[0]
		var dimensions: Vector3 = record[1]
		var facing: float = record[2]
		var rock := _mesh(_strata_mesh(dimensions, local), cuts, Vector3(p.x, _height(p) - .61, p.y))
		rock.rotation.y = facing
		_collision(rock.position + Vector3(0, dimensions.y * .26, 0), dimensions * Vector3(.70, .71, .58))
		if index in [1, 2, 4, 6, 8, 9, 11]:
			var root := rock.position + Vector3(.22, dimensions.y * .925, -.34)
			_tree(root, 2.6 + .6 * float(index % 3), 0 if index != 6 else 2)

	_bedded_spur(PackedVector2Array([
		Vector2(-15.5, -20.9), Vector2(-16.4, -18.2), Vector2(-17.63, -15.6), Vector2(-16.52, -13.1),
		Vector2(-17.04, -10.6), Vector2(-18.58, -7.98), Vector2(-18.26, -5.9), Vector2(-17.44, -4.1),
		Vector2(-18.82, -2.18), Vector2(-17.92, .12), Vector2(-17.13, 1.86), Vector2(-17.65, 3.11),
		Vector2(-17.79, 4.8), Vector2(-17.29, 6.2), Vector2(-19.32, 7.1),
	]), PackedFloat32Array([.14, .83, 1.86, 2.47, 1.8, 1.25, .78, 1.19, .92, 1.27, 2.10, 1.69, 1.35, .66, .04]), 4.35, cuts)
	_bedded_spur(PackedVector2Array([
		Vector2(24.7, -19.6), Vector2(22.7, -19.1), Vector2(20.45, -20.36), Vector2(17.62, -20.31),
		Vector2(14.96, -20.78), Vector2(13.32, -22.0), Vector2(11.4, -22.12), Vector2(8.8, -21.88),
		Vector2(5.96, -22.48), Vector2(3.1, -22.13), Vector2(.57, -22.75), Vector2(-2.81, -22.46),
		Vector2(-5.11, -21.8), Vector2(-8.3, -21.98), Vector2(-10.6, -22.64), Vector2(-13.1, -24.0),
	]), PackedFloat32Array([.10, .65, 1.2, 1.89, 1.76, .95, .73, .95, 1.42, 1.18, .73, 1.06, 1.28, 1.38, .92, .09]), 3.24, cuts)

	var trim := _sun_stone(Color("e2d3b3"), 4.0, 0.42, 0.74, 0.0, 0.25, 0.35)
	var old_tiles := jade
	var arcade_origin := Vector3(3.3, 0, -18.8)
	for index in range(3):
		var bay := arcade_origin + Vector3(4.03 * index, 0, -.20 * index)
		_viaduct_bay(bay, index, trim, old_tiles, local)
	var end := arcade_origin + Vector3(10.12, 0, -.48)
	for i in range(5):
		var offset := Vector3(.47 * i, -.35 + .35 * i, -.08 * i)
		var abutment := _worn_block(end + offset, Vector3(1.30, 1.25, 1.95), .14, local)
		abutment.material_override = trim
	_collision(end + Vector3(.72, .80, 0), Vector3(2.82, 2.70, 1.96))

	_plant_terrace_pockets(local)


func _bedded_spur(edge: PackedVector2Array, crown_height: PackedFloat32Array, reach: float, cut: Material) -> void:
	var sections: Array[PackedVector3Array] = []
	var skirt_masks: Array[PackedFloat32Array] = []
	for i in edge.size():
		var corner := edge[i]
		var tangent := edge[mini(i + 1, edge.size() - 1)] - edge[maxi(i - 1, 0)]
		var rise := Vector2(-tangent.y, tangent.x).normalized()
		var crest := crown_height[i]
		var width := reach * (.81 + .19 * sin(.96 * i + .6))
		var heights := PackedFloat32Array([-.13, .06, .41, .36, .81, .86, 1., .51, -.15])
		var offsets := PackedFloat32Array([-.91, -.53, -.10, .02, .25, .66, 1.18, width * .68, width])
		var section := PackedVector3Array()
		var skirts := PackedFloat32Array()
		for band in heights.size():
			var p := corner + rise * offsets[band] * (.70 + clampf(crest, .0, 1.) * .3)
			var bed := _height(p)
			var shape := heights[band] * crest + sin(i * 1.3 + band * .73) * .09 * clampf(crest, .0, 1.)
			section.append(Vector3(p.x, bed + shape, p.y))
			skirts.append(1.0 - smoothstep(0.0, 0.55, maxf(0.0, shape)))
		sections.append(section)
		skirt_masks.append(skirts)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in range(sections[0].size() - 1):
		surface.set_smooth_group(band)
		for i in range(sections.size() - 1):
			var pts := [sections[i][band], sections[i + 1][band + 1], sections[i][band + 1],
				sections[i][band], sections[i + 1][band], sections[i + 1][band + 1]]
			var sks := [skirt_masks[i][band], skirt_masks[i + 1][band + 1], skirt_masks[i][band + 1],
				skirt_masks[i][band], skirt_masks[i + 1][band], skirt_masks[i + 1][band + 1]]
			var tone := .48 + sin(i * 1.43 + band * 2.87) * .14
			if band in [1, 3]:
				tone += .17
			elif band in [2, 4]:
				tone -= .18
			var moss := .82 if band >= 5 else .38
			for k in range(6):
				surface.set_color(Color(tone, moss, .53, sks[k]))
				surface.add_vertex(pts[k])
	surface.generate_normals()
	var ledges := _mesh(surface.commit(), cut, Vector3.ZERO)
	ledges.create_trimesh_collision()


func _strata_mesh(size: Vector3, local: RandomNumberGenerator) -> ArrayMesh:
	var profile := PackedVector2Array([Vector2(-.56, -.09), Vector2(-.49, -.31), Vector2(-.39, -.43),
		Vector2(-.22, -.51), Vector2(.02, -.53), Vector2(.21, -.50), Vector2(.42, -.41),
		Vector2(.52, -.22), Vector2(.57, -.07), Vector2(.52, .18), Vector2(.40, .27),
		Vector2(.30, .39), Vector2(.11, .46), Vector2(-.10, .43), Vector2(-.32, .39), Vector2(-.51, .26)])
	var levels: Array[PackedVector3Array] = []
	var whorls := [[-.26, 1.13, -.12], [.08, 1.09, -.10], [.27, 1.0, -.04],
		[.36, .89, -.015], [.42, .94, -.035], [.61, .92, .024], [.68, .80, .045],
		[.73, .83, .047], [.855, .74, .085], [.925, .60, .11]]
	var lash := local.randf_range(-.16, .16)
	var lean := local.randf_range(-.07, .12)
	var offsets := PackedFloat32Array()
	for _corner in profile:
		offsets.append(local.randf_range(-.19, .19))
	for band in whorls:
		var ring := PackedVector3Array()
		for i in profile.size():
			var corner := profile[i]
			var scale := float(band[1]) + float(offsets[i]) * .38
			var x: float = corner.x * scale + band[2] + local.randf_range(-.026, .026)
			var z: float = corner.y * scale + corner.x * lash * float(band[0]) + local.randf_range(-.018, .018)
			var y: float = band[0] + x * (.108 + lean) + z * .081 + local.randf_range(-.018, .018)
			ring.append(Vector3(x, y, z) * size)
		levels.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(levels.size() - 1):
		surface.set_smooth_group(layer)
		var sk0 := 1.0 - smoothstep(-0.1, 0.42, float(whorls[layer][0]))
		var sk1 := 1.0 - smoothstep(-0.1, 0.42, float(whorls[layer + 1][0]))
		var weathered := Color(.56, .52, .55, sk0)
		if layer in [2, 6, 8]:
			weathered = Color(.68, .58, .50, sk0)
		elif layer in [3, 5]:
			weathered = Color(.46, .48, .60, sk0)
		var weathered_top := Color(weathered.r, weathered.g, weathered.b, sk1)
		for i in range(profile.size()):
			var next := (i + 1) % profile.size()
			var tri_pts := [levels[layer][i], levels[layer][next], levels[layer + 1][next],
				levels[layer][i], levels[layer + 1][next], levels[layer + 1][i]]
			var tri_cols := [weathered, weathered, weathered_top, weathered, weathered_top, weathered_top]
			for k in range(6):
				surface.set_color(tri_cols[k])
				surface.add_vertex(tri_pts[k])
	var cap := levels[-1]
	var crest := Vector3(.09 * size.x, .955 * size.y, -.084 * size.z)
	surface.set_smooth_group(levels.size())
	for i in range(profile.size()):
		for point in [cap[i], cap[(i + 1) % profile.size()], crest]:
			surface.set_color(Color(.64, .92, .40, 0.0))
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()


func _viaduct_bay(at: Vector3, index: int, trim: Material, old_tiles: Material, local: RandomNumberGenerator) -> void:
	var spring := at + Vector3(0, 1.83, .03)
	var sides := [-1.0, 1.0] if index == 0 else [1.0]
	for side: float in sides:
		var post := at + Vector3(side * 2.015, 0, -.06)
		var base := _height(Vector2(post.x, post.z))
		var bottom := minf(base - .18, .05)
		_box(post + Vector3(0, bottom + .11, 0), Vector3(.92, .34, 1.42), foundation)
		for course in range(4):
			var center := Vector3(post.x, lerpf(bottom + .27, 1.62, course / 3.0), post.z)
			var stone := _worn_block(center, Vector3(.74, .54, .94), .07, local)
			stone.material_override = trim if course in [0, 2] else limestone
		_box(post + Vector3(0, 1.82, 0), Vector3(.96, .18, 1.24), limestone)
		_collision(post + Vector3(0, 1.02, 0), Vector3(.77, 2.12, .97))
	var segments := 13
	for i in range(segments):
		var first := PI * float(i) / float(segments) + .007
		var last := PI * float(i + 1) / float(segments) - .007
		var top_rail := 3.53 - at.y
		var arch := _arch_stone(first, last, Vector2(1.56, 1.31), Vector2(1.96, 1.64), .14)
		_mesh(arch, trim if i % 4 == 1 else limestone, spring + Vector3(0, 0, .54))
		var wall := _arch_stone(first - .009, last + .009, Vector2(1.60, 1.36), Vector2(1.98, 1.67), .89, top_rail - spring.y)
		_mesh(wall, foundation if i % 4 == 2 else trim, spring + Vector3(0, 0, -.05))
	_box(at + Vector3(0, 3.59, 0), Vector3(4.05, .17, 1.34), limestone)
	_box(at + Vector3(0, 3.77, -.015), Vector3(4.05, .095, 1.10), old_tiles)
	_box(at + Vector3(0, 3.90, -.09), Vector3(4.05, .16, .88), trim)
	for offset: float in [-.82, .82]:
		_cylinder(at + Vector3(offset, 3.1, .565), .115, .115, .04, copper, 10).rotation.x = PI * .5
	_collision(at + Vector3(0, 3.51, 0), Vector3(4.00, .9, 1.2))


func _arch_stone(first: float, last: float, inside: Vector2, outside: Vector2, depth: float, to_coping := -1.0) -> ArrayMesh:
	var points := PackedVector3Array()
	for z: float in [depth / 2.0, -depth / 2.0]:
		for coordinate in [Vector2(cos(last), sin(last)) * inside, Vector2(cos(last), sin(last)) * outside,
			Vector2(cos(first), sin(first)) * outside, Vector2(cos(first), sin(first)) * inside]:
			var p: Vector2 = coordinate
			if to_coping > 0.0 and points.size() % 4 in [1, 2]:
				p.y = to_coping
			points.append(Vector3(p.x, p.y, z))
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	band.set_smooth_group(-1)
	for face in [[1, 0, 3, 2], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [2, 3, 7, 6], [1, 5, 4, 0]]:
		for corner: int in [face[0], face[2], face[1], face[0], face[3], face[2]]:
			band.set_color(Color(0.62, 0.4, 0.5, 0.0))
			band.add_vertex(points[corner])
	band.generate_normals()
	return band.commit()


func _plant_terrace_pockets(local: RandomNumberGenerator) -> void:
	var beds := [
		[Vector2(-15.2, 5.2), Vector2(1.54, .77), -1.0], [Vector2(-14.2, -3.0), Vector2(1.81, .96), -.6],
		[Vector2(-10.3, -8.5), Vector2(.72, .85), .4], [Vector2(-8.1, 8.55), Vector2(1.20, .58), .44],
		[Vector2(-3.56, 5.52), Vector2(.70, .92), -.48], [Vector2(3.01, 4.13), Vector2(.83, 1.04), -.27],
		[Vector2(1.08, -16.76), Vector2(1.30, .52), -.22], [Vector2(5.22, -17.42), Vector2(1.45, .76), .24],
		[Vector2(12.63, -15.65), Vector2(1.31, .72), .18], [Vector2(-18.0, -12.2), Vector2(1.72, .80), -.18],
	]
	var low := _flora_mat(Color("27592c"), Color("6fb03b"))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for bed: Array in beds:
		for _place in range(14):
			var offset := Vector2(local.randf_range(-1., 1.), local.randf_range(-1., 1.))
			var p: Vector2 = bed[0] + (offset * (bed[1] as Vector2)).rotated(bed[2])
			if _road_dist(p) < 2.10 or _pond_math(p) < 1.03:
				continue
			var y := _height(p)
			var h := local.randf_range(0.42, 0.85)
			var base_yaw := local.randf() * TAU
			for k in range(3):
				var card := _mesh(quad, low, Vector3(p.x, y + h * 0.42, p.y))
				card.scale = Vector3(h * 1.25, h, 1.0)
				card.rotation = Vector3(deg_to_rad(14.0), base_yaw + float(k) * TAU / 3.0, 0.0)
				card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _shore_treatment() -> void:
	var spans := [
		[2.40, 3.13, 0.11],
		[3.30, 3.68, 0.14],
		[4.36, 4.67, 0.17],
		[5.38, 5.66, 0.16],
		[0.49, 0.83, 0.18],
	]
	for span in spans:
		var first: float = span[0]
		var end: float = span[1]
		var interval: float = span[2]
		var count := floori((end - first) / interval) + 1
		for index in range(count):
			var a := first + index * interval
			var out := Vector2(cos(a), sin(a))
			var p := POND + POND_RADIUS * out * (1.053 + sin(a * 11.4) * .020)
			var y := _height(p)
			var span_size := rng.randf_range(.56, .78)
			var block := _box(Vector3(p.x, y + .035, p.y), Vector3(span_size, .28, .38), foundation)
			block.rotation.y = atan2(out.x, out.y) + rng.randf_range(-.15, .15)
			if index % 3 != 2:
				var coping := _box(Vector3(p.x, y + .17, p.y), Vector3(span_size * .92, .093, .44), limestone)
				coping.rotation.y = block.rotation.y

	var court := Vector3(7.95, -0.07, -16.64)
	_box(court, Vector3(3.3, .25, 2.20), foundation)
	_box(court + Vector3(0, .155, .08), Vector3(3.06, .14, 1.94), limestone)
	for i in [-1, 1]:
		_column(court + Vector3(i * 1.18, .22, -.58), 1.2 if i == -1 else 2.14)
	var dial_at := court + Vector3(.07, .34, -.225)
	_cylinder(dial_at, .63, .72, .29, limestone, 14)
	_cylinder(dial_at + Vector3(0, .19, 0), .54, .55, .13, jade, 14)
	_taper(dial_at + Vector3(0, .24, .11), dial_at + Vector3(.19, .91, -.30), .073, .025, copper)
	for index in range(8):
		var phase := TAU * float(index) / 8.0
		var mark := _box(dial_at + Vector3(cos(phase) * .44, .266, sin(phase) * .44), Vector3(.094, .032, .035), copper)
		mark.rotation.y = -phase


func _garden_edges() -> void:
	var slab_rng := RandomNumberGenerator.new()
	slab_rng.seed = 6598
	var ledges := [
		[Vector2(-11.7, 9.5), Vector2(-10.5, 7.1), Vector2(-9.9, 4.5), Vector2(-10.4, 2.45), Vector2(-11.35, 0.45)],
		[Vector2(-13.4, 8.5), Vector2(-12.4, 6.4), Vector2(-12.0, 4.7), Vector2(-12.6, 2.9)],
	]
	var moss := boulder_mossy
	for row in range(ledges.size()):
		var wall: Array = ledges[row]
		for section in range(wall.size() - 1):
			var from: Vector2 = wall[section]
			var to: Vector2 = wall[section + 1]
			var count := maxi(2, roundi(from.distance_to(to) / .73))
			var yaw := atan2(-(to - from).y, (to - from).x)
			for index in range(count):
				var p := from.lerp(to, (float(index) + .5) / count)
				var y := _height(p)
				var height := slab_rng.randf_range(.33, .55) * (1.05 if row == 0 else .82)
				var base := Vector3(p.x, y + height * .26, p.y)
				var width := from.distance_to(to) / count
				var stone := _worn_block(base, Vector3(width * .98, height, .82), .14, slab_rng)
				stone.material_override = moss if (section + index) % 4 == 0 else foundation
				stone.rotation.y = yaw + slab_rng.randf_range(-.075, .075)
				if (section + index * 2 + row) % 5 != 2:
					var lip := _worn_block(base + Vector3(0, height * .56, 0), Vector3(width * .97, .145, .91), .12, slab_rng)
					lip.material_override = limestone if index % 3 == 0 else foundation
					lip.rotation.y = stone.rotation.y
	var bank := Vector2(-.38, .925).normalized()
	var outward := Vector2(bank.x, bank.y).normalized()
	var bearing := atan2(outward.x, outward.y)
	for later in range(5):
		var distance := 1.16 - float(later) * .053
		var p := POND + POND_RADIUS * bank * distance
		var y := maxf(-.46, _height(p)) + .026
		var step := _worn_block(Vector3(p.x, y, p.y), Vector3(1.81 - later * .072, .15, .58), .12, slab_rng)
		step.rotation.y = bearing
		step.material_override = limestone if later < 2 else moss
		for side: float in [-1.0, 1.0]:
			var shoulder := p + Vector2(outward.y, -outward.x) * side * .96
			var trim := _worn_block(Vector3(shoulder.x, maxf(-.40, _height(shoulder)) + .09, shoulder.y),
				Vector3(.40, .38, .64), .16, slab_rng)
			trim.rotation.y = bearing + side * .13
			trim.material_override = foundation


func _worn_block(origin: Vector3, size: Vector3, irregularity: float, local_rng: RandomNumberGenerator) -> MeshInstance3D:
	var xs := [-.5, -.35, .34, .5, .5, .34, -.35, -.5]
	var zs := [-.31, -.5, -.5, -.33, .31, .5, .5, .32]
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels: Array[PackedVector3Array] = []
	var offsets := PackedVector2Array()
	for i in range(8):
		offsets.append(Vector2(local_rng.randf_range(-irregularity, irregularity),
			local_rng.randf_range(-irregularity, irregularity)) * .28)
	for layer in range(4):
		var bevel := .84 if layer % 3 == 0 else 1.0
		var height: float = [-.5, -.31, .26, .50][layer]
		var ring := PackedVector3Array()
		for i in range(8):
			ring.append(Vector3((float(xs[i]) + offsets[i].x) * bevel, height + local_rng.randf_range(-.035, .035),
				(float(zs[i]) + offsets[i].y) * bevel) * size)
		levels.append(ring)
	for layer in range(3):
		var sk0 := 1.0 if layer == 0 else 0.0
		var sk1 := 1.0 if layer + 1 == 0 else 0.0
		var curv0 := 0.78 if layer >= 2 else 0.48
		var curv1 := 0.85 if layer + 1 >= 2 else 0.52
		for i in range(8):
			var next := (i + 1) % 8
			var pts := [levels[layer][i], levels[layer][next], levels[layer + 1][next],
				levels[layer][i], levels[layer + 1][next], levels[layer + 1][i]]
			var cols := [Color(curv0, 0.5, 0.5, sk0), Color(curv0, 0.5, 0.5, sk0), Color(curv1, 0.7, 0.5, sk1),
				Color(curv0, 0.5, 0.5, sk0), Color(curv1, 0.7, 0.5, sk1), Color(curv1, 0.7, 0.5, sk1)]
			for k in range(6):
				geometry.set_color(cols[k])
				geometry.add_vertex(pts[k])
	for i in range(1, 7):
		geometry.set_color(Color(0.82, 0.9, 0.5, 0.0))
		geometry.add_vertex(levels[3][0])
		geometry.add_vertex(levels[3][i])
		geometry.add_vertex(levels[3][i + 1])
	geometry.generate_normals()
	return _mesh(geometry.commit(), foundation, origin)


func _forecourt() -> void:
	var tools := RandomNumberGenerator.new()
	tools.seed = 14619
	for tier in range(2):
		var z := -.4 if tier == 0 else 2.2
		var last := 12.7 if tier == 0 else 10.6
		while z < last:
			var span := tools.randf_range(.68, 1.66)
			var next := minf(z + span, last)
			var first := Vector2(_terrace_line(z) - 2.1 * tier, z)
			var second := Vector2(_terrace_line(next) - 2.1 * tier, next)
			var point := (first + second) * .5
			var height := tools.randf_range(.34, .53)
			var bearing := atan2(-(second - first).y, (second - first).x)
			if tools.randf() > .11 and span > .34:
				var wall := _worn_block(Vector3(point.x, _height(point + Vector2(.16, 0)) + height * .19, point.y),
					Vector3(span * .97, height, .66 if tier == 0 else .54), .13, tools)
				wall.rotation.y = bearing + tools.randf_range(-.07, .08)
				wall.material_override = foundation if tools.randf() > .27 else boulder_mossy
				if tools.randf() > .28:
					var cap := _worn_block(wall.position + Vector3(0, height * .48, 0),
						Vector3(span * .92, .136, .77), .11, tools)
					cap.rotation.y = wall.rotation.y
					cap.material_override = limestone if tools.randf() < .55 else foundation
			z = next

	var rill := [
		Vector2(-9.16, 4.19), Vector2(-9.38, 5.17), Vector2(-9.79, 5.57),
		Vector2(-10.09, 6.11), Vector2(-10.24, 7.18),
	]
	var clear_rill := StandardMaterial3D.new()
	clear_rill.albedo_color = Color("36a8a2")
	clear_rill.roughness = 0.08
	clear_rill.emission_enabled = true
	clear_rill.emission = Color("287d82")
	clear_rill.emission_energy_multiplier = 0.25
	for index in range(rill.size() - 1):
		_rill_section(rill[index], rill[index + 1], foundation, clear_rill, tools)
	_meter(Vector2(-9.16, 3.23), foundation, boulder_mossy, clear_rill, tools)
	var terminal := rill[-1] as Vector2
	var terminal_base := Vector3(terminal.x, _height(terminal), terminal.y + .30)
	var base_plinth := _worn_block(terminal_base + Vector3(0, .04, 0), Vector3(1.58, .24, 1.23), .12, tools)
	base_plinth.material_override = boulder_mossy
	_box(terminal_base + Vector3(0, .18, .09), Vector3(1.13, .035, .76), clear_rill)
	for bank: float in [-1., 1.]:
		_box(terminal_base + Vector3(bank * .65, .20, .10), Vector3(.16, .22, .89), limestone)
	_box(terminal_base + Vector3(0, .21, .56), Vector3(1.35, .20, .17), foundation)


func _rill_section(first: Vector2, second: Vector2, stone: Material, water: Material, tools: RandomNumberGenerator) -> void:
	var difference := second - first
	var normal := Vector2(-difference.y, difference.x).normalized()
	var yaw := atan2(-difference.y, difference.x)
	var channels := PackedVector3Array()
	for p: Vector2 in [first - normal * .16, second - normal * .16,
		second + normal * .16, first + normal * .16]:
		channels.append(Vector3(p.x, _height(p) + .034, p.y))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [channels[0], channels[1], channels[2], channels[0], channels[2], channels[3]]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)
	_mesh(surface.commit(), water, Vector3.ZERO)
	var center := (first + second) * .5
	for side: float in [-1.0, 1.0]:
		var pick := center + normal * side * .255
		var curb := _worn_block(Vector3(pick.x, _height(pick) + .071, pick.y),
			Vector3(difference.length() + .046, .21, .22), .075, tools)
		curb.rotation.y = yaw
		curb.material_override = stone


func _meter(point: Vector2, stone: Material, damp: Material, water: Material, tools: RandomNumberGenerator) -> void:
	var base := Vector3(point.x, _height(point), point.y)
	var inset := _worn_block(base + Vector3(0, -.07, 0), Vector3(3.02, .42, 2.12), .09, tools)
	inset.material_override = damp
	var plinth := _worn_block(base + Vector3(0, .19, 0), Vector3(2.72, .25, 1.88), .06, tools)
	plinth.material_override = stone
	_box(base + Vector3(0, .345, .36), Vector3(1.80, .05, 1.02), water)
	for side: float in [-1., 1.]:
		_box(base + Vector3(side * .96, .37, .34), Vector3(.15, .18, 1.07), limestone)
		_box(base + Vector3(side * .61, .38, .93), Vector3(.62, .17, .14), stone)
	for side: float in [-1., 1.]:
		var position := base + Vector3(side * .76, .315, -.44)
		_box(position + Vector3(0, .11, 0), Vector3(.57, .23, .60), stone)
		_cylinder(position + Vector3(0, .73, 0), .136, .212, 1.06, limestone, 12)
		_box(position + Vector3(0, 1.31, 0), Vector3(.45, .19, .52), limestone)
		_box(position + Vector3(0, 1.40, 0), Vector3(.37, .082, .46), jade)
	var curve := base + Vector3(0, 1.59, -.44)
	for i in range(9):
		var theta := PI * (float(i) + .50) / 9.0
		var block := _worn_block(curve + Vector3(.77 * cos(theta), .52 * sin(theta), 0),
			Vector3(.33, .26, .43), .054, tools)
		block.rotation.z = atan2(.52 * cos(theta), -.77 * sin(theta))
		block.material_override = limestone if i % 4 != 2 else stone
	_box(base + Vector3(0, 1.52, -.23), Vector3(.128, .57, .086), copper)
	_box(base + Vector3(0, .86, -.23), Vector3(.49, .41, .145), jade)
	for level in range(5):
		_box(base + Vector3(.09, .72 + float(level) * .059, -.139), Vector3(.127, .012, .018), copper)
	_taper(base + Vector3(.06, .91, -.125), base + Vector3(-.142, .85, -.125), .021, .009, copper)
	_collision(base + Vector3(0, .63, -.24), Vector3(2.65, 1.40, 1.46))


func _lower_orchard() -> void:
	var local := RandomNumberGenerator.new()
	local.seed = 463918
	var borders := [
		[Vector2(-17.88, 4.1), Vector2(-17.11, 6.3), Vector2(-16.36, 7.86), Vector2(-15.5, 8.85),
			Vector2(-14.2, 9.71), Vector2(-12.66, 9.85), Vector2(-11.40, 9.25)],
		[Vector2(-21.4, 5.3), Vector2(-19.6, 8.3), Vector2(-18.05, 10.30), Vector2(-16.72, 11.55),
			Vector2(-14.87, 12.76), Vector2(-12.87, 13.24), Vector2(-10.8, 12.79), Vector2(-9.45, 12.05)],
		[Vector2(-20.60, 10.15), Vector2(-19.10, 12.1), Vector2(-16.97, 13.82), Vector2(-14.9, 15.22),
			Vector2(-13.12, 15.62), Vector2(-11.34, 15.41), Vector2(-10.20, 14.67)],
	]
	var sod := _flora_mat(Color("2b612e"), Color("78b83d"))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for tier in range(borders.size()):
		var border: Array = borders[tier]
		for section in range(border.size() - 1):
			var first: Vector2 = border[section]
			var second: Vector2 = border[section + 1]
			var axis := (second - first).normalized()
			var facing := Vector2(axis.y, -axis.x)
			var bearing := atan2(-axis.y, axis.x)
			var count := maxi(2, roundi(first.distance_to(second) / .78))
			var span := first.distance_to(second) / float(count)
			for block in range(count):
				var p := first.lerp(second, (block + .5) / count)
				var path := _path_distance(p, ORCHARD_BRANCH)
				if path < .91 or _road_dist(p) < 2.0:
					continue
				var y := _height(p)
				var height := local.randf_range(.36, .65) * (1.19 if tier == 1 else .91)
				var center := Vector3(p.x, y, p.y)
				var base := _worn_block(center + Vector3.UP * height * .20, Vector3(span + .06, height, .83), .10, local)
				base.material_override = boulder_mossy if (section + block * 2) % 4 == 1 else foundation
				base.rotation.y = bearing + local.randf_range(-.045, .045)
				var cap_at := p + facing * .066
				var cap := _worn_block(Vector3(cap_at.x, y + height * .79, cap_at.y), Vector3(span * .98, .18, .99), .07, local)
				cap.material_override = limestone if (section + block) % 4 != 0 else foundation
				cap.rotation.y = base.rotation.y
				if block == 0 and tier != 2:
					_collision(center + Vector3.UP * .16, Vector3(.68, .49, .66))
				if (section + block * 3) % 4 == 1:
					var foot := p + facing * .64
					var h := local.randf_range(.48, .85)
					for k in range(3):
						var spot := foot + axis * local.randf_range(-.38, .38) + facing * local.randf_range(-.12, .28)
						if _path_distance(spot, ORCHARD_BRANCH) < .76:
							continue
						var tuft := _mesh(quad, sod, Vector3(spot.x, _height(spot) + h * .38, spot.y))
						tuft.rotation = Vector3(deg_to_rad(12.0), local.randf_range(-PI, PI), 0.0)
						tuft.scale = Vector3(h * 1.25, h, 1)
						tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for entry: Array in [[Vector2(-15.73, 6.03), 3.24, 2], [Vector2(-17.24, 9.55), 3.88, 1],
		[Vector2(-18.68, 7.44), 3.66, 0], [Vector2(-19.3, 10.4), 3.12, 0],
		[Vector2(-14.42, 14.19), 3.76, 1], [Vector2(-12.72, 14.21), 3.38, 2],
		[Vector2(-9.62, 12.36), 3.25, 0]]:
		var point: Vector2 = entry[0]
		_tree(Vector3(point.x, _height(point), point.y), entry[1], entry[2])
	_orchard_stones(local, limestone)


func _orchard_stones(local: RandomNumberGenerator, cap: Material) -> void:
	for segment in range(ORCHARD_BRANCH.size() - 1):
		var from: Vector2 = ORCHARD_BRANCH[segment]
		var to: Vector2 = ORCHARD_BRANCH[segment + 1]
		var direction := (to - from).normalized()
		var facing := Vector2(-direction.y, direction.x)
		var joints := maxi(2, roundi(from.distance_to(to) / .84))
		for i in range(joints):
			if (segment + i) % 5 == 2:
				continue
			var p := from.lerp(to, (i + .5) / joints) + facing * local.randf_range(-.31, .31)
			var stone := _worn_block(Vector3(p.x, _height(p) - .018, p.y), Vector3(.58, .088, .81), .16, local)
			stone.rotation.y = atan2(-direction.y, direction.x) + local.randf_range(-.23, .23)
			stone.material_override = cap
	var turn := Vector2(-.35, 9.2)
	var ward := Vector2(-1.35, 1.5)
	for _index in range(35):
		var at := turn.lerp(ward, local.randf())
		at.x += local.randf_range(-3.02, -.74)
		at.y += local.randf_range(-.45, .56)
		if _road_dist(at) > 3.01:
			continue
		var stone := _worn_block(Vector3(at.x, _height(at) - .025, at.y),
			Vector3(local.randf_range(.40, .69), .080, local.randf_range(.29, .72)), .16, local)
		stone.rotation.y = local.randf_range(-.29, .64)
		stone.material_override = cap


func _garden_bench(p: Vector2) -> void:
	var y := _height(p)
	_box(Vector3(p.x, y + .35, p.y), Vector3(1.54, .15, .54), limestone)
	for sign_x in [-1.0, 1.0]:
		_box(Vector3(p.x + sign_x * .53, y + .12, p.y), Vector3(.24, .42, .39), foundation)


func _column(at: Vector3, height: float) -> void:
	_box(at + Vector3(0, .12, 0), Vector3(.82, .26, .82), foundation)
	_cylinder(at + Vector3(0, height * .47, 0), .28, .34, height * .87, limestone, 14)
	_box(at + Vector3(0, height, 0), Vector3(.67, .17, .67), limestone)
	_cylinder(at + Vector3(0, height + .15, 0), .20, .29, .16, jade, 12)


func _brazier(p: Vector2) -> void:
	var y := _paving_stage_height(p)
	var at := Vector3(p.x, y, p.y)
	_column(at, .79)
	_cylinder(at + Vector3(0, .96, 0), .30, .19, .17, copper, 12)
	_cylinder(at + Vector3(0, 1.065, 0), .28, .30, .072, jade, 12)
	_cylinder(at + Vector3(0, 1.40, 0), .12, .30, .13, jade, 12)
	_cylinder(at + Vector3(0, 1.335, 0), .30, .30, .041, copper, 12)
	_cylinder(at + Vector3(0, 1.491, 0), .056, .12, .078, copper, 12)

	var core := StandardMaterial3D.new()
	core.albedo_color = Color("fff2c9")
	core.roughness = 0.20
	core.emission_enabled = true
	core.emission = Color("ffd478")
	core.emission_energy_multiplier = 2.10
	_cylinder(at + Vector3(0, 1.212, 0), .138, .112, .23, core, 12)

	# Delicate warm golden lantern kiss
	var warm_lamp := OmniLight3D.new()
	warm_lamp.position = at + Vector3(0, 1.26, 0)
	warm_lamp.light_color = Color("ffd896")
	warm_lamp.light_energy = 0.42
	warm_lamp.omni_range = 4.2
	warm_lamp.omni_attenuation = 1.75
	warm_lamp.shadow_enabled = false
	add_child(warm_lamp)

	for angle in range(8):
		var d := TAU * angle / 8.0
		var rim := Vector3(cos(d) * .252, 0.0, sin(d) * .252)
		_taper(at + rim + Vector3.UP * 1.075, at + rim * .95 + Vector3.UP * 1.34, .018, .018, copper)
		if angle % 2 == 0:
			var panel := _box(at + rim * 1.05 + Vector3.UP * 1.15, Vector3(.10, .057, .024), jade)
			panel.rotation.y = PI * .50 - d


func _boulder_groups() -> void:
	if sculpted_boulders.is_empty():
		return
	var rocks := [
		[Vector2(-13.3, -6.9), Vector3(1.5, 1.15, 1.6), 0],
		[Vector2(-14.7, -7.0), Vector3(1.7, 2.0, 1.6), 1],
		[Vector2(-15.8, -10.4), Vector3(2.7, 2.6, 1.9), 2],
		[Vector2(-17.4, -8.1), Vector3(2.0, 2.4, 1.9), 1],
		[Vector2(-13.1, 6.5), Vector3(1.9, 1.4, 2.1), 2],
		[Vector2(-9.5, 9.0), Vector3(1.35, 0.9, 1.25), 0],
		[Vector2(17.9, 1.7), Vector3(1.9, 2.1, 1.7), 1],
		[Vector2(17.3, -8.9), Vector3(2.1, 1.45, 2.0), 0],
		[Vector2(19.8, -8.1), Vector3(1.75, 2.4, 1.9), 1],
		[Vector2(20.1, -11.4), Vector3(2.6, 3.0, 2.1), 2],
		[Vector2(12.2, -10.0), Vector3(1.1, 0.65, 0.95), 3],
		[Vector2(5.3, -7.25), Vector3(0.95, 0.58, 1.05), 3],
	]
	for i in range(rocks.size()):
		var entry: Array = rocks[i]
		var point: Vector2 = entry[0]
		var dims: Vector3 = entry[1]
		var b_idx: int = int(entry[2]) % sculpted_boulders.size()
		var mat := boulder_mossy if i % 2 == 0 else boulder_warm
		var piece := _mesh(sculpted_boulders[b_idx], mat, Vector3(point.x, _height(point) - 0.08, point.y))
		piece.scale = dims
		piece.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08))

	for _i in range(95):
		var a := rng.randf() * TAU
		var p := POND + Vector2(cos(a), sin(a)) * POND_RADIUS * rng.randf_range(.94, 1.12)
		if _road_dist(p) < 1.75:
			continue
		var size := rng.randf_range(.32, .78)
		var b_mesh: Mesh = sculpted_boulders[3 % sculpted_boulders.size()]
		var small := _mesh(b_mesh, boulder_warm if _i % 3 != 0 else boulder_mossy, Vector3(p.x, _height(p) - 0.04, p.y))
		small.scale = Vector3(size * 1.15, size * 0.72, size)
		small.rotation.y = a


func _trees() -> void:
	var locations := [
		[Vector2(-9.8, 8.4), 5.0, 0], [Vector2(-12.8, 3.2), 5.6, 0],
		[Vector2(-11.2, -2.5), 5.6, 1], [Vector2(-6.35, 5.15), 4.25, 1],
		[Vector2(-16.5, -3.4), 6.8, 0], [Vector2(-14.9, -13.9), 5.8, 1, .35],
		[Vector2(-6.2, -16), 5.0, 0], [Vector2(1.9, -16.25), 4.7, 2, .38],
		[Vector2(9.9, 12.8), 4.2, 2], [Vector2(13.0, 10.6), 4.1, 0],
		[Vector2(15.2, 7.7), 6.5, 0], [Vector2(18.0, -1.35), 4.8, 2, .61],
		[Vector2(18.56, -15.13), 5.6, 0, .32], [Vector2(11.5, -16.0), 5.5, 0, .21],
		[Vector2(21.5, -12), 6.8, 0], [Vector2(20.0, .6), 6.6, 0],
	]
	for entry in locations:
		var p: Vector2 = entry[0]
		var exposed := float(entry[3]) if entry.size() > 3 else .0
		_tree(Vector3(p.x, _height(p), p.y), entry[1], entry[2], exposed)
	for _i in range(19):
		var p := Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(-29.0, -19.5))
		if p.x > -9.5 and p.x < 5.3:
			continue
		if p.x > 5.3 and p.x < 18.5:
			p.x = lerpf(p.x, 18.5, .43)
			p.y -= 1.6
		_tree(Vector3(p.x, _height(p), p.y), rng.randf_range(2.6, 4.8), 0, .81)


func _sculpted_limb(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, h0: float, h1: float, segs := 10) -> void:
	"""Smooth continuous lofted tube for organic S-curved tree trunks, flared buttress roots, and boughs."""
	var rings: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	for idx in range(pts.size()):
		var p := pts[idx]
		var tang: Vector3
		if idx == 0:
			tang = (pts[1] - pts[0]).normalized()
		elif idx == pts.size() - 1:
			tang = (pts[idx] - pts[idx - 1]).normalized()
		else:
			tang = (pts[idx + 1] - pts[idx - 1]).normalized()
		var ref := Vector3.FORWARD if absf(tang.y) > 0.92 else Vector3.UP
		var bx := tang.cross(ref).normalized()
		var bz := bx.cross(tang).normalized()
		var ring := PackedVector3Array()
		var r_norms := PackedVector3Array()
		var rad := radii[idx]
		for s in range(segs):
			var ang := TAU * float(s) / float(segs)
			# Subtle organic root/bark fluting near base
			var flute := 1.0 + (0.14 * (1.0 - float(idx) / maxf(1.0, float(pts.size() - 1)))) * cos(ang * 4.0)
			var dir := bx * cos(ang) + bz * sin(ang)
			ring.append(p + dir * (rad * flute))
			r_norms.append(dir)
		rings.append(ring)
		norms.append(r_norms)

	for idx in range(rings.size() - 1):
		var v0 := lerpf(h0, h1, float(idx) / float(rings.size() - 1))
		var v1 := lerpf(h0, h1, float(idx + 1) / float(rings.size() - 1))
		for s in range(segs):
			var nxt := (s + 1) % segs
			var quad_p := [rings[idx][s], rings[idx][nxt], rings[idx + 1][nxt],
				rings[idx][s], rings[idx + 1][nxt], rings[idx + 1][s]]
			var quad_n := [norms[idx][s], norms[idx][nxt], norms[idx + 1][nxt],
				norms[idx][s], norms[idx + 1][nxt], norms[idx + 1][s]]
			var quad_h := [v0, v0, v1, v0, v1, v1]
			for k in range(6):
				st.set_color(Color(0.5, quad_h[k], 0.5, 1.0))
				st.set_normal(quad_n[k])
				st.add_vertex(quad_p[k])


func _tree(at: Vector3, height: float, species: int, exposed := .0) -> void:
	var wind := Vector3(cos(at.x * .18 + .8), 0, sin(at.x * .18 + .8))
	wind = wind.lerp(Vector3(.85, 0, -.53), exposed * .84).normalized()
	var across := Vector3(-wind.z, 0, wind.x)
	var windlean: float = float([.15, .20, .09][species]) + exposed * .12

	var base := at - Vector3(0, 0.10, 0)
	var p1 := at + Vector3.UP * height * 0.24 - wind * height * 0.03
	var p2 := at + Vector3.UP * height * 0.48 - wind * height * 0.045 + across * height * 0.025
	var p3 := at + Vector3.UP * height * 0.72 + across * height * 0.05 + wind * height * (windlean * 0.45)
	var top := at + Vector3.UP * height * 0.92 + wind * height * windlean

	var trunk_st := SurfaceTool.new()
	trunk_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sculpted_limb(trunk_st,
		PackedVector3Array([base, p1, p2, p3, top]),
		PackedFloat32Array([height * 0.068, height * 0.046, height * 0.034, height * 0.022, height * 0.008]),
		0.0, 1.0, 12)

	var close := at.z > -18.5
	if close:
		for root_index in range(4):
			var root_angle := TAU * root_index / 4.0 + at.x * .4
			var rdir := Vector3(cos(root_angle), 0, sin(root_angle))
			var foot := at + rdir * height * (.14 + .02 * (root_index % 2))
			foot.y = _height(Vector2(foot.x, foot.z)) - 0.09
			var mid_root := at.lerp(foot, 0.48) + Vector3.UP * height * 0.055
			_sculpted_limb(trunk_st,
				PackedVector3Array([foot, mid_root, at + Vector3.UP * height * 0.16]),
				PackedFloat32Array([height * 0.008, height * 0.024, height * 0.042]),
				0.0, 0.25, 8)

	var puff_mesh: ArrayMesh = puff_meshes[species]
	var canopy_mat: ShaderMaterial = canopy_mats[species]
	var silhouette: Vector3 = [Vector3(1.12, .52, .90), Vector3(.88, .68, .86), Vector3(.74, .92, .72)][species]
	var branches: Array = [
		[[-.30, .68, .16], [-.15, .84, -.28], [.34, .92, -.16], [.46, .76, .14], [.12, 1.10, .08], [.12, .94, .36]],
		[[-.38, .78, .22], [-.16, .66, -.30], [.28, 1.02, -.24], [.42, .82, .22], [.12, 1.08, .08], [.24, .72, -.36]],
		[[-.22, .68, .12], [-.13, .85, -.24], [.19, 1.10, -.10], [.26, .78, .20], [.12, 1.22, .05], [.11, .94, .25]],
	][species]

	for i in range(branches.size()):
		var design := Vector3(branches[i][0], branches[i][1], branches[i][2])
		var reach := rng.randf_range(.92, 1.14)
		var rise := rng.randf_range(-.045, .045)
		var cut := rng.randf_range(.15, .62)
		var size := height * rng.randf_range(.40, .52)
		var direction := wind * (design.x + exposed * .08) + across * design.z
		var tip := at + Vector3.UP * height * (design.y + rise) + direction * height * reach
		var root := p2.lerp(p3, cut if i < 4 else .82)
		var fork := root.lerp(tip, .54) - Vector3.UP * height * (.030 if species == 1 else .015)
		var bearing := atan2(direction.x, direction.z)
		if exposed > .65 and i in [1, 5]:
			continue
		_sculpted_limb(trunk_st,
			PackedVector3Array([root, fork, tip]),
			PackedFloat32Array([height * (.020 if i < 4 else .014), height * .011, height * .004]),
			0.55, 1.0, 7)

		var puff := _mesh(puff_mesh, canopy_mat, tip + Vector3.UP * size * .08)
		puff.scale = silhouette * size * (1.14 if i == 2 else .90 if i == 5 else 1.0)
		puff.scale *= Vector3(1.0 + exposed * .15, 1.0 - exposed * .14, 1.0 - exposed * .18)
		puff.rotation_degrees = Vector3(10.0 if i % 2 == 0 else -8.0, rad_to_deg(bearing), (-1.0 if i % 2 == 0 else 1.0) * (12.0 if species == 1 else 6.0))
		puff.set_instance_shader_parameter("exposure", exposed)

		if close:
			var outward := direction.normalized()
			var split := tip + ((outward + across * (.36 if i % 2 == 0 else -.42)).normalized() + Vector3.DOWN * (.36 if species == 1 else .24)) * size * .54
			_sculpted_limb(trunk_st,
				PackedVector3Array([fork, split]),
				PackedFloat32Array([height * .008, height * .003]),
				0.75, 1.0, 6)
			var sat := _mesh(puff_mesh, canopy_mat, split)
			sat.scale = silhouette * size * Vector3(.62, .64, .65)
			sat.rotation = puff.rotation + Vector3(.16, .45, -.10)
			sat.set_instance_shader_parameter("exposure", exposed)

	_mesh(trunk_st.commit(), bark_mat, Vector3.ZERO)
	if _road_dist(Vector2(at.x, at.z)) > 1.55 and at.y < .95:
		_collision(at + Vector3(.10, .78, 0), Vector3(height * .120, 1.7, height * .120))


func _flora_mat(base_col: Color, tip_col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SUN_FLORA
	m.set_shader_parameter("plant_atlas", FOLIAGE_CARDS)
	m.set_shader_parameter("quadrant", Vector2(1.0, 1.0))
	m.set_shader_parameter("base_tint", base_col)
	m.set_shader_parameter("tip_tint", tip_col)
	return m


func _understory() -> void:
	var lush_bush := _flora_mat(Color("23572a"), Color("6fb53c"))
	var warm_bush := _flora_mat(Color("35692c"), Color("94cc44"))
	var card := QuadMesh.new()
	card.size = Vector2.ONE
	var clusters := [
		Vector2(-4, 10.8), Vector2(-2.2, 7.7), Vector2(-4.2, 3.25), Vector2(-5.5, 3.4),
		Vector2(-8.1, .8), Vector2(-4.8, -4.2), Vector2(-10.45, -5), Vector2(-6.3, -6),
		Vector2(-2.9, -10.8), Vector2(-5.5, -13.3), Vector2(2.9, -14.9), Vector2(0.8, -11.8),
		Vector2(1.9, -5), Vector2(3.1, .9), Vector2(5.2, 5.5), Vector2(8.9, 7.75),
		Vector2(13, 6.5), Vector2(14, 2.3), Vector2(15.3, -2.05), Vector2(13.3, -6.9),
		Vector2(9.8, -10), Vector2(12.25, -14.6), Vector2(17.4, -10.4), Vector2(-10.9, 13.9),
	]
	for index in range(clusters.size()):
		for i in range(6):
			var p: Vector2 = clusters[index] + _jitter(1.55)
			if _road_dist(p) < 1.48 or _pond_math(p) < 1.02:
				continue
			var height := rng.randf_range(.36, .78)
			var bearing := rng.randf() * TAU
			var material := warm_bush if (i + index) % 3 == 0 else lush_bush
			for k in range(3):
				var plant := _mesh(card, material, Vector3(p.x, _height(p) + height * .42, p.y))
				plant.scale = Vector3(height * 1.22, height, 1.0)
				plant.rotation = Vector3(deg_to_rad(14.0), bearing + float(k) * TAU / 3.0, 0.0)
				plant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_genshin_grass_sea()


func _genshin_grass_clump_mesh(variant: int) -> ArrayMesh:
	"""3-segment curved, soft alpine meadow grass cluster (7 blades per clump) with UV.y = 0..1."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var local := RandomNumberGenerator.new()
	local.seed = 8800 + variant * 131
	var blades := 7
	for b in range(blades):
		var ang := (float(b) / float(blades)) * TAU + local.randf_range(-0.35, 0.35)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side_dir := Vector3(-dir.z, 0.0, dir.x)
		var offset := dir * local.randf_range(0.03, 0.20)
		var h := local.randf_range(0.18, 0.34) * (1.24 if variant == 2 else 1.0)
		var arch := local.randf_range(0.28, 0.56) * h
		var w0 := local.randf_range(0.036, 0.052)
		var v_rand := local.randf()

		var p0 := offset
		var p1 := offset + dir * (arch * 0.42) + Vector3.UP * (h * 0.54)
		var p2 := offset + dir * arch + Vector3.UP * h
		var s0 := side_dir * w0
		var s1 := side_dir * (w0 * 0.62)

		var seg_tris := [
			[p0 - s0, p0 + s0, p1 + s1, 0.0, 0.0, 0.52],
			[p0 - s0, p1 + s1, p1 - s1, 0.0, 0.52, 0.52],
			[p1 - s1, p1 + s1, p2, 0.52, 0.52, 1.0],
		]
		for tri in seg_tris:
			for k in range(3):
				st.set_color(Color(v_rand, 0.0, 0.0, 1.0))
				st.set_uv(Vector2(0.5, tri[k + 3]))
				st.set_normal(Vector3.UP)
				st.add_vertex(tri[k])
	return st.commit()


func _genshin_grass_sea() -> void:
	"""Spatial-chunked MultiMesh grass carpet (~16,000 7-blade clumps = ~112,000 terrain-matched blades!)."""
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = MEADOW_GRASS
	var clump_meshes: Array[ArrayMesh] = [
		_genshin_grass_clump_mesh(0),
		_genshin_grass_clump_mesh(1),
		_genshin_grass_clump_mesh(2),
	]

	var local := RandomNumberGenerator.new()
	local.seed = 50291
	var x_min := -30.0
	var x_max := 29.0
	var z_min := -26.5
	var z_max := 19.5
	var gx := 4
	var gz := 3
	var step_x := (x_max - x_min) / float(gx)
	var step_z := (z_max - z_min) / float(gz)

	for cx in range(gx):
		for cz in range(gz):
			var buckets: Array = [[], [], []]
			var bx0 := x_min + float(cx) * step_x
			var bz0 := z_min + float(cz) * step_z
			for _n in range(2500):
				var p := Vector2(local.randf_range(bx0, bx0 + step_x), local.randf_range(bz0, bz0 + step_z))
				var r_dist := _road_dist(p)
				var o_dist := _path_distance(p, ORCHARD_BRANCH)
				var p_math := _pond_math(p)
				if r_dist < 1.35 or o_dist < 0.85 or p_math < 1.02:
					continue
				if (p - Vector2(ORRERY_POSITION.x, ORRERY_POSITION.z)).length() < 3.55:
					continue
				var density_n := hills.get_noise_2dv(p * 1.85)
				var border_taper := smoothstep(1.35, 2.45, r_dist) * smoothstep(0.85, 1.55, o_dist)
				var sc := local.randf_range(0.76, 1.28) * (0.45 + 0.58 * border_taper) * (0.86 + 0.22 * maxf(0.0, density_n))
				var variant := 2 if (density_n > 0.20 and border_taper > 0.65) else (0 if local.randf() < 0.55 else 1)
				var basis := Basis.from_euler(Vector3(0.0, local.randf() * TAU, 0.0)).scaled(Vector3(sc, sc, sc))
				(buckets[variant] as Array).append(Transform3D(basis, Vector3(p.x, _height(p) - 0.02, p.y)))

			for v in range(3):
				var xforms: Array = buckets[v]
				if xforms.is_empty():
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = clump_meshes[v]
				mm.instance_count = xforms.size()
				for idx in range(xforms.size()):
					mm.set_instance_transform(idx, xforms[idx])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = grass_mat
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mmi)


func _wildflower_mesh() -> ArrayMesh:
	"""Delicate 5-petal cupped Genshin Cecilia / Windwheel wildflower with golden center."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var petals := 5
	for p in range(petals):
		var a := float(p) * TAU / float(petals)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * 0.048
		var mid := dir * 0.075 + Vector3.UP * 0.022
		var tip := dir * 0.155 + Vector3.UP * 0.052
		var n := (Vector3.UP + dir * 0.32).normalized()
		for tri in [[Vector3.ZERO, mid + side, tip], [Vector3.ZERO, tip, mid - side]]:
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


func _garden_flowers() -> void:
	var targets := [
		Vector2(-3.84, 8.1), Vector2(-3.45, 4.94), Vector2(-6.19, 1.97),
		Vector2(-5.22, -4.43), Vector2(-3.3, -9.9), Vector2(-5.06, -7.08),
		Vector2(1.63, 6.15), Vector2(2.14, .44), Vector2(2.50, -4.22), Vector2(2.33, -9.77),
		Vector2(5.6, -14.1), Vector2(9.32, -11.04), Vector2(15.05, -4.0),
		Vector2(-9.8, 6.8), Vector2(5.45, 6.7), Vector2(4.32, 4.05),
		Vector2(-2.6, 9.6), Vector2(2.6, 8.4),
	]
	var fl_mesh := _wildflower_mesh()
	var stem_mat := _solid(Color("3f7032"), 0.85)
	var cecilia := StandardMaterial3D.new()
	cecilia.cull_mode = BaseMaterial3D.CULL_DISABLED
	cecilia.albedo_color = Color("fffdf6")
	cecilia.roughness = 0.62
	cecilia.emission_enabled = true
	cecilia.emission = Color("fff4d4")
	cecilia.emission_energy_multiplier = 0.22

	var sakura_pink := StandardMaterial3D.new()
	sakura_pink.cull_mode = BaseMaterial3D.CULL_DISABLED
	sakura_pink.albedo_color = Color("ffc0cb")
	sakura_pink.roughness = 0.62
	sakura_pink.emission_enabled = true
	sakura_pink.emission = Color("ffa8b8")
	sakura_pink.emission_energy_multiplier = 0.16

	var glaze_blue := StandardMaterial3D.new()
	glaze_blue.cull_mode = BaseMaterial3D.CULL_DISABLED
	glaze_blue.albedo_color = Color("a8dfff")
	glaze_blue.roughness = 0.60
	glaze_blue.emission_enabled = true
	glaze_blue.emission = Color("86ceff")
	glaze_blue.emission_energy_multiplier = 0.22

	var fl_mats: Array[Material] = [cecilia, sakura_pink, glaze_blue]
	for bed in range(targets.size()):
		var mat: Material = fl_mats[bed % 3]
		for _index in range(12):
			var p: Vector2 = targets[bed] + _jitter(.92)
			if _road_dist(p) < 1.48 or _pond_math(p) < 1.04:
				continue
			var at := Vector3(p.x, _height(p), p.y)
			# Stand cleanly above the 0.28m alpine meadow grass!
			var h := rng.randf_range(.34, .54)
			var top := at + Vector3(rng.randf_range(-0.04, 0.04), h, rng.randf_range(-0.04, 0.04))
			_taper(at, top, 0.011, 0.006, stem_mat)
			var fl := _mesh(fl_mesh, mat, top)
			fl.rotation = Vector3(rng.randf_range(-0.20, 0.20), rng.randf() * TAU, rng.randf_range(-0.20, 0.20))
			fl.scale = Vector3.ONE * rng.randf_range(0.95, 1.42)
			fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _solid(tint: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _taper(from: Vector3, to: Vector3, lower: float, upper: float, material: Material) -> void:
	var node := _cylinder((from + to) / 2., upper, lower, from.distance_to(to), material, 10)
	node.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


func _cylinder(at: Vector3, top: float, bottom: float, height: float, material: Material, segments: int) -> MeshInstance3D:
	var geometry := CylinderMesh.new()
	geometry.radial_segments = segments
	geometry.rings = 1
	geometry.top_radius = top
	geometry.bottom_radius = bottom
	geometry.height = height
	return _mesh(geometry, material, at)


func _box(at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = dimensions
	return _mesh(geometry, material, at)


func _collision(at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var geometry := BoxShape3D.new()
	geometry.size = dimensions
	var hit := CollisionShape3D.new()
	hit.shape = geometry
	body.add_child(hit)
	add_child(body)


func _mesh(geometry: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = geometry
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance


func _jitter(radius: float) -> Vector2:
	return Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))

extends Node3D

const STONE_MAP := preload("res://textures/painted_stone.png")
const FOLIAGE_MAP := preload("res://textures/painted_plants.png")
const STONE := preload("res://grove_r20_stone.gdshader")
const FOLIAGE := preload("res://painted_plants.gdshader")
const TERRAIN := preload("res://refine_grove_terrain.gdshader")
const POOL := preload("res://refine_grove_pool.gdshader")
const GROVE_SKY := preload("res://refine_grove_sky.gdshader")
const CANOPY := preload("res://refine_grove_canopy.gdshader")
const BARK := preload("res://refine_grove_bark.gdshader")
const FORGED_METAL := preload("res://refine_grove_metal.gdshader")
const STRATA := preload("res://refine_grove_strata.gdshader")
const GROUND_MAP := preload("res://textures/refinement_ground.png")
const POND_CENTER := Vector2(3.7, -2.6)
const POND_RADII := Vector2(7.1, 12.6)
const WATER_LEVEL := -0.72

var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var warm_stone: ShaderMaterial
var cold_stone: ShaderMaterial
var foundation_stone: ShaderMaterial
var bedrock_stone: ShaderMaterial
var wood: ShaderMaterial
var celadon: ShaderMaterial
var brass: ShaderMaterial
var nectar: StandardMaterial3D
var canopy_materials: Array[ShaderMaterial] = []
var canopy_palette: Array[Color] = []
var leaf_layer: ShaderMaterial
var ferns: Array[ShaderMaterial] = []


func route() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.8, 13.5), Vector2(-2.7, 7.3), Vector2(-5.0, 1.4),
		Vector2(-5.5, -5.1), Vector2(-4.0, -10.2), Vector2(-0.9, -13.4),
	])


func review_views() -> Array:
	return [
		[Vector3(-4.8, 3.7, 12.9), Vector3(1.15, 2.07, -6.0), 51.0],
		[Vector3(-5.2, 22.1, 19.0), Vector3(0.4, 0.45, -3.35), 48.0],
	]


func _ready() -> void:
	rng.seed = 298860
	noise.seed = 5101
	noise.frequency = 0.077
	warm_stone = _stone(Color("c6c7b4"), 4.6, 0.0)
	cold_stone = _stone(Color("b8c2ad"), 6.4, 1.0)
	foundation_stone = _strata_material(Color("a6a791"), Color("5c6852"), Color("738063"), .22, .63)
	bedrock_stone = _strata_material(Color("adae98"), Color("696559"), Color("7b8c62"), .61, .48)
	wood = ShaderMaterial.new()
	wood.shader = BARK
	celadon = _forged(Color("447870"), Color("5f927b"), Color("204e48"))
	brass = _forged(Color("a5743a"), Color("d4aa62"), Color("675135"))
	nectar = _surface(Color("cfebd7"), 0.25, 0.08)
	nectar.emission_enabled = true
	nectar.emission = Color("c5edba")
	nectar.emission_energy_multiplier = 0.37
	for hex in ["bd873d", "b96f35", "bd9649", "d7a250", "92a962", "518b6b", "3e776d", "6c9469"]:
		var foliage := ShaderMaterial.new()
		foliage.shader = CANOPY
		foliage.set_shader_parameter("foliage_atlas", load("res://textures/genshin_foliage_cards.png"))
		foliage.set_shader_parameter("tint", Color(hex))
		canopy_materials.append(foliage)
		canopy_palette.append(Color(hex).srgb_to_linear())
	leaf_layer = ShaderMaterial.new()
	leaf_layer.shader = CANOPY
	leaf_layer.set_shader_parameter("foliage_atlas", load("res://textures/genshin_foliage_cards.png"))
	leaf_layer.set_shader_parameter("using_vertex", 1.0)
	var cover_palettes := [Color("a9b58a"), Color("b3ab84"), Color("91a892")]
	var cells := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
	for i in cells.size():
		var plant := ShaderMaterial.new()
		plant.shader = FOLIAGE
		plant.set_shader_parameter("plant_atlas", FOLIAGE_MAP)
		plant.set_shader_parameter("quadrant", cells[i])
		plant.set_shader_parameter("foliage_tint", cover_palettes[i])
		ferns.append(plant)
	_build_light()
	_build_terrain()
	_build_water()
	_build_landmark()
	_build_stonework()
	_build_trail_trim()
	_build_grove()
	_build_bank_details()
	_build_shore_shale()
	var scenery_seed := rng.state
	_build_overflow_sill()
	_build_slope_outcrops()
	_build_pond_shelves()
	_build_trail_aprons()
	_build_escarpments()
	_build_sedge_cove()
	_build_slope_gardens()
	_build_garden_retaining_banks()
	preload("res://grove_r20_understory.gd").build(self)
	rng.state = scenery_seed


func _build_light() -> void:
	# R20: keep R19 sun direction and both review cameras for direct comparison.
	var env := Environment.new()
	var sky := Sky.new()
	var paint := ShaderMaterial.new()
	paint.shader = GROVE_SKY
	sky.sky_material = paint
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.55
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("b4d0dc")
	env.ambient_light_sky_contribution = .42
	env.ambient_light_energy = .58
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.02
	env.adjustment_saturation = 1.02
	# A near-identity RGB grading volume; never flatten the actual lighting.
	var slices: Array[Image] = []
	for z in range(16):
		var slice_image := Image.create(16, 16, false, Image.FORMAT_RGB8)
		for y in range(16):
			for x in range(16):
				var c := Color(float(x) / 15.0, float(y) / 15.0, float(z) / 15.0)
				var value := c.r * .2126 + c.g * .7152 + c.b * .0722
				var shadow := (1.0 - smoothstep(.05, .56, value)) * value
				c.g = clampf(c.g + shadow * .035, 0.0, 1.0)
				c.b = clampf(c.b + shadow * .065, 0.0, 1.0)
				slice_image.set_pixel(x, y, c)
		slices.append(slice_image)
	var lut := ImageTexture3D.new()
	if lut.create(Image.FORMAT_RGB8, 16, 16, 16, false, slices) == OK:
		env.adjustment_color_correction = lut
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = .13
	env.glow_bloom = .0
	env.glow_hdr_threshold = 1.18
	var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_enabled = forward_plus
	env.ssao_radius = 1.10
	env.ssao_intensity = .95
	env.ssr_enabled = forward_plus
	env.ssr_max_steps = 48
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 38.0
	env.fog_depth_end = 145.0
	env.fog_density = .55
	env.fog_light_color = Color("bdd9df")
	env.fog_sun_scatter = .12
	env.fog_aerial_perspective = .12
	env.fog_sky_affect = .03
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37, -57, 0)
	sun.light_color = Color("fff0d7")
	sun.light_energy = 1.32
	sun.light_angular_distance = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _route_distance(point: Vector2) -> float:
	var line := route()
	var nearest := 100.0
	for i in range(line.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, line[i], line[i + 1])
		nearest = minf(nearest, closest.distance_to(point))
	return nearest


func _pond_radius(point: Vector2) -> float:
	var radial := (point - POND_CENTER) / POND_RADII
	var bearing := radial.angle()
	var shore := 1.0 + .039 * sin(bearing * 4.0 - .81) + .021 * sin(bearing * 7.0 + 1.74)
	return radial.length() / shore


func _height(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var route_mix := smoothstep(1.9, 4.8, _route_distance(point))
	var pond := _pond_radius(point)
	var basin := (1.0 - smoothstep(.59, .93, pond)) * .83
	var shelf := (1.0 - smoothstep(.76, 1.12, pond)) * .99
	var cove := ((point - Vector2(8.25,4.9)).rotated(-.34) / Vector2(4.96,3.31)).length()
	var terrace := (1.0 - smoothstep(.23,1.0,cove)) * 1.51
	var west := noise.get_noise_2d(x * .61 - 17.0, z * .72)
	var side := smoothstep(6.2, 20.0, absf(x)) * (2.14 + west * 3.6)
	var ridge := smoothstep(16.0, 26.5, -z) * (6.7 + noise.get_noise_2d(x * 1.05, z) * 2.8)
	var rear := smoothstep(19.0, 31.0, z) * 2.0
	return (noise.get_noise_2d(x, z) * .71 - basin - shelf + terrace + side + ridge + rear) * route_mix


func _top(builder: SurfaceTool, x: float, z: float) -> void:
	var near := _route_distance(Vector2(x, z))
	var path_mask := 1.0 - smoothstep(1.10, 2.42, near + noise.get_noise_2d(x * 3.5, z * 3.1) * 0.58)
	var height := _height(x, z)
	var close_to_pond := 1.0 - smoothstep(.96, 1.10, _pond_radius(Vector2(x, z)))
	var above_water := maxf(0.0, height - WATER_LEVEL)
	var dampness := (1.0 - smoothstep(.08, .58, above_water)) * close_to_pond
	builder.set_color(Color(path_mask, smoothstep(-0.93, -0.23, height), dampness))
	builder.add_vertex(Vector3(x, height, z))


func _build_terrain() -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.61
	for iz in range(111):
		for ix in range(119):
			var x := -35.945 + ix * step
			var z := -37.0 + iz * step
			_top(builder, x, z)
			_top(builder, x + step, z)
			_top(builder, x + step, z + step)
			_top(builder, x, z)
			_top(builder, x + step, z + step)
			_top(builder, x, z + step)
	builder.index()
	builder.generate_normals()
	var mesh := builder.commit()
	var ground := ShaderMaterial.new()
	ground.shader = TERRAIN
	ground.set_shader_parameter("atlas", STONE_MAP)
	ground.set_shader_parameter("ground_sheet", GROUND_MAP)
	ground.set_shader_parameter("waterline", WATER_LEVEL)
	_place(mesh, ground, Vector3.ZERO)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	floor_body.add_child(shape)
	add_child(floor_body)


func _build_water() -> void:
	# Sample the same bed used for collision and visually intersect the actual slope.
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := .39
	var water_start := POND_CENTER - POND_RADII * 1.19
	var slices := Vector2i(ceil(POND_RADII.x*2.38/step), ceil(POND_RADII.y*2.38/step))
	for iz in slices.y:
		for ix in slices.x:
			var at := water_start + Vector2(ix, iz) * step
			var corners := [
				at, at + Vector2(step, 0), at + Vector2(step, step), at + Vector2(0, step),
			]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = corners[idx]
				var depth := clampf((WATER_LEVEL - _height(p.x, p.y)) / 1.08, 0.0, 1.0)
				builder.set_color(Color(depth, 0.0, 0.0))
				builder.add_vertex(Vector3(p.x, WATER_LEVEL, p.y))
	builder.index()
	builder.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = POOL
	material.render_priority = -2
	_place(builder.commit(), material, Vector3.ZERO)
	# Physical lily pads sit in quiet clusters by the shallow bank.
	for i in range(37):
		var x := rng.randf_range(0.7, 7.7)
		var z := rng.randf_range(-8.8, 4.1)
		if Vector2((x - 2.4) / 4.8, (z + 1.4) / 7.8).length() > 0.96:
			continue
		var pad := CylinderMesh.new()
		pad.height = 0.052
		pad.radial_segments = 11
		pad.top_radius = rng.randf_range(0.13, 0.31)
		pad.bottom_radius = pad.top_radius * 0.89
		var material_index := rng.randi_range(4,7)
		var lean := rng.randf_range(-8.0,8.0)
		if _height(x,z) < WATER_LEVEL - .07:
			var leaf := _place(pad,canopy_materials[material_index],Vector3(x,-.69,z))
			leaf.rotation_degrees.z = lean


func _build_shore_shale() -> void:
	var shoreline := 0
	for along: float in [-2.81, -2.48, -1.94, -1.38, -.96, -.09, .52, .71, 1.11, 1.91, 2.62, 3.07]:
		var outward := POND_RADII * Vector2(cos(along), sin(along))
		var inner := .58
		var outer := 1.19
		for i in range(8):
			var test := (inner + outer) * .5
			var p := POND_CENTER + outward * test
			if _height(p.x, p.y) < WATER_LEVEL:
				inner = test
			else:
				outer = test
		var bank := POND_CENTER + outward * outer
		var tangent := outward.orthogonal().normalized()
		shoreline += 1
		for i in range(3 + shoreline % 4):
			var at := bank + tangent * rng.randf_range(-.71, .88) + outward.normalized() * rng.randf_range(-.45, .39)
			if _route_distance(at) < 1.78:
				continue
			var bottom := _height(at.x, at.y)
			var radius := rng.randf_range(.115, .30) * (1.55 if i == 0 else 1.0)
			var piece := _cut_stone(Vector3(radius*1.40, radius * .47, radius * .69), .09)
			var surface := cold_stone if i % 2 else warm_stone
			var mesh := _place(piece, surface, Vector3(at.x, bottom + radius*.045, at.y))
			mesh.rotation.y = rng.randf_range(-2.3, 2.3)
			mesh.rotation.z = rng.randf_range(-.22, .26)


func _build_pond_shelves() -> void:
	var silt := _stone(Color("a9ab91"), 3.9, 0.0)
	var stained := _stone(Color("8b9d79"), 3.2, 0.0)
	silt.set_shader_parameter("micro_relief", .0051)
	stained.set_shader_parameter("micro_relief", .0051)
	# Recessed outcrops interrupt the eastern and northern banks where no wall was built.
	var breaks := [-1.67, -1.31, -.55, .42, .91, 1.42]
	for index in breaks.size():
		var angle: float = breaks[index]
		var heading := Vector2(cos(angle), sin(angle)) * POND_RADII
		var tangent := Vector2(-sin(angle),cos(angle)) * POND_RADII
		tangent = tangent.normalized()
		var lo := .54
		var hi := 1.13
		for search in range(10):
			var middle := (hi + lo) * .5
			var p := POND_CENTER + middle * heading
			if _height(p.x, p.y) < WATER_LEVEL:
				lo = middle
			else:
				hi = middle
		var shore := POND_CENTER + heading * ((hi + lo) * .5)
		var normal := heading.normalized()
		for piece in range(4):
			var along := (piece - 1.4) * .59 + rng.randf_range(-.19,.19)
			var at := shore + tangent * along + normal * rng.randf_range(-.26,.54)
			if _route_distance(at) < 2.16:
				continue
			var width := rng.randf_range(.42,.75)
			var height := rng.randf_range(.14,.27)
			var depth := rng.randf_range(.33,.59)
			var bed := _height(at.x,at.y)
			var layer := _place(_cut_stone(Vector3(width,height,depth),.24), silt if piece != 1 else stained,
				Vector3(at.x,bed + height*.08,at.y))
			layer.rotation.y = -.18 - atan2(tangent.y,tangent.x) + rng.randf_range(-.12,.12)
			layer.rotation.z = rng.randf_range(-.11,.16)
			var crumble := at - normal * (depth * .63) + tangent * rng.randf_range(-.38,.23)
			var chip := _place(_cut_stone(Vector3(width*.46,height*.43,depth*.62),.26), stained,
				Vector3(crumble.x,_height(crumble.x,crumble.y)+height*.10,crumble.y))
			chip.rotation.y = layer.rotation.y - .31


func _build_sedge_cove() -> void:
	var garden := RandomNumberGenerator.new()
	garden.seed = 126940
	var dried := _strata_material(Color("b7bd9c"), Color("69785a"), Color("85966a"), .41, .68)
	var cove_edge := [Vector2(5.94,3.43),Vector2(6.48,2.86),Vector2(7.15,2.57),Vector2(8.07,2.42),Vector2(8.81,2.58),Vector2(9.42,3.13)]
	for index in range(cove_edge.size()-1):
		var foot: Vector2 = cove_edge[index]
		var head: Vector2 = cove_edge[index+1]
		var axis := (head-foot).normalized()
		var point := (head+foot)*.5
		var heading := -atan2(axis.y,axis.x)
		var y := _height(point.x,point.y)
		var h := garden.randf_range(.24,.39)
		var slab := _place(_strata_mesh(Vector3(foot.distance_to(head)*.72,h,.52),index*1.78),
			dried,Vector3(point.x,y-h*.52,point.y))
		slab.rotation.y = heading + garden.randf_range(-.19,.13)
		var sunny := point + Vector2(-.17,.39)
		_fern(Vector3(sunny.x,_height(sunny.x,sunny.y),sunny.y), garden.randf_range(.39,.64), ferns[index%ferns.size()])
		if index % 2 == 0:
			var chip := point + Vector2(-.22,-.48)
			var wet_height := maxf(_height(chip.x,chip.y),WATER_LEVEL-.17)
			var peel := _place(_cut_stone(Vector3(.28,.14,.24),.23),foundation_stone,
				Vector3(chip.x,wet_height,chip.y))
			peel.rotation.y = heading - .25
	# Use actual submerged stones so the edge keeps its thickness in both review views.
	for index in range(22):
		var edge: Vector2 = cove_edge[garden.randi_range(0,cove_edge.size()-1)]
		var at := edge + Vector2(garden.randf_range(-.44,.44),garden.randf_range(-1.21,-.22))
		var y := _height(at.x,at.y)
		if y > WATER_LEVEL - .105 or y < WATER_LEVEL - .52:
			continue
		var size := garden.randf_range(.125,.365)
		var pebble := _place(_cut_stone(Vector3(size,size*.34,size*.71),.24),foundation_stone,
			Vector3(at.x,y-.018,at.y))
		pebble.rotation.y = garden.randf_range(-2.2,2.2)
	# Irises sit at the sheltered edge of the terrace, where stone gives way to reeds.
	var stems := SurfaceTool.new()
	stems.begin(Mesh.PRIMITIVE_TRIANGLES)
	var petals := SurfaceTool.new()
	petals.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem_material := _surface(Color("62785a"),.89)
	for cluster in [Vector2(6.09,3.72),Vector2(7.10,3.16),Vector2(8.93,2.90)]:
		for blade in range(13):
			var at: Vector2 = cluster + Vector2(garden.randf_range(-.31,.31),garden.randf_range(-.29,.29))
			var y := maxf(_height(at.x,at.y),WATER_LEVEL-.10)
			var bottom := Vector3(at.x,y,at.y)
			var angle := garden.randf_range(0.0,TAU)
			var across := Vector3(cos(angle),0.0,sin(angle))
			var bend := Vector3(-across.z,0.0,across.x)
			var length_value := garden.randf_range(.30,.75)
			var width := garden.randf_range(.028,.058)
			var middle := bottom + Vector3.UP*length_value*.56 + bend*.081
			var top := bottom + Vector3.UP*length_value + bend*.22
			stems.set_color(Color("697548").srgb_to_linear())
			_triangle(stems,bottom,middle+across*width,middle-across*width)
			stems.set_color(Color("92a35a").srgb_to_linear())
			_triangle(stems,middle-across*width,middle+across*width,top)
			if blade % 4 != 0:
				continue
			var height_value := length_value + .11
			var bloom := bottom + Vector3.UP*height_value
			_beam(bottom,bloom,.009,.007,stem_material,5)
			for index in range(5):
				var phase := TAU*index/5.0 + angle
				var axis := Vector3(cos(phase),0.0,sin(phase))
				var fan := axis.cross(Vector3.UP)
				var fold := bloom + axis*.075 + Vector3.UP*.043
				petals.set_color(Color("83799a" if index%2 else "b0a2bd").srgb_to_linear())
				_triangle(petals,bloom,fold+fan*.029,fold+axis*.037)
				_triangle(petals,bloom,fold+axis*.037,fold-fan*.029)
				petals.set_color(Color("d6bf79").srgb_to_linear())
				_triangle(petals,bloom,fold-fan*.011,fold+fan*.011)
	stems.generate_normals()
	_place(stems.commit(),leaf_layer,Vector3.ZERO)
	petals.generate_normals()
	_place(petals.commit(),leaf_layer,Vector3.ZERO)


func _build_slope_gardens() -> void:
	var planting := RandomNumberGenerator.new()
	planting.seed = 21027
	var growth := SurfaceTool.new()
	growth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var patches := [
		[Vector2(-11.92,3.15),Vector2(1.77,1.81),.57],
		[Vector2(-12.70,-2.25),Vector2(1.61,.96),.67],
		[Vector2(-10.46,-10.01),Vector2(2.23,1.6),.81],
		[Vector2(-7.05,-16.33),Vector2(2.14,1.64),.77],
		[Vector2(13.23,-10.01),Vector2(2.52,1.87),.55],
		[Vector2(11.57,-6.67),Vector2(1.48,1.32),.65],
		[Vector2(10.24,5.05),Vector2(2.49,1.57),.88],
		[Vector2(8.43,5.87),Vector2(1.31,1.07),.74],
		[Vector2(11.30,7.35),Vector2(2.18,1.57),.59],
		[Vector2(8.65,7.9),Vector2(1.11,.72),.75],
	]
	for patch in patches:
		var center: Vector2 = patch[0]
		var extent: Vector2 = patch[1]
		var scale_value: float = patch[2]
		for tuft in range(54):
			var offset := Vector2.from_angle(planting.randf_range(0.0, TAU))
			var at := center + offset * extent * sqrt(planting.randf())
			var y := _height(at.x,at.y)
			if y < WATER_LEVEL + .044 or _route_distance(at) < 2.3:
				continue
			for blade in range(5):
				var a := planting.randf_range(0.0,TAU)
				var base := Vector3(at.x,y,at.y) + Vector3(cos(a),.014,sin(a)) * .07
				var across := Vector3(cos(a),0.0,sin(a))
				var bow := Vector3(across.z,0.0,-across.x)
				var height_value := planting.randf_range(.15,.55)*scale_value
				var width := planting.randf_range(.017,.037)
				var bend := bow * height_value * planting.randf_range(.30,.85)
				var middle := base + Vector3.UP * height_value*.63 + bend*.33
				var tip := base + Vector3.UP*height_value + bend
				growth.set_color(Color("53664d").srgb_to_linear())
				_triangle(growth,base,middle-across*width,middle+across*width)
				growth.set_color(Color("83945e" if tuft % 4 else "a59e62").srgb_to_linear())
				_triangle(growth,middle-across*width,tip,middle+across*width)
			if tuft % 17 == 0:
				var extent_value := planting.randf_range(.13,.25)
				var gravel := _place(_cut_stone(Vector3(extent_value,extent_value*.28,extent_value*.86),.23),foundation_stone,
					Vector3(at.x,y-.015,at.y))
				gravel.rotation.y = planting.randf_range(-1.0,1.0)
	growth.generate_normals()
	_place(growth.commit(),leaf_layer,Vector3.ZERO)


func _build_trail_aprons() -> void:
	var stone := _stone(Color("baa98b"), 4.6, 0.0)
	stone.set_shader_parameter("micro_relief", .003)
	var joints := [Vector2(-1.66,8.75), Vector2(-5.05,-5.22)]
	var bearing := Vector2(.86,-.51)
	var uphill := Vector2(-.51,-.86)
	for apron in joints.size():
		for row in range(3):
			for segment in range(5):
				if (row == 0 and segment % 3 == apron) or (row == 2 and segment < 2):
					continue
				var span := (segment - 2.0) * .53 + .18 * (row % 2)
				var at: Vector2 = joints[apron] + bearing * span + uphill * (row - 1.0) * .53
				var size := Vector3(rng.randf_range(.20,.32),.056,rng.randf_range(.23,.33))
				var y := _height(at.x,at.y)
				var slab := _place(_cut_stone(size,.19), stone if segment % 3 else warm_stone,
					Vector3(at.x,y - .029,at.y))
				slab.rotation.y = -atan2(bearing.y,bearing.x) + rng.randf_range(-.11,.11)


func _build_garden_retaining_banks() -> void:
	# Sediment has collected behind two deliberately different structures:
	# a dry verge following the turn, and the bedded shoulders of the spillway.
	var verge := [
		Vector2(-7.34,6.22), Vector2(-7.45,5.61), Vector2(-7.54,4.92),
		Vector2(-7.4,4.26), Vector2(-7.05,3.62), Vector2(-6.86,2.85),
		Vector2(-7.04,2.23), Vector2(-7.42,1.62),
	]
	var apron := [
		Vector2(11.92,-1.74), Vector2(11.23,-1.57), Vector2(10.61,-1.63),
		Vector2(9.92,-1.87), Vector2(9.21,-2.18), Vector2(8.72,-2.46),
	]
	var wet_face := _strata_material(Color("929981"),Color("565d4d"),Color("657c56"),.24,.88)
	var dry_cap := _strata_material(Color("bcbc9b"),Color("787d65"),Color("74866c"),.26,.64)
	var canopy := SurfaceTool.new()
	canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stems := RandomNumberGenerator.new()
	stems.seed = 765697
	for course: int in range(2):
		var axis: Array = verge if course == 0 else apron
		for i in range(axis.size()-1):
			var a: Vector2 = axis[i]
			var b: Vector2 = axis[i+1]
			var at := a.lerp(b,.50)
			var tangent := (b-a).normalized()
			var wall_y := (_height(a.x,a.y) + _height(b.x,b.y))*.5
			var h := .26 + .20*sin(float(i)*.61+.38)
			var footing := _place(_cut_stone(Vector3(a.distance_to(b)*.55,h,.28),.12),wet_face,
				Vector3(at.x,wall_y+h*.28-.05,at.y))
			footing.rotation.y = -atan2(tangent.y,tangent.x)
			var crown_offset := Vector2(-.04,.03) * sin(float(i)*1.8+.62)
			var crown := _place(_cut_stone(Vector3(a.distance_to(b)*.47,.084,.32),.09),dry_cap,
				Vector3(at.x+crown_offset.x,wall_y+h*1.25,at.y+crown_offset.y))
			crown.rotation.y = footing.rotation.y + .12*sin(float(i)*1.48)
			if course == 0 and i in [0, 1, 3, 4]:
				# Creepers follow the projecting cap and drop across the
				# shaded face between sections of exposed masonry.
				var inward := Vector2(-tangent.y,tangent.x)
				var root := crown.position + Vector3.UP*.087
				for strand in range(6 if i < 2 else 3):
					var finger := Vector3(tangent.x,0,tangent.y)*stems.randf_range(-.24,.23)
					var length := stems.randf_range(.34,.66)
					for leaf in range(9):
						var t := float(leaf)/8.0
						var curve := inward * (.07+.29*sin(t*PI*.52))
						var vine := root + finger + Vector3(curve.x,.065*sin(PI*t)-t*t*length,curve.y)
						var side := (-1.0 if leaf%2 else 1.0)*stems.randf_range(.038,.088)
						var along := Vector3(tangent.x,-.24,tangent.y)*side
						var tip := vine+along*1.67 - Vector3.UP*.038
						var mid := vine+along*.72
						canopy.set_color(Color("718b52" if leaf%3 else "849957").srgb_to_linear())
						_triangle(canopy,vine,mid+Vector3.UP*.043,tip)
						canopy.set_color(Color("42634e").srgb_to_linear())
						_triangle(canopy,vine,tip,mid-Vector3.UP*.043)
			if i == 1 or i == axis.size()-3:
				var toe := at + Vector2(.31,-.19) * (1.0 if course == 0 else -1.0)
				var chipped := _place(_cut_stone(Vector3(.25,.085,.23),.22),warm_stone,
					Vector3(toe.x,_height(toe.x,toe.y)-.029,toe.y))
				chipped.rotation.y = footing.rotation.y - .30

	# Broad understory leaves emerge on the sheltered side of the wall;
	# their larger forms taper back to the fine ferns already on the bank.
	var centers := [
		[Vector2(-7.79,6.12),1.21],[Vector2(-7.98,5.27),1.34],
		[Vector2(-7.68,4.26),.91],[Vector2(-7.51,3.02),.67],
		[Vector2(-7.98,2.19),.72],[Vector2(-8.9,5.2),.69],
		[Vector2(-6.95,6.44),.81],[Vector2(-6.72,5.30),.53],
		[Vector2(-6.93,5.74),.70],[Vector2(-6.31,7.73),.67],
		[Vector2(11.82,-.86),.96],[Vector2(11.18,-.24),1.16],
		[Vector2(12.32,-.59),.80],[Vector2(10.72,-2.18),.73],
		[Vector2(10.13,-2.56),.57],
	]
	for item: Array in centers:
		var center: Vector2 = item[0]
		var size: float = item[1]
		var origin := Vector3(center.x,_height(center.x,center.y),center.y)
		for blade in range(15):
			var angle := float(blade)*2.399963 + stems.randf_range(-.15,.15)
			var axis := Vector3(cos(angle),0,sin(angle))
			var tangent := Vector3(-axis.z,.20*sin(angle*2.41),axis.x)
			var low := origin + axis*size*stems.randf_range(.028,.084)
			var height := stems.randf_range(.22,.61)*size
			var reach := stems.randf_range(.19,.58)*size
			var width := stems.randf_range(.048,.099) * size
			var fold := low + axis*reach*.56 + Vector3.UP*height
			var tip := low + axis*reach + Vector3.UP*height*.82
			var left := fold-tangent*width-Vector3.UP*width*.20
			var right := fold+tangent*width-Vector3.UP*width*.35
			canopy.set_color(Color("547353" if blade%3 else "819759").srgb_to_linear())
			_triangle(canopy,low,fold,left)
			_triangle(canopy,left,fold,tip)
			canopy.set_color(Color("3a5c4d" if blade%3 else "667848").srgb_to_linear())
			_triangle(canopy,low,right,fold)
			_triangle(canopy,right,tip,fold)
		if center.x < -8.0 or center.x >= -6.71:
			continue
		for cluster in range(4):
			var heading := float(cluster)*2.399963 + .54
			var arm := Vector3(cos(heading),0,sin(heading))
			var foot := origin + arm * (.18 + .19*stems.randf())
			var top := foot + Vector3.UP * stems.randf_range(.26,.47) + arm * .07
			_beam(foot,top,.008,.005,wood,5)
			for petal in range(6):
				var sweep := float(petal)*TAU/6.0 + heading
				var face := Vector3(cos(sweep),0,sin(sweep))
				var edge := face.cross(Vector3.UP)
				var rim := top + face*.058 + Vector3.UP*.027
				canopy.set_color(Color("aa8fa8" if petal%3 else "c3a6b5").srgb_to_linear())
				_triangle(canopy,top,rim+edge*.022,rim+face*.020)
				_triangle(canopy,top,rim+face*.020,rim-edge*.023)
	canopy.generate_normals()
	_place(canopy.commit(),leaf_layer,Vector3.ZERO)


func _build_escarpments() -> void:
	# Asymmetric bedrock rises above both sides of the path and is sheltered by the established tree line.
	var west := [
		[Vector2(-13.6,-3.6), Vector3(2.25,1.22,1.16), .34],
		[Vector2(-14.3,-5.2), Vector3(2.75,1.92,1.62), .46],
		[Vector2(-14.9,-7.3), Vector3(2.88,2.14,1.66), .56],
		[Vector2(-14.1,-9.2), Vector3(1.95,1.16,1.46), .53],
		[Vector2(-10.3,-16.1), Vector3(1.8,.95,.85), -.73],
		[Vector2(-11.2,-16.8), Vector3(2.6,2.60,1.15), -.83],
		[Vector2(-11.8,-18.0), Vector3(2.88,2.37,1.52), -.93],
	]
	var east := [
		[Vector2(11.6,4.75), Vector3(2.16,.91,1.18), .20],
		[Vector2(12.7,3.8), Vector3(2.56,1.44,1.36), .27],
		[Vector2(13.45,2.14), Vector3(2.9,2.88,1.57), .42],
		[Vector2(14.1,.28), Vector3(2.61,2.21,1.26), .30],
		[Vector2(14.5,-2.6), Vector3(2.1,1.24,1.16), .32],
		[Vector2(11.9,-8.9), Vector3(2.30,1.33,1.07), -.47],
		[Vector2(12.8,-10.4), Vector3(2.45,1.60,1.42), -.69],
	]
	var scarp := west + east
	for index in scarp.size():
		var entry: Array = scarp[index]
		var at: Vector2 = entry[0]
		var extent: Vector3 = entry[1]
		var bed := _height(at.x,at.y)
		var rock := _place(_strata_mesh(extent,index*.79), bedrock_stone,
			Vector3(at.x,bed - extent.y*.33,at.y))
		rock.rotation.y = entry[2]
		# Fallen pieces lead from the large form to the finer debris at its base.
		var drop := Vector2(.59 * (-1.0 if index > 6 else 1.0), .63)
		var foot := at + drop * (1.18 + extent.y*.23)
		var toe := _place(_cut_stone(Vector3(extent.x*.32,extent.y*.20,extent.z*.51),.22), foundation_stone,
			Vector3(foot.x,_height(foot.x,foot.y) - .09,foot.y))
		toe.rotation.y = rock.rotation.y - .29
		if index % 3 == 1:
			var plant := foot + drop*.61
			_fern(Vector3(plant.x,_height(plant.x,plant.y),plant.y), .79, ferns[1])


func _strata_mesh(extent: Vector3, salt: float, eroded: bool = false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var perimeter := [
		Vector2(1.04,-.22),Vector2(.79,.64),Vector2(.16,1.03),Vector2(-.57,.78),
		Vector2(-1.0,.31),Vector2(-.87,-.62),Vector2(-.27,-.98),Vector2(.61,-.82),
	]
	var profile := [Vector2(-.36,.89),Vector2(.12,1.0),Vector2(.46,.93),Vector2(.52,.85),
		Vector2(.75,.79),Vector2(.82,.62),Vector2(.96,.49)]
	var rings: Array[PackedVector3Array] = []
	for layer: Vector2 in profile:
		var ring := PackedVector3Array()
		for index in perimeter.size():
			var edge: Vector2 = perimeter[index]
			var fracture := .065*sin(float(index)*8.19 + salt) + .039*cos(layer.x * 8.6 - float(index)*5.29)
			var grade := 0.0
			if eroded:
				fracture += layer.x * (.12 * sin(salt * .91 + edge.y*2.51) - .11 * edge.x)
				grade = layer.x * (.065*sin(float(index)*2.24+salt) + .12*cos(salt)*edge.y)
			var point := Vector3(edge.x * (layer.y + fracture) + layer.x*.21,
				layer.x + edge.x*.126 - edge.y*.059 + grade, edge.y * (layer.y + fracture) - layer.x*.17)
			ring.append(point * extent)
		rings.append(ring)
	for row in range(rings.size() - 1):
		var pigment := .91 if row == 2 or row == 4 else .99
		surface.set_color(Color(pigment,pigment,pigment))
		for i in perimeter.size():
			var j := (i+1)%perimeter.size()
			_triangle(surface,rings[row][i],rings[row][j],rings[row+1][j])
			_triangle(surface,rings[row][i],rings[row+1][j],rings[row+1][i])
	surface.set_color(Color.WHITE)
	var crown := Vector3(.15,.995,-.20)
	if eroded:
		crown += Vector3(sin(salt)*.27,cos(salt*.71)*.12,cos(salt)*.17)
	crown *= extent
	for i in perimeter.size():
		_triangle(surface,rings[-1][i],rings[-1][(i+1)%perimeter.size()],crown)
	surface.index()
	surface.generate_normals()
	return surface.commit()


func _build_overflow_sill() -> void:
	var crest := Vector2(9.68, -.53)
	var stream := Vector2(-.91, -.414).normalized()
	var bank_normal := stream.orthogonal()
	var slope_bed := _stone(Color("a7aa80"), 3.8, 0.0)
	slope_bed.set_shader_parameter("micro_relief", .0062)
	var saturated_stone := _stone(Color("a1b8a0"), 3.12, 1.0)
	saturated_stone.set_shader_parameter("micro_relief", .0049)
	var crest_height := maxf(-.10, _height(crest.x, crest.y))
	for index in range(4):
		var distance := .36 + float(index) * .67
		var spot := crest + stream * distance
		var bed_height := _height(spot.x, spot.y)
		var surface_height := maxf(bed_height + .075, lerpf(crest_height+.29, WATER_LEVEL+.07, float(index)/3.0))
		var face := _place(_cut_stone(Vector3(.40,.17,.75 + .12*index),.071), slope_bed,
			Vector3(spot.x,surface_height-.12,spot.y))
		face.rotation.y = -atan2(stream.y,stream.x) + rng.randf_range(-.072,.072)
		var mouth := _place(_cut_stone(Vector3(.24,.04,.56+.09*index),.11), saturated_stone,
			Vector3(spot.x,surface_height+.060,spot.y))
		mouth.rotation.y = face.rotation.y
		for side: int in [-1, 1]:
			var edge := spot + bank_normal * side * (.72 + .10 * index)
			if index == 2 and side > 0:
				continue
			var rise := _place(_cut_stone(Vector3(.43,.20 - .025*index,.27),.086), warm_stone,
				Vector3(edge.x,surface_height+.026,edge.y))
			rise.rotation.y = face.rotation.y + rng.randf_range(-.25,.15)
	var spill := crest + stream * 3.36
	for index in range(6):
		var spot := spill + stream * rng.randf_range(-.43,.47) + bank_normal * rng.randf_range(-1.12,1.12)
		var dim := rng.randf_range(.14,.45)
		var toe := _place(_cut_stone(Vector3(dim,dim*.41,dim*.76),.13), saturated_stone,
			Vector3(spot.x,maxf(_height(spot.x,spot.y), WATER_LEVEL - dim*.41),spot.y))
		toe.rotation.y = rng.randf_range(-.8,1.8)
	for bank: float in [-1.28, .91]:
		var grass := crest + bank_normal * bank
		_fern(Vector3(grass.x,_height(grass.x,grass.y),grass.y), .72, ferns[2])


func _build_slope_outcrops() -> void:
	var weathered := _stone(Color("adae89"), 4.4, 0.0)
	weathered.set_shader_parameter("micro_relief", .0042)
	var flecks := _stone(Color("9ba79b"), 2.4, 1.0)
	var strata := [
		[Vector2(-11.4, 2.15), Vector3(.96,.19,.39), .41],
		[Vector2(-12.24, 2.87), Vector3(1.18,.19,.46), .53],
		[Vector2(-13.15, 3.57), Vector3(1.61,.27,.49), .59],
		[Vector2(-13.36, 2.55), Vector3(.91,.21,.36), .40],
		[Vector2(-11.93,-10.12), Vector3(1.08,.29,.45), -.19],
		[Vector2(-13.52,-10.65), Vector3(1.38,.38,.73), -.35],
		[Vector2(-13.81,-11.86), Vector3(1.15,.20,.44), -.20],
		[Vector2(12.22,-7.45), Vector3(.96,.29,.42), -.38],
		[Vector2(12.69,-8.22), Vector3(1.31,.27,.56), -.44],
		[Vector2(13.77,-8.64), Vector3(1.59,.32,.51), -.37],
	]
	for i in strata.size():
		var detail: Array = strata[i]
		var spot: Vector2 = detail[0]
		var size: Vector3 = detail[1]
		var height := _height(spot.x, spot.y)
		var slab := _place(_cut_stone(size,.13), weathered,
			Vector3(spot.x,height - size.y*.17,spot.y))
		slab.rotation.y = detail[2]
		slab.rotation.z = rng.randf_range(-.18,.21)
		var foot := spot + Vector2(.37,.52)
		var talus := _place(_cut_stone(size * .42,.20), flecks, Vector3(foot.x,_height(foot.x,foot.y),foot.y))
		talus.rotation.y = slab.rotation.y - .38
		if i % 3 == 1:
			_fern(Vector3(foot.x,_height(foot.x,foot.y),foot.y), .67, ferns[0])


func _build_landmark() -> void:
	# A copper water clock rather than a gateway: sun dial, catch basin and three calibrated supports.
	var origin := Vector3(2.4, -0.94, -5.5)
	for step in range(3):
		var tier := _cylinder(2.65 - 0.22 * step, 0.24, 24)
		_place(tier, warm_stone, origin + Vector3(0, 0.12 + 0.235 * step, 0))
	_circle_tube(origin + Vector3(0, 0.66, 0), 2.10, 0.041, brass, false)
	for i in range(3):
		var a := TAU * float(i) / 3.0 + PI / 6.0
		var r := Vector3(cos(a), 0, sin(a))
		var foot := origin + r * 1.92 + Vector3.UP * 0.68
		_place(_cylinder(0.34, 0.30, 8), warm_stone, foot + Vector3.UP * 0.08)
		_beam(foot + Vector3.UP * 0.15, origin + r * 1.42 + Vector3.UP * 3.35, 0.20, 0.095, celadon, 10)
		_beam(foot + Vector3.UP * 0.37, origin + r * 1.38 + Vector3.UP * 3.25, 0.042, 0.035, brass, 6)
		_place(_cylinder(0.19, 0.16, 8), brass, origin + r * 1.42 + Vector3.UP * 3.31)
	var crown := origin + Vector3.UP * 3.50
	_circle_tube(crown, 1.74, 0.091, celadon, false)
	_circle_tube(crown + Vector3.UP * 0.07, 1.58, 0.035, brass, false)
	_circle_tube(crown + Vector3.UP * 0.74, 1.36, 0.083, celadon, true)
	_circle_tube(crown + Vector3.UP * 0.74, 1.20, 0.032, brass, true)
	for i in range(28):
		var a := float(i) * TAU / 28.0
		var r := Vector3(cos(a), sin(a), 0)
		_beam(crown + Vector3.UP * 0.74 + r * (1.10 if i % 7 == 0 else 1.155), crown + Vector3.UP * 0.74 + r * 1.33, 0.024, 0.018, brass, 5)
	for i in range(7):
		var angle := TAU * i / 7.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var petal := _place(SphereMesh.new(), celadon, crown + direction * 1.10 + Vector3.UP * 0.17)
		petal.scale = Vector3(0.88, 0.081, 0.28)
		petal.rotation.y = -angle
	_beam(crown + Vector3(-0.02, 0.80, 0.01), crown + Vector3(0.67, 1.43, 0.01), 0.059, 0.014, brass, 7)
	_build_clock_mechanics(origin, crown)
	var decoration_seed := rng.state
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var r := Vector3(cos(angle), 0.0, sin(angle))
		var stem := origin + r * 1.91 + Vector3.UP * .61
		var tile := _place(_cut_stone(Vector3(.23, .08, .14), .06), cold_stone, stem)
		tile.rotation.y = -angle
	for i in range(10):
		var angle := (float(i) + .3) / 10.0 * TAU
		var r := Vector3(cos(angle), 0.0, sin(angle))
		_beam(origin + r * .92 + Vector3.UP * .78, origin + r * .78 + Vector3.UP * 1.51, .018, .026, brass, 6)
	for i in range(3):
		var angle := float(i) * TAU / 3.0 + .43
		var r := Vector3(cos(angle), 0.0, sin(angle))
		var drip := _surface(Color("489187"), 0.19, 0.20)
		_beam(origin + r * 1.32 + Vector3.UP * 3.42, origin + r * 1.51 + Vector3.UP * .67, .021, .042, drip, 8)
	rng.state = decoration_seed


func _build_clock_mechanics(origin: Vector3, crown: Vector3) -> void:
	var bronze_dark := _forged(Color("537267"), Color("9a8363"), Color("2b4440"))
	var plate := origin + Vector3.UP * 0.83
	_place(_cylinder(1.18, .16, 9), bronze_dark, plate)
	var reservoir := _cylinder(1.03, .74, 12)
	reservoir.top_radius = .71
	_place(reservoir, celadon, plate + Vector3.UP * .44)
	_place(_cylinder(.73, .16, 12), bronze_dark, plate + Vector3.UP * .87)
	for y: float in [.16, .68, .94]:
		_circle_tube(plate + Vector3.UP * y, 1.03 - y*.33, .045, brass, false)
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var near := plate + out*.95 + Vector3.UP*.14
		var far := plate + out*.75 + Vector3.UP*.78
		_beam(near, far, .065, .042, bronze_dark, 7)
		if i % 3 == 0:
			var valve := _place(_cylinder(.113, .16, 8), brass, plate + out*.95 + Vector3.UP*.43)
			valve.rotation.z = PI*.5
			valve.rotate_y(-angle)
	var dial := crown + Vector3.UP*.74
	_beam(dial - Vector3.BACK*.19, dial + Vector3.BACK*.21, .18, .17, bronze_dark, 11)
	_beam(dial + Vector3.BACK*.19, dial + Vector3.BACK*.28, .11, .125, brass, 11)
	var inset := _place(_cylinder(.078, .082, 8), nectar, dial + Vector3.BACK*.28)
	inset.rotation.x = PI*.5
	_circle_tube(dial + Vector3.BACK*.23, .24, .032, brass, true)
	for side: int in [-1, 1]:
		var anchor := dial + Vector3(side * 1.27, -.55, 0)
		_beam(anchor, crown + Vector3(side*1.34, 0, .75), .073, .092, bronze_dark, 8)
		_beam(anchor, crown + Vector3(side*1.42, 0, -.61), .063, .078, brass, 7)
		_beam(anchor + Vector3.UP*.18, anchor - Vector3.UP*.12, .12, .09, brass, 8)
	for i in range(8):
		var angle := TAU * (float(i) + .5) / 8.0
		var radial := Vector3(cos(angle), sin(angle), 0)
		var clamp_at := dial + radial*1.34
		_beam(clamp_at - Vector3.BACK*.11, clamp_at + Vector3.BACK*.12, .055, .06, brass, 7)


func _build_stonework() -> void:
	# Retaining walls bend along contours, preserving the winding trail.
	var beds := [
		[Vector2(-10.2, 5.2), Vector2(-11.2, -4.2), Vector2(-9.5, -10.7)],
		[Vector2(9.0, 5.6), Vector2(11.3, -3.2), Vector2(9.8, -9.7)],
		[Vector2(4.9, -13.4), Vector2(9.4, -14.0), Vector2(13.1, -11.5)],
	]
	for line in beds:
		for segment in range(line.size() - 1):
			var src: Vector2 = line[segment]
			var dst: Vector2 = line[segment + 1]
			var span := src.distance_to(dst)
			var count := ceili(span / 0.85)
			var direction := (dst - src).normalized()
			for i in range(count):
				var point := src.lerp(dst, (float(i) + .5) / count)
				var foundation := _height(point.x, point.y)
				for tier in range(2):
					var stone := _cut_stone(Vector3(span / count * 0.51, 0.25 + tier * 0.02, 0.63 - tier * 0.09), rng.randf_range(-0.08, .11))
					var stone_type := foundation_stone if tier == 0 or (i+segment)%5 == 1 else warm_stone
					var block := _place(stone, stone_type, Vector3(point.x, foundation - .10 + tier * 0.41, point.y))
					block.rotation.y = -atan2(direction.y, direction.x)
	for index in range(38):
		var pos := Vector2(rng.randf_range(-13.7, 15.8), rng.randf_range(-15.2, 14.1))
		if _route_distance(pos) < 2.8 or Vector2((pos.x - 3.7) / 7.0, (pos.y + 2.6) / 12.5).length() < 1.03:
			continue
		var size := rng.randf_range(0.21, 1.4)
		var rock := _place(_cut_stone(Vector3(size, size * 0.59, size * 0.78), 0.18), warm_stone if index % 4 != 0 else cold_stone, Vector3(pos.x, _height(pos.x, pos.y) - size * 0.1, pos.y))
		rock.rotation.y = rng.randf_range(-PI, PI)
	var stone_seed := rng.state
	_build_ridges()
	_build_left_terrace()
	rng.state = stone_seed


func _build_ridges() -> void:
	var pale := _strata_material(Color("a4aa9e"),Color("687b7b"),Color("6b815c"),2.05,.63)
	var muted := _strata_material(Color("919f9b"),Color("617c80"),Color("627c68"),1.73,.68)
	pale.set_shader_parameter("ridge_weathering", .93)
	muted.set_shader_parameter("ridge_weathering", .89)
	var distance_stone := _strata_material(Color("9ebac5"),Color("87a8b8"),Color("91b3b0"),4.17,.22)
	distance_stone.set_shader_parameter("ridge_weathering", .22)
	# Broad sloped shoulders descend behind the trail. The same original
	# footprints keep the path and water untouched; depth comes from plane
	# direction, with quieter blue-grey paint reserved for the distant tier.
	var hilltops := [
		[Vector3(-33.8, 1.4,-28.9),Vector3(15.4,14.2,8.6),-.49,pale],
		[Vector3(-24.2, 1.2,-28.2),Vector3(13.7,10.8,8.1),-.39,muted],
		[Vector3(-20.1, 1.1,-23.1),Vector3(9.1,8.4,5.9),-.32,pale],
		[Vector3(-13.4, 1.8,-26.5),Vector3(9.6,7.2,6.9),-.51,muted],
		[Vector3(-5.7, 1.9,-28.8),Vector3(9.4,5.3,7.7),-.45,muted],
		[Vector3(2.1, 2.4,-34.8),Vector3(9.8,7.2,6.2),.39,muted],
		[Vector3(12.4, 1.8,-28.8),Vector3(11.3,9.1,7.9),.55,pale],
		[Vector3(21.2, 1.6,-25.9),Vector3(12.1,10.5,6.8),.58,pale],
		[Vector3(28.3, 2.5,-22.9),Vector3(12.9,12.9,7.4),.47,muted],
		[Vector3(36.1, 1.1,-20.8),Vector3(11.5,10.2,7.7),.36,muted],
		[Vector3(45.4, .25,-17.7),Vector3(13.6,12.4,10.6),-.23,pale],
	]
	for i in hilltops.size():
		var spec: Array = hilltops[i]
		var massif := _place(_rock_mass(spec[1],float(i)*1.49, false),spec[3],spec[0])
		massif.rotation.y = spec[2]
	var shelves := [
		[Vector2(-17.75,-17.63),Vector3(3.89,1.34,1.46),.33,muted],
		[Vector2(-20.8,-18.6),Vector3(5.47,2.63,2.31),.26,pale],
		[Vector2(-23.27,-20.5),Vector3(5.85,3.39,2.18),.29,pale],
		[Vector2(-26.4,-19.2),Vector3(5.80,2.73,2.09),.54,muted],
		[Vector2(-15.79,-23.18),Vector3(4.83,2.89,2.93),.66,pale],
		[Vector2(-11.91,-21.8),Vector3(3.27,1.70,1.69),.52,muted],
		[Vector2(11.95,-20.43),Vector3(5.08,1.47,2.39),-.54,muted],
		[Vector2(16.84,-19.76),Vector3(5.62,1.65,2.23),-.46,muted],
		[Vector2(20.83,-17.88),Vector3(6.39,3.84,2.07),-.47,pale],
		[Vector2(24.27,-15.9),Vector3(6.88,4.95,3.47),-.54,pale],
		[Vector2(27.18,-14.53),Vector3(7.28,3.40,2.12),-.43,muted],
		[Vector2(31.14,-14.85),Vector3(5.84,2.24,2.65),-.61,pale],
	]
	for i in shelves.size():
		var spec: Array = shelves[i]
		var at: Vector2 = spec[0]
		var extent: Vector3 = spec[1]
		var above := _height(at.x,at.y)-extent.y*.35
		var rock := _place(_strata_mesh(extent,float(i)*1.47,true),spec[3],Vector3(at.x,above,at.y))
		rock.rotation.y = spec[2]
	var horizon := [
		[Vector3(-45.0, 4.4, -58.5), Vector3(26.3, 21.5, 15.3), -.41],
		[Vector3(-21.3, 5.2, -66.7), Vector3(30.4, 24.3, 16.1), .64],
		[Vector3(2.4, 5.0, -73.8), Vector3(23.9, 19.4, 17.9), -.62],
		[Vector3(24.5, 4.7, -59.2), Vector3(22.1, 20.1, 14.0), .51],
		[Vector3(49.3, 3.2, -49.4), Vector3(26.6, 23.7, 12.9), -.29],
	]
	for i in horizon.size():
		var spec: Array = horizon[i]
		var rock := _place(_rock_mass(spec[1], float(i)*1.92 + 3.78, true),distance_stone,spec[0])
		rock.rotation.y = spec[2]


func _build_left_terrace() -> void:
	var ledge_start := Vector2(-12.9, -.2)
	var ledge_end := Vector2(-13.4, -7.7)
	var ledge_direction := (ledge_end - ledge_start).normalized()
	var ledge_angle := -atan2(ledge_direction.y, ledge_direction.x)
	for i in range(11):
		var point := ledge_start.lerp(ledge_end, (float(i) + .5) / 11.0)
		var base := _height(point.x, point.y)
		for level in range(2):
			var dimensions := Vector3(.38 + .09 * level, .19, .29)
			var stone_type := foundation_stone if level == 0 or i % 4 == 0 else cold_stone
			if (i == 1 or i == 5 or i == 10) and level == 1:
				continue
			var rock := _place(_cut_stone(dimensions, .07), stone_type,
				Vector3(point.x - level * .09, base + .09 + level * .30, point.y))
			rock.rotation.y = ledge_angle + rng.randf_range(-.09, .09)
		if i > 3 and i % 2 == 0:
			var outward := point + Vector2(.27, .12)
			var grass := maxf(base, _height(outward.x, outward.y))
			_fern(Vector3(outward.x, grass + .35, outward.y), rng.randf_range(.66, .95), ferns[1])
	for index in range(5):
		var center := Vector2(-7.8 - .26 * index, -12.4 - .54 * index)
		var base := _height(center.x, center.y)
		var step := _place(_cut_stone(Vector3(.48 + .04 * index, .10, .28), .06), warm_stone,
			Vector3(center.x, base + .055, center.y))
		step.rotation.y = -.51
	var bank := [
		[Vector2(-11.92, 2.25),Vector3(.71,.21,.39),.57],
		[Vector2(-12.34, 1.75),Vector3(.98,.24,.58),.63],
		[Vector2(-12.31, .92),Vector3(1.18,.34,.62),.54],
		[Vector2(-12.73, .44),Vector3(.91,.36,.59),.50],
		[Vector2(-12.83,-.28),Vector3(1.11,.23,.77),.54],
	]
	for index in bank.size():
		var foot: Vector2 = bank[index][0]
		var extent: Vector3 = bank[index][1]
		var y := _height(foot.x,foot.y)-extent.y*.29
		var support := _place(_strata_mesh(extent,index*.71), foundation_stone,
			Vector3(foot.x,y,foot.y))
		support.rotation.y = bank[index][2]


func _build_grove() -> void:
	var trees := [
		[Vector2(-11.3, 6.3), 5.8, 1, 0, 1.1], [Vector2(-10.1, -6.8), 5.6, 0, 1, -0.63],
		[Vector2(9.9, 3.7), 6.0, 3, 2, -2.25], [Vector2(10.2, -5.4), 4.9, 4, 1, 0.73],
		[Vector2(8.3, -12.0), 5.1, 5, 0, 1.21], [Vector2(-7.8, -15.9), 5.8, 5, 2, -0.21],
		[Vector2(2.0, -15.7), 5.1, 5, 0, 1.8], [Vector2(13.5, -15.7), 7.6, 6, 1, -2.16],
		[Vector2(-15.8, -12.7), 6.1, 7, 2, -1.13], [Vector2(14.4, 7.1), 4.6, 5, 1, 1.72],
	]
	var saved_state := rng.state
	for index in trees.size():
		var item: Array = trees[index]
		var pos: Vector2 = item[0]
		rng.seed = 298860 + 7193 * index
		_tree(Vector3(pos.x, _height(pos.x, pos.y), pos.y), item[1], item[2], item[3], item[4])
	rng.seed = 298860
	rng.state = saved_state
	var clusters := [
		Vector2(-5.1, 8.4), Vector2(-0.9, 5.0), Vector2(-8.0, 2.2), Vector2(-7.8, -4.8),
		Vector2(-1.9, 0.0), Vector2(-2.0, -9.0), Vector2(9.8, 5.1), Vector2(9.8, -3.2),
		Vector2(9.9, -9.0), Vector2(0.3, -15.7), Vector2(-8.5, -11.7), Vector2(10.4, -12.2),
	]
	for i in clusters.size():
		var center: Vector2 = clusters[i]
		var bank_edge := Vector2(1.0,.47).rotated(float(i%3)*.71)
		var growth := ferns[i % ferns.size()]
		for j in range(19):
			# The banks alternate exposed ground and a few damp perennial clumps.
			var pocket := center + bank_edge * (float(j%3) - 1.0)
			var point := pocket + Vector2(rng.randf_range(-.64,.64), rng.randf_range(-.73,.73))
			var y := _height(point.x, point.y)
			if y < -0.63 or _route_distance(point) < 1.58:
				continue
			# Give the new wood margin and reflected cove a few gaps
			# between their distinctive vegetation patches.
			if (i == 0 and point.x < -5.70) or (i == 2 and j % 3 != 0) or (i == 6 and j % 2 == 0):
				continue
			_fern(Vector3(point.x, y, point.y), rng.randf_range(.52, 1.16), growth)


func _tree(origin: Vector3, height: float, palette: int, habit: int, bearing: float) -> void:
	var along := Vector3(cos(bearing), 0.0, sin(bearing))
	var cross := along.cross(Vector3.UP)
	var wood_mesh := SurfaceTool.new()
	wood_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := [.97, 1.17, .84][habit] as float
	var reach := [1.14, .82, 1.29][habit] as float
	var base := origin + Vector3.DOWN * .18
	var waist := base + (along * -.046 + Vector3.UP * .36) * height
	var fork := base + (along * .085 + cross * .042 + Vector3.UP * .66 * lift) * height
	var crown := base + (along * .19 - cross * .034 + Vector3.UP * .86 * lift) * height
	_bough(wood_mesh, [base, waist, fork, crown], [height*.086, height*.053, height*.031, height*.008], 11)

	for i in range(5):
		var root_dir := along.rotated(Vector3.UP, i * TAU / 5.0 + rng.randf_range(-.19, .19))
		var root_out := origin + root_dir * height * rng.randf_range(.14,.22)
		root_out.y = _height(root_out.x, root_out.z) - .03
		var knee := origin.lerp(root_out, .54)
		knee.y = _height(knee.x, knee.z) + height*.02
		_bough(wood_mesh, [origin + Vector3.UP * height*.055, knee, root_out], [height*.033, height*.025, .009], 7)

	var branch_profiles := [
		Vector3(-1.34, .43, .27), Vector3(1.00, .58, .22), Vector3(-2.66, .65, .16),
		Vector3(-.14, .82, .30), Vector3(2.16, .79, .22), Vector3(.53, .96, .15),
	]
	for i in branch_profiles.size():
		var profile: Vector3 = branch_profiles[i]
		var out := along.rotated(Vector3.UP, profile.x + rng.randf_range(-.23, .23))
		var branch_start := waist.lerp(fork, profile.y * .90) if i < 4 else fork.lerp(crown, (i - 3) * .27)
		var mid := branch_start + (out * .11 * reach + Vector3.UP * .085) * height
		var tip := mid + (out * profile.z * reach + Vector3.UP * (.055 + (i % 4) * .034) * lift) * height
		_bough(wood_mesh, [branch_start, mid, tip], [height*.026, height*.017, height*.0043], 8)
		for lateral: int in [-1, 0, 1]:
			var sway := out.rotated(Vector3.UP, lateral * (.49 + (i % 3) * .18))
			var shoot_start := mid.lerp(tip, .24 + (lateral + 1) * .19)
			var shoot_tip := shoot_start + (sway * (.14 + (lateral + 1) * .018) * reach
				+ Vector3.UP * (.035 + (i + lateral + 2) % 3 * .039)) * height
			_bough(wood_mesh, [shoot_start, shoot_start.lerp(shoot_tip, .51) + Vector3.UP*.12, shoot_tip],
				[height*.011, height*.006, .007], 6)
			var pigment := canopy_palette[palette] * (.92 + .037 * float(i + lateral))
			_leaf_spray(leaves, shoot_start.lerp(shoot_tip, .52), sway, height*(.276 if lateral == 0 else .207),
				height*(.042 + (i % 3) * .013), pigment, 102)
	_leave_crown_top(leaves, crown, along, height, canopy_palette[palette])
	wood_mesh.index()
	wood_mesh.generate_normals()
	_place(wood_mesh.commit(), wood, Vector3.ZERO)
	# Crown normals are authored per vertex; recomputing would expose the card planes.
	leaves.index()
	_place(leaves.commit(), leaf_layer, Vector3.ZERO)


func _leave_crown_top(builder: SurfaceTool, crown: Vector3, axis: Vector3, height: float, pigment: Color) -> void:
	_leaf_spray(builder, crown, axis, height*.28, height*.075, pigment*1.04, 148)
	_leaf_spray(builder, crown + (axis * .12 - Vector3.UP * .09) * height, axis, height*.225, height*.05, pigment, 94)


func _bough(builder: SurfaceTool, spine: Array, girths: Array, sides: int) -> void:
	var rings: Array[PackedVector3Array] = []
	for i in spine.size():
		var p: Vector3 = spine[i]
		var tangent: Vector3 = (spine[min(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var right := tangent.cross(Vector3.FORWARD).normalized()
		var normal := tangent.cross(right)
		var ring := PackedVector3Array()
		for j in sides:
			var theta := TAU * float(j) / sides
			var fluting := 1.0 + .14 * sin(theta * 4.0 + float(i) * .49)
			ring.append(p + (right * cos(theta) + normal * sin(theta)) * float(girths[i]) * fluting)
		rings.append(ring)
	for i in range(rings.size() - 1):
		for j in sides:
			var j2 := (j + 1) % sides
			builder.set_color(Color(.59 + .28 * sin(j * 2.317) ** 2.0, .51 + .34 * float(i) / spine.size(), .72))
			_triangle(builder, rings[i][j], rings[i+1][j2], rings[i+1][j])
			_triangle(builder, rings[i][j], rings[i][j2], rings[i+1][j2])


func _leaf_spray(builder: SurfaceTool, at: Vector3, along: Vector3, radius: float, depth: float, pigment: Color, amount: int) -> void:
	# Original branch positions remain unchanged. Volume is added inside each
	# branch's own footprint, with broad atlas leaves and air between boughs.
	var cross := along.cross(Vector3.UP).normalized()
	var cards := clampi(int(round(float(amount) * .38)), 32, 50)
	var crown_depth := maxf(depth, radius * .28)
	var warm := pigment.r > pigment.g * 1.17
	var quadrant := Vector2(0.0, 1.0) if warm else Vector2.ZERO
	var golden_angle := PI * (3.0 - sqrt(5.0))
	for i in range(cards):
		var frac := (float(i) + .5) / float(cards)
		var layer := i % 3
		var shell := [.30, .55, .78][layer] as float
		var theta := float(i) * golden_angle + rng.randf_range(-.15,.15)
		var vertical := 1.0 - 2.0 * frac
		var radial := sqrt(maxf(0.0, 1.0 - vertical * vertical))
		var direction := along * (cos(theta) * radial) + cross * (sin(theta) * radial) + Vector3.UP * vertical
		var offset := (along * (cos(theta) * radial * radius * 1.01)
			+ cross * (sin(theta) * radial * radius * .69)
			+ Vector3.UP * vertical * crown_depth) * shell
		var center := at + offset
		var facing := (direction + Vector3.UP * .38).normalized()
		var reference := Vector3.UP if absf(facing.y) < .92 else along
		var right := reference.cross(facing).normalized()
		var up := facing.cross(right).normalized()
		var roll := rng.randf_range(-PI, PI)
		var rx := right * cos(roll) + up * sin(roll)
		var ry := -right * sin(roll) + up * cos(roll)
		var size_value := radius * rng.randf_range(.66,.86)
		if layer == 2:
			size_value *= .90
		var half_size := size_value * .5
		var middle := center + facing * size_value * .07
		var corners := PackedVector3Array([
			center - rx * half_size - ry * half_size,
			center + rx * half_size - ry * half_size,
			center + rx * half_size + ry * half_size,
			center - rx * half_size + ry * half_size,
		])
		var uvs := PackedVector2Array([Vector2(.02,.98),Vector2(.98,.98),Vector2(.98,.02),Vector2(.02,.02)])
		var variation := rng.randf_range(.94,1.05)
		for edge in range(4):
			var next_edge := (edge + 1) % 4
			var positions := PackedVector3Array([corners[edge],corners[next_edge],middle])
			for flatten_index in range(3):
				positions[flatten_index].y = at.y + (positions[flatten_index].y - at.y) * .76
			var local_uvs := PackedVector2Array([uvs[edge],uvs[next_edge],Vector2(.5,.5)])
			for vertex_index in range(3):
				var local := positions[vertex_index] - at
				# Use the bough ellipsoid rather than each card face for lighting.
				var crown_normal := (along * local.dot(along) / (radius * radius)
					+ cross * local.dot(cross) / pow(radius * .80,2)
					+ Vector3.UP * (local.y + crown_depth * .65) / pow(crown_depth * 1.55,2)).normalized()
				var height_tone := clampf(local.y / (crown_depth * 2.0) + .5, 0.0, 1.0)
				var value := lerpf(.82,1.10,height_tone) * variation
				var shade := pigment * value
				builder.set_color(Color(shade.r,shade.g,shade.b,lerpf(.60,.98,shell)))
				builder.set_uv((quadrant + local_uvs[vertex_index]) * .5)
				builder.set_uv2(Vector2(1.0,height_tone))
				builder.set_normal(crown_normal)
				builder.add_vertex(positions[vertex_index])


func _build_trail_trim() -> void:
	var trail := route()
	for piece in range(trail.size() - 1):
		var a := trail[piece]
		var b := trail[piece + 1]
		var direction := (b - a).normalized()
		var shoulder := Vector2(-direction.y, direction.x)
		for j in range(9):
			if rng.randf() > .78:
				continue
			var edge := 1.0 if (piece + j / 3) % 2 == 0 else -1.0
			var p := a.lerp(b, (float(j) + .46) / 9.0) + shoulder * (1.68 + rng.randf_range(-.21, .24)) * edge
			var size_value := rng.randf_range(.15, .38)
			var mesh := _cut_stone(Vector3(size_value * 1.30, .075, size_value), rng.randf_range(.04, .21))
			var paving := _place(mesh, warm_stone, Vector3(p.x, _height(p.x,p.y) + .018, p.y))
			paving.rotation.y = rng.randf_range(-.32,.32) - atan2(direction.y,direction.x)
	for j in range(21):
		var angle := (float(j) + .41) / 21.0 * TAU
		var eccentricity := .91 + sin(angle * 5.3) * .054
		var p := Vector2(3.7 + cos(angle) * 7.4 * eccentricity, -2.6 + sin(angle) * 12.9 * eccentricity)
		if _route_distance(p) < 1.85:
			continue
		var extent := rng.randf_range(.12, .43)
		var stone := _place(_cut_stone(Vector3(extent, extent * .51, extent * .84), .24), warm_stone, Vector3(p.x, _height(p.x,p.y), p.y))
		stone.rotation.y = angle


func _build_bank_details() -> void:
	var grass := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var position_list := [
		Vector2(-1.8, 2.5), Vector2(-1.9, -2.3), Vector2(-1.42, -6.5), Vector2(0.5, -10.4), Vector2(4.5, -12.0),
		Vector2(8.67, -7.2), Vector2(9.35, -1.9), Vector2(7.3, 4.4), Vector2(5.8, 6.6), Vector2(2.05, 6.9),
	]
	for center in position_list:
		for strand in range(37):
			var p: Vector2 = center + Vector2(rng.randf_range(-.49,.49), rng.randf_range(-.45,.45))
			var bed := Vector3(p.x, maxf(_height(p.x,p.y), -.84), p.y)
			var height := rng.randf_range(.18, .78)
			var angle := rng.randf_range(0, TAU)
			var u := Vector3(cos(angle), 0, sin(angle))
			var v := Vector3(-sin(angle), 0, cos(angle))
			var spread := rng.randf_range(.021, .055)
			var arc := u * rng.randf_range(.065,.26) + Vector3.UP * height
			grass.set_color(Color("65562d").srgb_to_linear())
			grass.add_vertex(bed - v * spread*.69)
			grass.add_vertex(bed + v * spread*.69)
			grass.set_color(Color("737733").srgb_to_linear())
			grass.add_vertex(bed + arc * .56 + v * spread)
			grass.add_vertex(bed + arc * .56 + v * spread)
			grass.set_color(Color("65562d").srgb_to_linear())
			grass.add_vertex(bed - v * spread*.69)
			grass.set_color(Color("737733").srgb_to_linear())
			grass.add_vertex(bed + arc * .56 - v * spread)
			grass.add_vertex(bed + arc * .56 - v * spread)
			grass.add_vertex(bed + arc * .56 + v * spread)
			grass.set_color(Color("a5a457").srgb_to_linear())
			grass.add_vertex(bed + arc)
	grass.generate_normals()
	_place(grass.commit(), leaf_layer, Vector3.ZERO)
	for p in [Vector2(-6.9, -.75), Vector2(-6.98, -8.7), Vector2(-2.1, -14.5)]:
		var y := _height(p.x,p.y)
		var at := Vector3(p.x, y, p.y)
		_place(_cut_stone(Vector3(.31,.13,.26), .03), warm_stone, at+.10*Vector3.UP)
		_place(_cylinder(.16,.63,8), warm_stone, at+.47*Vector3.UP)
		for i in range(4):
			var a := (float(i)+.5)*TAU/4.0
			var offset := Vector3(cos(a),0,sin(a))*.22
			_beam(at+offset+.70*Vector3.UP, at+offset+1.02*Vector3.UP, .031,.031, celadon, 6)
		_place(_cylinder(.29,.087,8), warm_stone, at+.70*Vector3.UP)
		_place(_cylinder(.134,.24,7), nectar, at+.86*Vector3.UP)
		_beam(at+1.00*Vector3.UP, at+1.20*Vector3.UP, .31,.12, celadon, 7)
		_place(_cylinder(.061,.13,8), brass, at+1.22*Vector3.UP)


func _fern(at: Vector3, size_value: float, material: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(size_value * 1.10, size_value)
	for index in range(2):
		var plant := _place(quad, material, at + Vector3.UP * (size_value * .46))
		plant.rotation.y = (index * PI * .49) + rng.randf_range(-.2, .2)
		plant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _rock_mass(extent: Vector3, salt: float, distant: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 44
	var rings: Array[PackedVector3Array] = []
	var profiles := [
		Vector2(-.36, 1.04), Vector2(-.04, 1.03), Vector2(.14, .96), Vector2(.25, .88),
		Vector2(.31, .81), Vector2(.35, .82), Vector2(.40, .78), Vector2(.49, .69),
		Vector2(.55, .67), Vector2(.59, .655), Vector2(.65, .62), Vector2(.73, .58),
		Vector2(.77, .49), Vector2(.83, .43), Vector2(.90, .36), Vector2(.95, .25),
		Vector2(1.0, .10), Vector2(1.025, .026),
	]
	var lean := Vector3(.26 + .13 * sin(salt), 0.0, -.17 + .11 * cos(salt*1.66))
	for profile: Vector2 in profiles:
		var ring := PackedVector3Array()
		for i in range(segments):
			var angle := TAU * float(i) / float(segments)
			var vector := Vector3(cos(angle), 0.0, sin(angle))
			# R20-B restores continuous folded faces after the low-ring trial
			# produced polygon domes and full-width bands. Small vertex wear
			# is reduced while original broad shoulders and smooth normals remain.
			# Long folded faces shed into narrow gullies. At the toe they
			# spread back into the adjoining grass and buried rubble.
			var folds := .125*sin(angle*3.0 + salt*.79) + .082*sin(angle*6.0-salt*.62)
			var gully := .082 * pow(.5+.5*cos(angle*8.0 + salt*.49 + profile.x*.94), 3.1)
			var wear := noise.get_noise_3dv(vector*14.0 + Vector3(salt, profile.x*11.0, salt*.13))*.038
			var landing := .28 + .72*smoothstep(-.1,.55,profile.x)
			var crest := 1.0 + .15*sin(angle*2.0+salt) + .063*sin(angle*5.0-salt*.68)
			var erosion := (folds - gully + wear) * landing * (.68 if distant else 1.0)
			var at := (vector * profile.y*(crest + erosion) + lean * maxf(0.0,profile.x)**1.65) * extent
			at.y = extent.y * (profile.x + (.084*sin(angle + salt) + .071*sin(angle*2.0-salt*.71))*profile.y)
			ring.append(at)
		rings.append(ring)
	var ridge_normals: Array[PackedVector3Array] = []
	var peak := (lean*1.07 + Vector3.UP*1.035)*extent
	for row in rings.size():
		var band := PackedVector3Array()
		for i in range(segments):
			var top := peak if row == rings.size()-1 else rings[row+1][i]
			var toe := rings[maxi(0,row-1)][i]
			var tangent := rings[row][(i+1)%segments]-rings[row][posmod(i-1,segments)]
			band.append((top-toe).cross(tangent).normalized())
		ridge_normals.append(band)
	for row in range(rings.size() - 1):
		for i in range(segments):
			var j := (i + 1) % segments
			for key: Vector2i in [Vector2i(row,i),Vector2i(row,j),Vector2i(row+1,j),
					Vector2i(row,i),Vector2i(row+1,j),Vector2i(row+1,i)]:
				var vertex := rings[key.x][key.y]
				var strength := smoothstep(-.17,.69,vertex.y/extent.y)
				surface.set_normal(ridge_normals[key.x][key.y])
				surface.set_color(Color(.71+.29*strength,.78+.22*strength,.72+.28*strength))
				surface.add_vertex(vertex)
	for i in range(segments):
		var j := (i+1)%segments
		surface.set_color(Color.WHITE)
		surface.set_normal(ridge_normals[-1][i])
		surface.add_vertex(rings[-1][i])
		surface.set_normal(ridge_normals[-1][j])
		surface.add_vertex(rings[-1][j])
		surface.set_normal(Vector3.UP)
		surface.add_vertex(peak)
	surface.index()
	return surface.commit()


func _cut_stone(half: Vector3, variance: float) -> ArrayMesh:
	var b := SurfaceTool.new()
	b.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for h in [Vector2(-1.0, 0.87), Vector2(-0.66, 1.0), Vector2(0.68, 1.0), Vector2(1.0, .83)]:
		var ring := PackedVector3Array()
		for index in range(8):
			var a := (index + 0.5) * TAU / 8.0
			var x := clampf(cos(a) * 1.22, -1.0, 1.0)
			var z := clampf(sin(a) * 1.22, -1.0, 1.0)
			ring.append(Vector3(x * h.y, h.x + rng.randf_range(-0.05, .05), z * h.y) * half * (1.0 + variance * sin(index * 11.1)))
		rings.append(ring)
	for row in range(3):
		for col in range(8):
			var j := (col + 1) % 8
			_triangle(b, rings[row][col], rings[row][j], rings[row + 1][j])
			_triangle(b, rings[row][col], rings[row + 1][j], rings[row + 1][col])
	for col in range(8):
		_triangle(b, Vector3.UP * half.y, rings[3][col], rings[3][(col + 1) % 8])
	b.generate_normals()
	return b.commit()


func _circle_tube(at: Vector3, radius: float, thickness: float, material: Material, vertical: bool) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - thickness
	ring.outer_radius = radius + thickness
	ring.rings = 76
	ring.ring_segments = 12
	var instance := _place(ring, material, at)
	if vertical:
		instance.rotation.x = PI / 2.0


func _beam(a: Vector3, b: Vector3, start_radius: float, end_radius: float, material: Material, sides: int) -> void:
	var cylinder := _cylinder(start_radius, a.distance_to(b), sides)
	cylinder.top_radius = end_radius
	var instance := _place(cylinder, material, (a + b) * .5)
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())


func _cylinder(radius: float, height: float, sides: int) -> CylinderMesh:
	var result := CylinderMesh.new()
	result.top_radius = radius
	result.bottom_radius = radius
	result.height = height
	result.radial_segments = sides
	result.rings = 1
	return result


func _triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	builder.add_vertex(a)
	builder.add_vertex(b)
	builder.add_vertex(c)


func _surface(tint: Color, roughness: float, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.metallic = metal
	return mat


func _forged(patina: Color, rubbed: Color, deep: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FORGED_METAL
	mat.set_shader_parameter("patina", patina)
	mat.set_shader_parameter("rubbed", rubbed)
	mat.set_shader_parameter("deep", deep)
	return mat


func _stone(tint: Color, scale_value: float, half: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = STONE
	mat.set_shader_parameter("stone_atlas", STONE_MAP)
	mat.set_shader_parameter("atlas_half", half)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("texture_scale", scale_value)
	mat.set_shader_parameter("micro_relief", 0.008)
	return mat


func _strata_material(pigment: Color, seam: Color, lichen: Color, bedding: float, weathering: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = STRATA
	mat.set_shader_parameter("painted_stone", STONE_MAP)
	mat.set_shader_parameter("stone", pigment)
	mat.set_shader_parameter("seam", seam)
	mat.set_shader_parameter("lichen", lichen)
	mat.set_shader_parameter("bedding", bedding)
	mat.set_shader_parameter("weathering", weathering)
	return mat


func _place(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	add_child(visual)
	return visual

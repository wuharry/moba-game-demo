extends Node3D

const ATLAS := preload("res://textures/painted_stone.png")
const STONE := preload("res://painted_stone.gdshader")
const PLANT_TEXTURE := preload("res://textures/painted_plants.png")
const PLANT := preload("res://painted_plants.gdshader")
const ACTOR_MODEL := "res://models/fog_runner.glb"
const PALETTES := [
	["Sunvine Court", "res://models/garden_hero.glb"],
	["Tide Relay", "res://models/ridge_hero.glb"],
]

var stage := Node3D.new()
var camera := Camera3D.new()
var rng := RandomNumberGenerator.new()
var profile: int = 0
var view_index: int = 0
var actor_mode := false
var asset_focus: Vector3
var asset_radius: float
var message := Label.new()
var ui := CanvasLayer.new()
var capture_dir := ""
var missing_hero := false


func _ready() -> void:
	add_child(stage)
	add_child(camera)
	camera.make_current()
	camera.near = 0.04
	camera.far = 240.0
	add_child(ui)
	ui.add_child(message)
	message.position = Vector2(16, 16)
	message.add_theme_color_override("font_outline_color", Color("1b242a"))
	message.add_theme_constant_override("outline_size", 5)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_dir = argument.trim_prefix("--capture=")
	if not capture_dir.is_empty() and not capture_dir.is_absolute_path():
		capture_dir = ProjectSettings.globalize_path("res://" + capture_dir.trim_prefix("./"))
	if capture_dir.is_empty():
		_build_stage()
	else:
		ui.visible = false
		_capture_all.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1, KEY_2:
			profile = 0 if event.physical_keycode == KEY_1 else 1
			view_index = 0
			_build_stage()
		KEY_TAB:
			if actor_mode:
				_build_stage()
			else:
				_build_actor_stage()
		KEY_C:
			view_index = (view_index + 1) % 3
			_move_camera()
		KEY_P:
			get_tree().change_scene_to_file("res://station.tscn")
		KEY_G:
			get_tree().change_scene_to_file("res://refinement_gallery.tscn")
		KEY_ESCAPE:
			get_tree().quit()


func _build_stage() -> void:
	_clear_stage()
	actor_mode = false
	rng.seed = 58725 + profile * 41
	_set_lighting()
	_build_court()
	_add_hero()
	_move_camera()
	message.text = "%s    1 / 2  asset    C  camera    Tab  character    P  play    G  gallery" % PALETTES[profile][0]


func _clear_stage() -> void:
	for object in stage.get_children():
		stage.remove_child(object)
		object.queue_free()


func _build_actor_stage() -> void:
	_clear_stage()
	actor_mode = true
	view_index = 0
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = Color("344550")
	lighting.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("cedce6")
	lighting.ambient_light_energy = 0.63
	lighting.fog_enabled = true
	lighting.fog_mode = Environment.FOG_MODE_DEPTH
	lighting.fog_light_color = lighting.background_color
	lighting.fog_depth_begin = 5.0
	lighting.fog_depth_end = 13.0
	lighting.fog_density = 1.0
	var backdrop := WorldEnvironment.new()
	backdrop.environment = lighting
	stage.add_child(backdrop)

	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(40, 40)
	_mesh(floor_plane, _mat(Color("29363a"), 0.90), Vector3(0, -0.028, 0))
	_actor_light(Vector3(-32, -27, 0), Color("fff1db"), 0.95, true)
	_actor_light(Vector3(-18, 132, 0), Color("a9cdf2"), 0.7, false)
	if ResourceLoader.exists(ACTOR_MODEL):
		var scene := load(ACTOR_MODEL) as PackedScene
		var model := scene.instantiate() as Node3D
		stage.add_child(model)
		model.rotation.y = PI
		for animator in model.find_children("*", "AnimationPlayer", true, false):
			var player := animator as AnimationPlayer
			for clip in player.get_animation_list():
				if "scout" in clip.to_lower():
					player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
					player.play(clip)
					break
	else:
		missing_hero = true
		push_error("Character model missing: " + ACTOR_MODEL)
	_move_camera()
	message.text = "Fog Runner    C  camera    Tab  environment    P  play    G  gallery"


func _actor_light(angles: Vector3, tint: Color, strength: float, shadow: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angles
	light.light_color = tint
	light.light_energy = strength
	light.shadow_enabled = shadow
	light.directional_shadow_max_distance = 12.0
	light.light_angular_distance = 2.0
	stage.add_child(light)


func _set_lighting() -> void:
	var warm := profile == 0
	var scene_environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("35688b") if warm else Color("354f68")
	sky_material.sky_horizon_color = Color("b7d5d1") if warm else Color("a0aab0")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color("4e6965") if warm else Color("2f3844")
	sky_material.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	scene_environment.sky = sky
	scene_environment.background_mode = Environment.BG_SKY
	scene_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	scene_environment.tonemap_exposure = 0.95 if warm else 1.04
	scene_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	scene_environment.ambient_light_color = Color("c6e0e2") if warm else Color("a0b3cf")
	scene_environment.ambient_light_energy = 0.74 if warm else 0.61
	scene_environment.ssao_enabled = true
	scene_environment.ssao_radius = 2.5
	scene_environment.ssao_intensity = 2.0
	scene_environment.fog_enabled = true
	scene_environment.fog_mode = Environment.FOG_MODE_DEPTH
	scene_environment.fog_light_color = Color("a8c8ca") if warm else Color("72899a")
	scene_environment.fog_depth_begin = 13.5
	scene_environment.fog_depth_end = 64.0
	scene_environment.fog_density = 0.92
	scene_environment.fog_sky_affect = 0.75
	scene_environment.glow_enabled = not warm
	scene_environment.glow_bloom = 0.12
	var environment := WorldEnvironment.new()
	environment.environment = scene_environment
	stage.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37, -38, 0) if warm else Vector3(-19, -133, 0)
	sun.light_color = Color("fff0d4") if warm else Color("bad2ff")
	sun.light_energy = 1.43 if warm else 1.24
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 37.0
	sun.light_angular_distance = 3.2 if warm else 5.0
	stage.add_child(sun)

	if not warm:
		var bounce := SpotLight3D.new()
		bounce.position = Vector3(-3.4, 3.8, 4.5)
		stage.add_child(bounce)
		bounce.look_at(Vector3(0, 1.5, 0))
		bounce.light_color = Color("ffe4bd")
		bounce.light_energy = 4.0
		bounce.spot_range = 15.0
		bounce.spot_angle = 46.0


func _add_hero() -> void:
	var hero_path: String = PALETTES[profile][1]
	if ResourceLoader.exists(hero_path):
		var scene := load(hero_path) as PackedScene
		if scene != null:
			var hero := scene.instantiate() as Node3D
			stage.add_child(hero)
			hero.position = Vector3(0, 0.0, 0)
			var bounds := _mesh_bounds(hero)
			asset_focus = bounds.get_center()
			asset_focus.y *= 0.94
			asset_radius = maxf(bounds.size.x * 0.75, bounds.size.y)
			return
	missing_hero = true
	asset_focus = Vector3(0, 0.65, 0)
	asset_radius = 2.6


func _mesh_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var piece := child as MeshInstance3D
		var bounds := piece.global_transform * piece.get_aabb()
		result = result.merge(bounds) if found else bounds
		found = true
	return result


func _move_camera() -> void:
	if actor_mode:
		var actor_views := [
			[Vector3(0.58, 1.52, 3.95), Vector3(0, 0.98, 0), 34.0],
			[Vector3(0.22, 1.72, 1.44), Vector3(0, 1.62, 0), 26.0],
			[Vector3(-1.1, 1.45, -3.8), Vector3(0, 0.94, 0), 34.0],
		]
		camera.position = actor_views[view_index][0]
		camera.look_at(actor_views[view_index][1], Vector3.UP)
		camera.fov = actor_views[view_index][2]
		return
	var offsets := [Vector3(0.92, 0.42, 1.98), Vector3(0.38, 0.15, 1.41), Vector3(-1.05, 1.10, 1.70)]
	var focus := asset_focus
	if view_index == 1:
		focus.y = maxf(0.48, focus.y * 0.72)
	camera.position = focus + offsets[view_index] * asset_radius
	camera.look_at(focus, Vector3.UP)
	camera.fov = 36.0 if view_index != 1 else 33.0


func _stone_material(scale: float, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STONE
	material.set_shader_parameter("stone_atlas", ATLAS)
	material.set_shader_parameter("atlas_half", float(profile))
	material.set_shader_parameter("texture_scale", scale)
	material.set_shader_parameter("tint", tint)
	return material


func _build_court() -> void:
	var warm := profile == 0
	var path_tint := Color("b2a186") if warm else Color("a8a5a0")
	var surface := _stone_material(3.9, path_tint)
	var rock_surface := _stone_material(4.4, Color("a9aa87") if warm else Color("a2b5c5"))
	var distant_rock := _stone_material(8.2, Color("acb5bf"))
	distant_rock.set_shader_parameter("atlas_half", 1.0)
	var underland := PlaneMesh.new()
	underland.size = Vector2(330, 330)
	_mesh(underland, _mat(Color("62774e") if warm else Color("343c3d"), 0.96), Vector3(0, -0.11, 0))

	for row in range(11):
		for column in range(13):
			var x := (float(column) - 6.0) * 1.18
			var z := (float(row) - 4.4) * 1.02
			var boundary := absf(x) > 5.7 and rng.randf() < 0.58
			if boundary:
				continue
			var color := Color.WHITE.lerp(Color("676e64"), rng.randf_range(0.01, 0.21))
			var tile := _paver_mesh(rng.randf_range(0.54, 0.58), rng.randf_range(0.46, 0.50), color)
			var paver := _mesh(tile, surface, Vector3(x + rng.randf_range(-0.032, 0.032), -0.025, z))
			paver.rotation.y = rng.randf_range(-0.035, 0.035)

	var rock := [
		[Vector3(-7.8, 0.3, -2.90), Vector3(2.8, 3.9, 3.1)],
		[Vector3(-9.1, 0.9, -7.6), Vector3(3.7, 5.2, 3.3)],
		[Vector3(8.9, 0.3, -6.3), Vector3(3.0, 4.5, 3.6)],
		[Vector3(9.45, -0.18, 2.6), Vector3(2.6, 1.5, 2.3)],
		[Vector3(-5.8, -0.2, 6.0), Vector3(1.7, 1.3, 1.25)],
	]
	for item in rock:
		_mesh(_boulder(item[1], rng.randi()), rock_surface, item[0])

	for index in range(15):
		var x := (float(index) - 7.0) * 5.7
		var height := rng.randf_range(4.7, 16.2)
		var far_rock := _boulder(Vector3(rng.randf_range(4.9, 9.0), height, rng.randf_range(5.3, 10.0)), rng.randi())
		_mesh(far_rock, distant_rock, Vector3(x, height * 0.18, -27.0 - rng.randf_range(0.0, 10.0)))

	var planting_centers := [
		Vector3(-5.9, 0.0, 2.7), Vector3(-4.5, 0.0, -2.5),
		Vector3(4.8, 0.0, -1.2), Vector3(6.3, 0.0, 3.2),
		Vector3(2.3, 0.0, -3.2), Vector3(-2.1, 0.0, -3.3),
		Vector3(0.8, 0.0, -5.3), Vector3(4.8, 0.0, 6.5),
		Vector3(-3.9, 0.0, 5.3), Vector3(3.9, 0.0, 5.1),
	]
	var flora := [_plant_material(0, warm), _plant_material(1, warm)]
	for zone in planting_centers.size():
		var center: Vector3 = planting_centers[zone]
		for index in rng.randi_range(3, 7):
			var spread := Vector3(rng.randf_range(-0.85, 0.85), 0.0, rng.randf_range(-0.65, 0.65))
			var size := rng.randf_range(0.38, 1.16) * (0.82 if not warm else 1.0)
			_plant_clump(center + spread, size, flora[(zone + index) % flora.size()])


func _paver_mesh(half_width: float, half_length: float, tint: Color) -> ArrayMesh:
	var bevel := rng.randf_range(0.035, 0.087)
	var outline := [
		Vector2(-half_width + bevel, -half_length),
		Vector2(half_width - bevel, -half_length),
		Vector2(half_width, -half_length + bevel),
		Vector2(half_width, half_length - bevel),
		Vector2(half_width - bevel, half_length),
		Vector2(-half_width + bevel, half_length),
		Vector2(-half_width, half_length - bevel),
		Vector2(-half_width, -half_length + bevel),
	]
	var top: Array[Vector3] = []
	var seam: Array[Vector3] = []
	var base: Array[Vector3] = []
	for point in outline:
		var weathered: Vector2 = point + Vector2(rng.randf_range(-0.024, 0.024), rng.randf_range(-0.021, 0.021))
		top.append(Vector3(weathered.x * 0.94, rng.randf_range(0.018, 0.051), weathered.y * 0.94))
		seam.append(Vector3(weathered.x, -0.018, weathered.y))
		base.append(Vector3(weathered.x * 0.99, -0.15, weathered.y * 0.99))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var j := (i + 1) % outline.size()
		_triangle(tool, Vector3(0, 0.046, 0), top[i], top[j], tint)
		_triangle(tool, top[i], seam[i], seam[j], tint)
		_triangle(tool, top[i], seam[j], top[j], tint)
		_triangle(tool, seam[i], base[i], base[j], tint.darkened(0.13))
		_triangle(tool, seam[i], base[j], seam[j], tint.darkened(0.13))
	tool.generate_normals()
	return tool.commit()


func _boulder(dimensions: Vector3, seed_value: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.77
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var sides := 30
	for h in range(21):
		var latitude := lerpf(-1.54, 1.54, float(h) / 20.0)
		var band := PackedVector3Array()
		for side in range(sides):
			var angle := TAU * float(side) / sides
			var dir := Vector3(cos(angle) * cos(latitude), sin(latitude), sin(angle) * cos(latitude))
			var fracture := noise.get_noise_3dv(dir * 3.5)
			var stratum := sin(dir.y * 37.0 + dir.x * 7.5 + dir.z * 3.0 + fracture * 5.0)
			var radial := 1.0 + fracture * 0.23 + stratum * 0.027
			dir.x += dir.y * 0.21
			dir *= dimensions * 0.5 * radial
			band.append(dir)
		rings.append(band)
	for level in range(rings.size() - 1):
		for side in range(sides):
			var j := (side + 1) % sides
			var a := rings[level][side]
			var b := rings[level][j]
			var c := rings[level + 1][j]
			var d := rings[level + 1][side]
			_triangle(surface, a, b, c, Color.WHITE)
			_triangle(surface, a, c, d, Color.WHITE)
	surface.index()
	surface.generate_normals()
	return surface.commit()


func _plant_material(column: int, warm: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PLANT
	material.set_shader_parameter("plant_atlas", PLANT_TEXTURE)
	material.set_shader_parameter("quadrant", Vector2(column, 0 if warm else 1))
	material.set_shader_parameter("foliage_tint", Color("a0a995") if warm else Color("9badae"))
	return material


func _plant_clump(point: Vector3, height: float, material: Material) -> void:
	var card := QuadMesh.new()
	card.size = Vector2(height * 1.08, height)
	var bearing := rng.randf_range(-0.74, 0.74)
	for span in [0.0, 1.12, -1.12]:
		var plant := _mesh(card, material, point + Vector3(0, height * 0.5 - 0.16, 0))
		plant.rotation.y = bearing + span


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	surface.set_color(tint)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _mat(albedo: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	return material


func _mesh(geometry: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.material_override = material
	node.position = at
	stage.add_child(node)
	return node


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for index in PALETTES.size():
		profile = index
		_build_stage()
		for angle in range(2):
			view_index = angle
			_move_camera()
			await _save_capture("%02d_%02d.png" % [index + 1, angle + 1])
	_build_actor_stage()
	for angle in range(3):
		view_index = angle
		_move_camera()
		await _save_capture("03_%02d.png" % [angle + 1])
	get_tree().quit(int(missing_hero))


func _save_capture(name: String) -> void:
	for n in range(12):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var outcome := image.save_png(capture_dir.path_join(name))
	print("CAPTURE %s %s" % [name, error_string(outcome)])
	if outcome != OK:
		missing_hero = true


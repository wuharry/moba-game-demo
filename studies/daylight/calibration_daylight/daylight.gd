extends Node3D

const Terrain = preload("res://calibration_daylight/terrain.gd")
const Foliage = preload("res://calibration_daylight/foliage.gd")
const MaterialStudies = preload("res://calibration_daylight/material_studies.gd")
const VERSION := "P34-D"
const TerraceLighting = preload("res://calibration_daylight/terrace_lighting.gd")
var study_hour := 16.0
const CLIFF_SWEEP: JSON = preload("res://calibration_daylight/assets/cliff_sweep.json")
var camera: Camera3D
var player: CharacterBody3D
var walking := false
var moba := false
var miniature_material := false
var scout: Node3D
const MOBA_OFFSET := Vector3(6.0, 26.0, 19.0)
var illustration_enabled := true
var plane_weight := 1.0
var pitch := 0.0
var yaw := 0.0
var leaf_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var rock_mat: ShaderMaterial
var meadow_mat: ShaderMaterial
var sun: DirectionalLight3D
var study_environment: Environment

func _ready() -> void:
	_build_environment()
	var rock := ShaderMaterial.new()
	rock_mat=rock
	rock.shader = preload("res://calibration_daylight/painted.gdshader")
	rock.set_shader_parameter("bedding_mask",load("res://calibration_daylight/assets/limestone_beds.png"))
	rock.set_shader_parameter("paint",load("res://calibration_daylight/assets/painted_limestone.png"))
	rock.set_shader_parameter("meadow_paint",load("res://calibration_daylight/assets/painted_meadow.png"))
	var grass_ground := ShaderMaterial.new()
	meadow_mat=grass_ground
	grass_ground.shader = rock.shader
	grass_ground.set_shader_parameter("paint",load("res://calibration_daylight/assets/painted_meadow.png"))
	grass_ground.set_shader_parameter("meadow",true)
	leaf_mat = ShaderMaterial.new()
	leaf_mat.shader = preload("res://calibration_daylight/leaves.gdshader")
	leaf_mat.set_shader_parameter("leaves",load("res://calibration_daylight/assets/leaf_cluster.png"))
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = preload("res://calibration_daylight/grass.gdshader")
	grass_mat.set_shader_parameter("meadow_paint",load("res://calibration_daylight/assets/painted_meadow.png"))
	grass_ground.set_shader_parameter("meadow_paint",load("res://calibration_daylight/assets/painted_meadow.png"))
	var floor_paint := preload("res://calibration_daylight/assets/turf_floor.png")
	for material: ShaderMaterial in [rock_mat, meadow_mat, grass_mat]:
		material.set_shader_parameter("turf_floor", floor_paint)
		material.set_shader_parameter("habitat_wash", preload("res://calibration_daylight/assets/habitat_wash.png"))
	preload("res://calibration_daylight/ground_margin.gd").apply([rock_mat, meadow_mat, grass_mat])
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.43,0.37,0.25)
	bark.roughness = 1.0
	bark.vertex_color_use_as_albedo = true
	Terrain.build(self,rock,grass_ground)
	preload("res://calibration_daylight/talus.gd").build(self, rock)
	preload("res://calibration_daylight/mid_cliff_talus.gd").build(self, Terrain, rock)
	# P07: the whole integrated cliff is built by Terrain; the P06 attached asset is retired.
	Foliage.build(self,Terrain,leaf_mat,grass_mat,bark)
	preload("res://calibration_daylight/background.gd").build(self)
	_set_material_environment(study_environment.ambient_light_color,.27)
	camera = Camera3D.new()
	camera.name = "ReferenceCamera"
	camera.fov = 60
	camera.far = 650
	add_child(camera)
	camera.current = true
	_set_view(0)
	_build_player()
	var arguments := OS.get_cmdline_user_args()
	if "--study-test" in arguments:
		call_deferred("_test_route")
	elif "--study-safe-motion" in arguments:
		call_deferred("_capture_motion", true)
	elif "--study-motion" in arguments:
		call_deferred("_capture_motion")
	elif "--study-capture" in arguments or "--study-blockout" in arguments or "--study-review" in arguments:
		call_deferred("_capture")
	else:
		_apply_afternoon()
	print("DAYLIGHT ",VERSION," | ",DisplayServer.get_name()," | ",RenderingServer.get_video_adapter_name()," | ",RenderingServer.get_current_rendering_method())

func _build_environment() -> void:
	var env := Environment.new()
	study_environment=env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://calibration_daylight/painted_day_sky.gdshader")
	sky_mat.set_shader_parameter("panorama", load("res://calibration_daylight/assets/painted_sky.png"))
	sky.sky_material = sky_mat
	env.sky = sky
	# Keep the bright cloud bank over the left end of the terrace.
	env.sky_rotation.y = deg_to_rad(110.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55,0.72,0.90)
	env.ambient_light_energy = 0.0 if OS.get_environment("DAYLIGHT_AMBIENT_ZERO")=="1" else 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.53,0.75,0.82)
	env.fog_light_energy = 0.80
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "MorningSun"
	sun.rotation_degrees = Vector3(-44,-77,0)
	sun.light_color = Color(1.0,0.96,0.87)
	sun.light_energy = 0.95
	sun.shadow_enabled = OS.get_environment("DAYLIGHT_SHADOWS")!="off"
	sun.directional_shadow_max_distance = 130
	sun.shadow_bias = 0.13
	sun.shadow_normal_bias = 2.0
	add_child(sun)

func _set_view(index:int) -> void:
	moba = false
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if scout: scout.hide()
	camera.fov = 60.0
	grass_mat.set_shader_parameter("animate_wind", false)
	leaf_mat.set_shader_parameter("animate_wind", false)
	walking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if index >= 8 and index < 8 + MaterialStudies.VIEWS.size():
		MaterialStudies.apply_pose(camera, index - 8)
	elif index==0:
		camera.position=Vector3(18,12,32)
		camera.look_at(Vector3(0,5,-32))
	elif index==1:
		camera.position=Vector3(-21,14.8518005214351,-13)
		camera.look_at(Vector3(-18,16.03550080926226,-26))
	elif index==2:
		camera.position=Vector3(17,5.397635132347,15)
		camera.look_at(Vector3(-4,4.41656733017261,-12))
	elif index==4:
		camera.position=Vector3(-45,4.15044139798902,16)
		camera.look_at(Vector3(-24,8,-12))
	elif index==5:
		camera.position=Vector3(-58,18,32)
		camera.look_at(Vector3(-32,10,-12))
	elif index==6:
		# P10-D2 physical camera and target, retained as the terrain changes.
		camera.position = Vector3(14.0, 6.264821, -52.0)
		camera.look_at(Vector3(-24.0, 10.45528, -5.0))
	elif index==7:
		# P12-D path-bend eye and target, frozen to compare successive terrain versions.
		camera.position = Vector3(27.96051, 3.581203, -29.0)
		camera.look_at(Vector3(17.858115, 3.995856, -43.0))
	else:
		camera.position=Vector3(14,13,29)
		camera.look_at(Vector3(-8,8,-35))

func _build_player() -> void:
	player=CharacterBody3D.new()
	player.name="WalkController"
	add_child(player)
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.32
	capsule.height=1.8
	var shape:=CollisionShape3D.new()
	shape.shape=capsule
	shape.position.y=.9
	player.add_child(shape)
	player.floor_max_angle=deg_to_rad(42)
	player.floor_snap_length=.8
	player.position=Vector3(Terrain.path_center(30),Terrain.ground_height(Terrain.path_center(30),30)+.15,30)

	scout = preload("res://calibration_daylight/lane_scout.gd").new()
	player.add_child(scout)
	scout.hide()

func _moba_follow() -> void:
	var target := player.position + Vector3(0, .65, -2.4)
	camera.position = target + MOBA_OFFSET
	camera.look_at(target)

func _activate_moba() -> void:
	moba = true
	walking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
	scout.show()
	_moba_follow()

func _set_miniature_material(enabled: bool) -> void:
	miniature_material = enabled
	for material: ShaderMaterial in [rock_mat, meadow_mat, grass_mat]:
		material.set_shader_parameter("miniature_material", 1.0 if enabled else 0.0)


func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_N and not event.echo: _set_miniature_material(not miniature_material)
		if event.keycode==KEY_1:_set_view(0)
		if event.keycode==KEY_2:_set_view(1)
		if event.keycode==KEY_3:_set_view(2)
		if event.keycode==KEY_4:_set_view(3)
		if event.keycode==KEY_5:_set_view(4)
		if event.keycode==KEY_6:_apply_sunset()
		if event.keycode==KEY_7:_apply_daylight()
		if event.keycode==KEY_J:_apply_afternoon()
		if event.keycode == KEY_BRACKETLEFT and not event.echo: _set_study_hour(study_hour - .5)
		if event.keycode == KEY_BRACKETRIGHT and not event.echo: _set_study_hour(study_hour + .5)
		if event.keycode==KEY_8:_set_view(5)
		if event.keycode==KEY_9:_set_view(6)
		if event.keycode==KEY_0:_set_view(7)
		if event.keycode==KEY_F1 and not event.echo:_set_illustration_light(not illustration_enabled)
		if event.keycode==KEY_F2:_set_view(8)
		if event.keycode==KEY_F3:_set_view(9)
		if event.keycode==KEY_F4:_set_view(10)
		if event.keycode == KEY_M and not event.echo:
			if moba: _set_view(0)
			else: _activate_moba()
		if event.keycode==KEY_TAB:
			if moba: _set_view(0)
			walking=not walking
			if walking: camera.fov = 60.0
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if walking else Input.MOUSE_MODE_VISIBLE
			leaf_mat.set_shader_parameter("animate_wind",walking)
			grass_mat.set_shader_parameter("animate_wind",walking)
		if event.keycode==KEY_ESCAPE:
			if moba: _set_view(0)
			walking=false
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and walking:
		yaw-=event.relative.x*.002
		pitch=clampf(pitch-event.relative.y*.002,-1.2,1.2)

func _set_illustration_light(enabled: bool) -> void:
	illustration_enabled=enabled
	for material: ShaderMaterial in [rock_mat, meadow_mat, leaf_mat]:
		material.set_shader_parameter("illustration_light", plane_weight if enabled else 0.0)

func _physics_process(delta:float) -> void:
	if walking or moba:
		var direction:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		direction=direction.rotated(Vector3.UP,atan2(MOBA_OFFSET.x, MOBA_OFFSET.z) if moba else yaw).normalized()
		player.velocity.x=direction.x*5
		player.velocity.z=direction.z*5
		if not player.is_on_floor():player.velocity.y-=20*delta
		else:player.velocity.y=0
		player.move_and_slide()
		if moba:
			if direction.length_squared() > .001: scout.rotation.y = atan2(-direction.x, -direction.z)
			_moba_follow()
			return
		camera.position=player.position+Vector3(0,1.65,0)
		camera.rotation=Vector3(pitch,yaw,0)

func _test_route() -> void:
	var total:=0.0
	var last:=player.position
	var passed_previous_exit := false
	for step in range(5400):
		var target_z:=maxf(-98.0,player.position.z-2.5)
		var target:=Vector3(Terrain.path_center(target_z),player.position.y,target_z)
		var dir:Vector3=(target-player.position).normalized()
		player.velocity.x=dir.x*4
		player.velocity.z=dir.z*4
		player.velocity.y-=20.0/60.0
		player.move_and_slide()
		total+=player.position.distance_to(last)
		last=player.position
		if player.position.z < -40 and not passed_previous_exit:
			passed_previous_exit = true
			print("STUDY_ROUTE previous exit | ", snappedf(total, .01), " m")
		if player.position.z < -96:
			print("STUDY_ROUTE PASS | ",snappedf(total,.01)," m | physical capsule reached z=",player.position.z)
			get_tree().quit(0)
			return
		await get_tree().physics_frame
	for index in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider:
			print("Last route contact ", collider.get_path(), " | normal ", collision.get_normal())
	push_error("STUDY_ROUTE FAIL | "+str(player.position))
	get_tree().quit(1)

func _capture() -> void:
	_apply_daylight()
	if DisplayServer.get_name()=="headless":
		push_error("Actual renderer required; headless output is not visual evidence.")
		get_tree().quit(2)
		return
	var dir:=OS.get_environment("DAYLIGHT_CAPTURE_DIR")
	if dir.is_empty():dir="res://calibration_daylight/review/"+VERSION
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var args := OS.get_cmdline_user_args()
	_set_clay(true)
	_set_view(0)
	if not await _save_frame(dir, "clay_geometry"): return
	_set_view(5)
	if not await _save_frame(dir, "clay_overview"): return
	_set_clay(false)
	if "--study-blockout" in args:
		get_tree().quit()
		return
	var names := ["reference", "tree_close", "grass_rock_close", "secondary", "cliff_side", "cliff_overview", "reverse_trail", "trail_bend"]
	for index in range(names.size()):
		_set_view(index)
		if not await _save_frame(dir, names[index]): return
	for index in MaterialStudies.VIEWS.size():
		_set_view(8 + index)
		if not await _save_frame(dir, MaterialStudies.VIEWS[index][0]): return
	_set_view(0)
	_apply_sunset()
	if not await _save_frame(dir, "lighting_sunset"): return
	if "--study-review" in args:
		_apply_daylight()
		get_window().size = Vector2i(960, 540)
		await get_tree().process_frame
		await _capture_motion()
	else:
		get_tree().quit()

func _set_clay(enabled: bool) -> void:
	rock_mat.set_shader_parameter("clay_mode", enabled)
	meadow_mat.set_shader_parameter("clay_mode", enabled)
	get_node("DaylightVegetation").visible = not enabled
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("MountainRange_"):
			child.material_override.set_shader_parameter("clay_mode", enabled)

func _save_frame(folder: String, label: String) -> bool:
	for frame in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture := get_viewport().get_texture().get_image()
	var error := capture.save_png(folder.path_join(label + ".png"))
	print("STUDY_CAPTURE ", label, " | ", capture.get_size(), " | ", error)
	if error != OK:
		push_error("Capture failed: " + label)
		get_tree().quit(2)
	return error == OK

func _capture_motion(use_safe_rail: bool = false) -> void:
	_apply_daylight()
	if DisplayServer.get_name() == "headless":
		push_error("Actual renderer required for motion evidence.")
		get_tree().quit(2)
		return
	var output := OS.get_environment("DAYLIGHT_CAPTURE_DIR")
	if output.is_empty(): output = "res://calibration_daylight/review/" + VERSION
	var folder := output.path_join("motion_frames")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var rail: JSON = load("res://calibration_daylight/assets/cliff_sweep_safe.json") if use_safe_rail else CLIFF_SWEEP
	if not rail or not (rail.data is Array) or rail.data.size() != CLIFF_SWEEP.data.size():
		push_error("Expected a complete fixed camera rail.")
		get_tree().quit(2)
		return
	var poses: Array = rail.data
	for index in range(poses.size()):
		var eye: Array = poses[index][0]
		var target: Array = poses[index][1]
		camera.position = Vector3(eye[0], eye[1], eye[2])
		camera.look_at(Vector3(target[0], target[1], target[2]))
		leaf_mat.set_shader_parameter("frozen_time", float(index) / 18.0)
		grass_mat.set_shader_parameter("frozen_time", float(index) / 18.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		if capture.save_png(folder.path_join("frame_%03d.png" % index)) != OK:
			push_error("Motion frame save failed: " + str(index))
			get_tree().quit(1)
			return
	print("STUDY_SAFE_MOTION " if use_safe_rail else "STUDY_MOTION ", poses.size(), " actual frames | 18 samples/sec | cliff foot sweep | ", VERSION)
	get_tree().quit()

func _set_afternoon_response(cloud_warmth: float, transmission: float, plane_blend: float) -> void:
	var sky_material := study_environment.sky.sky_material as ShaderMaterial
	sky_material.set_shader_parameter("cloud_warmth", cloud_warmth)
	grass_mat.set_shader_parameter("transmission_strength", transmission)
	leaf_mat.set_shader_parameter("transmission_strength", transmission)
	plane_weight = plane_blend
	_set_illustration_light(illustration_enabled)

func _apply_afternoon() -> void:
	_set_study_hour(TerraceLighting.AFTERNOON_HOUR)

func _apply_sunset() -> void:
	_set_study_hour(TerraceLighting.DUSK_HOUR)

func _apply_daylight() -> void:
	_set_study_hour(TerraceLighting.DAY_HOUR)

func _set_study_hour(hour: float) -> void:
	study_hour = clampf(hour, TerraceLighting.DAY_HOUR, TerraceLighting.DUSK_HOUR)
	var state := TerraceLighting.at_hour(study_hour)
	sun.rotation_degrees = Vector3(state.sun_pitch, state.sun_yaw, 0)
	sun.light_color = state.direct
	sun.light_energy = state.direct_energy
	study_environment.ambient_light_color = state.fill
	study_environment.ambient_light_energy = state.ambient_energy
	study_environment.fog_light_color = state.fog
	_set_material_environment(state.fill, state.material_fill)
	var sky_material := study_environment.sky.sky_material as ShaderMaterial
	sky_material.set_shader_parameter("energy", state.sky_energy)
	sky_material.set_shader_parameter("clear_sky_tint", state.clear_tint)
	_set_afternoon_response(state.cloud_warmth, state.transmission, state.planes)
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("MountainRange_"):
			child.material_override.set_shader_parameter("haze_color", state.haze)

func _set_material_environment(color:Color,strength:float) -> void:
	for material in [rock_mat,meadow_mat,grass_mat,leaf_mat]:
		material.set_shader_parameter("environment_color",color)
		material.set_shader_parameter("environment_strength",strength)
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("MountainRange_"):
			child.material_override.set_shader_parameter("environment_color",color)
			child.material_override.set_shader_parameter("environment_strength",strength)
			child.material_override.set_shader_parameter("sun_direction",sun.global_transform.basis.z.normalized())
			child.material_override.set_shader_parameter("sun_color",sun.light_color)
			child.material_override.set_shader_parameter("sun_energy",sun.light_energy)

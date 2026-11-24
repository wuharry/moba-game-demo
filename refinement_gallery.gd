extends Node3D

const LOCATIONS := [
	["北盆地壓力站", "basin", "res://station_world.gd"],
	["潮鎖棧岸", "tide", "res://refine_tide.gd"],
	["日藤庭院", "sunvine", "res://refine_sunvine.gd"],
	["硃萼雨庭", "grove", "res://refine_grove.gd"],
]
const PLAYER_MODEL := preload("res://station_runner.gd")
const SPEED := 4.65
const FINAL_BASIN_ROUND := 33
const LAST_BASIN_TRIAL := 33

var stage := Node3D.new()
var camera := Camera3D.new()
var ui := CanvasLayer.new()
var current := Label.new()
var help := Label.new()
var world: Node3D
var player: CharacterBody3D
var runner: Node3D
var points := PackedVector2Array()
var index := 0
var view_index := -1
var follow_initialized := false
var route_test := false
var capture_dir := ""
var only_index := -1
var basin_round := FINAL_BASIN_ROUND
var test_velocity := Vector3.ZERO
var failed := false


func _ready() -> void:
	add_child(stage)
	add_child(camera)
	camera.near = 0.06
	camera.far = 234.0
	camera.make_current()
	_build_menu()
	for argument in OS.get_cmdline_user_args():
		if argument == "--gallery-walk":
			route_test = true
		elif argument.begins_with("--gallery-capture="):
			capture_dir = argument.trim_prefix("--gallery-capture=")
		elif argument.begins_with("--gallery-map="):
			only_index = argument.trim_prefix("--gallery-map=").to_int()
		elif argument.begins_with("--basin-round="):
			basin_round = clampi(argument.trim_prefix("--basin-round=").to_int(), 0, LAST_BASIN_TRIAL)
	if not capture_dir.is_empty():
		if not capture_dir.is_absolute_path():
			capture_dir = ProjectSettings.globalize_path("res://" + capture_dir.trim_prefix("./"))
		ui.hide()
		_capture.call_deferred()
	elif route_test:
		_verify.call_deferred()
	elif not _load_location(0):
		get_tree().quit(1)


func _build_menu() -> void:
	add_child(ui)
	var panel := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.036, 0.068, 0.073, 0.87)
	frame.border_color = Color("#7dac9b")
	frame.border_width_left = 2
	frame.set_corner_radius_all(6)
	frame.content_margin_left = 15
	frame.content_margin_right = 16
	frame.content_margin_top = 9
	frame.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", frame)
	ui.add_child(panel)
	panel.position = Vector2(22, 19)
	current.add_theme_font_size_override("font_size", 21)
	current.add_theme_color_override("font_color", Color("#fff0d6"))
	panel.add_child(current)
	ui.add_child(help)
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_outline_color", Color("#102023"))
	help.add_theme_constant_override("outline_size", 5)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 22
	help.offset_top = -42
	help.offset_bottom = -17
	help.text = "WASD 移動  ｜  1–4 切換場景  ｜  C 比較鏡位  ｜  E 互動  ｜  Tab 壓力站"


func _load_location(next_index: int) -> bool:
	index = next_index
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	player = null
	world = null
	view_index = -1
	follow_initialized = false
	var environment_script := load(LOCATIONS[index][2]) as Script
	if environment_script == null or not environment_script.can_instantiate():
		push_error("Could not load " + str(LOCATIONS[index][0]))
		return false
	world = environment_script.new()
	if index == 0:
		world.set("refinement_round", basin_round)
	stage.add_child(world)
	points = world.call("route")
	if points.size() < 2:
		push_error("No playable route in " + str(LOCATIONS[index][0]))
		return false
	player = CharacterBody3D.new()
	player.name = "Walker"
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = 0.32
	player.floor_max_angle = deg_to_rad(48)
	player.position = Vector3(points[0].x, 0.65, points[0].y)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.74
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.87
	player.add_child(collider)
	runner = PLAYER_MODEL.new()
	runner.rotation.y = PI
	player.add_child(runner)
	stage.add_child(player)
	current.text = str(LOCATIONS[index][0])
	_follow_camera(0.0)
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_load_location(event.physical_keycode - KEY_1)
		KEY_C:
			var views: Array = world.call("review_views")
			view_index += 1
			if view_index == views.size():
				view_index = -1
				follow_initialized = false
			else:
				_set_view(views[view_index])
		KEY_E:
			if index == 0 and Vector2(player.position.x, player.position.z + 2.45).length() < 1.8:
				world.call("set_power", true)
		KEY_TAB:
			get_tree().change_scene_to_file("res://station.tscn")
		KEY_ESCAPE:
			get_tree().quit()


func _follow_camera(delta: float) -> void:
	var focus := player.position + Vector3(0, 0.85, -1.8)
	var goal := focus + Vector3(0, 12.8, 11.7)
	if not follow_initialized:
		camera.position = goal
		follow_initialized = true
	else:
		camera.position = camera.position.lerp(goal, 1.0 - exp(-11.0 * delta))
	camera.look_at(focus, Vector3.UP)
	camera.fov = 53.0


func _set_view(view: Array) -> void:
	camera.position = view[0]
	camera.look_at(view[1], Vector3.UP)
	camera.fov = float(view[2])


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var direction := test_velocity
	if not route_test and capture_dir.is_empty():
		direction = Vector3(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			0,
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		).normalized()
	player.velocity.x = direction.x * SPEED
	player.velocity.z = direction.z * SPEED
	player.velocity.y = maxf(-23, player.velocity.y - 24.0 * delta)
	player.move_and_slide()
	if direction.length_squared() > 0.08:
		runner.rotation.y = lerp_angle(runner.rotation.y, atan2(direction.x, direction.z), 1 - exp(-15.0 * delta))
	var real := player.get_real_velocity()
	runner.call("set_motion", Vector2(real.x, real.z).length(), delta)
	if player.position.y < -8 and not route_test:
		player.position = Vector3(points[0].x, 1.2, points[0].y)
		player.velocity = Vector3.ZERO
	if view_index == -1:
		_follow_camera(delta)


func _selected() -> Array:
	return [only_index] if only_index >= 0 else range(LOCATIONS.size())


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendered window.")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for item in _selected():
		if not _load_location(item):
			failed = true
			continue
		for step in range(32):
			await get_tree().physics_frame
		if item == 0:
			world.call("set_power", true)
		var views: Array = world.call("review_views")
		if views.size() < 2:
			push_error("Missing reference cameras.")
			failed = true
			continue
		for number in range(2):
			view_index = number
			_set_view(views[number])
			for frame in range(18):
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var name := "%s_%s.png" % [LOCATIONS[item][1], ["ground", "overhead"][number]]
			var outcome := image.save_png(capture_dir.path_join(name))
			print("CAPTURE | %s | %s" % [name, error_string(outcome)])
			failed = failed or outcome != OK
	get_tree().quit(int(failed))


func _verify() -> void:
	for item in _selected():
		if not _load_location(item):
			failed = true
			continue
		for step in range(52):
			await get_tree().physics_frame
		var distance := 0.0
		var reached := 0
		for mark in range(1, points.size()):
			if not await _walk_to(points[mark]):
				failed = true
				break
			distance += points[mark].distance_to(points[mark - 1])
			reached += 1
		print("ROUTE | %s | %d/%d | %.2f m | %s" % [
			LOCATIONS[item][1], reached, points.size() - 1, distance,
			"PASS" if reached == points.size() - 1 else str(player.position)
		])
	get_tree().quit(int(failed))


func _walk_to(target: Vector2) -> bool:
	for step in range(310):
		var offset := target - Vector2(player.position.x, player.position.z)
		if offset.length() < 0.15:
			test_velocity = Vector3.ZERO
			return player.is_on_floor()
		test_velocity = Vector3(offset.x, 0, offset.y).normalized()
		await get_tree().physics_frame
		if player.position.y < -6:
			break
	test_velocity = Vector3.ZERO
	return false


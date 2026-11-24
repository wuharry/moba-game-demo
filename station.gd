extends Node3D

const WORLD := "res://station_world.gd"
const RUNNER := "res://station_runner.gd"
const SPAWN := Vector3(0, 0.55, 11)
const CONSOLE := Vector3(0, 0, -2.45)
const USE_DISTANCE := 1.8
const WALK_SPEED := 4.55
const SPRINT_SPEED := 6.65

var world: Node3D
var body := CharacterBody3D.new()
var runner: Node3D
var camera := Camera3D.new()
var progress := Label.new()
var objective := Label.new()
var notice := Label.new()
var canvas := CanvasLayer.new()
var powered := false
var close_camera := false
var camera_placed := false
var automated := false
var test_direction := Vector3.ZERO
var capture_path := ""


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	automated = arguments.has("--station-test")
	for argument in arguments:
		if argument.begins_with("--station-capture="):
			capture_path = argument.trim_prefix("--station-capture=")
			automated = true
	if not capture_path.is_empty() and not capture_path.is_absolute_path():
		capture_path = ProjectSettings.globalize_path("res://" + capture_path.trim_prefix("./"))
	if not _build_level():
		set_physics_process(false)
		get_tree().quit(1)
		return
	if automated:
		_verify_route.call_deferred()


func _build_level() -> bool:
	var world_script := load(WORLD) as Script
	var runner_script := load(RUNNER) as Script
	if world_script == null or not world_script.can_instantiate():
		push_error("Station world did not load.")
		return false
	if runner_script == null or not runner_script.can_instantiate():
		push_error("Station runner did not load.")
		return false
	world = world_script.new()
	add_child(world)
	body.name = "Player"
	body.collision_layer = 2
	body.collision_mask = 1
	body.floor_snap_length = 0.38
	body.floor_max_angle = deg_to_rad(48.0)
	body.position = SPAWN
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.76
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.88
	body.add_child(shape)
	runner = runner_script.new()
	body.add_child(runner)
	runner.rotation.y = PI
	add_child(body)
	add_child(camera)
	camera.make_current()
	camera.near = 0.05
	camera.far = 150
	_plot_camera(1.0)
	_build_hud()
	_update_interface()
	return true


func _build_hud() -> void:
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(26, 24)
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.04, 0.076, 0.087, 0.86)
	backing.border_color = Color("#639b96")
	backing.border_width_left = 2
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 17
	backing.content_margin_top = 11
	backing.content_margin_right = 17
	backing.content_margin_bottom = 11
	panel.add_theme_stylebox_override("panel", backing)
	canvas.add_child(panel)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	panel.add_child(lines)
	var title := Label.new()
	title.text = "北盆地壓力站"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#eee4cc"))
	lines.add_child(title)
	lines.add_child(progress)
	lines.add_child(objective)
	for label in [progress, objective]:
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("#c0d3d0"))
	notice.text = "WASD 移動 ｜ Shift 奔跑 ｜ E 互動 ｜ C 鏡頭 ｜ G 四景比較 ｜ Tab 美術試驗場"
	notice.add_theme_font_size_override("font_size", 15)
	notice.add_theme_color_override("font_outline_color", Color("#102023"))
	notice.add_theme_constant_override("outline_size", 5)
	canvas.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	notice.offset_left = 27.0
	notice.offset_top = -44.0
	notice.offset_bottom = -18.0


func _physics_process(delta: float) -> void:
	var direction := test_direction if automated else _input_direction()
	var speed := SPRINT_SPEED if not automated and Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	body.velocity.x = speed * direction.x
	body.velocity.z = speed * direction.z
	body.velocity.y = maxf(-25.0, body.velocity.y - 23.0 * delta)
	body.move_and_slide()
	if direction.length_squared() > 0.09:
		runner.rotation.y = lerp_angle(runner.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-16.0 * delta))
	if runner.has_method("set_motion"):
		var movement := body.get_real_velocity()
		runner.call("set_motion", Vector2(movement.x, movement.z).length(), delta)
	if body.position.y < -6.0 and not automated:
		body.position = SPAWN
		body.velocity = Vector3.ZERO
		camera_placed = false
	_plot_camera(delta)
	if not automated:
		_update_interface()


func _input_direction() -> Vector3:
	return Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		0.0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).normalized()


func _plot_camera(delta: float) -> void:
	var focus := body.position + Vector3(0, 0.8, -1.9)
	var offset := Vector3(0, 12.3, 10.4)
	if close_camera:
		focus = body.position + Vector3(0, 1.35, -2.75)
		offset = Vector3(2.4, 3.0, 7.7)
	var goal := focus + offset
	if camera_placed:
		camera.position = camera.position.lerp(goal, 1.0 - exp(-10.0 * delta))
	else:
		camera_placed = true
		camera.position = goal
	camera.look_at(focus, Vector3.UP)
	camera.fov = 59.0 if close_camera else 55.0


func _unhandled_key_input(event: InputEvent) -> void:
	if automated or event is not InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_E:
			_use_console()
		KEY_C:
			close_camera = not close_camera
		KEY_G:
			get_tree().change_scene_to_file("res://refinement_gallery.tscn")
		KEY_TAB:
			get_tree().change_scene_to_file("res://lookdev.tscn")
		KEY_ESCAPE:
			get_tree().quit()


func _can_reach_console() -> bool:
	return Vector2(body.position.x - CONSOLE.x, body.position.z - CONSOLE.z).length() <= USE_DISTANCE


func _update_interface() -> void:
	if powered:
		progress.text = "壓力站已供電"
		objective.text = "沿右側步道繞過調節器"
	elif _can_reach_console():
		progress.text = "壓力站待機"
		objective.text = "按 E 恢復供電"
	else:
		progress.text = "壓力站待機"
		objective.text = "沿著主路靠近調節器"


func _use_console() -> bool:
	if powered or not _can_reach_console():
		return false
	powered = true
	if world.has_method("set_power"):
		world.call("set_power", true)
	_update_interface()
	return true


func _go_to(destination: Vector2, max_ticks: int = 260) -> bool:
	for tick in range(max_ticks):
		var displacement := destination - Vector2(body.position.x, body.position.z)
		if displacement.length() <= 0.135:
			test_direction = Vector3.ZERO
			return body.is_on_floor()
		test_direction = Vector3(displacement.x, 0, displacement.y).normalized()
		await get_tree().physics_frame
		if body.position.y < -5.0:
			break
	test_direction = Vector3.ZERO
	return false


func _verify_route() -> void:
	for tick in range(45):
		await get_tree().physics_frame
	if not body.is_on_floor() or _use_console():
		_fail("spawn contact / interaction range")
		return
	if not await _go_to(Vector2(0, -2.42)):
		_fail("main route")
		return
	print("PASS | main route | 13.4 m")
	if not capture_path.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_path)
		if not await _go_to(Vector2(-0.62, -2.31)):
			_fail("approach camera mark")
			return
		runner.rotation.y = atan2(-body.position.x, -5.0 - body.position.z)
		close_camera = true
		await _capture("01_station_standby.png")
	if not _use_console() or not powered or not world.has_method("set_power"):
		_fail("station interaction / environment connection")
		return
	print("PASS | pressure station changed state through the interact function")
	if not capture_path.is_empty():
		await _capture("02_station_powered.png")
	test_direction = Vector3.FORWARD
	for tick in range(100):
		await get_tree().physics_frame
	test_direction = Vector3.ZERO
	if not body.is_on_floor() or body.position.z < -5.0 or body.position.z > -3.3:
		_fail("imported landmark collision (player z=%.2f)" % body.position.z)
		return
	print("PASS | landmark blocks player at z=%.2f" % body.position.z)
	for point in [Vector2(1, -2.32), Vector2(5, -2.32), Vector2(5, -9.2), Vector2(0, -9.2)]:
		if not await _go_to(point):
			_fail("bypass at %s (player %s)" % [point, body.position])
			return
	print("PASS | side route reconnects behind the imported landmark")
	if not capture_path.is_empty():
		close_camera = false
		await _go_to(Vector2(5, -2.32))
		await _go_to(Vector2(2.7, 3.0))
		await _capture("03_station_play_camera.png")
	get_tree().quit()


func _capture(filename: String) -> void:
	for tick in range(30):
		await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(capture_path.path_join(filename)) != OK:
		push_error("Capture failed: " + filename)


func _fail(stage: String) -> void:
	push_error("FAIL | " + stage + " | " + str(body.position))
	get_tree().quit(1)


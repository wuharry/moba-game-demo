extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check() -> void:
	var game = load("res://calibration_daylight/daylight.tscn").instantiate()
	root.add_child(game)
	_key(KEY_M, true)
	_key(KEY_M, false)
	await physics_frame
	if not game.moba or not game.scout.visible or game.camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		quit(2)
		return
	var locked: Transform3D = game.camera.global_transform
	_key(KEY_N, true)
	_key(KEY_N, false)
	if not game.miniature_material or game.camera.global_transform != locked:
		push_error("Material toggle changed the camera or failed to switch to B.")
		quit(2)
		return
	for material: ShaderMaterial in [game.rock_mat, game.meadow_mat, game.grass_mat]:
		if material.get_shader_parameter("miniature_material") != 1.0:
			push_error("Material toggle failed to update a shared surface.")
			quit(2)
			return
	_key(KEY_N, true)
	_key(KEY_N, false)
	if game.miniature_material:
		push_error("Material toggle did not restore A.")
		quit(2)
		return
	var start: Vector3 = game.player.position
	_key(KEY_W, true)
	for tick in 45: await physics_frame
	_key(KEY_W, false)
	var finish: Vector3 = game.player.position
	var distance := Vector2(start.x,start.z).distance_to(Vector2(finish.x,finish.z))
	var offset_error: float = game.camera.position.distance_to(finish+game.MOBA_OFFSET+Vector3(0,.65,-2.4))
	_key(KEY_1, true)
	_key(KEY_1, false)
	await physics_frame
	if distance < 1.0 or offset_error > .01 or game.moba or game.scout.visible or game.camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		push_error("Camera transition or following failed. distance=%f offset error=%f" % [distance, offset_error])
		quit(2)
		return
	print("MOBA_CONTROL PASS | A/B toggle kept camera | player travel ",distance," m | follow error ",offset_error," m | returned to main")
	quit()

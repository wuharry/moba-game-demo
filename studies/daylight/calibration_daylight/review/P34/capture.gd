extends SceneTree

const BASELINE_Z := 4.0
const MOTION_FRAMES := 24

func _initialize() -> void:
	call_deferred("_run")

func _place_scout(scene: Node3D, z: float) -> void:
	var x: float = scene.Terrain.path_center(z)
	scene.player.position = Vector3(x, scene.Terrain.ground_height(x, z) + .01, z)
	scene._moba_follow()

func _run() -> void:
	var output := OS.get_environment("P34_REVIEW_DIR")
	var interactive := "--interactive" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or (output.is_empty() and not interactive):
		push_error("P34 review requires a windowed renderer and P34_REVIEW_DIR.")
		quit(2)
		return
	var scene: Node3D = load("res://calibration_daylight/daylight.tscn").instantiate()
	root.add_child(scene)
	scene.grass_mat.set_shader_parameter("frozen_time", 0.0)
	scene.leaf_mat.set_shader_parameter("frozen_time", 0.0)
	scene._apply_daylight()
	if interactive:
		scene._activate_moba()
		_place_scout(scene, BASELINE_Z)
		return
	scene._set_view(0)
	if OS.get_environment("P34_WALL_ONLY") == "1":
		scene._set_miniature_material(true)
		await _save_wall(scene, output)
		quit()
		return
	if not await scene._save_frame(output.path_join("captures"), "A_fixed_day"): return
	scene._set_miniature_material(true)
	if not await scene._save_frame(output.path_join("captures"), "B_fixed_day"): return

	if not await _save_wall(scene, output): return

	scene._activate_moba()
	_place_scout(scene, BASELINE_Z)
	var fixed_camera: Transform3D = scene.camera.global_transform
	# The review steps poses explicitly. Disable player input integration during
	# these takes so A and B use the identical location and camera at every frame.
	scene.set_physics_process(false)
	for preset: String in ["day", "afternoon", "dusk"]:
		match preset:
			"day": scene._apply_daylight()
			"afternoon": scene._apply_afternoon()
			"dusk": scene._apply_sunset()
		for variant: String in ["A", "B"]:
			scene._set_miniature_material(variant == "B")
			if not await scene._save_frame(output.path_join("captures"), variant + "_moba_" + preset):
				return
			assert(scene.camera.global_transform == fixed_camera)
			print("P34_LOCKED ", variant, " ", preset, " | ", fixed_camera, " | size ", scene.camera.size)

	if OS.get_environment("P34_STILLS_ONLY") != "1":
		scene._apply_daylight()
		for variant: String in ["A", "B"]:
			scene._set_miniature_material(variant == "B")
			for frame in MOTION_FRAMES:
				var progress := float(frame) / float(MOTION_FRAMES - 1)
				_place_scout(scene, lerpf(BASELINE_Z + 1.5, BASELINE_Z - 3.0, progress))
				if not await scene._save_frame(output.path_join("frames").path_join(variant), "%03d" % frame):
					return
	print("P34_CAPTURE_COMPLETE")
	quit()


func _save_wall(scene: Node3D, output: String) -> bool:
	scene.camera.position = Vector3(11.0, 8.1, 10.0)
	scene.camera.look_at(Vector3(-8.3, 6.0, -13.0))
	return await scene._save_frame(output.path_join("captures"), "B_wall_day")

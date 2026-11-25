extends SceneTree

# World-space eye and target with vertical FOV. Keep these exact between material revisions.
# The same resource can be preloaded by the interactive scene to recall a study with apply_pose().
const VIEWS := [
	["grass_study", Vector3(25.3, 4.14, 18.75), Vector3(22.4, 3.02, 15.5), 48.0],
	["stone_study", Vector3(26.95, 4.08, -2.24), Vector3(29.4, 1.93, -1.1), 27.0],
	["shade_study", Vector3(-1.2, 2.71, 13.8), Vector3(-4.45, 1.57, 10.35), 47.0],
]

static func apply_pose(camera: Camera3D, index: int) -> void:
	var view: Array = VIEWS[index]
	camera.global_position = view[1]
	camera.look_at(view[2], Vector3.UP)
	camera.fov = view[3]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var output := OS.get_environment("DAYLIGHT_CAPTURE_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Material studies require a real renderer and DAYLIGHT_CAPTURE_DIR.")
		quit(2)
		return
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Cannot create material study output directory: " + str(error))
		quit(1)
		return
	var scene: Node3D = load("res://calibration_daylight/daylight.tscn").instantiate()
	root.add_child(scene)
	scene._apply_daylight()
	scene.grass_mat.set_shader_parameter("frozen_time", 0.0)
	scene.leaf_mat.set_shader_parameter("frozen_time", 0.0)
	for i in VIEWS.size():
		apply_pose(scene.camera, i)
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		var label: String = VIEWS[i][0]
		error = capture.save_png(output.path_join(label + ".png"))
		print("STUDY_CAPTURE ", label, " | ", capture.get_size(), " | ", error)
		if error != OK:
			quit(1)
			return
	quit(0)

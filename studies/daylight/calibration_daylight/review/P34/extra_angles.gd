extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var folder := OS.get_environment("P34_ANGLE_DIR")
	if DisplayServer.get_name() == "headless" or folder.is_empty():
		push_error("Windowed Godot and P34_ANGLE_DIR are required.")
		quit(2)
		return
	var scene: Node3D = load("res://calibration_daylight/daylight.tscn").instantiate()
	root.add_child(scene)
	scene._apply_daylight()
	scene._set_miniature_material(true)
	scene.grass_mat.set_shader_parameter("frozen_time", 0.0)
	scene.leaf_mat.set_shader_parameter("frozen_time", 0.0)
	var foot := Vector3(-10.3, 2.725091, -1.9)
	var views := [
		["Valley_Low", foot, Vector3(-21.0,6.7,-6.5), 58.0],
		["High_Oblique", Vector3(-1.0,30.0,15.7), Vector3(-22.5,4.8,-7.4), 52.0],
		["West_Overview", Vector3(-46.0,20.0,29.0), Vector3(-13.6,6.1,-17.0), 60.0],
		["Plateau_Back", Vector3(-30.8,25.5,-25.2), Vector3(-16.3,3.7,3.5), 56.0],
	]
	for view in views:
		scene.camera.position = view[1]
		scene.camera.fov = view[3]
		scene.camera.look_at(view[2])
		if not await scene._save_frame(folder,view[0]):
			return
		print("P34_ANGLE ",view[0]," | ",view[1]," | ",view[2]," | FOV ",view[3])
	print("P34_EXTRA_ANGLES_COMPLETE")
	quit()

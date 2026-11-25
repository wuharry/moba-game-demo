extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 var s=load("res://calibration_daylight/daylight.tscn").instantiate()
 root.add_child(s)
 s._set_view(0)
 for i in 3: await physics_frame
 var space=s.get_world_3d().direct_space_state
 for p in [Vector2(600,500),Vector2(750,540),Vector2(800,500),Vector2(900,480),Vector2(1000,560),Vector2(680,600),Vector2(450,560)]:
  var a=s.camera.project_ray_origin(p)
  var b=a+s.camera.project_ray_normal(p)*300
  var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
  print("GROUND ",p," = ",hit.get("position","NONE"))
 quit()

extends SceneTree
## Check the recorded safe rail against the current terrain without writing scene assets.
const Terrain = preload("res://calibration_daylight/terrain.gd")
const ORIGINAL := "res://calibration_daylight/assets/cliff_sweep.json"
const SAFE := "res://calibration_daylight/assets/cliff_sweep_safe.json"
const EYE_MIN := 1.30
const NEAR_MIN := 1.25
const SAMPLE_STEPS := 16
const ASPECT := 1280.0 / 720.0
const NEAR := .05
const FOV_DEG := 60.0

static func _v(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])

# The review rail uses a 60 degree vertical field of view (KEEP_HEIGHT).
# Measure the eye and all near-plane corners with the actual camera pitch.
static func _clearance(eye: Vector3, aim: Vector3) -> Vector2:
	var front := (aim-eye).normalized()
	var right := front.cross(Vector3.UP).normalized()
	var up := right.cross(front)
	var half_height := NEAR*tan(deg_to_rad(FOV_DEG)*.5)
	var near_centre := eye+front*NEAR
	var corners := INF
	for sx in [-1.0,1.0]:
		for sy in [-1.0,1.0]:
			var corner := near_centre + right*(float(sx)*half_height*ASPECT) + up*(float(sy)*half_height)
			corners=minf(corners,corner.y-Terrain.ground_height(corner.x,corner.z))
	return Vector2(eye.y-Terrain.ground_height(eye.x,eye.z),corners)

static func _segment(a: Array, b: Array, step: int) -> Vector2:
	var t:=float(step)/SAMPLE_STEPS
	return _clearance(_v(a[0]).lerp(_v(b[0]),t),_v(a[1]).lerp(_v(b[1]),t))

static func _measure(rail: Array) -> Dictionary:
	var worst:=Vector2(INF,INF)
	var eye_at:=0.0
	var corners_at:=0.0
	var buried_frames: Array[int]=[]
	for i in range(rail.size()-1):
		for k in range(SAMPLE_STEPS+1):
			if i>0 and k==0: continue
			var here:=float(i)+float(k)/SAMPLE_STEPS
			var c:=_segment(rail[i],rail[i+1],k)
			if c.x<worst.x:
				worst.x=c.x
				eye_at=here
			if c.y<worst.y:
				worst.y=c.y
				corners_at=here
			if k%SAMPLE_STEPS==0 and c.x<0: buried_frames.append(roundi(here))
	return {"eye_min_m":worst.x,"eye_min_at":eye_at,"corner_min_m":worst.y,"corner_min_at":corners_at,"buried_keyframes":buried_frames}

func _initialize() -> void:
	var original: Array=JSON.parse_string(FileAccess.get_file_as_string(ORIGINAL))
	var recorded=JSON.parse_string(FileAccess.get_file_as_string(SAFE))
	if not recorded is Array or recorded.size()!=original.size():
		push_error("Missing camera rail or pose count mismatch")
		quit(1)
		return
	var max_lift:=0.0
	var changed: Array[int]=[]
	for i in range(recorded.size()):
		var delta:=_v(recorded[i][0])-_v(original[i][0])
		var target_delta:=_v(recorded[i][1])-_v(original[i][1])
		if absf(delta.x)+absf(delta.z)>.00005 or delta.distance_to(target_delta)>.00005:
			push_error("Camera XZ or direction changed at "+str(i))
			quit(1)
			return
		if delta.y>.00001: changed.append(i)
		max_lift=maxf(max_lift,delta.y)
	var legacy:=_measure(original)
	var clearance:=_measure(recorded)
	var audit:={"original_sha256":FileAccess.get_sha256(ORIGINAL),"safe_sha256":FileAccess.get_sha256(SAFE),
		"resolution":[1280,720],"vertical_fov_deg":FOV_DEG,"near_plane_m":NEAR,"substeps_per_segment":SAMPLE_STEPS,
		"tested_poses":(recorded.size()-1)*SAMPLE_STEPS+1,"samples_per_pose":5,"original":legacy,"safe":clearance,
		"changed_frames":changed,"max_lift_m":max_lift,"eye_requirement_m":EYE_MIN,"near_corner_requirement_m":NEAR_MIN}
	if clearance.eye_min_m<EYE_MIN-.001 or clearance.corner_min_m<NEAR_MIN-.001:
		push_error("Camera rail validation failed: " + JSON.stringify(audit))
		quit(1)
		return
	print("SWEEP_CLEARANCE PASS ",JSON.stringify(audit))
	quit()

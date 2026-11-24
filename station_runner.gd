extends Node3D
## Blends a stationary authored animation with a speed-driven locomotion pose.

const RUNNER := preload("res://models/fog_runner.glb")
const HIPS := "J_Bip_C_Hips"
const SPINE := "J_Bip_C_Spine"
const LEFT := ["J_Bip_L_UpperLeg", "J_Bip_L_LowerLeg", "J_Bip_L_Foot", "J_Bip_L_UpperArm", "J_Bip_L_LowerArm"]
const RIGHT := ["J_Bip_R_UpperLeg", "J_Bip_R_LowerLeg", "J_Bip_R_Foot", "J_Bip_R_UpperArm", "J_Bip_R_LowerArm"]

var skeleton: Skeleton3D
var animator: AnimationPlayer
var hips: int
var spine: int
var left: Array[int]
var right: Array[int]
var tracked_bones: Array[int]
var idle_rotations: Array[Quaternion]
var idle_hips: Vector3
var phase := 0.0
var gait_weight := 0.0


func _ready() -> void:
	var model := RUNNER.instantiate() as Node3D
	model.rotation.y = PI
	add_child(model)
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if rigs.is_empty() or players.is_empty():
		push_error("Fog Runner is missing its skeleton or idle clip.")
		return
	skeleton = rigs[0] as Skeleton3D
	animator = players[0] as AnimationPlayer
	hips = skeleton.find_bone(HIPS)
	spine = skeleton.find_bone(SPINE)
	left = _resolve_bones(LEFT)
	right = _resolve_bones(RIGHT)
	tracked_bones = left + right
	tracked_bones.append(spine)
	for clip in animator.get_animation_list():
		if "scout" in clip.to_lower():
			animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			animator.play(clip)
			animator.advance(0.0)
			_store_idle_pose()
			return
	push_error("Fog Runner's Scout idle animation was not found.")
	animator = null


func _resolve_bones(names: Array) -> Array[int]:
	var ids: Array[int] = []
	for bone_name in names:
		ids.append(skeleton.find_bone(bone_name))
		assert(ids[-1] >= 0, "Unknown Fog Runner bone: " + bone_name)
	return ids


func set_motion(speed: float, delta: float) -> void:
	if animator == null or delta <= 0.0:
		return
	# The glTF importer may omit constant tracks. Strip our previous overlay
	# before evaluating the clip so those bones keep their untouched pose.
	skeleton.set_bone_pose_position(hips, idle_hips)
	for i in tracked_bones.size():
		skeleton.set_bone_pose_rotation(tracked_bones[i], idle_rotations[i])
	animator.advance(delta)
	_store_idle_pose()
	var amount := smoothstep(0.08, 2.0, speed)
	gait_weight = lerpf(gait_weight, amount, 1.0 - exp(-12.0 * delta))
	if gait_weight < 0.005:
		phase = 0.0
		return

	phase = fmod(phase + TAU * lerpf(0.8, 2.45, clampf(speed / 6.0, 0.0, 1.0)) * delta, TAU)
	var stride := lerpf(0.43, 0.79, clampf(speed / 6.0, 0.0, 1.0))
	var foot_height := _lowest_foot()
	_pose_side(left, phase, stride, -1.0)
	_pose_side(right, phase + PI, stride, 1.0)
	_add_pitch(spine, -0.15 * gait_weight)
	var base_position := skeleton.get_bone_pose_position(hips)
	var float_height := _lowest_foot() - foot_height
	var bob := (1.0 - cos(phase * 2.0)) * 0.008 * gait_weight
	skeleton.set_bone_pose_position(hips, base_position + Vector3.UP * (bob - float_height))


func _store_idle_pose() -> void:
	idle_hips = skeleton.get_bone_pose_position(hips)
	idle_rotations.clear()
	for bone in tracked_bones:
		idle_rotations.append(skeleton.get_bone_pose_rotation(bone))


func _pose_side(bones: Array[int], step: float, stride: float, hand: float) -> void:
	var sweep := sin(step)
	var swing := maxf(cos(step), 0.0)
	_add_pitch(bones[0], sweep * stride * gait_weight)
	_add_pitch(bones[1], -(0.16 + swing * 0.94) * gait_weight)
	_add_pitch(bones[2], (0.20 + swing * 0.42 - sweep * 0.15) * gait_weight)
	_add_pitch(bones[3], -sweep * 0.42 * gait_weight)
	var elbow := skeleton.get_bone_pose_rotation(bones[4])
	skeleton.set_bone_pose_rotation(bones[4],
		elbow * Quaternion(Vector3.UP, hand * (0.35 - sweep * 0.15) * gait_weight))


func _add_pitch(bone: int, radians: float) -> void:
	skeleton.set_bone_pose_rotation(bone,
		Quaternion(Vector3.RIGHT, radians) * skeleton.get_bone_pose_rotation(bone))


func _lowest_foot() -> float:
	return minf(
		skeleton.get_bone_global_pose(left[2]).origin.y,
		skeleton.get_bone_global_pose(right[2]).origin.y
	)

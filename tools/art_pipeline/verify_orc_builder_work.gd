extends SceneTree

var out_path := "res://assets/generated/orcs/orc_builder_v1/"
var stem := "orc_builder_v1"
const ARM := ["upper_arm_r", "forearm_r", "hand_r"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--race=dwarf" in OS.get_cmdline_user_args():
		out_path = "res://assets/generated/dwarves/dwarf_builder_v1/"
		stem = "dwarf_builder_v1"
	var model := (load(out_path + stem + ".glb") as PackedScene).instantiate()
	root.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var chest := skeleton.find_bone("chest")
	var indices: Array[int] = []
	for name in ARM: indices.append(skeleton.find_bone(name))
	player.play("work")
	player.pause()
	player.seek(0.0, true)
	player.advance(0)
	skeleton.force_update_all_bone_transforms()
	var chest_start := skeleton.get_bone_global_pose(chest)
	var reference: Array[Transform3D] = []
	for index in indices: reference.append(skeleton.get_bone_global_pose(index))
	var wrist_start := reference[1].affine_inverse() * reference[2]
	var lengths := [reference[0].origin.distance_to(reference[1].origin), reference[1].origin.distance_to(reference[2].origin)]
	var max_plane_error := 0.0
	var max_roll_error := 0.0
	var max_wrist_error := 0.0
	var max_length_error := 0.0
	var max_frame_rotation := 0.0
	var max_wrist_frame := 0
	var previous: Array[Transform3D] = []
	# Half-frame samples check interpolation as well as the authored keys.
	for frame in range(289):
		player.seek(frame / 96.0, true)
		player.advance(0)
		skeleton.force_update_all_bone_transforms()
		var follow_inverse := chest_start * skeleton.get_bone_global_pose(chest).affine_inverse()
		var poses: Array[Transform3D] = []
		for index in indices: poses.append(skeleton.get_bone_global_pose(index))
		for j in range(3):
			var aligned := follow_inverse * poses[j]
			max_plane_error = maxf(max_plane_error, absf(aligned.origin.x - reference[j].origin.x))
			var delta := aligned.basis * reference[j].basis.inverse()
			max_roll_error = maxf(max_roll_error, (delta * Vector3.RIGHT).distance_to(Vector3.RIGHT))
			if not previous.is_empty():
				max_frame_rotation = maxf(max_frame_rotation, rad_to_deg(previous[j].basis.get_rotation_quaternion().angle_to(poses[j].basis.get_rotation_quaternion())))
		var wrist := poses[1].affine_inverse() * poses[2]
		if wrist.origin.distance_to(wrist_start.origin) > max_wrist_error:
			max_wrist_frame = frame
		max_wrist_error = maxf(max_wrist_error, wrist.origin.distance_to(wrist_start.origin))
		for axis in range(3): max_wrist_error = maxf(max_wrist_error, wrist.basis[axis].distance_to(wrist_start.basis[axis]))
		for j in range(2): max_length_error = maxf(max_length_error, absf(poses[j].origin.distance_to(poses[j + 1].origin) - lengths[j]))
		previous = poses
	print("ORC_WORK_METRICS ", [max_plane_error, max_roll_error, max_wrist_error, max_length_error, max_frame_rotation, max_wrist_frame])
	assert(max_plane_error < 0.0001, "Elbow/wrist moved sideways")
	assert(max_roll_error < 0.0001, "Arm rolled out of the swing plane")
	assert(max_wrist_error < 0.0001, "Wrist twisted relative to forearm")
	assert(max_length_error < 0.0001, "Arm joints separated")
	assert(max_frame_rotation < 10.0, "Abrupt arm rotation")
	var report := {"status": "PASS", "pose_samples": 289, "maximum_plane_error": max_plane_error,
		"maximum_roll_error": max_roll_error, "maximum_wrist_error": max_wrist_error,
		"maximum_length_error": max_length_error, "maximum_half_frame_rotation_degrees": max_frame_rotation}
	var file := FileAccess.open(out_path + "work_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ORC_WORK_VALIDATION " + JSON.stringify(report))
	model.free()
	quit()

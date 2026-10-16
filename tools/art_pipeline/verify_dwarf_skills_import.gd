extends SceneTree

var problems: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func bounds_for(mesh: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	var bounds := AABB()
	var first := true
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences := weights.size() / points.size()
		for index in points.size():
			var point := Vector3.ZERO
			for slot in influences:
				var weight := weights[index * influences + slot]
				if weight < 0.0001: continue
				var binding := indices[index * influences + slot]
				var bone := mesh.skin.get_bind_bone(binding)
				if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(binding))
				point += skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(binding) * points[index] * weight
			if not point.is_finite(): problems.append("Non-finite skin vertex")
			bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
			first = false
	return bounds

func poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count(): result.append(skeleton.get_bone_global_pose(bone))
	return result

func difference(before: Array[Transform3D], after: Array[Transform3D]) -> float:
	var result := 0.0
	for index in before.size():
		result = maxf(result, before[index].origin.distance_to(after[index].origin))
		for axis in 3: result = maxf(result, before[index].basis[axis].distance_to(after[index].basis[axis]))
	return result

func _run() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/dwarves/dwarf_troops_manifest.json"))
	var results: Array = []
	var total := 0
	for row: Dictionary in rows:
		var model := (load(row.path) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() != 1: problems.append(row.stem + ": consolidated mesh missing")
		var mesh := meshes[0] as MeshInstance3D
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(row.path.get_basename() + "_report.json"))
		var expected: Dictionary = report.skills.clips
		var clip_results := {}
		var listed := player.get_animation_list()
		if listed.size() != expected.size() + 3: problems.append(row.stem + ": unexpected clips")
		for clip: String in ["idle", "walk", "attack"]:
			if not player.has_animation(clip): problems.append(row.stem + ": lost " + clip)
		var hold_start: Array[Transform3D] = []
		var enter_end: Array[Transform3D] = []
		for role: String in expected:
			if not player.has_animation(role):
				problems.append(row.stem + ": missing " + role)
				continue
			var animation := player.get_animation(role)
			var info: Dictionary = expected[role]
			if abs(animation.length - float(info.seconds)) > 0.001: problems.append(row.stem + ": duration " + role)
			if animation.loop_mode != (Animation.LOOP_LINEAR if bool(info.loop) else Animation.LOOP_NONE): problems.append(row.stem + ": loop " + role)
			player.play(role)
			player.seek(0.0, true)
			var initial := poses(skeleton)
			var motion := 0.0
			var minimum := INF
			for sample in [0.0, 0.22, 0.34, 0.43, 0.52, 0.60, 0.72, 0.87, 1.0]:
				player.seek(animation.length * float(sample), true)
				motion = maxf(motion, difference(initial, poses(skeleton)))
				minimum = minf(minimum, bounds_for(mesh, skeleton).position.y)
			var recovery := difference(initial, poses(skeleton))
			if role == "shield_wall": enter_end = poses(skeleton)
			elif recovery > 0.001: problems.append(row.stem + ": recovery " + role)
			if role == "shield_wall_hold": hold_start = initial
			if minimum < -0.004: problems.append(row.stem + ": ground " + role)
			if motion < 0.001: problems.append(row.stem + ": motionless " + role)
			clip_results[role] = {"seconds": animation.length, "loop": bool(info.loop), "min_ground_y": minimum, "recovery_error": recovery, "motion": motion}
			player.stop()
		if not enter_end.is_empty() and difference(enter_end, hold_start) > 0.001: problems.append(row.stem + ": shield transition")
		total += expected.size()
		results.append({"stem": row.stem, "clips": clip_results, "bones": skeleton.get_bone_count()})
		model.free()
	var result := {"status": "PASS" if problems.is_empty() else "FAIL", "new_clips": total, "models": results, "problems": problems}
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
	print("DWARF_SKILLS_IMPORT_", result.status, ": ", total, " skills, ", results.size(), " native models; ", problems)
	quit(0 if problems.is_empty() else 1)

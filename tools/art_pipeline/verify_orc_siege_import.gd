extends SceneTree

var problems: Array[String] = []

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/orcs/orc_siege_manifest.json"))
	var results: Array = []
	for row: Dictionary in rows:
		var stem: String = row["stem"]
		var packed := load(row["path"]) as PackedScene
		if packed == null:
			problems.append(stem + ": import failed")
			continue
		var model := packed.instantiate() as Node3D
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if meshes.size() != 1 or skeletons.size() != 1:
			problems.append(stem + ": missing mesh or skeleton")
			model.free()
			continue
		if players.size() != 1:
			problems.append(stem + ": missing animation player")
			model.free()
			continue
		var player := players[0] as AnimationPlayer
		var skeleton := skeletons[0] as Skeleton3D
		var mesh := meshes[0] as MeshInstance3D
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/orcs/%s/%s_report.json" % [stem, stem]))
		if skeleton.get_bone_count() != report["rig"]["bones"].size(): problems.append(stem + ": lost pivot bones")
		if mesh.skin == null:
			problems.append(stem + ": lost skin")
			model.free()
			continue
		var clip_checks: Dictionary = {}
		var expected_clips: Dictionary = report["clips"]
		var actual_clips: Array[String] = []
		for clip in player.get_animation_list():
			if clip != "RESET": actual_clips.append(String(clip))
		if actual_clips.size() != expected_clips.size(): problems.append(stem + ": clip count mismatch")
		for clip: String in expected_clips:
			if not player.has_animation(clip):
				problems.append(stem + ": missing " + clip)
				continue
			var animation := player.get_animation(clip)
			var loops := clip.ends_with("_Idle") or clip.ends_with("_Walk")
			if abs(animation.length - float(expected_clips[clip])) > 0.001: problems.append(clip + ": wrong duration")
			if animation.loop_mode != (Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE): problems.append(clip + ": wrong loop flag")
			player.play(clip)
			player.seek(0.0, true)
			var start_poses: Array[Transform3D] = []
			for joint in skeleton.get_bone_count(): start_poses.append(skeleton.get_bone_global_pose(joint))
			var movement := 0.0
			var bone_motion: Dictionary = {}
			var independent_recoil := 0.0
			var minimum := 100.0
			var recovery := 0.0
			for fraction in [0.0, 0.20, 0.40, 0.45, 0.55, 0.65, 0.72, 0.85, 1.0]:
				player.seek(animation.length * float(fraction), true)
				var posed_bounds := _skin_bounds(mesh, skeleton)
				minimum = minf(minimum, posed_bounds.position.y)
				for joint in skeleton.get_bone_count():
					var pose := skeleton.get_bone_global_pose(joint)
					var initial := start_poses[joint]
					var difference := maxf(pose.origin.distance_to(initial.origin), pose.basis.x.distance_to(initial.basis.x))
					difference = maxf(difference, pose.basis.y.distance_to(initial.basis.y))
					movement = maxf(movement, difference)
					var bone_name := skeleton.get_bone_name(joint)
					bone_motion[bone_name] = maxf(float(bone_motion.get(bone_name, 0.0)), difference)
					if fraction == 1.0: recovery = maxf(recovery, difference)
				if int(row["tier"]) == 3:
					var left := skeleton.find_bone("weapon_l")
					var right := skeleton.find_bone("weapon_r")
					var left_delta := skeleton.get_bone_global_pose(left).origin - start_poses[left].origin
					var right_delta := skeleton.get_bone_global_pose(right).origin - start_poses[right].origin
					independent_recoil = maxf(independent_recoil, (left_delta - right_delta).length())
			if minimum < -0.004: problems.append(clip + ": passes below ground")
			if recovery > 0.001: problems.append(clip + ": failed recovery/loop seam")
			if not clip.ends_with("_Idle") and movement < 0.10: problems.append(clip + ": no mechanical motion")
			for bone_name: String in bone_motion:
				var amount := float(bone_motion[bone_name])
				if clip.ends_with("_Walk") and bone_name.begins_with("wheel_") and amount < 0.5:
					problems.append(clip + ": wheel did not turn " + bone_name)
				if not loops and bone_name in ["weapon", "weapon_l", "weapon_r", "counterweight", "sling", "loader"] and amount < 0.10:
					problems.append(clip + ": mechanism did not move " + bone_name)
			if int(row["tier"]) == 3 and not loops and independent_recoil < 0.08:
				problems.append(clip + ": twin cannons did not recoil independently")
			clip_checks[clip] = {"duration": animation.length, "loop": loops, "movement": movement, "bone_motion": bone_motion,
				"independent_recoil": independent_recoil, "minimum_y": minimum, "recovery_error": recovery}
		player.play(row["prefix"] + "_Idle")
		player.seek(0.0, true)
		player.pause()
		var bounds := _skin_bounds(mesh, skeleton)
		var dims: Array = report["geometry"]["dimensions"]
		var expected := Vector3(float(dims[0]), float(dims[2]), float(dims[1]))
		if bounds.size.distance_to(expected) > 0.002: problems.append(stem + ": wrong rendered dimensions")
		if abs(bounds.position.y) > 0.002: problems.append(stem + ": wheels above/below ground")
		if abs(bounds.end.y - float(row["character_height_m"])) > 0.002: problems.append(stem + ": wrong rendered height")
		results.append({"stem": stem, "bones": skeleton.get_bone_count(), "clips": clip_checks,
			"dimensions": [bounds.size.x, bounds.size.y, bounds.size.z], "ground_y": bounds.position.y})
		model.free()
	var result := {"status": "PASS" if problems.is_empty() else "FAIL", "models": results, "problems": problems}
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	quit(0 if problems.is_empty() else 1)

func _skin_bounds(mesh: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	var bounds := AABB()
	var first := true
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for index in positions.size():
			var point := Vector3.ZERO
			for channel in 4:
				var weight := weights[index * 4 + channel]
				if weight < 0.00001: continue
				var binding := bones[index * 4 + channel]
				var joint := mesh.skin.get_bind_bone(binding)
				if joint < 0: joint = skeleton.find_bone(mesh.skin.get_bind_name(binding))
				point += (skeleton.global_transform * skeleton.get_bone_global_pose(joint) * mesh.skin.get_bind_pose(binding) * positions[index]) * weight
			if not point.is_finite(): problems.append(mesh.name + ": invalid skinned vertex")
			bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
			first = false
		var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if material == null or material.albedo_texture == null:
			problems.append(mesh.name + ": missing embedded atlas")
		elif material.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
			problems.append(mesh.name + ": nearest filtering lost")
	return bounds

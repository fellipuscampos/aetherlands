extends "res://tools/art_pipeline/review_elemental_dragon.gd"

var skeleton: Skeleton3D
var _deforming: Array[int] = []
var metrics := {"cases": 0, "samples": 0, "maximum_instant_jump_m": 0.0, "maximum_frame_displacement_m": 0.0, "maximum_scale_error": 0.0, "maximum_settled_pose_error_m": 0.0, "maximum_imported_pose_error_m": 0.0}

func _run() -> void:
	await super._run()
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	unit._anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for index in bones.size():
		if weights[index] > .00001:
			var bone := skeleton.find_bone(mesh.skin.get_bind_name(bones[index]))
			if bone not in _deforming: _deforming.append(bone)
	if "--capture-transitions" in OS.get_cmdline_user_args():
		await _capture_sequence()
	else:
		await _verify_pairs()
	get_tree().quit()

func _pose() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count(): result.append(skeleton.get_bone_global_pose(bone))
	return result

func _step(delta: float) -> void:
	unit._anim_player.advance(delta)
	await RenderingServer.frame_post_draw

func _set_source(clip: String, time: float) -> void:
	unit._walking = false
	unit._anim_player.stop(true)
	unit._anim_player.clear_caches()
	unit._anim_player.play(clip, 0.0)
	unit._anim_player.seek(time, true)
	await _step(0.0)

func _switch(clip: String) -> void:
	if clip == "spell": unit.play_cast_visual(unit.position + Vector3(0, 0, 2))
	elif clip == "attack": unit.play_attack_visual(null)
	else: unit._play_animation(clip)
	unit._stop_facing_turn()
	unit.rotation = Vector3.ZERO

func _check_pose(previous: Array[Transform3D]) -> void:
	var pose := _pose()
	for bone in _deforming:
		assert(pose[bone].origin.is_finite())
		if skeleton.get_bone_name(bone) != "core":
			metrics.maximum_scale_error = maxf(metrics.maximum_scale_error, absf(pose[bone].basis.determinant() - 1.0))
		var displacement := previous[bone].origin.distance_to(pose[bone].origin)
		if displacement > metrics.maximum_frame_displacement_m:
			metrics.maximum_frame_displacement_m = displacement
			metrics.worst_frame = {"bone": skeleton.get_bone_name(bone), "clip": unit._anim_player.current_animation, "time": unit._anim_player.current_animation_position}
	metrics.samples += 1

func _switch_check(target: String) -> void:
	var before := _pose()
	_switch(target)
	await _step(0.0)
	var after := _pose()
	for bone in _deforming:
		metrics.maximum_instant_jump_m = maxf(metrics.maximum_instant_jump_m, before[bone].origin.distance_to(after[bone].origin))
	metrics.cases += 1

func _verify_pairs() -> void:
	for source in ["idle", "walk", "spell", "attack"]:
		for target in ["idle", "walk", "spell", "attack"]:
			if source == target: continue
			await _set_source(source, unit._anim_player.get_animation(source).length * .37)
			unit._walking = target == "walk"
			await _switch_check(target)
			for sample in range(66):
				var previous := _pose()
				await _step(1.0 / 60.0)
				_check_pose(previous)
			# After capture finishes, the pose must match the unchanged incoming clip.
			var settled := _pose()
			var time := unit._anim_player.current_animation_position
			unit._anim_player.seek(time, true)
			await _step(0.0)
			var direct := _pose()
			for bone in _deforming:
				metrics.maximum_settled_pose_error_m = maxf(metrics.maximum_settled_pose_error_m, settled[bone].origin.distance_to(direct[bone].origin))
	await _set_source("idle", 1.0)
	for target in ["walk", "spell", "spell", "idle", "walk", "idle"]:
		await _switch_check(target)
		for sample in range(15):
			var previous := _pose()
			await _step(1.0 / 60.0)
			_check_pose(previous)
	assert(metrics.maximum_instant_jump_m < .006, str(metrics))
	assert(metrics.maximum_frame_displacement_m < .8, str(metrics))
	assert(metrics.maximum_scale_error < .0002, str(metrics))
	assert(metrics.maximum_settled_pose_error_m < .0001, str(metrics))
	var original := load(unit.unit_data.model_scene_path).instantiate() as Node3D
	add_child(original)
	original.visible = false
	var original_player := original.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var original_skeleton := original.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	original_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["idle", "walk", "spell", "attack"]:
		for fraction in [0.0, .17, .37, .63, .91]:
			var time: float = original_player.get_animation(clip).length * float(fraction)
			await _set_source(clip, time)
			original_player.play(clip, 0.0)
			original_player.seek(time, true)
			original_player.advance(0.0)
			for bone in _deforming:
				var difference := skeleton.get_bone_global_pose(bone).origin.distance_to(original_skeleton.get_bone_global_pose(bone).origin)
				if difference > metrics.maximum_imported_pose_error_m:
					metrics.maximum_imported_pose_error_m = difference
					metrics.worst_imported = {"clip": clip, "time": time, "bone": skeleton.get_bone_name(bone), "actual": str(skeleton.get_bone_global_pose(bone).origin), "expected": str(original_skeleton.get_bone_global_pose(bone).origin)}
	assert(metrics.maximum_imported_pose_error_m < .0001, str(metrics))
	original.queue_free()
	metrics.status = "PASS"
	FileAccess.open(output_path + "transition_validation.json", FileAccess.WRITE).store_string(JSON.stringify(metrics, "  "))
	print("ELEMENTAL_TRANSITIONS " + JSON.stringify(metrics))

func _capture_sequence() -> void:
	get_tree().root.size=Vector2i(720,720)
	camera.size=8.0; camera.position=Vector3(6,6,10); camera.look_at(Vector3(.5,2.0,-2.0))
	for child in get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh: child.mesh.size=Vector2(100,100)
	var directory := output_path+"previews/transitions_frames"
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory+"/.gdignore",FileAccess.WRITE).close()
	await _set_source("idle",0.0)
	var switches := {1.0:"walk",4.0:"idle",6.0:"spell",15.0:"walk",17.0:"idle"}
	for frame in range(390):
		var time := float(frame)/20.0
		if switches.has(time):
			unit._walking=switches[time]=="walk"
			_switch(switches[time])
		await _step(1.0/20.0)
		assert(get_tree().root.get_texture().get_image().save_png(directory+"/%03d.png" % frame)==OK)
	print("ELEMENTAL_TRANSITIONS_CAPTURE_COMPLETE")

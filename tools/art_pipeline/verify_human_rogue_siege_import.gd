extends SceneTree
## Tests actual editor-imported PackedScenes, loop flags, 1:1 height and every baked pose.

var failures: Array[String] = []

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var results: Array = []
	for item: Dictionary in manifest:
		var stem: String = item["stem"]
		var prefix: String = item["prefix"]
		var packed := load("res://assets/generated/humans/%s/%s.glb" % [stem, stem]) as PackedScene
		if packed == null:
			failures.append(stem + ": not imported")
			continue
		var model := packed.instantiate()
		root.add_child(model)
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if skeletons.size() != 1 or meshes.size() != 1 or players.size() != 1:
			failures.append(stem + ": skeleton/mesh/player count")
			model.free()
			continue
		var skeleton := skeletons[0] as Skeleton3D
		var mesh := meshes[0] as MeshInstance3D
		var player := players[0] as AnimationPlayer
		if skeleton.get_bone_count() != int(item["bones"]) or mesh.skin == null:
			failures.append(stem + ": joints/skin")
		var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if mat == null or mat.albedo_texture == null or not mat.emission_enabled or mat.emission_texture == null:
			failures.append(stem + ": missing embedded atlas")
		elif mat.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
			failures.append(stem + ": nearest filter")
		var bounds := mesh.global_transform * mesh.get_aabb()
		if abs(bounds.position.y) > 0.002 or abs(bounds.size.y - float(item["height"])) > 0.006:
			failures.append(stem + ": ground/height " + str(bounds))
		var clips: Dictionary = item["clips"]
		if player.get_animation_list().size() != clips.size():
			failures.append(stem + ": unexpected animations")
		var verified := {}
		for clip: String in clips:
			if not player.has_animation(clip):
				failures.append(stem + ": missing " + clip)
				continue
			var animation := player.get_animation(clip)
			var loop: bool = clip in [prefix + "_Idle", prefix + "_Walk"]
			if abs(animation.length - float(clips[clip])) > 0.001 or animation.loop_mode != (Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE):
				failures.append(clip + ": duration/loop")
			player.play(clip)
			var samples := int(round(animation.length * 24)) + 1
			for frame in range(samples):
				player.seek(float(frame) / 24.0, true)
				skeleton.force_update_all_bone_transforms()
				for bone in range(skeleton.get_bone_count()):
					if not skeleton.get_bone_global_pose(bone).is_finite(): failures.append(clip + ": nonfinite pose")
			verified[clip] = {"seconds": animation.length, "loop": loop, "samples": samples}
		results.append({"asset": stem, "bones": skeleton.get_bone_count(), "height_m": bounds.size.y, "ground_y": bounds.position.y, "clips": verified})
		model.free()
	var output := {"status": "PASS" if failures.is_empty() else "FAIL", "verified": results.size(), "assets": results, "problems": failures}
	var args := OS.get_cmdline_user_args()
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print(JSON.stringify({"status": output["status"], "verified": results.size(), "problems": failures}))
	quit(0 if failures.is_empty() else 1)

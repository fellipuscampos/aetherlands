extends SceneTree
## Verify repaired GLBs after the real Godot editor importer, including pixels.

var problems: Array[String] = []

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var arguments := OS.get_cmdline_user_args()
	var manifest_path: String = arguments[1] if arguments.size() > 1 else "res://manifest.json"
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var results: Array = []
	for item: Dictionary in manifest:
		var unit: String = item["unit"]
		var packed := load(item["path"]) as PackedScene
		if packed == null:
			problems.append(unit + ": GLB not imported")
			continue
		var model := packed.instantiate()
		root.add_child(model)
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if skeletons.size() != 1 or players.size() != 1 or meshes.is_empty():
			problems.append(unit + ": skeleton/mesh/animation player missing")
			model.free()
			continue
		var skeleton := skeletons[0] as Skeleton3D
		var player := players[0] as AnimationPlayer
		if skeleton.get_bone_count() != int(item["bones"]):
			problems.append(unit + ": bone count changed")
		var pixels_match := true
		var filters_nearest := true
		if not item["legacy"]:
			var mesh := meshes[0] as MeshInstance3D
			var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
			if meshes.size() != 1 or mesh.skin == null or material == null or material.albedo_texture == null:
				problems.append(unit + ": skinned mesh or albedo missing")
				pixels_match = false
			else:
				var expected := Image.load_from_file(ProjectSettings.globalize_path(item["albedo"]))
				var actual := material.albedo_texture.get_image()
				if actual.is_compressed():
					actual.decompress()
				# The project's pixel-art imports include mipmap levels; compare
				# the base pixels to the source PNG, which contains only level zero.
				actual.clear_mipmaps()
				expected.clear_mipmaps()
				expected.convert(Image.FORMAT_RGBA8)
				actual.convert(Image.FORMAT_RGBA8)
				pixels_match = expected.get_size() == actual.get_size() and expected.get_data() == actual.get_data()
				filters_nearest = material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]
				if not material.emission_enabled or material.emission_texture == null:
					problems.append(unit + ": emission missing")
				if not pixels_match:
					problems.append(unit + ": imported albedo differs from repaired PNG")
				if not filters_nearest:
					problems.append(unit + ": nearest filter changed")
		var clips: Dictionary = item["clips"]
		var verified := {}
		if player.get_animation_list().size() != clips.size():
			problems.append(unit + ": clip count changed")
		for clip: String in clips:
			if not player.has_animation(clip):
				problems.append(unit + ": missing " + clip)
				continue
			var animation := player.get_animation(clip)
			if abs(animation.length - float(clips[clip])) > 0.001:
				problems.append(unit + ": changed duration for " + clip)
			if not item["legacy"]:
				var expected_loop := Animation.LOOP_LINEAR if bool(item["loops"][clip]) else Animation.LOOP_NONE
				if animation.loop_mode != expected_loop:
					problems.append(unit + ": changed loop flag for " + clip)
			player.play(clip)
			var samples := int(round(animation.length * 24.0)) + 1
			for frame in range(samples):
				player.seek(float(frame) / 24.0, true)
				for bone in range(skeleton.get_bone_count()):
					if not skeleton.get_bone_global_pose(bone).is_finite():
						problems.append(unit + ": nonfinite animated pose")
			verified[clip] = {"seconds": animation.length, "loop": animation.loop_mode, "samples": samples}
		results.append({"unit":unit,"bones":skeleton.get_bone_count(),"albedo_pixels_match_png":pixels_match,
			"nearest_filter":filters_nearest,"animations":verified})
		model.free()
	var report := {"status":"PASS" if problems.is_empty() else "FAIL","verified":results.size(),"units":results,"problems":problems}
	var file := FileAccess.open(arguments[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify({"status":report["status"],"verified":results.size(),"problems":problems}))
	quit(0 if problems.is_empty() else 1)

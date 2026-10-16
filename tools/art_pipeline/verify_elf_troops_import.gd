extends SceneTree

var problems: Array[String] = []

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/elves/elf_troops_manifest.json"))
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
		if meshes.is_empty() or skeletons.size() != 1 or players.size() != 1:
			problems.append(stem + ": missing mesh, skeleton or player")
			model.free()
			continue
		var skeleton := skeletons[0] as Skeleton3D
		var player := players[0] as AnimationPlayer
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/elves/%s/%s_report.json" % [stem, stem]))
		if skeleton.get_bone_count() != report["rig"]["bones"].size(): problems.append(stem + ": lost bones")
		var total := AABB()
		var first := true
		var atlas_pixels_match := true
		for child in meshes:
			var mesh := child as MeshInstance3D
			var bounds := mesh.global_transform * mesh.get_aabb()
			total = bounds if first else total.merge(bounds)
			first = false
			if mesh.skin == null: problems.append(stem + ": missing skin")
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material == null or material.albedo_texture == null:
					problems.append(stem + ": missing embedded texture")
				elif material.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
					problems.append(stem + ": nearest filtering lost")
				else:
					var atlas_path := "res://assets/generated/elves/%s/%s_albedo.png" % [stem, stem]
					var expected_image := Image.load_from_file(ProjectSettings.globalize_path(atlas_path))
					var actual_image := material.albedo_texture.get_image()
					if actual_image.is_compressed(): actual_image.decompress()
					expected_image.clear_mipmaps()
					actual_image.clear_mipmaps()
					expected_image.convert(Image.FORMAT_RGBA8)
					actual_image.convert(Image.FORMAT_RGBA8)
					if expected_image.get_size() != actual_image.get_size() or expected_image.get_data() != actual_image.get_data():
						atlas_pixels_match = false
						problems.append(stem + ": imported pixels differ from corrected atlas")
		var dims: Array = report["geometry"]["dimensions"]
		var expected := Vector3(float(dims[0]), float(dims[2]), float(dims[1]))
		if total.size.distance_to(expected) > 0.008: problems.append(stem + ": wrong dimensions " + str(total.size) + " vs " + str(expected))
		if abs(total.position.y) > 0.005: problems.append(stem + ": feet above/below ground")
		var clips_checked := 0
		for clip: String in report["clips"]:
			if not player.has_animation(clip):
				problems.append(stem + ": missing clip " + clip)
				continue
			var animation := player.get_animation(clip)
			if abs(animation.length - float(report["clips"][clip])) > 0.002: problems.append(stem + ": wrong clip duration " + clip)
			player.play(clip)
			for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				player.seek(animation.length * fraction, true)
				player.advance(0.0)
				skeleton.force_update_all_bone_transforms()
				for bone in skeleton.get_bone_count():
					if not skeleton.get_bone_global_pose(bone).is_finite(): problems.append(stem + ": nonfinite bone in " + clip)
			clips_checked += 1
		results.append({"stem": stem, "dimensions": [total.size.x, total.size.y, total.size.z], "bones": skeleton.get_bone_count(), "clips_played": clips_checked, "atlas_pixels_match": atlas_pixels_match})
		model.free()
	var review := (load("res://_elf_troop_models_review.tscn") as PackedScene).instantiate()
	root.add_child(review)
	for family in range(review.FAMILIES.size()):
		review._select(family)
		await process_frame
		if review.players.size() != 4: problems.append("Review: expected four elves per class")
		for role: String in ["Idle", "Walk", "Attack"]:
			review._play(role)
			await process_frame
		for index in range(1, review.techniques.item_count):
			review._play(review.techniques.get_item_text(index))
			await process_frame
		review.show_human = true
		review._display()
		await process_frame
		review.show_human = false
	var siege_review := (load("res://_elf_siege_models_review.tscn") as PackedScene).instantiate()
	root.add_child(siege_review)
	await process_frame
	if siege_review.current != 5 or siege_review.players.size() != 4:
		problems.append("Siege review: expected four machines and the siege category at startup")
	for role: String in ["Idle", "Walk", "Attack", "DemolitionAmmo", "PreparedBombardment"]:
		siege_review._play(role)
		await process_frame
	var output := {"status": "PASS" if problems.is_empty() else "FAIL", "verified": results.size(), "review_classes": review.FAMILIES.size(), "problems": problems, "assets": results}
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else "res://docs/elf_troops_godot_validation.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print(JSON.stringify({"status": output["status"], "verified": results.size(), "problems": problems}))
	quit(0 if problems.is_empty() else 1)

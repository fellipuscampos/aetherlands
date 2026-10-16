extends SceneTree

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var problems: Array[String] = []
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/orcs/orc_squire_v1/orc_squire_v1_report.json"))
	var model := (load("res://assets/generated/orcs/orc_squire_v1/orc_squire_v1.glb") as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.size() != 1 or players.size() != 1: problems.append("Missing rig/player")
	var skeleton := skeletons[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	if skeleton.get_bone_count() != report["rig"]["bones"].size(): problems.append("Lost bones")
	var total := AABB()
	var first := true
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		var bounds := mesh.global_transform * mesh.get_aabb()
		total = bounds if first else total.merge(bounds)
		first = false
		if mesh.skin == null: problems.append("Missing skin")
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null or material.albedo_texture == null:
				problems.append("Missing atlas")
				continue
			if material.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]: problems.append("Lost nearest filtering")
			var actual := material.albedo_texture.get_image()
			var expected := Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/orcs/orc_squire_v1/orc_squire_v1_albedo.png"))
			if actual.is_compressed(): actual.decompress()
			actual.clear_mipmaps()
			expected.clear_mipmaps()
			actual.convert(Image.FORMAT_RGBA8)
			expected.convert(Image.FORMAT_RGBA8)
			if actual.get_data() != expected.get_data(): problems.append("Imported atlas pixels changed")
	if abs(total.size.y - 2.0) > 0.003 or abs(total.position.y) > 0.003: problems.append("Wrong 2 m height or grounding")
	var dims: Array = report["geometry"]["dimensions"]
	if total.size.distance_to(Vector3(float(dims[0]), float(dims[2]), float(dims[1]))) > 0.003: problems.append("Import dimensions differ")
	var clips := 0
	for clip: String in report["clips"]:
		if not player.has_animation(clip):
			problems.append("Missing clip " + clip)
			continue
		var animation := player.get_animation(clip)
		if abs(animation.length - float(report["clips"][clip])) > 0.002: problems.append("Clip duration changed: " + clip)
		player.play(clip)
		for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			player.seek(animation.length * fraction, true)
			player.advance(0.0)
			skeleton.force_update_all_bone_transforms()
			for bone in skeleton.get_bone_count():
				if not skeleton.get_bone_global_pose(bone).is_finite(): problems.append("Nonfinite pose " + clip)
		clips += 1
	var review := (load("res://_orc_squire_model_review.tscn") as PackedScene).instantiate()
	root.add_child(review)
	await process_frame
	if review.players.size() != 2: problems.append("Comparison must show elf and orc")
	for role: String in ["Idle", "Walk", "Attack", "ShieldWall", "ShieldWallHold"]:
		review._play(role)
		await process_frame
		for review_player in review.players:
			if review_player.current_animation != "Squire_" + role: problems.append("Review failed to play " + role)
	review.comparison = false
	review._display()
	await process_frame
	if review.players.size() != 1: problems.append("Solo preview must show one orc")
	var result := {"status": "PASS" if problems.is_empty() else "FAIL", "models": 1, "clips_played": clips, "height_m": total.size.y, "problems": problems, "comparison_tested": true}
	var file := FileAccess.open("res://docs/orc_squire_godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print(JSON.stringify(result))
	quit(0 if problems.is_empty() else 1)

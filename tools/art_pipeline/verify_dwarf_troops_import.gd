extends SceneTree

var problems: Array[String] = []

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/dwarves/dwarf_troops_manifest.json"))
	var results: Array = []
	for row: Dictionary in rows:
		var stem: String = row["stem"]
		var packed := load(row["path"]) as PackedScene
		if packed == null:
			problems.append(stem + ": import failed")
			continue
		var model := packed.instantiate()
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty(): problems.append(stem + ": no mesh")
		if not model.find_children("*", "Skeleton3D", true, false).is_empty(): problems.append(stem + ": unexpected skeleton")
		if not model.find_children("*", "AnimationPlayer", true, false).is_empty(): problems.append(stem + ": unexpected animations")
		if row["family"] == "cavalry":
			for segment: String in ["thigh", "shin", "hoof"]:
				var count := 0
				for child: Node in meshes:
					if String(child.name).contains("mount_" + segment + "_"): count += 1
				if count != 4: problems.append(stem + ": expected four separate ram " + segment + " meshes")
		var total := AABB()
		var first := true
		for child: Node in meshes:
			var mesh := child as MeshInstance3D
			var bounds := mesh.global_transform * mesh.get_aabb()
			total = bounds if first else total.merge(bounds)
			first = false
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material == null or material.albedo_texture == null:
					problems.append(stem + ": missing embedded material")
				elif material.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
					problems.append(stem + ": pixel filtering")
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/dwarves/%s/%s_report.json" % [stem, stem]))
		var dimensions: Array = report["geometry"]["dimensions"]
		var expected := Vector3(float(dimensions[0]), float(dimensions[2]), float(dimensions[1]))
		if total.size.distance_to(expected) > 0.008:
			problems.append(stem + ": export changed dimensions " + str(total.size) + " expected " + str(expected))
		if abs(total.position.y) > 0.004: problems.append(stem + ": ground contact")
		results.append({"stem": stem, "meshes": meshes.size(), "dimensions": [total.size.x, total.size.y, total.size.z]})
		model.free()
	var output := {"status": "PASS" if problems.is_empty() else "FAIL", "verified": results.size(), "problems": problems, "assets": results}
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else "res://docs/dwarf_troops_godot_validation.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print(JSON.stringify({"status": output["status"], "verified": results.size(), "problems": problems}))
	quit(0 if problems.is_empty() else 1)

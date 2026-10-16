extends SceneTree

var failures: Array[String] = []
var checked: Array[Dictionary] = []

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	var project_root: String = args[0]
	var completed: Array = JSON.parse_string(FileAccess.get_file_as_string(project_root.path_join("art_source/building_architecture_review/completed.json")))
	for entry: Dictionary in completed:
		var folder: String = entry["asset"]
		var race: String = entry["civilization"]
		var plural: String = {"human":"humans", "elf":"elves", "dwarf":"dwarves", "orc":"orcs"}[race]
		var path := project_root.path_join("assets/generated/" + plural + "/buildings/" + folder)
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join(folder + "_report.json")))
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(path.path_join(folder + ".glb"), state)
		if error != OK:
			failures.append(folder + ": import " + str(error))
			continue
		var model := document.generate_scene(state)
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var triangles := 0
		var bounds := AABB()
		var first := true
		if meshes.size() != int(report["export"]["meshes"]):
			failures.append(folder + ": mesh count")
		for instance: MeshInstance3D in meshes:
			var box := instance.global_transform * instance.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			for surface in instance.mesh.get_surface_count():
				var arrays := instance.mesh.surface_get_arrays(surface)
				triangles += int((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					var world_vertex := instance.global_transform * vertex
					for side in range(6):
						var angle := deg_to_rad(side * 60.0)
						if not world_vertex.is_finite() or world_vertex.x * cos(angle) - world_vertex.z * sin(angle) > sqrt(3.0)/2.0 - 0.03 + 0.00001:
							failures.append(folder + ": outside tile")
							break
				var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
				if material == null or material.albedo_texture == null or material.emission_texture == null:
					failures.append(folder + ": missing texture")
				elif material.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
					failures.append(folder + ": texture filter")
		if triangles != int(report["triangles"]) or abs(bounds.position.y) > 0.0001:
			failures.append(folder + ": triangles or ground")
		var dimensions: Array = report["dimensions_m"]
		if bounds.size.distance_to(Vector3(dimensions[0], dimensions[2], dimensions[1])) > 0.0001:
			failures.append(folder + ": dimensions")
		for type in ["Camera3D", "Light3D", "Skeleton3D", "AnimationPlayer"]:
			if not model.find_children("*", type, true, false).is_empty():
				failures.append(folder + ": unwanted " + type)
		checked.append({"asset":folder, "triangles":triangles, "meshes":meshes.size()})
		model.free()
	var summary := {"status":"PASS" if failures.is_empty() else "FAIL", "verified":checked.size(), "assets":checked, "problems":failures}
	var file := FileAccess.open(project_root.path_join("docs/building_architecture_godot_validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	print(JSON.stringify({"status":summary["status"], "verified":checked.size(), "problems":failures}))
	quit(0 if failures.is_empty() else 1)

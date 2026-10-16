extends SceneTree
## Direct GLB import in an isolated Godot project; no game scene changes.

var failures: Array[String] = []
var results: Array[Dictionary] = []

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the game project absolute path after --")
		quit(1)
		return
	var project_root := args[0]
	var stems := ["sacred_temple", "infernal_sanctum", "necromancy_ossuary", "druidic_circle", "arcane_conclave", "elemental_observatory"]
	var grand_mode := args.size() > 2 and args[2] == "grand"
	if grand_mode:
		stems = ["sacred_ritual", "infernal_ritual", "necromancy_ritual", "druidic_ritual", "arcane_ritual", "elemental_ritual"]
	var civs := {"human": "humans", "orc": "orcs", "dwarf": "dwarves", "elf": "elves"}
	for civ: String in civs:
		if args.size() > 1 and args[1] != "all" and civ != args[1]:
			continue
		for stem: String in stems:
			var folder := ("" if civ == "human" else civ + "_") + stem + "_hex_v1"
			var path := project_root.path_join("assets/generated/" + civs[civ] + "/buildings/" + folder)
			var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join(folder + "_report.json")))
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var err := document.append_from_file(path.path_join(folder + ".glb"), state)
			if err != OK:
				failures.append(folder + ": GLB import error " + str(err))
				continue
			var model := document.generate_scene(state)
			root.add_child(model)
			var meshes := model.find_children("*", "MeshInstance3D", true, false)
			var bounds := AABB()
			var first := true
			var triangles := 0
			if meshes.size() != int(report["export"]["meshes"]):
				failures.append(folder + ": mesh count differs")
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
							if not world_vertex.is_finite() or world_vertex.x * cos(angle) - world_vertex.z * sin(angle) > sqrt(3.0) / 2.0 - 0.03:
								failures.append(folder + ": vertex outside hex or nonfinite")
								break
					var mat := instance.mesh.surface_get_material(surface) as StandardMaterial3D
					if mat == null or mat.albedo_texture == null or mat.emission_texture == null:
						failures.append(folder + ": missing atlas material")
						continue
					if mat.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
						failures.append(folder + ": texture filter differs")
					var size: Array = report["texture"]["size"]
					if mat.albedo_texture.get_size() != Vector2(size[0], size[1]):
						failures.append(folder + ": atlas size differs")
			if triangles != int(report["triangles"]) or abs(bounds.position.y) > 0.001:
				failures.append(folder + ": triangles or ground differs")
			for type in ["Camera3D", "Light3D", "Skeleton3D", "AnimationPlayer"]:
				if not model.find_children("*", type, true, false).is_empty():
					failures.append(folder + ": unwanted " + type)
			results.append({"asset": folder, "meshes": meshes.size(), "triangles": triangles,
				"dimensions": [bounds.size.x, bounds.size.y, bounds.size.z]})
			model.free()
	var output := {"status": "PASS" if failures.is_empty() else "FAIL", "verified": results.size(), "assets": results, "problems": failures}
	var filename := ("grand_magic_godot_validation" if grand_mode else "magic_schools_godot_validation") + ("_" + args[1] if args.size() > 1 and args[1] != "all" else "") + ".json"
	var file := FileAccess.open(project_root.path_join("docs/" + filename), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print(JSON.stringify({"status": output["status"], "verified": results.size(), "problems": failures}))
	quit(0 if failures.is_empty() else 1)

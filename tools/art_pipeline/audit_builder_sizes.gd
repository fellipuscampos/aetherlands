extends Node3D

func _ready() -> void:
	_run.call_deferred()

func visible_bounds(model: Node3D, head_corners: Array = []) -> AABB:
	var result := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skeleton: skeleton.force_update_all_bone_transforms()
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var influences := weights.size() / vertices.size()
			for i in vertices.size():
				if not head_corners.is_empty():
					var matches_head := false
					for corner in head_corners:
						if vertices[i].is_equal_approx(Vector3(corner[0], corner[1], corner[2])):
							matches_head = true
							break
					if not matches_head: continue
				var point := vertices[i]
				if mesh.skin and skeleton and influences > 0:
					point = Vector3.ZERO
					for j in influences:
						var weight := weights[i * influences + j]
						if weight < 0.00001: continue
						var bind := bones[i * influences + j]
						var bone := mesh.skin.get_bind_bone(bind)
						if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
						point += (skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * vertices[i]) * weight
				point = mesh.global_transform * point
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else: result = result.expand(point)
	return result

func _run() -> void:
	var results: Array = []
	for race in ["human", "elf", "orc", "dwarf"]:
		var civilization := CivilizationData.new()
		civilization.race = race
		var owner := PlayerData.new(civilization)
		for kind in ["v2_unit_builder", "settler", "v2_unit_warrior", "v2_unit_shieldbearer", "v2_unit_guardian", "v2_unit_swordsman", "v2_unit_sentinel", "v2_unit_weapon_master"]:
			var unit := Unit.new()
			add_child(unit)
			unit.setup(UnitDatabase.create_unit(kind), owner, Vector2i.ZERO)
			unit._anim_player.pause()
			unit._anim_player.seek(0, true)
			unit._anim_player.advance(0)
			var model := unit._anim_player.get_parent() as Node3D
			var bounds := visible_bounds(model)
			results.append({"race":race, "kind":kind, "path":unit.unit_data.model_scene_path,
				"model_scale":model.scale.x, "height":bounds.size.y, "top":bounds.end.y, "floor":bounds.position.y})
			if kind == "v2_unit_builder":
				var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(unit.unit_data.model_scene_path.get_basename() + "_report.json"))
				var body_height := visible_bounds(model, report.body_sizing.head_bind_vertices_gltf).end.y - bounds.position.y
				var target: float = {"human":1.8, "elf":1.8, "orc":2.0, "dwarf":1.35}[race]
				results[-1]["body_height"] = body_height
				results[-1]["target_body_height"] = target
				print("BUILDER_BODY_SIZE ", race, " measured=", body_height, " target=", target, " full=", bounds.size.y)
				assert(absf(body_height - target) < 0.00001, "Builder body size does not match race")
			unit.free()
		owner.release_relations()
	var file := FileAccess.open("res://art_source/builder_size_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	for row in results:
		print(row.race, " ", row.kind, " height=", row.height, " scale=", row.model_scale)
	get_tree().quit()

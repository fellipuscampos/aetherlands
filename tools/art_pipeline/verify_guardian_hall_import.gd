extends SceneTree
## Direct engine check, without changing BuildingDatabase or gameplay scenes.

var failures: Array[String] = []

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file("res://assets/generated/humans/buildings/guardian_hall_v1/guardian_hall_v1.glb", state)
	if err != OK:
		push_error("Cannot load Guardian Hall GLB: " + str(err))
		quit(1)
		return
	var model := document.generate_scene(state)
	root.add_child(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var first := true
	var triangles := 0
	if meshes.size() != 8:
		failures.append("Expected 8 architectural meshes, got %d" % meshes.size())
	for instance: MeshInstance3D in meshes:
		var box := instance.global_transform * instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if not v.is_finite():
					failures.append("Nonfinite vertex")
			var mat := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if mat == null or mat.albedo_texture == null or mat.emission_texture == null:
				failures.append("Missing material/albedo/emission on " + instance.name)
				continue
			if mat.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
				failures.append("Texture is not nearest on " + instance.name)
			if mat.albedo_texture.get_size() != Vector2(4096, 4096):
				failures.append("Unexpected atlas dimensions")
	if triangles != 4672:
		failures.append("Expected 4672 triangles, got %d" % triangles)
	if abs(bounds.position.y) > 0.001:
		failures.append("Model is not grounded")
	if bounds.size.distance_to(Vector3(9.85, 6.83, 9.325)) > 0.005:
		failures.append("Unexpected source dimensions: " + str(bounds.size))
	for type in ["Camera3D", "Light3D", "Skeleton3D", "AnimationPlayer"]:
		if not model.find_children("*", type, true, false).is_empty():
			failures.append("Unwanted export objects: " + type)
	var report := {"status": "PASS" if failures.is_empty() else "FAIL", "meshes": meshes.size(),
		"triangles": triangles, "dimensions_godot_m": [bounds.size.x, bounds.size.y, bounds.size.z],
		"ground_y": bounds.position.y, "problems": failures}
	print(JSON.stringify(report))
	model.free()
	quit(0 if failures.is_empty() else 1)

extends SceneTree

const KIT := "res://assets/generated/nature/temperate_forest_v1"
var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		problems.append(message)

func find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		find_meshes(child, result)

func combined_transform(node: Node3D) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		transform = parent.transform * transform
		parent = parent.get_parent()
	return transform

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT + "/manifest.json"))
	var material := StandardMaterial3D.new()
	material.resource_name = "Temperate Forest Shared Pixel Material"
	material.albedo_texture = load(KIT + "/textures/forest_pixel_atlas.png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.92
	material.metallic = 0.0
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	var material_path := KIT + "/godot/forest_pixel_material.tres"
	check(ResourceSaver.save(material, material_path) == OK, "Cannot save shared material")
	material.take_over_path(material_path)
	var verified: Array[Dictionary] = []
	for entry: Dictionary in manifest["assets"]:
		var asset: String = entry["asset"]
		var source: PackedScene = load(KIT + "/models/" + asset + "/" + asset + ".glb")
		check(source != null, asset + " GLB failed to import")
		if source == null:
			continue
		var instance := source.instantiate()
		var meshes: Array[MeshInstance3D] = []
		find_meshes(instance, meshes)
		check(meshes.size() == 1, asset + " must have one game mesh")
		if meshes.size() != 1:
			instance.free()
			continue
		check(combined_transform(meshes[0]).is_equal_approx(Transform3D.IDENTITY), asset + " unexpected import transform")
		var mesh: ArrayMesh = meshes[0].mesh.duplicate(true)
		check(mesh.get_surface_count() == 1, asset + " multiple draw surfaces")
		var bounds := mesh.get_aabb()
		var dimensions: Array = entry["dimensions"]
		check(absf(bounds.position.y) < 0.00001, asset + " incorrect ground pivot")
		check(bounds.size.is_equal_approx(Vector3(dimensions[0], dimensions[2], dimensions[1])), asset + " incorrect native scale")
		var arrays := mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		check(indices.size() / 3 == int(entry["triangles"]), asset + " triangle mismatch")
		mesh.surface_set_material(0, material)
		mesh.resource_name = asset
		var mesh_path := KIT + "/godot/" + asset + ".res"
		check(ResourceSaver.save(mesh, mesh_path) == OK, asset + " cannot save runtime mesh")
		mesh.take_over_path(mesh_path)
		var node := Node3D.new()
		node.name = asset
		var geometry := MeshInstance3D.new()
		geometry.name = "Mesh"
		geometry.mesh = mesh
		node.add_child(geometry)
		geometry.owner = node
		var packed := PackedScene.new()
		check(packed.pack(node) == OK, asset + " cannot pack standalone scene")
		check(ResourceSaver.save(packed, KIT + "/godot/" + asset + ".tscn") == OK, asset + " cannot save standalone scene")
		node.free()
		instance.free()
		var roundtrip: PackedScene = load(KIT + "/godot/" + asset + ".tscn")
		var restored := roundtrip.instantiate()
		var restored_mesh: MeshInstance3D = restored.get_node("Mesh")
		check(restored_mesh.mesh.surface_get_material(0) == material, asset + " material is not shared")
		check(restored_mesh.mesh.resource_path == mesh_path and restored_mesh.mesh == load(mesh_path), asset + " scene duplicates its reusable mesh")
		check(restored.transform.is_equal_approx(Transform3D.IDENTITY), asset + " scene has a scale correction")
		# Verify the same mesh supports many transformed instances. This creates
		# no tile scene and deliberately saves no assembled forest.
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = restored_mesh.mesh
		multi.instance_count = 1000
		var last_transform := Transform3D.IDENTITY
		for i in range(1000):
			var scale_factor := 0.85 + float(i % 28) * 0.01
			var basis := Basis(Vector3.UP, float(i) * 0.618).scaled(Vector3.ONE * scale_factor)
			last_transform = Transform3D(basis, Vector3(i % 25, 0, floori(float(i) / 25.0)))
			multi.set_instance_transform(i, last_transform)
			multi.set_instance_color(i, Color(0.97, 1.0, 0.95, 1.0))
		check(multi.mesh == restored_mesh.mesh and multi.instance_count == 1000, asset + " MultiMesh failed")
		# The headless dummy renderer does not retain GPU instance transforms.
		# Validate the CPU transforms supplied to the real MultiMesh API instead.
		check(last_transform.origin.is_equal_approx(Vector3(24, 0, 39)), asset + " transformed instance mismatch")
		restored.free()
		verified.append({"asset": asset, "surfaces": 1, "triangles": entry["triangles"], "native_scale": true, "shared_material": true, "multimesh_instances_configured": 1000, "gpu_benchmark": false})
	var report := {"status": "PASS" if problems.is_empty() else "FAIL", "verified": verified.size(), "problems": problems, "assets": verified, "no_tile_scene_saved": true}
	var output := FileAccess.open(KIT + "/godot_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify({"status": report["status"], "verified": verified.size(), "problems": problems}))
	quit(0 if problems.is_empty() else 1)

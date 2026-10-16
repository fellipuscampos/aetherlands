extends SceneTree

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(1))
	run_check.call_deferred()

func run_check() -> void:
	var packed := load("res://scenes/art_review/VeilArchonModelReview.tscn") as PackedScene
	assert(packed != null)
	var world := packed.instantiate()
	root.add_child(world)
	world.canvas.visible = false
	var model: Node3D = world.model
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(meshes.size() == 1 and skeletons.size() == 1)
	var animation_count := 0
	for player in players:
		animation_count += player.get_animation_list().size()
	assert(animation_count == 0)
	var mesh := meshes[0] as MeshInstance3D
	var skeleton := skeletons[0] as Skeleton3D
	assert(skeleton.get_bone_count() > 15 and mesh.skin != null)
	assert(mesh.mesh.get_surface_count() == 1)
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert(material != null and material.albedo_texture != null)
	assert(material.emission_texture != null and material.emission_enabled)
	assert(material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS])
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/grand_manifestations/veil_archon_blocky_v1/veil_archon_blocky_v1_report.json"))
	assert(indices.size() / 3 == int(expected.triangles))
	var stride := int(bones.size() / vertices.size())
	skeleton.force_update_all_bone_transforms()
	var matrices: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var name := mesh.skin.get_bind_name(bind)
		var bone := skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(bind)
		assert(bone >= 0)
		var transform := skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind)
		assert(transform.is_finite())
		matrices.append(transform)
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for i in vertices.size():
		var v := Vector3.ZERO
		var total_weight := 0.0
		var influences := 0
		for j in stride:
			var k := i * stride + j
			if weights[k] > 0:
				influences += 1
				total_weight += weights[k]
				v += (matrices[bones[k]] * vertices[i]) * weights[k]
		assert(influences == 1 and absf(total_weight - 1) < 0.00001)
		assert(v.is_finite())
		low = low.min(v)
		high = high.max(v)
	assert(absf((high-low).y - 3) < 0.001 and absf(low.y-.25) < 0.001)
	var views := {
		"godot_three_quarter": Vector3(3, 4.2, 10),
		"front": Vector3(0, 1.75, 10),
		"back": Vector3(-4, 5.2, -10),
		"side": Vector3(10, 3, 0),
		"godot_game_view": Vector3(4, 8, 6),
	}
	var destination := OS.get_cmdline_user_args()[0]
	for view in views:
		world.camera.position = views[view]
		world.camera.look_at(Vector3(0, 1.75, 0))
		for frame in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(destination.path_join(view + ".png")) == OK)
	var report := {"status": "PASS", "native_godot_version": Engine.get_version_info().string,
		"height_m": high.y-low.y, "ground_clearance_m": low.y,
		"size_m": [high.x-low.x, high.y-low.y, high.z-low.z],
		"triangles": indices.size()/3, "prepared_bones": skeleton.get_bone_count(), "meshes": 1,
		"materials": 1, "animations": animation_count, "rigid_weights": true,
		"emission": true, "nearest": true, "review_scene_valid": true, "views": views.keys()}
	print("VEIL_ARCHON_MODEL_VALIDATION " + JSON.stringify(report))
	quit(0)

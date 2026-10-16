extends SceneTree

const ASSET_DIR := "res://assets/generated/grand_manifestations/seraph_blocky_v3/"

func _initialize() -> void:
	run_check.call_deferred()

func run_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET_DIR + "seraph_blocky_v3_report.json"))
	var packed := load("res://scenes/art_review/SeraphModelV3Review.tscn") as PackedScene
	assert(packed != null)
	var world := packed.instantiate()
	root.add_child(world)
	world.canvas.visible = false
	var model: Node3D = world.model
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(meshes.size() == 1 and skeletons.size() == 1 and players.size() == 1)
	var mesh := meshes[0] as MeshInstance3D
	var skeleton := skeletons[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	assert(player.has_animation("Seraph_CoreOrbit"))
	var animation := player.get_animation("Seraph_CoreOrbit")
	assert(animation.loop_mode == Animation.LOOP_LINEAR and absf(animation.length - 24) < 0.001)
	assert(skeleton.get_bone_count() == 11 and mesh.skin != null)
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
	assert(indices.size() / 3 == int(expected.triangles))
	var stride := int(bones.size() / vertices.size())
	var bind_bones: Array[int] = []
	var bind_groups: Array[String] = []
	for bind in mesh.skin.get_bind_count():
		var name := mesh.skin.get_bind_name(bind)
		var bone := skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(bind)
		assert(bone >= 0)
		bind_bones.append(bone)
		var group := String(skeleton.get_bone_name(bone))
		bind_groups.append(group if group in ["core", "orbit_a", "orbit_b"] else "static")
	var vertex_binds: PackedInt32Array = []
	for i in vertices.size():
		var influences := 0
		for j in stride:
			var k := i * stride + j
			if weights[k] > 0:
				assert(absf(weights[k]-1) < 0.00001)
				influences += 1
				vertex_binds.append(bones[k])
		assert(influences == 1)
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var baseline: Array[Transform3D] = []
	var first_points: PackedVector3Array = []
	var seam := 0.0
	var origin := Vector3.ZERO
	var count := 577
	for frame in count:
		player.play("Seraph_CoreOrbit")
		player.seek(float(frame)/24, true)
		player.advance(0)
		player.pause()
		skeleton.force_update_all_bone_transforms()
		var matrices: Array[Transform3D] = []
		for bind in bind_bones.size():
			var transform := skeleton.global_transform * skeleton.get_bone_global_pose(bind_bones[bind]) * mesh.skin.get_bind_pose(bind)
			assert(transform.is_finite() and absf(transform.basis.determinant()-1) < 0.001)
			matrices.append(transform)
			if frame > 0 and bind_groups[bind] == "static":
				assert(transform.is_equal_approx(baseline[bind]))
		var core_origin := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("core")).origin
		if frame == 0:
			baseline = matrices.duplicate()
			origin = core_origin
		assert(origin.distance_to(core_origin) < 0.0001)
		for ring in ["orbit_a", "orbit_b"]:
			var ring_origin := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(ring)).origin
			assert(origin.distance_to(ring_origin) < 0.0001)
		for i in vertices.size():
			var bind := vertex_binds[i]
			var v := matrices[bind] * vertices[i]
			assert(v.is_finite())
			var group := bind_groups[bind]
			var radial := origin.distance_to(v)
			assert(radial <= float(expected.radial_bounds[group].max_m) + 0.001)
			assert(radial >= float(expected.radial_bounds[group].min_m) - 0.001)
			low = low.min(v)
			high = high.max(v)
			if frame == 0: first_points.append(v)
			if frame == count-1: seam = maxf(seam, v.distance_to(first_points[i]))
	assert(seam < 0.0001)
	assert(absf((high-low).y - 3) < 0.001 and absf(low.y - 0.22) < 0.001)
	player.play("Seraph_CoreOrbit")
	player.seek(0, true)
	player.advance(0)
	player.pause()
	skeleton.force_update_all_bone_transforms()
	var views := {
		"godot_three_quarter": Vector3(3, 4.2, 10), "front": Vector3(0, 1.72, 10),
		"back": Vector3(-4, 5.2, -10), "side": Vector3(10, 3, 0), "godot_game_view": Vector3(4, 8, 6),
	}
	var destination := OS.get_cmdline_user_args()[0]
	for view in views:
		world.camera.position = views[view]
		world.camera.look_at(Vector3(0, 1.72, 0))
		for frame in 6: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(destination.path_join(view + ".png")) == OK)
	# A deterministic full loop also lets the user review the requested motion.
	world.camera.position = views.godot_three_quarter
	world.camera.look_at(Vector3(0, 1.72, 0))
	root.size = Vector2i(640, 640)
	var frame_directory := OS.get_cmdline_user_args()[1]
	assert(DirAccess.make_dir_recursive_absolute(frame_directory) == OK)
	for frame in 144:
		player.play("Seraph_CoreOrbit")
		player.seek(float(frame)/6, true)
		player.advance(0)
		player.pause()
		skeleton.force_update_all_bone_transforms()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(frame_directory.path_join("%04d.png" % (frame+1))) == OK)
	var report := {"status": "PASS", "native_godot_version": Engine.get_version_info().string,
		"height_m": high.y-low.y, "ground_clearance_m": low.y,
		"size_m": [high.x-low.x, high.y-low.y, high.z-low.z], "triangles": indices.size()/3,
		"prepared_bones": 11, "meshes": 1, "materials": 1, "animations": 1,
		"rotation_clip": "Seraph_CoreOrbit", "rotation_duration_s": 24, "rotation_loop": true,
		"poses_checked": count, "loop_seam_max_m": seam, "root_wings_and_rear_cubes_static": true,
		"all_rotation_clearances_m": expected.all_rotation_clearances_m,
		"rigid_weights": true, "emission": true, "nearest": true,
		"review_scene_valid": true, "views": views.keys(), "preview_frames": 144, "preview_fps": 6}
	print("SERAPH_MODEL_VALIDATION " + JSON.stringify(report))
	quit(0)

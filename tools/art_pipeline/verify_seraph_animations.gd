extends SceneTree

const ASSET := "res://assets/generated/grand_manifestations/seraph_blocky_v4_animated/"

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		push_error("Seraph animation validation did not finish.")
		quit(1))
	run_check.call_deferred()

func points_for_pose(vertices: PackedVector3Array, binds: PackedInt32Array, matrices: Array[Transform3D]) -> PackedVector3Array:
	var points: PackedVector3Array = []
	for i in vertices.size(): points.append(matrices[binds[i]] * vertices[i])
	return points

func matrices_for_pose(mesh: MeshInstance3D, skeleton: Skeleton3D, bone_indices: Array[int]) -> Array[Transform3D]:
	skeleton.force_update_all_bone_transforms()
	var result: Array[Transform3D] = []
	for i in bone_indices.size():
		result.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone_indices[i]) * mesh.skin.get_bind_pose(i))
	return result

func run_check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET + "animation_report.json"))
	var packed := load("res://scenes/art_review/SeraphAnimationReview.tscn") as PackedScene
	assert(packed != null)
	var world := packed.instantiate()
	root.add_child(world)
	world.canvas.visible = false
	var model: Node3D = world.model
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(meshes.size()==1 and skeletons.size()==1 and players.size()==1)
	var mesh := meshes[0] as MeshInstance3D
	var skeleton := skeletons[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	player.animation_finished.disconnect(Callable(world, "_animation_finished"))
	assert(player.get_animation_list().size()==4 and skeleton.get_bone_count()==11)
	assert(mesh.mesh.get_surface_count()==1 and mesh.skin!=null)
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert(material.albedo_texture!=null and material.emission_texture!=null and material.emission_enabled)
	assert(material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS])
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bone_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var vertex_bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert(indices.size()/3==2072)
	var stride := int(vertex_bones.size()/vertices.size())
	var bind_indices: Array[int] = []
	for i in mesh.skin.get_bind_count():
		var bone_name := mesh.skin.get_bind_name(i)
		var bone := skeleton.find_bone(bone_name) if bone_name!=&"" else mesh.skin.get_bind_bone(i)
		assert(bone>=0)
		bind_indices.append(bone)
	var binds: PackedInt32Array = []
	for i in vertices.size():
		var influences := 0
		for j in stride:
			var k := i*stride+j
			if bone_weights[k]>0:
				assert(absf(bone_weights[k]-1)<0.00001)
				influences+=1
				binds.append(vertex_bones[k])
		assert(influences==1)
	var results := {}
	var idle_start: PackedVector3Array = []
	var all_samples := 0
	for clip in ["Idle", "Walk", "Attack", "Spell"]:
		assert(player.has_animation(clip))
		var animation := player.get_animation(clip)
		var data: Dictionary = expected.clips[clip]
		assert(absf(animation.length-float(data.duration_s))<0.001)
		assert(animation.loop_mode==(Animation.LOOP_LINEAR if bool(data.loop) else Animation.LOOP_NONE))
		var low := Vector3(INF,INF,INF)
		var high := Vector3(-INF,-INF,-INF)
		var first: PackedVector3Array = []
		var seam := 0.0
		var count := roundi(animation.length*24)+1
		for frame in count:
			player.play(clip,0)
			player.seek(float(frame)/24,true)
			player.advance(0)
			player.pause()
			var matrices := matrices_for_pose(mesh,skeleton,bind_indices)
			for transform in matrices:
				assert(transform.is_finite() and transform.basis.determinant()>0)
				var scales := Vector3(transform.basis.x.length(),transform.basis.y.length(),transform.basis.z.length())
				assert(absf(scales.x-scales.y)<0.00001 and absf(scales.y-scales.z)<0.00001)
				var axes := transform.basis.orthonormalized()
				assert(absf(axes.x.dot(axes.y))<0.00001 and absf(axes.y.dot(axes.z))<0.00001)
			var root_pose := skeleton.get_bone_pose(skeleton.find_bone("root"))
			assert(root_pose.is_equal_approx(Transform3D.IDENTITY))
			var core_origin := skeleton.get_bone_global_pose(skeleton.find_bone("core")).origin
			for ring in ["orbit_a","orbit_b"]:
				assert(core_origin.distance_to(skeleton.get_bone_global_pose(skeleton.find_bone(ring)).origin)<0.00001)
			var points := points_for_pose(vertices,binds,matrices)
			for i in points.size():
				assert(points[i].is_finite())
				low=low.min(points[i]); high=high.max(points[i])
				if frame==0: first.append(points[i])
				if frame==count-1: seam=maxf(seam,points[i].distance_to(first[i]))
		assert(seam<0.0001 and low.y>0.09)
		var source_min: Array = data.bounds_min_m
		var source_max: Array = data.bounds_max_m
		var expected_low := Vector3(source_min[0],source_min[2],-source_max[1])
		var expected_high := Vector3(source_max[0],source_max[2],-source_min[1])
		assert(low.distance_to(expected_low)<0.02 and high.distance_to(expected_high)<0.02)
		if clip=="Idle": idle_start=first
		if clip in ["Attack","Spell"]:
			for i in first.size(): assert(first[i].distance_to(idle_start[i])<0.0001)
		results[clip]={"duration_s":animation.length,"loop":bool(data.loop),"samples":count,
			"minimum_ground_clearance_m":low.y,"seam_vertex_delta_m":seam,"rigid_uniform_parts":true}
		all_samples+=count
	# Interrupted spell must reset its core scale and all wing transforms.
	player.play("Spell",0); player.seek(1.4,true); player.advance(0)
	player.play("Idle",0); player.seek(0,true); player.advance(0); player.pause()
	var reset_points := points_for_pose(vertices,binds,matrices_for_pose(mesh,skeleton,bind_indices))
	for i in reset_points.size(): assert(reset_points[i].distance_to(idle_start[i])<0.0001)
	var destination := OS.get_cmdline_user_args()[0]
	var frames_root := OS.get_cmdline_user_args()[1]
	var render_info := {}
	var pose_times := {"Idle":0.0,"Walk":0.5,"Attack":0.625,"Spell":1.4}
	for clip in ["Idle","Walk","Attack","Spell"]:
		player.play(clip,0); player.seek(pose_times[clip],true); player.advance(0); player.pause()
		skeleton.force_update_all_bone_transforms()
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(destination.path_join(clip+".png"))==OK)
	root.size=Vector2i(640,640)
	for clip in ["Idle","Walk","Attack","Spell"]:
		var fps := 6 if clip=="Idle" else 12 if clip=="Walk" else 24
		var frames := roundi(float(expected.clips[clip].duration_s)*fps)
		var directory := frames_root.path_join(clip)
		assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
		for frame in frames:
			player.play(clip,0); player.seek(float(frame)/fps,true); player.advance(0); player.pause()
			skeleton.force_update_all_bone_transforms()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(directory.path_join("%04d.png" % (frame+1)))==OK)
		render_info[clip]={"frames":frames,"fps":fps,"duration_s":expected.clips[clip].duration_s}
	var report := {"status":"PASS","native_godot_version":Engine.get_version_info().string,
		"clips":results,"samples":all_samples,"root_motion":false,"rigid_weights":true,
		"textures_preserved":true,"nearest":true,"emission":true,"spell_to_idle_resets_all_transforms":true,
		"meshes":1,"materials":1,"triangles":2072,"bones":11,"previews":render_info}
	print("SERAPH_ANIMATION_VALIDATION "+JSON.stringify(report))
	quit(0)

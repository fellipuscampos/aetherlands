extends SceneTree

const ASSET := "res://assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb"

func _initialize() -> void:
	run_check.call_deferred()

func run_check() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var packed := load(ASSET) as PackedScene
	assert(packed != null)
	var model := packed.instantiate() as Node3D
	world.add_child(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(meshes.size() == 1 and skeletons.size() == 1 and players.size() == 1)
	var mesh := meshes[0] as MeshInstance3D
	var skeleton := skeletons[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	assert(skeleton.get_bone_count() == 7 and mesh.skin != null)
	assert(mesh.mesh.get_surface_count() == 1)
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert(material != null and material.albedo_texture != null)
	assert(material.emission_texture != null and material.emission_enabled)
	assert(material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS])
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := bones.size() / vertices.size()
	var report := {"status": "PASS", "bones": 7, "meshes": 1, "emission": true, "nearest": true, "clips": {}}
	for clip in ["ManaDevourer_Idle", "ManaDevourer_Walk", "ManaDevourer_Attack"]:
		assert(player.has_animation(clip))
		var animation := player.get_animation(clip)
		assert(animation.loop_mode == (Animation.LOOP_NONE if clip.ends_with("Attack") else Animation.LOOP_LINEAR))
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		var count := int(round(animation.length * 24)) + 1
		for frame in count:
			player.play(clip)
			player.seek(float(frame) / 24, true)
			player.advance(0)
			skeleton.force_update_all_bone_transforms()
			var matrices: Array[Transform3D] = []
			for bind in mesh.skin.get_bind_count():
				var name := mesh.skin.get_bind_name(bind)
				var bone := skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(bind)
				assert(bone >= 0)
				var transform := skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind)
				assert(transform.is_finite())
				matrices.append(transform)
			for i in vertices.size():
				var v := Vector3.ZERO
				for j in stride:
					var k := i * stride + j
					if weights[k] > 0:
						v += (matrices[bones[k]] * vertices[i]) * weights[k]
				assert(v.is_finite())
				low = low.min(v)
				high = high.max(v)
		assert(low.y > 0.10, "%s touches terrain: %s" % [clip, low])
		assert((high-low).y < 2.15 and (high-low).x < 2.30)
		report.clips[clip] = {"poses_checked": count, "duration_s": animation.length, "floor_clearance_m": low.y, "size_m": [high.x-low.x, high.y-low.y, high.z-low.z]}
	player.play("ManaDevourer_Idle")
	player.seek(0, true)
	player.pause()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.86, 1)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	world.add_child(light)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_node.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.13, 0.15, 0.18)
	ground.roughness = 1
	floor_node.material_override = ground
	floor_node.position.y = -0.01
	world.add_child(floor_node)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	world.add_child(camera)
	camera.position = Vector3(2.7, 4.2, 5)
	camera.look_at(Vector3(0, 1.03, 0))
	camera.current = true
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var dest := OS.get_cmdline_user_args()[0]
	assert(root.get_texture().get_image().save_png(dest) == OK)
	print("MANA_BLOCKY_VALIDATION " + JSON.stringify(report))
	quit(0)

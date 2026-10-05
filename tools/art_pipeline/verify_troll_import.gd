extends SceneTree

func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var packed := load("res://assets/generated/trolls/troll_blocky_v3/troll_blocky_v3.glb") as PackedScene
	assert(packed != null, "GLB did not import as a PackedScene")
	var model := packed.instantiate()
	root.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(skeletons.size() == 1)
	assert(skeletons[0].get_bone_count() == 24)
	assert(meshes.size() == 2)
	assert(players.size() == 1)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		assert(mesh.skin != null, "Mesh has no skin")
		assert(mesh.mesh.get_surface_count() == 1)
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		assert(material != null and material.albedo_texture != null)
		assert(material.albedo_texture.get_width() == 512)
		assert(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS or material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	assert(abs(bounds.position.y) < 0.001)
	assert(abs(bounds.size.y - 2.5) < 0.002)
	var player: AnimationPlayer = players[0]
	var expected := {"Troll_Idle": 2.0, "Troll_Walk": 28.0 / 24.0, "Troll_Attack": 1.5}
	assert(player.get_animation_list().size() == 3)
	var verified := {}
	for clip: String in expected:
		assert(player.has_animation(clip))
		var animation := player.get_animation(clip)
		assert(abs(animation.length - expected[clip]) < 0.001)
		assert(animation.loop_mode == (Animation.LOOP_NONE if clip == "Troll_Attack" else Animation.LOOP_LINEAR))
		player.play(clip)
		var samples := int(round(animation.length * 24.0)) + 1
		for frame in range(samples):
			player.seek(float(frame) / 24.0, true)
			for i in range(skeletons[0].get_bone_count()):
				assert(skeletons[0].get_bone_global_pose(i).is_finite())
		verified[clip] = {"length": animation.length, "loop": animation.loop_mode, "samples": samples}
	print(JSON.stringify({"status": "PASS", "bones": 24, "skinned_meshes": 2,
		"height": bounds.size.y, "ground_y": bounds.position.y,
		"animations": verified, "nearest_filter": true,
		"pose_samples": 115}))
	model.queue_free()
	quit(0)

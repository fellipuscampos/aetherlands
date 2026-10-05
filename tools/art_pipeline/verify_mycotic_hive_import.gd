extends SceneTree
## Headless check of the imported Mycotic Hive V3 GLB: skeleton, skin, nearest albedo +
## emission textures, height/ground, Hive_Idle length, loop mode and finite poses.
## godot --headless --path . -s tools/art_pipeline/verify_mycotic_hive_import.gd

func _initialize() -> void:
	_verify.call_deferred()

## assert() pauses on the debugger in headless runs and hangs the process;
## this prints the failure and exits with code 1 instead.
func _check(condition: bool, message: String = "check failed") -> void:
	if not condition:
		push_error("VERIFY FAIL: " + message)
		quit(1)

func _verify() -> void:
	var packed := load("res://assets/generated/mycotic_hives/mycotic_hive_v3/mycotic_hive_v3.glb") as PackedScene
	_check(packed != null, "GLB did not import as a PackedScene")
	var model := packed.instantiate()
	root.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_check(skeletons.size() == 1 and skeletons[0].get_bone_count() == 11, "expected one 11-bone skeleton")
	_check(meshes.size() == 1 and players.size() == 1, "expected one mesh and one AnimationPlayer")
	var mesh: MeshInstance3D = meshes[0]
	_check(mesh.skin != null, "mesh has no skin")
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	_check(material != null and material.albedo_texture != null, "missing albedo")
	_check(material.emission_enabled and material.emission_texture != null, "missing emission")
	_check(material.albedo_texture.get_width() == 1024 and material.emission_texture.get_width() == 1024)
	_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS or material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "texture filter is not nearest")
	var bounds := mesh.global_transform * mesh.get_aabb()
	_check(abs(bounds.position.y) < 0.002, "not standing on the ground")
	_check(abs(bounds.size.y - 2.887) < 0.01, "unexpected height %f" % bounds.size.y)
	var player: AnimationPlayer = players[0]
	_check(player.get_animation_list().size() == 1 and player.has_animation("Hive_Idle"), "expected only Hive_Idle")
	var animation := player.get_animation("Hive_Idle")
	_check(abs(animation.length - 3.0) < 0.001, "Hive_Idle length")
	_check(animation.loop_mode == Animation.LOOP_LINEAR, "Hive_Idle must loop")
	player.play("Hive_Idle")
	for frame in range(73):
		player.seek(float(frame) / 24.0, true)
		for i in range(skeletons[0].get_bone_count()):
			_check(skeletons[0].get_bone_global_pose(i).is_finite(), "non-finite pose")
	print(JSON.stringify({"status": "PASS", "bones": 11, "height": bounds.size.y, "ground_y": bounds.position.y,
		"emission_energy": material.emission_energy_multiplier, "Hive_Idle": {"length": animation.length, "loop": animation.loop_mode}}))
	model.queue_free()
	quit(0)

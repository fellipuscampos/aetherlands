extends SceneTree
## Headless check of the imported Basilisk GLB: skeleton, skins, texture filter,
## height/ground, clip lengths, loop modes and finite poses on every frame.
## godot --headless --path . -s tools/art_pipeline/verify_basilisk_import.gd

func _initialize() -> void:
	_verify.call_deferred()

## assert() pauses on the debugger in headless runs and hangs the process;
## this prints the failure and exits with code 1 instead.
func _check(condition: bool, message: String = "check failed") -> void:
	if not condition:
		push_error("VERIFY FAIL: " + message)
		quit(1)

func _verify() -> void:
	var packed := load("res://assets/generated/basilisks/basilisk_blocky_v1/basilisk_blocky_v1.glb") as PackedScene
	_check(packed != null, "GLB did not import as a PackedScene")
	var model := packed.instantiate()
	root.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_check(skeletons.size() == 1 and skeletons[0].get_bone_count() == 20)
	_check(meshes.size() == 1 and players.size() == 1)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		_check(mesh.skin != null, "Mesh has no skin")
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		_check(material != null and material.albedo_texture != null)
		_check(material.albedo_texture.get_width() == 512)
		_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS or material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_check(abs(bounds.position.y) < 0.002)
	_check(abs(bounds.size.y - 2.31) < 0.01)
	var player: AnimationPlayer = players[0]
	var expected := {"Basilisk_Idle": 2.0, "Basilisk_Walk": 28.0 / 24.0, "Basilisk_Attack": 32.0 / 24.0}
	_check(player.get_animation_list().size() == 3)
	var verified := {}
	for clip: String in expected:
		_check(player.has_animation(clip))
		var animation := player.get_animation(clip)
		_check(abs(animation.length - expected[clip]) < 0.001)
		_check(animation.loop_mode == (Animation.LOOP_NONE if clip == "Basilisk_Attack" else Animation.LOOP_LINEAR))
		player.play(clip)
		var samples := int(round(animation.length * 24.0)) + 1
		for frame in range(samples):
			player.seek(float(frame) / 24.0, true)
			for i in range(skeletons[0].get_bone_count()):
				_check(skeletons[0].get_bone_global_pose(i).is_finite())
		verified[clip] = {"length": animation.length, "loop": animation.loop_mode, "samples": samples}
	print(JSON.stringify({"status": "PASS", "bones": 20, "skinned_meshes": 1,
		"height": bounds.size.y, "ground_y": bounds.position.y, "animations": verified}))
	model.queue_free()
	quit(0)

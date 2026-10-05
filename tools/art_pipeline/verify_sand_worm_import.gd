extends SceneTree
## Headless check of the imported Sand Worm V1 GLB: skeleton, skin, nearest albedo, ground,
## Worm_Idle/Attack/Burrow/Emerge lengths, loop mode, finite poses, and that the body is
## fully hidden (scale ~0) at the end of Burrow and the start of Emerge.
## godot --headless --path . -s tools/art_pipeline/verify_sand_worm_import.gd

func _initialize() -> void:
	_verify.call_deferred()

## assert() pauses on the debugger in headless runs and hangs the process;
## this prints the failure and exits with code 1 instead.
func _check(condition: bool, message: String = "check failed") -> void:
	if not condition:
		push_error("VERIFY FAIL: " + message)
		quit(1)

func _max_bone_scale(skeleton: Skeleton3D) -> float:
	var biggest := 0.0
	for i in range(skeleton.get_bone_count()):
		if skeleton.get_bone_name(i) == "root":
			continue
		biggest = max(biggest, skeleton.get_bone_global_pose(i).basis.get_scale().x)
	return biggest

func _verify() -> void:
	var packed := load("res://assets/generated/sand_worms/sand_worm_v1/sand_worm_v1.glb") as PackedScene
	_check(packed != null, "GLB did not import as a PackedScene")
	var model := packed.instantiate()
	root.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_check(skeletons.size() == 1 and skeletons[0].get_bone_count() == 35, "expected one 35-bone skeleton")
	_check(meshes.size() == 1 and players.size() == 1, "expected one mesh and one AnimationPlayer")
	var skeleton: Skeleton3D = skeletons[0]
	var mesh: MeshInstance3D = meshes[0]
	_check(mesh.skin != null, "mesh has no skin")
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	_check(material != null and material.albedo_texture != null, "missing albedo")
	_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS or material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "texture filter is not nearest")
	var bounds := mesh.global_transform * mesh.get_aabb()
	_check(abs(bounds.position.y) < 0.005, "not standing on the ground")
	var player: AnimationPlayer = players[0]
	var expected := {"Worm_Idle": 3.0, "Worm_Attack": 1.5, "Worm_Burrow": 2.0, "Worm_Emerge": 2.0}
	_check(player.get_animation_list().size() == 4, "expected 4 clips")
	var verified := {}
	for clip: String in expected:
		_check(player.has_animation(clip), "missing " + clip)
		var animation := player.get_animation(clip)
		_check(abs(animation.length - expected[clip]) < 0.001, clip + " length")
		_check(animation.loop_mode == (Animation.LOOP_LINEAR if clip == "Worm_Idle" else Animation.LOOP_NONE), clip + " loop mode")
		player.play(clip)
		var samples := int(round(animation.length * 24.0)) + 1
		for frame in range(samples):
			player.seek(float(frame) / 24.0, true)
			for i in range(skeleton.get_bone_count()):
				_check(skeleton.get_bone_global_pose(i).is_finite(), "non-finite pose")
		player.seek(0.0, true)
		var first := _max_bone_scale(skeleton)
		player.seek(animation.length, true)
		var last := _max_bone_scale(skeleton)
		verified[clip] = {"length": animation.length, "loop": animation.loop_mode, "samples": samples,
			"max_scale_first": snappedf(first, 0.001), "max_scale_last": snappedf(last, 0.001)}
	_check(verified["Worm_Burrow"]["max_scale_last"] < 0.05, "body still visible at the end of Burrow")
	_check(verified["Worm_Emerge"]["max_scale_first"] < 0.05, "body visible at the start of Emerge")
	_check(abs(verified["Worm_Emerge"]["max_scale_last"] - 1.0) < 0.01, "Emerge does not end at full scale")
	print(JSON.stringify({"status": "PASS", "bones": 35, "height": bounds.size.y, "ground_y": bounds.position.y, "animations": verified}))
	model.queue_free()
	quit(0)

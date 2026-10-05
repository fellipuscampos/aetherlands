extends SceneTree
## Headless check of the imported ShockCavalier V1 GLB: skeleton, skin, nearest albedo +
## emission textures, height/ground, ShockCavalier_Idle/Walk/Attack/Charge lengths, loop mode and finite poses.
## godot --headless --path . -s tools/art_pipeline/verify_shock_cavalier_import.gd

func _initialize() -> void:
	_verify.call_deferred()

## assert() pauses on the debugger in headless runs and hangs the process;
## this prints the failure and exits with code 1 instead.
func _check(condition: bool, message: String = "check failed") -> void:
	if not condition:
		push_error("VERIFY FAIL: " + message)
		quit(1)

func _verify() -> void:
	var packed := load("res://assets/generated/humans/shock_cavalier_v1/shock_cavalier_v1.glb") as PackedScene
	_check(packed != null, "GLB did not import as a PackedScene")
	var model := packed.instantiate()
	root.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_check(skeletons.size() == 1 and skeletons[0].get_bone_count() == 28, "expected one 28-bone skeleton (horse 12 + rider 16)")
	_check(meshes.size() == 1 and players.size() == 1, "expected one mesh and one AnimationPlayer")
	var mesh: MeshInstance3D = meshes[0]
	_check(mesh.skin != null, "mesh has no skin")
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	_check(material != null and material.albedo_texture != null, "missing albedo")
	_check(material.emission_enabled and material.emission_texture != null, "missing emission")
	_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS or material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "texture filter is not nearest")
	var bounds := mesh.global_transform * mesh.get_aabb()
	_check(abs(bounds.position.y) < 0.002, "not standing on the ground")
	var player: AnimationPlayer = players[0]
	var expected := {"ShockCavalier_Idle": 3.0, "ShockCavalier_Walk": 18.0 / 24.0, "ShockCavalier_Attack": 32.0 / 24.0, "ShockCavalier_Charge": 36.0 / 24.0}
	_check(player.get_animation_list().size() == 4, "expected 4 clips")
	var verified := {}
	for clip: String in expected:
		_check(player.has_animation(clip), "missing " + clip)
		var animation := player.get_animation(clip)
		_check(abs(animation.length - expected[clip]) < 0.001, clip + " length")
		_check(animation.loop_mode == (Animation.LOOP_NONE if clip in ["ShockCavalier_Attack", "ShockCavalier_Charge"] else Animation.LOOP_LINEAR), clip + " loop mode")
		player.play(clip)
		var samples := int(round(animation.length * 24.0)) + 1
		for frame in range(samples):
			player.seek(float(frame) / 24.0, true)
			for i in range(skeletons[0].get_bone_count()):
				_check(skeletons[0].get_bone_global_pose(i).is_finite(), "non-finite pose")
		verified[clip] = {"length": animation.length, "loop": animation.loop_mode, "samples": samples}
	_check(abs(bounds.size.y - 3.296) < 0.01, "mounted: rider at real scale + the heavy lance tip (3.296 m)")
	print(JSON.stringify({"status": "PASS", "bones": 28, "height": bounds.size.y, "ground_y": bounds.position.y,
		"emission_energy": material.emission_energy_multiplier, "animations": verified}))
	model.queue_free()
	quit(0)

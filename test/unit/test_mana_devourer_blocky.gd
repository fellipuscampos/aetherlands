extends GutTest

func _create_devourer() -> Unit:
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(MonsterDatabase.create_monster("mana_devourer"), null, Vector2i.ZERO)
	return unit

func test_spawn_uses_blocky_asset_with_native_idle_and_emission():
	var unit := _create_devourer()
	assert_true(unit.unit_data.model_scene_path.contains("mana_devourer_blocky_v3"))
	var player := unit._anim_player
	assert_not_null(player)
	if player == null:
		return
	assert_eq(player.current_animation, "ManaDevourer_Idle")
	var meshes := unit.find_children("*", "MeshInstance3D", true, false)
	var found_mana := false
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh.skin == null:
			continue
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		found_mana = material != null and material.emission_enabled and material.emission_texture != null
	assert_true(found_mana, "The actual game instance keeps the emissive mana atlas.")

func test_movement_selects_native_walk_and_attack_keeps_one_shot_contract():
	var unit := _create_devourer()
	var player := unit._anim_player
	assert_not_null(player)
	if player == null:
		return
	unit.slide_to(Vector3(1, 0, 0))
	assert_eq(player.current_animation, "ManaDevourer_Walk")
	assert_eq(player.get_animation("ManaDevourer_Walk").loop_mode, Animation.LOOP_LINEAR)
	assert_true(player.has_animation(unit.attack_animation))
	assert_eq(unit.attack_animation, "ManaDevourer_Attack")
	assert_eq(player.get_animation(unit.attack_animation).loop_mode, Animation.LOOP_NONE)
	unit.play_attack_visual(null)
	assert_eq(player.current_animation, "ManaDevourer_Attack")

func test_blending_from_orbit_to_attack_keeps_stones_outside_core():
	var unit := _create_devourer()
	var player := unit._anim_player
	assert_not_null(player)
	if player == null:
		return
	var skeleton := unit.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	player.seek(8.0, true)
	player.advance(0)
	unit.play_attack_visual(null)
	for frame in 12:
		player.advance(0.025)
		skeleton.force_update_all_bone_transforms()
		var core := skeleton.get_bone_global_pose(skeleton.find_bone("core")).origin
		for stone in 4:
			var position := skeleton.get_bone_global_pose(skeleton.find_bone("stone_%02d" % stone)).origin
			assert_gt(position.distance_to(core), 0.72, "Crossfade preserves the orbit instead of moving stone through the core.")

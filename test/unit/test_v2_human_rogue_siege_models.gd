extends GutTest
## Exercise Unit.setup/playback with the new native humanoid/mechanical rigs.

const KINDS := ["v2_unit_rogue", "v2_unit_saboteur", "v2_unit_assassin", "v2_legendary_shadow_master", "v2_unit_catapult", "v2_unit_trebuchet", "v2_unit_bombard", "v2_legendary_siege_colossus"]

func _unit(kind: String) -> Unit:
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(UnitDatabase.create_unit(kind), PlayerData.new(CivilizationData.new()), Vector2i.ZERO)
	return unit

func test_native_skeletons_play_idle_walk_attack_and_techniques_in_unit():
	var target := _unit("v2_unit_warrior")
	target.position = Vector3(0, 0, 2)
	for kind in KINDS:
		var unit := _unit(kind)
		var data := unit.unit_data
		assert_not_null(unit._anim_player, kind)
		if unit._anim_player == null: continue
		assert_eq(data.model_scale_multiplier, 1.0, kind + ": native dimensions")
		assert_false(data.merge_shared_walk_animation, kind + ": own rig")
		assert_eq(unit._anim_player.current_animation, data.idle_animation_override, kind)
		assert_true(unit._anim_player.has_animation(data.walk_animation_override), kind)
		unit.play_attack_visual(target)
		assert_eq(unit._anim_player.current_animation, data.attack_animation_override, kind)
		for technique in data.technique_animation_overrides:
			unit.begin_technique_animation(technique)
			unit.play_attack_visual(target)
			assert_eq(unit._anim_player.current_animation, data.technique_animation_overrides[technique], kind + ": " + technique)
			unit.end_technique_animation()
		unit._on_blended_animation_finished(StringName(data.attack_animation_override), unit._anim_player)
		assert_eq(unit._anim_player.current_animation, data.idle_animation_override, kind + ": recovery")

func test_legendary_rules_and_passive_mechanics_are_preserved():
	var shadow := UnitDatabase.create_unit("v2_legendary_shadow_master")
	var colossus := UnitDatabase.create_unit("v2_legendary_siege_colossus")
	assert_eq(shadow.movement_profile, UnitData.MovementProfile.INFILTRATOR)
	assert_true(colossus.ignores_technique_stationary_requirement)
	assert_true(colossus.has_trait(UnitData.TRAIT_SIEGE))
	assert_true(shadow.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_true(colossus.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_true(V2DoctrineTechniqueDatabase.get_technique(V2DoctrineTechniqueDatabase.DISMANTLE).is_passive())
	assert_true(V2DoctrineTechniqueDatabase.get_technique(V2DoctrineTechniqueDatabase.DEMOLITION_AMMO).is_passive())

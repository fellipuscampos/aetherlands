extends GutTest

const Feedback := preload("res://scripts/vfx/CombatFeedback.gd")
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var original := {}

func before_each() -> void:
	for key in ["players", "rival_players", "human_player", "hex_grid", "state"]: original[key] = GameManager.get(key)
	original.turn = TurnManager.turn_number
	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.state = GameManager.GameState.PLAYING
	Diplomacy.declare_war(human, rival, "visual test", true)
	TurnManager.turn_number = 20
	human.mana = 600.0
	for school in ["sacred", "infernal", "arcanism", "necromancy", "druidism"]:
		for tier in range(2, 10): human.v2_research.complete_research("v2_magic_%s_%d" % [school, tier])
	grid = HexGrid.new()
	add_child(grid)
	GameManager.hex_grid = grid
	for coord in HexMetrics.coords_within(Vector2i.ZERO, 8): grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	Feedback.force_in_tests = true

func after_each() -> void:
	Feedback.clear_grid(grid)
	Feedback.force_in_tests = false
	SelectionManager.reset()
	human.release_relations()
	rival.release_relations()
	grid.queue_free()
	for key in original:
		if key != "turn": GameManager.set(key, original[key])
	TurnManager.turn_number = original.turn
	await get_tree().process_frame

func _unit(kind: String, coord: Vector2i, owner: PlayerData = null) -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), human if owner == null else owner)

func _batches() -> Array:
	return get_tree().get_nodes_in_group(Feedback.GROUP).filter(func(node): return node.map == grid and not node.is_queued_for_deletion())

func _popups() -> Array:
	return grid.get_children().filter(func(node): return node is Label3D and (node.text.begins_with("-") or node.text.begins_with("+")))

func test_attack_resolves_now_but_bar_reaction_and_number_wait_for_contact():
	var attacker := _unit("warrior", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(1, 0), rival)
	var before := target.hp
	CombatResolver.resolve(attacker, target, grid)
	assert_lt(target.hp, before)
	assert_eq(target.presentation_hp(), before)
	assert_eq(attacker.movement_left, 0.0)
	assert_true(target._hit_reaction_tweens.is_empty())
	assert_eq(_popups().size(), 0)
	assert_eq(_batches().size(), 1)
	_batches()[0].flush()
	assert_eq(target.presentation_hp(), target.hp)
	assert_false(target._hit_reaction_tweens.is_empty())
	assert_gt(_popups().size(), 0)

func test_lethal_target_is_removed_from_rules_now_but_keeps_its_body_until_impact():
	var attacker := _unit("warrior", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(1, 0), rival)
	target.set_hp_silent(1.0)
	CombatResolver.resolve(attacker, target, grid)
	assert_null(grid.get_unit_at(Vector2i(1, 0)))
	assert_false(target in rival.units)
	assert_false(target.is_queued_for_deletion())
	assert_true(target.get_meta("feedback_retired", false))
	assert_false(target.can_receive_orders(), "corpo preservado não pode agir")
	assert_eq(target.presentation_hp(), 1.0)
	_batches()[0].flush()
	assert_lte(target.presentation_hp(), 0.0)

func test_real_spell_damage_and_cast_costs_are_immediate_but_feedback_matches_arrival():
	var caster := _unit("v2_unit_infernal_warlock", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0), rival)
	var before := target.hp
	var mana := human.mana
	assert_true(V2MagicRuntime.cast(caster, "v2_spell_infernal_flame", target.coord, grid))
	assert_lt(target.hp, before)
	assert_lt(human.mana, mana)
	assert_eq(caster.movement_left, 0.0)
	assert_eq(target.presentation_hp(), before)
	var batch = _batches()[0]
	var effect = get_tree().get_nodes_in_group(SpellVFX.GROUP).filter(func(node): return node.get_parent() == grid)[0]
	assert_almost_eq(batch.delay, effect.arrival, 0.001)
	assert_true(effect.get_meta("synchronized_feedback"))
	batch.flush()
	assert_eq(target.presentation_hp(), target.hp)

func test_heal_has_one_number_at_arrival_and_buff_visual_waits_while_rules_apply_now():
	var caster := _unit("v2_unit_sacred_cleric", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0))
	target.set_hp_silent(5.0)
	assert_true(V2MagicRuntime.cast(caster, "v2_spell_restoring_light", target.coord, grid))
	assert_gt(target.hp, 5.0)
	assert_eq(target.presentation_hp(), 5.0)
	assert_eq(_popups().size(), 0)
	_batches()[0].flush()
	assert_eq(_popups().size(), 1)
	var effect = get_tree().get_nodes_in_group(SpellVFX.GROUP).filter(func(node): return node.get_parent() == grid)[0]
	effect.age = effect.arrival + 0.1
	effect._process(0.0)
	assert_eq(_popups().size(), 1, "VFX não duplica a cura já sincronizada")
	caster.reset_movement()
	assert_true(V2MagicRuntime.cast(caster, "v2_spell_sacred_aegis", target.coord, grid))
	assert_true(V2MagicRuntime.is_status_active(target, "v2_spell_sacred_aegis"))
	assert_null(target.get_node_or_null("SacredAegis"))
	_batches().back().flush()
	assert_not_null(target.get_node_or_null("SacredAegis"))

func test_newer_damage_or_immediate_updates_cannot_be_rewound_by_old_callbacks():
	var source := _unit("warrior", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(1, 0), rival)
	var first := Feedback._begin(grid, source, 1.0)
	target.hp -= 1.0
	Feedback.finish(first)
	var second := Feedback._begin(grid, source, 1.0)
	target.hp -= 2.0
	Feedback.finish(second)
	second.flush()
	var current_hp := target.hp
	first.flush()
	assert_eq(target.presentation_hp(), current_hp)
	target.hp += 1.0
	assert_eq(target.presentation_hp(), target.hp)

func test_hidden_or_headless_actions_add_no_presentation_timeline():
	var source := _unit("warrior", Vector2i.ZERO)
	source.visible = false
	assert_null(Feedback._begin(grid, source, 1.0))
	source.visible = true
	Feedback.force_in_tests = false
	assert_null(Feedback.begin_cast(source, grid))
	assert_true(_batches().is_empty())

func test_exact_animation_marker_and_speed_override_normalized_fallback():
	var source := _unit("warrior", Vector2i.ZERO)
	var player: AnimationPlayer = source._anim_player
	var animation := Animation.new()
	animation.length = 2.0
	animation.add_marker(&"impact", 0.6)
	player.get_animation_library("").add_animation("FeedbackTest", animation)
	player.play("FeedbackTest")
	player.advance(0.0)
	player.speed_scale = 2.0
	assert_almost_eq(Feedback.attack_delay(source), 0.3, 0.001)
	player.seek(0.2)
	assert_almost_eq(Feedback.attack_delay(source), 0.2, 0.001)

func test_pending_presentations_are_bounded_and_map_reset_cancels_all_callbacks():
	var source := _unit("warrior", Vector2i.ZERO)
	for i in Feedback.MAX_PENDING:
		var batch := Feedback._begin(grid, source, 1.0)
		assert_not_null(batch)
		grid.spawn_damage_popup(Vector2i(1, 0), 1.0)
		Feedback.finish(batch)
	assert_null(Feedback._begin(grid, source, 1.0))
	Feedback.clear_grid(grid)
	assert_eq(int(grid.get_meta("feedback_pending", 0)), 0)
	assert_true(_batches().is_empty())
	assert_null(Feedback.current())

func test_retired_body_obeys_fog_and_impact_never_reveals_a_hidden_number():
	var source := _unit("warrior", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(1, 0), rival)
	target.set_hp_silent(1.0)
	CombatResolver.resolve(source, target, grid)
	var batch = _batches()[0]
	grid.visibility[target.coord] = HexGrid.Visibility.UNSEEN
	Feedback.refresh_fog(grid)
	assert_false(target.visible)
	batch.flush()
	assert_true(_popups().is_empty())

func test_moving_attack_waits_for_arrival_before_its_authored_contact():
	var attacker := _unit("warrior", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0), rival)
	grid.move_unit(attacker, Vector2i(1, 0), 1.0)
	var walking := attacker.visual_walk_remaining()
	assert_gt(walking, 0.0)
	CombatResolver.resolve(attacker, target, grid)
	assert_gt(_batches()[0].delay, walking)
	assert_ne(attacker._anim_player.current_animation, attacker.attack_animation)
	_batches()[0].flush()

func test_moving_spell_and_vfx_share_the_same_start_delay():
	var caster := _unit("v2_unit_infernal_warlock", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(3, 0), rival)
	grid.move_unit(caster, Vector2i(1, 0), 1.0)
	assert_true(V2MagicRuntime.cast(caster, "v2_spell_infernal_flame", target.coord, grid))
	var effect = get_tree().get_nodes_in_group(SpellVFX.GROUP).filter(func(node): return node.get_parent() == grid)[0]
	assert_lt(effect.age, 0.0)
	assert_almost_eq(_batches()[0].delay, effect.arrival - effect.age, 0.001)
	_batches()[0].flush()

func test_imported_contact_frames_match_the_authored_warrior_and_archer_reports():
	var unit := _unit("warrior", Vector2i.ZERO)
	var animation := Animation.new()
	animation.length = 1.33333333
	assert_almost_eq(Feedback.contact_seconds(unit, animation, "Warrior_Attack"), 14.0 / 24.0, 0.001)
	animation.length = 2.0
	assert_almost_eq(Feedback.contact_seconds(unit, animation, "Archer_Attack"), 26.0 / 24.0, 0.001)

func test_real_silence_applies_now_but_its_aura_waits_for_the_spell_arrival():
	var caster := _unit("v2_unit_arcanist", Vector2i.ZERO)
	var target := _unit("v2_unit_infernal_warlock", Vector2i(2, 0), rival)
	assert_true(V2MagicRuntime.cast(caster, "v2_spell_silence", target.coord, grid))
	assert_true(V2MagicRuntime.is_spellcasting_silenced(target))
	assert_null(target.get_node_or_null("SchoolStatus_v2_spell_silence"))
	_batches()[0].flush()
	assert_not_null(target.get_node_or_null("SchoolStatus_v2_spell_silence"))

func test_monster_poison_after_the_strike_joins_the_same_impact_timeline():
	var spider := grid.spawn_monster_at(Vector2i.ZERO, "giant_spider")
	spider.ecology_site_id = 999
	var target := _unit("warrior", Vector2i(1, 0))
	var before := target.hp
	CombatResolver.resolve(spider, target, grid)
	MonsterAbilitySystem.after_attack(spider, target, before)
	assert_true(UnitStatusEffects.is_active(target, UnitStatusEffects.POISON))
	assert_eq(_batches().size(), 1)
	assert_null(target.get_node_or_null(Unit.STATUS_MARKER_NAME))
	_batches()[0].flush()
	assert_not_null(target.get_node_or_null(Unit.STATUS_MARKER_NAME))

func test_real_timer_commits_feedback_without_any_gameplay_await():
	var attacker := _unit("warrior", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(1, 0), rival)
	CombatResolver.resolve(attacker, target, grid)
	var remaining: float = _batches()[0].delay
	assert_ne(target.presentation_hp(), target.hp)
	await get_tree().create_timer(remaining + 0.05).timeout
	assert_eq(target.presentation_hp(), target.hp)
	assert_true(_batches().is_empty())

func test_teleport_changes_occupancy_now_and_moves_the_model_at_arrival():
	var caster := _unit("v2_unit_arcanist", Vector2i.ZERO)
	var position_before := caster.position
	var destination := Vector2i(3, 0)
	assert_true(V2MagicRuntime.cast(caster, "v2_spell_arcane_step", destination, grid))
	assert_eq(caster.coord, destination)
	assert_eq(grid.get_unit_at(destination), caster)
	assert_eq(caster.position, position_before)
	_batches()[0].flush()
	assert_eq(caster.position, grid.world_surface_for_coord(destination))

func test_summon_exists_in_the_roster_now_but_appears_with_the_cast():
	var caster := _unit("v2_unit_necromancer", Vector2i.ZERO)
	var destination := Vector2i(2, 0)
	assert_true(V2MagicRuntime.cast(caster, "v2_spell_raise_dead", destination, grid))
	var summoned := grid.get_unit_at(destination)
	assert_not_null(summoned)
	assert_true(summoned in human.units)
	assert_false(summoned.visible)
	grid._apply_fog_to_entities(human)
	assert_false(summoned.visible, "recalcular neblina não antecipa a aparição")
	_batches()[0].flush()
	assert_true(summoned.visible)

func test_grove_rules_apply_now_and_its_trees_appear_on_arrival():
	var caster := _unit("v2_unit_druid", Vector2i.ZERO)
	var destination := Vector2i(2, 0)
	assert_true(V2MagicRuntime.cast(caster, "v2_spell_grow_grove", destination, grid))
	assert_true(V2TerrainRuntime.has_modification(grid, destination))
	assert_false(grid._terrain_modification_markers.has(destination))
	_batches()[0].flush()
	assert_true(grid._terrain_modification_markers.has(destination))

func test_knockback_moves_the_logical_unit_now_but_starts_sliding_on_contact():
	var attacker := _unit("warrior", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(1, 0), rival)
	var before := target.position
	var batch := Feedback._begin(grid, attacker, 1.0)
	grid.move_unit(target, Vector2i(2, 0), 0.0)
	Feedback.finish(batch)
	assert_eq(target.coord, Vector2i(2, 0))
	assert_eq(target.position, before)
	assert_false(target._walking)
	batch.flush()
	assert_true(target._walking)

func test_deferred_numbers_keep_the_original_global_rng_sequence():
	var source := _unit("warrior", Vector2i.ZERO)
	seed(112358)
	randf_range(-0.15, 0.15)
	var expected_before := randi()
	var expected_after := randi()
	seed(112358)
	var batch := Feedback._begin(grid, source, 1.0)
	grid.spawn_damage_popup(Vector2i(1, 0), 1.0)
	Feedback.finish(batch)
	assert_eq(randi(), expected_before, "mesmo consumo de RNG na chamada original")
	batch.flush()
	assert_eq(randi(), expected_after, "apresentar depois não consome RNG adicional")

func test_a_new_attack_during_recovery_restarts_its_gesture_and_keeps_a_future_contact():
	var attacker := _unit("warrior", Vector2i.ZERO)
	var target := _unit("v2_unit_guardian", Vector2i(1, 0), rival)
	CombatResolver.resolve(attacker, target, grid)
	var player: AnimationPlayer = attacker._anim_player
	player.seek(player.current_animation_length * 0.9, true)
	attacker.reset_movement()
	CombatResolver.resolve(attacker, target, grid)
	assert_eq(_batches().size(), 2)
	assert_gt(_batches().back().delay, 0.05, "um turno rápido não transforma o próximo golpe em dano visual instantâneo")

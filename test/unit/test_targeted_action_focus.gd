extends GutTest

## Regressões de foco com SelectionManager + ContextRouter reais, inclusive no impacto visual.
const Feedback := preload("res://scripts/vfx/CombatFeedback.gd")
const CLERIC := "v2_unit_sacred_cleric"
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var router: ContextRouter
var original := {}

func before_each() -> void:
	for key in ["players", "rival_players", "human_player", "hex_grid", "state"]:
		original[key] = GameManager.get(key)
	original.turn = TurnManager.turn_number
	original.feedback = Feedback.force_in_tests
	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 20
	human.mana = 600.0
	for branch in ["v2_magic_sacred", "v2_magic_arcanism", "v2_magic_druidism", "v2_doctrine_ranger", "v2_doctrine_warrior"]:
		for tier in range(2, 8): human.v2_research.complete_research("%s_%d" % [branch, tier])
	grid = HexGrid.new()
	add_child(grid)
	GameManager.hex_grid = grid
	for coord in [Vector2i.ZERO] + HexMetrics.coords_within(Vector2i.ZERO, 7):
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var host := PanelContainer.new()
	add_child_autofree(host)
	router = ContextRouter.new()
	host.add_child(router)
	router.setup(host)
	Feedback.force_in_tests = true

func after_each() -> void:
	Feedback.clear_grid(grid)
	Feedback.force_in_tests = original.feedback
	SelectionManager.reset()
	await AudioManager.drain_audio()
	human.release_relations()
	rival.release_relations()
	grid.queue_free()
	for key in original:
		if key != "turn" and key != "feedback": GameManager.set(key, original[key])
	TurnManager.turn_number = original.turn
	await get_tree().process_frame

func _unit(kind: String, coord: Vector2i, owner: PlayerData = null) -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), human if owner == null else owner)

func _select(unit: Unit) -> void:
	SelectionManager.select_unit(unit)
	router.flush()
	if router.mode != ContextRouter.MODE_UNIT:
		router.selector_button("unit").pressed.emit()
		router.flush()

func _click(coord: Vector2i) -> void:
	SelectionManager.handle_world_click(HexMetrics.axial_to_world(coord.x, coord.y, grid.hex_size))
	router.flush()

func _assert_focus(unit: Unit) -> void:
	assert_eq(SelectionManager.selected_unit, unit)
	assert_eq(router.mode, ContextRouter.MODE_UNIT, "a ação não abre o terreno nem a cidade")
	assert_eq(router.coord, unit.coord)
	assert_true(router.unit_panel.is_showing(unit))
	assert_eq(grid.visual_focus.focus_mode, VisualFocusSystem.MODE_UNIT)
	assert_eq(grid.visual_focus.focus_coord, unit.coord)
	var position := HexMetrics.axial_to_world(unit.coord.x, unit.coord.y, grid.hex_size)
	assert_almost_eq(grid._selection_marker.position.x, position.x, 0.001)
	assert_almost_eq(grid._selection_marker.position.z, position.z, 0.001)
	assert_false(SelectionManager.is_targeting())

func _cast(caster: Unit, spell: String, coord: Vector2i) -> void:
	_select(caster)
	SelectionManager.use_v2_spell_selected(spell)
	assert_eq(SelectionManager.v2_spell_targeting_id, spell)
	_click(coord)

func test_healing_an_ally_keeps_caster_focus_before_and_after_visual_impact():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0))
	target.set_hp_silent(2.0)
	_cast(caster, "v2_spell_restoring_light", target.coord)
	assert_gt(target.hp, 2.0)
	_assert_focus(caster)
	for batch in get_tree().get_nodes_in_group(Feedback.GROUP):
		if batch.map == grid: batch.flush()
	router.flush()
	_assert_focus(caster)

func test_buffing_an_ally_on_a_structure_keeps_caster_focus():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0))
	grid.place_building(target.coord, "v2_building_market", human)
	_cast(caster, "v2_spell_sacred_aegis", target.coord)
	assert_true(target.magic_status.has("v2_spell_sacred_aegis"))
	_assert_focus(caster)

func test_casting_from_a_garrison_keeps_the_open_unit_tab():
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var caster := _unit(CLERIC, Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0))
	_cast(caster, "v2_spell_sacred_aegis", target.coord)
	_assert_focus(caster)
	EventBus.fog_updated.emit()
	router.flush()
	_assert_focus(caster)

func test_self_buff_does_not_reopen_a_remembered_terrain_tab():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	_select(caster)
	router.selector_button("tile").pressed.emit()
	router.flush()
	assert_eq(router.mode, ContextRouter.MODE_TILE)
	router.open_unit(caster)
	SelectionManager.use_v2_spell_selected("v2_spell_sacred_aegis")
	_click(caster.coord)
	_assert_focus(caster)

func test_terrain_spell_keeps_the_caster_selected_and_changes_the_target():
	var caster := _unit("v2_unit_druid", Vector2i.ZERO)
	var target := Vector2i(2, 0)
	_cast(caster, "v2_spell_grow_grove", target)
	assert_not_null(V2TerrainRuntime.modification_at(grid, target))
	_assert_focus(caster)

func test_teleport_focus_follows_the_casters_actual_destination():
	var caster := _unit("v2_unit_arcanist", Vector2i.ZERO)
	var target := Vector2i(3, 0)
	_cast(caster, "v2_spell_arcane_step", target)
	assert_eq(caster.coord, target)
	_assert_focus(caster)

func test_a_cached_target_that_becomes_invalid_spends_nothing_and_keeps_focus():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0))
	target.set_hp_silent(2.0)
	_select(caster)
	SelectionManager.use_v2_spell_selected("v2_spell_restoring_light")
	target.set_hp_silent(target.unit_data.max_hp)
	var mana := human.mana
	var movement := caster.movement_left
	_click(target.coord)
	assert_eq(human.mana, mana)
	assert_eq(caster.movement_left, movement)
	_assert_focus(caster)

func test_cancelled_spell_keeps_focus_and_does_not_consume_resources():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	_select(caster)
	SelectionManager.use_v2_spell_selected("v2_spell_sacred_aegis")
	var mana := human.mana
	_click(Vector2i(6, 0))
	assert_eq(human.mana, mana)
	assert_gt(caster.movement_left, 0.0)
	_assert_focus(caster)

func test_targeted_technique_keeps_its_attacker_context():
	Diplomacy.declare_war(human, rival, "focus test", true)
	var attacker := _unit("v2_unit_archer", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0), rival)
	_select(attacker)
	SelectionManager.start_technique_targeting(attacker, V2DoctrineTechniqueDatabase.PRECISE_SHOT)
	assert_eq(SelectionManager.technique_targeting_id, V2DoctrineTechniqueDatabase.PRECISE_SHOT)
	_click(target.coord)
	assert_lt(target.hp, target.unit_data.max_hp)
	_assert_focus(attacker)

func test_losing_the_attacker_to_a_counterattack_inspects_the_target_instead():
	Diplomacy.declare_war(human, rival, "focus test", true)
	var attacker := _unit("v2_unit_warrior", Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(1, 0), rival)
	_unit("warrior", Vector2i(0, 1)) # mantém o alvo visível depois que o atacante cai
	attacker.set_hp_silent(1.0)
	target.unit_data.attack = 1000.0
	target.unit_data.defense = 1000.0
	_select(attacker)
	SelectionManager.start_technique_targeting(attacker, V2DoctrineTechniqueDatabase.POWER_STRIKE)
	assert_eq(SelectionManager.technique_targeting_id, V2DoctrineTechniqueDatabase.POWER_STRIKE)
	_click(target.coord)
	assert_lte(attacker.hp, 0.0)
	assert_null(SelectionManager.selected_unit)
	assert_eq(router.coord, target.coord)
	assert_true(router.unit_panel.is_showing(target))
	assert_false(SelectionManager.is_targeting())

func test_a_caster_removed_during_targeting_cannot_finish_casting():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0))
	target.set_hp_silent(2.0)
	_select(caster)
	SelectionManager.use_v2_spell_selected("v2_spell_restoring_light")
	grid.remove_unit(caster)
	var mana := human.mana
	_click(target.coord)
	assert_eq(human.mana, mana)
	assert_eq(target.hp, 2.0)
	assert_null(SelectionManager.selected_unit)
	assert_false(SelectionManager.is_targeting())

func test_cancelling_after_the_caster_was_removed_does_not_reselect_it():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	_select(caster)
	SelectionManager.use_v2_spell_selected("v2_spell_sacred_aegis")
	grid.remove_unit(caster)
	assert_true(SelectionManager.cancel_v2_spell_targeting())
	router.flush()
	assert_null(SelectionManager.selected_unit)
	assert_false(SelectionManager.is_targeting())

func test_a_freed_caster_does_not_crash_confirmation_or_restore_selection():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0))
	target.set_hp_silent(2.0)
	_select(caster)
	SelectionManager.use_v2_spell_selected("v2_spell_restoring_light")
	grid.remove_unit(caster)
	await get_tree().process_frame
	assert_false(is_instance_valid(caster))
	var mana := human.mana
	_click(target.coord)
	assert_eq(human.mana, mana)
	assert_eq(target.hp, 2.0)
	assert_null(SelectionManager.selected_unit)
	assert_false(SelectionManager.is_targeting())

func test_an_ordinary_click_after_casting_still_changes_selection():
	var caster := _unit(CLERIC, Vector2i.ZERO)
	var target := _unit("warrior", Vector2i(2, 0))
	_cast(caster, "v2_spell_sacred_aegis", target.coord)
	_assert_focus(caster)
	_click(target.coord)
	_assert_focus(target)
	_click(Vector2i(5, 0))
	assert_eq(router.mode, ContextRouter.MODE_TILE)
	assert_null(SelectionManager.selected_unit)

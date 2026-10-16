extends GutTest

var grid: HexGrid
var human: PlayerData
var original := {}

func before_each():
	for key in ["hex_grid", "human_player", "players", "state"]: original[key] = GameManager.get(key)
	human = PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.players = [human] as Array[PlayerData]
	GameManager.state = GameManager.GameState.PLAYING
	grid = HexGrid.new()
	grid._ready()
	autofree(grid)
	GameManager.hex_grid = grid

func after_each():
	SelectionManager.reset()
	human.release_relations()
	for key in original: GameManager.set(key, original[key])

func _tile(coord: Vector2i, terrain: int = HexTileData.TerrainType.GRASSLAND, unseen: bool = false):
	grid.tiles[coord] = TerrainDatabase.create_tile(terrain)
	grid.visibility[coord] = HexGrid.Visibility.UNSEEN if unseen else HexGrid.Visibility.VISIBLE

func _line(length: int):
	for q in length + 1: _tile(Vector2i(q, 0))
	grid.visibility[Vector2i(length, 0)] = HexGrid.Visibility.UNSEEN

func _unit(kind: String, coord: Vector2i = Vector2i.ZERO) -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), human)

func test_flying_explorer_crosses_water_without_landing_in_it():
	_line(2)
	_tile(Vector2i(1, 0), HexTileData.TerrainType.OCEAN)
	var unit := _unit("v2_manifestation_seraph")
	unit.exploring = true
	grid.explore_step(unit)
	assert_eq(unit.coord, Vector2i(2, 0))
	assert_almost_eq(unit.movement_left, unit.unit_data.movement_points - 2.0, 0.001)
	assert_false(unit.embarked)

func test_flight_uses_legal_landings_over_multiple_turns():
	_line(6)
	for q in [1, 3, 5]: _tile(Vector2i(q, 0), HexTileData.TerrainType.MOUNTAINS)
	var unit := _unit("v2_manifestation_seraph")
	unit.exploring = true
	for q in [2, 4, 6]:
		unit.reset_movement()
		grid.explore_step(unit)
		assert_eq(unit.coord, Vector2i(q, 0), "voo não pousa numa montanha nem excede o orçamento")

func test_flight_cannot_cross_a_gap_wider_than_a_full_turn():
	_line(5)
	for q in range(1, 5): _tile(Vector2i(q, 0), HexTileData.TerrainType.MOUNTAINS)
	var unit := _unit("v2_manifestation_seraph")
	unit.exploring = true
	grid.explore_step(unit)
	assert_eq(unit.coord, Vector2i.ZERO)
	assert_false(unit.exploring)

func test_infiltrator_crosses_occupied_tiles_without_overwriting_their_units():
	_line(3)
	var first := _unit("warrior", Vector2i(1, 0))
	var second := _unit("warrior", Vector2i(2, 0))
	var unit := _unit("v2_legendary_shadow_master")
	unit.exploring = true
	grid.explore_step(unit)
	assert_eq(unit.coord, Vector2i(3, 0))
	assert_eq(grid.get_unit_at(first.coord), first)
	assert_eq(grid.get_unit_at(second.coord), second)
	assert_almost_eq(unit.movement_left, 1.0, 0.001)

func test_infiltration_does_not_enter_an_occupied_tile_when_it_cannot_exit_this_turn():
	_line(3)
	var first := _unit("warrior", Vector2i(1, 0))
	var second := _unit("warrior", Vector2i(2, 0))
	var unit := _unit("v2_legendary_shadow_master")
	unit.movement_left = 2.0
	unit.exploring = true
	grid.explore_step(unit)
	assert_eq(unit.coord, Vector2i.ZERO)
	assert_true(unit.exploring, "aguarda um turno inteiro em vez de desistir")
	assert_eq(grid.get_unit_at(first.coord), first)
	assert_eq(grid.get_unit_at(second.coord), second)
	unit.reset_movement()
	grid.explore_step(unit)
	assert_eq(unit.coord, Vector2i(3, 0))

func test_infiltration_preserves_its_flat_movement_cost():
	_line(2)
	for q in [1, 2]: grid.v2_terrain_modifications[Vector2i(q, 0)] = "v2_terrain_dense_grove"
	var unit := _unit("v2_legendary_shadow_master")
	unit.exploring = true
	grid.explore_step(unit)
	assert_eq(unit.coord, Vector2i(2, 0))
	assert_almost_eq(unit.movement_left, 2.0, 0.001)

func test_twenty_four_blocked_candidates_do_not_hide_a_reachable_frontier():
	_line(8)
	var count := 0
	for coord in HexMetrics.coords_within(Vector2i.ZERO, 4):
		if coord.y == 0: continue
		_tile(coord, HexTileData.TerrainType.GRASSLAND, true)
		_unit("warrior", coord)
		count += 1
		if count == 24: break
	var unit := _unit("warrior")
	unit.exploring = true
	grid.explore_step(unit)
	assert_ne(unit.coord, Vector2i.ZERO)
	assert_true(unit.exploring)

func test_no_movement_keeps_the_order_for_the_next_turn():
	_line(3)
	var unit := _unit("v2_unit_sacred_cleric")
	unit.movement_left = 0.0
	unit.exploring = true
	grid.explore_step(unit)
	assert_eq(unit.coord, Vector2i.ZERO)
	assert_true(unit.exploring)

func test_a_boat_can_cancel_an_exploration_order_it_started_on_land():
	_line(2)
	_tile(Vector2i.ZERO, HexTileData.TerrainType.OCEAN)
	var unit := _unit("warrior")
	unit.exploring = true
	SelectionManager._select_unit(unit)
	var commands := UnitPresenter.commands_for(unit, grid)
	var explore = commands.filter(func(command): return command.id == "explore")[0]
	assert_ne(explore.state, UnitAbilityViewData.State.BLOCKED)
	SelectionManager.toggle_explore_selected()
	assert_false(unit.exploring)

func test_common_units_explore_with_their_current_movement_stats():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		grid.tiles.clear()
		grid.visibility.clear()
		_line(8)
		var unit := _unit(kind)
		if unit.unit_data.can_found_city:
			assert_true(UnitPresenter.commands_for(unit, grid).all(func(command): return command.id != "explore"), "Colonizador mantém apenas suas ações essenciais")
			grid.remove_unit(unit)
			continue
		unit.exploring = true
		grid.explore_step(unit)
		assert_ne(unit.coord, Vector2i.ZERO, kind)
		assert_true(unit.exploring, kind)
		grid.remove_unit(unit)

func test_all_six_mages_can_schedule_exploration_after_casting():
	var cases := [
		["v2_unit_sacred_cleric", "v2_spell_restoring_light", "sacred"],
		["v2_unit_infernal_warlock", "v2_spell_infernal_flame", "infernal"],
		["v2_unit_necromancer", "v2_spell_raise_dead", "necromancy"],
		["v2_unit_druid", "v2_spell_grow_grove", "druidism"],
		["v2_unit_arcanist", "v2_spell_arcane_step", "arcanism"],
		["v2_unit_elementalist", "v2_spell_dense_mist", "elementalism"],
	]
	for entry in cases:
		grid.tiles.clear()
		grid.visibility.clear()
		_line(10)
		_tile(Vector2i(-1, 0))
		human.mana = 500.0
		for tier in range(2, 8): human.v2_research.complete_research("v2_magic_%s_%d" % [entry[2], tier])
		var caster := _unit(entry[0])
		if entry[2] == "sacred":
			var target := _unit("warrior", Vector2i(-1, 0))
			target.set_hp_silent(2.0)
		elif entry[2] == "infernal":
			grid.spawn_monster_at(Vector2i(-1, 0), "goblin")
		assert_true(V2MagicRuntime.cast(caster, entry[1], Vector2i(-1, 0), grid), entry[0])
		assert_eq(caster.movement_left, 0.0, entry[0])
		SelectionManager._select_unit(caster)
		var panel := (load("res://scenes/ui/context/UnitContextPanel.tscn") as PackedScene).instantiate()
		add_child(panel)
		panel.show_unit(caster)
		var command = panel.view.commands.filter(func(item): return item.id == "explore")[0]
		assert_ne(command.state, UnitAbilityViewData.State.BLOCKED, entry[0])
		assert_eq(command.cost_text, "Ordem futura")
		panel.button_for("explore").pressed.emit()
		assert_true(caster.exploring, entry[0])
		var position := caster.coord
		caster.reset_movement()
		grid.run_standing_orders(caster)
		assert_ne(caster.coord, position, entry[0])
		panel.free()
		for unit in grid.units_by_coord.values(): grid.remove_unit(unit)

func test_retinues_need_command_to_explore_and_resume_when_it_returns():
	_line(8)
	for kind in ["v2_unit_skeleton_host", "v2_unit_macabre_host"]:
		var unit := _unit(kind)
		unit.exploring = true
		grid.explore_step(unit)
		assert_eq(unit.coord, Vector2i.ZERO, kind)
		assert_true(unit.exploring, "sem comando: a ordem aguarda")
		_tile(Vector2i(-1, 0))
		var commander := _unit("v2_unit_necromancer", Vector2i(-1, 0))
		grid.explore_step(unit)
		assert_ne(unit.coord, Vector2i.ZERO, kind)
		grid.remove_unit(commander)
		grid.remove_unit(unit)

func test_an_isolated_flight_goal_does_not_hide_another_reachable_goal():
	_line(5)
	_tile(Vector2i(0, 4), HexTileData.TerrainType.GRASSLAND, true)
	var unit := _unit("v2_manifestation_seraph")
	unit.exploring = true
	grid.explore_step(unit)
	assert_ne(unit.coord, Vector2i.ZERO)
	assert_true(unit.exploring)

func test_manual_exploration_explains_when_there_is_no_frontier():
	_line(2)
	for coord in grid.visibility: grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var unit := _unit("v2_unit_arcanist")
	SelectionManager._select_unit(unit)
	watch_signals(EventBus)
	SelectionManager.toggle_explore_selected()
	assert_false(unit.exploring)
	assert_signal_emitted_with_parameters(EventBus, "notify", ["%s: nenhuma área inexplorada acessível para explorar." % unit.unit_data.unit_name, ""])

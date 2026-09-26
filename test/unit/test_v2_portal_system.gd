extends GutTest

## Fase 21 — par persistente, travessia explícita, visibilidade, fechamento e serialização fail-safe.

const SCHOOL := "arcanism"
const SAVE_PATH := "user://test_v2_portal_phase21.json"
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _players: Array[PlayerData] = []
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	grid = HexGrid.new()
	grid._ready()
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Humano")
	rival = _player("Rival")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid

func after_each():
	SaveManager.delete_save(SAVE_PATH)
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	for player in _players:
		player.release_relations()
	_players.clear()
	if is_instance_valid(grid):
		grid.queue_free()

func _player(name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = name
	_players.append(player)
	return player

func _unit(owner: PlayerData, coord: Vector2i, kind: String = "warrior") -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func test_one_pair_per_owner_and_school_replaces_transactionally():
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i.ZERO, Vector2i(4, 0), grid))
	var first := V2PortalSystem.pair_for(human, SCHOOL, grid)
	assert_eq([first.a, first.b], [Vector2i.ZERO, Vector2i(4, 0)])
	grid.tiles[Vector2i(0, 4)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	assert_false(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i(1, 0), Vector2i(0, 4), grid))
	assert_eq(V2PortalSystem.pair_for(human, SCHOOL, grid), first, "falha preserva o par antigo")
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i(1, 0), Vector2i(5, 0), grid))
	assert_true(V2PortalSystem.endpoint_at(Vector2i.ZERO, grid).is_empty())
	assert_eq(V2PortalSystem.pair_for(human, SCHOOL, grid).b, Vector2i(5, 0))

func test_pairs_are_independent_by_owner_and_school_and_endpoints_do_not_overlap():
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i.ZERO, Vector2i(4, 0), grid))
	assert_true(V2PortalSystem.create_or_replace_pair(rival, SCHOOL, Vector2i(0, 3), Vector2i(4, 3), grid))
	assert_eq(grid.v2_portal_pairs.size(), 2)
	assert_false(V2PortalSystem.create_or_replace_pair(rival, "sacred", Vector2i(-2, 0), Vector2i(4, 0), grid), "endpoint já indexado")

func test_traversal_prefers_exact_exit_then_canonical_adjacent_and_consumes_action():
	var unit := _unit(human, Vector2i.ZERO)
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, unit.coord, Vector2i(4, 0), grid))
	assert_eq(V2PortalSystem.traversal_destination(unit, grid), Vector2i(4, 0))
	unit.exploring = true
	unit.move_order_target = Vector2i(7, 0)
	assert_true(V2PortalSystem.traverse(unit, grid))
	assert_eq([unit.coord, unit.movement_left], [Vector2i(4, 0), 0.0])
	assert_false(unit.exploring)
	assert_eq(unit.move_order_target, Unit.NO_MOVE_ORDER)
	unit.movement_left = 2.0
	_unit(human, Vector2i.ZERO)
	assert_true(V2PortalSystem.traverse(unit, grid))
	assert_eq(unit.coord, Vector2i(1, 0), "saída exata ocupada: primeiro vizinho canônico legal")

func test_traversal_requires_own_endpoint_orders_movement_visibility_and_space():
	var unit := _unit(human, Vector2i.ZERO)
	assert_true(V2PortalSystem.create_or_replace_pair(rival, SCHOOL, unit.coord, Vector2i(4, 0), grid))
	assert_eq(V2PortalSystem.traversal_reason(unit, grid), V2PortalSystem.REASON_NO_PAIR)
	V2PortalSystem.clear_all(grid)
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, unit.coord, Vector2i(4, 0), grid))
	unit.movement_left = 0.0
	assert_eq(V2PortalSystem.traversal_reason(unit, grid), V2PortalSystem.REASON_NO_MOVEMENT)
	unit.movement_left = 2.0
	grid.visibility[Vector2i(4, 0)] = HexGrid.Visibility.UNSEEN
	grid.visibility[Vector2i(3, 0)] = HexGrid.Visibility.VISIBLE
	assert_eq(V2PortalSystem.traversal_reason(unit, grid), V2PortalSystem.REASON_EXIT_HIDDEN)
	grid.visibility.clear()
	for coord in [Vector2i(4, 0)] + grid.get_neighbors(Vector2i(4, 0)):
		_unit(human, coord)
	assert_eq(V2PortalSystem.traversal_reason(unit, grid), V2PortalSystem.REASON_NO_LANDING)

func test_traversal_uses_retinue_command_gate_and_never_captures_city():
	var retinue := _unit(human, Vector2i.ZERO, "v2_unit_skeleton_host")
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, retinue.coord, Vector2i(4, 0), grid))
	# Sem um conjurador da Escola, a Hoste está fora de comando.
	assert_false(retinue.can_receive_orders())
	assert_ne(V2PortalSystem.traversal_reason(retinue, grid), "")
	var enemy_city := grid.found_city(Vector2i(4, 0), rival, "Alvo", true)
	assert_not_null(enemy_city)
	assert_eq(V2PortalSystem.traversal_destination(retinue, grid), V2PortalSystem.INVALID_COORD)
	assert_eq(enemy_city.owner_player, rival)

func test_building_resource_improvement_and_found_city_close_the_pair_but_capture_helper_can_preserve_it():
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i.ZERO, Vector2i(2, 0), grid))
	grid.place_building(Vector2i(2, 0), "v2_building_market", human, true)
	assert_true(V2PortalSystem.endpoint_at(Vector2i.ZERO, grid).is_empty(), "construção fecha os dois endpoints")
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i.ZERO, Vector2i(3, 0), grid))
	grid.tiles[Vector2i(3, 0)].resource = "iron"
	var city := grid.found_city(Vector2i(-2, 0), human, "Base", true)
	city.owned_tiles.append(Vector2i(3, 0))
	var builder := _unit(human, Vector2i(3, 0), "v2_unit_builder")
	builder.work_charges_remaining = 1
	assert_true(V2ConstructorRuntime.improve_resource(builder, grid))
	assert_true(grid.v2_portal_pairs.is_empty())
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i.ZERO, Vector2i(4, 0), grid))
	grid.found_city(Vector2i(4, 0), human, "Nova", true)
	assert_true(grid.v2_portal_pairs.is_empty())

func test_capture_preserves_a_pair_and_raw_resources_enemy_territory_and_druid_terrain_are_legal():
	var enemy_city := grid.found_city(Vector2i(4, 0), rival, "Cidade Rival", true)
	var endpoint := Vector2i(3, 0)
	grid.get_tile(endpoint).resource = "gems"
	assert_true(V2TerrainRuntime.apply(grid, endpoint, "v2_terrain_dense_grove"))
	assert_true(endpoint in enemy_city.owned_tiles)
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i.ZERO, endpoint, grid))
	grid.capture_city(enemy_city, human)
	assert_eq(V2PortalSystem.paired_endpoint(Vector2i.ZERO, grid), endpoint, "captura/anexação não é construção")
	assert_eq(grid.get_tile(endpoint).resource, "gems")
	assert_true(V2TerrainRuntime.has_modification(grid, endpoint))

func test_real_save_manager_round_trip_restores_owner_pair_indexes_and_markers():
	grid.found_city(Vector2i(-4, 0), human, "Capital", true)
	grid.found_city(Vector2i(4, 0), rival, "Rival", true)
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i(-3, 0), Vector2i(3, 0), grid))
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var saved_text := FileAccess.get_file_as_string(SAVE_PATH)
	assert_true(saved_text.contains("v2_portal_pairs"))
	for forbidden in ["marker", "endpoint_index", "owner_school_index"]:
		assert_false(saved_text.contains(forbidden), "índices/visual derivado não são persistidos: %s" % forbidden)
	var old_grid := grid
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid = loaded
	GameManager.hex_grid = loaded
	_players.append_array(GameManager.players)
	human = GameManager.human_player
	rival = GameManager.rival_players[0]
	old_grid.queue_free()
	assert_eq(V2PortalSystem.paired_endpoint(Vector2i(-3, 0), grid), Vector2i(3, 0))
	assert_eq(int(V2PortalSystem.pair_for(human, SCHOOL, grid).owner_index), GameManager.players.find(human))
	assert_true(grid.v2_portal_endpoint_index.has(Vector2i(-3, 0)))
	assert_true(grid.v2_portal_owner_school_index.has("0:arcanism"))
	assert_true(grid._v2_portal_markers.has(Vector2i(-3, 0)))
	assert_true(grid._v2_portal_markers.has(Vector2i(3, 0)))
	assert_true(grid._v2_portal_markers[Vector2i(-3, 0)].get_child_count() > 0)

func test_save_array_round_trip_and_malformed_or_duplicate_records_are_ignored():
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i.ZERO, Vector2i(4, 0), grid))
	assert_true(V2PortalSystem.create_or_replace_pair(rival, SCHOOL, Vector2i(0, 3), Vector2i(4, 3), grid))
	var saved := V2PortalSystem.to_save_array(grid)
	saved.append(saved[0].duplicate(true))
	saved.append({"owner_index": 99, "school": SCHOOL, "a": [1, 1], "b": [2, 2]})
	saved.append({"owner_index": 0, "school": "unknown", "a": [1, 1], "b": [2, 2]})
	saved.append({"owner_index": "bad"})
	V2PortalSystem.clear_all(grid)
	assert_eq(V2PortalSystem.load_save_array(saved, grid), 2)
	assert_eq(V2PortalSystem.to_save_array(grid).size(), 2)
	assert_eq(V2PortalSystem.paired_endpoint(Vector2i.ZERO, grid), Vector2i(4, 0))
	assert_eq(V2PortalSystem.load_save_array(null, grid), 0, "campo ausente/errado carrega vazio")

func test_indexes_are_constant_time_dictionaries_and_no_process_hook_exists():
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i.ZERO, Vector2i(4, 0), grid))
	assert_true(grid.v2_portal_endpoint_index.has(Vector2i.ZERO))
	assert_true(grid.v2_portal_owner_school_index.has("0:arcanism"))
	var source := FileAccess.get_file_as_string("res://scripts/core/V2PortalSystem.gd")
	assert_false(source.contains("func _process"))
	assert_false(source.contains("compute_reachable("))
	assert_false(source.contains("compute_path("))

func test_an_active_portal_never_changes_ground_pathfinding_or_its_cost():
	var start := Vector2i(-4, 0)
	var destination := Vector2i(4, 0)
	var before_path := grid.compute_path(start, destination, human)
	var before_reachable := grid.compute_reachable(start, 6.0, human)
	assert_true(V2PortalSystem.create_or_replace_pair(human, SCHOOL, Vector2i(-3, 0), Vector2i(3, 0), grid))
	var after_path := grid.compute_path(start, destination, human)
	var after_reachable := grid.compute_reachable(start, 6.0, human)
	assert_eq(after_path, before_path)
	assert_eq(after_reachable, before_reachable)

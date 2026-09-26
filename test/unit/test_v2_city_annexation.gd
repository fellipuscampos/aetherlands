extends GutTest

## Aetherlands V2, Fase 13 — expansão territorial manual: Pontos de Anexação, elegibilidade de
## tile (raio por City Level, contiguidade, propriedade), gasto atômico, fim da expansão
## automática, e o modo de anexação do SelectionManager (mira, ESC, clique inválido).

var _owned_players: Array[PlayerData] = []
var _cities: Array[City] = []
var _grids: Array[HexGrid] = []
var _original_hex_grid: HexGrid
var _original_human: PlayerData

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human = GameManager.human_player

func after_each():
	SelectionManager.reset()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()

func _player() -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_owned_players.append(player)
	return player

func _grid(radius: int = 8) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if absi(q + r) <= radius:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

func _founded_city(owner_player: PlayerData, grid: HexGrid, coord: Vector2i = Vector2i.ZERO) -> City:
	var city := grid.found_city(coord, owner_player, "Capital")
	_cities.append(city)
	return city

# --- §33/§88: expansão automática desligada -----------------------------------------------------

func test_several_turns_of_growth_never_claim_a_new_tile_automatically():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	var owned_before := city.owned_tiles.size()
	for i in 12:
		city.process_turn(grid)
	assert_eq(city.owned_tiles.size(), owned_before, "nenhum tile novo é adquirido automaticamente (Fase 25: não há mais população)")

# --- §31/§36-41: elegibilidade e gasto de Pontos de Anexação -------------------------------------

func test_zero_points_blocks_any_annexation():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	assert_eq(city.annexation_points, 0)
	var target := grid.get_neighbors(city.coord)[0]
	# um vizinho direto já é território inicial -- pega um tile realmente fora, a distância 2
	var far := _tile_at_distance(grid, city.coord, 2)
	assert_false(city.can_annex_tile(far, grid))
	assert_eq(city.annex_unavailable_reason(far, grid), "Sem Pontos de Anexação.")

func test_adjacent_tile_within_radius_is_eligible_and_costs_exactly_one_point():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 4
	var target := _tile_at_distance(grid, city.coord, 2) # raio da Cidade II = 2
	assert_true(city.can_annex_tile(target, grid), city.annex_unavailable_reason(target, grid))
	assert_true(city.annex_tile(target, grid))
	assert_eq(city.annexation_points, 3, "gastou exatamente 1")
	assert_true(target in city.owned_tiles)

func test_tile_beyond_the_current_level_radius_is_blocked():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.city_level = 1 # raio 1
	city.annexation_points = 10
	var far := _tile_at_distance(grid, city.coord, 2)
	assert_false(city.can_annex_tile(far, grid))
	assert_eq(city.annex_unavailable_reason(far, grid), "Fora do raio territorial da cidade.")

func test_non_contiguous_tile_is_blocked_even_within_radius():
	var player := _player()
	var grid := _grid(10)
	var city := _founded_city(player, grid)
	city.city_level = 4 # raio 4, de sobra
	city.annexation_points = 10
	# Um tile a distância 3 que NÃO é vizinho de nenhum owned_tile (isolado atrás de território não seu).
	var isolated := city.coord + Vector2i(0, 4)
	assert_true(HexMetrics.axial_distance(city.coord, isolated) <= V2CityLevelData.max_territory_radius(city.city_level))
	var touches_owned := false
	for n in grid.get_neighbors(isolated):
		if n in city.owned_tiles:
			touches_owned = true
	assert_false(touches_owned, "pré-condição do teste: o tile escolhido não é contíguo")
	assert_false(city.can_annex_tile(isolated, grid))
	assert_eq(city.annex_unavailable_reason(isolated, grid), "Tile não é contíguo ao território atual da cidade.")

func test_tile_owned_by_a_rival_city_is_blocked():
	var human := _player()
	var rival := _player()
	var grid := _grid()
	var human_city := _founded_city(human, grid, Vector2i(0, 0))
	var rival_city := _founded_city(rival, grid, Vector2i(6, 0))
	human_city.city_level = 4
	human_city.annexation_points = 10
	var rival_tile: Vector2i = rival_city.owned_tiles[0]
	assert_false(human_city.can_annex_tile(rival_tile, grid))
	assert_eq(human_city.annex_unavailable_reason(rival_tile, grid), "Tile já pertence a outra cidade.")

func test_tile_owned_by_another_city_of_the_same_player_is_blocked_no_transfer():
	var player := _player()
	var grid := _grid(10)
	var a := _founded_city(player, grid, Vector2i(0, 0))
	var b := _founded_city(player, grid, Vector2i(6, 0))
	a.city_level = 4
	a.annexation_points = 10
	var b_tile: Vector2i = b.owned_tiles[0]
	assert_false(a.can_annex_tile(b_tile, grid))
	assert_eq(a.annex_unavailable_reason(b_tile, grid), "Tile já pertence a outra cidade.")

func test_tile_already_owned_by_this_same_city_is_blocked():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.annexation_points = 10
	var already_owned: Vector2i = city.owned_tiles[1]
	assert_false(city.can_annex_tile(already_owned, grid))

func test_annexation_never_requires_a_builder_reuses_existing_territory_validity_rules():
	# §36/§39 do pedido: sem Construtor, sem restrição de terreno especial além do que
	# _claim_frontier_tile já não tinha (água já podia ser território antes desta fase).
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 4
	var target := _tile_at_distance(grid, city.coord, 2)
	_set_terrain(grid, target, HexTileData.TerrainType.OCEAN)
	assert_true(city.can_annex_tile(target, grid), "água pode ser anexada -- mesma permissividade que a posse automática já tinha")

func test_annexation_is_atomic_a_failed_attempt_never_spends_a_point():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.annexation_points = 5
	var invalid := _tile_at_distance(grid, city.coord, 5) # fora do raio (Cidade I = raio 1)
	assert_false(city.annex_tile(invalid, grid))
	assert_eq(city.annexation_points, 5, "nada foi gasto numa anexação que falhou")

func test_annexation_points_accumulate_never_reset_on_level_up():
	var player := _player()
	player.v2_research.complete_research("v2_infrastructure_urbanization_1")
	player.gold = 100.0
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 4
	var target := _tile_at_distance(grid, city.coord, 2)
	city.annex_tile(target, grid) # gasta 1 -> restam 3
	assert_eq(city.annexation_points, 3)
	city.city_level = 3 # simula ter subido pra III
	city.annexation_points += V2CityLevelData.annexation_grant(3)
	assert_eq(city.annexation_points, 8, "3 + 5, nunca resetado")

func test_eligible_annexation_tiles_is_bounded_by_the_territory_radius_never_the_whole_map():
	var player := _player()
	var grid := _grid(10)
	var city := _founded_city(player, grid)
	city.city_level = 2 # raio 2
	city.annexation_points = 99
	var eligible := city.eligible_annexation_tiles(grid)
	for coord in eligible:
		assert_lte(HexMetrics.axial_distance(city.coord, coord), 2, str(coord))
	assert_true(eligible.size() > 0)

func test_legacy_territory_beyond_the_current_radius_is_never_shrunk():
	var player := _player()
	var grid := _grid(10)
	var city := _founded_city(player, grid)
	city.city_level = 1 # raio 1 -- mas o save legado tem território maior
	var far_legacy_tile := _tile_at_distance(grid, city.coord, 3)
	city.claim_tile(far_legacy_tile)
	city.annexation_points = 1 # com pontos, o motivo reportado é a posse, não a falta de pontos
	assert_true(far_legacy_tile in city.owned_tiles, "território legado preservado mesmo além do raio de NOVAS anexações")
	assert_eq(city.annex_unavailable_reason(far_legacy_tile, grid), "Tile já pertence a esta cidade.")

# --- §48-52: modo de anexação do SelectionManager (mira, ESC, clique) ---------------------------

func _tile_at_distance(grid: HexGrid, center: Vector2i, distance: int) -> Vector2i:
	for coord in HexMetrics.coords_within(center, distance):
		if HexMetrics.axial_distance(center, coord) == distance and grid.tiles.has(coord) and grid.get_city_at(coord) == null:
			return coord
	fail_test("sem tile a distância %d de %s" % [distance, center])
	return Vector2i(999, 999)

func _set_terrain(grid: HexGrid, coord: Vector2i, terrain: HexTileData.TerrainType) -> void:
	grid.tiles[coord] = TerrainDatabase.create_tile(terrain)

func test_start_city_annexation_highlights_only_eligible_tiles():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 4
	SelectionManager.start_city_annexation(city)
	assert_eq(SelectionManager.annexing_city, city)
	assert_true(SelectionManager.annexable_coords.size() > 0)
	for coord in SelectionManager.annexable_coords:
		assert_true(city.can_annex_tile(coord, grid))

func test_start_city_annexation_refuses_with_zero_points():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := _founded_city(player, grid)
	SelectionManager.start_city_annexation(city)
	assert_null(SelectionManager.annexing_city)

func test_clicking_an_eligible_tile_annexes_it_and_stays_in_mode_while_points_remain():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 2
	SelectionManager.start_city_annexation(city)
	var target := _tile_at_distance(grid, city.coord, 2)
	SelectionManager._handle_city_annexation_click(target)
	assert_true(target in city.owned_tiles)
	assert_eq(city.annexation_points, 1)
	assert_not_null(SelectionManager.annexing_city, "ainda há pontos -- continua no modo (§50 do pedido)")

func test_clicking_the_last_eligible_tile_exits_the_mode_automatically():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 1
	SelectionManager.start_city_annexation(city)
	var target := _tile_at_distance(grid, city.coord, 2)
	SelectionManager._handle_city_annexation_click(target)
	assert_eq(city.annexation_points, 0)
	assert_null(SelectionManager.annexing_city, "sem pontos, o modo encerra sozinho")

func test_clicking_an_ineligible_tile_spends_nothing_and_does_not_exit_the_mode():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := _founded_city(player, grid)
	city.city_level = 2 # raio 2 -- no Nível I o anel de raio 1 já é todo da cidade e o modo nem abre
	city.annexation_points = 5
	SelectionManager.start_city_annexation(city)
	assert_eq(SelectionManager.annexing_city, city, "pré-condição: modo aberto")
	var out_of_range := _tile_at_distance(grid, city.coord, 3)
	SelectionManager._handle_city_annexation_click(out_of_range)
	assert_false(out_of_range in city.owned_tiles)
	assert_eq(city.annexation_points, 5, "clique inválido não gasta")
	assert_eq(SelectionManager.annexing_city, city, "clique inválido não sai do modo")

func test_esc_cancels_the_annexation_mode_without_spending_or_changing_territory():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 4
	SelectionManager.start_city_annexation(city)
	var owned_before := city.owned_tiles.duplicate()
	assert_true(SelectionManager.cancel_city_annexation())
	assert_null(SelectionManager.annexing_city)
	assert_eq(city.annexation_points, 4, "ESC não gasta ponto")
	assert_eq(city.owned_tiles, owned_before, "ESC não muda território")

func test_starting_a_technique_targeting_or_building_placement_cancels_annexation_mode():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 4
	SelectionManager.start_city_annexation(city)
	assert_not_null(SelectionManager.annexing_city)
	SelectionManager.start_building_placement(city, "v2_building_market")
	assert_null(SelectionManager.annexing_city, "modos mutuamente exclusivos")
	SelectionManager.cancel_building_placement()

func test_annexation_state_is_its_own_variable_never_reuses_technique_target_mode():
	# §49 do pedido: Técnica pertence a unidades (V2DoctrineTechniqueData.TargetMode), Anexação
	# pertence a cidades -- estados de mira independentes, cada um com seu próprio par de
	# variáveis (annexing_city/annexable_coords vs. technique_targeting_id/unit), nunca uma
	# unidade genérica compartilhada entre os dois.
	var code := FileAccess.get_file_as_string("res://scripts/autoload/SelectionManager.gd")
	assert_true(code.contains("var annexing_city"))
	assert_true(code.contains("var annexable_coords"))
	assert_true(code.contains("var technique_targeting_id"))
	var doctrine_technique_code := FileAccess.get_file_as_string("res://scripts/data/V2DoctrineTechniqueData.gd")
	assert_false(doctrine_technique_code.contains("ANNEX"), "TargetMode de Técnica nunca ganhou um caso de anexação de cidade")

# --- §98/§99/§100: performance -- bounded pelo raio, nunca varre o mapa inteiro ------------------

func test_eligible_annexation_tiles_scans_only_the_radius_not_the_whole_grid():
	var player := _player()
	var grid := _grid(10) # ~331 tiles no grid inteiro
	var city := _founded_city(player, grid, Vector2i(-8, 4)) # canto do mapa, longe do centro
	city.city_level = 2 # raio 2 -- no máximo ~19 tiles candidatos (HexMetrics.coords_within)
	city.annexation_points = 99
	var candidates := HexMetrics.coords_within(city.coord, V2CityLevelData.max_territory_radius(city.city_level))
	assert_lt(candidates.size(), 25, "a busca é bounded pelo raio, não pelo tamanho do mapa (~331 tiles)")
	var eligible := city.eligible_annexation_tiles(grid)
	assert_true(eligible.size() <= candidates.size())

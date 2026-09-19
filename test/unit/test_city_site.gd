extends GutTest

## Task 22 -- CitySite: regra estrutural de fundacao (distancia minima entre
## centros urbanos, terreno, territorio alheio, covil/predio) e avaliacao de
## local (espacamento, recursos raros, retorno decrescente, seguranca,
## histerese). Grades planas pequenas, sem simulacao -- as metricas em
## partidas completas vivem em test/integration/test_city_placement.gd.

var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_min_distance: int

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_min_distance = CitySite.min_city_distance

func after_each():
	SelectionManager.selected_unit = null
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	CitySite.min_city_distance = _original_min_distance

# ---------------------------------------------------------------------------
# Regressoes estruturais (CitySite) -- grade plana pequena, sem simulacao
# ---------------------------------------------------------------------------

func _flat_grid(radius: int) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var coord := Vector2i(q, r)
			if HexMetrics.axial_distance(coord, Vector2i.ZERO) <= radius:
				grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	return grid

func _player() -> PlayerData:
	return PlayerData.new(CivilizationData.new())

func _settler_at(grid: HexGrid, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("settler"), player, coord)
	player.units.append(unit)
	grid.units_by_coord[coord] = unit
	unit.reset_movement()
	return unit

func test_rule_rejects_cities_closer_than_the_minimum_for_any_owner():
	var grid := _flat_grid(10)
	var mine := _player()
	var other := _player()
	grid.found_city(Vector2i.ZERO, other, "Alheia")
	for distance in range(1, CitySite.min_city_distance):
		assert_eq(CitySite.rejection_reason(grid, Vector2i(distance, 0), mine), CitySite.REASON_TOO_CLOSE, "distancia %d deveria ser recusada" % distance)
	assert_eq(CitySite.rejection_reason(grid, Vector2i(CitySite.min_city_distance, 0), mine), "", "a distancia minima em si e' valida")
	grid.free()

func test_rule_applies_to_the_players_own_cities_too():
	var grid := _flat_grid(10)
	var mine := _player()
	grid.found_city(Vector2i.ZERO, mine, "Propria")
	assert_eq(CitySite.rejection_reason(grid, Vector2i(2, 0), mine), CitySite.REASON_TOO_CLOSE)
	grid.free()

func test_rule_rejects_water_mountain_lava_and_existing_city():
	var grid := _flat_grid(6)
	var mine := _player()
	grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	grid.tiles[Vector2i(0, 5)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	grid.tiles[Vector2i(-5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA)
	assert_eq(CitySite.rejection_reason(grid, Vector2i(5, 0), mine), CitySite.REASON_TERRAIN)
	assert_eq(CitySite.rejection_reason(grid, Vector2i(0, 5), mine), CitySite.REASON_TERRAIN)
	assert_eq(CitySite.rejection_reason(grid, Vector2i(-5, 0), mine), CitySite.REASON_TERRAIN)
	assert_eq(CitySite.rejection_reason(grid, Vector2i(99, 99), mine), CitySite.REASON_TERRAIN, "fora do mapa")
	grid.found_city(Vector2i(0, -5), mine, "Existente")
	assert_eq(CitySite.rejection_reason(grid, Vector2i(0, -5), mine), CitySite.REASON_CITY)
	grid.free()

func test_rule_rejects_foreign_territory_but_allows_own_territory():
	var grid := _flat_grid(12)
	var mine := _player()
	var other := _player()
	var foreign_city := grid.found_city(Vector2i.ZERO, other, "Alheia")
	foreign_city.owned_tiles.append(Vector2i(5, 0)) # territorio cresceu alem do minimo
	assert_eq(CitySite.rejection_reason(grid, Vector2i(5, 0), mine), CitySite.REASON_FOREIGN_TERRITORY)
	assert_eq(CitySite.rejection_reason(grid, Vector2i(5, 0), other), "", "territorio proprio nao bloqueia")
	grid.free()

func test_rule_rejects_lair_and_building_tiles():
	var grid := _flat_grid(8)
	var mine := _player()
	var lair := LairStructure.new()
	var building := Building.new()
	grid.lairs_by_coord[Vector2i(6, 0)] = lair
	grid.buildings_by_coord[Vector2i(0, 6)] = building
	assert_eq(CitySite.rejection_reason(grid, Vector2i(6, 0), mine), CitySite.REASON_LAIR)
	assert_eq(CitySite.rejection_reason(grid, Vector2i(0, 6), mine), CitySite.REASON_BUILDING)
	grid.lairs_by_coord.clear()
	grid.buildings_by_coord.clear()
	lair.free()
	building.free()
	grid.free()

func test_found_city_from_settler_refuses_an_invalid_site_and_keeps_the_settler():
	var grid := _flat_grid(8)
	var mine := _player()
	var other := _player()
	grid.found_city(Vector2i.ZERO, other, "Alheia")
	var settler := _settler_at(grid, mine, Vector2i(2, 0))
	assert_null(WorldSetup.found_city_from_settler(grid, settler))
	assert_true(mine.units.has(settler), "colonizador nao deveria ser consumido")
	assert_null(grid.get_city_at(Vector2i(2, 0)))
	grid.free()

func test_found_city_from_settler_works_for_a_valid_site():
	var grid := _flat_grid(8)
	var mine := _player()
	mine.civ.civ_name = "Teste"
	var settler := _settler_at(grid, mine, Vector2i(4, 0))
	grid.found_city(Vector2i.ZERO, mine, "Capital")
	var city := WorldSetup.found_city_from_settler(grid, settler)
	assert_not_null(city)
	assert_eq(grid.get_city_at(Vector2i(4, 0)), city)
	grid.free()

func test_reason_text_is_never_empty_for_a_rejection():
	for reason in [CitySite.REASON_TERRAIN, CitySite.REASON_CITY, CitySite.REASON_BUILDING, CitySite.REASON_LAIR, CitySite.REASON_TOO_CLOSE, CitySite.REASON_FOREIGN_TERRITORY]:
		assert_ne(CitySite.reason_text(reason), "", reason)
	assert_eq(CitySite.reason_text(""), "")

# --- Avaliacao ---------------------------------------------------------------

func _score(grid: HexGrid, player: PlayerData, coord: Vector2i) -> Dictionary:
	return CitySite.evaluate(grid, coord, CitySite.build_context(grid, player))

func test_score_prefers_the_ideal_spacing_band_over_crowding_and_stretching():
	var grid := _flat_grid(20)
	var mine := _player()
	grid.found_city(Vector2i.ZERO, mine, "Capital")
	var crowded := float(_score(grid, mine, Vector2i(4, 0)).total)
	var ideal := float(_score(grid, mine, Vector2i(6, 0)).total)
	var stretched := float(_score(grid, mine, Vector2i(14, 0)).total)
	assert_gt(ideal, crowded, "espacamento ideal deveria vencer o apertado")
	assert_gt(ideal, stretched, "espacamento ideal deveria vencer o esticado")

func test_a_rare_resource_cluster_can_justify_a_more_distant_site():
	var grid := _flat_grid(20)
	var mine := _player()
	grid.found_city(Vector2i.ZERO, mine, "Capital")
	var far := Vector2i(11, 0) # esticado (4 alem do ideal), mas nada o impede
	var plain_far := float(_score(grid, mine, far).total)
	for dir in HexGrid.NEIGHBOR_DIRS:
		var data: HexTileData = grid.tiles[far + dir]
		data.resource = "mana_node"
	var with_nodes := float(_score(grid, mine, far).total)
	var near_plain := float(_score(grid, mine, Vector2i(6, 0)).total)
	assert_gt(with_nodes, plain_far)
	assert_gt(with_nodes, near_plain, "um aglomerado de Nodulos Arcanos deveria compensar a distancia")

func test_a_single_common_resource_does_not_justify_a_distant_site():
	var grid := _flat_grid(20)
	var mine := _player()
	grid.found_city(Vector2i.ZERO, mine, "Capital")
	var far := Vector2i(13, 0)
	grid.tiles[far + HexGrid.NEIGHBOR_DIRS[0]].resource = "horses"
	assert_lt(float(_score(grid, mine, far).total), float(_score(grid, mine, Vector2i(6, 0)).total))

func test_repeated_resource_types_are_worth_less():
	var grid := _flat_grid(20)
	var mine := _player()
	var coord := Vector2i(9, 0)
	grid.tiles[coord + HexGrid.NEIGHBOR_DIRS[0]].resource = "iron"
	var first := float(_score(grid, mine, coord).parts.resources)
	grid.found_city(Vector2i(0, 0), mine, "Capital")
	grid.tiles[Vector2i(1, 0)].resource = "iron"
	grid.tiles[Vector2i(0, 1)].resource = "iron"
	var after := float(_score(grid, mine, coord).parts.resources)
	assert_lt(after, first, "ja controlo Ferro: mais uma fonte vale menos")

func test_arcane_strategy_values_mana_nodes_more():
	var grid := _flat_grid(20)
	var military := _player()
	var arcane := _player()
	arcane.personality = {CityIdentity.AXIS_ARCANA: 1.0}
	var coord := Vector2i(6, 0)
	grid.tiles[coord + HexGrid.NEIGHBOR_DIRS[0]].resource = "mana_node"
	assert_gt(float(_score(grid, arcane, coord).parts.resources), float(_score(grid, military, coord).parts.resources))

func test_rival_pressure_reduces_the_score():
	var grid := _flat_grid(20)
	var mine := _player()
	var other := _player()
	var coord := Vector2i(6, 0)
	var clean := float(_score(grid, mine, coord).total)
	grid.found_city(Vector2i(10, 0), other, "Rival") # distancia 4 do candidato (dentro de RIVAL_PRESSURE_RADIUS)
	assert_lt(float(_score(grid, mine, coord).total), clean)

func test_choose_site_never_returns_an_invalid_or_unreachable_site():
	var grid := _flat_grid(14)
	var mine := _player()
	mine.civ.civ_name = "Teste"
	grid.found_city(Vector2i.ZERO, mine, "Capital")
	var settler := _settler_at(grid, mine, Vector2i(1, 0))
	for coord in grid.tiles.keys():
		mine.explored_tiles[coord] = true
	var site := CitySite.choose_site(grid, mine, settler)
	assert_false(site.is_empty())
	assert_eq(CitySite.rejection_reason(grid, site.coord, mine), "")
	assert_false(grid.compute_path(settler.coord, site.coord, mine).is_empty())
	assert_gte(HexMetrics.axial_distance(site.coord, Vector2i.ZERO), CitySite.min_city_distance)
	grid.free()

func test_choose_site_without_known_tiles_finds_nothing():
	var grid := _flat_grid(10)
	var mine := _player()
	grid.found_city(Vector2i.ZERO, mine, "Capital")
	var settler := _settler_at(grid, mine, Vector2i(1, 0))
	assert_true(CitySite.choose_site(grid, mine, settler).is_empty(), "a IA nunca usa mapa que nao explorou")
	grid.free()

func test_choose_site_keeps_the_previous_target_when_the_alternative_is_only_marginally_better():
	var grid := _flat_grid(14)
	var mine := _player()
	mine.civ.civ_name = "Teste"
	grid.found_city(Vector2i.ZERO, mine, "Capital")
	var settler := _settler_at(grid, mine, Vector2i(1, 0))
	for coord in grid.tiles.keys():
		mine.explored_tiles[coord] = true
	var first := CitySite.choose_site(grid, mine, settler)
	settler.settle_target = first.coord
	var second := CitySite.choose_site(grid, mine, settler)
	assert_eq(second.coord, first.coord, "sem mudanca no mapa, o alvo nao deveria oscilar")
	grid.free()

func test_ai_settler_founds_at_the_chosen_site_and_never_next_to_a_city():
	var grid := _flat_grid(14)
	var mine := _player()
	mine.civ.civ_name = "Teste"
	GameManager.hex_grid = grid
	grid.found_city(Vector2i.ZERO, mine, "Capital")
	var settler := _settler_at(grid, mine, Vector2i(1, 0))
	for coord in grid.tiles.keys():
		mine.explored_tiles[coord] = true
	for i in range(10):
		if not mine.units.has(settler):
			break
		settler.reset_movement()
		RivalAI._handle_settler(settler, grid, mine)
	assert_eq(mine.cities.size(), 2, "o colonizador deveria fundar a segunda cidade")
	assert_gte(HexMetrics.axial_distance(mine.cities[1].coord, Vector2i.ZERO), CitySite.min_city_distance)
	grid.free()

func test_ai_does_not_produce_a_settler_when_no_site_is_acceptable():
	var grid := _flat_grid(4) # pequeno demais: nenhum local a 4+ com valor aceitavel dentro do mapa
	var mine := _player()
	var other := _player()
	GameManager.hex_grid = grid
	var city := grid.found_city(Vector2i.ZERO, mine, "Capital")
	# Todo o mapa tomado por territorio alheio => nenhum local valido.
	var foreign := grid.found_city(Vector2i(4, 0), other, "Alheia")
	for coord in grid.tiles.keys():
		if coord != Vector2i.ZERO and HexMetrics.axial_distance(coord, Vector2i.ZERO) >= CitySite.min_city_distance:
			foreign.owned_tiles.append(coord)
	for coord in grid.tiles.keys():
		mine.explored_tiles[coord] = true
	assert_false(CitySite.has_acceptable_site(grid, mine))
	RivalAI.decide_production(mine, grid, other)
	assert_ne(city.production_item, "settler")
	grid.free()


# --- Jogador humano: a MESMA regra (nada de `if ai`) ----------------------------

func test_human_founding_is_refused_next_to_a_city_with_feedback():
	var grid := _flat_grid(8)
	var human := _player()
	GameManager.hex_grid = grid
	GameManager.human_player = human
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var settler := _settler_at(grid, human, Vector2i(2, 0))
	SelectionManager.selected_unit = settler
	watch_signals(EventBus)

	SelectionManager.found_city_with_selected()

	assert_null(grid.get_city_at(Vector2i(2, 0)), "o jogador tambem nao pode fundar colado numa cidade")
	assert_true(human.units.has(settler), "colonizador nao e' consumido numa fundacao recusada")
	assert_signal_emitted(EventBus, "notify", "o jogador deveria ser avisado do motivo")
	grid.free()

func test_human_founding_works_at_a_valid_distance():
	var grid := _flat_grid(10)
	var human := _player()
	human.civ.civ_name = "Teste"
	GameManager.hex_grid = grid
	GameManager.human_player = human
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var settler := _settler_at(grid, human, Vector2i(CitySite.min_city_distance + 2, 0))
	SelectionManager.selected_unit = settler

	SelectionManager.found_city_with_selected()

	assert_not_null(grid.get_city_at(Vector2i(CitySite.min_city_distance + 2, 0)))
	grid.free()

extends GutTest

## Roadmap "Fase F" F1/F2 -- cobre as funcoes PURAS de VictoryConditions.gd
## (avaliacao de condicao + progresso das 3 vitorias alternativas). Nenhum
## teste aqui muta estado de jogo real nem passa por GameManager/
## check_game_over -- isso fica pra uma fatia de integracao futura.

var _created_units: Array[Unit] = []
var _created_cities: Array[City] = []
var _created_hex_grids: Array[HexGrid] = []

func after_each():
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	for city in _created_cities:
		if is_instance_valid(city):
			city.queue_free()
	for grid in _created_hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_created_units = []
	_created_cities = []
	_created_hex_grids = []

func _make_city(coord: Vector2i, owned_tiles: Array[Vector2i] = []) -> City:
	var city := City.new()
	city.coord = coord
	city.owned_tiles = owned_tiles
	_created_cities.append(city)
	return city

func _make_unit(player: PlayerData) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), player, Vector2i(0, 0))
	player.units.append(unit)
	_created_units.append(unit)
	return unit

func _make_grid_with_tiles(assignments: Dictionary) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for coord in assignments.keys():
		grid.tiles[coord] = TerrainDatabase.create_tile(assignments[coord])
	_created_hex_grids.append(grid)
	return grid

## --- Dominacao -----------------------------------------------------------

func test_dominance_achieved_when_all_others_eliminated():
	var human = PlayerData.new(CivilizationData.new())
	var rival = PlayerData.new(CivilizationData.new())
	var players: Array[PlayerData] = [human, rival]
	assert_true(VictoryConditions.is_dominance_achieved(human, players))

func test_dominance_not_achieved_while_a_rival_has_units():
	var human = PlayerData.new(CivilizationData.new())
	var rival = PlayerData.new(CivilizationData.new())
	_make_unit(rival)
	var players: Array[PlayerData] = [human, rival]
	assert_false(VictoryConditions.is_dominance_achieved(human, players))

func test_dominance_not_achieved_while_a_rival_has_a_city():
	var human = PlayerData.new(CivilizationData.new())
	var rival = PlayerData.new(CivilizationData.new())
	rival.cities.append(_make_city(Vector2i(0, 0)))
	var players: Array[PlayerData] = [human, rival]
	assert_false(VictoryConditions.is_dominance_achieved(human, players))

func test_dominance_progress_fraction_of_others_eliminated():
	var human = PlayerData.new(CivilizationData.new())
	var rival_a = PlayerData.new(CivilizationData.new()) # sem unidade/cidade -- ja "eliminado"
	var rival_b = PlayerData.new(CivilizationData.new())
	_make_unit(rival_b) # ainda vivo
	var players: Array[PlayerData] = [human, rival_a, rival_b]
	assert_almost_eq(VictoryConditions.dominance_progress(human, players), 0.5, 0.001)

func test_dominance_progress_is_zero_with_no_other_players():
	var human = PlayerData.new(CivilizationData.new())
	var players: Array[PlayerData] = [human]
	assert_eq(VictoryConditions.dominance_progress(human, players), 0.0)

## --- Dominio Territorial ---------------------------------------------------

func test_total_habitable_tiles_excludes_water_and_lava():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(1, 0): HexTileData.TerrainType.HILLS,
		Vector2i(2, 0): HexTileData.TerrainType.OCEAN,
		Vector2i(3, 0): HexTileData.TerrainType.LAVA,
		Vector2i(4, 0): HexTileData.TerrainType.COAST,
	})
	assert_eq(VictoryConditions.total_habitable_tiles(grid), 2)

func test_total_habitable_tiles_counts_special_continent_terrain_as_habitable():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.VOLCANIC_ASH,
		Vector2i(1, 0): HexTileData.TerrainType.MYSTIC_SOIL,
		Vector2i(2, 0): HexTileData.TerrainType.MOUNTAINS,
	})
	assert_eq(VictoryConditions.total_habitable_tiles(grid), 3, "vulcanico/cristalino/montanha contam como habitavel, mesma definicao de blocks_land_units()")

func test_player_habitable_tiles_dedupes_city_coord_and_owned_tiles():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(1, 0): HexTileData.TerrainType.GRASSLAND,
	})
	var player = PlayerData.new(CivilizationData.new())
	var owned: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)] # inclui o proprio coord de proposito -- testa o dedupe
	player.cities.append(_make_city(Vector2i(0, 0), owned))
	assert_eq(VictoryConditions.player_habitable_tiles(player, grid), 2)

func test_player_habitable_tiles_excludes_water_even_if_somehow_owned():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(1, 0): HexTileData.TerrainType.COAST,
	})
	var player = PlayerData.new(CivilizationData.new())
	var owned: Array[Vector2i] = [Vector2i(1, 0)]
	player.cities.append(_make_city(Vector2i(0, 0), owned))
	assert_eq(VictoryConditions.player_habitable_tiles(player, grid), 1, "Costa nunca conta pro territorio habitavel, mesmo se possuida")

func test_territorial_percentage_ratio():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(1, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(2, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(3, 0): HexTileData.TerrainType.GRASSLAND,
	})
	var player = PlayerData.new(CivilizationData.new())
	var owned: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	player.cities.append(_make_city(Vector2i(0, 0), owned))
	assert_almost_eq(VictoryConditions.territorial_percentage(player, grid), 0.5, 0.001)

func test_territorial_percentage_is_zero_when_map_has_no_habitable_tile():
	var grid := _make_grid_with_tiles({Vector2i(0, 0): HexTileData.TerrainType.OCEAN})
	var player = PlayerData.new(CivilizationData.new())
	assert_eq(VictoryConditions.territorial_percentage(player, grid), 0.0)

func test_territorial_threshold_met_and_progress_clamped():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(1, 0): HexTileData.TerrainType.GRASSLAND,
	})
	var player = PlayerData.new(CivilizationData.new())
	var owned: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)] # 100% do mapa
	player.cities.append(_make_city(Vector2i(0, 0), owned))
	assert_true(VictoryConditions.is_territorial_threshold_met(player, grid))
	assert_eq(VictoryConditions.territorial_progress(player, grid), 1.0, "progresso nunca passa de 1.0 mesmo com 100% > 50% de limiar")

func test_territorial_threshold_not_met_below_it():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(1, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(2, 0): HexTileData.TerrainType.GRASSLAND,
		Vector2i(3, 0): HexTileData.TerrainType.GRASSLAND,
	})
	var player = PlayerData.new(CivilizationData.new())
	var owned: Array[Vector2i] = [Vector2i(0, 0)] # 25% do mapa
	player.cities.append(_make_city(Vector2i(0, 0), owned))
	assert_false(VictoryConditions.is_territorial_threshold_met(player, grid))

func test_territorial_dominance_achieved_reads_streak_state():
	var player = PlayerData.new(CivilizationData.new())
	player.territorial_streak = VictoryConditions.TERRITORIAL_SUSTAIN_TURNS
	assert_true(VictoryConditions.is_territorial_dominance_achieved(player))

func test_territorial_dominance_not_achieved_below_sustain_turns():
	var player = PlayerData.new(CivilizationData.new())
	player.territorial_streak = VictoryConditions.TERRITORIAL_SUSTAIN_TURNS - 1
	assert_false(VictoryConditions.is_territorial_dominance_achieved(player))

## --- Ascensao Arcana --------------------------------------------------------

func test_arcane_schools_researched_counts_distinct_schools_once():
	var player = PlayerData.new(CivilizationData.new())
	player.researched_techs["canalizacao_base"] = true # Arcanismo
	player.researched_techs["invocacao_espiritos"] = true # Arcanismo TAMBEM -- nao deveria contar 2x
	player.researched_techs["alquimia_botanica"] = true # Alquimia
	assert_eq(VictoryConditions.arcane_schools_researched(player), 2)

func test_arcane_schools_researched_excludes_doutrina():
	var player = PlayerData.new(CivilizationData.new())
	player.researched_techs["navegacao"] = true # Doutrina
	assert_eq(VictoryConditions.arcane_schools_researched(player), 0, "Doutrina nao e uma das 7 escolas magicas, decisao explicita de F1")

func test_meets_arcane_ritual_prerequisites_false_with_schools_but_no_nodes():
	var grid := _make_grid_with_tiles({Vector2i(0, 0): HexTileData.TerrainType.GRASSLAND})
	var player = PlayerData.new(CivilizationData.new())
	for tech_id in ["canalizacao_base", "alquimia_botanica", "transmutacao_rocha", "geomancia"]:
		player.researched_techs[tech_id] = true
	assert_false(VictoryConditions.meets_arcane_ritual_prerequisites(player, grid), "4 escolas mas 0 nodulos -- nao deveria bastar")

func test_meets_arcane_ritual_prerequisites_true_with_both():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.HILLS,
		Vector2i(1, 0): HexTileData.TerrainType.HILLS,
		Vector2i(2, 0): HexTileData.TerrainType.HILLS,
	})
	for coord in grid.tiles.keys():
		grid.tiles[coord].resource = "mana_node"
	var player = PlayerData.new(CivilizationData.new())
	for tech_id in ["canalizacao_base", "alquimia_botanica", "transmutacao_rocha", "geomancia"]:
		player.researched_techs[tech_id] = true
	var owned: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	player.cities.append(_make_city(Vector2i(0, 0), owned))
	assert_true(VictoryConditions.meets_arcane_ritual_prerequisites(player, grid))

func test_has_arcane_sanctuary_true_when_any_city_has_it():
	var player = PlayerData.new(CivilizationData.new())
	var city = _make_city(Vector2i(0, 0))
	city.buildings[VictoryConditions.SANCTUARY_BUILDING_ID] = true
	player.cities.append(city)
	assert_true(VictoryConditions.has_arcane_sanctuary(player))

func test_has_arcane_sanctuary_false_without_it():
	var player = PlayerData.new(CivilizationData.new())
	player.cities.append(_make_city(Vector2i(0, 0)))
	assert_false(VictoryConditions.has_arcane_sanctuary(player))

## Fecha o desacoplamento: SANCTUARY_BUILDING_ID agora aponta pra um predio
## de verdade registrado em BuildingDatabase (Roadmap Fase F, "Santuario do
## Nodulo") -- antes deste registro has_arcane_sanctuary() SEMPRE retornava
## false pra qualquer cidade real, ja que nenhuma cidade jamais teria esse
## building_id em City.buildings.
func test_sanctuary_building_id_resolves_to_a_real_building():
	var sanctuary = BuildingDatabase.get_building(VictoryConditions.SANCTUARY_BUILDING_ID)
	assert_not_null(sanctuary, "VictoryConditions.SANCTUARY_BUILDING_ID deveria apontar pra um predio real de BuildingDatabase")

func test_arcane_progress_averages_four_fractions():
	var grid := _make_grid_with_tiles({Vector2i(0, 0): HexTileData.TerrainType.GRASSLAND})
	var player = PlayerData.new(CivilizationData.new())
	for tech_id in ["canalizacao_base", "alquimia_botanica", "transmutacao_rocha", "geomancia"]: # 4/4 escolas = 1.0
		player.researched_techs[tech_id] = true
	# 0 nodulos = 0.0, sem santuario = 0.0, sem sustentacao = 0.0 -> media 0.25
	assert_almost_eq(VictoryConditions.arcane_progress(player, grid), 0.25, 0.001)

func test_arcane_progress_can_be_high_without_sanctuary_built():
	var grid := _make_grid_with_tiles({
		Vector2i(0, 0): HexTileData.TerrainType.HILLS,
		Vector2i(1, 0): HexTileData.TerrainType.HILLS,
		Vector2i(2, 0): HexTileData.TerrainType.HILLS,
	})
	for coord in grid.tiles.keys():
		grid.tiles[coord].resource = "mana_node"
	var player = PlayerData.new(CivilizationData.new())
	for tech_id in ["canalizacao_base", "alquimia_botanica", "transmutacao_rocha", "geomancia"]:
		player.researched_techs[tech_id] = true
	var owned: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	player.cities.append(_make_city(Vector2i(0, 0), owned))
	# escolas=1.0, nodulos=1.0, santuario=0.0, sustentacao=0.0 -> media 0.5
	assert_almost_eq(VictoryConditions.arcane_progress(player, grid), 0.5, 0.001, "pronto pra ativar mas ainda sem Santuario nao deveria travar em 0%")

func test_arcane_ascension_achieved_requires_active_and_streak():
	var player = PlayerData.new(CivilizationData.new())
	player.arcane_ritual_active = true
	player.arcane_ritual_streak = VictoryConditions.ARCANE_SUSTAIN_TURNS
	assert_true(VictoryConditions.is_arcane_ascension_achieved(player))

func test_arcane_ascension_not_achieved_if_streak_met_but_not_active():
	var player = PlayerData.new(CivilizationData.new())
	player.arcane_ritual_active = false
	player.arcane_ritual_streak = VictoryConditions.ARCANE_SUSTAIN_TURNS
	assert_false(VictoryConditions.is_arcane_ascension_achieved(player), "streak sem ritual ativo nao deveria acontecer na pratica, mas a funcao precisa ser explicita mesmo assim")

func test_arcane_ascension_not_achieved_if_active_but_streak_too_low():
	var player = PlayerData.new(CivilizationData.new())
	player.arcane_ritual_active = true
	player.arcane_ritual_streak = VictoryConditions.ARCANE_SUSTAIN_TURNS - 1
	assert_false(VictoryConditions.is_arcane_ascension_achieved(player))

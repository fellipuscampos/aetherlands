extends GutTest

## Cobre a arvore de tecnologia: disponibilidade por pre-requisito,
## desbloqueio de unidade, bonus de rendimento por bioma
## (TechDatabase.yield_bonus_for aplicado em City.collect_yields), e o
## processamento de pesquisa por turno (GameManager._process_research —
## ciencia = populacao das cidades, so acumula com uma pesquisa escolhida).

var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]

func before_each():
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players

func after_each():
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players

func test_techs_without_prerequisites_are_available_from_start():
	var ids = TechDatabase.available_techs({}).map(func(t): return t.id)
	assert_true("agriculture" in ids)
	assert_true("mining" in ids)
	assert_true("archery" in ids)
	assert_true("animal_husbandry" in ids)
	assert_false("horseback_riding" in ids, "equitacao exige pecuaria pesquisada antes")
	assert_false("irrigation" in ids, "irrigacao exige agricultura pesquisada antes")

func test_tech_with_prerequisite_becomes_available_after_researching_it():
	var ids = TechDatabase.available_techs({"animal_husbandry": true}).map(func(t): return t.id)
	assert_true("horseback_riding" in ids)

func test_researched_tech_is_not_offered_again():
	var ids = TechDatabase.available_techs({"agriculture": true}).map(func(t): return t.id)
	assert_false("agriculture" in ids)

func test_is_unit_unlocked_settler_and_warrior_always_true():
	assert_true(TechDatabase.is_unit_unlocked("settler", {}))
	assert_true(TechDatabase.is_unit_unlocked("warrior", {}))

func test_is_unit_unlocked_archer_requires_archery():
	assert_false(TechDatabase.is_unit_unlocked("archer", {}))
	assert_true(TechDatabase.is_unit_unlocked("archer", {"archery": true}))

func test_is_unit_unlocked_cavalry_requires_horseback_riding():
	assert_false(TechDatabase.is_unit_unlocked("cavalry", {}))
	assert_true(TechDatabase.is_unit_unlocked("cavalry", {"horseback_riding": true}))

func test_is_unit_unlocked_catapult_requires_engineering():
	assert_false(TechDatabase.is_unit_unlocked("catapult", {}))
	assert_true(TechDatabase.is_unit_unlocked("catapult", {"engineering": true}))

func test_engineering_requires_metalworking_prerequisite():
	assert_false("engineering" in TechDatabase.available_techs({}).map(func(t): return t.id))
	assert_true("engineering" in TechDatabase.available_techs({"metalworking": true}).map(func(t): return t.id))

func test_is_unit_unlocked_mage_requires_arcane_studies():
	assert_false(TechDatabase.is_unit_unlocked("mage", {}))
	assert_true(TechDatabase.is_unit_unlocked("mage", {"arcane_studies": true}))

func test_is_unit_unlocked_griffin_requires_griffin_training():
	assert_false(TechDatabase.is_unit_unlocked("griffin", {}))
	assert_true(TechDatabase.is_unit_unlocked("griffin", {"griffin_training": true}))

func test_griffin_training_requires_horseback_riding_prerequisite():
	assert_false("griffin_training" in TechDatabase.available_techs({}).map(func(t): return t.id))
	assert_true("griffin_training" in TechDatabase.available_techs({"horseback_riding": true}).map(func(t): return t.id))

func test_is_unit_unlocked_treant_requires_druidism():
	assert_false(TechDatabase.is_unit_unlocked("treant", {}))
	assert_true(TechDatabase.is_unit_unlocked("treant", {"druidism": true}))

func test_druidism_has_no_prerequisite():
	assert_true("druidism" in TechDatabase.available_techs({}).map(func(t): return t.id))

func test_yield_bonus_for_sums_matching_researched_techs():
	var bonus = TechDatabase.yield_bonus_for(HexTileData.TerrainType.GRASSLAND, {"agriculture": true})
	assert_eq(bonus.food, 1)
	assert_eq(bonus.production, 0)

func test_yield_bonus_for_ignores_unrelated_terrain():
	var bonus = TechDatabase.yield_bonus_for(HexTileData.TerrainType.DESERT, {"agriculture": true})
	assert_eq(bonus.food, 0, "agricultura afeta planicie/estepe, nao deserto (isso e irrigacao)")

func test_player_data_has_unlocked_delegates_to_tech_database():
	var player = PlayerData.new(CivilizationData.new())
	assert_false(player.has_unlocked("archer"))
	player.researched_techs["archery"] = true
	assert_true(player.has_unlocked("archer"))

func test_city_collect_yields_applies_tech_bonus():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # comida 3

	var player := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = player
	city.coord = coord

	assert_eq(city.collect_yields(hex_grid).food, 3)

	player.researched_techs["agriculture"] = true # +1 comida em planicie/estepe
	assert_eq(city.collect_yields(hex_grid).food, 4)

	hex_grid.queue_free()
	city.queue_free()

func test_process_research_accumulates_progress_from_city_population():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city = hex_grid.found_city(coord, player, "Capital")
	city.population = 3
	player.current_research = "agriculture" # custo 20

	GameManager.human_player = player
	GameManager._process_research(player)

	assert_almost_eq(player.research_progress, 3.0, 0.01)
	assert_false(player.researched_techs.has("agriculture"))

	hex_grid.queue_free()

func test_process_research_completes_tech_when_cost_is_reached():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city = hex_grid.found_city(coord, player, "Capital")
	city.population = 25 # bem mais que o custo (20) num turno so
	player.current_research = "agriculture"

	GameManager.human_player = player
	GameManager._process_research(player)

	assert_true(player.researched_techs.has("agriculture"))
	assert_eq(player.current_research, "")
	assert_almost_eq(player.research_progress, 0.0, 0.01)

	hex_grid.queue_free()

func test_process_research_does_nothing_without_a_selected_tech():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city = hex_grid.found_city(coord, player, "Capital")
	city.population = 5

	GameManager._process_research(player)

	assert_almost_eq(player.research_progress, 0.0, 0.01, "sem pesquisa selecionada, ciencia gerada e descartada")

	hex_grid.queue_free()

func test_decide_research_picks_an_available_tech_when_idle():
	var player := PlayerData.new(CivilizationData.new())
	RivalAI.decide_research(player)
	assert_ne(player.current_research, "", "IA deveria escolher alguma pesquisa quando esta ociosa")

func test_decide_research_does_not_override_existing_choice():
	var player := PlayerData.new(CivilizationData.new())
	player.current_research = "mining"
	RivalAI.decide_research(player)
	assert_eq(player.current_research, "mining")

## Regressao: antes da arvore de tecnologia, a IA sorteava Arqueiro/
## Cavaleiro desde o primeiro turno. Agora so pode produzir o que ja
## desbloqueou.
func test_decide_production_never_picks_locked_units_before_researching():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city_a = hex_grid.found_city(Vector2i(0, 0), player, "Cidade A")
	hex_grid.found_city(Vector2i(5, 0), player, "Cidade B") # 2 cidades: sai do ramo "sempre colonizador"

	for i in range(20): # varias rodadas pra reduzir chance de falso-positivo por sorte
		RivalAI.decide_production(player)
		assert_eq(city_a.production_item, "warrior", "sem Tiro com Arco/Equitacao pesquisados, so guerreiro deveria sair do sorteio")

	hex_grid.queue_free()

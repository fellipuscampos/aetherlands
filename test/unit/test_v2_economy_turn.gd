extends GutTest

## Aetherlands V2, Fase 14 — processamento de turno, não-duplicação com a V1 (Produção/Ouro/Mana),
## separação Conhecimento×Ciência e Suprimentos×Comida, overflow de Conhecimento sem pesquisa
## ativa, reset de debug e save antigo (§103-109, §111-112 do pedido). Prédios/yields ficam em
## test_v2_economy_buildings.gd; o fluxo principal ponta a ponta fica em test_v2_economy_flow.gd.

var _owned_players: Array[PlayerData] = []
var _cities: Array[City] = []
var _grids: Array[HexGrid] = []

func after_each():
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

func _grid(radius: int = 6) -> HexGrid:
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

func _research(player: PlayerData, unlock_id: String) -> void:
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	assert_not_null(node, unlock_id)
	assert_true(player.v2_research.complete_research(node.id), unlock_id)

func _free_neighbor(city: City, grid: HexGrid) -> Vector2i:
	for n in grid.get_neighbors(city.coord):
		if city.is_valid_building_tile(n, grid):
			return n
	return Vector2i(999998, 999998)

func _build_copy(city: City, grid: HexGrid, building_id: String) -> void:
	var target := _free_neighbor(city, grid)
	city.set_production(building_id)
	city.pending_building_coord = target
	city.stored_production = city.production_cost()
	var result := city.process_turn(grid)
	if result.built_coord != City.NO_PENDING_COORD:
		grid.place_building(result.built_coord, result.built_kind, city.owner_player)

# --- §105: Produção V1 não duplica ----------------------------------------------------------------

func test_v1_high_yield_terrain_and_population_never_leak_into_active_production():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	# Fixture: terreno com metadado de Produção/Ouro ABSURDAMENTE alto -- mas NENHUMA Oficina construída.
	# Fase 25: o metadado de terreno não é lido por nenhuma economia (não há mais tiles trabalhados).
	for n in grid.get_neighbors(city.coord):
		var data: HexTileData = grid.get_tile(n)
		data.production_yield = 500
		data.gold_yield = 500
	var start := city.stored_production
	city.process_turn(grid)
	assert_almost_eq(city.stored_production - start, V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY, 0.01, "produção ativa V2 continua exatamente a base, nunca 4 + workers")

# --- §106: Ouro/Mana V1 não duplicam --------------------------------------------------------------

func test_v1_high_yield_terrain_never_leaks_into_active_gold_or_mana():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	for n in grid.get_neighbors(city.coord):
		var data: HexTileData = grid.get_tile(n)
		data.gold_yield = 500
	var gold_before := player.gold
	var mana_before := player.mana
	city.process_turn(grid) # não credita mais ouro/mana ao jogador (ver GameManager/City.gd)
	assert_almost_eq(player.gold, gold_before, 0.01, "city.process_turn() não credita mais ouro")
	assert_almost_eq(player.mana, mana_before, 0.01)
	V2EconomyRuntime.apply_turn_income(player)
	assert_almost_eq(player.gold - gold_before, V2InfrastructureEconomyData.BASE_GOLD_PER_CITY, 0.01, "só a renda V2 (base, sem Mercado) é creditada")

# --- §107: Conhecimento V2 != Ciência V1 -----------------------------------------------------------

# --- §108: Suprimentos != Comida -------------------------------------------------------------------

func test_food_and_population_changes_never_move_supply_capacity():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	var before := V2EconomyRuntime.city_supply_capacity(city)
	city.process_turn(grid)
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), before, "Suprimentos só mudam por Fazenda/base/Cavalos")
	_research(player, "v2_building_farm")
	_build_copy(city, grid, "v2_building_farm")
	assert_gt(V2EconomyRuntime.city_supply_capacity(city), before, "só a Fazenda muda a capacidade")

# --- §109: Conhecimento acumula em overflow sem pesquisa ativa --------------------------------------

func test_knowledge_accumulates_as_overflow_across_several_turns_without_an_active_project():
	var player := _player()
	var grid := _grid()
	_founded_city(player, grid)
	assert_false("current_research" in player, "Fase 25: estado V1 removido")
	assert_eq(player.v2_research.active_id, "")
	var per_turn := V2EconomyRuntime.player_knowledge_income(player)
	for i in 5:
		V2EconomyRuntime.apply_turn_income(player)
	assert_almost_eq(player.v2_research.research_overflow, per_turn * 5.0, 0.01)
	player.v2_research.select_research("v2_infrastructure_economy_1")
	assert_true(player.v2_research.get_progress("v2_infrastructure_economy_1") > 0.0, "overflow aplicado pela API existente ao selecionar")

# --- §111: reset de debug ----------------------------------------------------------------------------

func test_debug_reset_keeps_buildings_reverts_yield_to_tier_one_and_blocks_new_copies():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_market")
	_research(player, "v2_market_efficiency_2")
	_build_copy(city, grid, "v2_building_market")
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 6.0)
	player.v2_research.reset()
	assert_eq(city.building_count("v2_building_market"), 1, "o Mercado não é destruído")
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 4.0, "yield volta pro tier 1")
	assert_false(city.can_build("v2_building_market"), "sem pesquisa, nenhuma cópia nova")

# --- §112: uma cidade sem NENHUM prédio econômico novo (equivalente ao que um save antigo carrega,
# já que repeatable_building_coords/repeatable_building_counts vêm vazios por padrão) continua
# rendendo a base inteira -- o round trip REAL via SaveManager.save_game/load_game (arquivo antigo
# de antes da Fase 14) fica em test_v2_economy_flow.gd, junto do resto do save/load desta fase. ---

func test_a_city_with_no_v2_economy_buildings_still_yields_the_full_base():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	assert_true(city.repeatable_building_counts.is_empty())
	assert_true(city.repeatable_building_coords.is_empty())
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY)
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY)
	assert_eq(V2EconomyRuntime.city_production_income(city), V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY)
	assert_eq(V2EconomyRuntime.city_knowledge_income(city), V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY)
	assert_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY)

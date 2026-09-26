extends GutTest

## Aetherlands V2, Fase 14 — os cinco prédios econômicos (Mercado/Fazenda/Oficina/Academia/
## Santuário Arcano): construção real (gate de pesquisa, CopyLimitMode.CITY_LEVEL, cap por City
## Level, slots), yield real por tier, prédio capturado sem a pesquisa do novo dono (§93-102 do
## pedido). Turno/agregação global ficam em test_v2_economy_turn.gd.

const MARKET := "v2_building_market"
const FARM := "v2_building_farm"
const WORKSHOP := "v2_building_workshop"
const ACADEMY := "v2_building_academy"
const SHRINE := "v2_building_arcane_shrine"

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

func _free_neighbor(city: City, grid: HexGrid) -> Vector2i:
	for n in grid.get_neighbors(city.coord):
		if city.is_valid_building_tile(n, grid):
			return n
	for n in city.owned_tiles:
		if city.is_valid_building_tile(n, grid):
			return n
	return Vector2i(999998, 999998)

## Constrói UMA cópia de `building_id` num tile REAL do mapa (não fixture, §98 do pedido) — mesma
## sequência real do jogo: escolhe production_item, reserva um tile livre, completa a produção
## (process_turn) e coloca o modelo físico (hex_grid.place_building, papel normalmente do
## GameManager depois de ler o resultado).
func _build_copy(city: City, grid: HexGrid, building_id: String) -> Vector2i:
	var target := _free_neighbor(city, grid)
	city.set_production(building_id)
	city.pending_building_coord = target
	city.stored_production = city.production_cost()
	var result := city.process_turn(grid)
	if result.built_coord != City.NO_PENDING_COORD:
		grid.place_building(result.built_coord, result.built_kind, city.owner_player)
	return target

func _research(player: PlayerData, unlock_id: String) -> void:
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	assert_not_null(node, unlock_id)
	player.v2_research.complete_research(node.id)

# --- Dados dos 5 prédios --------------------------------------------------------------------------

func test_all_five_buildings_exist_with_city_level_copy_limit():
	for id in [MARKET, FARM, WORKSHOP, ACADEMY, SHRINE]:
		var b: BuildingData = BuildingDatabase.get_building(id)
		assert_not_null(b, id)
		assert_eq(b.copy_limit_mode, BuildingData.CopyLimitMode.CITY_LEVEL, id)
		assert_eq(b.requires_building, "", "%s: infraestrutura básica independente (§59)" % id)
		# Aetherlands V2, Fase 15 — a Oficina passou a treinar o Construtor (§53 do pedido); as
		# outras quatro continuam sem treinar tropa nenhuma.
		var expected_trains_unit := "v2_unit_builder" if id == WORKSHOP else ""
		assert_eq(b.trains_unit, expected_trains_unit, "%s: unidade treinada" % id)
		assert_true(ResourceLoader.exists(b.model_scene_path), id)

func test_building_costs_match_the_documented_baseline():
	assert_almost_eq(BuildingDatabase.get_building(MARKET).production_cost, 20.0, 0.01)
	assert_almost_eq(BuildingDatabase.get_building(FARM).production_cost, 20.0, 0.01)
	assert_almost_eq(BuildingDatabase.get_building(WORKSHOP).production_cost, 24.0, 0.01)
	assert_almost_eq(BuildingDatabase.get_building(ACADEMY).production_cost, 24.0, 0.01)
	assert_almost_eq(BuildingDatabase.get_building(SHRINE).production_cost, 24.0, 0.01)

# --- §93: Mercado ----------------------------------------------------------------------------------

func test_market_cannot_be_built_without_research():
	var city := _founded_city(_player(), _grid())
	assert_false(city.can_build(MARKET))

func test_market_can_be_built_once_n1_is_researched():
	var player := _player()
	var city := _founded_city(player, _grid())
	_research(player, "v2_building_market")
	assert_true(city.can_build(MARKET))

func test_market_yields_four_gold_at_tier_one():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_market")
	_build_copy(city, grid, MARKET)
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 4.0)

func test_market_yields_scale_with_tier_two_and_three():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_market")
	_build_copy(city, grid, MARKET)
	_research(player, "v2_market_efficiency_2")
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 6.0)
	_research(player, "v2_market_efficiency_3")
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 8.0)

# --- §94: Fazenda ------------------------------------------------------------------------------------

func test_farm_provides_supply_capacity_not_stock():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_farm")
	_build_copy(city, grid, FARM)
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 4.0)

func test_farm_yields_scale_with_tier():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_farm")
	_build_copy(city, grid, FARM)
	_research(player, "v2_farm_efficiency_2")
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 6.0)
	_research(player, "v2_farm_efficiency_3")
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 8.0)

func test_two_cities_base_supply_is_additive_without_any_farm():
	var player := _player()
	var grid := _grid(10)
	_founded_city(player, grid, Vector2i(0, 0))
	_founded_city(player, grid, Vector2i(6, 0))
	assert_eq(V2EconomyRuntime.player_supply_capacity(player), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY * 2.0)

func test_farm_capacity_recalculates_immediately_no_synced_state():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY)
	_research(player, "v2_building_farm")
	_build_copy(city, grid, FARM)
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 4.0, "muda na consulta seguinte, sem hook de turno")

# --- §95: Oficina (Produção LOCAL) -----------------------------------------------------------------

func test_workshop_adds_local_production_only_to_its_own_city():
	var player := _player()
	var grid := _grid(10)
	var city_a := _founded_city(player, grid, Vector2i(0, 0))
	var city_b := _founded_city(player, grid, Vector2i(6, 0))
	_research(player, "v2_building_workshop")
	_build_copy(city_a, grid, WORKSHOP)
	assert_eq(V2EconomyRuntime.city_production_income(city_a), V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY + 2.0)
	assert_eq(V2EconomyRuntime.city_production_income(city_b), V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY, "a Oficina de A não ajuda B")

func test_workshop_tiers_increase_local_production():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_workshop")
	_build_copy(city, grid, WORKSHOP)
	_research(player, "v2_workshop_efficiency_2")
	assert_eq(V2EconomyRuntime.city_production_income(city), V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY + 3.0)
	_research(player, "v2_workshop_efficiency_3")
	assert_eq(V2EconomyRuntime.city_production_income(city), V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY + 4.0)

func test_workshop_completed_this_turn_only_counts_from_next_turn():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_workshop")
	var target := _free_neighbor(city, grid)
	city.set_production(WORKSHOP)
	city.pending_building_coord = target
	var cost := city.production_cost()
	# Falta só 0.01 pra completar -- a base (4.0) deste turno sozinha já cobre; se a Oficina
	# contasse NO MESMO turno em que termina, isso provaria pouca coisa (completaria de qualquer
	# jeito). O que este teste garante é o oposto: mesmo faltando pouquíssimo, o snapshot usado
	# pra completar é o de ANTES da Oficina existir (§52/§104 do pedido) -- conferido abaixo pelo
	# turno SEGUINTE, que precisa refletir a diferença exata (+2 Produção local).
	city.stored_production = cost - 0.01
	var result := city.process_turn(grid)
	assert_eq(result.built_kind, WORKSHOP, "completou neste turno")
	grid.place_building(result.built_coord, result.built_kind, player)
	city.set_production("warrior")
	var start := city.stored_production
	city.process_turn(grid)
	assert_almost_eq(city.stored_production - start, V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY + 2.0, 0.01, "só no turno seguinte a Oficina conta")

func test_city_project_and_units_and_buildings_all_receive_workshop_production():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_workshop")
	_build_copy(city, grid, WORKSHOP)
	city.set_production("warrior")
	var start := city.stored_production
	city.process_turn(grid)
	assert_gt(city.stored_production - start, V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY, "unidade recebe a Produção normal da cidade")

# --- §96: Academia -----------------------------------------------------------------------------------

func test_academy_base_knowledge_per_city_without_any_academy():
	var player := _player()
	var grid := _grid(10)
	_founded_city(player, grid, Vector2i(0, 0))
	_founded_city(player, grid, Vector2i(6, 0))
	assert_eq(V2EconomyRuntime.player_knowledge_income(player), V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY * 2.0)

func test_academy_adds_knowledge_and_tiers_scale():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_academy")
	_build_copy(city, grid, ACADEMY)
	assert_eq(V2EconomyRuntime.city_knowledge_income(city), V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY + 3.0)
	_research(player, "v2_academy_efficiency_2")
	assert_eq(V2EconomyRuntime.city_knowledge_income(city), V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY + 4.0)
	_research(player, "v2_academy_efficiency_3")
	assert_eq(V2EconomyRuntime.city_knowledge_income(city), V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY + 5.0)

func test_apply_turn_income_feeds_add_knowledge_with_an_active_project():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_academy")
	_build_copy(city, grid, ACADEMY)
	player.v2_research.select_research("v2_infrastructure_logistics_1")
	var before := player.v2_research.get_progress("v2_infrastructure_logistics_1")
	V2EconomyRuntime.apply_turn_income(player)
	var after := player.v2_research.get_progress("v2_infrastructure_logistics_1")
	assert_almost_eq(after - before, V2EconomyRuntime.player_knowledge_income(player), 0.01)

func test_apply_turn_income_overflows_without_an_active_project():
	var player := _player()
	var grid := _grid()
	_founded_city(player, grid)
	assert_eq(player.v2_research.research_overflow, 0.0)
	V2EconomyRuntime.apply_turn_income(player)
	assert_almost_eq(player.v2_research.research_overflow, V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY, 0.01, "nada é descartado sem projeto ativo")

func test_academy_knowledge_isolated_between_civilizations():
	var grid := _grid(10)
	var a := _player()
	var b := _player()
	var city_a := _founded_city(a, grid, Vector2i(0, 0))
	_founded_city(b, grid, Vector2i(6, 0))
	_research(a, "v2_building_academy")
	_build_copy(city_a, grid, ACADEMY)
	assert_gt(V2EconomyRuntime.player_knowledge_income(a), V2EconomyRuntime.player_knowledge_income(b))

# --- §97: Santuário Arcano --------------------------------------------------------------------------

func test_arcane_shrine_base_mana_and_tiers():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	assert_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY)
	_research(player, "v2_building_arcane_shrine")
	_build_copy(city, grid, SHRINE)
	assert_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY + 2.0)
	_research(player, "v2_arcane_shrine_efficiency_2")
	assert_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY + 3.0)
	_research(player, "v2_arcane_shrine_efficiency_3")
	assert_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY + 4.0)

func test_arcane_shrine_reuses_the_existing_mana_pool():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_arcane_shrine")
	_build_copy(city, grid, SHRINE)
	var before := player.mana
	V2EconomyRuntime.apply_turn_income(player)
	assert_almost_eq(player.mana - before, V2EconomyRuntime.player_mana_income(player), 0.01)

func test_multiple_shrines_stack():
	var player := _player()
	var grid := _grid()
	player.gold = 1000.0
	var city := _founded_city(player, grid)
	city.city_level = 3
	_research(player, "v2_building_arcane_shrine")
	_build_copy(city, grid, SHRINE)
	_build_copy(city, grid, SHRINE)
	assert_eq(city.building_count(SHRINE), 2)
	assert_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY + 4.0)

# --- §98: prédio repetível REAL no mapa (não fixture) ------------------------------------------------

func test_two_real_copies_of_the_same_building_at_city_level_two():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.city_level = 2
	_research(player, "v2_building_market")
	var coord1 := _build_copy(city, grid, MARKET)
	var coord2 := _build_copy(city, grid, MARKET)
	assert_ne(coord1, coord2, "cada cópia precisa do seu próprio tile")
	assert_not_null(grid.get_building_at(coord1), "modelo físico #1")
	assert_not_null(grid.get_building_at(coord2), "modelo físico #2")
	assert_eq(city.building_count(MARKET), 2)
	assert_true(city.buildings.has(MARKET), "buildings ainda representa 'existe pelo menos uma'")
	assert_eq(city.repeatable_building_counts.get(MARKET, 0), 2)
	assert_eq(city.used_building_slots(), 2)
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 8.0, "2 cópias x 4 Ouro")

# --- §99: cap de cópias -----------------------------------------------------------------------------

func test_the_nth_plus_one_copy_is_blocked_at_the_current_city_level_cap():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.city_level = 2 # cap repetível = 2, slots = 7 (não é o gargalo aqui)
	_research(player, "v2_building_academy")
	_build_copy(city, grid, ACADEMY)
	_build_copy(city, grid, ACADEMY)
	assert_eq(city.building_count(ACADEMY), 2)
	assert_false(city.can_build(ACADEMY), "cap de cópias do nível (2) atingido, mesmo com slots sobrando")

# --- §100: cap de slots -----------------------------------------------------------------------------

func test_city_level_one_fills_all_four_slots_with_one_of_each():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_market")
	_research(player, "v2_building_farm")
	_research(player, "v2_building_workshop")
	_research(player, "v2_building_academy")
	_research(player, "v2_building_arcane_shrine")
	_build_copy(city, grid, MARKET)
	_build_copy(city, grid, FARM)
	_build_copy(city, grid, WORKSHOP)
	_build_copy(city, grid, ACADEMY)
	assert_eq(city.used_building_slots(), 4)
	assert_eq(city.used_building_slots(), city.max_building_slots())
	assert_false(city.can_build(SHRINE), "sem slot -- cap de cópias (1) não é o motivo aqui")
	city.city_level = 2
	assert_true(city.can_build(SHRINE), "Cidade II libera o 5º slot")

# --- §101: N2/N3 não criam prédio novo ---------------------------------------------------------------

func test_n2_and_n3_never_change_the_copy_count_only_the_yield():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	_research(player, "v2_building_market")
	_build_copy(city, grid, MARKET)
	var count_before := city.building_count(MARKET)
	var yield_before := V2EconomyRuntime.city_gold_income(city)
	_research(player, "v2_market_efficiency_2")
	assert_eq(city.building_count(MARKET), count_before, "número de Mercados não muda")
	assert_gt(V2EconomyRuntime.city_gold_income(city), yield_before, "yield muda imediatamente")
	_research(player, "v2_market_efficiency_3")
	assert_eq(city.building_count(MARKET), count_before)

func test_the_five_lines_never_create_a_new_building_object_on_n2_n3():
	for branch_unlock in [["v2_market_efficiency_2", "v2_market_efficiency_3"], ["v2_farm_efficiency_2", "v2_farm_efficiency_3"], ["v2_workshop_efficiency_2", "v2_workshop_efficiency_3"], ["v2_academy_efficiency_2", "v2_academy_efficiency_3"], ["v2_arcane_shrine_efficiency_2", "v2_arcane_shrine_efficiency_3"]]:
		for unlock_id in branch_unlock:
			var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
			assert_eq(node.unlock_type, "infrastructure_upgrade", unlock_id)

# --- §102: prédio capturado sem a pesquisa do novo dono -----------------------------------------------

func test_captured_building_still_produces_at_tier_one_without_the_new_owners_research():
	var grid := _grid(10)
	var conqueror := _player()
	var original_owner := _player()
	original_owner.gold = 1000.0
	var city := _founded_city(original_owner, grid, Vector2i(0, 0))
	_research(original_owner, "v2_building_market")
	_research(original_owner, "v2_market_efficiency_2")
	_research(original_owner, "v2_market_efficiency_3")
	_build_copy(city, grid, MARKET)
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 8.0, "dono original com N3: yield máximo")
	grid.capture_city(city, conqueror)
	assert_false(conqueror.has_unlocked("v2_building_market"), "o novo dono não pesquisou nada de Infraestrutura")
	assert_true(city.building_count(MARKET) > 0, "o Mercado continua existindo fisicamente")
	assert_false(city.can_build(MARKET), "sem N1, o NOVO dono não constrói outro")
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 4.0, "yield cai pro tier 1 -- eficiência do NOVO dono, nunca do antigo")

func test_new_owner_researching_n2_upgrades_the_captured_building_without_rebuilding():
	var grid := _grid(10)
	var conqueror := _player()
	var original_owner := _player()
	var city := _founded_city(original_owner, grid, Vector2i(0, 0))
	_research(original_owner, "v2_building_market")
	_build_copy(city, grid, MARKET)
	grid.capture_city(city, conqueror)
	var count_before := city.building_count(MARKET)
	_research(conqueror, "v2_building_market")
	_research(conqueror, "v2_market_efficiency_2")
	assert_eq(city.building_count(MARKET), count_before, "nenhuma reconstrução")
	assert_eq(V2EconomyRuntime.city_gold_income(city), V2InfrastructureEconomyData.BASE_GOLD_PER_CITY + 6.0)

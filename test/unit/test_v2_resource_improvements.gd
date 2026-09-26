extends GutTest

## Aetherlands V2, Fase 15 — os cinco recursos do mapa (V2ResourceImprovementData): efeitos
## corretos por recurso, tier que segue o DONO ATUAL (nunca quem construiu, sempre pelo menos 1 —
## mesma regra dos prédios capturados da Fase 14), armazenamento por CIDADE (nunca global, nunca
## conta como prédio/slot), captura "de graça" e save/load (só id + coord).

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _original_human: PlayerData
var _original_grid: HexGrid
var _original_players: Array[PlayerData]
var _original_rivals: Array[PlayerData]

func before_each():
	_original_human = GameManager.human_player
	_original_grid = GameManager.hex_grid
	_original_players = GameManager.players
	_original_rivals = GameManager.rival_players

func after_each():
	GameManager.human_player = _original_human
	GameManager.hex_grid = _original_grid
	GameManager.players = _original_players
	GameManager.rival_players = _original_rivals
	for player in _players:
		player.release_relations()
	_players.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()

func _grid_with_city() -> Dictionary:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-3, 4):
		for r in range(-3, 4):
			if absi(q + r) <= 3:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	_grids.append(grid)
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	return {"grid": grid, "player": player, "city": city}

# --- Catálogo central --------------------------------------------------------------------------

func test_all_five_resources_are_registered_with_the_canonical_ids():
	var expected := {
		"iron": "v2_improvement_iron_mine",
		"horses": "v2_improvement_horse_ranch",
		"gems": "v2_improvement_gem_mine",
		"silk": "v2_improvement_silk_post",
		"mana_node": "v2_improvement_arcane_conduit",
	}
	for resource_id in expected:
		assert_true(V2ResourceImprovementData.has_resource(resource_id), resource_id)
		assert_eq(V2ResourceImprovementData.improvement_id_for_resource(resource_id), expected[resource_id])
		assert_eq(V2ResourceImprovementData.resource_for_improvement(expected[resource_id]), resource_id, "round-trip inverso")

# --- Efeitos por recurso, escalando com o tier ---------------------------------------------------

func test_iron_gives_local_production_scaled_by_industry_tier():
	var s := _grid_with_city()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_iron_mine"
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "production").improvement_total, 2.0, 0.0001, "tier 1 (sem pesquisa)")
	_research_tier(s.player, "industry", 2)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "production").improvement_total, 3.0, 0.0001, "tier 2")
	_research_tier(s.player, "industry", 3)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "production").improvement_total, 4.0, 0.0001, "tier 3")

func test_horses_give_supply_capacity_scaled_by_logistics_tier():
	var s := _grid_with_city()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_horse_ranch"
	assert_almost_eq(V2EconomyRuntime.city_supply_capacity(s.city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 4.0, 0.0001, "tier 1")
	_research_tier(s.player, "logistics", 2)
	assert_almost_eq(V2EconomyRuntime.city_supply_capacity(s.city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 6.0, 0.0001, "tier 2")
	_research_tier(s.player, "logistics", 3)
	assert_almost_eq(V2EconomyRuntime.city_supply_capacity(s.city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 8.0, 0.0001, "tier 3")

func test_gems_give_gold_scaled_by_economy_tier():
	var s := _grid_with_city()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_gem_mine"
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "gold").improvement_total, 4.0, 0.0001, "tier 1")
	_research_tier(s.player, "economy", 2)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "gold").improvement_total, 6.0, 0.0001, "tier 2")

func test_silk_gives_both_gold_and_knowledge():
	var s := _grid_with_city()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_silk_post"
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "gold").improvement_total, 2.0, 0.0001, "Ouro tier 1 (Economia)")
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "knowledge").improvement_total, 1.0, 0.0001, "Conhecimento tier 1 (Academia)")
	_research_tier(s.player, "economy", 2)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "gold").improvement_total, 3.0, 0.0001, "Ouro sobe com Economia...")
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "knowledge").improvement_total, 1.0, 0.0001, "...mas Conhecimento não muda, tiers independentes")

func test_arcane_conduit_gives_mana_scaled_by_arcane_tier():
	var s := _grid_with_city()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_arcane_conduit"
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "mana").improvement_total, 2.0, 0.0001, "tier 1")
	_research_tier(s.player, "arcane", 2)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "mana").improvement_total, 3.0, 0.0001, "tier 2")

# --- Tier segue o DONO ATUAL, nunca quem construiu, nunca 0 -----------------------------------------

func test_tier_never_floors_below_one_even_without_any_research():
	var s := _grid_with_city()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_gem_mine"
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "gold").improvement_total, 4.0, 0.0001, "tier 1, nunca 0")

func test_tier_follows_the_new_owner_after_capture_not_the_builder():
	var s := _grid_with_city()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_gem_mine"
	var conqueror := PlayerData.new(CivilizationData.new())
	_players.append(conqueror)
	_research_tier(conqueror, "economy", 2)
	s.city.change_owner(conqueror)
	s.player.cities.erase(s.city)
	conqueror.cities.append(s.city)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "gold").improvement_total, 6.0, 0.0001, "tier 2 do NOVO dono, mesmo sem ele ter construído nada")

# --- Local vs global -----------------------------------------------------------------------------

func test_iron_only_benefits_the_owning_city_not_other_cities_of_the_same_player():
	var s := _grid_with_city()
	var second: City = s.grid.found_city(Vector2i(3, 0), s.player, "Segunda", true)
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_iron_mine"
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "production").improvement_total, 2.0, 0.0001)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(second, "production").improvement_total, 0.0, 0.0001, "melhoria é LOCAL -- não vaza pra outra cidade")

func test_horses_is_aggregated_globally_across_all_cities_of_the_player():
	var s := _grid_with_city()
	var second: City = s.grid.found_city(Vector2i(3, 0), s.player, "Segunda", true)
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_horse_ranch"
	second.resource_improvements[Vector2i(4, 0)] = "v2_improvement_horse_ranch"
	var expected := 2.0 * (V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 4.0)
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(s.player), expected, 0.0001)

# --- Armazenamento: por cidade, nunca prédio/slot -------------------------------------------------

func test_improvements_never_occupy_a_building_slot_or_enter_the_buildings_dict():
	var s := _grid_with_city()
	var before_slots: int = s.city.used_building_slots()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_iron_mine"
	assert_eq(s.city.used_building_slots(), before_slots, "melhoria não ocupa slot")
	assert_false(s.city.buildings.has("v2_improvement_iron_mine"))

func test_at_most_one_improvement_per_tile_ever():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("v2_unit_builder"), s.player)
	unit.work_charges_remaining = 3
	unit.movement_left = unit.unit_data.movement_points
	assert_true(V2ConstructorRuntime.improve_resource(unit, s.grid))
	assert_eq(s.city.resource_improvements.size(), 1)
	# Um SEGUNDO Construtor, mesmo com cargas de sobra, não pode melhorar o mesmo tile de novo (a
	# primeira unidade sai do caminho pra isolar exatamente essa checagem, não "dois na mesma cidade").
	s.grid.remove_unit(unit)
	var second_unit: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("v2_unit_builder"), s.player)
	second_unit.work_charges_remaining = 3
	second_unit.movement_left = second_unit.unit_data.movement_points
	assert_eq(V2ConstructorRuntime.unavailable_reason(second_unit, s.grid), "Este recurso já está sendo explorado.")

func _resource_tile(s: Dictionary, coord: Vector2i, resource_id: String) -> void:
	var tile := TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = resource_id
	s.grid.tiles[coord] = tile

# --- Captura transfere de graça, save/load só guarda id + coord ------------------------------------

func test_capturing_the_city_transfers_the_improvement_for_free():
	var s := _grid_with_city()
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_gem_mine"
	var conqueror := PlayerData.new(CivilizationData.new())
	_players.append(conqueror)
	s.city.change_owner(conqueror)
	assert_true(s.city.resource_improvements.has(Vector2i(1, 0)), "a melhoria sobrevive à captura junto com a cidade")
	assert_eq(s.city.resource_improvements[Vector2i(1, 0)], "v2_improvement_gem_mine")

## Save/load da melhoria (só id + coord, marcador reconstruído): ver test_save_manager.gd, que tem
## o fixture de mapa gerado exigido pelo formato do save.

## Completa, EM ORDEM, os nós N1..`tier` da linha econômica `branch` (a pesquisa exige o anterior).
func _research_tier(player: PlayerData, branch: String, tier: int) -> void:
	var ids: Array = V2InfrastructureEconomyData.unlock_ids_for_branch(branch)
	for i in tier:
		var node := V2ResearchDatabase.node_for_unlock_id(ids[i])
		if not player.v2_research.is_completed(node.id):
			assert_true(player.v2_research.complete_research(node.id), "pesquisa %s" % node.id)

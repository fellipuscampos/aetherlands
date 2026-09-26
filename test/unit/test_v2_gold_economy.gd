extends GutTest

## Aetherlands V2, Fase 15 — upkeep de Ouro, renda líquida, e a derivação de Déficit
## (V2EconomyRuntime.is_gold_deficit) sem recursão. Cobre upkeep por tipo de prédio (incluindo
## múltiplas cópias multiplicando), o cálculo bruto/upkeep/líquido, "tesouro financiando um líquido
## temporariamente negativo não é Déficit", os efeitos do Déficit (50% nos prédios COM upkeep,
## 100% em base/Mercado/melhorias) e os gates (bloqueia treino/construção com upkeep, permite
## Mercado e Construtor, nunca cancela produção já em andamento).

const MARKET := "v2_building_market"
const FARM := "v2_building_farm"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const SHIELD := "v2_unit_shieldbearer"
const BUILDER := "v2_unit_builder"

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []

func after_each():
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
	for n in range(1, 10):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	_players.append(player)
	_grids.append(grid)
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	return {"grid": grid, "player": player, "city": city}

# --- Upkeep por prédio -----------------------------------------------------------------------------

func test_gold_upkeep_per_building_type():
	var expected := {
		"v2_building_market": 0.0,
		"v2_building_farm": 1.0,
		"v2_building_workshop": 1.0,
		"v2_building_academy": 1.0,
		"v2_building_arcane_shrine": 1.0,
		"v2_building_guardian_hall": 1.0, "v2_building_guardian_mastery": 2.0,
		"v2_building_warrior_hall": 1.0, "v2_building_warrior_mastery": 2.0,
		"v2_building_ranger_camp": 1.0, "v2_building_ranger_mastery": 2.0,
		"v2_building_war_stable": 1.0, "v2_building_cavalry_mastery": 2.0,
		"v2_building_rogue_guild": 1.0, "v2_building_rogue_mastery": 2.0,
		"v2_building_siege_arsenal": 1.0, "v2_building_grand_arsenal": 2.0,
	}
	for id in expected:
		var building: BuildingData = BuildingDatabase.get_building(id)
		assert_not_null(building, id)
		assert_almost_eq(building.gold_upkeep, float(expected[id]), 0.0001, id)

func test_gold_upkeep_defaults_to_zero_on_the_data_class():
	assert_eq(BuildingData.new().gold_upkeep, 0.0)

func test_multiple_copies_of_the_same_building_multiply_its_upkeep():
	var s := _grid_with_city()
	s.city.buildings[FARM] = true
	s.city.repeatable_building_counts[FARM] = 3
	assert_almost_eq(V2EconomyRuntime.city_gold_upkeep(s.city), 3.0, 0.0001, "3 cópias x 1.0 cada")

func test_city_gold_upkeep_sums_across_different_buildings():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	assert_almost_eq(V2EconomyRuntime.city_gold_upkeep(s.city), 1.0 + 2.0, 0.0001)

func test_player_gold_upkeep_sums_across_cities():
	var s := _grid_with_city()
	var second: City = s.grid.found_city(Vector2i(3, 0), s.player, "Segunda", true)
	s.city.buildings[G_HALL] = true
	second.buildings[FARM] = true
	assert_almost_eq(V2EconomyRuntime.player_gold_upkeep(s.player), 1.0 + 1.0, 0.0001)

# --- Bruto / upkeep / líquido -----------------------------------------------------------------------

func test_net_income_is_gross_minus_upkeep():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true # upkeep 1.0, sem prédio econômico -- bruto fica só a base (2.0)
	var gross := V2EconomyRuntime.player_gold_gross_income(s.player)
	var upkeep := V2EconomyRuntime.player_gold_upkeep(s.player)
	assert_almost_eq(gross, 2.0, 0.0001)
	assert_almost_eq(upkeep, 1.0, 0.0001)
	assert_almost_eq(V2EconomyRuntime.player_gold_net_income(s.player), gross - upkeep, 0.0001)

func test_apply_turn_income_never_lets_gold_go_negative():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true # upkeep 3.0 total, bruto 2.0 (sem Mercado)
	s.player.gold = 0.5
	V2EconomyRuntime.apply_turn_income(s.player)
	assert_eq(s.player.gold, 0.0, "max(0, 0.5 + 2 - 3) = 0, nunca negativo")

# --- Déficit: derivação sem recursão -----------------------------------------------------------------

func test_treasury_financing_a_temporary_negative_net_is_not_deficit():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true # upkeep 3.0 > bruto 2.0 -- líquido negativo
	s.player.gold = 500.0 # mas o caixa está positivo: financia a diferença
	assert_lt(V2EconomyRuntime.player_gold_net_income(s.player), 0.0, "pré-condição: líquido negativo")
	assert_false(V2EconomyRuntime.is_gold_deficit(s.player), "caixa positivo financiando não é Déficit (§36)")

func test_deficit_requires_both_empty_treasury_and_negative_nominal_net():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player))

func test_zero_gold_with_non_negative_nominal_net_is_not_deficit():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true # upkeep 1.0, bruto base 2.0 -- líquido nominal +1.0
	s.player.gold = 0.0
	assert_false(V2EconomyRuntime.is_gold_deficit(s.player))

func test_positive_gold_short_circuits_deficit_regardless_of_net():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	s.player.gold = 1.0
	assert_false(V2EconomyRuntime.is_gold_deficit(s.player))

# --- Efeitos do Déficit: 50% nos prédios COM upkeep, nunca na base/melhoria -------------------------

func test_deficit_never_discounts_a_building_without_upkeep_like_the_market():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true # upkeep 3.0 > base 2.0 (sem Mercado nesta cidade) -- Déficit
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição")
	# Checagem direta e dirigida pelo DADO (BuildingData.gold_upkeep), não por id — Mercado só não é
	# descontado porque gold_upkeep == 0, nunca por um `if building_id == "v2_building_market"`.
	assert_false(V2EconomyRuntime._building_output_is_deficit_discounted(MARKET, s.player), "Mercado (upkeep 0) nunca é descontado, mesmo em Déficit")
	assert_true(V2EconomyRuntime._building_output_is_deficit_discounted(FARM, s.player), "Fazenda (upkeep 1) é descontada em Déficit")

func test_deficit_discounts_a_building_with_upkeep_to_half_its_output():
	var s := _grid_with_city()
	s.city.buildings[FARM] = true # upkeep 1.0
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true # upkeep total suficiente pra Déficit
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição")
	var breakdown := V2EconomyRuntime.city_income_breakdown(s.city, "supply")
	assert_true(breakdown.deficit_discounted, "Fazenda tem upkeep: descontada")
	assert_almost_eq(breakdown.building_total, 4.0 * V2EconomyRuntime.DEFICIT_OUTPUT_MULTIPLIER, 0.0001)

func test_deficit_never_reduces_the_base_per_city_yield():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição")
	var breakdown := V2EconomyRuntime.city_income_breakdown(s.city, "gold")
	assert_almost_eq(breakdown.base, V2InfrastructureEconomyData.BASE_GOLD_PER_CITY, 0.0001, "base nunca reduzida")

func test_deficit_never_reduces_resource_improvement_yields():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	s.player.gold = 0.0
	# Mina de Ferro (Produção) -- uma melhoria de OURO tiraria a civilização do próprio Déficit.
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_iron_mine" # +2 Produção tier 1
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição")
	var breakdown := V2EconomyRuntime.city_income_breakdown(s.city, "production")
	assert_almost_eq(breakdown.improvement_total, 2.0, 0.0001, "melhoria nunca tem upkeep — nunca descontada")

# --- Gates: bloqueia treino/construção com custo, permite Mercado e Construtor -----------------------

func test_deficit_blocks_new_training_of_any_unit_with_positive_supply_cost_with_the_exact_message():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição")
	assert_false(s.city.can_train(SHIELD))
	assert_eq(V2LogisticsRuntime.training_unavailable_reason(s.player, s.city, SHIELD), "Déficit de Ouro: estabilize a economia antes de treinar novas tropas.")

func test_deficit_still_permits_training_the_builder():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição")
	assert_eq(V2LogisticsRuntime.training_unavailable_reason(s.player, s.city, BUILDER), "", "Construtor não tem Suprimentos nem é bloqueado por Déficit")

func test_deficit_blocks_new_construction_of_buildings_with_upkeep_with_the_exact_message():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição")
	assert_false(s.city.can_build(FARM))
	assert_eq(s.city.deficit_build_reason(FARM), "Déficit de Ouro: estabilize a economia antes de adicionar manutenção.")

func test_deficit_still_permits_building_the_market():
	var s := _grid_with_city()
	s.player.v2_research.complete_research(V2ResearchDatabase.node_for_unlock_id(MARKET).id)
	s.city.buildings[G_HALL] = true
	s.city.buildings[G_MASTERY] = true
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição")
	assert_eq(s.city.deficit_build_reason(MARKET), "", "Mercado não tem upkeep -- nunca bloqueado por Déficit")
	assert_true(s.city.can_build(MARKET))

func test_deficit_never_cancels_production_already_in_progress():
	var s := _grid_with_city()
	s.city.buildings[G_HALL] = true
	s.player.gold = 1000.0
	s.city.set_production(SHIELD)
	assert_eq(s.city.production_item, SHIELD)
	s.city.buildings[G_MASTERY] = true # empurra upkeep pra cima
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "pré-condição: Déficit agora ativo")
	assert_eq(s.city.production_item, SHIELD, "produção em andamento não é cancelada pelo Déficit sozinho")

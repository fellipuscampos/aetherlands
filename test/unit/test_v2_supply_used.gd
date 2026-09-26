extends GutTest

## Aetherlands V2, Fase 15 — V2LogisticsRuntime.player_supply_used: unidades vivas + produção EM
## ANDAMENTO de cada cidade (a própria City.production_item já é a reserva, sem segundo estado).
## Cobre vivo/morto/cancelado/duas cidades/Lendária/Construtor excluído, o gate can_train (Suprimentos
## e a mensagem exata) e o delta de upgrade.

const SHIELD := "v2_unit_shieldbearer" # N3, custo 1
const GUARDIAN := "v2_unit_guardian" # N5, custo 2
const SENTINEL := "v2_unit_sentinel" # N7, custo 3
const CHAMPION := "v2_legendary_guardian_champion" # N9, custo 5
const BUILDER := "v2_unit_builder" # custo 0
const HALL := "v2_building_guardian_hall"
const MASTERY := "v2_building_guardian_mastery"

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

## Grid pequeno (raio 4, grama) com uma cidade em (0,0) e pesquisa completa do Guardião — espaço de
## sobra pra espalhar várias unidades/uma segunda cidade sem esbarrar em tile inexistente.
func _grid_with_city() -> Dictionary:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-4, 5):
		for r in range(-4, 5):
			if absi(q + r) <= 4:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var player := PlayerData.new(CivilizationData.new())
	for n in range(1, 10):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	_players.append(player)
	_grids.append(grid)
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	return {"grid": grid, "player": player, "city": city}

func test_a_living_unit_with_supply_cost_counts_towards_used():
	var s := _grid_with_city()
	s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SHIELD), s.player)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 1)

func test_several_living_units_sum_their_costs():
	var s := _grid_with_city()
	s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SHIELD), s.player)
	s.grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit(GUARDIAN), s.player)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 1 + 2)

func test_a_dead_unit_never_counts():
	var s := _grid_with_city()
	var unit: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SENTINEL), s.player)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 3)
	s.grid.remove_unit(unit)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 0, "recalculado do zero — sem hook de refund")

func test_a_unit_with_zero_hp_still_on_the_roster_never_counts():
	var s := _grid_with_city()
	var unit: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SENTINEL), s.player)
	unit.hp = 0.0
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 0)

func test_production_in_progress_reserves_its_cost_even_before_any_unit_exists():
	var s := _grid_with_city()
	s.city.set_production(SHIELD)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 1)

func test_a_building_or_city_project_in_production_reserves_nothing():
	var s := _grid_with_city()
	s.city.set_production(HALL)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 0)

func test_the_builder_in_production_reserves_nothing():
	var s := _grid_with_city()
	s.city.set_production(BUILDER)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 0)

func test_cancelling_production_frees_the_reservation_on_the_next_query():
	var s := _grid_with_city()
	s.city.set_production(SENTINEL)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 3)
	s.city.set_production("")
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 0)

func test_switching_production_to_a_different_kind_replaces_the_reservation_not_adds_to_it():
	var s := _grid_with_city()
	s.city.set_production(SENTINEL)
	s.city.set_production(SHIELD)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 1)

func test_two_cities_reservations_both_count_towards_the_shared_total():
	var s := _grid_with_city()
	var second_city: City = s.grid.found_city(Vector2i(3, 0), s.player, "Segunda", true)
	s.city.set_production(SHIELD)
	second_city.set_production(GUARDIAN)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 1 + 2)

func test_a_legendary_reservation_counts_like_any_other():
	var s := _grid_with_city()
	s.city.set_production(CHAMPION)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 5)

func test_losing_a_city_removes_its_reservation_from_the_shared_total():
	var s := _grid_with_city()
	var second_city: City = s.grid.found_city(Vector2i(3, 0), s.player, "Segunda", true)
	second_city.set_production(SENTINEL)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 3)
	s.player.cities.erase(second_city)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 0, "cidade perdida: reserva recalculada sem ela")

func test_excluding_a_city_removes_only_its_own_reservation_not_the_others():
	var s := _grid_with_city()
	var second_city: City = s.grid.found_city(Vector2i(3, 0), s.player, "Segunda", true)
	s.city.set_production(SHIELD)
	second_city.set_production(GUARDIAN)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player, s.city), 2, "exclui só a própria (SHIELD), mantém a da outra")
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player, second_city), 1, "e vice-versa")

# --- can_train: gate de Suprimentos e a mensagem exata ------------------------------------------

func test_can_train_blocks_when_used_after_would_exceed_capacity_with_the_exact_message():
	var s := _grid_with_city()
	s.city.buildings[HALL] = true
	s.city.buildings[MASTERY] = true
	s.player.gold = 1000.0
	# Capacidade base de UMA cidade sozinha = 4 (V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY,
	# sem Fazenda). A Lendária custa 5: 0 + 5 > 4.
	assert_false(s.city.can_train(CHAMPION))
	assert_eq(V2LogisticsRuntime.training_unavailable_reason(s.player, s.city, CHAMPION), "Suprimentos insuficientes: requer 5, disponíveis 4.")

func test_can_train_never_hides_the_supply_reason_behind_a_generic_one():
	var s := _grid_with_city()
	s.city.buildings[HALL] = true
	s.city.buildings[MASTERY] = true
	s.player.gold = 1000.0
	var reason := V2LogisticsRuntime.training_soft_reason(s.player, s.city, CHAMPION)
	assert_true(reason.begins_with("Suprimentos insuficientes"), reason)

func test_can_train_excludes_the_askers_own_reservation_when_checking_if_it_can_start_a_new_one():
	var s := _grid_with_city()
	s.city.buildings[HALL] = true
	s.player.gold = 1000.0
	s.city.set_production(SENTINEL) # reserva 3 — capacidade 4
	# Reconsultar a MESMA Sentinela (3): a própria reserva atual NUNCA compete contra si mesma (senão
	# 3 + 3 = 6 > 4 e a cidade bloquearia a si própria).
	assert_true(s.city.can_train(SENTINEL), "a reserva da própria cidade não conta contra ela mesma")

func test_can_train_counts_other_cities_reservations_when_checking_capacity():
	var s := _grid_with_city()
	var second_city: City = s.grid.found_city(Vector2i(3, 0), s.player, "Segunda", true)
	s.city.buildings[HALL] = true
	s.player.gold = 1000.0
	# Duas cidades = capacidade 8 (4 + 4). Reserva 3 na OUTRA cidade + uma Sentinela viva (3) = 6.
	second_city.set_production(SENTINEL)
	s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SENTINEL), s.player)
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(s.player), 8.0, 0.0001)
	assert_false(s.city.can_train(SENTINEL), "6 (outra cidade + viva) + 3 (esta) > 8")
	assert_eq(V2LogisticsRuntime.training_unavailable_reason(s.player, s.city, SENTINEL), "Suprimentos insuficientes: requer 3, disponíveis 2.")

func test_a_dead_units_supply_cost_frees_room_for_a_new_one():
	var s := _grid_with_city()
	s.city.buildings[HALL] = true
	s.player.gold = 1000.0
	var unit: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SENTINEL), s.player)
	assert_false(s.city.can_train(SENTINEL), "3 vivo + 3 novo > 4")
	s.grid.remove_unit(unit)
	assert_true(s.city.can_train(SENTINEL), "a capacidade liberou assim que a unidade morreu")

func test_the_builder_is_never_gated_by_supply_capacity():
	var s := _grid_with_city()
	# Estoura a capacidade da cidade de propósito (Suprimentos não deveria nem entrar na conta).
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		s.grid.spawn_unit(n, UnitDatabase.create_unit(SHIELD), s.player)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 4)
	assert_eq(V2LogisticsRuntime._supply_cost_for_kind(BUILDER), 0)

# --- Upgrade: só o DELTA entre formas --------------------------------------------------------------

func test_upgrade_delta_only_charges_the_difference_between_forms():
	assert_eq(V2LogisticsRuntime.upgrade_supply_delta(SHIELD, GUARDIAN), 1, "1 -> 2: delta 1")
	assert_eq(V2LogisticsRuntime.upgrade_supply_delta(GUARDIAN, SENTINEL), 1, "2 -> 3: delta 1")
	assert_eq(V2LogisticsRuntime.upgrade_supply_delta(SHIELD, SENTINEL), 2, "1 -> 3: delta 2")

func test_upgrade_is_blocked_when_the_delta_exceeds_free_capacity_with_the_exact_message():
	var s := _grid_with_city()
	s.city.buildings[HALL] = true
	s.player.gold = 1000.0
	# 3 unidades N3 (custo 1 cada = 3) já ocupam quase toda a capacidade (4).
	var coords := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]
	var units: Array[Unit] = []
	for coord in coords:
		units.append(s.grid.spawn_unit(coord, UnitDatabase.create_unit(SHIELD), s.player))
	var reason := V2LogisticsRuntime.upgrade_unavailable_reason(s.player, units[0], SENTINEL)
	assert_eq(reason, "Suprimentos insuficientes: requer 2, disponíveis 1.", reason)
	assert_false(V2LogisticsRuntime.can_afford_upgrade(s.player, units[0], SENTINEL))

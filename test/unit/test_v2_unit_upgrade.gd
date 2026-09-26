extends GutTest

## Upgrade físico de unidades V2 (V2UnitUpgrade, Aetherlands V2 Fase 4): Escudeiro ->
## Guardião pela API GENÉRICA (metadata `upgrade_to`, custo por fórmula, prédio de
## treino da forma nova). O custo (2 Ouro por PP de diferença) e todos os números são
## BALANCE PLACEHOLDER: os testes calculam o esperado pela fórmula, sem repetir "24".

const SHIELD := "v2_unit_shieldbearer"
const GUARDIAN := "v2_unit_guardian"
const HALL := "v2_building_guardian_hall"
const WALL := "v2_technique_shield_wall"

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _original_turn: int
var _original_human: PlayerData

func before_each():
	_original_turn = TurnManager.turn_number
	_original_human = GameManager.human_player
	TurnManager.turn_number = 5

func after_each():
	TurnManager.turn_number = _original_turn
	GameManager.human_player = _original_human
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()
	for player in _players:
		player.release_relations()
	_players.clear()

# --- Helpers -------------------------------------------------------------------------------------

func _world() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-4, 5):
		for r in range(-4, 5):
			if absi(q + r) <= 4:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

func _player(through: int = 5, gold: float = 100.0) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	player.gold = gold
	for n in range(1, through + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	return player

## Cenário válido: cidade própria com Salão em (0,0), Escudeiro num tile vizinho (território
## da cidade), N1-N5, Ouro de sobra, ação intacta.
func _case(through: int = 5, with_hall: bool = true) -> Dictionary:
	var grid := _world()
	var player := _player(through)
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	if with_hall:
		city.buildings[HALL] = true
	var unit := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SHIELD), player)
	assert_not_null(unit)
	return {"grid": grid, "player": player, "city": city, "unit": unit}

func _reason(c: Dictionary) -> String:
	return V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid)

func _units_of(player: PlayerData, kind: String) -> Array:
	return player.units.filter(func(u): return u.unit_data.visual_kind == kind)

# --- API genérica / metadata ---------------------------------------------------------------------------

func test_the_target_comes_from_the_node_metadata():
	var c := _case()
	var node := V2ResearchDatabase.node_for_unlock_id(SHIELD)
	assert_eq(node.upgrade_to, GUARDIAN)
	assert_eq(V2UnitUpgrade.get_upgrade_target(c.unit), GUARDIAN)

func test_units_without_a_connected_evolution_have_no_target():
	var c := _case()
	var guardian: Unit = c.grid.spawn_unit(Vector2i(0, 1), UnitDatabase.create_unit(GUARDIAN), c.player)
	assert_eq(V2UnitUpgrade.get_upgrade_target(guardian), "v2_unit_sentinel", "Fase 5: o Guardião evolui pra Sentinela (o alvo não exige pesquisa)")
	var sentinel: Unit = c.grid.spawn_unit(Vector2i(0, -1), UnitDatabase.create_unit("v2_unit_sentinel"), c.player)
	assert_eq(V2UnitUpgrade.get_upgrade_target(sentinel), "", "a Sentinela é a última forma da linha")
	var v1: Unit = c.grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit("warrior"), c.player)
	assert_eq(V2UnitUpgrade.get_upgrade_target(v1), "", "unidade V1 não evolui por aqui")
	assert_eq(V2UnitUpgrade.get_upgrade_target(null), "")
	assert_eq(V2UnitUpgrade.upgrade_cost(v1), 0.0)
	assert_ne(V2UnitUpgrade.unavailable_upgrade_reason(c.player, v1, c.grid), "")

func test_the_cost_follows_the_generic_formula():
	var c := _case()
	var expected := V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (UnitDatabase.create_unit(GUARDIAN).production_cost - UnitDatabase.create_unit(SHIELD).production_cost)
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), expected)
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), 24.0, "com os números atuais: 2 x (32 - 20)")

func test_the_upgrade_needs_a_building_derived_from_the_target_not_a_hardcoded_hall():
	assert_eq(BuildingDatabase.building_that_trains(GUARDIAN).id, HALL)

# --- Requisitos ----------------------------------------------------------------------------------------

func test_a_valid_situation_allows_the_upgrade():
	var c := _case()
	assert_eq(_reason(c), "")
	assert_true(V2UnitUpgrade.can_upgrade(c.player, c.unit, c.grid))

func test_without_n5_it_is_refused_with_the_research_reason():
	var c := _case(4)
	assert_eq(_reason(c), "Requer pesquisa: Guardião.")
	assert_false(V2UnitUpgrade.can_upgrade(c.player, c.unit, c.grid))
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.unit.unit_data.visual_kind, SHIELD, "nada mudou")

func test_outside_a_city_it_is_refused():
	var c := _case()
	c.grid.move_unit(c.unit, Vector2i(4, 0), 1.0) # longe do território
	assert_eq(_reason(c), "Precisa estar em uma cidade própria.")
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))

func test_a_city_without_the_hall_refuses():
	var c := _case(5, false)
	assert_eq(_reason(c), "Requer Salão dos Guardiões na cidade.")
	assert_false(V2UnitUpgrade.can_upgrade(c.player, c.unit, c.grid))

func test_the_hall_of_another_city_does_not_count():
	var c := _case(5, false)
	var far_city: City = c.grid.found_city(Vector2i(-4, 0), c.player, "Outra", true)
	far_city.buildings[HALL] = true
	assert_eq(_reason(c), "Requer Salão dos Guardiões na cidade.", "vale o Salão da cidade em cujo território a unidade está")

func test_an_enemy_city_refuses():
	var grid := _world()
	var mine := _player()
	var rival := _player()
	var enemy_city := grid.found_city(Vector2i(0, 0), rival, "Rival", true)
	enemy_city.buildings[HALL] = true
	var unit := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SHIELD), mine)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(mine, unit, grid), "Precisa estar em uma cidade própria.")
	assert_false(V2UnitUpgrade.perform_upgrade(mine, unit, grid))

func test_a_unit_of_another_player_cannot_be_upgraded_by_me():
	var c := _case()
	var other := _player()
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(other, c.unit, c.grid), "A unidade não é sua.")

func test_insufficient_gold_refuses():
	var c := _case()
	c.player.gold = V2UnitUpgrade.upgrade_cost(c.unit) - 1.0
	assert_eq(_reason(c), "Ouro insuficiente (custa 24).")
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.player.gold, 23.0, "nada foi cobrado")

func test_exactly_enough_gold_is_enough():
	var c := _case()
	c.player.gold = V2UnitUpgrade.upgrade_cost(c.unit)
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.player.gold, 0.0)

func test_a_unit_that_already_acted_refuses():
	var c := _case()
	c.unit.movement_left = 0.0
	assert_eq(_reason(c), "A unidade já agiu neste turno.")
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))

func test_a_unit_that_attacked_this_turn_refuses():
	var c := _case()
	var rival := _player(0)
	var target: Unit = c.grid.spawn_unit(Vector2i(2, 0), UnitDatabase.create_unit("warrior"), rival)
	CombatResolver.resolve(c.unit, target, c.grid)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, c.unit, c.grid))

func test_an_active_technique_blocks_the_upgrade_with_a_simple_reason():
	var c := _case()
	assert_true(V2TechniqueRuntime.activate(c.unit, WALL))
	c.unit.movement_left = 2.0 # defensivo: mesmo com ação sobrando
	assert_eq(_reason(c), "Não pode evoluir com Muralha de Escudos ativa.")

# --- Execução ------------------------------------------------------------------------------------------

func test_the_upgrade_turns_the_same_unit_into_a_guardian_and_charges_gold():
	var c := _case()
	var gold: float = c.player.gold
	var unit: Unit = c.unit
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, GUARDIAN)
	assert_eq(unit.unit_data.unit_name, "Guardião")
	assert_eq(unit.unit_data.max_hp, 24.0)
	assert_eq(c.player.gold, gold - 24.0, "Ouro descontado na hora")

func test_it_is_the_same_object_with_no_duplicate_and_no_ghost_shieldbearer():
	var c := _case()
	var unit: Unit = c.unit
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	var count: int = c.player.units.size()
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)

	assert_eq(unit.get_instance_id(), id)
	assert_eq(unit.serial_id, serial)
	assert_eq(c.player.units.size(), count, "não duplica a unidade")
	assert_eq(_units_of(c.player, SHIELD).size(), 0, "nenhum Escudeiro fantasma")
	assert_eq(_units_of(c.player, GUARDIAN).size(), 1)
	assert_same(c.grid.get_unit_at(Vector2i(1, 0)), unit, "um único ocupante no tile")
	assert_eq(unit.coord, Vector2i(1, 0))
	assert_eq(unit.owner_player, c.player)

func test_hp_keeps_the_percentage_and_never_heals_for_free():
	var c := _case()
	var unit: Unit = c.unit
	unit.hp = 9.0 # 9/18 = 50%
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)
	assert_almost_eq(unit.hp, 12.0, 0.0001, "50% de 24")
	assert_lt(unit.hp, unit.unit_data.max_hp)

func test_full_hp_stays_full_and_never_exceeds_the_new_max():
	var c := _case()
	var unit: Unit = c.unit
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)
	assert_eq(unit.hp, 24.0)
	assert_lte(unit.hp, unit.unit_data.max_hp)

func test_an_odd_hp_fraction_is_preserved_proportionally():
	var c := _case()
	var unit: Unit = c.unit
	unit.hp = 4.5 # 25%
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)
	assert_almost_eq(unit.hp / unit.unit_data.max_hp, 0.25, 0.0001)
	assert_gt(unit.hp, 0.0)

func test_xp_veterancy_and_kills_are_preserved():
	var c := _case()
	var unit: Unit = c.unit
	unit.kills = 3
	unit.veterancy_level = 2
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)
	assert_eq(unit.kills, 3)
	assert_eq(unit.veterancy_level, 2)
	assert_eq(unit.veterancy_title(), "Elite")
	assert_almost_eq(unit.veterancy_multiplier(), 1.2, 0.0001)

func test_cooldowns_are_preserved_so_upgrading_does_not_reset_the_technique():
	var c := _case()
	var unit: Unit = c.unit
	V2TechniqueRuntime.activate(unit, WALL) # turno 5, recarga até 8
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(c.player)
	unit.movement_left = 2.0
	var remaining := V2TechniqueRuntime.cooldown_remaining(unit, WALL)
	assert_eq(remaining, 2)

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), remaining, "o Guardião mantém a recarga")
	unit.movement_left = 2.0
	assert_false(V2TechniqueRuntime.can_use(unit, WALL), "evoluir não é um jeito de resetar a técnica")

func test_the_action_is_consumed_movement_zeroed_and_no_second_upgrade_or_attack():
	var c := _case()
	var unit: Unit = c.unit
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)
	assert_eq(unit.movement_left, 0.0)
	var rival := _player(0)
	c.grid.spawn_unit(Vector2i(2, 0), UnitDatabase.create_unit("warrior"), rival)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, unit, c.grid), "já é Guardião e sem ação")
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "v2_unit_sentinel", "a próxima forma é a Sentinela (mas sem N7 e sem ação, não evolui)")

func test_orders_and_exploration_are_cancelled():
	var c := _case()
	var unit: Unit = c.unit
	unit.exploring = true
	unit.move_order_target = Vector2i(3, 0)
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)
	assert_false(unit.exploring)
	assert_eq(unit.move_order_target, Unit.NO_MOVE_ORDER)

func test_the_visual_is_rebuilt_for_the_new_form():
	var c := _case()
	var unit: Unit = c.unit
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)
	assert_true(unit.get_child_count() > 0)
	assert_false(unit.get_children().any(func(n): return n.is_queued_for_deletion() == false and n.name == Unit.TECHNIQUE_MARKER_NAME), "sem técnica ativa, sem anel")
	var visual_children := unit.get_children().filter(func(n): return not n.is_queued_for_deletion())
	assert_gt(visual_children.size(), 2, "corpo, base, barra de vida e ícone foram recriados")

func test_a_human_gets_a_toast_when_upgrading():
	var c := _case()
	GameManager.human_player = c.player
	watch_signals(EventBus)
	V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid)
	assert_signal_emitted_with_parameters(EventBus, "notify", ["Escudeiro evoluiu para Guardião.", "confirm"])

func test_a_rival_upgrade_is_silent():
	var c := _case()
	GameManager.human_player = _player(0)
	watch_signals(EventBus)
	V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid)
	assert_signal_not_emitted(EventBus, "notify")

# --- Reset de debug ----------------------------------------------------------------------------------------

func test_debug_reset_does_not_downgrade_but_blocks_new_use():
	var c := _case()
	var unit: Unit = c.unit
	V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid)
	c.player.v2_research.reset()
	assert_eq(unit.unit_data.visual_kind, GUARDIAN, "conteúdo existente não sofre downgrade")
	assert_true(c.city.buildings.has(HALL))
	unit.movement_left = 2.0
	assert_false(V2TechniqueRuntime.can_use(unit, WALL), "sem N4 não usa a Muralha")
	var fresh: Unit = c.grid.spawn_unit(Vector2i(0, 1), UnitDatabase.create_unit(SHIELD), c.player)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, fresh, c.grid), "sem N5 não evolui")

# --- Genérico ------------------------------------------------------------------------------------------------

## Só o CÓDIGO conta (comentários podem citar exemplos): a lógica é dirigida por metadata.
func _code_of(path: String) -> String:
	var lines: Array[String] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return "\n".join(lines)

func test_the_upgrade_module_never_mentions_a_specific_unit_id():
	var source := _code_of("res://scripts/core/V2UnitUpgrade.gd")
	for forbidden in ["v2_unit_shieldbearer", "v2_unit_guardian", "shieldbearer", "guardian_hall"]:
		assert_false(source.contains(forbidden), "V2UnitUpgrade não pode hardcodar %s" % forbidden)

func test_the_technique_runtime_and_line_modules_never_hardcode_unit_or_technique_ids():
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/V2UnitLine.gd"]:
		var source := _code_of(path)
		for forbidden in ["v2_unit_", "v2_technique_", "shield_wall"]:
			assert_false(source.contains(forbidden), "%s não pode hardcodar %s" % [path, forbidden])

extends GutTest

## Muralha de Escudos (v2_technique_shield_wall, Aetherlands V2 Fase 4) e o framework de
## Técnicas Militares de Doutrina (V2DoctrineTechniqueData/Database + V2TechniqueRuntime).
## Os números (+35% próprio, +15% aliados adjacentes, recarga 3) são BALANCE PLACEHOLDER —
## os testes leem os valores do dado, então rebalancear não quebra a lógica testada.

const WALL := "v2_technique_shield_wall"
const SHIELDBEARER := "v2_unit_shieldbearer"
const GUARDIAN := "v2_unit_guardian"
## Ataque do atacante rival: alto o bastante pra o dano nunca cair no piso de 1 e baixo o bastante pra o Escudeiro sobreviver a um golpe.
const STRIKE := 15.0

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _cities: Array[City] = []
var _supply_granted: Dictionary = {}
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
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	_supply_granted.clear()
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

func _player(research_through: int = 4) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	for n in range(1, research_through + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	return player

func _unit(grid: HexGrid, player: PlayerData, kind: String, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player)
	assert_not_null(unit, "spawn %s em %s" % [kind, str(coord)])
	# Aetherlands V2, Fase 15 — este arquivo é sobre a fórmula da Muralha de Escudos, não sobre
	# Suprimentos: sem cidade nenhuma, a capacidade seria 0 e QUALQUER unidade com supply_cost > 0
	# entraria em Tensão Logística sozinha, poluindo o dano que os testes verificam pela fórmula.
	if unit != null and unit.unit_data.supply_cost > 0 and not _supply_granted.has(player):
		var city := City.new()
		city.owner_player = player
		city.buildings["v2_building_farm"] = true
		city.repeatable_building_counts["v2_building_farm"] = 50
		player.cities.append(city)
		_cities.append(city)
		_supply_granted[player] = true
		if player.gold <= 0.0:
			player.gold = 1000.0
	return unit

func _striker(grid: HexGrid, rival: PlayerData, coord: Vector2i) -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.attack = STRIKE
	var unit := grid.spawn_unit(coord, data, rival)
	assert_not_null(unit)
	return unit

func _damage(grid: HexGrid, attacker: Unit, defender: Unit) -> float:
	return CombatResolver.predict(attacker, defender, grid).damage_to_defender

## Dano esperado de `attack` contra `defense` base, com o mesmo terreno do tile do defensor.
func _expected(grid: HexGrid, attack: float, defender: Unit, extra: float) -> float:
	var terrain := 1.0 + grid.get_tile(defender.coord).defense_bonus
	return maxf(1.0, attack - defender.unit_data.defense * terrain * extra * CombatResolver.DEFENSE_MITIGATION_FACTOR)

# --- Dados / framework ---------------------------------------------------------------------------

func test_the_technique_is_registered_from_data_with_the_canonical_name():
	var technique := V2DoctrineTechniqueDatabase.get_technique(WALL)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Muralha de Escudos")
	assert_eq(technique.display_name, V2ResearchDatabase.node_for_unlock_id(WALL).display_name, "o nome vem do nó")
	assert_eq(technique.doctrine_branch, "guardian")
	assert_eq(technique.duration, V2DoctrineTechniqueData.DURATION_UNTIL_OWNER_NEXT_TURN)

func test_baseline_numbers_are_the_specified_placeholders():
	var technique := V2DoctrineTechniqueDatabase.get_technique(WALL)
	assert_almost_eq(technique.self_defense_bonus, 0.35, 0.0001)
	assert_almost_eq(technique.adjacent_ally_defense_bonus, 0.15, 0.0001)
	assert_eq(technique.adjacent_radius, 1)
	assert_eq(technique.cooldown_turns, 3)
	assert_true(technique.consumes_action)

func test_the_description_is_built_from_the_numbers_and_has_no_placeholder_notice():
	var text := V2DoctrineTechniqueDatabase.get_technique(WALL).description
	assert_true(text.contains("+35%"), text)
	assert_true(text.contains("+15%"), text)
	assert_true(text.contains("recarga de 3 turnos"), text)
	assert_false(text.contains("Gameplay V2"))

func test_it_is_not_a_spell():
	var technique := V2DoctrineTechniqueDatabase.get_technique(WALL)
	var names: Array = technique.get_property_list().map(func(p): return p.name)
	for forbidden in ["mana_cost", "school", "magic_school", "cast_range"]:
		assert_false(forbidden in names, "%s não existe numa técnica militar" % forbidden)

func test_no_technique_id_is_hardcoded_in_the_runtime_lookup():
	# Elegibilidade e defesa vêm do registro: toda técnica defensiva do banco entra em predict.
	assert_true(V2DoctrineTechniqueDatabase.defensive_techniques().has(V2DoctrineTechniqueDatabase.get_technique(WALL)))
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("guardian").size(), 2, "Muralha (ativa) e Preparar Lanças (passiva)")
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("warrior").size(), 2, "o Guerreiro (Fase 7) tem Golpe Poderoso e Ataque em Arco")
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("ranger").size(), 2, "o Patrulheiro (Fase 8) tem Disparo Preciso e Saraivada")
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("cavalry").size(), 2, "a Cavalaria (Fase 9) tem Carga e Retirada Tática")
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("rogue").size(), 2, "o Ladino (Fase 10) tem Ataque Furtivo (ativa) e Desmantelar (passiva)")
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("siege").size(), 2, "o Cerco (Fase 11) tem Munição Demolidora (passiva) e Bombardeio Preparado (ativa)")
	assert_eq(V2DoctrineTechniqueDatabase.get_technique(WALL).activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_eq(V2DoctrineTechniqueDatabase.get_technique("v2_technique_brace_spears").activation_mode, V2DoctrineTechniqueData.ActivationMode.PASSIVE)
	assert_not_null(V2DoctrineTechniqueDatabase.get_technique("v2_technique_demolition_ammo"), "a última Doutrina (Cerco) também está conectada")

# --- Elegibilidade por LINHA ---------------------------------------------------------------------

func test_eligibility_is_by_doctrine_line_not_by_shieldbearer_id():
	assert_eq(V2UnitLine.unit_ids("guardian"), ["v2_unit_shieldbearer", "v2_unit_guardian", "v2_unit_sentinel"], "a Sentinela já é reconhecida na linha")
	for id in V2UnitLine.unit_ids("guardian"):
		assert_eq(V2UnitLine.branch_of(id), "guardian", id)
	assert_eq(V2UnitLine.branch_of("warrior"), "", "unidade V1 não é de linha")
	assert_eq(V2UnitLine.branch_of("v2_unit_warrior"), "warrior", "outra linha, mesma regra")

func test_the_sentinel_is_eligible_without_specific_code():
	# Fase 5: a Sentinela existe e herda a Muralha só por pertencer à LINHA de Doutrina.
	assert_eq(UnitDatabase.create_unit("v2_unit_sentinel").unit_name, "Sentinela")
	var technique := V2DoctrineTechniqueDatabase.get_technique(WALL)
	assert_eq(V2UnitLine.branch_of("v2_unit_sentinel"), technique.doctrine_branch)
	var grid := _world()
	var sentinel := _unit(grid, _player(4), "v2_unit_sentinel", Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.can_use(sentinel, WALL))

func test_not_offered_before_n4_and_offered_after():
	var grid := _world()
	var player := _player(3)
	var unit := _unit(grid, player, SHIELDBEARER, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit), [], "sem o N4 nada aparece")
	assert_ne(V2TechniqueRuntime.unavailable_reason(unit, WALL), "")
	assert_false(V2TechniqueRuntime.can_use(unit, WALL))

	player.v2_research.complete_research("v2_doctrine_guardian_4")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).size(), 1)
	assert_true(V2TechniqueRuntime.can_use(unit, WALL))

func test_shieldbearer_and_guardian_can_both_use_it_and_other_units_cannot():
	var grid := _world()
	var player := _player(5)
	var shield := _unit(grid, player, SHIELDBEARER, Vector2i(0, 0))
	var guardian := _unit(grid, player, GUARDIAN, Vector2i(2, 0))
	var archer := _unit(grid, player, "archer", Vector2i(-2, 0))
	assert_true(V2TechniqueRuntime.can_use(shield, WALL))
	assert_true(V2TechniqueRuntime.can_use(guardian, WALL))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(archer), [])
	assert_false(V2TechniqueRuntime.can_use(archer, WALL))

func test_research_is_per_civilization():
	var grid := _world()
	var researcher := _player(4)
	var other := _player(0)
	var mine := _unit(grid, researcher, SHIELDBEARER, Vector2i(0, 0))
	var theirs := _unit(grid, other, SHIELDBEARER, Vector2i(2, 0))
	assert_true(V2TechniqueRuntime.can_use(mine, WALL))
	assert_false(V2TechniqueRuntime.can_use(theirs, WALL))

# --- Ativação ------------------------------------------------------------------------------------

func test_activation_costs_no_mana_and_no_gold():
	var grid := _world()
	var player := _player()
	player.mana = 7.0
	player.gold = 50.0
	var unit := _unit(grid, player, SHIELDBEARER, Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.activate(unit, WALL))
	assert_eq(player.mana, 7.0)
	assert_eq(player.gold, 50.0)

func test_activation_spends_the_action_and_zeroes_the_remaining_movement():
	var grid := _world()
	var unit := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	unit.movement_left = 1.0 # já se moveu um pouco: ainda pode agir
	assert_true(V2TechniqueRuntime.can_use(unit, WALL))
	assert_true(V2TechniqueRuntime.activate(unit, WALL))
	assert_eq(unit.movement_left, 0.0)
	assert_true(V2TechniqueRuntime.is_active(unit, WALL))

func test_activation_cancels_automatic_orders():
	var grid := _world()
	var unit := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	unit.exploring = true
	unit.move_order_target = Vector2i(3, 0)
	V2TechniqueRuntime.activate(unit, WALL)
	assert_false(unit.exploring)
	assert_eq(unit.move_order_target, Unit.NO_MOVE_ORDER)

func test_cannot_activate_after_the_unit_spent_its_action():
	var grid := _world()
	var unit := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	unit.movement_left = 0.0 # atacou ou gastou o movimento
	assert_false(V2TechniqueRuntime.can_use(unit, WALL))
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, WALL), "A unidade já agiu neste turno.")
	assert_false(V2TechniqueRuntime.activate(unit, WALL))
	assert_false(V2TechniqueRuntime.is_active(unit, WALL), "falhou sem alterar nada")

func test_a_unit_that_attacked_cannot_activate():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var unit := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var target := _unit(grid, rival, "warrior", Vector2i(1, 0))
	CombatResolver.resolve(unit, target, grid) # zera o movimento (ação ofensiva gasta)
	assert_false(V2TechniqueRuntime.can_use(unit, WALL))

func test_the_basic_attack_still_works_while_the_technique_is_unavailable():
	var grid := _world()
	var mine := _player(3) # sem N4: técnica indisponível
	var rival := _player(0)
	var unit := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var target := _unit(grid, rival, "warrior", Vector2i(1, 0))
	var hp := target.hp
	CombatResolver.resolve(unit, target, grid)
	assert_lt(target.hp, hp, "o ataque básico segue disponível")

func test_cannot_activate_twice_while_active():
	var grid := _world()
	var unit := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	V2TechniqueRuntime.activate(unit, WALL)
	unit.movement_left = 2.0
	assert_false(V2TechniqueRuntime.can_use(unit, WALL))
	assert_true(V2TechniqueRuntime.unavailable_reason(unit, WALL).contains("ativa"))

func test_an_unknown_technique_or_a_null_unit_is_refused():
	var grid := _world()
	var unit := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	assert_false(V2TechniqueRuntime.can_use(unit, "v2_technique_inexistente"))
	assert_false(V2TechniqueRuntime.can_use(null, WALL))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(null), [])

# --- Recarga e duração ---------------------------------------------------------------------------------

func test_cooldown_is_three_turns_counted_from_the_activation_turn():
	var grid := _world()
	var unit := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	V2TechniqueRuntime.activate(unit, WALL) # turno 5
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 3)
	TurnManager.turn_number = 6
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 2)
	TurnManager.turn_number = 7
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 1)
	TurnManager.turn_number = 8
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 0)

func test_cannot_use_during_cooldown_and_can_after():
	var grid := _world()
	var unit := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	V2TechniqueRuntime.activate(unit, WALL)
	V2TechniqueRuntime.expire_finished(unit.owner_player)
	for turn in [6, 7]:
		TurnManager.turn_number = turn
		V2TechniqueRuntime.expire_finished(unit.owner_player)
		unit.movement_left = 2.0
		assert_false(V2TechniqueRuntime.can_use(unit, WALL), "turno %d ainda em recarga" % turn)
		assert_true(V2TechniqueRuntime.unavailable_reason(unit, WALL).begins_with("Em recarga"))
	TurnManager.turn_number = 8
	unit.movement_left = 2.0
	assert_true(V2TechniqueRuntime.can_use(unit, WALL))

func test_the_effect_lasts_until_the_owner_next_turn_starts_and_the_cooldown_keeps_counting():
	var grid := _world()
	var player := _player()
	var unit := _unit(grid, player, SHIELDBEARER, Vector2i(0, 0))
	V2TechniqueRuntime.activate(unit, WALL) # turno 5
	assert_true(V2TechniqueRuntime.is_active(unit, WALL))

	# A virada de turno: o mundo age já com turn_number = 6, ainda sob a Muralha.
	TurnManager.turn_number = 6
	assert_true(V2TechniqueRuntime.is_active(unit, WALL), "cobre a fase da IA")
	# ...e o dono volta a jogar: a Muralha termina sozinha (sem clique).
	assert_eq(V2TechniqueRuntime.expire_finished(player), 1)
	assert_false(V2TechniqueRuntime.is_active(unit, WALL))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 2, "a recarga não foi tocada")

func test_expiry_is_a_safety_net_even_if_nobody_calls_the_hook():
	var grid := _world()
	var unit := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	V2TechniqueRuntime.activate(unit, WALL) # turno 5
	TurnManager.turn_number = 7
	assert_false(V2TechniqueRuntime.is_active(unit, WALL), "no máximo até o turno T+1")

func test_expiring_does_not_touch_a_technique_activated_this_turn():
	var grid := _world()
	var player := _player()
	var unit := _unit(grid, player, SHIELDBEARER, Vector2i(0, 0))
	V2TechniqueRuntime.activate(unit, WALL)
	assert_eq(V2TechniqueRuntime.expire_finished(player), 0, "ativada agora não expira agora")
	assert_true(V2TechniqueRuntime.is_active(unit, WALL))

func test_the_visual_marker_follows_the_active_state():
	var grid := _world()
	var player := _player()
	var unit := _unit(grid, player, SHIELDBEARER, Vector2i(0, 0))
	assert_null(unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME))
	V2TechniqueRuntime.activate(unit, WALL)
	assert_not_null(unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME))
	unit.refresh_technique_marker()
	assert_eq(unit.get_children().filter(func(c): return c.name == Unit.TECHNIQUE_MARKER_NAME).size(), 1, "idempotente")
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(player)
	assert_null(unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME))

func test_the_panel_lines_say_active_and_cooldown():
	var grid := _world()
	var player := _player()
	var unit := _unit(grid, player, SHIELDBEARER, Vector2i(0, 0))
	V2TechniqueRuntime.activate(unit, WALL)
	assert_true(V2TechniqueRuntime.status_lines(unit)[0].begins_with("Muralha de Escudos — Ativa"))
	assert_true(TileInspector.status_effect_lines(unit).any(func(l): return l.begins_with("Muralha de Escudos — Ativa")))
	assert_true(V2TechniqueRuntime.cooldown_lines(unit)[0].contains("recarga: 3 turno(s)"))
	# O id cru da técnica não vaza na linha de "Recarga:" dos feitiços (regressão da validação visual).
	assert_false(TileInspector.caster_lines(unit).any(func(l): return l.contains("v2_technique")), "sem id cru no painel")
	assert_eq(TileInspector.caster_lines(unit).filter(func(l): return l.contains("recarga")).size(), 1, "uma única linha de recarga")
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(player)
	assert_eq(V2TechniqueRuntime.status_lines(unit), [])
	assert_true(TileInspector.caster_lines(unit).any(func(l): return l.contains("Muralha de Escudos — recarga: 2 turno(s)")))

# --- Efeito na Defesa (chega à resolução de combate) ---------------------------------------------------------

func test_own_defense_is_raised_by_35_percent_in_combat_prediction():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var defender := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var attacker := _striker(grid, rival, Vector2i(1, 0))
	var before := _damage(grid, attacker, defender)
	assert_almost_eq(before, _expected(grid, STRIKE, defender, 1.0), 0.0001)

	V2TechniqueRuntime.activate(defender, WALL)
	var after := _damage(grid, attacker, defender)
	assert_almost_eq(after, _expected(grid, STRIKE, defender, 1.35), 0.0001, "+35% de Defesa no cálculo real")
	assert_lt(after, before)

func test_the_bonus_reaches_the_real_combat_resolution():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var plain := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var walled := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 2))
	V2TechniqueRuntime.activate(walled, WALL)
	var a1 := _striker(grid, rival, Vector2i(1, 0))
	var a2 := _striker(grid, rival, Vector2i(1, 2))

	var plain_hp := plain.hp
	var walled_hp := walled.hp
	CombatResolver.resolve(a1, plain, grid)
	CombatResolver.resolve(a2, walled, grid)

	var plain_loss := plain_hp - plain.hp
	var walled_loss := walled_hp - walled.hp
	assert_gt(plain_loss, 0.0)
	assert_lt(walled_loss, plain_loss, "quem está de Muralha perde menos vida pelo mesmo golpe")

func test_guardian_also_gets_the_own_bonus():
	var grid := _world()
	var mine := _player(5)
	var rival := _player(0)
	var defender := _unit(grid, mine, GUARDIAN, Vector2i(0, 0))
	var attacker := _striker(grid, rival, Vector2i(1, 0))
	V2TechniqueRuntime.activate(defender, WALL)
	assert_almost_eq(_damage(grid, attacker, defender), _expected(grid, STRIKE, defender, 1.35), 0.0001)

func test_adjacent_ally_gets_15_percent_from_the_formation():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var wall := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var archer := _unit(grid, mine, "archer", Vector2i(1, 0))
	var attacker := _striker(grid, rival, Vector2i(2, 0))
	var base := _damage(grid, attacker, archer)

	V2TechniqueRuntime.activate(wall, WALL)
	assert_almost_eq(_damage(grid, attacker, archer), _expected(grid, STRIKE, archer, 1.15), 0.0001, "+15% enquanto adjacente")
	assert_lt(_damage(grid, attacker, archer), base)

func test_the_protection_is_by_formation_not_a_permanent_buff():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var wall := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var archer := _unit(grid, mine, "archer", Vector2i(1, 0))
	var attacker := _striker(grid, rival, Vector2i(3, 0))
	var base := _damage(grid, attacker, archer)
	V2TechniqueRuntime.activate(wall, WALL)
	var protected := _damage(grid, attacker, archer)
	assert_lt(protected, base)

	grid.move_unit(archer, Vector2i(2, 0), 1.0) # se afasta da Muralha (2 tiles)
	assert_almost_eq(_damage(grid, attacker, archer), base, 0.0001, "afastou-se: perdeu o bônus sozinho")
	grid.move_unit(archer, Vector2i(1, 0), 1.0) # volta pra formação
	assert_almost_eq(_damage(grid, attacker, archer), protected, 0.0001, "voltou: recebe de novo")

func test_the_protection_disappears_when_the_wall_expires():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var wall := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var archer := _unit(grid, mine, "archer", Vector2i(1, 0))
	var attacker := _striker(grid, rival, Vector2i(2, 0))
	var base := _damage(grid, attacker, archer)
	V2TechniqueRuntime.activate(wall, WALL)
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(mine)
	assert_almost_eq(_damage(grid, attacker, archer), base, 0.0001)

func test_two_walls_do_not_stack_on_an_adjacent_ally():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var wall_a := _unit(grid, mine, SHIELDBEARER, Vector2i(-1, 0))
	var wall_b := _unit(grid, mine, SHIELDBEARER, Vector2i(1, 0))
	var archer := _unit(grid, mine, "archer", Vector2i(0, 0))
	var attacker := _striker(grid, rival, Vector2i(0, 1))
	V2TechniqueRuntime.activate(wall_a, WALL)
	var one := _damage(grid, attacker, archer)
	V2TechniqueRuntime.activate(wall_b, WALL)
	var two := _damage(grid, attacker, archer)
	assert_almost_eq(two, one, 0.0001, "duas Muralhas adjacentes dão só +15%")
	assert_almost_eq(two, _expected(grid, STRIKE, archer, 1.15), 0.0001)
	assert_false(is_equal_approx(two, _expected(grid, STRIKE, archer, 1.15 * 1.15)))

func test_the_unit_with_its_own_wall_takes_the_larger_bonus_not_the_sum():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var wall_a := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var wall_b := _unit(grid, mine, SHIELDBEARER, Vector2i(1, 0))
	var attacker := _striker(grid, rival, Vector2i(2, 0))
	V2TechniqueRuntime.activate(wall_a, WALL)
	V2TechniqueRuntime.activate(wall_b, WALL)
	# Cada uma tem o próprio +35% e a vizinha projeta +15%: vale só o maior.
	assert_almost_eq(_damage(grid, attacker, wall_b), _expected(grid, STRIKE, wall_b, 1.35), 0.0001)
	assert_false(is_equal_approx(_damage(grid, attacker, wall_b), _expected(grid, STRIKE, wall_b, 1.35 * 1.15)))
	assert_false(is_equal_approx(_damage(grid, attacker, wall_b), _expected(grid, STRIKE, wall_b, 1.50)))

func test_an_enemy_wall_does_not_protect_my_units():
	var grid := _world()
	var mine := _player()
	var rival := _player(4)
	var rival_wall := _unit(grid, rival, SHIELDBEARER, Vector2i(0, 0))
	var my_unit := _unit(grid, mine, "archer", Vector2i(1, 0))
	var striker := _striker(grid, rival, Vector2i(2, 0))
	var before := _damage(grid, striker, my_unit)
	V2TechniqueRuntime.activate(rival_wall, WALL)
	assert_almost_eq(_damage(grid, striker, my_unit), before, 0.0001, "o aliado tem que ser do MESMO dono")

func test_the_wall_does_not_protect_a_neutral_or_rival_unit_standing_next_to_it():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var wall := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var enemy := _unit(grid, rival, "archer", Vector2i(1, 0))
	var attacker := _unit(grid, mine, "warrior", Vector2i(2, 0))
	var before := _damage(grid, attacker, enemy)
	V2TechniqueRuntime.activate(wall, WALL)
	assert_almost_eq(_damage(grid, attacker, enemy), before, 0.0001)

func test_a_wall_that_is_not_adjacent_gives_nothing():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var wall := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var far_archer := _unit(grid, mine, "archer", Vector2i(2, 0))
	var attacker := _striker(grid, rival, Vector2i(3, 0))
	var base := _damage(grid, attacker, far_archer)
	V2TechniqueRuntime.activate(wall, WALL)
	assert_almost_eq(_damage(grid, attacker, far_archer), base, 0.0001)

func test_a_fallen_protector_gives_no_bonus():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var wall := _unit(grid, mine, SHIELDBEARER, Vector2i(0, 0))
	var archer := _unit(grid, mine, "archer", Vector2i(1, 0))
	var attacker := _striker(grid, rival, Vector2i(2, 0))
	var base := _damage(grid, attacker, archer)
	V2TechniqueRuntime.activate(wall, WALL)
	grid.remove_unit(wall)
	assert_almost_eq(_damage(grid, attacker, archer), base, 0.0001)

func test_defense_without_any_technique_is_exactly_the_v1_value():
	var grid := _world()
	var mine := _player(0)
	var rival := _player(0)
	var defender := _unit(grid, mine, "warrior", Vector2i(0, 0))
	var attacker := _striker(grid, rival, Vector2i(1, 0))
	assert_eq(V2TechniqueRuntime.defense_multiplier(defender, grid), 1.0)
	assert_almost_eq(_damage(grid, attacker, defender), _expected(grid, STRIKE, defender, 1.0), 0.0001)

func test_the_multiplier_ignores_neutral_units_and_a_null_grid():
	var grid := _world()
	var defender := _unit(grid, _player(), SHIELDBEARER, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.defense_multiplier(defender, null), 1.0)
	assert_eq(V2TechniqueRuntime.defense_multiplier(null, grid), 1.0)

# --- Evolução e recarga; sem processamento por frame ----------------------------------------------------------

func test_the_cooldown_and_status_live_on_the_unit_so_evolving_keeps_them():
	var grid := _world()
	var player := _player(5)
	var unit := _unit(grid, player, SHIELDBEARER, Vector2i(0, 0))
	V2TechniqueRuntime.activate(unit, WALL)
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(player)
	unit.apply_form(UnitDatabase.create_unit(GUARDIAN))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 2, "evoluir não reseta a recarga")

func test_there_is_no_per_frame_hook_in_the_runtime():
	var runtime := V2TechniqueRuntime.new()
	assert_false(runtime.has_method("_process"))
	assert_false(runtime.has_method("_physics_process"))

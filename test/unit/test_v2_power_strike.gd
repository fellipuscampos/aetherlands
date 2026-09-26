extends "res://test/unit/v2_combat_fixture.gd"

## Golpe Poderoso (v2_technique_power_strike, Aetherlands V2 Fase 7): a primeira técnica ATIVA DE ATAQUE do
## framework de Técnicas Militares (V2DoctrineTechniqueData/Database + V2TechniqueRuntime), do Guerreiro. Números
## (1,60x, recarga 3) = BALANCE PLACEHOLDER — os testes leem o multiplicador do dado quando o assunto é a lógica e
## fixam os valores canônicos só no teste de baseline.

## Guerreiro (N3) em (0,0) e um inimigo em guerra no vizinho (1,0).
func _duel(target_hp: float = 40.0, target_def: float = 3.0, through: int = 4) -> Dictionary:
	var grid := _world()
	var me := _player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	var foe := _foe(grid, rival, Vector2i(1, 0), target_hp, target_def)
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "foe": foe}

# --- Dado ----------------------------------------------------------------------------------------------------

func test_the_technique_has_the_specified_active_strike_baseline():
	var technique := _technique(POWER)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Golpe Poderoso", "o nome vem do nó de pesquisa")
	assert_eq(technique.doctrine_branch, "warrior")
	assert_eq(technique.activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_true(technique.is_strike())
	assert_eq(technique.strike_multiplier, 1.6)
	assert_eq(technique.strike_targeting, V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET)
	assert_eq(technique.strike_max_targets, 1)
	assert_eq(technique.strike_range, 1, "adjacente")
	assert_eq(technique.cooldown_turns, 3)
	assert_true(technique.consumes_action)

func test_it_is_registered_in_the_same_database_as_the_guardian_techniques():
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(POWER)))
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("warrior").size(), 2)
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(WALL)), "a Muralha continua ao lado")
	assert_true("v2_technique_power_strike" in V2DoctrineContent.CONNECTED_UNLOCK_IDS)

func test_it_is_neither_a_defensive_stance_nor_a_passive_bonus():
	var technique := _technique(POWER)
	assert_false(technique.has_defense_effect())
	assert_false(technique.has_attack_effect(), "não é bônus passivo contra um traço")
	assert_false(V2DoctrineTechniqueDatabase.defensive_techniques().has(technique))
	assert_false(V2DoctrineTechniqueDatabase.attack_bonus_techniques().has(technique))
	assert_false(technique.is_passive())

func test_the_description_and_button_suffix_are_built_from_the_data():
	var technique := _technique(POWER)
	assert_true(technique.description.contains("×1.6"), technique.description)
	assert_true(technique.description.contains("recarga de 3 turnos"), technique.description)
	assert_eq(V2DoctrineTechniqueDatabase.button_suffix(technique), "×1.6")
	assert_eq(V2DoctrineTechniqueDatabase.button_suffix(_technique(WALL)), "", "as demais técnicas não têm sufixo")

func test_the_multiplier_comes_from_the_data_not_from_the_code():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var technique := _technique(POWER)
	var original := technique.strike_multiplier
	technique.strike_multiplier = 2.5
	var predicted: float = CombatResolver.predict(unit, foe, d.grid, technique.strike_multiplier).damage_to_defender
	assert_eq(predicted, _formula_damage(d.grid, 5.0, 2.5, foe))
	var hp_before := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, foe, d.grid))
	assert_almost_eq(hp_before - foe.hp, predicted, 0.0001, "o golpe usa o que está no dado")
	technique.strike_multiplier = original

# --- Elegibilidade -------------------------------------------------------------------------------------------

func test_it_appears_only_after_n4():
	var grid := _world()
	var me := _player(3)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty(), "N3 não dá técnica")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, POWER, grid), "Requer pesquisa: Golpe Poderoso.")
	me.v2_research.complete_research("v2_doctrine_warrior_4")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [POWER])
	assert_eq(V2TechniqueRuntime.active_techniques_for_unit(unit).size(), 1, "é ativa: ganha botão")

func test_only_the_warrior_branch_has_it_every_form_of_the_line_inherits_it():
	var grid := _world()
	var me := _player(9)
	for kind in [WARRIOR, SWORDSMAN, MASTER, HERO]:
		var unit := _unit(grid, me, kind, Vector2i(0, 0) if kind == WARRIOR else _free_coord(grid))
		assert_true(V2TechniqueRuntime.techniques_for_unit(unit).any(func(t): return t.id == POWER), "%s herda o Golpe Poderoso" % kind)

func test_a_guardian_or_v1_unit_never_gets_it_even_when_the_owner_researched_it():
	var grid := _world()
	var me := _player(9, 9)
	var shield := _unit(grid, me, SHIELD, Vector2i(0, 0))
	var champion := _unit(grid, me, CHAMPION, Vector2i(2, 0))
	var v1 := _unit(grid, me, "warrior", Vector2i(-2, 0))
	for unit in [shield, champion, v1]:
		assert_false(V2TechniqueRuntime.techniques_for_unit(unit).any(func(t): return t.id == POWER), unit.unit_data.unit_name)
	assert_eq(V2TechniqueRuntime.unavailable_reason(shield, POWER, grid), "Esta unidade não pertence à linha da Doutrina.")
	assert_eq(V2TechniqueRuntime.unavailable_reason(v1, POWER, grid), "Esta unidade não pertence à linha da Doutrina.")

func test_a_warrior_of_a_civilization_without_the_warrior_research_has_nothing():
	var grid := _world()
	var only_guardian := _player(0, 9)
	var unit := _unit(grid, only_guardian, WARRIOR, Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty())

func test_the_guardian_techniques_do_not_leak_into_the_warrior():
	var grid := _world()
	var me := _player(9, 9)
	var warrior := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	var ids: Array = V2TechniqueRuntime.techniques_for_unit(warrior).map(func(t): return t.id)
	assert_true(POWER in ids and CLEAVE in ids)
	assert_false(WALL in ids)
	assert_false("v2_technique_brace_spears" in ids)

func _free_coord(grid: HexGrid) -> Vector2i:
	for coord in grid.tiles.keys():
		if grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			return coord
	fail_test("sem tile livre")
	return Vector2i.ZERO

# --- Alvo ----------------------------------------------------------------------------------------------------

func test_the_target_must_be_adjacent_and_hostile_no_enemy_next_to_it_means_unavailable():
	var grid := _world()
	var me := _player()
	var rival := _rival_of(me)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	_foe(grid, rival, Vector2i(2, 0)) # a 2 tiles: fora do alcance
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, POWER, grid), "Nenhum inimigo adjacente.")
	assert_false(V2TechniqueRuntime.can_use(unit, POWER, grid))
	_foe(grid, rival, Vector2i(1, 0))
	assert_true(V2TechniqueRuntime.can_use(unit, POWER, grid))

func test_allies_civilizations_at_peace_and_cities_are_never_targets():
	var grid := _world()
	var me := _player()
	var rival := _rival_of(me)
	var peaceful := PlayerData.new(CivilizationData.new())
	_players.append(peaceful)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	var technique := _technique(POWER)
	_unit(grid, me, SHIELD, Vector2i(1, 0)) # aliado
	_foe(grid, peaceful, Vector2i(0, 1)) # civilização sem guerra
	assert_not_null(grid.found_city(Vector2i(-1, 0), rival, "Rival", true), "cidade inimiga adjacente")
	assert_true(V2TechniqueRuntime.strike_targets(unit, technique, grid).is_empty(), "nenhum alvo válido")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, POWER, grid), "Nenhum inimigo adjacente.")
	assert_false(V2TechniqueRuntime.perform_strike(unit, POWER, grid.get_unit_at(Vector2i(1, 0)), grid), "aliado não pode ser alvo")
	assert_eq(int(unit.magic_cooldowns.get(POWER, 0)), 0)

func test_the_hostility_rule_is_the_one_of_the_normal_attack_including_neutral_monsters():
	var grid := _world()
	var me := _player()
	var rival := _rival_of(me)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	var foe := _foe(grid, rival, Vector2i(1, 0))
	assert_true(CombatResolver.can_attack_unit(unit, foe, grid))
	assert_false(CombatResolver.can_attack_unit(unit, unit, grid), "nunca a si mesma")
	assert_false(CombatResolver.can_attack_unit(unit, null, grid))
	foe.owner_player = null # monstro neutro: hostil a todos, sem diplomacia
	assert_true(CombatResolver.can_attack_unit(unit, foe, grid))
	foe.owner_player = me
	assert_false(CombatResolver.can_attack_unit(unit, foe, grid), "mesmo dono")

# --- Multiplicador e resolução -------------------------------------------------------------------------------

func test_the_strike_hits_with_160_percent_of_the_basic_attack():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var basic: float = CombatResolver.predict(unit, foe, d.grid).damage_to_defender
	var strike: float = CombatResolver.predict(unit, foe, d.grid, _technique(POWER).strike_multiplier).damage_to_defender
	assert_eq(basic, _formula_damage(d.grid, 5.0, 1.0, foe), "ataque comum: 5,0 - 3,0/2")
	assert_eq(strike, _formula_damage(d.grid, 5.0, 1.6, foe), "golpe: 8,0 - 3,0/2")
	assert_gt(strike, basic)
	assert_eq(CombatResolver.predict(unit, foe, d.grid, 1.0).damage_to_defender, basic, "1.0 é o ataque comum")

func test_prediction_and_real_resolution_agree_hp_loss_equals_the_predicted_damage():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var predicted: float = CombatResolver.predict(unit, foe, d.grid, 1.6).damage_to_defender
	var before := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, foe, d.grid))
	assert_almost_eq(before - foe.hp, predicted, 0.0001)
	assert_almost_eq(before - foe.hp, 6.5, 0.0001, "5,0 x 1,6 - 3,0 x 0,5")

func test_it_consumes_the_action_and_zeroes_the_remaining_movement():
	var d := _duel()
	var unit: Unit = d.unit
	assert_gt(unit.movement_left, 0.0)
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, d.foe, d.grid))
	assert_eq(unit.movement_left, 0.0)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, POWER, d.grid), "Em recarga: 3 turno(s).", "a recarga tem prioridade sobre a ação já gasta")
	unit.movement_left = 0.0
	unit.magic_cooldowns.erase(POWER)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, POWER, d.grid), "A unidade já agiu neste turno.")

func test_the_cooldown_is_three_turns_counting_the_turn_of_use():
	var d := _duel()
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, d.foe, d.grid))
	assert_eq(int(unit.magic_cooldowns[POWER]), 5 + 3)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, POWER), 3)
	unit.movement_left = unit.unit_data.movement_points
	assert_false(V2TechniqueRuntime.can_use(unit, POWER, d.grid))
	TurnManager.turn_number = 7
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, POWER), 1)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, POWER, d.grid), "Em recarga: 1 turno(s).")
	TurnManager.turn_number = 8
	assert_true(V2TechniqueRuntime.can_use(unit, POWER, d.grid), "volta no turno T+3")

func test_it_costs_no_mana_and_no_gold():
	var d := _duel()
	var me: PlayerData = d.me
	me.gold = 50.0
	me.mana = 20.0
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, POWER, d.foe, d.grid))
	assert_eq(me.gold, 50.0)
	assert_eq(me.mana, 20.0)

func test_no_effect_is_stored_only_the_cooldown_so_it_never_blocks_an_upgrade_or_shows_as_active():
	var d := _duel()
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, d.foe, d.grid))
	assert_true(unit.magic_status.get(POWER, null) == null, "sem magic_status")
	assert_false(V2TechniqueRuntime.is_active(unit, POWER))
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "")
	assert_true(V2TechniqueRuntime.status_lines(unit).is_empty())
	assert_eq(V2TechniqueRuntime.expire_finished(d.me), 0, "nada a expirar")
	assert_true(V2TechniqueRuntime.cooldown_lines(unit).any(func(l): return l.begins_with("Golpe Poderoso")))

func test_activate_refuses_strike_techniques_they_need_a_target():
	var d := _duel()
	var unit: Unit = d.unit
	assert_false(V2TechniqueRuntime.activate(unit, POWER))
	assert_eq(int(unit.magic_cooldowns.get(POWER, 0)), 0)
	assert_gt(unit.movement_left, 0.0)

func test_a_failed_use_changes_nothing():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var far := _foe(d.grid, d.rival, Vector2i(3, 0))
	var hp := foe.hp
	var movement := unit.movement_left
	assert_false(V2TechniqueRuntime.perform_strike(unit, POWER, null, d.grid), "sem alvo")
	assert_false(V2TechniqueRuntime.perform_strike(unit, POWER, far, d.grid), "alvo fora do alcance")
	assert_false(V2TechniqueRuntime.perform_strike(unit, POWER, unit, d.grid), "não pode ser ela mesma")
	assert_false(V2TechniqueRuntime.perform_strike(unit, "v2_technique_shield_wall", foe, d.grid), "não é técnica de ataque")
	assert_false(V2TechniqueRuntime.perform_strike(unit, "v2_inexistente", foe, d.grid))
	assert_eq(foe.hp, hp)
	assert_eq(unit.movement_left, movement)
	assert_false(unit.magic_cooldowns.has(POWER))

func test_it_passes_through_the_normal_defense_chain_wall_on_the_target_reduces_the_damage():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	foe.magic_status[WALL] = TurnManager.turn_number + 2 # Muralha de Escudos ativa no alvo (+35% Defesa)
	var wall_bonus: float = 1.0 + _technique(WALL).self_defense_bonus
	var expected := _formula_damage(d.grid, 5.0, 1.6, foe, wall_bonus)
	assert_lt(expected, _formula_damage(d.grid, 5.0, 1.6, foe))
	var before := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, foe, d.grid))
	assert_almost_eq(before - foe.hp, expected, 0.0001, "mesma cadeia de defesa do ataque normal")

func test_the_defenders_aura_from_a_command_champion_also_counts():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var rival: PlayerData = d.rival
	_unit(d.grid, rival, CHAMPION, Vector2i(2, 0)) # Comando Defensivo do inimigo: +20% Defesa ao aliado adjacente
	var aura: float = 1.0 + UnitDatabase.create_unit(CHAMPION).aura_defense_bonus
	var before := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, foe, d.grid))
	assert_almost_eq(before - foe.hp, _formula_damage(d.grid, 5.0, 1.6, foe, aura), 0.0001)

func test_a_kill_counts_once_for_xp_and_removes_the_target():
	var d := _duel(4.0, 3.0)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var rival: PlayerData = d.rival
	assert_eq(unit.kills, 0)
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, foe, d.grid))
	assert_eq(unit.kills, 1, "um abate, contado uma vez")
	assert_false(rival.units.has(foe), "o alvo saiu do jogo")
	assert_null(d.grid.get_unit_at(Vector2i(1, 0)))
	assert_eq(unit.movement_left, 0.0)

func test_a_surviving_target_counterattacks_exactly_like_in_a_normal_attack():
	var d := _duel(60.0, 14.0) # Defesa alta: revida (o revide sai da Defesa do alvo)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var prediction: Dictionary = CombatResolver.predict(unit, foe, d.grid, 1.6)
	assert_gt(prediction.damage_to_attacker, 0.0, "pré-condição: há revide")
	var my_hp := unit.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, foe, d.grid))
	assert_almost_eq(my_hp - unit.hp, prediction.damage_to_attacker, 0.0001)

func test_cooldown_and_preservation_across_forms_the_cooldown_lives_on_the_unit():
	var d := _duel()
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, d.foe, d.grid))
	var cooldown: int = unit.magic_cooldowns[POWER]
	unit.apply_form(UnitDatabase.create_unit(SWORDSMAN))
	assert_eq(int(unit.magic_cooldowns[POWER]), cooldown, "evoluir não reinicia a recarga")

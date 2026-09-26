extends "res://test/unit/v2_combat_fixture.gd"

## Ataque em Arco (v2_technique_cleave, Aetherlands V2 Fase 7): a segunda técnica ATIVA DE ATAQUE do Guerreiro — sem
## mira, atinge até 3 inimigos ADJACENTES, cada um por uma resolução de combate normal a 0,75x o Ataque. Números
## (0,75x, 3 alvos, recarga 4) = BALANCE PLACEHOLDER.

## Direções dos 6 vizinhos de (0,0), em ordem fixa.
const RING := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

## Guerreiro (N3) em (0,0), com `count` inimigos nos primeiros vizinhos de RING. `through` = nível do Guerreiro pesquisado.
func _arc(count: int, target_hp: float = 40.0, target_def: float = 3.0, through: int = 6) -> Dictionary:
	var grid := _world()
	var me := _player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	var foes: Array[Unit] = []
	for i in count:
		foes.append(_foe(grid, rival, RING[i], target_hp, target_def))
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "foes": foes}

# --- Dado ----------------------------------------------------------------------------------------------------

func test_the_technique_has_the_specified_active_arc_baseline():
	var technique := _technique(CLEAVE)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Ataque em Arco", "o nome vem do nó (o unlock id é 'cleave')")
	assert_eq(technique.doctrine_branch, "warrior")
	assert_eq(technique.activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_true(technique.is_strike())
	assert_eq(technique.strike_multiplier, 0.75)
	assert_eq(technique.strike_targeting, V2DoctrineTechniqueData.StrikeTargeting.ADJACENT_ENEMIES, "sem mira")
	assert_eq(technique.strike_max_targets, 3)
	assert_eq(technique.strike_range, 1)
	assert_eq(technique.cooldown_turns, 4)
	assert_true(technique.consumes_action)
	assert_true(technique.description.contains("até 3 inimigos adjacentes"), technique.description)
	assert_true(technique.description.contains("×0.75"), technique.description)
	assert_eq(V2DoctrineTechniqueDatabase.button_suffix(technique), "×0.75")

func test_it_is_a_single_target_burst_versus_a_multi_target_pressure_by_design():
	var power := _technique(POWER)
	var cleave := _technique(CLEAVE)
	assert_lt(cleave.strike_multiplier, 1.0, "contra um único alvo o Arco rende menos que o ataque comum")
	assert_gt(power.strike_multiplier, cleave.strike_multiplier * 2.0, "o Golpe Poderoso é o burst de alvo único")
	assert_gt(cleave.cooldown_turns, power.cooldown_turns)

# --- Disponibilidade -----------------------------------------------------------------------------------------

func test_it_appears_only_after_n6():
	var grid := _world()
	var me := _player(5)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	assert_false(V2TechniqueRuntime.techniques_for_unit(unit).any(func(t): return t.id == CLEAVE), "N5 ainda não")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, CLEAVE, grid), "Requer pesquisa: Ataque em Arco.")
	me.v2_research.complete_research("v2_doctrine_warrior_6")
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).any(func(t): return t.id == CLEAVE))

func test_only_the_warrior_branch_and_every_form_of_it_have_it():
	var grid := _world()
	var me := _player(9, 9)
	var master := _unit(grid, me, MASTER, Vector2i(0, 0))
	var hero := _unit(grid, me, HERO, Vector2i(3, 0))
	var shield := _unit(grid, me, SHIELD, Vector2i(-3, 0))
	assert_true(V2TechniqueRuntime.techniques_for_unit(master).any(func(t): return t.id == CLEAVE))
	assert_true(V2TechniqueRuntime.techniques_for_unit(hero).any(func(t): return t.id == CLEAVE))
	assert_false(V2TechniqueRuntime.techniques_for_unit(shield).any(func(t): return t.id == CLEAVE))

func test_zero_adjacent_enemies_makes_it_unavailable_and_consumes_nothing():
	var d := _arc(0)
	var unit: Unit = d.unit
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, CLEAVE, d.grid), "Nenhum inimigo adjacente.")
	var movement := unit.movement_left
	assert_false(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid))
	assert_eq(unit.movement_left, movement, "a ação não foi gasta")
	assert_false(unit.magic_cooldowns.has(CLEAVE), "a recarga não começou")

func test_an_enemy_two_tiles_away_is_not_adjacent():
	var d := _arc(0)
	_foe(d.grid, d.rival, Vector2i(2, 0))
	assert_false(V2TechniqueRuntime.can_use(d.unit, CLEAVE, d.grid))

# --- Um, dois e três alvos ---------------------------------------------------------------------------------

func test_it_works_with_one_two_and_three_targets_each_at_075_of_the_attack():
	for count in [1, 2, 3]:
		var d := _arc(count)
		var unit: Unit = d.unit
		var foes: Array = d.foes
		var expected := _formula_damage(d.grid, 5.0, 0.75, foes[0])
		assert_almost_eq(expected, 3.75 - 1.5, 0.0001, "0,75 x 5,0 - 3,0/2")
		assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid), "%d alvo(s)" % count)
		for foe in foes:
			assert_almost_eq(40.0 - foe.hp, expected, 0.0001, "cada alvo perde o dano de 0,75x (%d alvos)" % count)
		assert_eq(unit.movement_left, 0.0)
		assert_eq(int(unit.magic_cooldowns[CLEAVE]), 5 + 4)

func test_a_single_target_arc_hits_less_than_the_basic_attack_and_far_less_than_a_power_strike():
	var d := _arc(1)
	var unit: Unit = d.unit
	var foe: Unit = d.foes[0]
	var basic: float = CombatResolver.predict(unit, foe, d.grid).damage_to_defender
	var arc: float = CombatResolver.predict(unit, foe, d.grid, 0.75).damage_to_defender
	var power: float = CombatResolver.predict(unit, foe, d.grid, 1.6).damage_to_defender
	assert_lt(arc, basic)
	assert_gt(power, basic)
	assert_gt(power, arc * 2.0)

func test_prediction_and_real_resolution_agree_for_every_target():
	var d := _arc(3, 40.0, 3.0)
	var unit: Unit = d.unit
	var foes: Array = d.foes
	var predicted: Array[float] = []
	for foe in foes:
		predicted.append(CombatResolver.predict(unit, foe, d.grid, 0.75).damage_to_defender)
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid))
	for i in foes.size():
		assert_almost_eq(40.0 - foes[i].hp, predicted[i], 0.0001)

func test_it_ignores_the_target_argument_it_hits_everyone_adjacent():
	var d := _arc(3)
	var foes: Array = d.foes
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CLEAVE, foes[2], d.grid))
	for foe in foes:
		assert_lt(foe.hp, 40.0)

# --- Mais de três alvos: seleção determinística -------------------------------------------------------------

func test_with_more_than_three_the_three_lowest_hp_percent_are_hit_first():
	var d := _arc(5)
	var foes: Array = d.foes
	# HP% por vizinho: 100, 30, 80, 45, 60 -> os três menores são os índices 1 (30%), 3 (45%) e 4 (60%).
	var hp := [40.0, 12.0, 32.0, 18.0, 24.0]
	for i in 5:
		foes[i].hp = hp[i]
	var targets := V2TechniqueRuntime.strike_targets(d.unit, _technique(CLEAVE), d.grid)
	assert_eq(targets.size(), 3)
	assert_eq(targets.map(func(u): return u.coord), [RING[1], RING[3], RING[4]], "menor HP% primeiro")
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CLEAVE, null, d.grid))
	assert_eq(foes[0].hp, 40.0, "o de 100% ficou de fora")
	assert_eq(foes[2].hp, 32.0, "o de 80% ficou de fora")
	for i in [1, 3, 4]:
		assert_lt(foes[i].hp, hp[i], "atingido: %d" % i)

func test_ties_are_broken_by_the_lowest_serial_id_not_by_tile_order():
	var grid := _world()
	var me := _player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	# Inimigos criados na ORDEM INVERSA dos vizinhos: o serial_id cresce enquanto o índice do RING decresce.
	var order := [5, 4, 3, 2, 1, 0]
	var by_ring := {}
	for i in order:
		by_ring[i] = _foe(grid, rival, RING[i])
	var targets := V2TechniqueRuntime.strike_targets(unit, _technique(CLEAVE), grid)
	assert_eq(targets.size(), 3)
	# HP% idênticos (100%): valem os três MENORES serial_id = os três primeiros criados (RING 5, 4, 3).
	assert_eq(targets.map(func(u): return u.coord), [RING[5], RING[4], RING[3]])
	var serials: Array = targets.map(func(u): return u.serial_id)
	var sorted_serials := serials.duplicate()
	sorted_serials.sort()
	assert_eq(serials, sorted_serials, "e na ordem do serial")

func test_the_selection_is_stable_across_repeated_calls():
	var d := _arc(6)
	var first := V2TechniqueRuntime.strike_targets(d.unit, _technique(CLEAVE), d.grid).map(func(u): return u.serial_id)
	for i in 5:
		assert_eq(V2TechniqueRuntime.strike_targets(d.unit, _technique(CLEAVE), d.grid).map(func(u): return u.serial_id), first)

func test_more_than_three_enemies_still_hits_exactly_three():
	var d := _arc(6)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CLEAVE, null, d.grid))
	var hit := 0
	for foe in d.foes:
		if foe.hp < 40.0:
			hit += 1
	assert_eq(hit, 3)

func test_the_cap_comes_from_the_data():
	var d := _arc(5)
	var technique := _technique(CLEAVE)
	technique.strike_max_targets = 2
	assert_eq(V2TechniqueRuntime.strike_targets(d.unit, technique, d.grid).size(), 2)
	technique.strike_max_targets = 3

# --- Quem nunca é atingido ----------------------------------------------------------------------------------

func test_allies_peaceful_civilizations_and_cities_are_never_hit():
	var grid := _world()
	var me := _player(6)
	var rival := _rival_of(me)
	var peaceful := PlayerData.new(CivilizationData.new())
	_players.append(peaceful)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	var ally := _unit(grid, me, SHIELD, RING[0])
	var neutral := _foe(grid, peaceful, RING[1]) # sem guerra
	var enemy_city := grid.found_city(RING[2], rival, "Rival", true)
	var enemy := _foe(grid, rival, RING[3])
	var ally_hp := ally.hp
	var neutral_hp := neutral.hp
	var city_hp := enemy_city.hp
	assert_eq(V2TechniqueRuntime.strike_targets(unit, _technique(CLEAVE), grid), [enemy], "só o inimigo real")
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, grid))
	assert_eq(ally.hp, ally_hp, "aliado intacto")
	assert_eq(neutral.hp, neutral_hp, "civilização em paz intacta")
	assert_eq(enemy_city.hp, city_hp, "cidade inimiga intacta (é anti-unidade)")
	assert_lt(enemy.hp, 40.0)

func test_it_never_hits_an_unit_that_the_normal_attack_could_not():
	var d := _arc(2)
	var foes: Array = d.foes
	d.me.enemies.erase(d.rival) # a guerra acabou
	d.rival.enemies.erase(d.me)
	assert_true(V2TechniqueRuntime.strike_targets(d.unit, _technique(CLEAVE), d.grid).is_empty())
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CLEAVE, d.grid), "Nenhum inimigo adjacente.")
	assert_eq(foes[0].hp, 40.0)

# --- Defesa individual, abates e XP ---------------------------------------------------------------------------

func test_each_target_uses_its_own_defense_terrain_and_effects():
	var grid := _world()
	var me := _player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	var soft := _foe(grid, rival, RING[0], 40.0, 2.0)
	var hard := _foe(grid, rival, RING[1], 40.0, 9.0)
	var walled := _foe(grid, rival, RING[2], 40.0, 4.0)
	walled.magic_status[WALL] = TurnManager.turn_number + 2
	var wall_bonus: float = 1.0 + _technique(WALL).self_defense_bonus
	var expected_soft := _formula_damage(grid, 5.0, 0.75, soft)
	var expected_hard := _formula_damage(grid, 5.0, 0.75, hard)
	var expected_walled := _formula_damage(grid, 5.0, 0.75, walled, wall_bonus)
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, grid))
	assert_almost_eq(40.0 - soft.hp, expected_soft, 0.0001)
	assert_almost_eq(40.0 - hard.hp, expected_hard, 0.0001)
	assert_almost_eq(40.0 - walled.hp, expected_walled, 0.0001)
	assert_gt(expected_soft, expected_walled)
	assert_gt(expected_walled, expected_hard - 1.0, "as três contas são diferentes: nada de dano total dividido")

func test_the_command_aura_of_the_enemy_reaches_only_the_units_inside_it():
	var d := _arc(0)
	# Campeão inimigo em (2,0): a distância 1 de RING[0]=(1,0) e a 3 de RING[3]=(-1,0) (raio da aura = 2).
	_unit(d.grid, d.rival, CHAMPION, Vector2i(2, 0))
	var protected := _foe(d.grid, d.rival, RING[0])
	var exposed := _foe(d.grid, d.rival, RING[3])
	var aura: float = 1.0 + UnitDatabase.create_unit(CHAMPION).aura_defense_bonus
	var expected_protected := _formula_damage(d.grid, 5.0, 0.75, protected, aura)
	var expected_exposed := _formula_damage(d.grid, 5.0, 0.75, exposed)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CLEAVE, null, d.grid))
	assert_almost_eq(40.0 - protected.hp, expected_protected, 0.0001)
	assert_almost_eq(40.0 - exposed.hp, expected_exposed, 0.0001)
	assert_gt(expected_exposed, expected_protected)

func test_multiple_kills_count_one_each_for_xp_and_remove_every_victim():
	var d := _arc(3, 3.0, 3.0) # HP 3: 3,75 - 1,5 = 2,25 não mata; usa HP 2
	for foe in d.foes:
		foe.hp = 2.0
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid))
	assert_eq(unit.kills, 3, "três abates, um por vítima")
	assert_eq(unit.veterancy_level, Unit._level_for_kills(3), "a veterania segue a regra normal")
	for foe in d.foes:
		assert_false(d.rival.units.has(foe))
	for coord in RING:
		assert_null(d.grid.get_unit_at(coord))

func test_the_attacker_dying_to_a_counterattack_stops_the_sweep():
	var d := _arc(3, 80.0, 30.0) # Defesa 30: cada alvo revida forte (o revide sai da Defesa do alvo)
	var unit: Unit = d.unit
	var foes: Array = d.foes
	unit.hp = 1.0
	assert_gt(CombatResolver.predict(unit, foes[0], d.grid, 0.75).damage_to_attacker, 1.0, "pré-condição: o primeiro revide o mata")
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid))
	assert_true(unit.hp <= 0.0, "caiu no contra-ataque")
	# O 1º alvo levou o golpe e ganhou o abate (a promoção de veterania o curou de volta); os outros dois seguem intactos.
	assert_eq(foes[0].kills, 1, "quem derrubou o atacante conta o abate")
	assert_eq(foes[1].hp, 80.0, "os demais alvos não são atacados por quem já morreu")
	assert_eq(foes[2].hp, 80.0)
	assert_eq(foes[1].kills + foes[2].kills, 0)
	assert_eq(int(unit.magic_cooldowns[CLEAVE]), 9, "a recarga já tinha sido gravada")

# --- Ação, recarga, independência ---------------------------------------------------------------------------

func test_it_consumes_the_action_and_starts_a_four_turn_cooldown():
	var d := _arc(2)
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid))
	assert_eq(unit.movement_left, 0.0)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, CLEAVE), 4)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, CLEAVE, d.grid), "Em recarga: 4 turno(s).")
	TurnManager.turn_number = 8
	unit.movement_left = unit.unit_data.movement_points
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, CLEAVE), 1)
	TurnManager.turn_number = 9
	assert_true(V2TechniqueRuntime.can_use(unit, CLEAVE, d.grid))

func test_it_costs_no_mana_and_no_gold_and_stores_no_effect():
	var d := _arc(2)
	var me: PlayerData = d.me
	me.gold = 40.0
	me.mana = 10.0
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid))
	assert_eq(me.gold, 40.0)
	assert_eq(me.mana, 10.0)
	assert_false(unit.magic_status.has(CLEAVE))
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "")

func test_the_two_techniques_have_independent_cooldowns_but_share_the_action():
	var d := _arc(2)
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid))
	assert_false(unit.magic_cooldowns.has(POWER), "o Arco não põe o Golpe em recarga")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, POWER, d.grid), "A unidade já agiu neste turno.", "a ação é uma só por turno")
	unit.movement_left = unit.unit_data.movement_points
	assert_true(V2TechniqueRuntime.can_use(unit, POWER, d.grid), "com a ação de volta o Golpe segue livre")

func test_the_cleave_cooldown_survives_the_form_change():
	var d := _arc(1)
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, d.grid))
	unit.apply_form(UnitDatabase.create_unit(SWORDSMAN))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, CLEAVE), 4)

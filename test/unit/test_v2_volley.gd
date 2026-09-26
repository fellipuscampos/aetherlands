extends "res://test/unit/v2_combat_fixture.gd"

## Saraivada (v2_technique_volley, Aetherlands V2 Fase 8): a segunda técnica ATIVA de ataque à distância do Patrulheiro — parte de um alvo PRIMÁRIO à escolha,
## dentro do alcance BÁSICO da unidade (sem o +1 do Disparo Preciso), e atinge também os inimigos a 1 tile dele, no máximo 3 no total, cada um por uma resolução
## de combate normal a 0,70x o Ataque. Anti-unidade. Números (0,70x, 3 alvos, recarga 4) = BALANCE PLACEHOLDER.

## Direções dos vizinhos do primário, em ordem fixa. A quarta ((-1,0), que cai adjacente ao Arqueiro em (0,0)) só entra quando pedida.
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(-1, 0)]
const PRIMARY := Vector2i(2, 0)

## Arqueiro em (0,0), o alvo primário em (2,0) e `count` inimigos secundários ao redor dele (vizinhos do primário). `through` = nível do Patrulheiro.
func _cluster(count: int = 2, hp: float = 40.0, defense: float = 3.0, kind: String = ARCHER, through: int = 6) -> Dictionary:
	var grid := _world()
	var me := _ranger_player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, kind, Vector2i(0, 0))
	var primary := _foe(grid, rival, PRIMARY, hp, defense)
	var others: Array[Unit] = []
	for i in count:
		others.append(_foe(grid, rival, PRIMARY + DIRS[i], hp, defense))
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "primary": primary, "others": others}

func _all(d: Dictionary) -> Array:
	return [d.primary] + (d.others as Array)

# --- Dado ------------------------------------------------------------------------------------------------------------------------

func test_the_technique_has_the_specified_active_volley_baseline():
	var technique := _technique(VOLLEY)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Saraivada")
	assert_eq(technique.doctrine_branch, "ranger")
	assert_eq(technique.activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_true(technique.is_strike() and technique.needs_target())
	assert_eq(technique.strike_multiplier, 0.7)
	assert_eq(technique.strike_targeting, V2DoctrineTechniqueData.StrikeTargeting.TARGET_AND_NEIGHBORS)
	assert_eq(technique.strike_range_mode, V2DoctrineTechniqueData.StrikeRangeMode.ATTACK_RANGE_PLUS)
	assert_eq(technique.strike_range, 0, "alcance BÁSICO, sem bônus")
	assert_eq(technique.strike_splash_radius, 1)
	assert_eq(technique.strike_max_targets, 3)
	assert_eq(technique.cooldown_turns, 4)
	assert_true(technique.consumes_action)

func test_the_volley_is_not_the_warriors_arc_with_more_range_it_starts_from_a_chosen_primary():
	var volley := _technique(VOLLEY)
	var arc := _technique(CLEAVE)
	assert_ne(volley.strike_targeting, arc.strike_targeting)
	assert_true(volley.needs_target(), "tem mira")
	assert_false(arc.needs_target(), "o Arco não tem")
	assert_true(volley.description.contains("alvo à sua escolha"), volley.description)
	assert_true(volley.description.contains("até 3 no total"), volley.description)
	assert_true(volley.description.contains("×0.7"), volley.description)
	assert_eq(V2DoctrineTechniqueDatabase.button_suffix(volley), "×0.7")

func test_the_arc_of_the_warrior_is_untouched_by_the_generalization():
	var arc := _technique(CLEAVE)
	assert_eq(arc.strike_targeting, V2DoctrineTechniqueData.StrikeTargeting.ADJACENT_ENEMIES)
	assert_eq(arc.strike_multiplier, 0.75)
	assert_eq(arc.strike_max_targets, 3)
	assert_true(arc.description.contains("até 3 inimigos adjacentes"))

# --- Elegibilidade ----------------------------------------------------------------------------------------------------------------

func test_it_appears_only_after_n6_and_only_in_the_ranger_branch():
	var grid := _world()
	var me := _player(9, 9, 5)
	var archer := _unit(grid, me, ARCHER, Vector2i(0, 0))
	var shield := _unit(grid, me, SHIELD, Vector2i(0, 2))
	var warrior := _unit(grid, me, WARRIOR, Vector2i(0, -2))
	assert_false(V2TechniqueRuntime.techniques_for_unit(archer).any(func(t): return t.id == VOLLEY), "N5 ainda não")
	assert_eq(V2TechniqueRuntime.unavailable_reason(archer, VOLLEY, grid), "Requer pesquisa: Saraivada.")
	me.v2_research.complete_research("v2_doctrine_ranger_6")
	assert_true(V2TechniqueRuntime.techniques_for_unit(archer).any(func(t): return t.id == VOLLEY))
	assert_false(V2TechniqueRuntime.techniques_for_unit(shield).any(func(t): return t.id == VOLLEY))
	assert_false(V2TechniqueRuntime.techniques_for_unit(warrior).any(func(t): return t.id == VOLLEY))

func test_every_form_and_the_legend_hunter_inherit_it_by_branch():
	var grid := _world()
	var me := _player(0, 0, 9)
	for kind in [ARCHER, HUNTER, MARKSMAN, LEGEND_HUNTER]:
		var unit := _unit(grid, me, kind, _coord_at(grid, Vector2i(0, 0), 1 + [ARCHER, HUNTER, MARKSMAN, LEGEND_HUNTER].find(kind)))
		var ids: Array = V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id)
		assert_eq(ids, [PRECISE, VOLLEY], kind)

# --- Alvo primário e alcance -----------------------------------------------------------------------------------------------------------

func test_the_primary_uses_the_basic_range_without_the_plus_one():
	var d := _cluster(0)
	var unit: Unit = d.unit
	var volley := _technique(VOLLEY)
	var precise := _technique(PRECISE)
	var at_three := _foe(d.grid, d.rival, Vector2i(3, 0))
	assert_true(d.primary in V2TechniqueRuntime.strike_targets(unit, volley, d.grid), "a 2 tiles: alcance básico do Arqueiro")
	assert_false(at_three in V2TechniqueRuntime.strike_targets(unit, volley, d.grid), "a 3 tiles: fora da Saraivada")
	assert_true(at_three in V2TechniqueRuntime.strike_targets(unit, precise, d.grid), "mas dentro do Disparo Preciso (+1)")
	assert_eq(V2TechniqueRuntime.strike_range_of(unit, volley), 2)

func test_the_marksman_volley_reaches_3_tiles_and_the_hunter_2():
	var marksman := _cluster(0, 40.0, 3.0, MARKSMAN, 7)
	var far := _foe(marksman.grid, marksman.rival, Vector2i(3, -1))
	assert_true(far in V2TechniqueRuntime.strike_targets(marksman.unit, _technique(VOLLEY), marksman.grid), "alcance básico 3")
	assert_eq(V2TechniqueRuntime.strike_range_of(marksman.unit, _technique(VOLLEY)), 3)
	var hunter := _cluster(0, 40.0, 3.0, HUNTER, 6)
	assert_eq(V2TechniqueRuntime.strike_range_of(hunter.unit, _technique(VOLLEY)), 2)

func test_no_enemy_in_range_makes_it_unavailable_and_consumes_nothing():
	var grid := _world()
	var me := _ranger_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ARCHER, Vector2i(0, 0))
	_foe(grid, rival, Vector2i(4, 0)) # a 4 tiles
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, VOLLEY, grid), "Nenhum inimigo ao alcance.")
	var movement := unit.movement_left
	assert_false(V2TechniqueRuntime.perform_strike(unit, VOLLEY, null, grid))
	assert_eq(unit.movement_left, movement)
	assert_false(unit.magic_cooldowns.has(VOLLEY))

func test_an_invalid_primary_is_rejected_and_nothing_is_spent():
	var d := _cluster(2)
	var unit: Unit = d.unit
	var out_of_range := _foe(d.grid, d.rival, Vector2i(5, 0))
	var ally := _unit(d.grid, d.me, SHIELD, Vector2i(0, 2))
	var volley := _technique(VOLLEY)
	assert_true(V2TechniqueRuntime.strike_victims(unit, volley, out_of_range, d.grid).is_empty())
	assert_true(V2TechniqueRuntime.strike_victims(unit, volley, ally, d.grid).is_empty())
	assert_true(V2TechniqueRuntime.strike_victims(unit, volley, null, d.grid).is_empty())
	assert_false(V2TechniqueRuntime.perform_strike(unit, VOLLEY, out_of_range, d.grid))
	assert_false(V2TechniqueRuntime.perform_strike(unit, VOLLEY, null, d.grid))
	assert_false(unit.magic_cooldowns.has(VOLLEY))
	for foe in _all(d):
		assert_eq(foe.hp, 40.0)

# --- Um, dois, três alvos ---------------------------------------------------------------------------------------------------------------------

func test_the_primary_is_always_included_and_comes_first_even_when_the_others_are_weaker():
	var d := _cluster(2)
	var others: Array = d.others
	others[0].hp = 6.0
	others[1].hp = 10.0
	var victims := V2TechniqueRuntime.strike_victims(d.unit, _technique(VOLLEY), d.primary, d.grid)
	assert_eq(victims[0], d.primary, "o primário é o primeiro, mesmo a 100% de HP")
	assert_eq(victims.size(), 3)

func test_it_works_with_one_two_and_three_targets_each_at_070_of_the_attack():
	for count in [0, 1, 2]:
		var d := _cluster(count)
		var foes := _all(d)
		var expected := _formula_damage(d.grid, 4.5, 0.7, foes[0])
		assert_almost_eq(expected, 4.5 * 0.7 - 1.5, 0.0001, "0,70 x 4,5 - 3,0/2")
		assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, d.primary, d.grid), "%d secundário(s)" % count)
		for foe in foes:
			assert_almost_eq(40.0 - foe.hp, expected, 0.0001, "cada alvo perde o dano de 0,70x (%d secundários)" % count)
		assert_eq((d.unit as Unit).movement_left, 0.0)
		assert_eq(int((d.unit as Unit).magic_cooldowns[VOLLEY]), 5 + 4)

func test_prediction_and_real_resolution_agree_for_every_target():
	var d := _cluster(2)
	var foes := _all(d)
	var predicted: Array[float] = []
	for foe in foes:
		predicted.append(CombatResolver.predict(d.unit, foe, d.grid, 0.7).damage_to_defender)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, d.primary, d.grid))
	for i in foes.size():
		assert_almost_eq(40.0 - foes[i].hp, predicted[i], 0.0001)

# --- Mais de dois secundários: seleção determinística ---------------------------------------------------------------------------------------------

func test_with_more_secondaries_than_slots_the_lowest_hp_percent_are_hit_and_the_total_is_three():
	var d := _cluster(5)
	var others: Array = d.others
	var hp := [40.0, 12.0, 32.0, 18.0, 24.0] # % : 100, 30, 80, 45, 60
	for i in 5:
		others[i].hp = hp[i]
	var victims := V2TechniqueRuntime.strike_victims(d.unit, _technique(VOLLEY), d.primary, d.grid)
	assert_eq(victims.size(), 3, "o teto é 3 no total, primário incluso")
	assert_eq(victims[0], d.primary)
	assert_eq(victims.slice(1).map(func(u): return u.coord), [others[1].coord, others[3].coord], "os dois de menor HP% (30% e 45%)")
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, d.primary, d.grid))
	assert_eq(others[0].hp, 40.0, "o de 100% ficou de fora")
	assert_eq(others[2].hp, 32.0, "o de 80% ficou de fora")
	assert_eq(others[4].hp, 24.0, "o de 60% ficou de fora")
	assert_lt(others[1].hp, 12.0)
	assert_lt(others[3].hp, 18.0)

func test_ties_are_broken_by_the_lowest_serial_id_not_by_tile_order():
	var grid := _world()
	var me := _ranger_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ARCHER, Vector2i(0, 0))
	var primary := _foe(grid, rival, PRIMARY)
	# Secundários criados na ORDEM INVERSA dos vizinhos: o serial_id cresce enquanto o índice de DIRS decresce.
	var by_dir := {}
	for i in [4, 3, 2, 1, 0]:
		by_dir[i] = _foe(grid, rival, PRIMARY + DIRS[i])
	var victims := V2TechniqueRuntime.strike_victims(unit, _technique(VOLLEY), primary, grid)
	assert_eq(victims.size(), 3)
	assert_eq(victims.slice(1).map(func(u): return u.coord), [PRIMARY + DIRS[4], PRIMARY + DIRS[3]], "HP% igual: valem os menores serial_id (criados primeiro)")
	var serials: Array = victims.slice(1).map(func(u): return u.serial_id)
	assert_true(serials[0] < serials[1])

func test_the_selection_is_stable_across_repeated_calls():
	var d := _cluster(5)
	var first := V2TechniqueRuntime.strike_victims(d.unit, _technique(VOLLEY), d.primary, d.grid).map(func(u): return u.serial_id)
	for i in 5:
		assert_eq(V2TechniqueRuntime.strike_victims(d.unit, _technique(VOLLEY), d.primary, d.grid).map(func(u): return u.serial_id), first)

func test_the_cap_and_the_splash_radius_come_from_the_data():
	var d := _cluster(5)
	var technique := _technique(VOLLEY)
	technique.strike_max_targets = 2
	assert_eq(V2TechniqueRuntime.strike_victims(d.unit, technique, d.primary, d.grid).size(), 2)
	technique.strike_max_targets = 3
	var two_away := _foe(d.grid, d.rival, PRIMARY + Vector2i(2, -1)) # a 2 tiles do primário
	assert_false(two_away in V2TechniqueRuntime.strike_victims(d.unit, technique, d.primary, d.grid))
	technique.strike_splash_radius = 2
	technique.strike_max_targets = 9
	assert_true(two_away in V2TechniqueRuntime.strike_victims(d.unit, technique, d.primary, d.grid), "com o dado em raio 2 ele entra")
	technique.strike_splash_radius = 1
	technique.strike_max_targets = 3

func test_only_the_tiles_adjacent_to_the_primary_count_not_the_ones_next_to_the_archer():
	var d := _cluster(1)
	var beside_archer := _foe(d.grid, d.rival, Vector2i(-1, 0)) # adjacente ao Arqueiro, longe do primário
	var beyond := _foe(d.grid, d.rival, Vector2i(4, 0)) # a 2 tiles do primário
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, d.primary, d.grid))
	assert_eq(beside_archer.hp, 40.0, "fora do raio 1 do primário")
	assert_eq(beyond.hp, 40.0)
	assert_lt((d.others as Array)[0].hp, 40.0)

func test_the_targets_list_shown_to_the_player_is_the_primary_candidates_not_the_victims():
	var d := _cluster(2)
	var candidates := V2TechniqueRuntime.strike_targets(d.unit, _technique(VOLLEY), d.grid)
	assert_true(d.primary in candidates)
	for other in d.others:
		assert_true(other in candidates or HexMetrics.axial_distance(d.unit.coord, other.coord) > 2, "candidatos a primário = todo inimigo ao alcance básico")

# --- Quem nunca é atingido ----------------------------------------------------------------------------------------------------------------------

func test_allies_peaceful_civilizations_and_cities_next_to_the_primary_are_never_hit():
	var d := _cluster(0)
	var peaceful := PlayerData.new(CivilizationData.new())
	_players.append(peaceful)
	var ally := _unit(d.grid, d.me, SHIELD, PRIMARY + DIRS[0])
	var neutral := _foe(d.grid, peaceful, PRIMARY + DIRS[1])
	var enemy_city: City = d.grid.found_city(PRIMARY + DIRS[2], d.rival, "Rival", true)
	var enemy := _foe(d.grid, d.rival, PRIMARY + DIRS[3])
	var ally_hp := ally.hp
	var neutral_hp := neutral.hp
	var city_hp: float = enemy_city.hp
	assert_eq(V2TechniqueRuntime.strike_victims(d.unit, _technique(VOLLEY), d.primary, d.grid), [d.primary, enemy], "só inimigos reais")
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, d.primary, d.grid))
	assert_eq(ally.hp, ally_hp)
	assert_eq(neutral.hp, neutral_hp)
	assert_eq(enemy_city.hp, city_hp, "anti-unidade: cidade intacta")
	assert_lt(enemy.hp, 40.0)

func test_a_neutral_monster_next_to_the_primary_is_hit_by_the_normal_hostility_rule():
	var d := _cluster(1)
	var monster: Unit = (d.others as Array)[0]
	monster.owner_player = null
	assert_true(monster in V2TechniqueRuntime.strike_victims(d.unit, _technique(VOLLEY), d.primary, d.grid))
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, d.primary, d.grid))
	assert_lt(monster.hp, 40.0)

func test_it_never_hits_what_the_normal_attack_could_not_when_the_war_ends():
	var d := _cluster(2)
	d.me.enemies.erase(d.rival)
	d.rival.enemies.erase(d.me)
	assert_true(V2TechniqueRuntime.strike_targets(d.unit, _technique(VOLLEY), d.grid).is_empty())
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, VOLLEY, d.grid), "Nenhum inimigo ao alcance.")

# --- Defesa individual ---------------------------------------------------------------------------------------------------------------------------------

func test_each_target_uses_its_own_defense_wall_and_command_aura():
	var d := _cluster(0)
	var soft := d.primary as Unit
	soft.unit_data.defense = 2.0
	var hard := _foe(d.grid, d.rival, PRIMARY + DIRS[0], 40.0, 9.0)
	var walled := _foe(d.grid, d.rival, PRIMARY + DIRS[1], 40.0, 4.0)
	walled.magic_status[WALL] = TurnManager.turn_number + 2
	_unit(d.grid, d.rival, CHAMPION, PRIMARY + Vector2i(2, 0)) # a aura do Campeão inimigo alcança quem está a <= 2 dele
	var wall: float = 1.0 + _technique(WALL).self_defense_bonus
	var aura: float = 1.0 + UnitDatabase.create_unit(CHAMPION).aura_defense_bonus
	# A aura (raio 2) chega ao primário (distância 2), ao duro (1) e ao com Muralha (2): todos protegidos; calcula cada um.
	var expected_soft := _formula_damage(d.grid, 4.5, 0.7, soft, aura)
	var expected_hard := _formula_damage(d.grid, 4.5, 0.7, hard, aura)
	var expected_walled := _formula_damage(d.grid, 4.5, 0.7, walled, wall * aura)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, soft, d.grid))
	assert_almost_eq(40.0 - soft.hp, expected_soft, 0.0001)
	assert_almost_eq(40.0 - hard.hp, expected_hard, 0.0001)
	assert_almost_eq(40.0 - walled.hp, expected_walled, 0.0001)
	assert_gt(expected_soft, expected_walled, "as contas são diferentes: nada de dano total dividido")

func test_the_command_aura_reaches_only_the_units_inside_it():
	var d := _cluster(1)
	var inside: Unit = d.primary
	var outside: Unit = (d.others as Array)[0]
	_unit(d.grid, d.rival, CHAMPION, PRIMARY + Vector2i(-1, 1) + Vector2i(0, 0)) # perto do primário
	var aura: float = 1.0 + UnitDatabase.create_unit(CHAMPION).aura_defense_bonus
	var champion_coord := PRIMARY + Vector2i(-1, 1)
	var in_range := HexMetrics.axial_distance(champion_coord, outside.coord) <= 2
	var expected_inside := _formula_damage(d.grid, 4.5, 0.7, inside, aura)
	var expected_outside := _formula_damage(d.grid, 4.5, 0.7, outside, aura if in_range else 1.0)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, d.primary, d.grid))
	assert_almost_eq(40.0 - inside.hp, expected_inside, 0.0001)
	assert_almost_eq(40.0 - outside.hp, expected_outside, 0.0001)

# --- XP, abates, revide -------------------------------------------------------------------------------------------------------------------------------------

func test_multiple_kills_count_one_each_for_xp_and_remove_every_victim():
	var d := _cluster(2, 2.0) # HP 2: 3,15 - 1,5 = 1,65 não mata; use dano alto
	var unit: Unit = d.unit
	unit.unit_data.attack = 10.0
	assert_true(V2TechniqueRuntime.perform_strike(unit, VOLLEY, d.primary, d.grid))
	assert_eq(unit.kills, 3, "três abates, um por vítima")
	assert_eq(unit.veterancy_level, Unit._level_for_kills(3), "a veterania segue a regra normal")
	for foe in _all(d):
		assert_false(d.rival.units.has(foe))

func test_the_targets_at_range_two_or_more_never_counterattack_and_an_adjacent_one_does():
	var d := _cluster(0, 60.0, 14.0)
	var adjacent := _foe(d.grid, d.rival, Vector2i(1, 0), 60.0, 14.0) # adjacente ao Arqueiro e ao primário
	var prediction_primary: Dictionary = CombatResolver.predict(d.unit, d.primary, d.grid, 0.7)
	var prediction_adjacent: Dictionary = CombatResolver.predict(d.unit, adjacent, d.grid, 0.7)
	assert_eq(prediction_primary.damage_to_attacker, 0.0, "a distância 2: sem revide")
	assert_gt(prediction_adjacent.damage_to_attacker, 0.0, "adjacente: revide normal")
	var my_hp := (d.unit as Unit).hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, VOLLEY, d.primary, d.grid))
	assert_almost_eq(my_hp - (d.unit as Unit).hp, prediction_adjacent.damage_to_attacker, 0.0001, "só o adjacente revidou")

func test_the_attacker_falling_to_a_counter_stops_the_rest_of_the_volley():
	var grid := _world()
	var me := _ranger_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ARCHER, Vector2i(0, 0))
	var primary := _foe(grid, rival, Vector2i(1, 0), 80.0, 30.0) # o primário É adjacente: revida e mata o Arqueiro de 1 HP
	var second := _foe(grid, rival, Vector2i(2, 0), 80.0, 3.0)
	unit.hp = 1.0
	assert_gt(CombatResolver.predict(unit, primary, grid, 0.7).damage_to_attacker, 1.0, "pré-condição")
	assert_true(V2TechniqueRuntime.perform_strike(unit, VOLLEY, primary, grid))
	assert_true(unit.hp <= 0.0)
	assert_eq(second.hp, 80.0, "o secundário não é atacado por quem já morreu")
	assert_eq(primary.kills, 1, "quem derrubou o atacante conta o abate")

# --- Ação, recarga, independência ------------------------------------------------------------------------------------------------------------------------------

func test_it_consumes_the_action_and_starts_a_four_turn_cooldown_with_no_mana_no_gold_and_no_stored_effect():
	var d := _cluster(2)
	var me: PlayerData = d.me
	me.gold = 40.0
	me.mana = 10.0
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, VOLLEY, d.primary, d.grid))
	assert_eq(unit.movement_left, 0.0)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, VOLLEY), 4)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, VOLLEY, d.grid), "Em recarga: 4 turno(s).")
	assert_eq([me.gold, me.mana], [40.0, 10.0])
	assert_false(unit.magic_status.has(VOLLEY))
	TurnManager.turn_number = 8
	unit.movement_left = unit.unit_data.movement_points
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, VOLLEY), 1)
	TurnManager.turn_number = 9
	assert_true(V2TechniqueRuntime.can_use(unit, VOLLEY, d.grid))

func test_the_two_ranger_techniques_have_independent_cooldowns_but_share_the_action():
	var d := _cluster(1)
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, VOLLEY, d.primary, d.grid))
	assert_false(unit.magic_cooldowns.has(PRECISE))
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, PRECISE, d.grid), "A unidade já agiu neste turno.")
	unit.movement_left = unit.unit_data.movement_points
	assert_true(V2TechniqueRuntime.can_use(unit, PRECISE, d.grid))

func test_the_volley_cooldown_survives_the_form_change():
	var d := _cluster(1)
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, VOLLEY, d.primary, d.grid))
	unit.apply_form(UnitDatabase.create_unit(HUNTER))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, VOLLEY), 4)

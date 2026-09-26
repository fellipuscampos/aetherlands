extends "res://test/unit/v2_combat_fixture.gd"

## Disparo Preciso (v2_technique_precise_shot, Aetherlands V2 Fase 8): a técnica ATIVA de ataque à distância do Patrulheiro — UM alvo à escolha,
## alcance BÁSICO + 1 (por dado, `StrikeRangeMode.ATTACK_RANGE_PLUS`), 1,40x o Ataque, pelo combate normal. Reusa o framework de técnicas de ataque da
## Fase 7 (V2TechniqueRuntime.perform_strike). Números (1,40x, +1, recarga 3) = BALANCE PLACEHOLDER.

## Arqueiro (N3) em (0,0) e um inimigo em guerra a `distance` tiles; `through` = nível do Patrulheiro pesquisado.
func _shot(distance: int = 3, target_hp: float = 40.0, target_def: float = 3.0, kind: String = ARCHER, through: int = 4) -> Dictionary:
	var grid := _world()
	var me := _ranger_player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, kind, Vector2i(0, 0))
	var foe := _foe_at(grid, rival, unit, distance, target_hp, target_def)
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "foe": foe}

# --- Dado ---------------------------------------------------------------------------------------------------------------

func test_the_technique_has_the_specified_active_ranged_baseline():
	var technique := _technique(PRECISE)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Disparo Preciso")
	assert_eq(technique.doctrine_branch, "ranger")
	assert_eq(technique.activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_true(technique.is_strike())
	assert_true(technique.needs_target())
	assert_eq(technique.strike_multiplier, 1.4)
	assert_eq(technique.strike_targeting, V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET)
	assert_eq(technique.strike_range_mode, V2DoctrineTechniqueData.StrikeRangeMode.ATTACK_RANGE_PLUS)
	assert_eq(technique.strike_range, 1, "alcance básico + 1")
	assert_eq(technique.strike_max_targets, 1)
	assert_eq(technique.cooldown_turns, 3)
	assert_true(technique.consumes_action)

func test_it_lives_in_the_same_database_as_the_other_doctrines_techniques():
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(PRECISE)))
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("ranger").map(func(t): return t.id), [PRECISE, VOLLEY])
	assert_true(PRECISE in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	assert_true(_technique(POWER) != null and _technique(WALL) != null, "Golpe Poderoso e Muralha seguem ao lado")

func test_it_is_not_a_stance_nor_a_passive_bonus():
	var technique := _technique(PRECISE)
	assert_false(technique.has_defense_effect())
	assert_false(technique.has_attack_effect())
	assert_false(technique.is_passive())
	assert_false(V2DoctrineTechniqueDatabase.defensive_techniques().has(technique))
	assert_false(V2DoctrineTechniqueDatabase.attack_bonus_techniques().has(technique))

func test_the_description_and_button_suffix_come_from_the_data():
	var technique := _technique(PRECISE)
	assert_true(technique.description.contains("×1.4"), technique.description)
	assert_true(technique.description.contains("alcance básico +1"), technique.description)
	assert_true(technique.description.contains("recarga de 3 turnos"), technique.description)
	assert_eq(V2DoctrineTechniqueDatabase.button_suffix(technique), "×1.4")
	assert_eq(V2DoctrineTechniqueDatabase.range_text(technique), "alcance básico +1")

func test_the_golpe_poderoso_still_reads_as_melee_after_the_generalization():
	var power := _technique(POWER)
	assert_eq(power.strike_range_mode, V2DoctrineTechniqueData.StrikeRangeMode.FIXED)
	assert_eq(power.resolved_range(UnitDatabase.create_unit(MARKSMAN)), 1, "fixo em 1 mesmo com um atirador de alcance 3")
	assert_true(power.description.contains("corpo a corpo"), power.description)

# --- Alcance por dado --------------------------------------------------------------------------------------------------------

func test_the_range_is_the_units_basic_attack_range_plus_one_by_data():
	var technique := _technique(PRECISE)
	var expected := {ARCHER: 3, HUNTER: 3, MARKSMAN: 4, LEGEND_HUNTER: 4}
	for kind in expected:
		assert_eq(technique.resolved_range(UnitDatabase.create_unit(kind)), expected[kind], "%s: alcance básico + 1" % kind)
	var grid := _world()
	var unit := _unit(grid, _ranger_player(4), MARKSMAN, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.strike_range_of(unit, technique), 4, "o Atirador de Elite (alcance 3) passa naturalmente a 4")

func test_a_target_at_range_3_is_valid_for_the_archer_and_at_range_4_is_rejected():
	var d := _shot(3)
	var unit: Unit = d.unit
	var technique := _technique(PRECISE)
	assert_eq(V2TechniqueRuntime.strike_targets(unit, technique, d.grid), [d.foe], "a 3 tiles: alcance básico 2 + 1")
	var too_far := _foe_at(d.grid, d.rival, unit, 4)
	assert_false(too_far in V2TechniqueRuntime.strike_targets(unit, technique, d.grid), "a 4 tiles: fora")
	var hp := too_far.hp
	assert_false(V2TechniqueRuntime.perform_strike(unit, PRECISE, too_far, d.grid), "alvo fora do alcance é rejeitado")
	assert_eq(too_far.hp, hp)
	assert_false(unit.magic_cooldowns.has(PRECISE), "nada foi consumido")
	assert_gt(unit.movement_left, 0.0)

func test_targets_closer_than_the_maximum_range_are_also_valid_including_adjacent():
	var d := _shot(2)
	var adjacent := _foe_at(d.grid, d.rival, d.unit, 1)
	var ids := V2TechniqueRuntime.strike_targets(d.unit, _technique(PRECISE), d.grid)
	assert_true(d.foe in ids and adjacent in ids)

func test_the_marksman_reaches_4_tiles_and_not_5():
	var d := _shot(4, 40.0, 3.0, MARKSMAN, 7)
	var technique := _technique(PRECISE)
	assert_eq(V2TechniqueRuntime.strike_targets(d.unit, technique, d.grid), [d.foe])
	var five := _foe_at(d.grid, d.rival, d.unit, 5)
	assert_false(five in V2TechniqueRuntime.strike_targets(d.unit, technique, d.grid))
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, PRECISE, d.foe, d.grid))

func test_the_range_bonus_and_mode_come_from_the_data_not_from_the_code():
	var d := _shot(3)
	var technique := _technique(PRECISE)
	var original_bonus := technique.strike_range
	technique.strike_range = 2 # alcance básico + 2
	var far := _foe_at(d.grid, d.rival, d.unit, 4)
	assert_true(far in V2TechniqueRuntime.strike_targets(d.unit, technique, d.grid), "com o dado em +2 o Arqueiro chega a 4")
	technique.strike_range = original_bonus
	assert_false(far in V2TechniqueRuntime.strike_targets(d.unit, technique, d.grid))

func test_only_the_tiles_within_reach_are_looked_at_no_global_scan():
	assert_eq(HexMetrics.coords_within(Vector2i(0, 0), 3).size(), 36, "3r(r+1) coordenadas, sem BFS")
	assert_false(Vector2i(0, 0) in HexMetrics.coords_within(Vector2i(0, 0), 3), "sem o próprio centro")
	for coord in HexMetrics.coords_within(Vector2i(2, -1), 4):
		assert_lte(HexMetrics.axial_distance(Vector2i(2, -1), coord), 4)
		assert_gte(HexMetrics.axial_distance(Vector2i(2, -1), coord), 1)

# --- Elegibilidade ------------------------------------------------------------------------------------------------------------

func test_it_appears_only_after_n4():
	var grid := _world()
	var me := _ranger_player(3)
	var unit := _unit(grid, me, ARCHER, Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty(), "N3 não dá técnica")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, PRECISE, grid), "Requer pesquisa: Disparo Preciso.")
	me.v2_research.complete_research("v2_doctrine_ranger_4")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [PRECISE])
	assert_eq(V2TechniqueRuntime.active_techniques_for_unit(unit).size(), 1, "é ativa: ganha botão")

func test_every_form_of_the_ranger_branch_inherits_it_and_nothing_else_does():
	var grid := _world()
	var me := _player(9, 9, 9)
	for kind in [ARCHER, HUNTER, MARKSMAN, LEGEND_HUNTER]:
		var unit := _unit(grid, me, kind, _coord_at(grid, Vector2i(0, 0), 1 + [ARCHER, HUNTER, MARKSMAN, LEGEND_HUNTER].find(kind)))
		assert_true(V2TechniqueRuntime.techniques_for_unit(unit).any(func(t): return t.id == PRECISE), "%s herda o Disparo Preciso" % kind)
	for kind in [SHIELD, CHAMPION, WARRIOR, HERO, "archer", "warrior"]:
		var other := _unit(grid, me, kind, _coord_at(grid, Vector2i(0, 0), 5))
		assert_false(V2TechniqueRuntime.techniques_for_unit(other).any(func(t): return t.id == PRECISE), "%s não" % kind)
	var other_unit := _unit(grid, me, SHIELD, _coord_at(grid, Vector2i(0, 0), 6))
	assert_eq(V2TechniqueRuntime.unavailable_reason(other_unit, PRECISE, grid), "Esta unidade não pertence à linha da Doutrina.")

func test_a_ranger_unit_of_a_civilization_without_the_research_has_nothing():
	var grid := _world()
	var unit := _unit(grid, _player(0, 9, 0), ARCHER, Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty())

# --- Hostilidade -----------------------------------------------------------------------------------------------------------------

func test_allies_peaceful_civilizations_and_cities_are_never_targets():
	var grid := _world()
	var me := _ranger_player(4)
	var rival := _rival_of(me)
	var peaceful := PlayerData.new(CivilizationData.new())
	_players.append(peaceful)
	var unit := _unit(grid, me, ARCHER, Vector2i(0, 0))
	_unit(grid, me, SHIELD, Vector2i(2, 0))
	_foe(grid, peaceful, Vector2i(0, 2))
	assert_not_null(grid.found_city(Vector2i(-2, 0), rival, "Rival", true))
	assert_true(V2TechniqueRuntime.strike_targets(unit, _technique(PRECISE), grid).is_empty())
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, PRECISE, grid), "Nenhum inimigo ao alcance.", "o motivo de uma técnica à distância")
	assert_false(V2TechniqueRuntime.perform_strike(unit, PRECISE, grid.get_unit_at(Vector2i(2, 0)), grid), "aliado não é alvo")

func test_the_melee_reason_text_is_unchanged_for_adjacent_only_techniques():
	var grid := _world()
	var me := _player(6)
	var unit := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, POWER, grid), "Nenhum inimigo adjacente.")

func test_a_neutral_monster_in_range_is_a_valid_target_like_in_a_normal_attack():
	var d := _shot(3)
	var monster: Unit = d.foe
	monster.owner_player = null
	assert_true(monster in V2TechniqueRuntime.strike_targets(d.unit, _technique(PRECISE), d.grid))

func test_an_enemy_out_of_the_owners_vision_cannot_be_targeted_but_the_ai_ignores_fog():
	var d := _shot(3)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var original := GameManager.human_player
	GameManager.human_player = d.me
	d.grid.visibility[foe.coord] = HexGrid.Visibility.EXPLORED # visto antes, não agora
	assert_false(foe in V2TechniqueRuntime.strike_targets(unit, _technique(PRECISE), d.grid), "fora da visão do humano")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, PRECISE, d.grid), "Nenhum inimigo ao alcance.")
	d.grid.visibility[foe.coord] = HexGrid.Visibility.VISIBLE
	assert_true(foe in V2TechniqueRuntime.strike_targets(unit, _technique(PRECISE), d.grid), "visível: ok")
	d.grid.visibility[foe.coord] = HexGrid.Visibility.UNSEEN
	GameManager.human_player = d.rival # a IA (não humana) não usa a neblina do humano
	assert_true(foe in V2TechniqueRuntime.strike_targets(unit, _technique(PRECISE), d.grid), "para quem não é o humano não há restrição")
	GameManager.human_player = original

# --- Resolução -------------------------------------------------------------------------------------------------------------------

func test_the_shot_hits_with_140_percent_of_the_basic_attack():
	var d := _shot(3)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var basic: float = CombatResolver.predict(unit, foe, d.grid).damage_to_defender
	var shot: float = CombatResolver.predict(unit, foe, d.grid, _technique(PRECISE).strike_multiplier).damage_to_defender
	assert_eq(basic, _formula_damage(d.grid, 4.5, 1.0, foe))
	assert_eq(shot, _formula_damage(d.grid, 4.5, 1.4, foe), "4,5 x 1,4 - 3,0/2")
	assert_gt(shot, basic)

func test_prediction_and_real_resolution_agree_and_a_ranged_shot_takes_no_counterattack():
	var d := _shot(3, 60.0, 14.0) # Defesa alta: um alvo em melee revidaria
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var prediction: Dictionary = CombatResolver.predict(unit, foe, d.grid, 1.4)
	assert_eq(prediction.damage_to_attacker, 0.0)
	var foe_hp := foe.hp
	var my_hp := unit.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, PRECISE, foe, d.grid))
	assert_almost_eq(foe_hp - foe.hp, prediction.damage_to_defender, 0.0001)
	assert_eq(unit.hp, my_hp, "sem revide a distância")

func test_it_consumes_the_action_and_starts_a_three_turn_cooldown():
	var d := _shot(3)
	var unit: Unit = d.unit
	assert_gt(unit.movement_left, 0.0)
	assert_true(V2TechniqueRuntime.perform_strike(unit, PRECISE, d.foe, d.grid))
	assert_eq(unit.movement_left, 0.0, "consumiu a ação e zerou o movimento")
	assert_eq(int(unit.magic_cooldowns[PRECISE]), 5 + 3)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, PRECISE, d.grid), "Em recarga: 3 turno(s).")
	unit.movement_left = unit.unit_data.movement_points
	TurnManager.turn_number = 8
	assert_true(V2TechniqueRuntime.can_use(unit, PRECISE, d.grid), "volta no turno T+3")

func test_it_costs_no_mana_and_no_gold_and_stores_no_effect():
	var d := _shot(3)
	var me: PlayerData = d.me
	me.gold = 30.0
	me.mana = 12.0
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, PRECISE, d.foe, d.grid))
	assert_eq([me.gold, me.mana], [30.0, 12.0])
	assert_false(unit.magic_status.has(PRECISE))
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "")

func test_a_failed_use_changes_nothing():
	var d := _shot(3)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var hp := foe.hp
	assert_false(V2TechniqueRuntime.perform_strike(unit, PRECISE, null, d.grid), "sem alvo")
	assert_false(V2TechniqueRuntime.perform_strike(unit, PRECISE, unit, d.grid), "não pode ser ela mesma")
	assert_false(V2TechniqueRuntime.perform_strike(unit, POWER, foe, d.grid), "outra técnica")
	assert_eq(foe.hp, hp)
	assert_false(unit.magic_cooldowns.has(PRECISE))
	assert_gt(unit.movement_left, 0.0)

func test_the_defense_chain_of_the_target_applies_wall_and_command_aura():
	var d := _shot(3)
	var foe: Unit = d.foe
	foe.magic_status[WALL] = TurnManager.turn_number + 2
	_unit(d.grid, d.rival, CHAMPION, _coord_at(d.grid, foe.coord, 1)) # aura do Campeão inimigo perto do alvo
	var wall: float = 1.0 + _technique(WALL).self_defense_bonus
	var aura: float = 1.0 + UnitDatabase.create_unit(CHAMPION).aura_defense_bonus
	var expected := _formula_damage(d.grid, 4.5, 1.4, foe, wall * aura)
	var hp := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, PRECISE, foe, d.grid))
	assert_almost_eq(hp - foe.hp, expected, 0.0001)

func test_a_kill_counts_once_for_xp_and_removes_the_target():
	var d := _shot(3, 4.0, 3.0)
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, PRECISE, d.foe, d.grid))
	assert_eq(unit.kills, 1)
	assert_false(d.rival.units.has(d.foe))
	assert_eq(unit.movement_left, 0.0)

func test_a_shot_at_an_adjacent_target_takes_the_normal_melee_counter():
	var d := _shot(1, 60.0, 14.0)
	var prediction: Dictionary = CombatResolver.predict(d.unit, d.foe, d.grid, 1.4)
	assert_gt(prediction.damage_to_attacker, 0.0)
	var hp := (d.unit as Unit).hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, PRECISE, d.foe, d.grid))
	assert_almost_eq(hp - (d.unit as Unit).hp, prediction.damage_to_attacker, 0.0001)

func test_the_multiplier_comes_from_the_data():
	var d := _shot(3)
	var technique := _technique(PRECISE)
	var original := technique.strike_multiplier
	technique.strike_multiplier = 2.0
	var hp := (d.foe as Unit).hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, PRECISE, d.foe, d.grid))
	assert_almost_eq(hp - (d.foe as Unit).hp, _formula_damage(d.grid, 4.5, 2.0, d.foe), 0.0001)
	technique.strike_multiplier = original

func test_the_cooldown_lives_on_the_unit_and_survives_the_form_change():
	var d := _shot(3)
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, PRECISE, d.foe, d.grid))
	unit.apply_form(UnitDatabase.create_unit(HUNTER))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, PRECISE), 3)
	assert_true(V2TechniqueRuntime.cooldown_lines(unit).any(func(l): return l.begins_with("Disparo Preciso")))

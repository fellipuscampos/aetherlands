extends "res://test/unit/v2_combat_fixture.gd"

## Ataque Furtivo (v2_technique_sneak_attack, Aetherlands V2 Fase 10): a primeira técnica ATIVA de ataque que declara `strike_defense_penetration`
## (40% da Defesa do alvo ignorada NAQUELE golpe) e `strike_prevents_counterattack` (sem revide daquela resolução) — ambos campos genéricos do
## framework de técnicas, aplicados dentro da MESMA fórmula de combate (CombatResolver.predict/resolve), nunca um `if id`. Números (1,35x, 40%,
## recarga 3) = BALANCE PLACEHOLDER — os testes leem os valores do dado quando o assunto é a lógica e fixam os canônicos só no teste de baseline.

## Ladino (N4) em (0,0) e um inimigo em guerra no vizinho (1,0).
func _duel(target_hp: float = 40.0, target_def: float = 3.0, through: int = 4) -> Dictionary:
	var grid := _world()
	var me := _rogue_player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var foe := _foe(grid, rival, Vector2i(1, 0), target_hp, target_def)
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "foe": foe}

# --- Dado ----------------------------------------------------------------------------------------------------

func test_the_technique_has_the_specified_active_strike_baseline():
	var technique := _technique(SNEAK_ATTACK)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Ataque Furtivo", "o nome vem do nó de pesquisa")
	assert_eq(technique.doctrine_branch, "rogue")
	assert_eq(technique.activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_true(technique.is_strike())
	assert_eq(technique.strike_multiplier, 1.35)
	assert_eq(technique.strike_targeting, V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET)
	assert_eq(technique.strike_max_targets, 1)
	assert_eq(technique.strike_range, 1, "adjacente")
	assert_eq(technique.strike_defense_penetration, 0.4)
	assert_true(technique.strike_prevents_counterattack)
	assert_eq(technique.cooldown_turns, 3)
	assert_true(technique.consumes_action)
	assert_false(technique.repositions(), "não é a Carga")
	assert_false(technique.is_relocation())

func test_it_is_registered_in_the_same_database_as_the_other_doctrines():
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(SNEAK_ATTACK)))
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("rogue").size(), 2, "Ataque Furtivo + Desmantelar")
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(POWER)), "as do Guerreiro continuam ao lado")
	assert_true(SNEAK_ATTACK in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	var technique := _technique(SNEAK_ATTACK)
	assert_false(technique.has_defense_effect() or technique.has_attack_effect())
	assert_false(V2DoctrineTechniqueDatabase.defensive_techniques().has(technique))
	assert_false(technique.is_passive())

func test_the_description_mentions_the_penetration_and_the_lack_of_counterattack():
	var technique := _technique(SNEAK_ATTACK)
	assert_true(technique.description.contains("×1.35"), technique.description)
	assert_true(technique.description.contains("recarga de 3 turnos"), technique.description)
	assert_true(technique.description.contains("Ignora 40% da Defesa do alvo."), technique.description)
	assert_true(technique.description.contains("O alvo não revida este golpe."), technique.description)
	assert_eq(V2DoctrineTechniqueDatabase.button_suffix(technique), "×1.35")

func test_the_multiplier_and_penetration_come_from_the_data_not_from_the_code():
	var d := _duel()
	var technique := _technique(SNEAK_ATTACK)
	var original_mult := technique.strike_multiplier
	var original_pen := technique.strike_defense_penetration
	technique.strike_multiplier = 2.0
	technique.strike_defense_penetration = 0.9
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	technique.strike_multiplier = original_mult
	technique.strike_defense_penetration = original_pen
	assert_almost_eq(before - d.foe.hp, _formula_damage(d.grid, 4.5, 2.0, d.foe, 1.0, 0.9), 0.0001)

# --- Disponibilidade por nível e por unidade ----------------------------------------------------------------------------------

func test_it_appears_only_after_n4():
	var grid := _world()
	var me := _rogue_player(3)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	_foe(grid, rival, Vector2i(1, 0))
	assert_false(_technique(SNEAK_ATTACK) in V2TechniqueRuntime.techniques_for_unit(unit), "antes do N4")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, SNEAK_ATTACK, grid), "Requer pesquisa: Ataque Furtivo.")
	me.v2_research.complete_research("v2_doctrine_rogue_4")
	assert_true(_technique(SNEAK_ATTACK) in V2TechniqueRuntime.techniques_for_unit(unit))
	assert_true(V2TechniqueRuntime.can_use(unit, SNEAK_ATTACK, grid))

func test_every_form_of_the_line_and_the_legend_inherit_it_no_other_branch_has_it():
	var grid := _world()
	var me := _rogue_player(9, 9, 9, 9)
	var index := 0
	for kind in [ROGUE, SABOTEUR, ASSASSIN, SHADOW_MASTER]:
		var unit := _unit(grid, me, kind, Vector2i(index, 3))
		index += 1
		assert_true(_technique(SNEAK_ATTACK) in V2TechniqueRuntime.techniques_for_unit(unit), "%s herda o Ataque Furtivo" % kind)
		assert_true(_technique(DISMANTLE) in V2TechniqueRuntime.techniques_for_unit(unit), "%s herda Desmantelar" % kind)
	for kind in [WARRIOR, SHIELD, ARCHER, MASTER, SENTINEL, MARKSMAN, CAVALIER]:
		var other := _unit(grid, me, kind, Vector2i(index - 4, -3))
		index += 1
		assert_false(_technique(SNEAK_ATTACK) in V2TechniqueRuntime.techniques_for_unit(other), "%s não tem o Ataque Furtivo" % kind)
		assert_eq(V2TechniqueRuntime.unavailable_reason(other, SNEAK_ATTACK, grid), "Esta unidade não pertence à linha da Doutrina.")

func test_a_rogue_of_a_civilization_without_the_research_has_nothing():
	var grid := _world()
	var me := _rogue_player(3)
	var other := _rogue_player(9)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty(), "a pesquisa é por civilização")
	assert_false(V2TechniqueRuntime.techniques_for_unit(_unit(grid, other, ROGUE, Vector2i(2, 2))).is_empty())

# --- Alvo: adjacente e hostil ---------------------------------------------------------------------------------------------------

func test_the_target_must_be_adjacent_and_hostile_no_enemy_next_to_it_means_unavailable():
	var grid := _world()
	var me := _rogue_player(4)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, SNEAK_ATTACK, grid), "Nenhum inimigo adjacente.")

func test_a_target_two_tiles_away_is_out_of_reach():
	var d := _duel()
	var far := _foe(d.grid, d.rival, Vector2i(2, 0))
	assert_false(far in V2TechniqueRuntime.strike_targets(d.unit, _technique(SNEAK_ATTACK), d.grid))
	assert_true(d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(SNEAK_ATTACK), d.grid))

func test_allies_civilizations_at_peace_and_cities_are_never_targets():
	var d := _duel()
	var unit: Unit = d.unit
	var me: PlayerData = d.me
	var friend := _unit(d.grid, me, WARRIOR, Vector2i(-1, 0))
	assert_false(friend in V2TechniqueRuntime.strike_targets(unit, _technique(SNEAK_ATTACK), d.grid), "aliado")
	var neutral_civ := PlayerData.new(CivilizationData.new())
	_players.append(neutral_civ)
	var peaceful := _foe(d.grid, neutral_civ, Vector2i(0, 1))
	assert_false(peaceful in V2TechniqueRuntime.strike_targets(unit, _technique(SNEAK_ATTACK), d.grid), "civilização em paz")
	d.foe.owner_player = me
	assert_true(V2TechniqueRuntime.strike_targets(unit, _technique(SNEAK_ATTACK), d.grid).is_empty(), "mesmo dono")

func test_the_hostility_rule_is_the_one_of_the_normal_attack_including_neutral_monsters():
	var d := _duel()
	d.foe.owner_player = null
	assert_true(d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(SNEAK_ATTACK), d.grid))
	assert_eq(CombatResolver.can_attack_unit(d.unit, d.foe, d.grid), d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(SNEAK_ATTACK), d.grid))

# --- Multiplicador, penetração de Defesa e resolução -------------------------------------------------------------------------------

func test_the_strike_hits_with_135_percent_of_the_basic_attack_and_40_percent_defense_penetration():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var basic: float = CombatResolver.predict(unit, foe, d.grid).damage_to_defender
	var furtive: float = CombatResolver.predict(unit, foe, d.grid, 1.35, 0.4).damage_to_defender
	assert_eq(basic, _formula_damage(d.grid, 4.5, 1.0, foe), "ataque comum: 4,5 - 3,0/2")
	assert_eq(furtive, _formula_damage(d.grid, 4.5, 1.35, foe, 1.0, 0.4), "furtivo: 4,5 x 1,35 - (3,0 x 0,6)/2")
	assert_gt(furtive, basic)
	assert_eq(CombatResolver.predict(unit, foe, d.grid, 1.0, 0.0).damage_to_defender, basic, "1.0/0.0 é o ataque comum")

func test_penetration_reduces_only_the_defense_contribution_never_a_flat_correction_after_the_fact():
	var d := _duel(40.0, 10.0) # Defesa alta, pra a penetração fazer diferença clara
	var predicted: float = CombatResolver.predict(d.unit, d.foe, d.grid, 1.35, 0.4).damage_to_defender
	var manual := maxf(1.0, 4.5 * 1.35 - (10.0 * 0.6) * CombatResolver.DEFENSE_MITIGATION_FACTOR)
	assert_almost_eq(predicted, manual, 0.0001, "só 60% da Defesa entra na MESMA fórmula, não uma correção separada")

func test_prediction_and_real_resolution_agree_hp_loss_equals_the_predicted_damage():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var predicted: float = CombatResolver.predict(unit, foe, d.grid, 1.35, 0.4, true).damage_to_defender
	var before := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, foe, d.grid))
	assert_almost_eq(before - foe.hp, predicted, 0.0001)

func test_it_consumes_the_action_and_zeroes_the_remaining_movement():
	var d := _duel()
	var unit: Unit = d.unit
	assert_gt(unit.movement_left, 0.0)
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_eq(unit.movement_left, 0.0)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, SNEAK_ATTACK, d.grid), "Em recarga: 3 turno(s).", "a recarga tem prioridade sobre a ação já gasta")
	unit.movement_left = 0.0
	unit.magic_cooldowns.erase(SNEAK_ATTACK)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, SNEAK_ATTACK, d.grid), "A unidade já agiu neste turno.")

func test_the_cooldown_is_three_turns_counting_the_turn_of_use():
	var d := _duel()
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_eq(int(unit.magic_cooldowns[SNEAK_ATTACK]), 5 + 3)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, SNEAK_ATTACK), 3)
	unit.movement_left = unit.unit_data.movement_points
	assert_false(V2TechniqueRuntime.can_use(unit, SNEAK_ATTACK, d.grid))
	TurnManager.turn_number = 7
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, SNEAK_ATTACK), 1)
	TurnManager.turn_number = 8
	assert_true(V2TechniqueRuntime.can_use(unit, SNEAK_ATTACK, d.grid), "volta no turno T+3")

func test_it_costs_no_mana_and_no_gold():
	var d := _duel()
	d.me.gold = 50.0
	d.me.mana = 20.0
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_eq(d.me.gold, 50.0)
	assert_eq(d.me.mana, 20.0)

func test_no_effect_is_stored_only_the_cooldown_so_it_never_blocks_an_upgrade_or_shows_as_active():
	var d := _duel()
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_true(unit.magic_status.get(SNEAK_ATTACK, null) == null, "sem magic_status")
	assert_false(V2TechniqueRuntime.is_active(unit, SNEAK_ATTACK))
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "")
	assert_true(V2TechniqueRuntime.status_lines(unit).is_empty())
	assert_true(V2TechniqueRuntime.cooldown_lines(unit).any(func(l): return l.begins_with("Ataque Furtivo")))

func test_activate_refuses_strike_techniques_they_need_a_target():
	var d := _duel()
	var unit: Unit = d.unit
	assert_false(V2TechniqueRuntime.activate(unit, SNEAK_ATTACK))
	assert_eq(int(unit.magic_cooldowns.get(SNEAK_ATTACK, 0)), 0)
	assert_gt(unit.movement_left, 0.0)

func test_esc_cancels_without_moving_or_consuming_anything():
	var d := _duel()
	var unit: Unit = d.unit
	var original_grid := GameManager.hex_grid
	var original_human := GameManager.human_player
	GameManager.hex_grid = d.grid
	GameManager.human_player = d.me
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(SNEAK_ATTACK)
	assert_eq(SelectionManager.technique_targeting_id, SNEAK_ATTACK)
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_eq(unit.movement_left, unit.unit_data.movement_points)
	assert_false(unit.magic_cooldowns.has(SNEAK_ATTACK))
	assert_eq(d.foe.hp, 40.0)
	SelectionManager.reset()
	GameManager.hex_grid = original_grid
	GameManager.human_player = original_human

func test_a_failed_use_changes_nothing():
	var d := _duel()
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var far := _foe(d.grid, d.rival, Vector2i(3, 0))
	var hp := foe.hp
	var movement := unit.movement_left
	assert_false(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, null, d.grid), "sem alvo")
	assert_false(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, far, d.grid), "alvo fora do alcance")
	assert_false(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, unit, d.grid), "não pode ser ela mesma")
	assert_false(V2TechniqueRuntime.perform_strike(unit, "v2_technique_shield_wall", foe, d.grid), "não é técnica de ataque")
	assert_false(V2TechniqueRuntime.perform_strike(unit, "v2_inexistente", foe, d.grid))
	assert_eq(foe.hp, hp)
	assert_eq(unit.movement_left, movement)
	assert_false(unit.magic_cooldowns.has(SNEAK_ATTACK))

# --- Sem revide (genérico, aplicado ao Ataque Furtivo) -----------------------------------------------------------------------------

func test_a_surviving_target_never_counterattacks_this_strike():
	var d := _duel(60.0, 14.0) # Defesa alta: um ataque comum geraria revide
	var basic_prediction: Dictionary = CombatResolver.predict(d.unit, d.foe, d.grid)
	assert_gt(basic_prediction.damage_to_attacker, 0.0, "pré-condição: um ataque comum revidaria")
	var my_hp: float = d.unit.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_eq(d.unit.hp, my_hp, "sem revide neste golpe")

func test_a_surviving_target_stays_completely_normal_afterwards_no_status_full_action_next_turn():
	var d := _duel(60.0, 14.0)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_true(d.foe.hp > 0.0, "pré-condição: sobreviveu")
	assert_true(d.foe.magic_status.is_empty(), "nenhum status ficou no alvo")
	assert_eq(d.foe.movement_left, d.foe.unit_data.movement_points, "o alvo pode agir normalmente no turno dele")
	# no turno seguinte o alvo revida normalmente contra um ataque comum de terceiros
	var other_attacker := _unit(d.grid, d.me, WARRIOR, Vector2i(2, 0))
	var prediction: Dictionary = CombatResolver.predict(other_attacker, d.foe, d.grid)
	assert_gt(prediction.damage_to_attacker, 0.0, "revide normal restaurado")

func test_a_ranged_target_also_does_not_counterattack_this_strike_same_as_it_normally_would_not():
	var grid := _world()
	var me := _rogue_player(4)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var archer_data := UnitDatabase.create_unit("archer")
	archer_data.defense = 14.0
	var archer := grid.spawn_unit(Vector2i(1, 0), archer_data, rival)
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, archer, grid))
	assert_eq(unit.hp, unit.unit_data.max_hp)

func test_the_next_technique_used_normally_allows_counterattack_again():
	var d := _duel(60.0, 14.0)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	var my_hp_after_sneak: float = d.unit.hp
	d.unit.movement_left = d.unit.unit_data.movement_points
	d.unit.magic_cooldowns.erase(SNEAK_ATTACK)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid)) # de novo, ainda sem revide
	assert_eq(d.unit.hp, my_hp_after_sneak)
	# um ATAQUE COMUM contra o mesmo alvo de Defesa alta revida normalmente (nada ficou "desligado" globalmente)
	d.unit.movement_left = d.unit.unit_data.movement_points
	var before_common: float = d.unit.hp
	CombatResolver.resolve(d.unit, d.foe, d.grid)
	assert_lt(d.unit.hp, before_common, "revide restaurado no ataque comum")

func test_predict_reports_zero_damage_to_attacker_and_attacker_never_dies_from_this_strike():
	var d := _duel(200.0, 40.0) # Defesa altíssima: sem a supressão o revide mataria o Ladino
	d.unit.hp = 1.0
	var prediction: Dictionary = CombatResolver.predict(d.unit, d.foe, d.grid, 1.35, 0.4, true)
	assert_eq(prediction.damage_to_attacker, 0.0)
	assert_false(prediction.attacker_dies)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_gt(d.unit.hp, 0.0, "não morre no revide suprimido")

# --- A cadeia normal de combate segue valendo -------------------------------------------------------------------------------------

func test_terrain_defense_of_the_target_tile_applies():
	var d := _duel()
	_set_terrain(d.grid, Vector2i(1, 0), HexTileData.TerrainType.HILLS)
	assert_gt(d.grid.get_tile(Vector2i(1, 0)).defense_bonus, 0.0, "pré-condição: colina defende")
	var expected := _formula_damage(d.grid, 4.5, 1.35, d.foe, 1.0, 0.4)
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_almost_eq(before - d.foe.hp, expected, 0.0001)

func test_a_shield_wall_on_the_target_reduces_the_damage_penetration_applies_on_top():
	var d := _duel()
	d.foe.magic_status[WALL] = TurnManager.turn_number + 2
	var wall_bonus: float = 1.0 + _technique(WALL).self_defense_bonus
	var expected := _formula_damage(d.grid, 4.5, 1.35, d.foe, wall_bonus, 0.4)
	assert_lt(expected, _formula_damage(d.grid, 4.5, 1.35, d.foe, 1.0, 0.4), "a Muralha ainda ajuda, mesmo com a penetração")
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_almost_eq(before - d.foe.hp, expected, 0.0001, "mesma cadeia de defesa do ataque normal")

func test_a_kill_counts_once_for_xp_and_removes_the_target():
	var d := _duel(4.0, 3.0)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var rival: PlayerData = d.rival
	assert_eq(unit.kills, 0)
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, foe, d.grid))
	assert_eq(unit.kills, 1, "um abate, contado uma vez")
	assert_false(rival.units.has(foe), "o alvo saiu do jogo")
	assert_null(d.grid.get_unit_at(Vector2i(1, 0)))

func test_the_defenders_aura_from_a_command_champion_also_counts():
	var d := _duel()
	_unit(d.grid, d.rival, CHAMPION, Vector2i(2, 0)) # Comando Defensivo do inimigo: +20% Defesa ao aliado adjacente
	var aura: float = 1.0 + UnitDatabase.create_unit(CHAMPION).aura_defense_bonus
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, SNEAK_ATTACK, d.foe, d.grid))
	assert_almost_eq(before - d.foe.hp, _formula_damage(d.grid, 4.5, 1.35, d.foe, aura, 0.4), 0.0001)

func test_the_existing_strike_techniques_keep_zero_penetration_and_normal_counterattack():
	for id in [POWER, "v2_technique_cleave", PRECISE, VOLLEY, CHARGE]:
		var technique := _technique(id)
		assert_eq(technique.strike_defense_penetration, 0.0, id)
		assert_false(technique.strike_prevents_counterattack, id)

func test_no_unit_id_or_technique_id_of_the_rogue_appears_in_the_generic_movement_and_combat_code():
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/data/V2DoctrineTechniqueData.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["technique_sneak_attack", "technique_dismantle", "unit_rogue", "unit_saboteur", "unit_assassin", "shadow_master"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])

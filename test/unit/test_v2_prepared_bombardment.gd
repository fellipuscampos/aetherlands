extends "res://test/unit/v2_combat_fixture.gd"

## Bombardeio Preparado (v2_technique_prepared_bombardment, Aetherlands V2 Fase 11): a primeira Técnica ATIVA de ataque com `target_mode CITY`
## (generalização do framework de mira — UNIT/TILE/CITY) e com `strike_requires_undisturbed` (exige que a unidade não tenha se movido neste
## turno, derivado de movement_left == movement_points — nada salvo). O Colosso de Cerco ignora ESSE requisito por dado
## (UnitData.ignores_technique_stationary_requirement — Artilharia Andante), sem ganhar ação extra. Números (1,50x, alcance +1, recarga 4) =
## BALANCE PLACEHOLDER.

func _bombard_setup(through: int = 6) -> Dictionary:
	var grid := _world()
	var me := _siege_player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, CATAPULT, Vector2i(0, 0))
	var city := _enemy_city(grid, rival, Vector2i(3, 0)) # alcance básico (2) + 1 = 3
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "city": city}

# --- Dado --------------------------------------------------------------------------------------------------------------------

func test_the_technique_has_the_specified_city_strike_baseline():
	var technique := _technique(PREPARED_BOMBARDMENT)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Bombardeio Preparado")
	assert_eq(technique.doctrine_branch, "siege")
	assert_eq(technique.activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_true(technique.is_strike())
	assert_true(technique.is_city_strike())
	assert_eq(technique.target_mode, V2DoctrineTechniqueData.TargetMode.CITY)
	assert_eq(technique.strike_multiplier, 1.5)
	assert_eq(technique.strike_range_mode, V2DoctrineTechniqueData.StrikeRangeMode.ATTACK_RANGE_PLUS)
	assert_eq(technique.strike_range, 1, "alcance básico + 1")
	assert_true(technique.strike_requires_undisturbed)
	assert_eq(technique.cooldown_turns, 4)
	assert_true(technique.consumes_action)
	assert_false(technique.repositions(), "não é a Carga")
	assert_false(technique.is_relocation())
	assert_true(technique.needs_target(), "sempre com mira")

func test_it_is_registered_next_to_demolition_ammo():
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(PREPARED_BOMBARDMENT)))
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("siege").size(), 2, "Munição Demolidora + Bombardeio Preparado")
	assert_true(PREPARED_BOMBARDMENT in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	assert_false(_technique(PREPARED_BOMBARDMENT).is_passive())

func test_the_description_mentions_the_multiplier_the_range_the_requirement_and_the_cooldown():
	var technique := _technique(PREPARED_BOMBARDMENT)
	assert_true(technique.description.contains("×1.5"), technique.description)
	assert_true(technique.description.contains("cidade ou fortificação"), technique.description)
	assert_true(technique.description.contains("alcance básico +1"), technique.description)
	assert_true(technique.description.contains("Exige que a unidade não tenha se movido neste turno."), technique.description)
	assert_true(technique.description.contains("recarga de 4 turnos"), technique.description)
	assert_eq(V2DoctrineTechniqueDatabase.button_suffix(technique), "×1.5")

# --- Disponibilidade por nível e por unidade ----------------------------------------------------------------------------------

func test_it_appears_only_after_n6():
	var d := _bombard_setup(5)
	assert_false(_technique(PREPARED_BOMBARDMENT) in V2TechniqueRuntime.techniques_for_unit(d.unit), "antes do N6")
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, PREPARED_BOMBARDMENT, d.grid), "Requer pesquisa: Bombardeio Preparado.")
	d.me.v2_research.complete_research("v2_doctrine_siege_6")
	assert_true(_technique(PREPARED_BOMBARDMENT) in V2TechniqueRuntime.techniques_for_unit(d.unit))

func test_every_form_of_the_line_and_the_legend_inherit_it_no_other_branch_has_it():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var index := 0
	for kind in [CATAPULT, TREBUCHET, BOMBARD, COLOSSUS]:
		var unit := _unit(grid, me, kind, Vector2i(index, 3))
		index += 1
		assert_true(_technique(PREPARED_BOMBARDMENT) in V2TechniqueRuntime.techniques_for_unit(unit), "%s herda o Bombardeio" % kind)
		assert_true(_technique(DEMOLITION_AMMO) in V2TechniqueRuntime.techniques_for_unit(unit), "%s herda Munição" % kind)
	for kind in [WARRIOR, SHIELD, ARCHER, ROGUE, CAVALIER]:
		var other := _unit(grid, me, kind, Vector2i(index - 4, -3))
		index += 1
		assert_false(_technique(PREPARED_BOMBARDMENT) in V2TechniqueRuntime.techniques_for_unit(other), kind)

# --- Alvo: só cidade/fortificação hostil ----------------------------------------------------------------------------------------

func test_units_and_monsters_are_never_targets_only_city_or_fortification():
	var d := _bombard_setup()
	var foe := _foe(d.grid, d.rival, Vector2i(1, 0))
	assert_true(V2TechniqueRuntime.city_strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid).has(d.city))
	assert_false(foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid), "guardado é sempre vazio pra CITY")
	assert_eq(V2TechniqueRuntime.target_coords(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid), [d.city.coord])

func test_own_city_and_allied_city_at_peace_are_never_targets():
	var d := _bombard_setup()
	var own_city := _enemy_city(d.grid, d.me, Vector2i(-2, 0)) # "enemy_city" só descreve como é criada; aqui é a PRÓPRIA
	assert_false(own_city in V2TechniqueRuntime.city_strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid), "cidade própria")
	var neutral_civ := PlayerData.new(CivilizationData.new())
	_players.append(neutral_civ)
	var peaceful_city := _enemy_city(d.grid, neutral_civ, Vector2i(0, -3))
	assert_false(peaceful_city in V2TechniqueRuntime.city_strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid), "cidade em paz")

func test_the_hostility_rule_matches_the_normal_attack_against_a_city():
	var d := _bombard_setup()
	assert_true(CombatResolver.can_attack_city(d.unit, d.city))
	assert_true(d.city in V2TechniqueRuntime.city_strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid))
	d.city.owner_player = d.me
	assert_false(CombatResolver.can_attack_city(d.unit, d.city))
	assert_false(d.city in V2TechniqueRuntime.city_strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid))

func test_range_is_basic_range_plus_one_catapult_reaches_3_trebuchet_and_colossus_reach_4():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var rival := _rival_of(me)
	# Cada unidade num canto próprio do grid, com a própria cidade-alvo a distância EXATA — sem colisão de tile nem matemática de distância manual.
	var catapult := _unit(grid, me, CATAPULT, Vector2i(0, 0))
	var near_city := _enemy_city(grid, rival, _coord_at(grid, catapult.coord, 3))
	var far_from_catapult := _enemy_city(grid, rival, _coord_at(grid, catapult.coord, 4))
	assert_true(near_city in V2TechniqueRuntime.city_strike_targets(catapult, _technique(PREPARED_BOMBARDMENT), grid), "Catapulta alcança 3 (2+1)")
	assert_false(far_from_catapult in V2TechniqueRuntime.city_strike_targets(catapult, _technique(PREPARED_BOMBARDMENT), grid), "fora do alcance da Catapulta")

	var trebuchet := _unit(grid, me, TREBUCHET, Vector2i(-6, 6))
	var trebuchet_target := _enemy_city(grid, rival, _coord_at(grid, trebuchet.coord, 4))
	assert_true(trebuchet_target in V2TechniqueRuntime.city_strike_targets(trebuchet, _technique(PREPARED_BOMBARDMENT), grid), "Trebuchet alcança 4 (3+1)")

	var colossus := _unit(grid, me, COLOSSUS, Vector2i(6, -6))
	var colossus_target := _enemy_city(grid, rival, _coord_at(grid, colossus.coord, 4))
	assert_true(colossus_target in V2TechniqueRuntime.city_strike_targets(colossus, _technique(PREPARED_BOMBARDMENT), grid), "Colosso alcança 4 (3+1) também")

func test_no_hostile_city_in_range_gives_the_specific_reason():
	var grid := _world()
	var me := _siege_player(6)
	var unit := _unit(grid, me, CATAPULT, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, PREPARED_BOMBARDMENT, grid), "Nenhuma cidade hostil ao alcance.")

# --- Requisito de preparação: derivado de movement_left, não de um boolean --------------------------------------------------------

func test_full_movement_can_prepare_partial_movement_cannot_zero_movement_shows_already_acted():
	var d := _bombard_setup()
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.can_use(unit, PREPARED_BOMBARDMENT, d.grid), "movimento cheio: pode")
	unit.movement_left = unit.unit_data.movement_points - 0.5 # gastou uma parte
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, PREPARED_BOMBARDMENT, d.grid), "Bombardeio Preparado exige que a unidade não tenha se movido neste turno.")
	unit.movement_left = 0.0 # gastou tudo: motivo mais fundamental tem prioridade
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, PREPARED_BOMBARDMENT, d.grid), "A unidade já agiu neste turno.")

func test_a_new_turn_restores_the_requirement():
	var d := _bombard_setup()
	var unit: Unit = d.unit
	unit.movement_left = unit.unit_data.movement_points - 0.5
	assert_false(V2TechniqueRuntime.can_use(unit, PREPARED_BOMBARDMENT, d.grid))
	unit.movement_left = unit.unit_data.movement_points # o início de turno normal restaura o movimento cheio
	assert_true(V2TechniqueRuntime.can_use(unit, PREPARED_BOMBARDMENT, d.grid))

func test_no_state_is_saved_for_the_requirement_only_movement_left_decides():
	assert_false("prepared_this_turn" in Unit.new().get_property_list().map(func(p): return p.name), "nenhum boolean redundante")
	var d := _bombard_setup()
	assert_true(d.unit.magic_status.is_empty(), "nada guardado antes de usar")

# --- Multiplicador e resolução via o sistema urbano existente ---------------------------------------------------------------------

func test_the_strike_hits_the_city_with_150_percent_through_the_normal_city_formula():
	var d := _bombard_setup()
	# _bombard_setup completa até N6 (inclui N4): a fórmula já reflete Munição Demolidora (1,4x) também — o
	# multiplicador do golpe (1,5x) é só mais um fator da MESMA conta, testado isolado em test_without_n4_...
	var expected := _city_formula_damage(d.unit, d.city, 1.5, V2TechniqueRuntime.city_attack_multiplier(d.unit))
	var hp_before: float = d.city.hp
	var shield_before: float = d.city.shield
	assert_true(V2TechniqueRuntime.perform_city_strike(d.unit, PREPARED_BOMBARDMENT, d.city, d.grid))
	assert_almost_eq(_city_damage_taken(d.city, hp_before, shield_before), expected, 0.0001)

func test_it_consumes_the_action_zeroes_movement_and_enters_a_four_turn_cooldown():
	var d := _bombard_setup()
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_city_strike(unit, PREPARED_BOMBARDMENT, d.city, d.grid))
	assert_eq(unit.movement_left, 0.0)
	assert_eq(int(unit.magic_cooldowns[PREPARED_BOMBARDMENT]), 5 + 4)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, PREPARED_BOMBARDMENT), 4)
	TurnManager.turn_number = 9
	unit.movement_left = unit.unit_data.movement_points # o início de turno normal restaura o movimento cheio
	assert_true(V2TechniqueRuntime.can_use(unit, PREPARED_BOMBARDMENT, d.grid), "volta no turno T+4")

func test_it_costs_no_mana_and_no_gold():
	var d := _bombard_setup()
	d.me.gold = 50.0
	d.me.mana = 20.0
	assert_true(V2TechniqueRuntime.perform_city_strike(d.unit, PREPARED_BOMBARDMENT, d.city, d.grid))
	assert_eq(d.me.gold, 50.0)
	assert_eq(d.me.mana, 20.0)

func test_the_normal_basic_attack_against_the_city_remains_available_while_the_technique_is_on_cooldown():
	var d := _bombard_setup()
	assert_true(V2TechniqueRuntime.perform_city_strike(d.unit, PREPARED_BOMBARDMENT, d.city, d.grid))
	d.unit.movement_left = d.unit.unit_data.movement_points
	var hp_before: float = d.city.hp
	CombatResolver.resolve_city_attack(d.unit, d.city, d.grid) # ataque básico normal, não a Técnica
	assert_lt(d.city.hp, hp_before, "o ataque básico continua funcionando mesmo com o Bombardeio em recarga")

func test_a_unit_that_moved_loses_only_the_prepared_bombardment_not_its_normal_attack():
	var d := _bombard_setup()
	var unit: Unit = d.unit
	unit.movement_left = 0.5
	assert_false(V2TechniqueRuntime.can_use(unit, PREPARED_BOMBARDMENT, d.grid))
	unit.movement_left = unit.unit_data.movement_points
	var hp_before: float = d.city.hp
	CombatResolver.resolve_city_attack(unit, d.city, d.grid)
	assert_lt(d.city.hp, hp_before, "o ataque básico não é artificialmente bloqueado")

func test_a_failed_use_never_consumes_the_cooldown():
	var d := _bombard_setup()
	var unit: Unit = d.unit
	var movement := unit.movement_left
	assert_false(V2TechniqueRuntime.perform_city_strike(unit, PREPARED_BOMBARDMENT, null, d.grid), "sem alvo")
	var far := _enemy_city(d.grid, d.rival, Vector2i(9, 9))
	assert_false(V2TechniqueRuntime.perform_city_strike(unit, PREPARED_BOMBARDMENT, far, d.grid), "fora do alcance")
	assert_false(unit.magic_cooldowns.has(PREPARED_BOMBARDMENT))
	assert_eq(unit.movement_left, movement)

func test_esc_cancels_without_moving_or_consuming_anything():
	var d := _bombard_setup()
	var unit: Unit = d.unit
	var original_grid := GameManager.hex_grid
	var original_human := GameManager.human_player
	GameManager.hex_grid = d.grid
	GameManager.human_player = d.me
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(PREPARED_BOMBARDMENT)
	assert_eq(SelectionManager.technique_targeting_id, PREPARED_BOMBARDMENT)
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_eq(unit.movement_left, unit.unit_data.movement_points)
	assert_false(unit.magic_cooldowns.has(PREPARED_BOMBARDMENT))
	assert_eq(d.city.hp, d.city.max_hp())
	SelectionManager.reset()
	GameManager.hex_grid = original_grid
	GameManager.human_player = original_human

# --- Visibilidade: mesma regra das outras Técnicas de alcance > 1 -----------------------------------------------------------------

func test_a_city_hidden_by_fog_is_not_a_valid_target_for_the_human():
	var d := _bombard_setup()
	var original_human := GameManager.human_player
	GameManager.human_player = d.me
	d.unit.owner_player = d.me
	d.grid.visibility[d.city.coord] = HexGrid.Visibility.UNSEEN
	assert_false(d.city in V2TechniqueRuntime.city_strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid), "cidade não vista pelo humano")
	d.grid.visibility[d.city.coord] = HexGrid.Visibility.VISIBLE
	assert_true(d.city in V2TechniqueRuntime.city_strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid))
	GameManager.human_player = original_human

func test_without_fog_data_or_for_the_ai_there_is_no_visibility_restriction():
	var d := _bombard_setup() # grid.visibility vazio (partida de teste sem fog calculada)
	assert_true(d.city in V2TechniqueRuntime.city_strike_targets(d.unit, _technique(PREPARED_BOMBARDMENT), d.grid))

# --- A cidade não revida (regra normal, nenhuma imunidade inventada) ---------------------------------------------------------------

func test_the_city_does_not_counterattack_same_as_the_normal_attack():
	var d := _bombard_setup()
	var hp_before_attacker: float = d.unit.hp
	assert_true(V2TechniqueRuntime.perform_city_strike(d.unit, PREPARED_BOMBARDMENT, d.city, d.grid))
	assert_eq(d.unit.hp, hp_before_attacker, "cidade nunca revida, como o ataque normal")

# --- TargetMode CITY: genérico, independente da branch --------------------------------------------------------------------------

func test_target_mode_unit_and_tile_keep_working_exactly_as_before():
	assert_eq(_technique(SNEAK_ATTACK).target_mode, V2DoctrineTechniqueData.TargetMode.UNIT)
	assert_eq(_technique(RETREAT).target_mode, V2DoctrineTechniqueData.TargetMode.TILE)
	assert_false(_technique(SNEAK_ATTACK).is_city_strike())
	assert_false(_technique(RETREAT).is_city_strike())

func test_target_mode_city_rejects_a_unit_coordinate_and_an_empty_tile():
	var d := _bombard_setup()
	var foe := _foe(d.grid, d.rival, Vector2i(1, 0))
	assert_false(V2TechniqueRuntime.perform_targeted(d.unit, PREPARED_BOMBARDMENT, foe.coord, d.grid), "coordenada de unidade não é cidade")
	assert_false(V2TechniqueRuntime.perform_targeted(d.unit, PREPARED_BOMBARDMENT, Vector2i(50, 50), d.grid), "tile vazio não é cidade")

func test_no_technique_id_decides_the_target_mode_dispatch():
	var source := _code_only(FileAccess.get_file_as_string("res://scripts/autoload/SelectionManager.gd"))
	assert_false(source.contains("prepared_bombardment"), "SelectionManager nunca cita a Técnica por id")
	assert_false(source.contains("== \"CITY\""))

# --- Nenhum id concreto na lógica ---------------------------------------------------------------------------------------------------

func test_no_unit_id_or_technique_id_of_the_siege_doctrine_appears_in_the_generic_movement_and_combat_code():
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/data/V2DoctrineTechniqueData.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["technique_demolition_ammo", "technique_prepared_bombardment", "unit_catapult", "unit_trebuchet", "unit_bombard", "siege_colossus"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])

# --- Artilharia Andante: o Colosso ignora o requisito de preparação (por dado) ------------------------------------------------------

func test_conventional_forms_lose_access_after_moving_the_colossus_keeps_it():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var rival := _rival_of(me)
	var city := _enemy_city(grid, rival, Vector2i(4, 0))
	var index := 0
	for kind in [CATAPULT, TREBUCHET, BOMBARD]:
		var unit := _unit(grid, me, kind, Vector2i(0, index))
		index += 1
		unit.movement_left = unit.unit_data.movement_points - 0.5 # moveu uma parte
		assert_false(V2TechniqueRuntime.can_use(unit, PREPARED_BOMBARDMENT, grid), "%s perde acesso depois de se mover" % kind)
	var colossus := _unit(grid, me, COLOSSUS, Vector2i(0, index))
	colossus.movement_left = colossus.unit_data.movement_points - 0.5
	assert_true(UnitDatabase.create_unit(COLOSSUS).ignores_technique_stationary_requirement)
	assert_true(V2TechniqueRuntime.city_strike_targets(colossus, _technique(PREPARED_BOMBARDMENT), grid).has(city), "o Colosso ainda alcança a cidade")
	assert_true(V2TechniqueRuntime.can_use(colossus, PREPARED_BOMBARDMENT, grid), "e continua podendo bombardear mesmo tendo se movido")

func test_the_colossus_still_needs_range_a_valid_city_and_respects_cooldown_and_action_cost():
	var grid := _world()
	var me := _siege_player(9)
	var rival := _rival_of(me)
	var colossus := _unit(grid, me, COLOSSUS, Vector2i(0, 0))
	colossus.movement_left = colossus.unit_data.movement_points - 1.0
	assert_eq(V2TechniqueRuntime.unavailable_reason(colossus, PREPARED_BOMBARDMENT, grid), "Nenhuma cidade hostil ao alcance.", "moveu, mas ainda precisa de alcance e alvo válido")
	var city := _enemy_city(grid, rival, Vector2i(4, 0)) # alcance 3+1=4
	assert_true(V2TechniqueRuntime.perform_city_strike(colossus, PREPARED_BOMBARDMENT, city, grid))
	assert_eq(colossus.movement_left, 0.0, "a Técnica ainda zera o movimento")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(colossus, PREPARED_BOMBARDMENT), 4, "cooldown normal")
	colossus.movement_left = colossus.unit_data.movement_points
	assert_false(V2TechniqueRuntime.can_use(colossus, PREPARED_BOMBARDMENT, grid), "em recarga: não pode usar de novo no mesmo turno")

func test_the_colossus_gets_no_extra_action_it_still_cannot_move_and_strike_and_strike_again():
	var grid := _world()
	var me := _siege_player(9)
	var rival := _rival_of(me)
	var colossus := _unit(grid, me, COLOSSUS, Vector2i(0, 0))
	var city := _enemy_city(grid, rival, Vector2i(4, 0))
	assert_true(V2TechniqueRuntime.perform_city_strike(colossus, PREPARED_BOMBARDMENT, city, grid))
	assert_eq(colossus.movement_left, 0.0)
	assert_false(V2TechniqueRuntime.can_use(colossus, PREPARED_BOMBARDMENT, grid), "não pode usar de novo no mesmo turno: sem ação extra")
	assert_eq(V2TechniqueRuntime.unavailable_reason(colossus, PREPARED_BOMBARDMENT, grid), "Em recarga: 4 turno(s).")

func test_the_exception_is_data_driven_no_id_check_anywhere():
	var runtime_source := _code_only(FileAccess.get_file_as_string("res://scripts/core/V2TechniqueRuntime.gd"))
	assert_true(runtime_source.contains("ignores_technique_stationary_requirement"), "a exceção é lida do dado da unidade")
	assert_false(runtime_source.contains("siege_colossus"), "nunca por id concreto")
	var conventional := UnitDatabase.create_unit(BOMBARD)
	assert_false(conventional.ignores_technique_stationary_requirement, "só o Colosso tem a exceção; a Bombarda continua exigindo posição parada")

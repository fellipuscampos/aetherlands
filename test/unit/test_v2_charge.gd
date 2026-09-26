extends "res://test/unit/v2_combat_fixture.gd"

## Carga (v2_technique_charge, Aetherlands V2 Fase 9): a primeira técnica de MOVER-E-ATACAR do framework. Ativa, com alvo: a unidade percorre uma rota
## REAL até um tile adjacente ao alvo (2 a 4 tiles de distância) e o golpa pelo combate normal (×1,50). Números = BALANCE PLACEHOLDER — os testes leem
## o multiplicador do dado quando o assunto é a lógica e fixam os valores canônicos só no teste de baseline.

## Cavaleiro (N4) em (0,0) e um inimigo em guerra a `distance` tiles no eixo +q.
func _charge_duel(distance: int = 3, target_hp: float = 40.0, target_def: float = 3.0, through: int = 4) -> Dictionary:
	var grid := _world()
	var me := _cavalry_player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	var foe := _foe(grid, rival, Vector2i(distance, 0), target_hp, target_def)
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "foe": foe}

# --- Dado ------------------------------------------------------------------------------------------------------------------------

func test_the_technique_has_the_specified_active_move_then_strike_baseline():
	var technique := _technique(CHARGE)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Carga", "o nome vem do nó de pesquisa")
	assert_eq(technique.doctrine_branch, "cavalry")
	assert_eq(technique.activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_true(technique.is_strike())
	assert_true(technique.repositions(), "mover-e-atacar")
	assert_eq(technique.strike_multiplier, 1.5)
	assert_eq(technique.strike_targeting, V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET)
	assert_eq(technique.strike_range_mode, V2DoctrineTechniqueData.StrikeRangeMode.FIXED)
	assert_eq(technique.strike_range, 4)
	assert_eq(technique.strike_min_range, 2)
	assert_eq(technique.cooldown_turns, 3)
	assert_true(technique.consumes_action)
	assert_true(technique.needs_target())
	assert_false(technique.is_relocation(), "não é a Retirada")

func test_it_is_registered_in_the_same_database_as_the_other_doctrines_and_is_live():
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(CHARGE)))
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("cavalry").size(), 2, "Carga + Retirada Tática")
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(POWER)), "as do Guerreiro continuam ao lado")
	assert_true(CHARGE in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	var technique := _technique(CHARGE)
	assert_false(technique.has_defense_effect() or technique.has_attack_effect())
	assert_false(V2DoctrineTechniqueDatabase.defensive_techniques().has(technique))
	assert_false(technique.is_passive())

func test_the_description_and_button_suffix_are_built_from_the_data():
	var technique := _technique(CHARGE)
	assert_true(technique.description.contains("×1.5"), technique.description)
	assert_true(technique.description.contains("recarga de 3 turnos"), technique.description)
	assert_true(technique.description.contains("2 a 4 tiles"), technique.description)
	assert_eq(V2DoctrineTechniqueDatabase.button_suffix(technique), "×1.5")

func test_the_multiplier_comes_from_the_data_not_from_the_code():
	var d := _charge_duel(3)
	var technique := _technique(CHARGE)
	var original := technique.strike_multiplier
	technique.strike_multiplier = 2.5
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	technique.strike_multiplier = original
	assert_almost_eq(before - d.foe.hp, _formula_damage(d.grid, 5.0, 2.5, d.foe), 0.0001)

func test_the_distance_window_comes_from_the_data_too():
	var technique := _technique(CHARGE)
	var far := _charge_duel(4)
	assert_true(V2TechniqueRuntime.can_use(far.unit, CHARGE, far.grid), "4 tiles: dentro da janela")
	technique.strike_range = 3
	var narrowed := V2TechniqueRuntime.can_use(far.unit, CHARGE, far.grid)
	technique.strike_range = 4
	assert_false(narrowed, "o alcance máximo é o do dado")
	var near := _charge_duel(2)
	assert_true(V2TechniqueRuntime.can_use(near.unit, CHARGE, near.grid), "2 tiles: dentro da janela")
	technique.strike_min_range = 3
	var raised := V2TechniqueRuntime.can_use(near.unit, CHARGE, near.grid)
	technique.strike_min_range = 2
	assert_false(raised, "a distância mínima é a do dado")

# --- Disponibilidade por nível e por unidade ----------------------------------------------------------------------------------

func test_it_appears_only_after_n4():
	var grid := _world()
	var me := _cavalry_player(3)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	_foe(grid, rival, Vector2i(3, 0))
	assert_false(_technique(CHARGE) in V2TechniqueRuntime.techniques_for_unit(unit), "antes do N4")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, CHARGE, grid), "Requer pesquisa: Carga.")
	me.v2_research.complete_research("v2_doctrine_cavalry_4")
	assert_true(_technique(CHARGE) in V2TechniqueRuntime.techniques_for_unit(unit))
	assert_true(V2TechniqueRuntime.can_use(unit, CHARGE, grid))

func test_every_form_of_the_line_and_the_griffon_inherit_it_no_other_branch_has_it():
	var grid := _world()
	var me := _cavalry_player(9, 9, 9, 9)
	var index := 0
	for kind in [CAVALIER, SHOCK, ARMORED, GRIFFON]:
		var unit := _unit(grid, me, kind, Vector2i(index, 3))
		index += 1
		assert_true(_technique(CHARGE) in V2TechniqueRuntime.techniques_for_unit(unit), "%s herda a Carga" % kind)
		assert_true(_technique(RETREAT) in V2TechniqueRuntime.techniques_for_unit(unit), "%s herda a Retirada" % kind)
	for kind in [WARRIOR, SHIELD, ARCHER, MASTER, SENTINEL, MARKSMAN]:
		var other := _unit(grid, me, kind, Vector2i(index - 4, -3))
		index += 1
		assert_false(_technique(CHARGE) in V2TechniqueRuntime.techniques_for_unit(other), "%s não tem a Carga" % kind)
		assert_eq(V2TechniqueRuntime.unavailable_reason(other, CHARGE, grid), "Esta unidade não pertence à linha da Doutrina.")

func test_a_v1_unit_never_gets_it_even_when_the_owner_researched_it():
	var grid := _world()
	var me := _cavalry_player(9)
	var v1_cavalry := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("cavalry"), me)
	assert_true(UnitAbilities.is_mounted(v1_cavalry.unit_data), "montada, mas é V1")
	assert_true(V2TechniqueRuntime.techniques_for_unit(v1_cavalry).is_empty())

func test_a_cavalier_of_a_civilization_without_the_research_has_nothing():
	var grid := _world()
	var me := _cavalry_player(3)
	var other := _cavalry_player(9)
	var unit := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty(), "a pesquisa é por civilização")
	assert_false(V2TechniqueRuntime.techniques_for_unit(_unit(grid, other, CAVALIER, Vector2i(2, 2))).is_empty())

# --- Alvo: janela de distância 2 a 4 ---------------------------------------------------------------------------------------------

func test_targets_at_distance_2_3_and_4_are_valid():
	for distance in [2, 3, 4]:
		var d := _charge_duel(distance)
		assert_true(d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid), "distância %d" % distance)
		assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "", "distância %d" % distance)

func test_an_adjacent_target_alone_makes_it_unavailable_with_the_clear_reason():
	var d := _charge_duel(1)
	assert_false(d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid))
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "Requer espaço para realizar a Carga.")
	assert_false(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_eq(d.unit.coord, Vector2i(0, 0))
	assert_false(d.unit.magic_cooldowns.has(CHARGE))

func test_a_target_beyond_4_is_out_of_reach():
	var d := _charge_duel(5)
	assert_true(V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid).is_empty())
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "Nenhum inimigo ao alcance.")

func test_an_adjacent_enemy_does_not_block_charging_another_target_farther_away():
	var d := _charge_duel(3)
	var adjacent := _foe(d.grid, d.rival, Vector2i(0, 1))
	var targets := V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid)
	assert_true(d.foe in targets)
	assert_false(adjacent in targets, "o adjacente não é alvo da Carga (é do ataque comum)")
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "")

func test_allies_civilizations_at_peace_and_cities_are_never_targets():
	var d := _charge_duel(3)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var me: PlayerData = d.me
	var friend := _unit(d.grid, me, WARRIOR, Vector2i(0, 3))
	assert_false(friend in V2TechniqueRuntime.strike_targets(unit, _technique(CHARGE), d.grid), "aliado")
	var neutral_civ := PlayerData.new(CivilizationData.new())
	_players.append(neutral_civ)
	var peaceful := _foe(d.grid, neutral_civ, Vector2i(2, 2))
	assert_false(peaceful in V2TechniqueRuntime.strike_targets(unit, _technique(CHARGE), d.grid), "civilização em paz")
	foe.owner_player = me
	assert_true(V2TechniqueRuntime.strike_targets(unit, _technique(CHARGE), d.grid).is_empty(), "mesmo dono")

func test_a_neutral_monster_is_a_valid_target_like_in_a_normal_attack():
	var d := _charge_duel(3)
	d.foe.owner_player = null
	assert_true(d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid))

func test_the_hostility_rule_is_the_one_of_the_normal_attack():
	var d := _charge_duel(3)
	for other in [d.foe]:
		assert_eq(CombatResolver.can_attack_unit(d.unit, other, d.grid), other in V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid))

func test_an_enemy_out_of_the_owners_vision_cannot_be_charged_but_the_ai_ignores_fog():
	var d := _charge_duel(3)
	var original := GameManager.human_player
	GameManager.human_player = d.me
	d.grid.visibility[d.foe.coord] = HexGrid.Visibility.EXPLORED
	assert_false(d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid), "fora da visão do humano")
	d.grid.visibility[d.foe.coord] = HexGrid.Visibility.VISIBLE
	assert_true(d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid))
	d.grid.visibility[d.foe.coord] = HexGrid.Visibility.UNSEEN
	GameManager.human_player = d.rival
	assert_true(d.foe in V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid), "a IA não usa a neblina do humano")
	GameManager.human_player = original

# --- Rota real e tile de aproximação ------------------------------------------------------------------------------------------------

func test_the_unit_really_ends_adjacent_to_the_target_with_its_position_updated():
	var d := _charge_duel(3)
	var unit: Unit = d.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, CHARGE, d.foe, d.grid))
	assert_eq(HexMetrics.axial_distance(unit.coord, d.foe.coord), 1, "termina adjacente")
	assert_eq(unit.coord, Vector2i(2, 0), "o tile de menor custo da rota")
	assert_eq(d.grid.get_unit_at(Vector2i(2, 0)), unit, "o grid registra a unidade no novo tile")
	assert_null(d.grid.get_unit_at(Vector2i(0, 0)), "o tile antigo ficou livre")
	assert_eq(d.foe.coord, Vector2i(3, 0), "o alvo não se mexe")

func test_at_distance_2_the_unit_moves_one_tile_and_at_4_it_moves_three():
	var d2 := _charge_duel(2)
	assert_true(V2TechniqueRuntime.perform_strike(d2.unit, CHARGE, d2.foe, d2.grid))
	assert_eq(d2.unit.coord, Vector2i(1, 0))
	var d4 := _charge_duel(4)
	assert_true(V2TechniqueRuntime.perform_strike(d4.unit, CHARGE, d4.foe, d4.grid))
	assert_eq(d4.unit.coord, Vector2i(3, 0))

func _approach_of(d: Dictionary) -> Vector2i:
	var movable: Dictionary = d.grid.unit_reachable(d.unit)
	return V2TechniqueRuntime._approach_tile(d.unit, d.foe, movable, d.grid)

## Alvo em (3,-1): os vizinhos (2,-1) e (2,0) custam 2 cada, com o mesmo número de passos — o desempate é a coordenada (q, depois r).
func _tied_duel() -> Dictionary:
	var grid := _world()
	var me := _cavalry_player(4)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	var foe := _foe(grid, rival, Vector2i(3, -1))
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "foe": foe}

func test_a_tie_in_cost_and_steps_is_broken_by_the_stable_coordinate_never_by_dictionary_order():
	for i in 3:
		var d := _tied_duel()
		assert_eq(_approach_of(d), Vector2i(2, -1), "menor q, depois menor r (repetição %d)" % i)
		assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
		assert_eq(d.unit.coord, Vector2i(2, -1))

func test_a_costlier_terrain_makes_the_other_neighbor_win_by_real_path_cost():
	var d := _tied_duel()
	_set_costly(d.grid, Vector2i(2, -1), 3) # (2,-1) passa a custar 1+3, (2,0) segue a 2
	assert_eq(_approach_of(d), Vector2i(2, 0))
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_eq(d.unit.coord, Vector2i(2, 0))

func test_on_equal_cost_fewer_steps_wins_before_the_coordinate():
	var grid := _world()
	var me := _cavalry_player(4)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, CAVALIER, Vector2i(3, 0))
	var foe := _foe(grid, rival, Vector2i(1, 0))
	_set_costly(grid, Vector2i(2, 0), 2) # 1 passo custando 2; (1,1) e (2,-1) custam 2 em 2 passos
	var movable := grid.unit_reachable(unit)
	assert_eq(float(movable[Vector2i(2, 0)]), 2.0)
	assert_eq(float(movable[Vector2i(1, 1)]), 2.0)
	assert_eq(V2TechniqueRuntime._approach_tile(unit, foe, movable, grid), Vector2i(2, 0), "menos passos, apesar da coordenada maior")

func test_the_choice_does_not_depend_on_the_order_the_reachable_tiles_are_built():
	var d := _tied_duel()
	var movable: Dictionary = d.grid.unit_reachable(d.unit)
	var reversed: Dictionary = {}
	var keys := movable.keys()
	keys.reverse()
	for key in keys:
		reversed[key] = movable[key]
	assert_eq(V2TechniqueRuntime._approach_tile(d.unit, d.foe, movable, d.grid), V2TechniqueRuntime._approach_tile(d.unit, d.foe, reversed, d.grid))

func test_the_route_respects_impassable_terrain_and_goes_around_it():
	var d := _charge_duel(3)
	_set_terrain(d.grid, Vector2i(1, 0), HexTileData.TerrainType.MOUNTAINS)
	_set_terrain(d.grid, Vector2i(2, 0), HexTileData.TerrainType.MOUNTAINS)
	assert_true(d.grid.get_tile(Vector2i(2, 0)).blocks_land_units())
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid), "contorna pelo lado")
	assert_eq(HexMetrics.axial_distance(d.unit.coord, d.foe.coord), 1)
	assert_ne(d.unit.coord, Vector2i(2, 0), "nunca termina na montanha")
	assert_false(d.grid.get_tile(d.unit.coord).blocks_land_units())

func test_a_target_walled_in_by_impassable_terrain_has_no_route_and_nothing_happens():
	var d := _charge_duel(3)
	for coord in d.grid.get_neighbors(d.foe.coord):
		if coord != Vector2i(0, 0):
			_set_terrain(d.grid, coord, HexTileData.TerrainType.MOUNTAINS)
	assert_true(V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE), d.grid).is_empty())
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "Sem rota até um tile adjacente ao alvo.")
	var hp: float = d.foe.hp
	var movement: float = d.unit.movement_left
	assert_false(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_eq(d.unit.coord, Vector2i(0, 0), "sem movimento parcial")
	assert_eq(d.unit.movement_left, movement)
	assert_eq(d.foe.hp, hp)
	assert_false(d.unit.magic_cooldowns.has(CHARGE), "sem recarga")

func test_a_barrier_of_water_stops_ground_cavalry_from_charging_across_it():
	var d := _charge_duel(4)
	for r in range(-6, 7):
		if d.grid.tiles.has(Vector2i(2, r)):
			_set_terrain(d.grid, Vector2i(2, r), HexTileData.TerrainType.OCEAN)
	assert_true(d.grid.get_tile(Vector2i(2, 0)).blocks_land_units())
	assert_eq(d.unit.unit_data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_false(V2TechniqueRuntime.can_use(d.unit, CHARGE, d.grid), "o oceano corta a rota")
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "Sem rota até um tile adjacente ao alvo.")

func test_occupied_neighbors_are_not_valid_approach_tiles():
	var d := _charge_duel(2)
	var approach_before := _approach_of(d)
	assert_eq(approach_before, Vector2i(1, 0))
	_unit(d.grid, d.me, WARRIOR, Vector2i(1, 0)) # aliado no tile ideal
	var next := _approach_of(d)
	assert_ne(next, Vector2i(1, 0))
	assert_ne(next, V2TechniqueRuntime.NO_TILE)
	assert_eq(HexMetrics.axial_distance(next, d.foe.coord), 1)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_eq(d.unit.coord, next, "o mesmo tile que a busca deu")

func test_all_neighbors_of_the_target_occupied_means_no_route():
	var d := _charge_duel(3)
	for coord in d.grid.get_neighbors(d.foe.coord):
		if d.grid.get_unit_at(coord) == null and coord != d.unit.coord:
			_unit(d.grid, d.me, WARRIOR, coord)
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "Sem rota até um tile adjacente ao alvo.")
	assert_false(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))

func test_the_route_uses_only_the_movement_the_unit_still_has():
	var d := _charge_duel(4)
	d.unit.movement_left = 2.0 # a rota até o vizinho custa 3
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "Sem rota até um tile adjacente ao alvo.")
	d.unit.movement_left = 3.0
	assert_true(V2TechniqueRuntime.can_use(d.unit, CHARGE, d.grid))
	d.unit.movement_left = 0.0
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "A unidade já agiu neste turno.")

func test_enemy_units_in_the_middle_of_the_route_block_ground_cavalry_but_it_walks_around():
	var d := _charge_duel(4)
	_foe(d.grid, d.rival, Vector2i(1, 0))
	_foe(d.grid, d.rival, Vector2i(2, 0))
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid), "contorna os inimigos no meio")
	assert_eq(HexMetrics.axial_distance(d.unit.coord, d.foe.coord), 1)

# --- Resolução -------------------------------------------------------------------------------------------------------------------------

func test_the_charge_hits_with_150_percent_of_the_basic_attack_through_the_normal_formula():
	var d := _charge_duel(3)
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_almost_eq(before - d.foe.hp, _formula_damage(d.grid, 5.0, 1.5, d.foe), 0.0001, "5,0 x 1,5 - 3,0 x 0,5")
	assert_almost_eq(before - d.foe.hp, 6.0, 0.0001)

func test_prediction_from_the_approach_tile_equals_the_real_hp_loss():
	var d := _charge_duel(3)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var predicted: float = CombatResolver.predict(unit, foe, d.grid, _technique(CHARGE).strike_multiplier).damage_to_defender
	var before := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, CHARGE, foe, d.grid))
	assert_almost_eq(before - foe.hp, predicted, 0.0001)

func test_it_consumes_the_action_and_zeroes_the_movement_even_with_leftover_points():
	var d := _charge_duel(2)
	assert_eq(d.unit.movement_left, 4.0)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_eq(d.unit.movement_left, 0.0, "andou 1 e sobrariam 3: a ação acabou")
	d.unit.magic_cooldowns.erase(CHARGE)
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "A unidade já agiu neste turno.")

func test_the_cooldown_is_three_turns_counting_the_turn_of_use():
	var d := _charge_duel(3)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_eq(int(d.unit.magic_cooldowns[CHARGE]), 5 + 3)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(d.unit, CHARGE), 3)
	d.unit.movement_left = d.unit.unit_data.movement_points
	assert_false(V2TechniqueRuntime.can_use(d.unit, CHARGE, d.grid))
	TurnManager.turn_number = 7
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "Em recarga: 1 turno(s).")
	TurnManager.turn_number = 8
	assert_eq(V2TechniqueRuntime.cooldown_remaining(d.unit, CHARGE), 0, "volta no turno T+3")
	_foe(d.grid, d.rival, Vector2i(1, 3)) # o alvo da Carga anterior segue colado na unidade; outro inimigo a distância
	assert_true(V2TechniqueRuntime.can_use(d.unit, CHARGE, d.grid))

func test_it_costs_no_mana_and_no_gold():
	var d := _charge_duel(3)
	d.me.gold = 50.0
	d.me.mana = 20.0
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_eq(d.me.gold, 50.0)
	assert_eq(d.me.mana, 20.0)

func test_no_effect_is_stored_only_the_cooldown():
	var d := _charge_duel(3)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_true(d.unit.magic_status.get(CHARGE, null) == null)
	assert_false(V2TechniqueRuntime.is_active(d.unit, CHARGE))
	assert_true(V2TechniqueRuntime.status_lines(d.unit).is_empty())
	assert_eq(V2TechniqueRuntime.expire_finished(d.me), 0)
	assert_true(V2TechniqueRuntime.cooldown_lines(d.unit).any(func(l): return l.begins_with("Carga")))

func test_activate_refuses_it_because_it_needs_a_target():
	var d := _charge_duel(3)
	assert_false(V2TechniqueRuntime.activate(d.unit, CHARGE))
	assert_eq(d.unit.coord, Vector2i(0, 0))
	assert_false(d.unit.magic_cooldowns.has(CHARGE))
	assert_eq(d.unit.movement_left, 4.0)

func test_a_failed_use_changes_nothing():
	var d := _charge_duel(3)
	var unit: Unit = d.unit
	var foe: Unit = d.foe
	var far := _foe(d.grid, d.rival, Vector2i(-6, 0))
	var hp := foe.hp
	assert_false(V2TechniqueRuntime.perform_strike(unit, CHARGE, null, d.grid), "sem alvo")
	assert_false(V2TechniqueRuntime.perform_strike(unit, CHARGE, far, d.grid), "alvo fora do alcance")
	assert_false(V2TechniqueRuntime.perform_strike(unit, CHARGE, unit, d.grid), "não pode ser ela mesma")
	assert_false(V2TechniqueRuntime.perform_strike(unit, RETREAT, foe, d.grid), "não é técnica de ataque")
	assert_false(V2TechniqueRuntime.perform_strike(unit, "v2_inexistente", foe, d.grid))
	assert_eq(foe.hp, hp)
	assert_eq(unit.coord, Vector2i(0, 0))
	assert_eq(unit.movement_left, 4.0)
	assert_false(unit.magic_cooldowns.has(CHARGE))

func test_the_generic_entry_point_used_by_the_selection_takes_a_tile_with_a_unit_on_it():
	var d := _charge_duel(3)
	assert_false(V2TechniqueRuntime.perform_targeted(d.unit, CHARGE, Vector2i(1, 0), d.grid), "tile vazio")
	assert_false(V2TechniqueRuntime.perform_targeted(d.unit, CHARGE, V2TechniqueRuntime.NO_TILE, d.grid))
	assert_eq(d.unit.coord, Vector2i(0, 0))
	assert_true(V2TechniqueRuntime.perform_targeted(d.unit, CHARGE, d.foe.coord, d.grid))
	assert_eq(d.unit.coord, Vector2i(2, 0))

func test_the_highlighted_targets_are_the_valid_targets():
	var d := _charge_duel(3)
	assert_eq(V2TechniqueRuntime.target_coords(d.unit, _technique(CHARGE), d.grid), [Vector2i(3, 0)])
	_foe(d.grid, d.rival, Vector2i(0, 1)) # adjacente: não é destacado
	_foe(d.grid, d.rival, Vector2i(-2, 0))
	var coords := V2TechniqueRuntime.target_coords(d.unit, _technique(CHARGE), d.grid)
	assert_eq(coords.size(), 2)
	assert_true(Vector2i(3, 0) in coords and Vector2i(-2, 0) in coords)
	assert_false(Vector2i(0, 1) in coords)

# --- A cadeia normal de combate ---------------------------------------------------------------------------------------------------------

func test_terrain_defense_of_the_target_tile_applies():
	var d := _charge_duel(3)
	_set_terrain(d.grid, Vector2i(3, 0), HexTileData.TerrainType.HILLS)
	assert_gt(d.grid.get_tile(Vector2i(3, 0)).defense_bonus, 0.0, "pré-condição: colina defende")
	var expected := _formula_damage(d.grid, 5.0, 1.5, d.foe)
	assert_lt(expected, _formula_damage(_world(), 5.0, 1.5, d.foe), "menos dano que na grama")
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_almost_eq(before - d.foe.hp, expected, 0.0001)

func test_a_shield_wall_on_the_target_reduces_the_damage():
	var d := _charge_duel(3)
	d.foe.magic_status[WALL] = TurnManager.turn_number + 2
	var wall_bonus: float = 1.0 + _technique(WALL).self_defense_bonus
	var expected := _formula_damage(d.grid, 5.0, 1.5, d.foe, wall_bonus)
	assert_lt(expected, _formula_damage(d.grid, 5.0, 1.5, d.foe))
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_almost_eq(before - d.foe.hp, expected, 0.0001, "mesma cadeia de defesa do ataque normal")

func test_the_defenders_aura_also_counts():
	var d := _charge_duel(3)
	_unit(d.grid, d.rival, CHAMPION, Vector2i(4, 0))
	var aura: float = 1.0 + UnitDatabase.create_unit(CHAMPION).aura_defense_bonus
	var before: float = d.foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_almost_eq(before - d.foe.hp, _formula_damage(d.grid, 5.0, 1.5, d.foe, aura), 0.0001)

func test_a_charge_into_a_guardian_uses_only_the_cavaliers_own_attack_times_the_multiplier():
	# O Preparar Lanças é bônus do ATAQUE do Guardião contra montados — não altera o golpe do Cavaleiro contra ele.
	var grid := _world()
	var me := _cavalry_player(4)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	var guardian := _unit(grid, rival, SHIELD, Vector2i(3, 0))
	var before := guardian.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, CHARGE, guardian, grid))
	assert_almost_eq(before - guardian.hp, _formula_damage(grid, 5.0, 1.5, guardian), 0.0001)

func test_a_kill_counts_once_for_xp_the_unit_still_ends_at_the_approach_tile():
	var d := _charge_duel(3, 4.0, 3.0)
	assert_eq(d.unit.kills, 0)
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_eq(d.unit.kills, 1, "um abate, contado uma vez")
	assert_false(d.rival.units.has(d.foe))
	assert_null(d.grid.get_unit_at(Vector2i(3, 0)))
	assert_eq(d.unit.coord, Vector2i(2, 0), "a Carga terminou o deslocamento, o alvo já caiu")
	assert_eq(d.unit.movement_left, 0.0)

func test_a_surviving_target_counterattacks_after_the_unit_arrives_adjacent():
	var d := _charge_duel(3, 60.0, 14.0) # Defesa alta: o revide sai da Defesa do alvo
	var atk := 5.0 * 1.5
	var expected := maxf(0.0, 14.0 - atk * CombatResolver.DEFENSE_MITIGATION_FACTOR) * CombatResolver.COUNTER_ATTACK_PENALTY
	assert_gt(expected, 0.0, "pré-condição: há revide")
	var my_hp: float = d.unit.hp
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_almost_eq(my_hp - d.unit.hp, expected, 0.0001, "o revide existe porque a Carga termina adjacente")

func test_the_charger_can_die_in_the_counter_and_the_technique_still_settles_its_cost():
	var d := _charge_duel(3, 60.0, 40.0)
	d.unit.hp = 1.0
	assert_true(V2TechniqueRuntime.perform_strike(d.unit, CHARGE, d.foe, d.grid))
	assert_lte(d.unit.hp, 0.0)
	assert_gt(d.foe.hp, 0.0)

func test_it_does_not_break_the_guardians_brace_spears_counter_it_only_interacts_by_the_mounted_trait():
	var grid := _world()
	var me := _cavalry_player(4)
	var rival := _rival_of(me)
	var guardian_player := _player(0, 9)
	Diplomacy.declare_war(rival, guardian_player)
	Diplomacy.declare_war(me, guardian_player)
	var cavalier := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	var guardian := _unit(grid, guardian_player, SHIELD, Vector2i(3, 0))
	assert_true(V2TechniqueRuntime.perform_strike(cavalier, CHARGE, guardian, grid))
	assert_eq(cavalier.coord, Vector2i(2, 0))
	var brace := _technique(BRACE)
	var basic := _formula_damage(grid, guardian.unit_data.attack, 1.0, cavalier)
	var countered := _formula_damage(grid, guardian.unit_data.attack, 1.0 + brace.basic_attack_bonus, cavalier)
	var predicted: float = CombatResolver.predict(guardian, cavalier, grid).damage_to_defender
	assert_almost_eq(predicted, countered, 0.0001, "o Escudeiro golpeia o montado com o Preparar Lanças")
	assert_gt(countered, basic)

# --- As outras técnicas de ataque seguem como estavam ---------------------------------------------------------------------------------

func test_the_existing_strike_techniques_are_unchanged_by_the_generalization():
	for id in [POWER, "v2_technique_cleave", PRECISE, VOLLEY]:
		var technique := _technique(id)
		assert_false(technique.repositions(), id)
		assert_eq(technique.strike_min_range, 1, id)
		assert_false(technique.is_relocation(), id)
	assert_eq(_technique(POWER).strike_multiplier, 1.6)
	assert_eq(_technique(PRECISE).strike_multiplier, 1.4)

func test_a_non_repositioning_strike_never_moves_the_unit():
	var grid := _world()
	var me := _player(4)
	var rival := _rival_of(me)
	var warrior := _unit(grid, me, WARRIOR, Vector2i(0, 0))
	var foe := _foe(grid, rival, Vector2i(1, 0))
	assert_true(V2TechniqueRuntime.perform_strike(warrior, POWER, foe, grid))
	assert_eq(warrior.coord, Vector2i(0, 0))

func test_no_unit_id_or_technique_id_of_the_cavalry_appears_in_the_generic_movement_and_combat_code():
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/world/HexGrid.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/data/V2DoctrineTechniqueData.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["technique_charge", "tactical_retreat", "v2_unit_cavalier", "v2_unit_shock", "v2_unit_armored", "griffon"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])

func test_the_reason_uses_the_current_game_grid_when_the_caller_passes_none_like_the_hud_does():
	var d := _charge_duel(1)
	var original := GameManager.hex_grid
	GameManager.hex_grid = d.grid
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE), "Requer espaço para realizar a Carga.")
	assert_true(V2TechniqueRuntime.strike_targets(d.unit, _technique(CHARGE)).is_empty())
	GameManager.hex_grid = original

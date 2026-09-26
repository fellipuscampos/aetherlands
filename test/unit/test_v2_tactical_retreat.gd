extends "res://test/unit/v2_combat_fixture.gd"

## Retirada Tática (v2_technique_tactical_retreat, Aetherlands V2 Fase 9): a primeira técnica de REPOSICIONAMENTO POR TILE (`target_mode` TILE) do
## framework. Ativa: o jogador escolhe um tile livre a até 3 passos (cada passo custa 1, ignorando o custo do terreno, mas nunca atravessando
## terreno impassável ou unidade), a unidade vai até lá de verdade e ganha +20% de Defesa até o próximo turno do dono. Números = BALANCE PLACEHOLDER.

## Cavaleiro (N6) em (0,0), sem ninguém por perto.
func _retreat_scene(through: int = 6) -> Dictionary:
	var grid := _world()
	var me := _cavalry_player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	return {"grid": grid, "me": me, "rival": rival, "unit": unit}

# --- Dado ------------------------------------------------------------------------------------------------------------------------

func test_the_technique_has_the_specified_active_tile_relocation_baseline():
	var technique := _technique(RETREAT)
	assert_not_null(technique)
	assert_eq(technique.display_name, "Retirada Tática", "o nome vem do nó de pesquisa")
	assert_eq(technique.doctrine_branch, "cavalry")
	assert_eq(technique.activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_true(technique.is_relocation())
	assert_eq(technique.target_mode, V2DoctrineTechniqueData.TargetMode.TILE)
	assert_eq(technique.relocate_range, 3)
	assert_true(technique.relocate_flat_cost, "cada passo custa 1")
	assert_eq(technique.self_defense_bonus, 0.2)
	assert_eq(technique.cooldown_turns, 4)
	assert_true(technique.consumes_action)
	assert_true(technique.needs_target(), "o alvo é um tile")
	assert_false(technique.is_strike(), "não ataca")
	assert_false(technique.is_passive())

func test_it_is_registered_next_to_the_charge_and_is_live():
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(RETREAT)))
	assert_true(V2DoctrineTechniqueDatabase.for_branch("cavalry").has(_technique(RETREAT)))
	assert_true(RETREAT in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	assert_true(V2DoctrineTechniqueDatabase.defensive_techniques().has(_technique(RETREAT)), "o bônus de Defesa passa pela cadeia de defesa que já existia")

func test_the_description_is_built_from_the_data():
	var technique := _technique(RETREAT)
	assert_true(technique.description.contains("3"), technique.description)
	assert_true(technique.description.contains("+20%"), technique.description)
	assert_true(technique.description.contains("recarga de 4 turnos"), technique.description)

func test_the_existing_techniques_default_to_unit_targeting_and_are_not_relocations():
	for id in [WALL, POWER, "v2_technique_cleave", PRECISE, VOLLEY, CHARGE]:
		assert_eq(_technique(id).target_mode, V2DoctrineTechniqueData.TargetMode.UNIT, id)
		assert_false(_technique(id).is_relocation(), id)

# --- Disponibilidade -------------------------------------------------------------------------------------------------------------

func test_it_appears_only_after_n6_and_needs_no_enemy():
	var d := _retreat_scene(5)
	assert_false(_technique(RETREAT) in V2TechniqueRuntime.techniques_for_unit(d.unit), "antes do N6")
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, RETREAT, d.grid), "Requer pesquisa: Retirada Tática.")
	d.me.v2_research.complete_research("v2_doctrine_cavalry_6")
	assert_true(_technique(RETREAT) in V2TechniqueRuntime.techniques_for_unit(d.unit))
	assert_true(d.rival.units.is_empty(), "nenhum inimigo por perto")
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, RETREAT, d.grid), "")

func test_every_form_inherits_it_and_no_other_branch_has_it():
	var grid := _world()
	var me := _cavalry_player(9, 9, 9, 9)
	var index := 0
	for kind in [CAVALIER, SHOCK, ARMORED, GRIFFON]:
		assert_true(_technique(RETREAT) in V2TechniqueRuntime.techniques_for_unit(_unit(grid, me, kind, Vector2i(index, 3))), kind)
		index += 1
	for kind in [WARRIOR, SHIELD, ARCHER]:
		var other := _unit(grid, me, kind, Vector2i(index - 4, -3))
		index += 1
		assert_false(_technique(RETREAT) in V2TechniqueRuntime.techniques_for_unit(other), kind)

func test_it_needs_the_action_to_be_left():
	var d := _retreat_scene()
	d.unit.movement_left = 0.0
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, RETREAT, d.grid), "A unidade já agiu neste turno.")
	d.unit.movement_left = 1.0
	assert_true(V2TechniqueRuntime.can_use(d.unit, RETREAT, d.grid), "com qualquer movimento sobrando ela ainda pode agir")

# --- Os tiles válidos ---------------------------------------------------------------------------------------------------------------

func test_every_free_tile_within_3_steps_is_a_destination_and_none_beyond():
	var d := _retreat_scene()
	var tiles := V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid)
	assert_eq(tiles.size(), 36, "os 36 tiles do raio 3 (37 - o próprio)")
	for coord in tiles:
		assert_lte(HexMetrics.axial_distance(Vector2i(0, 0), coord), 3)
	assert_false(Vector2i(0, 0) in tiles, "não vale ficar parado")
	assert_false(Vector2i(4, 0) in tiles, "sem teleporte: 4 passos não vale")
	assert_false(Vector2i(0, -4) in tiles)
	assert_eq(tiles, V2TechniqueRuntime.target_coords(d.unit, _technique(RETREAT), d.grid), "são os tiles destacados na mira")

func test_the_order_is_stable_by_cost_then_coordinate():
	var d := _retreat_scene()
	var first := V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid)
	var second := V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid)
	assert_eq(first, second)
	assert_eq(first[0], Vector2i(-1, 0), "custo 1, menor q, depois menor r")
	var last_cost := 0
	for coord in first:
		var cost := HexMetrics.axial_distance(Vector2i(0, 0), coord)
		assert_gte(cost, last_cost, "custo nunca decresce")
		last_cost = cost

func test_each_step_costs_one_ignoring_the_terrain_cost():
	var d := _retreat_scene()
	_set_costly(d.grid, Vector2i(1, 0), 2) # o único caminho de 3 passos até (3,0) passa por aqui
	var normal: Dictionary = d.grid.unit_reachable(d.unit, 3.0)
	assert_false(normal.has(Vector2i(3, 0)), "pré-condição: pelo movimento normal o terreno caro impede")
	var tiles := V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid)
	assert_true(Vector2i(3, 0) in tiles, "na Retirada cada passo custa 1")
	assert_true(Vector2i(1, 0) in tiles)

func test_impassable_terrain_and_units_still_block_the_path():
	var d := _retreat_scene()
	_set_terrain(d.grid, Vector2i(1, 0), HexTileData.TerrainType.MOUNTAINS)
	var tiles := V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid)
	assert_false(Vector2i(1, 0) in tiles, "a montanha não é destino")
	assert_false(Vector2i(3, 0) in tiles, "e o único caminho de 3 passos passava por ela")
	assert_true(Vector2i(2, 0) in tiles, "mas dá pra contornar em 3 passos")
	_unit(d.grid, d.rival, WARRIOR, Vector2i(-1, 0))
	tiles = V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid)
	assert_false(Vector2i(-1, 0) in tiles, "tile ocupado não é destino")
	assert_false(Vector2i(-3, 0) in tiles, "nem se atravessa a unidade no meio do caminho")

func test_water_and_occupied_tiles_are_never_destinations():
	var d := _retreat_scene()
	_set_terrain(d.grid, Vector2i(0, 2), HexTileData.TerrainType.OCEAN)
	_unit(d.grid, d.me, SHIELD, Vector2i(2, -1))
	var tiles := V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid)
	assert_false(Vector2i(0, 2) in tiles)
	assert_false(Vector2i(2, -1) in tiles)

func test_a_unit_walled_in_has_nowhere_to_go_and_the_reason_says_so():
	var d := _retreat_scene()
	for coord in d.grid.get_neighbors(Vector2i(0, 0)):
		_set_terrain(d.grid, coord, HexTileData.TerrainType.MOUNTAINS)
	assert_true(V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid).is_empty())
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, RETREAT, d.grid), "Nenhum tile livre ao alcance.")
	assert_false(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(2, 0), d.grid))
	assert_eq(d.unit.coord, Vector2i(0, 0))
	assert_false(d.unit.magic_cooldowns.has(RETREAT))

func test_there_is_no_zone_of_control_enemies_next_to_the_unit_do_not_stop_it():
	var d := _retreat_scene()
	for coord in [Vector2i(1, 0), Vector2i(1, -1)]:
		_foe(d.grid, d.rival, coord)
	assert_true(V2TechniqueRuntime.can_use(d.unit, RETREAT, d.grid), "engajada, ainda pode recuar")
	var tiles := V2TechniqueRuntime.relocation_tiles(d.unit, _technique(RETREAT), d.grid)
	assert_true(Vector2i(-3, 0) in tiles, "se afasta a 3 passos, com inimigos colados")
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-3, 0), d.grid))
	assert_eq(d.unit.coord, Vector2i(-3, 0))

# --- Execução ------------------------------------------------------------------------------------------------------------------------

func test_the_unit_really_moves_and_the_grid_registers_the_new_tile():
	var d := _retreat_scene()
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-2, 1), d.grid))
	assert_eq(d.unit.coord, Vector2i(-2, 1))
	assert_eq(d.grid.get_unit_at(Vector2i(-2, 1)), d.unit)
	assert_null(d.grid.get_unit_at(Vector2i(0, 0)), "o tile antigo ficou livre")

func test_it_can_take_a_partial_tile_1_2_or_3():
	for dest in [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(-3, 0)]:
		var d := _retreat_scene()
		assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, dest, d.grid), str(dest))
		assert_eq(d.unit.coord, dest)

func test_it_consumes_the_action_and_zeroes_the_movement():
	var d := _retreat_scene()
	assert_eq(d.unit.movement_left, 4.0)
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	assert_eq(d.unit.movement_left, 0.0, "recuar 1 tile não deixa 3 pontos de sobra")
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, CHARGE, d.grid), "A unidade já agiu neste turno.", "a ação foi gasta")

func test_the_cooldown_is_four_turns_counting_the_turn_of_use():
	var d := _retreat_scene()
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	assert_eq(int(d.unit.magic_cooldowns[RETREAT]), 5 + 4)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(d.unit, RETREAT), 4)
	d.unit.movement_left = 4.0
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, RETREAT, d.grid), "Retirada Tática já está ativa.", "no turno de uso o efeito ainda vale")
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(d.me)
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, RETREAT, d.grid), "Em recarga: 3 turno(s).", "o efeito expirou, a recarga segue")
	TurnManager.turn_number = 8
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, RETREAT, d.grid), "Em recarga: 1 turno(s).")
	TurnManager.turn_number = 9
	assert_true(V2TechniqueRuntime.can_use(d.unit, RETREAT, d.grid), "volta no turno T+4")

func test_it_costs_no_mana_and_no_gold():
	var d := _retreat_scene()
	d.me.gold = 50.0
	d.me.mana = 20.0
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	assert_eq(d.me.gold, 50.0)
	assert_eq(d.me.mana, 20.0)

func test_a_failed_use_changes_nothing():
	var d := _retreat_scene()
	_unit(d.grid, d.me, SHIELD, Vector2i(1, 0))
	_set_terrain(d.grid, Vector2i(0, 2), HexTileData.TerrainType.OCEAN)
	for bad in [Vector2i(4, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 2), Vector2i(500, 500)]:
		assert_false(V2TechniqueRuntime.relocate(d.unit, RETREAT, bad, d.grid), str(bad))
		assert_false(V2TechniqueRuntime.perform_targeted(d.unit, RETREAT, bad, d.grid), str(bad))
	assert_false(V2TechniqueRuntime.relocate(d.unit, CHARGE, Vector2i(-1, 0), d.grid), "não é técnica de reposicionamento")
	assert_false(V2TechniqueRuntime.relocate(d.unit, "v2_inexistente", Vector2i(-1, 0), d.grid))
	assert_eq(d.unit.coord, Vector2i(0, 0))
	assert_eq(d.unit.movement_left, 4.0)
	assert_false(d.unit.magic_cooldowns.has(RETREAT))
	assert_false(d.unit.magic_status.has(RETREAT))

func test_activate_refuses_it_because_it_needs_a_tile():
	var d := _retreat_scene()
	assert_false(V2TechniqueRuntime.activate(d.unit, RETREAT))
	assert_eq(d.unit.coord, Vector2i(0, 0))
	assert_false(d.unit.magic_cooldowns.has(RETREAT))

func test_the_entry_point_of_the_selection_takes_the_chosen_tile():
	var d := _retreat_scene()
	assert_true(V2TechniqueRuntime.perform_targeted(d.unit, RETREAT, Vector2i(-2, 0), d.grid))
	assert_eq(d.unit.coord, Vector2i(-2, 0))

func test_the_action_is_one_per_turn_no_charge_after_retreat_and_no_retreat_after_charge():
	var d := _retreat_scene()
	var foe := _foe(d.grid, d.rival, Vector2i(3, 0))
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	assert_false(V2TechniqueRuntime.can_use(d.unit, CHARGE, d.grid))
	var other := _retreat_scene()
	var target := _foe(other.grid, other.rival, Vector2i(3, 0))
	assert_true(V2TechniqueRuntime.perform_strike(other.unit, CHARGE, target, other.grid))
	assert_false(V2TechniqueRuntime.can_use(other.unit, RETREAT, other.grid))
	assert_not_null(foe)

# --- O efeito: +20% de Defesa até o próximo turno --------------------------------------------------------------------------------

func test_the_status_is_the_same_state_as_the_shield_wall_and_shows_as_active():
	var d := _retreat_scene()
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	assert_true(V2TechniqueRuntime.is_active(d.unit, RETREAT))
	assert_eq(V2TechniqueRuntime.active_technique_name(d.unit), "Retirada Tática")
	assert_eq(int(d.unit.magic_status[RETREAT]), 5 + V2TechniqueRuntime.ACTIVE_TURNS, "guardado em magic_status como as outras posturas")
	assert_true(V2TechniqueRuntime.status_lines(d.unit).any(func(l): return l.begins_with("Retirada Tática")))
	assert_not_null(d.unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME), "o anel de técnica ativa")

func test_the_active_unit_takes_less_damage_through_the_normal_defense_chain():
	var d := _retreat_scene()
	var foe := _foe(d.grid, d.rival, Vector2i(-3, 0), 40.0, 3.0)
	foe.unit_data.attack = 10.0
	var plain: float = CombatResolver.predict(foe, d.unit, d.grid).damage_to_defender
	assert_almost_eq(plain, maxf(1.0, 10.0 - 3.0 * 0.5), 0.0001, "pré-condição: Cavaleiro Defesa 3,0")
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	var with_retreat: float = CombatResolver.predict(foe, d.unit, d.grid).damage_to_defender
	assert_almost_eq(with_retreat, _formula_damage(d.grid, 10.0, 1.0, d.unit, 1.2), 0.0001, "+20% de Defesa")
	assert_lt(with_retreat, plain)

func test_real_resolution_matches_the_prediction_with_the_bonus():
	var d := _retreat_scene()
	var foe := _foe(d.grid, d.rival, Vector2i(-2, 0), 40.0, 3.0)
	foe.unit_data.attack = 10.0
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	var predicted: float = CombatResolver.predict(foe, d.unit, d.grid).damage_to_defender
	var hp: float = d.unit.hp
	CombatResolver.resolve(foe, d.unit, d.grid)
	assert_almost_eq(hp - d.unit.hp, predicted, 0.0001)

func test_the_bonus_lasts_until_the_owners_next_turn_and_then_expires():
	var d := _retreat_scene()
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	assert_eq(V2TechniqueRuntime.expire_finished(d.me), 0, "no turno de uso ainda vale")
	assert_true(V2TechniqueRuntime.is_active(d.unit, RETREAT))
	TurnManager.turn_number = 6 # o próximo turno do dono
	assert_eq(V2TechniqueRuntime.expire_finished(d.me), 1)
	assert_false(V2TechniqueRuntime.is_active(d.unit, RETREAT))
	assert_null(d.unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME), "o anel some")
	assert_eq(int(d.unit.magic_cooldowns[RETREAT]), 9, "a recarga continua contando")

func test_it_does_not_stack_with_itself_and_only_the_bearer_is_affected():
	var d := _retreat_scene()
	var ally := _unit(d.grid, d.me, CAVALIER, Vector2i(0, 1))
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-2, 0), d.grid))
	assert_eq(V2TechniqueRuntime.defense_multiplier(d.unit, d.grid), 1.2)
	assert_eq(V2TechniqueRuntime.defense_multiplier(ally, d.grid), 1.0, "ninguém ao redor recebe")
	d.unit.movement_left = 4.0
	d.unit.magic_cooldowns.erase(RETREAT)
	assert_false(V2TechniqueRuntime.can_use(d.unit, RETREAT, d.grid), "já ativa")
	assert_eq(V2TechniqueRuntime.unavailable_reason(d.unit, RETREAT, d.grid), "Retirada Tática já está ativa.")

func test_an_active_retreat_blocks_the_upgrade_like_any_other_technique_status():
	var grid := _world()
	var me := _cavalry_player(9)
	me.gold = 500.0
	var city := grid.found_city(Vector2i(0, 0), me, "Capital", true)
	city.buildings[C_STABLE] = true
	var unit := _unit(grid, me, CAVALIER, Vector2i(1, 0))
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SHOCK)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(me, unit, grid), "", "pré-condição: pode evoluir")
	assert_true(V2TechniqueRuntime.relocate(unit, RETREAT, Vector2i(0, 1), grid))
	unit.movement_left = 4.0 # (a ação também estaria gasta; aqui isolamos o motivo da técnica ativa)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(me, unit, grid), "Não pode evoluir com Retirada Tática ativa.")

func test_the_cooldown_and_the_status_live_on_the_unit_across_forms():
	var d := _retreat_scene(9)
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-1, 0), d.grid))
	var cooldown: int = d.unit.magic_cooldowns[RETREAT]
	d.unit.apply_form(UnitDatabase.create_unit(SHOCK))
	assert_eq(int(d.unit.magic_cooldowns[RETREAT]), cooldown)
	assert_true(V2TechniqueRuntime.is_active(d.unit, RETREAT))

func test_a_retreat_stance_does_not_change_the_attack_only_the_defense():
	var d := _retreat_scene()
	var foe := _foe(d.grid, d.rival, Vector2i(-3, 0), 40.0, 3.0)
	var before: float = CombatResolver.predict(d.unit, foe, d.grid).damage_to_defender
	assert_true(V2TechniqueRuntime.relocate(d.unit, RETREAT, Vector2i(-2, 0), d.grid))
	assert_eq(CombatResolver.predict(d.unit, foe, d.grid).damage_to_defender, before)

func test_no_technique_id_of_the_retreat_appears_in_the_generic_relocation_code():
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/world/HexGrid.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/core/CombatResolver.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		assert_false(source.contains("tactical_retreat"), path)
		assert_false(source.contains("Retirada"), path)

extends "res://test/unit/v2_combat_fixture.gd"

## Cavaleiro N3 / Cavaleiro de Choque N5 / Cavaleiro Blindado N7 (Aetherlands V2 Fase 9): a cadeia convencional da Doutrina da Cavalaria, treinada no
## Estábulo de Guerra, evoluída pelo MESMO V2UnitUpgrade das outras Doutrinas e ofertada pela MESMA V2UnitLine (resolve_trainable_form). Números =
## BALANCE PLACEHOLDER: os testes fixam também as RELAÇÕES e calculam custos pela fórmula.

## Cidade PRÓPRIA (registrada no grid, com território) em (0,0) com o Estábulo de Guerra e uma unidade `kind` no vizinho (1,0).
func _case(through: int, kind: String, with_stable: bool = true, gold: float = 200.0) -> Dictionary:
	var grid := _world(4)
	var player := _cavalry_player(through)
	player.gold = gold
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	if with_stable:
		city.buildings[C_STABLE] = true
	var unit := _unit(grid, player, kind, Vector2i(1, 0))
	return {"grid": grid, "player": player, "city": city, "unit": unit}

func _trainable_forms(city: City) -> Array:
	return [CAVALIER, SHOCK, ARMORED].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

# --- Definições -------------------------------------------------------------------------------------------------

func test_the_shock_cavalier_and_the_armored_cavalier_have_the_specified_baselines():
	var shock := UnitDatabase.create_unit(SHOCK)
	assert_eq(shock.unit_name, "Cavaleiro de Choque")
	assert_eq([shock.max_hp, shock.attack, shock.defense, shock.movement_points, shock.production_cost], [22.0, 7.0, 4.0, 4.0, 38.0])
	var armored := UnitDatabase.create_unit(ARMORED)
	assert_eq(armored.unit_name, "Cavaleiro Blindado")
	assert_eq([armored.max_hp, armored.attack, armored.defense, armored.movement_points, armored.production_cost], [30.0, 8.5, 6.0, 4.0, 56.0])
	for data in [shock, armored]:
		assert_eq(data.attack_range, 1, "corpo a corpo")
		assert_eq(data.vision_range, 4)
		assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY), "convencional, não Lendária")
		assert_false(data.has_trait(UnitData.TRAIT_FLYING))
		assert_true(data.has_trait(UnitData.TRAIT_MOUNTED))
		assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
		assert_eq(data.ranged_damage_taken_bonus, 0.0, "só o Grifo tem a vulnerabilidade")
		assert_false(data.can_found_city)

func test_the_progression_of_the_three_forms_is_monotonic_and_mobility_is_preserved():
	var forms := [CAVALIER, SHOCK, ARMORED].map(func(k): return UnitDatabase.create_unit(k))
	for i in range(1, forms.size()):
		assert_gt(forms[i].max_hp, forms[i - 1].max_hp)
		assert_gt(forms[i].attack, forms[i - 1].attack)
		assert_gt(forms[i].defense, forms[i - 1].defense)
		assert_gt(forms[i].production_cost, forms[i - 1].production_cost)
		assert_eq(forms[i].movement_points, 4.0, "mobilidade preservada nas três formas")
		assert_eq(forms[i].vision_range, 4)

func test_the_identity_is_mobility_and_shock_the_line_never_beats_the_defensive_and_melee_lines_at_their_own_job():
	var pairs := [[CAVALIER, WARRIOR, SHIELD], [SHOCK, SWORDSMAN, "v2_unit_guardian"], [ARMORED, MASTER, SENTINEL]]
	for pair in pairs:
		var cavalry := UnitDatabase.create_unit(pair[0])
		var melee := UnitDatabase.create_unit(pair[1])
		var tank := UnitDatabase.create_unit(pair[2])
		assert_eq(cavalry.movement_points, melee.movement_points * 2.0, "%s: o dobro do movimento" % pair[0])
		assert_lt(cavalry.defense, tank.defense, "%s defende menos que %s" % [pair[0], pair[2]])
		assert_lt(cavalry.max_hp, tank.max_hp + 0.001, "%s tem menos ou a mesma vida que %s" % [pair[0], pair[2]])
		assert_lte(cavalry.attack, melee.attack, "%s não ataca mais que %s" % [pair[0], pair[1]])

func test_the_armored_cavalier_never_exceeds_the_sentinel_defensively():
	var armored := UnitDatabase.create_unit(ARMORED)
	var sentinel := UnitDatabase.create_unit(SENTINEL)
	assert_lt(armored.defense, sentinel.defense)
	assert_lt(armored.max_hp, sentinel.max_hp)
	var grid := _world()
	var me := _cavalry_player(9)
	var other := _player(0, 9)
	var foe_data := UnitDatabase.create_unit("warrior")
	foe_data.attack = 12.0 # alto o bastante para o piso de dano (1) não esconder a diferença
	var foe := grid.spawn_unit(Vector2i(2, 0), foe_data, other)
	var a := _unit(grid, me, ARMORED, Vector2i(1, 0))
	var s := _unit(grid, other, SENTINEL, Vector2i(-2, 0))
	assert_gt(CombatResolver.predict(foe, a, grid).damage_to_defender, CombatResolver.predict(foe, s, grid).damage_to_defender, "leva mais dano que a Sentinela do mesmo golpe")

func test_the_armored_cavalier_is_a_conventional_elite_below_the_griffon_and_the_other_legendaries():
	var armored := UnitDatabase.create_unit(ARMORED)
	for legendary in [GRIFFON, CHAMPION, HERO, LEGEND_HUNTER]:
		var data := UnitDatabase.create_unit(legendary)
		assert_lt(armored.max_hp, data.max_hp + 0.001, legendary)
		assert_lt(armored.production_cost, data.production_cost, legendary)

func test_the_forms_are_registered_once_and_carry_distinct_provisional_scales():
	for kind in [CAVALIER, SHOCK, ARMORED, GRIFFON]:
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(kind), 1, kind)
		var data := UnitDatabase.create_unit(kind)
		assert_true(ResourceLoader.exists(data.model_scene_path) or data.model_scene_path == "", data.model_scene_path)
		for race in ["human", "elf", "dwarf", "orc"]:
			assert_eq(RaceTheme.unit_name(kind, race), data.unit_name, "%s (%s)" % [kind, race])
	var scales := [CAVALIER, SHOCK, ARMORED, GRIFFON].map(func(k): return UnitDatabase.create_unit(k).model_scale_multiplier)
	assert_eq(scales, [1.0, 1.15, 1.3, 1.4], "as formas se distinguem no mapa só pela escala (sem arte nova)")
	assert_eq(UnitDatabase.create_unit(CAVALIER).visual_template, "cavalry")
	assert_eq(UnitDatabase.create_unit(GRIFFON).visual_template, "griffin")

func test_v1_units_are_untouched():
	assert_ne(UnitDatabase.create_unit("cavalry").visual_kind, CAVALIER)
	assert_eq(UnitDatabase.create_unit("cavalry").visual_template, "", "V1 não usa o template")
	assert_true(UnitAbilities.is_mounted(UnitDatabase.create_unit("cavalry")))
	assert_eq(UnitDatabase.create_unit("cavalry").movement_profile, UnitData.MovementProfile.GROUND)

# --- Produção: só a forma normal mais avançada ----------------------------------------------------------------------

func test_the_stable_offers_exactly_one_form_at_every_research_level():
	var expected := {3: CAVALIER, 4: CAVALIER, 5: SHOCK, 6: SHOCK, 7: ARMORED, 8: ARMORED, 9: ARMORED}
	for through in expected:
		var city := _standalone_city(_cavalry_player(through), [C_STABLE])
		var offered := _trainable_forms(city)
		assert_eq(offered, [expected[through]], "até N%d" % through)
		assert_eq(offered.size(), 1, "nunca duas formas da linha ao mesmo tempo")

func test_before_n3_nothing_is_offered():
	assert_eq(_trainable_forms(_standalone_city(_cavalry_player(2), [C_STABLE])), [])

func test_the_griffon_is_never_part_of_the_chain_and_the_stable_never_trains_it():
	var city := _standalone_city(_cavalry_player(9), [C_STABLE])
	assert_false(city.can_train(GRIFFON), "só a Ordem da Cavalaria produz o Grifo")
	assert_eq(V2UnitLine.resolve_trainable_form(city.owner_player, CAVALIER), ARMORED, "a cadeia termina no Blindado")
	assert_eq(V2ResearchDatabase.node_for_unlock_id(ARMORED).upgrade_to, "", "o Blindado não evolui para o Grifo")

func test_production_costs_follow_the_form():
	var player := _cavalry_player(3)
	var city := _standalone_city(player, [C_STABLE])
	city.set_production(CAVALIER)
	assert_eq(city.production_cost(), 24.0, "Cavaleiro — 24 PP")
	player.v2_research.complete_research("v2_doctrine_cavalry_4")
	player.v2_research.complete_research("v2_doctrine_cavalry_5")
	city.set_production(SHOCK)
	assert_eq(city.production_cost(), 38.0, "Cavaleiro de Choque — 38 PP")
	player.v2_research.complete_research("v2_doctrine_cavalry_6")
	player.v2_research.complete_research("v2_doctrine_cavalry_7")
	city.set_production(ARMORED)
	assert_eq(city.production_cost(), 56.0, "Cavaleiro Blindado — 56 PP")

func test_the_form_still_needs_the_war_stable_never_the_v1_stable_the_barracks_or_the_other_halls():
	var player := _player(9, 9, 9, 9)
	# Aetherlands V2, Fase 15 — seis prédios com upkeep (§24-30) espalhados em duas cidades sem
	# Mercado e sem Ouro em caixa entrariam em Déficit sozinhos, bloqueando o treino por um motivo
	# alheio ao que este teste verifica (qual prédio treina a forma).
	player.gold = 1000.0
	var wrong := _standalone_city(player, ["stable", "barracks", G_HALL, W_HALL, R_CAMP, C_ORDER])
	assert_false(wrong.can_train(ARMORED), "nem o Estábulo V1, nem o Quartel, nem os outros Salões, nem a Ordem")
	assert_true(_standalone_city(player, [C_STABLE]).can_train(ARMORED))

func test_the_other_halls_do_not_train_the_cavalry_line_and_the_stable_trains_nothing_else():
	var player := _player(9, 9, 9, 9)
	for kind in [CAVALIER, SHOCK, ARMORED]:
		assert_false(_standalone_city(player, [G_HALL, W_HALL, R_CAMP]).can_train(kind), kind)
	var stable := _standalone_city(player, [C_STABLE])
	for kind in [WARRIOR, SHIELD, SENTINEL, ARCHER, MARKSMAN, HERO, CHAMPION]:
		assert_false(stable.can_train(kind), kind)

func test_two_civilizations_at_different_levels_get_different_forms():
	assert_eq(_trainable_forms(_standalone_city(_cavalry_player(3), [C_STABLE])), [CAVALIER])
	assert_eq(_trainable_forms(_standalone_city(_cavalry_player(7), [C_STABLE])), [ARMORED])

func test_debug_reset_keeps_what_exists_and_production_follows_the_research():
	var player := _cavalry_player(7)
	var city := _standalone_city(player, [C_STABLE])
	player.v2_research.reset()
	assert_true(city.buildings.has(C_STABLE))
	assert_eq(_trainable_forms(city), [])
	for n in range(1, 6):
		player.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	assert_eq(_trainable_forms(city), [SHOCK])

func test_an_ai_civilization_with_n7_resolves_the_armored_cavalier_without_breaking():
	var rival := _cavalry_player(7)
	var city := _standalone_city(rival, [C_STABLE])
	var offered := UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(ARMORED))
	assert_false(offered.has(CAVALIER))
	assert_false(offered.has(SHOCK))

# --- Upgrade Cavaleiro -> Cavaleiro de Choque (N5) ------------------------------------------------------------------

func test_the_first_upgrade_target_comes_from_the_metadata_and_the_cost_from_the_generic_formula():
	var c := _case(5, CAVALIER)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(CAVALIER).upgrade_to, SHOCK)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SHOCK)
	var expected := V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (UnitDatabase.create_unit(SHOCK).production_cost - UnitDatabase.create_unit(CAVALIER).production_cost)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), expected)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 28.0, "com os números atuais: 2 x (38 - 24)")

func test_the_first_upgrade_requirements_each_have_their_own_reason():
	var c := _case(5, CAVALIER)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "")

	var early := _case(4, CAVALIER)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(early.player, early.unit, early.grid), "Requer pesquisa: Cavaleiro de Choque.")

	var no_stable := _case(5, CAVALIER, false)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(no_stable.player, no_stable.unit, no_stable.grid), "Requer Estábulo de Guerra na cidade.")

	var outside := _case(5, CAVALIER)
	outside.grid.move_unit(outside.unit, Vector2i(4, 0), 1.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(outside.player, outside.unit, outside.grid), "Precisa estar em uma cidade própria.")

	var poor := _case(5, CAVALIER, true, 27.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(poor.player, poor.unit, poor.grid), "Ouro insuficiente (custa 28).")

	var spent := _case(5, CAVALIER)
	spent.unit.movement_left = 0.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(spent.player, spent.unit, spent.grid), "A unidade já agiu neste turno.")

func test_no_other_hall_satisfies_the_stable_requirement():
	var grid := _world(4)
	var player := _player(9, 9, 9, 5)
	player.gold = 200.0
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	city.buildings[G_HALL] = true
	city.buildings[W_HALL] = true
	city.buildings[R_CAMP] = true
	var unit := _unit(grid, player, CAVALIER, Vector2i(1, 0))
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(player, unit, grid), "Requer Estábulo de Guerra na cidade.")

func test_a_charge_never_blocks_an_upgrade_because_it_keeps_no_active_effect():
	var c := _case(6, CAVALIER)
	var rival := _rival_of(c.player)
	var foe := _foe(c.grid, rival, Vector2i(3, -1))
	var unit: Unit = c.unit
	# a Carga move a unidade; para evoluir ela volta à cidade no turno seguinte
	assert_true(V2TechniqueRuntime.perform_strike(unit, CHARGE, foe, c.grid))
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "")
	c.grid.move_unit(unit, Vector2i(1, 0), 0.0)
	TurnManager.turn_number = 6
	unit.movement_left = 4.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, unit, c.grid), "")

func test_the_first_upgrade_preserves_everything_that_does_not_depend_on_the_form():
	var c := _case(6, CAVALIER)
	var unit: Unit = c.unit
	unit.hp = 8.5 # 8,5/17 = 50%
	unit.kills = 3
	unit.veterancy_level = 2
	unit.magic_cooldowns[CHARGE] = 8 # Carga em recarga
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	var coord := unit.coord
	var count: int = c.player.units.size()
	var gold: float = c.player.gold

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))

	assert_eq(unit.unit_data.visual_kind, SHOCK)
	assert_eq(unit.get_instance_id(), id, "mesma unidade")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.coord, coord)
	assert_eq(unit.owner_player, c.player)
	assert_eq(c.player.units.size(), count, "sem duplicar")
	assert_eq(c.player.units.filter(func(u): return u.unit_data.visual_kind == CAVALIER).size(), 0, "sem Cavaleiro fantasma")
	assert_same(c.grid.get_unit_at(coord), unit)
	assert_almost_eq(unit.hp, 11.0, 0.0001, "50% de 22")
	assert_eq(unit.unit_data.max_hp, 22.0)
	assert_eq(unit.kills, 3, "abates/XP")
	assert_eq(unit.veterancy_level, 2, "veterania")
	assert_eq(int(unit.magic_cooldowns[CHARGE]), 8, "recarga preservada")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(c.player.gold, gold - 28.0, "Ouro descontado")
	assert_true(UnitAbilities.is_mounted(unit.unit_data), "o traço acompanha a forma nova")

func test_a_failed_upgrade_changes_nothing():
	var c := _case(4, CAVALIER)
	var gold: float = c.player.gold
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.unit.unit_data.visual_kind, CAVALIER)
	assert_eq(c.player.gold, gold)

# --- Upgrade Choque -> Blindado (N7) e cadeia completa --------------------------------------------------------------

func test_the_second_upgrade_cost_is_36_gold_by_the_formula():
	var c := _case(7, SHOCK)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(SHOCK).upgrade_to, ARMORED)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), ARMORED)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (56.0 - 38.0))
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 36.0)

func test_the_armored_cavalier_has_no_further_evolution_and_the_griffon_is_not_one():
	var c := _case(9, ARMORED)
	assert_eq(V2UnitUpgrade.get_upgrade_target(c.unit), "")
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), 0.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Esta unidade não tem evolução disponível.")
	var griffon := _case(9, GRIFFON)
	assert_eq(V2UnitUpgrade.get_upgrade_target(griffon.unit), "", "o Grifo não tem evolução")

func test_without_n7_the_shock_cavalier_cannot_become_armored():
	var c := _case(6, SHOCK)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Requer pesquisa: Cavaleiro Blindado.")

func test_the_full_chain_cavalier_shock_armored_on_the_same_unit_preserves_everything():
	var c := _case(7, CAVALIER)
	var unit: Unit = c.unit
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	unit.kills = 4
	unit.veterancy_level = 2
	unit.hp = 8.5 # 50% de 17
	unit.magic_cooldowns[RETREAT] = 9
	var gold: float = c.player.gold
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SHOCK, "um passo por vez")

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, SHOCK)
	assert_almost_eq(unit.hp, 11.0, 0.0001)
	assert_eq(c.player.gold, gold - 28.0)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, unit, c.grid), "sem ação neste turno")

	TurnManager.turn_number = 6
	unit.movement_left = 4.0
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, ARMORED)
	assert_almost_eq(unit.hp, 15.0, 0.0001, "50% de 30")
	assert_eq(c.player.gold, gold - 28.0 - 36.0)

	assert_eq(unit.get_instance_id(), id, "a MESMA unidade nas três formas")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.kills, 4)
	assert_eq(unit.veterancy_level, 2)
	assert_eq(int(unit.magic_cooldowns[RETREAT]), 9)
	assert_eq(c.player.units.size(), 1)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "", "fim da linha")

func test_an_active_retreat_status_survives_the_form_change_data_not_the_form():
	var c := _case(7, CAVALIER)
	var unit: Unit = c.unit
	unit.magic_status[RETREAT] = TurnManager.turn_number + V2TechniqueRuntime.ACTIVE_TURNS
	unit.apply_form(UnitDatabase.create_unit(SHOCK))
	assert_true(V2TechniqueRuntime.is_active(unit, RETREAT))

# --- Herança das Técnicas -------------------------------------------------------------------------------------------

func test_every_form_inherits_both_techniques_by_line_with_no_specific_code():
	var grid := _world()
	var me := _cavalry_player(9)
	var kinds := [CAVALIER, SHOCK, ARMORED]
	for i in kinds.size():
		var unit := _unit(grid, me, kinds[i], Vector2i(i, 0) if i == 0 else Vector2i(-i, 0))
		var ids: Array = V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id)
		assert_eq(ids.size(), 2, kinds[i])
		assert_true(CHARGE in ids and RETREAT in ids, kinds[i])

func test_the_techniques_need_their_own_research_even_for_the_elite_form():
	var grid := _world()
	var me := _cavalry_player(5) # sem N6
	var armored := _unit(grid, me, ARMORED, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(armored).map(func(t): return t.id), [CHARGE], "a Retirada só existe após o N6")
	var early := _unit(grid, _cavalry_player(3), CAVALIER, Vector2i(2, 2))
	assert_true(V2TechniqueRuntime.techniques_for_unit(early).is_empty(), "sem a Carga (N4) ainda")

func test_the_line_resolution_is_data_driven_from_the_branch_not_from_ids():
	assert_eq(V2UnitLine.doctrine_branch_of(CAVALIER), "cavalry")
	assert_eq(V2UnitLine.doctrine_branch_of(SHOCK), "cavalry")
	assert_eq(V2UnitLine.doctrine_branch_of(ARMORED), "cavalry")
	assert_eq(V2UnitLine.doctrine_branch_of(GRIFFON), "cavalry")
	assert_eq(V2UnitLine.doctrine_branch_of("cavalry"), "", "a Cavalaria V1 não pertence a nenhuma Doutrina")
	assert_eq(V2UnitLine.doctrine_branch_of(WARRIOR), "warrior")

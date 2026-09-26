extends "res://test/unit/v2_combat_fixture.gd"

## Catapulta N3 / Trebuchet N5 / Bombarda N7 (Aetherlands V2 Fase 11): a cadeia convencional da Doutrina de Cerco, treinada no Arsenal de Cerco,
## evoluída pelo MESMO V2UnitUpgrade das outras Doutrinas e ofertada pela MESMA V2UnitLine (resolve_trainable_form). Números fixos pelo pedido
## (não BALANCE PLACEHOLDER inventado): os testes fixam as RELAÇÕES e calculam custos pela fórmula.

## Cidade PRÓPRIA (registrada no grid, com território) em (0,0) com o Arsenal de Cerco e uma unidade `kind` no vizinho (1,0).
func _case(through: int, kind: String, with_arsenal: bool = true, gold: float = 200.0) -> Dictionary:
	var grid := _world(4)
	var player := _siege_player(through)
	player.gold = gold
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	if with_arsenal:
		city.buildings[SIEGE_ARSENAL] = true
	var unit := _unit(grid, player, kind, Vector2i(1, 0))
	return {"grid": grid, "player": player, "city": city, "unit": unit}

func _trainable_forms(city: City) -> Array:
	return [CATAPULT, TREBUCHET, BOMBARD].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

# --- Definições -------------------------------------------------------------------------------------------------

func test_the_trebuchet_and_the_bombard_have_the_specified_baselines():
	var trebuchet := UnitDatabase.create_unit(TREBUCHET)
	assert_eq(trebuchet.unit_name, "Trebuchet")
	assert_eq([trebuchet.max_hp, trebuchet.attack, trebuchet.defense, trebuchet.movement_points, trebuchet.attack_range, trebuchet.production_cost], [20.0, 5.0, 3.0, 2.0, 3, 44.0])
	var bombard := UnitDatabase.create_unit(BOMBARD)
	assert_eq(bombard.unit_name, "Bombarda")
	assert_eq([bombard.max_hp, bombard.attack, bombard.defense, bombard.movement_points, bombard.attack_range, bombard.production_cost], [26.0, 6.5, 4.0, 2.0, 3, 64.0])
	for data in [trebuchet, bombard]:
		assert_true(data.has_trait(UnitData.TRAIT_SIEGE))
		assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY), "convencional, não Lendária")
		assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
		assert_false(data.can_found_city)

func test_the_progression_of_the_three_forms_is_monotonic_and_movement_never_increases():
	var forms := [CATAPULT, TREBUCHET, BOMBARD].map(func(k): return UnitDatabase.create_unit(k))
	for i in range(1, forms.size()):
		assert_gt(forms[i].max_hp, forms[i - 1].max_hp)
		assert_gt(forms[i].attack, forms[i - 1].attack)
		assert_gt(forms[i].defense, forms[i - 1].defense)
		assert_gt(forms[i].production_cost, forms[i - 1].production_cost)
		assert_eq(forms[i].movement_points, 2.0, "movimento NUNCA aumenta — não é uma evolução de mobilidade")
	assert_eq(forms[0].attack_range, 2, "Catapulta: alcance básico")
	assert_eq(forms[1].attack_range, 3, "Trebuchet: +1 de alcance — o ganho principal")
	assert_eq(forms[2].attack_range, 3, "Bombarda: mesmo alcance do Trebuchet, mais poder por tile")

func test_the_bombard_stays_worse_than_the_equivalent_ranger_form_in_anti_unit_combat():
	var bombard := UnitDatabase.create_unit(BOMBARD)
	var marksman := UnitDatabase.create_unit(MARKSMAN)
	assert_lt(bombard.attack, marksman.attack, "a Bombarda não vira um tanque nem um duelista")
	var grid := _world()
	var me := _siege_player(9)
	var other := _player(9, 9, 9)
	var b := _unit(grid, me, BOMBARD, Vector2i(0, 0))
	var m := _unit(grid, other, MARKSMAN, Vector2i(2, 0))
	assert_lte(CombatResolver.predict(b, m, grid).damage_to_defender, CombatResolver.predict(m, b, grid).damage_to_defender, "não vence de frente pelos números, mesmo à mesma distância")

func test_the_forms_are_registered_once_and_carry_distinct_provisional_scales():
	for kind in [CATAPULT, TREBUCHET, BOMBARD, COLOSSUS]:
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(kind), 1, kind)
		var data := UnitDatabase.create_unit(kind)
		assert_eq(data.visual_template, "catapult", "as quatro reaproveitam o MESMO corpo procedural V1")
		for race in ["human", "elf", "dwarf", "orc"]:
			assert_eq(RaceTheme.unit_name(kind, race), data.unit_name, "%s (%s)" % [kind, race])
	var scales := [CATAPULT, TREBUCHET, BOMBARD, COLOSSUS].map(func(k): return UnitDatabase.create_unit(k).model_scale_multiplier)
	assert_eq(scales, [1.0, 1.15, 1.3, 1.5], "as formas se distinguem no mapa só pela escala (sem arte nova)")

func test_v1_units_are_untouched():
	assert_eq(UnitDatabase.create_unit("catapult").unit_name, "Catapulta")
	assert_ne(UnitDatabase.create_unit("catapult").visual_kind, CATAPULT, "kinds diferentes, mesmo nome de exibição")
	assert_eq(UnitDatabase.create_unit("catapult").attack, 6.0, "stats V1 intactos")

# --- Produção: só a forma normal mais avançada ----------------------------------------------------------------------

func test_the_arsenal_offers_exactly_one_form_at_every_research_level():
	var expected := {3: CATAPULT, 4: CATAPULT, 5: TREBUCHET, 6: TREBUCHET, 7: BOMBARD, 8: BOMBARD, 9: BOMBARD}
	for through in expected:
		var city := _standalone_city(_siege_player(through), [SIEGE_ARSENAL])
		var offered := _trainable_forms(city)
		assert_eq(offered, [expected[through]], "até N%d" % through)
		assert_eq(offered.size(), 1, "nunca duas formas da linha ao mesmo tempo")

func test_before_n3_nothing_is_offered():
	assert_eq(_trainable_forms(_standalone_city(_siege_player(2), [SIEGE_ARSENAL])), [])

func test_the_colossus_is_never_part_of_the_chain_and_the_arsenal_never_trains_it():
	var city := _standalone_city(_siege_player(9), [SIEGE_ARSENAL])
	assert_false(city.can_train(COLOSSUS), "só o Grande Arsenal produz o Colosso")
	assert_eq(V2UnitLine.resolve_trainable_form(city.owner_player, CATAPULT), BOMBARD, "a cadeia termina na Bombarda")
	assert_eq(V2ResearchDatabase.node_for_unlock_id(BOMBARD).upgrade_to, "", "a Bombarda não evolui para o Colosso")

func test_production_costs_follow_the_form():
	var player := _siege_player(3)
	var city := _standalone_city(player, [SIEGE_ARSENAL])
	city.set_production(CATAPULT)
	assert_eq(city.production_cost(), 28.0, "Catapulta — 28 PP")
	player.v2_research.complete_research("v2_doctrine_siege_4")
	player.v2_research.complete_research("v2_doctrine_siege_5")
	city.set_production(TREBUCHET)
	assert_eq(city.production_cost(), 44.0, "Trebuchet — 44 PP")
	player.v2_research.complete_research("v2_doctrine_siege_6")
	player.v2_research.complete_research("v2_doctrine_siege_7")
	city.set_production(BOMBARD)
	assert_eq(city.production_cost(), 64.0, "Bombarda — 64 PP")

func test_the_form_still_needs_the_arsenal_never_the_other_halls():
	var player := _player(9, 9, 9, 9, 9, 9)
	# Aetherlands V2, Fase 15 — vários prédios com upkeep (§24-30) sem Mercado e sem Ouro em caixa
	# entrariam em Déficit sozinhos, bloqueando o treino por um motivo alheio ao que este teste
	# verifica (qual prédio treina a forma).
	player.gold = 1000.0
	var wrong := _standalone_city(player, ["barracks", "siege_workshop", G_HALL, W_HALL, R_CAMP, C_STABLE, ROGUE_GUILD, GRAND_ARSENAL])
	assert_false(wrong.can_train(BOMBARD), "nem o Arsenal V1, nem os outros Salões, nem o Grande Arsenal")
	assert_true(_standalone_city(player, [SIEGE_ARSENAL]).can_train(BOMBARD))

func test_the_other_halls_do_not_train_the_siege_line_and_the_arsenal_trains_nothing_else():
	var player := _player(9, 9, 9, 9, 9, 9)
	for kind in [CATAPULT, TREBUCHET, BOMBARD]:
		assert_false(_standalone_city(player, [G_HALL, W_HALL, R_CAMP, C_STABLE, ROGUE_GUILD]).can_train(kind), kind)
	var arsenal := _standalone_city(player, [SIEGE_ARSENAL])
	for kind in [WARRIOR, SHIELD, SENTINEL, ARCHER, MARKSMAN, HERO, CHAMPION, CAVALIER, ROGUE, ASSASSIN]:
		assert_false(arsenal.can_train(kind), kind)

func test_two_civilizations_at_different_levels_get_different_forms():
	assert_eq(_trainable_forms(_standalone_city(_siege_player(3), [SIEGE_ARSENAL])), [CATAPULT])
	assert_eq(_trainable_forms(_standalone_city(_siege_player(7), [SIEGE_ARSENAL])), [BOMBARD])

func test_debug_reset_keeps_what_exists_and_production_follows_the_research():
	var player := _siege_player(7)
	var city := _standalone_city(player, [SIEGE_ARSENAL])
	player.v2_research.reset()
	assert_true(city.buildings.has(SIEGE_ARSENAL))
	assert_eq(_trainable_forms(city), [])
	for n in range(1, 6):
		player.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	assert_eq(_trainable_forms(city), [TREBUCHET])

func test_an_ai_civilization_with_n7_resolves_the_bombard_without_breaking():
	var rival := _siege_player(7)
	var city := _standalone_city(rival, [SIEGE_ARSENAL])
	var offered := UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(BOMBARD))
	assert_false(offered.has(CATAPULT))
	assert_false(offered.has(TREBUCHET))

# --- Upgrade Catapulta -> Trebuchet (N5) ------------------------------------------------------------------------

func test_the_first_upgrade_target_comes_from_the_metadata_and_the_cost_from_the_generic_formula():
	var c := _case(5, CATAPULT)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(CATAPULT).upgrade_to, TREBUCHET)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), TREBUCHET)
	var expected := V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (UnitDatabase.create_unit(TREBUCHET).production_cost - UnitDatabase.create_unit(CATAPULT).production_cost)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), expected)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 32.0, "com os números atuais: 2 x (44 - 28)")

func test_the_first_upgrade_requirements_each_have_their_own_reason():
	var c := _case(5, CATAPULT)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "")

	var early := _case(4, CATAPULT)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(early.player, early.unit, early.grid), "Requer pesquisa: Trebuchet.")

	var no_arsenal := _case(5, CATAPULT, false)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(no_arsenal.player, no_arsenal.unit, no_arsenal.grid), "Requer Arsenal de Cerco na cidade.")

	var outside := _case(5, CATAPULT)
	outside.grid.move_unit(outside.unit, Vector2i(4, 0), 1.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(outside.player, outside.unit, outside.grid), "Precisa estar em uma cidade própria.")

	var poor := _case(5, CATAPULT, true, 31.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(poor.player, poor.unit, poor.grid), "Ouro insuficiente (custa 32).")

	var spent := _case(5, CATAPULT)
	spent.unit.movement_left = 0.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(spent.player, spent.unit, spent.grid), "A unidade já agiu neste turno.")

func test_a_prepared_bombardment_never_blocks_an_upgrade_because_it_keeps_no_active_effect():
	var c := _case(6, CATAPULT) # N4 e N6 completos
	var rival := _rival_of(c.player)
	var city := _enemy_city(c.grid, rival, Vector2i(3, 0))
	var unit: Unit = c.unit
	assert_true(V2TechniqueRuntime.perform_city_strike(unit, PREPARED_BOMBARDMENT, city, c.grid))
	TurnManager.turn_number = 6
	unit.movement_left = 2.0
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "")
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, unit, c.grid), "")

func test_the_first_upgrade_preserves_everything_that_does_not_depend_on_the_form():
	var c := _case(6, CATAPULT)
	var unit: Unit = c.unit
	unit.hp = 8.0 # 8/16 = 50%
	unit.kills = 3
	unit.veterancy_level = 2
	unit.magic_cooldowns[PREPARED_BOMBARDMENT] = 8
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	var coord := unit.coord
	var count: int = c.player.units.size()
	var gold: float = c.player.gold

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))

	assert_eq(unit.unit_data.visual_kind, TREBUCHET)
	assert_eq(unit.get_instance_id(), id, "mesma unidade")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.coord, coord)
	assert_eq(unit.owner_player, c.player)
	assert_eq(c.player.units.size(), count, "sem duplicar")
	assert_eq(c.player.units.filter(func(u): return u.unit_data.visual_kind == CATAPULT).size(), 0, "sem Catapulta fantasma")
	assert_same(c.grid.get_unit_at(coord), unit)
	assert_almost_eq(unit.hp, 10.0, 0.0001, "50% de 20")
	assert_eq(unit.unit_data.max_hp, 20.0)
	assert_eq(unit.kills, 3, "abates/XP")
	assert_eq(unit.veterancy_level, 2, "veterania")
	assert_eq(int(unit.magic_cooldowns[PREPARED_BOMBARDMENT]), 8, "recarga preservada")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(c.player.gold, gold - 32.0, "Ouro descontado")

func test_a_failed_upgrade_changes_nothing():
	var c := _case(4, CATAPULT)
	var gold: float = c.player.gold
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.unit.unit_data.visual_kind, CATAPULT)
	assert_eq(c.player.gold, gold)

# --- Upgrade Trebuchet -> Bombarda (N7) e cadeia completa --------------------------------------------------------------

func test_the_second_upgrade_cost_is_40_gold_by_the_formula():
	var c := _case(7, TREBUCHET)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(TREBUCHET).upgrade_to, BOMBARD)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), BOMBARD)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (64.0 - 44.0))
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 40.0)

func test_the_bombard_has_no_further_evolution_and_the_colossus_is_not_one():
	var c := _case(9, BOMBARD)
	assert_eq(V2UnitUpgrade.get_upgrade_target(c.unit), "")
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), 0.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Esta unidade não tem evolução disponível.")
	var colossus := _case(9, COLOSSUS)
	assert_eq(V2UnitUpgrade.get_upgrade_target(colossus.unit), "", "o Colosso não tem evolução")

func test_without_n7_the_trebuchet_cannot_become_a_bombard():
	var c := _case(6, TREBUCHET)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Requer pesquisa: Bombarda.")

func test_the_full_chain_catapult_trebuchet_bombard_on_the_same_unit_preserves_everything():
	var c := _case(7, CATAPULT)
	var unit: Unit = c.unit
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	unit.kills = 4
	unit.veterancy_level = 2
	unit.hp = 8.0 # 50% de 16
	unit.magic_cooldowns[DEMOLITION_AMMO] = 9 # passiva: nunca guarda recarga, mas o dado aceita a chave sem quebrar
	var gold: float = c.player.gold
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), TREBUCHET, "um passo por vez")

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, TREBUCHET)
	assert_almost_eq(unit.hp, 10.0, 0.0001)
	assert_eq(c.player.gold, gold - 32.0)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, unit, c.grid), "sem ação neste turno")

	TurnManager.turn_number = 6
	unit.movement_left = 2.0
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, BOMBARD)
	assert_almost_eq(unit.hp, 13.0, 0.0001, "50% de 26")
	assert_eq(c.player.gold, gold - 32.0 - 40.0)

	assert_eq(unit.get_instance_id(), id, "a MESMA unidade nas três formas")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.kills, 4)
	assert_eq(unit.veterancy_level, 2)
	assert_eq(c.player.units.size(), 1)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "", "fim da linha")

# --- Herança das Técnicas -------------------------------------------------------------------------------------------

func test_every_form_inherits_both_techniques_by_line_with_no_specific_code():
	var grid := _world()
	var me := _siege_player(9)
	var kinds := [CATAPULT, TREBUCHET, BOMBARD]
	for i in kinds.size():
		var unit := _unit(grid, me, kinds[i], Vector2i(i, 0) if i == 0 else Vector2i(-i, 0))
		var ids: Array = V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id)
		assert_eq(ids.size(), 2, kinds[i])
		assert_true(DEMOLITION_AMMO in ids and PREPARED_BOMBARDMENT in ids, kinds[i])

func test_the_techniques_need_their_own_research_even_for_the_elite_form():
	var grid := _world()
	var me := _siege_player(5) # sem N6
	var bombard := _unit(grid, me, BOMBARD, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(bombard).map(func(t): return t.id), [DEMOLITION_AMMO], "Bombardeio Preparado só existe após o N6")
	var early := _unit(grid, _siege_player(3), CATAPULT, Vector2i(2, 2))
	assert_true(V2TechniqueRuntime.techniques_for_unit(early).is_empty(), "sem Munição Demolidora (N4) ainda")

func test_the_line_resolution_is_data_driven_from_the_branch_not_from_ids():
	assert_eq(V2UnitLine.doctrine_branch_of(CATAPULT), "siege")
	assert_eq(V2UnitLine.doctrine_branch_of(TREBUCHET), "siege")
	assert_eq(V2UnitLine.doctrine_branch_of(BOMBARD), "siege")
	assert_eq(V2UnitLine.doctrine_branch_of(COLOSSUS), "siege")
	assert_eq(V2UnitLine.doctrine_branch_of("catapult"), "", "a Catapulta V1 não pertence a nenhuma Doutrina")
	assert_eq(V2UnitLine.doctrine_branch_of(WARRIOR), "warrior")

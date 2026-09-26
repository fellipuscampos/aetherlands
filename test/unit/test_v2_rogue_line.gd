extends "res://test/unit/v2_combat_fixture.gd"

## Ladino N3 / Sabotador N5 / Assassino N7 (Aetherlands V2 Fase 10): a cadeia convencional da Doutrina do Ladino, treinada na Guilda dos Ladinos,
## evoluída pelo MESMO V2UnitUpgrade das outras Doutrinas e ofertada pela MESMA V2UnitLine (resolve_trainable_form). Números = BALANCE PLACEHOLDER:
## os testes fixam também as RELAÇÕES e calculam custos pela fórmula.

## Cidade PRÓPRIA (registrada no grid, com território) em (0,0) com a Guilda dos Ladinos e uma unidade `kind` no vizinho (1,0).
func _case(through: int, kind: String, with_guild: bool = true, gold: float = 200.0) -> Dictionary:
	var grid := _world(4)
	var player := _rogue_player(through)
	player.gold = gold
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	if with_guild:
		city.buildings[ROGUE_GUILD] = true
	var unit := _unit(grid, player, kind, Vector2i(1, 0))
	return {"grid": grid, "player": player, "city": city, "unit": unit}

func _trainable_forms(city: City) -> Array:
	return [ROGUE, SABOTEUR, ASSASSIN].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

# --- Definições -------------------------------------------------------------------------------------------------

func test_the_saboteur_and_the_assassin_have_the_specified_baselines():
	var saboteur := UnitDatabase.create_unit(SABOTEUR)
	assert_eq(saboteur.unit_name, "Sabotador")
	assert_eq([saboteur.max_hp, saboteur.attack, saboteur.defense, saboteur.movement_points, saboteur.production_cost], [18.0, 6.0, 3.0, 3.0, 32.0])
	var assassin := UnitDatabase.create_unit(ASSASSIN)
	assert_eq(assassin.unit_name, "Assassino")
	assert_eq([assassin.max_hp, assassin.attack, assassin.defense, assassin.movement_points, assassin.production_cost], [23.0, 8.0, 3.5, 3.0, 48.0])
	for data in [saboteur, assassin]:
		assert_eq(data.attack_range, 1, "corpo a corpo")
		assert_eq(data.vision_range, 4)
		assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY), "convencional, não Lendária")
		assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
		assert_false(data.can_found_city)

func test_the_progression_of_the_three_forms_is_monotonic_and_mobility_is_preserved():
	var forms := [ROGUE, SABOTEUR, ASSASSIN].map(func(k): return UnitDatabase.create_unit(k))
	for i in range(1, forms.size()):
		assert_gt(forms[i].max_hp, forms[i - 1].max_hp)
		assert_gt(forms[i].attack, forms[i - 1].attack)
		assert_gt(forms[i].defense, forms[i - 1].defense)
		assert_gt(forms[i].production_cost, forms[i - 1].production_cost)
		assert_eq(forms[i].movement_points, 3.0, "mobilidade preservada nas três formas")
		assert_eq(forms[i].vision_range, 4)

func test_the_assassin_never_beats_the_weapon_master_in_a_sustained_frontal_fight():
	var assassin := UnitDatabase.create_unit(ASSASSIN)
	var master := UnitDatabase.create_unit(MASTER)
	assert_lt(assassin.attack, master.attack, "menos Ataque")
	assert_lt(assassin.defense, master.defense, "MUITO menos Defesa")
	var grid := _world()
	var me := _rogue_player(9)
	var other := _player(9)
	var a := _unit(grid, me, ASSASSIN, Vector2i(0, 0))
	var m := _unit(grid, other, MASTER, Vector2i(1, 0))
	assert_lte(CombatResolver.predict(a, m, grid).damage_to_defender, CombatResolver.predict(m, a, grid).damage_to_defender, "não vence de frente pelos números")

func test_the_assassin_is_not_a_tank_it_is_never_the_best_defensive_form_of_any_line():
	var assassin := UnitDatabase.create_unit(ASSASSIN)
	for tank_kind in [SENTINEL, "v2_unit_armored_cavalier"]:
		var tank := UnitDatabase.create_unit(tank_kind)
		assert_lt(assassin.defense, tank.defense, tank_kind)
		assert_lt(assassin.max_hp, tank.max_hp, tank_kind)

func test_the_forms_are_registered_once_and_carry_distinct_provisional_scales():
	for kind in [ROGUE, SABOTEUR, ASSASSIN, SHADOW_MASTER]:
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(kind), 1, kind)
		var data := UnitDatabase.create_unit(kind)
		assert_true(ResourceLoader.exists(data.model_scene_path), data.model_scene_path)
		for race in ["human", "elf", "dwarf", "orc"]:
			assert_eq(RaceTheme.unit_name(kind, race), data.unit_name, "%s (%s)" % [kind, race])
	var scales := [ROGUE, SABOTEUR, ASSASSIN, SHADOW_MASTER].map(func(k): return UnitDatabase.create_unit(k).model_scale_multiplier)
	assert_eq(scales, [1.0, 1.15, 1.3, 1.45], "as formas se distinguem no mapa só pela escala (sem arte nova)")

func test_v1_units_are_untouched():
	assert_eq(UnitDatabase.create_unit("scout").unit_name, "Batedor")
	assert_ne(UnitDatabase.create_unit("scout").visual_kind, ROGUE)
	assert_eq(UnitDatabase.create_unit("scout").model_scene_path, "res://assets/models/kaykit/characters/Rogue.glb", "o Batedor V1 já usava o mesmo modelo, sem conflito")

# --- Produção: só a forma normal mais avançada ----------------------------------------------------------------------

func test_the_guild_offers_exactly_one_form_at_every_research_level():
	var expected := {3: ROGUE, 4: ROGUE, 5: SABOTEUR, 6: SABOTEUR, 7: ASSASSIN, 8: ASSASSIN, 9: ASSASSIN}
	for through in expected:
		var city := _standalone_city(_rogue_player(through), [ROGUE_GUILD])
		var offered := _trainable_forms(city)
		assert_eq(offered, [expected[through]], "até N%d" % through)
		assert_eq(offered.size(), 1, "nunca duas formas da linha ao mesmo tempo")

func test_before_n3_nothing_is_offered():
	assert_eq(_trainable_forms(_standalone_city(_rogue_player(2), [ROGUE_GUILD])), [])

func test_the_shadow_master_is_never_part_of_the_chain_and_the_guild_never_trains_it():
	var city := _standalone_city(_rogue_player(9), [ROGUE_GUILD])
	assert_false(city.can_train(SHADOW_MASTER), "só o Refúgio das Sombras produz o Mestre")
	assert_eq(V2UnitLine.resolve_trainable_form(city.owner_player, ROGUE), ASSASSIN, "a cadeia termina no Assassino")
	assert_eq(V2ResearchDatabase.node_for_unlock_id(ASSASSIN).upgrade_to, "", "o Assassino não evolui para o Mestre")

func test_production_costs_follow_the_form():
	var player := _rogue_player(3)
	var city := _standalone_city(player, [ROGUE_GUILD])
	city.set_production(ROGUE)
	assert_eq(city.production_cost(), 20.0, "Ladino — 20 PP")
	player.v2_research.complete_research("v2_doctrine_rogue_4")
	player.v2_research.complete_research("v2_doctrine_rogue_5")
	city.set_production(SABOTEUR)
	assert_eq(city.production_cost(), 32.0, "Sabotador — 32 PP")
	player.v2_research.complete_research("v2_doctrine_rogue_6")
	player.v2_research.complete_research("v2_doctrine_rogue_7")
	city.set_production(ASSASSIN)
	assert_eq(city.production_cost(), 48.0, "Assassino — 48 PP")

func test_the_form_still_needs_the_guild_never_the_other_halls():
	var player := _player(9, 9, 9, 9, 9)
	# Aetherlands V2, Fase 15 — vários prédios com upkeep (§24-30) sem Mercado e sem Ouro em caixa
	# entrariam em Déficit sozinhos, bloqueando o treino por um motivo alheio ao que este teste
	# verifica (qual prédio treina a forma).
	player.gold = 1000.0
	var wrong := _standalone_city(player, ["barracks", G_HALL, W_HALL, R_CAMP, C_STABLE, ROGUE_MASTERY])
	assert_false(wrong.can_train(ASSASSIN), "nem o Quartel, nem os outros Salões, nem o Refúgio")
	assert_true(_standalone_city(player, [ROGUE_GUILD]).can_train(ASSASSIN))

func test_the_other_halls_do_not_train_the_rogue_line_and_the_guild_trains_nothing_else():
	var player := _player(9, 9, 9, 9, 9)
	for kind in [ROGUE, SABOTEUR, ASSASSIN]:
		assert_false(_standalone_city(player, [G_HALL, W_HALL, R_CAMP, C_STABLE]).can_train(kind), kind)
	var guild := _standalone_city(player, [ROGUE_GUILD])
	for kind in [WARRIOR, SHIELD, SENTINEL, ARCHER, MARKSMAN, HERO, CHAMPION, CAVALIER]:
		assert_false(guild.can_train(kind), kind)

func test_two_civilizations_at_different_levels_get_different_forms():
	assert_eq(_trainable_forms(_standalone_city(_rogue_player(3), [ROGUE_GUILD])), [ROGUE])
	assert_eq(_trainable_forms(_standalone_city(_rogue_player(7), [ROGUE_GUILD])), [ASSASSIN])

func test_debug_reset_keeps_what_exists_and_production_follows_the_research():
	var player := _rogue_player(7)
	var city := _standalone_city(player, [ROGUE_GUILD])
	player.v2_research.reset()
	assert_true(city.buildings.has(ROGUE_GUILD))
	assert_eq(_trainable_forms(city), [])
	for n in range(1, 6):
		player.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	assert_eq(_trainable_forms(city), [SABOTEUR])

func test_an_ai_civilization_with_n7_resolves_the_assassin_without_breaking():
	var rival := _rogue_player(7)
	var city := _standalone_city(rival, [ROGUE_GUILD])
	var offered := UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(ASSASSIN))
	assert_false(offered.has(ROGUE))
	assert_false(offered.has(SABOTEUR))

# --- Upgrade Ladino -> Sabotador (N5) ------------------------------------------------------------------------

func test_the_first_upgrade_target_comes_from_the_metadata_and_the_cost_from_the_generic_formula():
	var c := _case(5, ROGUE)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(ROGUE).upgrade_to, SABOTEUR)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SABOTEUR)
	var expected := V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (UnitDatabase.create_unit(SABOTEUR).production_cost - UnitDatabase.create_unit(ROGUE).production_cost)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), expected)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 24.0, "com os números atuais: 2 x (32 - 20)")

func test_the_first_upgrade_requirements_each_have_their_own_reason():
	var c := _case(5, ROGUE)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "")

	var early := _case(4, ROGUE)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(early.player, early.unit, early.grid), "Requer pesquisa: Sabotador.")

	var no_guild := _case(5, ROGUE, false)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(no_guild.player, no_guild.unit, no_guild.grid), "Requer Guilda dos Ladinos na cidade.")

	var outside := _case(5, ROGUE)
	outside.grid.move_unit(outside.unit, Vector2i(4, 0), 1.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(outside.player, outside.unit, outside.grid), "Precisa estar em uma cidade própria.")

	var poor := _case(5, ROGUE, true, 23.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(poor.player, poor.unit, poor.grid), "Ouro insuficiente (custa 24).")

	var spent := _case(5, ROGUE)
	spent.unit.movement_left = 0.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(spent.player, spent.unit, spent.grid), "A unidade já agiu neste turno.")

func test_no_other_hall_satisfies_the_guild_requirement():
	var grid := _world(4)
	var player := _player(9, 9, 9, 9, 5)
	player.gold = 200.0
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	city.buildings[G_HALL] = true
	city.buildings[W_HALL] = true
	city.buildings[R_CAMP] = true
	city.buildings[C_STABLE] = true
	var unit := _unit(grid, player, ROGUE, Vector2i(1, 0))
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(player, unit, grid), "Requer Guilda dos Ladinos na cidade.")

func test_a_sneak_attack_never_blocks_an_upgrade_because_it_keeps_no_active_effect():
	var c := _case(6, ROGUE)
	var rival := _rival_of(c.player)
	var foe := _foe(c.grid, rival, Vector2i(2, 0)) # adjacente ao Ladino em (1,0)
	var unit: Unit = c.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, foe, c.grid))
	TurnManager.turn_number = 6
	unit.movement_left = 3.0
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "")
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, unit, c.grid), "")

func test_the_first_upgrade_preserves_everything_that_does_not_depend_on_the_form():
	var c := _case(6, ROGUE)
	var unit: Unit = c.unit
	unit.hp = 7.0 # 7/14 = 50%
	unit.kills = 3
	unit.veterancy_level = 2
	unit.magic_cooldowns[SNEAK_ATTACK] = 8 # Ataque Furtivo em recarga
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	var coord := unit.coord
	var count: int = c.player.units.size()
	var gold: float = c.player.gold

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))

	assert_eq(unit.unit_data.visual_kind, SABOTEUR)
	assert_eq(unit.get_instance_id(), id, "mesma unidade")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.coord, coord)
	assert_eq(unit.owner_player, c.player)
	assert_eq(c.player.units.size(), count, "sem duplicar")
	assert_eq(c.player.units.filter(func(u): return u.unit_data.visual_kind == ROGUE).size(), 0, "sem Ladino fantasma")
	assert_same(c.grid.get_unit_at(coord), unit)
	assert_almost_eq(unit.hp, 9.0, 0.0001, "50% de 18")
	assert_eq(unit.unit_data.max_hp, 18.0)
	assert_eq(unit.kills, 3, "abates/XP")
	assert_eq(unit.veterancy_level, 2, "veterania")
	assert_eq(int(unit.magic_cooldowns[SNEAK_ATTACK]), 8, "recarga preservada")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(c.player.gold, gold - 24.0, "Ouro descontado")

func test_a_failed_upgrade_changes_nothing():
	var c := _case(4, ROGUE)
	var gold: float = c.player.gold
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.unit.unit_data.visual_kind, ROGUE)
	assert_eq(c.player.gold, gold)

# --- Upgrade Sabotador -> Assassino (N7) e cadeia completa --------------------------------------------------------------

func test_the_second_upgrade_cost_is_32_gold_by_the_formula():
	var c := _case(7, SABOTEUR)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(SABOTEUR).upgrade_to, ASSASSIN)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), ASSASSIN)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (48.0 - 32.0))
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 32.0)

func test_the_assassin_has_no_further_evolution_and_the_shadow_master_is_not_one():
	var c := _case(9, ASSASSIN)
	assert_eq(V2UnitUpgrade.get_upgrade_target(c.unit), "")
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), 0.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Esta unidade não tem evolução disponível.")
	var shadow := _case(9, SHADOW_MASTER)
	assert_eq(V2UnitUpgrade.get_upgrade_target(shadow.unit), "", "o Mestre não tem evolução")

func test_without_n7_the_saboteur_cannot_become_an_assassin():
	var c := _case(6, SABOTEUR)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Requer pesquisa: Assassino.")

func test_the_full_chain_rogue_saboteur_assassin_on_the_same_unit_preserves_everything():
	var c := _case(7, ROGUE)
	var unit: Unit = c.unit
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	unit.kills = 4
	unit.veterancy_level = 2
	unit.hp = 7.0 # 50% de 14
	unit.magic_cooldowns[DISMANTLE] = 9 # passiva: nunca guarda recarga, mas o dado aceita a chave sem quebrar
	var gold: float = c.player.gold
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SABOTEUR, "um passo por vez")

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, SABOTEUR)
	assert_almost_eq(unit.hp, 9.0, 0.0001)
	assert_eq(c.player.gold, gold - 24.0)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, unit, c.grid), "sem ação neste turno")

	TurnManager.turn_number = 6
	unit.movement_left = 3.0
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, ASSASSIN)
	assert_almost_eq(unit.hp, 11.5, 0.0001, "50% de 23")
	assert_eq(c.player.gold, gold - 24.0 - 32.0)

	assert_eq(unit.get_instance_id(), id, "a MESMA unidade nas três formas")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.kills, 4)
	assert_eq(unit.veterancy_level, 2)
	assert_eq(c.player.units.size(), 1)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "", "fim da linha")

# --- Herança das Técnicas -------------------------------------------------------------------------------------------

func test_every_form_inherits_both_techniques_by_line_with_no_specific_code():
	var grid := _world()
	var me := _rogue_player(9)
	var kinds := [ROGUE, SABOTEUR, ASSASSIN]
	for i in kinds.size():
		var unit := _unit(grid, me, kinds[i], Vector2i(i, 0) if i == 0 else Vector2i(-i, 0))
		var ids: Array = V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id)
		assert_eq(ids.size(), 2, kinds[i])
		assert_true(SNEAK_ATTACK in ids and DISMANTLE in ids, kinds[i])

func test_the_techniques_need_their_own_research_even_for_the_elite_form():
	var grid := _world()
	var me := _rogue_player(5) # sem N6
	var assassin := _unit(grid, me, ASSASSIN, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(assassin).map(func(t): return t.id), [SNEAK_ATTACK], "Desmantelar só existe após o N6")
	var early := _unit(grid, _rogue_player(3), ROGUE, Vector2i(2, 2))
	assert_true(V2TechniqueRuntime.techniques_for_unit(early).is_empty(), "sem o Ataque Furtivo (N4) ainda")

func test_the_line_resolution_is_data_driven_from_the_branch_not_from_ids():
	assert_eq(V2UnitLine.doctrine_branch_of(ROGUE), "rogue")
	assert_eq(V2UnitLine.doctrine_branch_of(SABOTEUR), "rogue")
	assert_eq(V2UnitLine.doctrine_branch_of(ASSASSIN), "rogue")
	assert_eq(V2UnitLine.doctrine_branch_of(SHADOW_MASTER), "rogue")
	assert_eq(V2UnitLine.doctrine_branch_of("scout"), "", "o Batedor V1 não pertence a nenhuma Doutrina")
	assert_eq(V2UnitLine.doctrine_branch_of(WARRIOR), "warrior")

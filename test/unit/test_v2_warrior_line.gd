extends "res://test/unit/v2_combat_fixture.gd"

## Guerreiro N3 / Espadachim N5 / Mestre de Armas N7 (Aetherlands V2 Fase 7): a cadeia convencional da Doutrina do Guerreiro,
## treinada no Salão de Armas, evoluída pelo MESMO V2UnitUpgrade do Guardião e ofertada pela MESMA V2UnitLine
## (resolve_trainable_form). Números = BALANCE PLACEHOLDER: os testes fixam também as RELAÇÕES e calculam custos pela fórmula.

## Cidade PRÓPRIA (registrada no grid, com território) em (0,0) com o Salão de Armas e uma unidade `kind` no vizinho (1,0).
func _case(through: int, kind: String, with_hall: bool = true, gold: float = 200.0) -> Dictionary:
	var grid := _world(4)
	var player := _player(through)
	player.gold = gold
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	if with_hall:
		city.buildings[W_HALL] = true
	var unit := _unit(grid, player, kind, Vector2i(1, 0))
	return {"grid": grid, "player": player, "city": city, "unit": unit}

func _trainable_forms(city: City) -> Array:
	return [WARRIOR, SWORDSMAN, MASTER].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

# --- Definições -------------------------------------------------------------------------------------------------

func test_the_warrior_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(WARRIOR)
	assert_eq(data.unit_name, "Guerreiro")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points], [16.0, 5.0, 3.5, 2.0])
	assert_eq(data.vision_range, 3)
	assert_eq(data.attack_range, 1, "corpo a corpo")
	assert_eq(data.production_cost, 20.0)
	assert_eq(data.visual_kind, WARRIOR, "o SaveManager recria a unidade por ele")
	assert_false(data.can_found_city)
	assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY))

func test_the_swordsman_and_the_weapon_master_have_the_specified_baselines():
	var swordsman := UnitDatabase.create_unit(SWORDSMAN)
	assert_eq(swordsman.unit_name, "Espadachim")
	assert_eq([swordsman.max_hp, swordsman.attack, swordsman.defense, swordsman.movement_points, swordsman.production_cost], [21.0, 7.0, 4.5, 2.0, 32.0])
	var master := UnitDatabase.create_unit(MASTER)
	assert_eq(master.unit_name, "Mestre de Armas")
	assert_eq([master.max_hp, master.attack, master.defense, master.movement_points, master.production_cost], [28.0, 9.5, 5.5, 2.0, 48.0])
	for data in [swordsman, master]:
		assert_eq(data.attack_range, 1)
		assert_eq(data.vision_range, 3)
		assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY), "convencional, não Lendário")

func test_the_progression_of_the_three_forms_is_monotonic():
	var forms := [WARRIOR, SWORDSMAN, MASTER].map(func(k): return UnitDatabase.create_unit(k))
	for i in range(1, forms.size()):
		assert_gt(forms[i].max_hp, forms[i - 1].max_hp)
		assert_gt(forms[i].attack, forms[i - 1].attack)
		assert_gt(forms[i].defense, forms[i - 1].defense)
		assert_gt(forms[i].production_cost, forms[i - 1].production_cost)
		assert_eq(forms[i].movement_points, forms[i - 1].movement_points, "sem ganhar mobilidade")

func test_the_identity_is_damage_the_guardian_wins_resilience_and_the_warrior_wins_damage_on_every_tier():
	var pairs := [[WARRIOR, SHIELD], [SWORDSMAN, "v2_unit_guardian"], [MASTER, SENTINEL]]
	for pair in pairs:
		var warrior_form := UnitDatabase.create_unit(pair[0])
		var guardian_form := UnitDatabase.create_unit(pair[1])
		assert_gt(warrior_form.attack, guardian_form.attack, "%s ataca mais que %s" % [pair[0], pair[1]])
		assert_lt(warrior_form.defense, guardian_form.defense, "%s defende menos" % pair[0])
		assert_lt(warrior_form.max_hp, guardian_form.max_hp + 0.001, "%s tem menos ou a mesma vida" % pair[0])
	assert_eq([UnitDatabase.create_unit(SHIELD).max_hp, UnitDatabase.create_unit(SHIELD).attack, UnitDatabase.create_unit(SHIELD).defense], [18.0, 3.0, 4.5], "o contraste citado no pedido: Escudeiro")

func test_the_weapon_master_is_an_advanced_melee_not_a_glass_cannon():
	var master := UnitDatabase.create_unit(MASTER)
	var sentinel := UnitDatabase.create_unit(SENTINEL)
	assert_gt(master.attack, sentinel.attack, "mais Ataque que a Sentinela")
	assert_lt(master.defense, sentinel.defense, "menos Defesa que a Sentinela")
	assert_gt(master.max_hp, UnitDatabase.create_unit(SWORDSMAN).max_hp)
	assert_gt(master.max_hp * master.defense, 100.0, "resistência suficiente para o corpo a corpo")

func test_the_forms_are_registered_once_and_carry_distinct_provisional_scales():
	for kind in [WARRIOR, SWORDSMAN, MASTER, HERO]:
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(kind), 1, kind)
		var data := UnitDatabase.create_unit(kind)
		assert_true(ResourceLoader.exists(data.model_scene_path), data.model_scene_path)
		assert_true(ResourceLoader.exists(data.animation_scene_path), data.animation_scene_path)
		for race in ["human", "elf", "dwarf", "orc"]:
			assert_eq(RaceTheme.unit_name(kind, race), data.unit_name, "%s (%s)" % [kind, race])
	var scales := [WARRIOR, SWORDSMAN, MASTER, HERO].map(func(k): return UnitDatabase.create_unit(k).model_scale_multiplier)
	assert_eq(scales, [1.0, 1.15, 1.3, 1.65], "as quatro formas se distinguem no mapa só pela escala (sem arte nova)")

func test_v1_units_are_untouched():
	assert_eq(UnitDatabase.create_unit("warrior").unit_name, "Guarda")
	assert_eq(UnitDatabase.create_unit("warrior").attack, 4.0)
	assert_eq(UnitDatabase.create_unit("espadachim").production_cost, 26.0, "o Espadachim V1 é outra unidade")
	assert_ne(UnitDatabase.create_unit("espadachim").visual_kind, SWORDSMAN)

# --- Produção: só a forma normal mais avançada ----------------------------------------------------------------------

func test_the_hall_offers_exactly_one_form_at_every_research_level():
	var expected := {3: WARRIOR, 4: WARRIOR, 5: SWORDSMAN, 6: SWORDSMAN, 7: MASTER, 8: MASTER, 9: MASTER}
	for through in expected:
		var city := _standalone_city(_player(through), [W_HALL])
		var offered := _trainable_forms(city)
		assert_eq(offered, [expected[through]], "até N%d" % through)
		assert_eq(offered.size(), 1, "nunca duas formas da linha ao mesmo tempo")

func test_before_n3_nothing_is_offered():
	assert_eq(_trainable_forms(_standalone_city(_player(2), [W_HALL])), [])

func test_production_costs_follow_the_form():
	var player := _player(3)
	var city := _standalone_city(player, [W_HALL])
	city.set_production(WARRIOR)
	assert_eq(city.production_cost(), 20.0, "Guerreiro — 20 PP")
	player.v2_research.complete_research("v2_doctrine_warrior_4")
	player.v2_research.complete_research("v2_doctrine_warrior_5")
	city.set_production(SWORDSMAN)
	assert_eq(city.production_cost(), 32.0, "Espadachim — 32 PP")
	player.v2_research.complete_research("v2_doctrine_warrior_6")
	player.v2_research.complete_research("v2_doctrine_warrior_7")
	city.set_production(MASTER)
	assert_eq(city.production_cost(), 48.0, "Mestre de Armas — 48 PP")

func test_the_form_still_needs_the_weapons_hall_never_the_v1_barracks_the_guardian_hall_or_the_arena():
	var player := _player(9, 9)
	var wrong := _standalone_city(player, [G_HALL, G_MASTERY, "barracks"])
	assert_false(wrong.can_train(MASTER), "nem o Quartel, nem o Salão dos Guardiões, nem o Bastião")
	var hall_only := _standalone_city(player, [W_HALL])
	assert_true(hall_only.can_train(MASTER), "só o Salão de Armas, sem a Arena")
	var arena_only := _standalone_city(player, [ARENA])
	assert_false(arena_only.can_train(MASTER), "a Arena não treina a cadeia convencional")

func test_the_guardian_hall_does_not_train_the_warrior_line_and_the_weapons_hall_does_not_train_the_guardians():
	var player := _player(9, 9)
	assert_false(_standalone_city(player, [G_HALL]).can_train(WARRIOR))
	assert_false(_standalone_city(player, [W_HALL]).can_train(SHIELD))
	assert_false(_standalone_city(player, [W_HALL]).can_train(SENTINEL))

func test_two_civilizations_at_different_levels_get_different_forms():
	assert_eq(_trainable_forms(_standalone_city(_player(3), [W_HALL])), [WARRIOR])
	assert_eq(_trainable_forms(_standalone_city(_player(7), [W_HALL])), [MASTER])

func test_debug_reset_keeps_what_exists_and_production_follows_the_research():
	var player := _player(7)
	var city := _standalone_city(player, [W_HALL])
	player.v2_research.reset()
	assert_true(city.buildings.has(W_HALL))
	assert_eq(_trainable_forms(city), [])
	for n in range(1, 6):
		player.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	assert_eq(_trainable_forms(city), [SWORDSMAN])

func test_an_ai_civilization_with_n7_resolves_the_weapon_master_without_breaking():
	var rival := _player(7)
	var city := _standalone_city(rival, [W_HALL])
	var offered := UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(MASTER))
	assert_false(offered.has(WARRIOR))
	assert_false(offered.has(SWORDSMAN))

# --- Upgrade Guerreiro -> Espadachim (N5) ---------------------------------------------------------------------------

func test_the_first_upgrade_target_comes_from_the_metadata_and_the_cost_from_the_generic_formula():
	var c := _case(5, WARRIOR)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(WARRIOR).upgrade_to, SWORDSMAN)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SWORDSMAN)
	var expected := V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (UnitDatabase.create_unit(SWORDSMAN).production_cost - UnitDatabase.create_unit(WARRIOR).production_cost)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), expected)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 24.0, "com os números atuais: 2 x (32 - 20)")

func test_the_first_upgrade_requirements_each_have_their_own_reason():
	var c := _case(5, WARRIOR)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "")

	var early := _case(4, WARRIOR)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(early.player, early.unit, early.grid), "Requer pesquisa: Espadachim.")

	var no_hall := _case(5, WARRIOR, false)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(no_hall.player, no_hall.unit, no_hall.grid), "Requer Salão de Armas na cidade.")

	var outside := _case(5, WARRIOR)
	outside.grid.move_unit(outside.unit, Vector2i(4, 0), 1.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(outside.player, outside.unit, outside.grid), "Precisa estar em uma cidade própria.")

	var poor := _case(5, WARRIOR, true, 23.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(poor.player, poor.unit, poor.grid), "Ouro insuficiente (custa 24).")

	var spent := _case(5, WARRIOR)
	spent.unit.movement_left = 0.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(spent.player, spent.unit, spent.grid), "A unidade já agiu neste turno.")

func test_the_guardian_hall_does_not_satisfy_the_weapons_hall_requirement():
	var grid := _world(4)
	var player := _player(5, 9)
	player.gold = 200.0
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	city.buildings[G_HALL] = true
	var unit := _unit(grid, player, WARRIOR, Vector2i(1, 0))
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(player, unit, grid), "Requer Salão de Armas na cidade.")

func test_a_strike_technique_never_blocks_an_upgrade_because_it_keeps_no_active_effect():
	var c := _case(6, WARRIOR)
	var rival := _rival_of(c.player)
	var foe := _foe(c.grid, rival, Vector2i(2, 0)) # adjacente ao Guerreiro em (1,0)
	var unit: Unit = c.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, foe, c.grid))
	# No turno seguinte a ação volta; só a recarga do Golpe fica (não há efeito "ativo" a impedir a evolução).
	TurnManager.turn_number = 6
	unit.movement_left = 2.0
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "")
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, unit, c.grid), "")

func test_the_first_upgrade_preserves_everything_that_does_not_depend_on_the_form():
	var c := _case(6, WARRIOR)
	var unit: Unit = c.unit
	unit.hp = 8.0 # 8/16 = 50%
	unit.kills = 3
	unit.veterancy_level = 2
	unit.magic_cooldowns[POWER] = 8 # Golpe Poderoso em recarga
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	var coord := unit.coord
	var count: int = c.player.units.size()
	var gold: float = c.player.gold

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))

	assert_eq(unit.unit_data.visual_kind, SWORDSMAN)
	assert_eq(unit.get_instance_id(), id, "mesma unidade")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.coord, coord)
	assert_eq(unit.owner_player, c.player)
	assert_eq(c.player.units.size(), count, "sem duplicar")
	assert_eq(c.player.units.filter(func(u): return u.unit_data.visual_kind == WARRIOR).size(), 0, "sem Guerreiro fantasma")
	assert_same(c.grid.get_unit_at(coord), unit)
	assert_almost_eq(unit.hp, 10.5, 0.0001, "50% de 21")
	assert_eq(unit.unit_data.max_hp, 21.0)
	assert_eq(unit.kills, 3, "abates/XP")
	assert_eq(unit.veterancy_level, 2, "veterania")
	assert_eq(int(unit.magic_cooldowns[POWER]), 8, "recarga preservada")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(c.player.gold, gold - 24.0, "Ouro descontado")

func test_a_failed_upgrade_changes_nothing():
	var c := _case(4, WARRIOR)
	var gold: float = c.player.gold
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.unit.unit_data.visual_kind, WARRIOR)
	assert_eq(c.player.gold, gold)

# --- Upgrade Espadachim -> Mestre de Armas (N7) e cadeia completa ---------------------------------------------------

func test_the_second_upgrade_cost_is_32_gold_by_the_formula():
	var c := _case(7, SWORDSMAN)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(SWORDSMAN).upgrade_to, MASTER)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), MASTER)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (48.0 - 32.0))
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 32.0)

func test_the_weapon_master_has_no_further_evolution_and_the_hero_is_not_one():
	var c := _case(9, MASTER)
	assert_eq(V2UnitUpgrade.get_upgrade_target(c.unit), "")
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), 0.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Esta unidade não tem evolução disponível.")

func test_without_n7_the_swordsman_cannot_become_a_master():
	var c := _case(6, SWORDSMAN)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Requer pesquisa: Mestre de Armas.")

func test_the_full_chain_warrior_swordsman_master_on_the_same_unit_preserves_everything():
	var c := _case(7, WARRIOR)
	var unit: Unit = c.unit
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	unit.kills = 4
	unit.veterancy_level = 2
	unit.hp = 8.0 # 50% de 16
	unit.magic_cooldowns[CLEAVE] = 9
	var gold: float = c.player.gold
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SWORDSMAN, "um passo por vez")

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, SWORDSMAN)
	assert_almost_eq(unit.hp, 10.5, 0.0001)
	assert_eq(c.player.gold, gold - 24.0)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, unit, c.grid), "sem ação neste turno")

	TurnManager.turn_number = 6
	unit.movement_left = 2.0
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, MASTER)
	assert_almost_eq(unit.hp, 14.0, 0.0001, "50% de 28")
	assert_eq(c.player.gold, gold - 24.0 - 32.0)

	assert_eq(unit.get_instance_id(), id, "a MESMA unidade nas três formas")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.kills, 4)
	assert_eq(unit.veterancy_level, 2)
	assert_eq(int(unit.magic_cooldowns[CLEAVE]), 9)
	assert_eq(c.player.units.size(), 1)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "", "fim da linha")

# --- Herança das Técnicas -------------------------------------------------------------------------------------------

func test_every_form_inherits_both_techniques_by_line_with_no_specific_code():
	var grid := _world()
	var me := _player(9)
	var kinds := [WARRIOR, SWORDSMAN, MASTER]
	for i in kinds.size():
		var unit := _unit(grid, me, kinds[i], Vector2i(i, 0) if i == 0 else Vector2i(-i, 0))
		var ids: Array = V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id)
		assert_eq(ids.size(), 2, kinds[i])
		assert_true(POWER in ids and CLEAVE in ids, kinds[i])

func test_the_techniques_need_their_own_research_even_for_the_elite_form():
	var grid := _world()
	var me := _player(5) # sem N6
	var master := _unit(grid, me, MASTER, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(master).map(func(t): return t.id), [POWER], "o Arco só existe após o N6")

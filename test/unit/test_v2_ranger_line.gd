extends "res://test/unit/v2_combat_fixture.gd"

## Arqueiro N3 / Caçador N5 / Atirador de Elite N7 (Aetherlands V2 Fase 8): a cadeia convencional da Doutrina do Patrulheiro, treinada no Campo dos
## Patrulheiros, evoluída pelo MESMO V2UnitUpgrade e ofertada pela MESMA V2UnitLine. O N7 muda o ALCANCE BÁSICO (2 -> 3). Números = BALANCE PLACEHOLDER:
## os testes fixam também as RELAÇÕES e calculam custos pela fórmula.

func _case(through: int, kind: String, with_camp: bool = true, gold: float = 200.0) -> Dictionary:
	var grid := _world(4)
	var player := _ranger_player(through)
	player.gold = gold
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	if with_camp:
		city.buildings[R_CAMP] = true
	var unit := _unit(grid, player, kind, Vector2i(1, 0))
	return {"grid": grid, "player": player, "city": city, "unit": unit}

func _trainable_forms(city: City) -> Array:
	return [ARCHER, HUNTER, MARKSMAN].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

# --- Definições ------------------------------------------------------------------------------------------------------------

func test_the_hunter_and_the_marksman_have_the_specified_baselines():
	var hunter := UnitDatabase.create_unit(HUNTER)
	assert_eq(hunter.unit_name, "Caçador")
	assert_eq([hunter.max_hp, hunter.attack, hunter.defense, hunter.movement_points, hunter.attack_range, hunter.production_cost], [17.0, 6.5, 3.0, 2.0, 2, 32.0])
	var marksman := UnitDatabase.create_unit(MARKSMAN)
	assert_eq(marksman.unit_name, "Atirador de Elite")
	assert_eq([marksman.max_hp, marksman.attack, marksman.defense, marksman.movement_points, marksman.attack_range, marksman.production_cost], [22.0, 8.5, 3.5, 2.0, 3, 48.0])
	for data in [hunter, marksman]:
		assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY), "convencional, não Lendário")
		assert_false(data.can_found_city)

func test_the_progression_is_monotonic_and_the_range_only_grows_at_n7_without_more_movement():
	var forms := [ARCHER, HUNTER, MARKSMAN].map(func(k): return UnitDatabase.create_unit(k))
	for i in range(1, forms.size()):
		assert_gt(forms[i].max_hp, forms[i - 1].max_hp)
		assert_gt(forms[i].attack, forms[i - 1].attack)
		assert_gt(forms[i].defense, forms[i - 1].defense)
		assert_gt(forms[i].production_cost, forms[i - 1].production_cost)
		assert_eq(forms[i].movement_points, forms[i - 1].movement_points, "sem mobilidade nova")
	assert_eq(forms.map(func(d): return d.attack_range), [2, 2, 3], "alcance 2 -> 2 -> 3: o domínio avançado é do N7")

func test_the_marksman_is_not_safe_in_melee_and_stays_fragile():
	var marksman := UnitDatabase.create_unit(MARKSMAN)
	assert_lt(marksman.max_hp, UnitDatabase.create_unit(WARRIOR).max_hp + 7.0, "frágil perto do Mestre de Armas")
	assert_lt(marksman.defense, UnitDatabase.create_unit(MASTER).defense)
	assert_lt(marksman.defense, UnitDatabase.create_unit(SENTINEL).defense)
	assert_lt(marksman.max_hp, UnitDatabase.create_unit(SENTINEL).max_hp)
	assert_gt(marksman.attack, UnitDatabase.create_unit(SENTINEL).attack)

func test_the_ranger_forms_are_fragile_at_every_tier_compared_with_the_other_doctrines():
	var ranger := [ARCHER, HUNTER, MARKSMAN]
	var guardian := [SHIELD, "v2_unit_guardian", SENTINEL]
	var warrior := [WARRIOR, SWORDSMAN, MASTER]
	for i in 3:
		var r := UnitDatabase.create_unit(ranger[i])
		assert_lt(r.max_hp, UnitDatabase.create_unit(guardian[i]).max_hp, "menos vida que o Guardião do mesmo nível")
		assert_lt(r.defense, UnitDatabase.create_unit(guardian[i]).defense)
		assert_lt(r.max_hp, UnitDatabase.create_unit(warrior[i]).max_hp, "menos vida que o Guerreiro do mesmo nível")
		assert_lt(r.defense, UnitDatabase.create_unit(warrior[i]).defense)

func test_the_forms_are_registered_once_with_distinct_provisional_scales_and_the_v1_model():
	for kind in [ARCHER, HUNTER, MARKSMAN, LEGEND_HUNTER]:
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(kind), 1, kind)
		var data := UnitDatabase.create_unit(kind)
		assert_true(ResourceLoader.exists(data.model_scene_path), data.model_scene_path)
		assert_true(ResourceLoader.exists(data.animation_scene_path))
		assert_eq(data.model_scene_path, UnitDatabase.create_unit("archer").model_scene_path, "reaproveita o Ranger do KayKit")
		for race in ["human", "elf", "dwarf", "orc"]:
			assert_eq(RaceTheme.unit_name(kind, race), data.unit_name, "%s (%s)" % [kind, race])
	var scales := [ARCHER, HUNTER, MARKSMAN, LEGEND_HUNTER].map(func(k): return UnitDatabase.create_unit(k).model_scale_multiplier)
	assert_eq(scales, [1.0, 1.15, 1.3, 1.5])

func test_the_vision_covers_the_extra_reach_of_the_marksman_shot():
	var precise := _technique(PRECISE)
	for kind in [ARCHER, HUNTER, MARKSMAN, LEGEND_HUNTER]:
		var data := UnitDatabase.create_unit(kind)
		assert_gte(data.vision_range, precise.resolved_range(data), "%s enxerga até onde o Disparo Preciso alcança" % kind)

# --- Produção: só a forma normal mais avançada ------------------------------------------------------------------------------

func test_the_camp_offers_exactly_one_form_at_every_research_level():
	var expected := {3: ARCHER, 4: ARCHER, 5: HUNTER, 6: HUNTER, 7: MARKSMAN, 8: MARKSMAN, 9: MARKSMAN}
	for through in expected:
		var offered := _trainable_forms(_standalone_city(_ranger_player(through), [R_CAMP]))
		assert_eq(offered, [expected[through]], "até N%d" % through)

func test_before_n3_nothing_is_offered_and_costs_follow_the_form():
	assert_eq(_trainable_forms(_standalone_city(_ranger_player(2), [R_CAMP])), [])
	var player := _ranger_player(3)
	var city := _standalone_city(player, [R_CAMP])
	city.set_production(ARCHER)
	assert_eq(city.production_cost(), 20.0, "Arqueiro — 20 PP")
	for n in range(4, 6):
		player.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	city.set_production(HUNTER)
	assert_eq(city.production_cost(), 32.0, "Caçador — 32 PP")
	for n in range(6, 8):
		player.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	city.set_production(MARKSMAN)
	assert_eq(city.production_cost(), 48.0, "Atirador de Elite — 48 PP")

func test_the_form_still_needs_the_camp_never_the_v1_archery_range_the_other_halls_or_the_tower():
	var player := _player(9, 9, 9)
	# Aetherlands V2, Fase 15 — vários prédios com upkeep (§24-30) sem Mercado e sem Ouro em caixa
	# entrariam em Déficit sozinhos, bloqueando o treino por um motivo alheio ao que este teste
	# verifica (qual prédio treina a forma).
	player.gold = 1000.0
	assert_false(_standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA, "archery_range", "barracks"]).can_train(MARKSMAN))
	assert_true(_standalone_city(player, [R_CAMP]).can_train(MARKSMAN), "só o Campo, sem a Torre")
	assert_false(_standalone_city(player, [R_TOWER]).can_train(MARKSMAN), "a Torre não treina a cadeia convencional")

func test_debug_reset_keeps_what_exists_and_production_follows_the_research():
	var player := _ranger_player(7)
	var city := _standalone_city(player, [R_CAMP])
	player.v2_research.reset()
	assert_true(city.buildings.has(R_CAMP))
	assert_eq(_trainable_forms(city), [])
	for n in range(1, 6):
		player.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	assert_eq(_trainable_forms(city), [HUNTER])

func test_an_ai_civilization_with_n7_resolves_the_marksman_without_breaking():
	var rival := _ranger_player(7)
	var city := _standalone_city(rival, [R_CAMP])
	var offered := UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(MARKSMAN))
	assert_false(offered.has(ARCHER))
	assert_false(offered.has(HUNTER))

# --- Upgrade Arqueiro -> Caçador (N5) -----------------------------------------------------------------------------------------

func test_the_first_upgrade_target_comes_from_the_metadata_and_the_cost_from_the_generic_formula():
	var c := _case(5, ARCHER)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(ARCHER).upgrade_to, HUNTER)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), HUNTER)
	var expected := V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (UnitDatabase.create_unit(HUNTER).production_cost - UnitDatabase.create_unit(ARCHER).production_cost)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), expected)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 24.0, "2 x (32 - 20)")

func test_the_first_upgrade_requirements_each_have_their_own_reason():
	var c := _case(5, ARCHER)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "")
	var early := _case(4, ARCHER)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(early.player, early.unit, early.grid), "Requer pesquisa: Caçador.")
	var no_camp := _case(5, ARCHER, false)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(no_camp.player, no_camp.unit, no_camp.grid), "Requer Campo dos Patrulheiros na cidade.")
	var outside := _case(5, ARCHER)
	outside.grid.move_unit(outside.unit, Vector2i(4, 0), 1.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(outside.player, outside.unit, outside.grid), "Precisa estar em uma cidade própria.")
	var poor := _case(5, ARCHER, true, 23.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(poor.player, poor.unit, poor.grid), "Ouro insuficiente (custa 24).")
	var spent := _case(5, ARCHER)
	spent.unit.movement_left = 0.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(spent.player, spent.unit, spent.grid), "A unidade já agiu neste turno.")

func test_another_doctrines_hall_does_not_satisfy_the_camp_requirement():
	var grid := _world(4)
	var player := _player(9, 9, 5)
	player.gold = 200.0
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	city.buildings[G_HALL] = true
	city.buildings[W_HALL] = true
	var unit := _unit(grid, player, ARCHER, Vector2i(1, 0))
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(player, unit, grid), "Requer Campo dos Patrulheiros na cidade.")

func test_the_first_upgrade_preserves_everything_that_does_not_depend_on_the_form():
	var c := _case(6, ARCHER)
	var unit: Unit = c.unit
	unit.hp = 6.5 # 6,5/13 = 50%
	unit.kills = 3
	unit.veterancy_level = 2
	unit.magic_cooldowns[PRECISE] = 8
	unit.magic_cooldowns[VOLLEY] = 9
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	var coord := unit.coord
	var count: int = c.player.units.size()
	var gold: float = c.player.gold
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, HUNTER)
	assert_eq(unit.get_instance_id(), id, "mesma unidade")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.coord, coord)
	assert_eq(unit.owner_player, c.player)
	assert_eq(c.player.units.size(), count, "sem duplicar")
	assert_eq(c.player.units.filter(func(u): return u.unit_data.visual_kind == ARCHER).size(), 0, "sem Arqueiro fantasma")
	assert_same(c.grid.get_unit_at(coord), unit)
	assert_almost_eq(unit.hp, 8.5, 0.0001, "50% de 17")
	assert_eq(unit.kills, 3)
	assert_eq(unit.veterancy_level, 2)
	assert_eq([int(unit.magic_cooldowns[PRECISE]), int(unit.magic_cooldowns[VOLLEY])], [8, 9], "recargas preservadas")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(c.player.gold, gold - 24.0)

func test_a_failed_upgrade_changes_nothing():
	var c := _case(4, ARCHER)
	var gold: float = c.player.gold
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.unit.unit_data.visual_kind, ARCHER)
	assert_eq(c.player.gold, gold)

# --- Upgrade Caçador -> Atirador de Elite (N7) e a cadeia ----------------------------------------------------------------------

func test_the_second_upgrade_costs_32_gold_by_the_formula():
	var c := _case(7, HUNTER)
	assert_eq(V2ResearchDatabase.node_for_unlock_id(HUNTER).upgrade_to, MARKSMAN)
	assert_eq(V2UnitUpgrade.get_upgrade_target(c.unit), MARKSMAN)
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (48.0 - 32.0))
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), 32.0)

func test_the_marksman_has_no_further_evolution_and_the_legend_hunter_is_not_one():
	var c := _case(9, MARKSMAN)
	assert_eq(V2UnitUpgrade.get_upgrade_target(c.unit), "")
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Esta unidade não tem evolução disponível.")
	assert_ne(V2ResearchDatabase.node_for_unlock_id(MARKSMAN).upgrade_to, LEGEND_HUNTER)

func test_without_n7_the_hunter_cannot_become_a_marksman():
	var c := _case(6, HUNTER)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Requer pesquisa: Atirador de Elite.")

func test_the_full_chain_archer_hunter_marksman_on_the_same_unit_changes_the_range_at_n7():
	var c := _case(7, ARCHER)
	var unit: Unit = c.unit
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	unit.kills = 4
	unit.veterancy_level = 2
	unit.hp = 6.5
	unit.magic_cooldowns[VOLLEY] = 9
	var gold: float = c.player.gold
	assert_eq(unit.unit_data.attack_range, 2)
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, HUNTER)
	assert_eq(unit.unit_data.attack_range, 2, "o Caçador ainda alcança 2")
	assert_almost_eq(unit.hp, 8.5, 0.0001)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, unit, c.grid), "sem ação neste turno")
	TurnManager.turn_number = 6
	unit.movement_left = 2.0
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, MARKSMAN)
	assert_eq(unit.unit_data.attack_range, 3, "o Atirador de Elite alcança 3")
	assert_almost_eq(unit.hp, 11.0, 0.0001, "50% de 22")
	assert_eq(c.player.gold, gold - 24.0 - 32.0)
	assert_eq(unit.get_instance_id(), id, "a MESMA unidade nas três formas")
	assert_eq(unit.serial_id, serial)
	assert_eq([unit.kills, unit.veterancy_level], [4, 2])
	assert_eq(int(unit.magic_cooldowns[VOLLEY]), 9)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "")

# --- Alcance avançado e herança das técnicas ------------------------------------------------------------------------------------

func test_the_marksman_basic_attack_reaches_3_tiles_without_counterattack():
	var grid := _world()
	var me := _ranger_player(7)
	var rival := _rival_of(me)
	var marksman := _unit(grid, me, MARKSMAN, Vector2i(0, 0))
	var foe := _foe_at(grid, rival, marksman, 3, 40.0, 14.0)
	var prediction: Dictionary = CombatResolver.predict(marksman, foe, grid)
	assert_false(prediction.is_melee_range)
	assert_eq(prediction.damage_to_attacker, 0.0)
	assert_eq(prediction.damage_to_defender, _formula_damage(grid, 8.5, 1.0, foe))
	var original_grid := GameManager.hex_grid
	var original_human := GameManager.human_player
	GameManager.hex_grid = grid
	GameManager.human_player = me
	SelectionManager._select_unit(marksman)
	assert_true(foe.coord in SelectionManager.attackable, "a 3 tiles é alvo do ataque básico do Atirador de Elite")
	var archer := _unit(grid, me, ARCHER, Vector2i(0, 2))
	SelectionManager._select_unit(archer)
	assert_false(foe.coord in SelectionManager.attackable, "o Arqueiro (alcance 2) não chega")
	SelectionManager.reset()
	GameManager.hex_grid = original_grid
	GameManager.human_player = original_human

func test_the_precise_shot_naturally_reaches_4_for_the_marksman_and_3_for_the_hunter():
	var grid := _world()
	var me := _ranger_player(7)
	var rival := _rival_of(me)
	var marksman := _unit(grid, me, MARKSMAN, Vector2i(0, 0))
	var hunter := _unit(grid, me, HUNTER, Vector2i(0, -3))
	var far := _foe_at(grid, rival, marksman, 4)
	assert_true(far in V2TechniqueRuntime.strike_targets(marksman, _technique(PRECISE), grid), "alcance 3 + 1 = 4, sem exceção específica")
	var near_hunter := _foe_at(grid, rival, hunter, 3)
	var far_hunter := _foe_at(grid, rival, hunter, 4)
	var hunter_targets := V2TechniqueRuntime.strike_targets(hunter, _technique(PRECISE), grid)
	assert_true(near_hunter in hunter_targets, "o Caçador (alcance 2) chega a 3")
	assert_false(far_hunter in hunter_targets, "e não a 4")

func test_every_form_inherits_both_techniques_by_line_with_no_specific_code():
	var grid := _world()
	var me := _ranger_player(9)
	var kinds := [ARCHER, HUNTER, MARKSMAN]
	for i in kinds.size():
		var unit := _unit(grid, me, kinds[i], _coord_at(grid, Vector2i(0, 0), i + 1))
		assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [PRECISE, VOLLEY], kinds[i])

func test_the_techniques_need_their_own_research_even_for_the_elite_form():
	var grid := _world()
	var me := _ranger_player(5)
	var marksman := _unit(grid, me, MARKSMAN, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(marksman).map(func(t): return t.id), [PRECISE], "a Saraivada só existe após o N6")

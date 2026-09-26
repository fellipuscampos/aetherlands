extends "res://test/unit/v2_combat_fixture.gd"

## Torre dos Patrulheiros (v2_building_ranger_mastery, N8) e Caçador de Lendas (v2_legendary_legend_hunter, N9) — Aetherlands V2 Fase 8. A Torre é um prédio NORMAL
## (BuildingData + requires_building); o Caçador de Lendas é uma Lendária pelo MESMO V2LegendarySystem do Campeão Guardião e do Herói da Lâmina: as TRÊS disputam o
## ÚNICO slot da civilização. Números = BALANCE PLACEHOLDER.

func _city_with_everything(player: PlayerData) -> City:
	return _standalone_city_with_supply(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER])

# --- Torre: definição --------------------------------------------------------------------------------------------------------

func test_the_tower_exists_with_the_canonical_id_name_and_type():
	var building := BuildingDatabase.get_building(R_TOWER)
	assert_not_null(building)
	assert_eq(building.display_name, "Torre dos Patrulheiros")
	assert_eq(building.display_name, V2ResearchDatabase.node_for_unlock_id(R_TOWER).display_name)
	assert_eq(V2ResearchDatabase.node_for_unlock_id(R_TOWER).unlock_type, "mastery_building")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == R_TOWER).size(), 1)

func test_its_only_function_is_to_enable_the_legend_hunter_and_it_has_no_bonuses():
	var building := BuildingDatabase.get_building(R_TOWER)
	assert_eq(building.trains_unit, LEGEND_HUNTER)
	assert_eq(BuildingDatabase.building_that_trains(LEGEND_HUNTER), building)
	assert_false("upkeep" in building.get_property_list().map(func(p): return p.name))

func test_it_requires_the_camp_costs_55_and_shares_the_scale_of_the_other_masteries():
	var tower := BuildingDatabase.get_building(R_TOWER)
	assert_eq(tower.requires_building, R_CAMP)
	assert_eq(BuildingDatabase.get_building(R_CAMP).trains_unit, ARCHER, "o Campo segue treinando a linha convencional")
	assert_eq(tower.production_cost, 55.0)
	assert_eq(tower.production_cost, BuildingDatabase.get_building(G_MASTERY).production_cost)
	assert_eq(tower.production_cost, BuildingDatabase.get_building(ARENA).production_cost)
	assert_lt(tower.production_cost, UnitDatabase.create_unit(LEGEND_HUNTER).production_cost)

func test_it_reuses_a_provisional_v1_model_and_has_no_v1_gate():
	var building := BuildingDatabase.get_building(R_TOWER)
	assert_true(ResourceLoader.exists(building.model_scene_path), building.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(R_TOWER, race), "Torre dos Patrulheiros", race)

# --- Torre: construir ----------------------------------------------------------------------------------------------------------

func test_it_cannot_be_built_before_n8_and_can_after_in_a_city_with_the_camp():
	var player := _ranger_player(7)
	var city := _standalone_city(player, [R_CAMP])
	assert_false(city.can_build(R_TOWER))
	player.v2_research.complete_research("v2_doctrine_ranger_8")
	assert_true(city.can_build(R_TOWER))

func test_a_city_without_the_camp_cannot_build_it_even_with_n8():
	var player := _ranger_player(8)
	var city := _standalone_city(player)
	assert_true(city._research_unlocked_for_building(R_TOWER), "a pesquisa está ok...")
	assert_false(city._prerequisite_building_present(R_TOWER), "...falta o Campo dos Patrulheiros")
	assert_false(city.can_build(R_TOWER))
	city.buildings[R_CAMP] = true
	assert_true(city.can_build(R_TOWER))

func test_no_other_hall_no_v1_building_and_no_v1_tech_stands_in_for_the_camp():
	var player := _player(9, 9, 8)
	var city := _standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA, "archery_range", "barracks"])
	assert_false(city.can_build(R_TOWER))

func test_it_uses_one_normal_slot_is_built_once_and_needs_room():
	var player := _ranger_player(8)
	var city := _standalone_city(player, [R_CAMP])
	var used := city.used_building_slots()
	city.buildings[R_TOWER] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(R_TOWER), "não constrói duas vezes")
	var small := _standalone_city(player, [R_CAMP])
	small.city_level = 1 # Fase 13: 4 slots (não é mais população) -- Campo + 3 mais enche
	for id in ["granary", "workshop", "market"]:
		small.buildings[id] = true
	assert_false(small.can_build(R_TOWER), "regra de slots de sempre")
	small.city_level = 2 # 7 slots
	assert_true(small.can_build(R_TOWER))

func test_the_unlock_belongs_to_the_researching_civilization_only_and_goes_through_the_normal_queue():
	assert_true(_standalone_city(_ranger_player(8), [R_CAMP]).can_build(R_TOWER))
	assert_false(_standalone_city(_ranger_player(7), [R_CAMP]).can_build(R_TOWER))
	assert_false(_standalone_city(_player(9, 9, 0), [R_CAMP]).can_build(R_TOWER), "outras Doutrinas não bastam")
	var city := _standalone_city(_ranger_player(8), [R_CAMP])
	city.set_production(R_TOWER)
	assert_eq(city.production_item, R_TOWER)
	assert_eq(city.production_cost(), 55.0)

func test_the_legend_hunter_stays_blocked_with_the_tower_but_without_n9():
	var player := _ranger_player(8)
	var city := _standalone_city(player, [R_CAMP, R_TOWER])
	assert_false(city.can_train(LEGEND_HUNTER), "N8 dá o prédio; o Caçador de Lendas é do N9")
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, LEGEND_HUNTER), "Requer pesquisa: Caçador de Lendas.")

# --- Caçador de Lendas: definição -----------------------------------------------------------------------------------------------------

func test_the_legend_hunter_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(LEGEND_HUNTER)
	assert_eq(data.unit_name, "Caçador de Lendas")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points, data.attack_range, data.production_cost], [30.0, 11.0, 4.5, 2.0, 3, 90.0])
	assert_eq(data.visual_kind, LEGEND_HUNTER)
	assert_true(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(data.has_aura(), "a aura é do Campeão")
	assert_false(data.has_low_hp_attack_bonus(), "a Execução é do Herói")
	assert_true(data.has_trait_attack_bonus(), "a Caçada Lendária é dele")

func test_it_is_extremely_dangerous_at_range_and_much_more_fragile_than_the_champion():
	var hunter := UnitDatabase.create_unit(LEGEND_HUNTER)
	var champion := UnitDatabase.create_unit(CHAMPION)
	var hero := UnitDatabase.create_unit(HERO)
	assert_gt(hunter.attack, UnitDatabase.create_unit(MARKSMAN).attack, "mais Ataque que o Atirador de Elite")
	assert_gt(hunter.attack, hero.attack * 0.9, "Ataque da ordem do Herói")
	assert_lt(hunter.max_hp, champion.max_hp * 0.75, "muito mais frágil que o Campeão Guardião")
	assert_lt(hunter.defense, champion.defense * 0.5)
	assert_lt(hunter.max_hp, hero.max_hp, "e mais frágil que o Herói da Lâmina")
	assert_eq(hunter.production_cost, champion.production_cost, "custos iguais: só a identidade difere")
	assert_gt(hunter.attack_range, hero.attack_range)

func test_the_legend_hunter_is_a_legendary_by_metadata_and_does_not_evolve():
	assert_true(V2LegendarySystem.is_legendary_kind(LEGEND_HUNTER))
	assert_eq(V2ResearchDatabase.node_for_unlock_id(LEGEND_HUNTER).unlock_type, "legendary_candidate")
	var grid := _world()
	var unit := _unit(grid, _ranger_player(9), LEGEND_HUNTER, Vector2i(0, 0))
	assert_true(V2LegendarySystem.is_legendary_unit(unit))
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "")

# --- Não é upgrade, não está na cadeia -------------------------------------------------------------------------------------------------

func test_it_is_outside_the_conventional_chain_and_does_not_replace_the_marksman():
	assert_false(V2UnitLine.is_line_unit(LEGEND_HUNTER))
	assert_eq(V2UnitLine.unit_ids("ranger"), [ARCHER, HUNTER, MARKSMAN])
	assert_eq(V2UnitLine.branch_of(LEGEND_HUNTER), "")
	assert_eq(V2UnitLine.doctrine_branch_of(LEGEND_HUNTER), "ranger", "pertence à Doutrina, não à cadeia")
	var player := _ranger_player(9)
	assert_eq(V2UnitLine.resolve_trainable_form(player, ARCHER), MARKSMAN, "a produção convencional segue no Atirador de Elite")
	assert_eq(V2UnitLine.resolve_trainable_form(player, LEGEND_HUNTER), "")
	# Fase 15: o Caçador de Lendas custa 5 Suprimentos, acima da base de uma cidade sozinha (4).
	var city := _standalone_city_with_supply(player, [R_CAMP, R_TOWER])
	assert_true(city.can_train(MARKSMAN))
	assert_true(city.can_train(LEGEND_HUNTER))
	city.set_production(LEGEND_HUNTER)
	assert_true(city.can_train(MARKSMAN), "o Atirador segue treinável mesmo com o Caçador de Lendas na fila")

func test_the_marksman_does_not_evolve_into_it():
	var grid := _world()
	var marksman := _unit(grid, _ranger_player(9), MARKSMAN, Vector2i(0, 0))
	assert_eq(V2UnitUpgrade.get_upgrade_target(marksman), "")

func test_producing_it_needs_n9_the_tower_and_a_free_slot_and_costs_90():
	var player := _ranger_player(8)
	# Fase 15: o Caçador de Lendas custa 5 Suprimentos, acima da base de uma cidade sozinha (4).
	var city := _standalone_city_with_supply(player, [R_CAMP, R_TOWER])
	assert_false(city.can_train(LEGEND_HUNTER), "sem N9")
	player.v2_research.complete_research("v2_doctrine_ranger_9")
	assert_true(city.can_train(LEGEND_HUNTER))
	assert_false(_standalone_city(player, [R_CAMP]).can_train(LEGEND_HUNTER), "sem a Torre")
	assert_false(_standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA]).can_train(LEGEND_HUNTER), "nem o Bastião nem a Arena o treinam")
	city.set_production(LEGEND_HUNTER)
	assert_eq(city.production_cost(), 90.0)

func test_the_other_masteries_do_not_train_it_and_the_tower_does_not_train_the_others():
	var player := _player(9, 9, 9)
	assert_false(_standalone_city(player, [R_CAMP, R_TOWER]).can_train(CHAMPION))
	assert_false(_standalone_city(player, [R_CAMP, R_TOWER]).can_train(HERO))

# --- Herança das Técnicas -----------------------------------------------------------------------------------------------------------------

func test_it_inherits_both_ranger_techniques_and_none_of_the_others():
	var grid := _world()
	var me := _player(9, 9, 9)
	var unit := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [PRECISE, VOLLEY])

func test_the_technique_data_does_not_mention_the_legend_hunter():
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_false(technique.id.contains("legend_hunter"))
	var source := FileAccess.get_file_as_string("res://scripts/data/V2DoctrineTechniqueDatabase.gd")
	assert_false(source.contains("v2_legendary_legend_hunter"), "nada duplicado no dado do Lendário")

func test_its_shots_use_its_own_range_basic_3_precise_4():
	var grid := _world()
	var me := _ranger_player(9)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	var at_four := _foe_at(grid, rival, unit, 4)
	assert_true(at_four in V2TechniqueRuntime.strike_targets(unit, _technique(PRECISE), grid))
	assert_false(at_four in V2TechniqueRuntime.strike_targets(unit, _technique(VOLLEY), grid), "a Saraivada usa o alcance básico (3)")

func test_the_basic_ranged_attack_reaches_3_tiles_without_counterattack():
	var grid := _world()
	var me := _ranger_player(9)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	var foe := _foe_at(grid, rival, unit, 3, 60.0, 14.0)
	var prediction: Dictionary = CombatResolver.predict(unit, foe, grid)
	assert_eq(prediction.damage_to_attacker, 0.0)
	assert_eq(prediction.damage_to_defender, _formula_damage(grid, 11.0, 1.0, foe))

# --- O slot GLOBAL entre as TRÊS Doutrinas (cenário obrigatório) --------------------------------------------------------------------------------

func test_the_three_doctrines_share_the_single_slot_step_by_step():
	var grid := _world()
	var me := _player(9, 9, 9)
	var rival := _rival_of(me)
	var city := _city_with_everything(me) # 1-3. Bastião + Arena + Torre (e os Salões)
	var other := _city_with_everything(me)
	assert_true(city.buildings.has(G_MASTERY) and city.buildings.has(ARENA) and city.buildings.has(R_TOWER))
	assert_true(city.can_train(CHAMPION) and city.can_train(HERO) and city.can_train(LEGEND_HUNTER), "pré-condição: as três livres")

	var champion := _unit(grid, me, CHAMPION, Vector2i(0, 0)) # 4. Campeão Guardião ativo
	assert_false(city.can_train(HERO), "5. Herói bloqueado")
	assert_false(city.can_train(LEGEND_HUNTER), "6. Caçador de Lendas bloqueado")
	assert_eq(V2LegendarySystem.unavailable_reason(me, city, LEGEND_HUNTER), V2LegendarySystem.SLOT_TAKEN_REASON)

	champion.hp = 1.0 # 7. matar o Campeão em combate real
	var killer_data := UnitDatabase.create_unit("warrior")
	killer_data.attack = 100.0
	CombatResolver.resolve(grid.spawn_unit(Vector2i(1, 0), killer_data, rival), champion, grid)
	assert_false(V2LegendarySystem.has_active_legendary(me))

	city.set_production(LEGEND_HUNTER) # 8. iniciar o Caçador de Lendas na Torre
	assert_eq(city.production_item, LEGEND_HUNTER)
	assert_false(other.can_train(CHAMPION), "9. Campeão bloqueado")
	assert_false(other.can_train(HERO), "9. Herói bloqueado")

	city.set_production("") # 10. cancelar a produção
	assert_true(other.can_train(CHAMPION) and other.can_train(HERO) and other.can_train(LEGEND_HUNTER), "a reserva foi liberada")

	city.set_production(HERO) # 11. iniciar o Herói
	assert_false(other.can_train(CHAMPION), "12. Campeão bloqueado")
	assert_false(other.can_train(LEGEND_HUNTER), "12. Caçador de Lendas bloqueado")
	assert_true(city.can_train(HERO), "a cidade produtora não se bloqueia")

func test_an_active_legend_hunter_blocks_the_other_two_and_its_death_releases_them():
	var grid := _world()
	var me := _player(9, 9, 9)
	var city := _city_with_everything(me)
	var unit := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	assert_false(city.can_train(CHAMPION))
	assert_false(city.can_train(HERO))
	assert_eq(V2LegendarySystem.slots_used(me), 1)
	grid.remove_unit(unit)
	assert_true(city.can_train(CHAMPION) and city.can_train(HERO) and city.can_train(LEGEND_HUNTER))

func test_a_rival_legend_hunter_never_blocks_me_and_one_civilization_has_one_slot():
	var grid := _world()
	var me := _player(9, 9, 9)
	var rival := _rival_of(me)
	_unit(grid, rival, LEGEND_HUNTER, Vector2i(3, 0))
	var city := _city_with_everything(me)
	assert_true(city.can_train(LEGEND_HUNTER))
	assert_eq(V2LegendarySystem.slots_used(me), 0)
	_unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	assert_eq(V2LegendarySystem.slots_used(me), 1)
	assert_eq(V2LegendarySystem.max_active(), 1)

func test_a_debug_reset_does_not_kill_the_legend_hunter_and_the_slot_stays_taken():
	var grid := _world()
	var me := _player(9, 9, 9)
	var city := _city_with_everything(me)
	_unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	me.v2_research.reset()
	assert_true(V2LegendarySystem.has_active_legendary(me))
	assert_false(city.can_train(CHAMPION))

func test_the_spawn_is_fail_closed_with_any_of_the_three_already_active():
	var grid := _world()
	var me := _player(9, 9, 9)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER]:
		assert_true(V2LegendarySystem.spawn_allowed(me, kind))
	_unit(grid, me, HERO, Vector2i(0, 0))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER]:
		assert_false(V2LegendarySystem.spawn_allowed(me, kind), kind)
	var city := _city_with_everything(me)
	city.stored_production = 0.0
	V2LegendarySystem.refuse_spawn(city, LEGEND_HUNTER, false)
	assert_push_error("não nasceu")
	assert_eq(city.stored_production, UnitDatabase.create_unit(LEGEND_HUNTER).production_cost)

extends "res://test/unit/v2_combat_fixture.gd"

## Ordem da Cavalaria (v2_building_cavalry_mastery, N8) e Cavaleiro de Grifo (v2_legendary_griffon_rider, N9) — Aetherlands V2 Fase 9. A Ordem é um prédio NORMAL
## (BuildingData + requires_building); o Cavaleiro de Grifo é uma Lendária pelo MESMO V2LegendarySystem do Campeão Guardião, do Herói da Lâmina e do Caçador
## de Lendas: as QUATRO disputam o ÚNICO slot da civilização, sem nenhuma mudança no sistema. Números = BALANCE PLACEHOLDER.

func _city_with_everything(player: PlayerData) -> City:
	return _standalone_city_with_supply(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER])

# --- Ordem: definição -----------------------------------------------------------------------------------------------------------

func test_the_order_exists_with_the_canonical_id_name_and_type():
	var building := BuildingDatabase.get_building(C_ORDER)
	assert_not_null(building)
	assert_eq(building.display_name, "Ordem da Cavalaria")
	assert_eq(building.display_name, V2ResearchDatabase.node_for_unlock_id(C_ORDER).display_name)
	assert_eq(V2ResearchDatabase.node_for_unlock_id(C_ORDER).unlock_type, "mastery_building")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == C_ORDER).size(), 1)

func test_its_only_function_is_to_enable_the_griffon_and_it_has_no_bonuses():
	var building := BuildingDatabase.get_building(C_ORDER)
	assert_eq(building.trains_unit, GRIFFON)
	assert_eq(BuildingDatabase.building_that_trains(GRIFFON), building)
	assert_false("upkeep" in building.get_property_list().map(func(p): return p.name))

func test_it_requires_the_stable_costs_55_and_shares_the_scale_of_the_other_masteries():
	var order := BuildingDatabase.get_building(C_ORDER)
	assert_eq(order.requires_building, C_STABLE)
	assert_eq(BuildingDatabase.get_building(C_STABLE).trains_unit, CAVALIER, "o Estábulo segue treinando a linha convencional")
	assert_eq(order.production_cost, 55.0)
	for other in [G_MASTERY, ARENA, R_TOWER]:
		assert_eq(order.production_cost, BuildingDatabase.get_building(other).production_cost, other)
	assert_lt(order.production_cost, UnitDatabase.create_unit(GRIFFON).production_cost)

func test_it_reuses_a_provisional_v1_model_and_has_no_v1_gate():
	var building := BuildingDatabase.get_building(C_ORDER)
	assert_true(ResourceLoader.exists(building.model_scene_path), building.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(C_ORDER, race), "Ordem da Cavalaria", race)

# --- Ordem: construir --------------------------------------------------------------------------------------------------------------

func test_it_cannot_be_built_before_n8_and_can_after_in_a_city_with_the_stable():
	var player := _cavalry_player(7)
	var city := _standalone_city(player, [C_STABLE])
	assert_false(city.can_build(C_ORDER))
	player.v2_research.complete_research("v2_doctrine_cavalry_8")
	assert_true(city.can_build(C_ORDER))

func test_a_city_without_the_stable_cannot_build_it_even_with_n8():
	var player := _cavalry_player(8)
	var city := _standalone_city(player)
	assert_true(city._research_unlocked_for_building(C_ORDER), "a pesquisa está ok...")
	assert_false(city._prerequisite_building_present(C_ORDER), "...falta o Estábulo de Guerra")
	assert_false(city.can_build(C_ORDER))
	city.buildings[C_STABLE] = true
	assert_true(city.can_build(C_ORDER))

func test_no_other_hall_no_v1_building_and_no_v1_tech_stands_in_for_the_stable():
	var player := _player(9, 9, 9, 8)
	var city := _standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, "stable", "barracks"])
	assert_false(city.can_build(C_ORDER))

func test_it_uses_one_normal_slot_is_built_once_and_needs_room():
	var player := _cavalry_player(8)
	var city := _standalone_city(player, [C_STABLE])
	var used := city.used_building_slots()
	city.buildings[C_ORDER] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(C_ORDER), "não constrói duas vezes")
	var small := _standalone_city(player, [C_STABLE])
	small.city_level = 1 # Fase 13: 4 slots (não é mais população) -- Estábulo + 3 mais enche
	for id in ["granary", "workshop", "market"]:
		small.buildings[id] = true
	assert_false(small.can_build(C_ORDER), "regra de slots de sempre")
	small.city_level = 2 # 7 slots
	assert_true(small.can_build(C_ORDER))

func test_the_unlock_belongs_to_the_researching_civilization_only_and_goes_through_the_normal_queue():
	assert_true(_standalone_city(_cavalry_player(8), [C_STABLE]).can_build(C_ORDER))
	assert_false(_standalone_city(_cavalry_player(7), [C_STABLE]).can_build(C_ORDER))
	assert_false(_standalone_city(_player(9, 9, 9, 0), [C_STABLE]).can_build(C_ORDER), "outras Doutrinas não bastam")
	var city := _standalone_city(_cavalry_player(8), [C_STABLE])
	city.set_production(C_ORDER)
	assert_eq(city.production_item, C_ORDER)
	assert_eq(city.production_cost(), 55.0)

func test_the_griffon_stays_blocked_with_the_order_but_without_n9():
	var player := _cavalry_player(8)
	var city := _standalone_city(player, [C_STABLE, C_ORDER])
	assert_false(city.can_train(GRIFFON), "N8 dá o prédio; o Cavaleiro de Grifo é do N9")
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, GRIFFON), "Requer pesquisa: Cavaleiro de Grifo.")

# --- Cavaleiro de Grifo: definição -----------------------------------------------------------------------------------------------------

func test_the_griffon_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(GRIFFON)
	assert_eq(data.unit_name, "Cavaleiro de Grifo")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points, data.production_cost], [36.0, 10.0, 6.5, 5.0, 100.0])
	assert_eq(data.vision_range, 5)
	assert_eq(data.attack_range, 1, "corpo a corpo")
	assert_eq(data.visual_kind, GRIFFON, "o SaveManager recria a unidade por ele")
	assert_false(data.can_found_city)

func test_it_carries_the_three_traits_and_the_flying_profile_and_the_ranged_vulnerability_by_data():
	var data := UnitDatabase.create_unit(GRIFFON)
	assert_true(data.has_trait(UnitData.TRAIT_MOUNTED))
	assert_true(data.has_trait(UnitData.TRAIT_FLYING))
	assert_true(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_eq(data.movement_profile, UnitData.MovementProfile.FLYING)
	assert_true(data.is_flying())
	assert_eq(data.ranged_damage_taken_bonus, 0.25)
	assert_true(UnitAbilities.is_mounted(data), "ainda montado: o Preparar Lanças o reconhece")

func test_it_is_not_stronger_than_the_other_legendaries_in_the_numbers():
	var griffon := UnitDatabase.create_unit(GRIFFON)
	var champion := UnitDatabase.create_unit(CHAMPION)
	var hero := UnitDatabase.create_unit(HERO)
	assert_lt(griffon.max_hp, champion.max_hp)
	assert_lt(griffon.defense, champion.defense)
	assert_lt(griffon.attack, hero.attack)
	assert_gt(griffon.movement_points, UnitDatabase.create_unit(ARMORED).movement_points, "o valor dele é o movimento")
	assert_gt(griffon.production_cost, UnitDatabase.create_unit(ARMORED).production_cost)

func test_the_griffon_is_a_legendary_by_metadata_and_does_not_evolve():
	assert_true(V2LegendarySystem.is_legendary_kind(GRIFFON))
	assert_eq(V2ResearchDatabase.node_for_unlock_id(GRIFFON).unlock_type, "legendary_candidate")
	var grid := _world()
	var unit := _unit(grid, _cavalry_player(9), GRIFFON, Vector2i(0, 0))
	assert_true(V2LegendarySystem.is_legendary_unit(unit))
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "")

# --- Não é upgrade, não está na cadeia ------------------------------------------------------------------------------------------------

func test_it_is_outside_the_conventional_chain_and_does_not_replace_the_armored_cavalier():
	assert_false(V2UnitLine.is_line_unit(GRIFFON))
	assert_eq(V2UnitLine.unit_ids("cavalry"), [CAVALIER, SHOCK, ARMORED])
	assert_eq(V2UnitLine.branch_of(GRIFFON), "")
	assert_eq(V2UnitLine.doctrine_branch_of(GRIFFON), "cavalry", "pertence à Doutrina, não à cadeia")
	var player := _cavalry_player(9)
	assert_eq(V2UnitLine.resolve_trainable_form(player, CAVALIER), ARMORED, "a produção convencional segue no Blindado")
	assert_eq(V2UnitLine.resolve_trainable_form(player, GRIFFON), "")
	# Fase 15: o Grifo custa 5 Suprimentos, acima da base de uma cidade sozinha (4) -- variante com
	# capacidade de sobra, já que Suprimentos não é o assunto deste teste (chave é o slot Lendário).
	var city := _standalone_city_with_supply(player, [C_STABLE, C_ORDER])
	assert_true(city.can_train(ARMORED))
	assert_true(city.can_train(GRIFFON))
	city.set_production(GRIFFON)
	assert_true(city.can_train(ARMORED), "o Blindado segue treinável mesmo com o Grifo na fila")

func test_the_armored_cavalier_does_not_evolve_into_it():
	var grid := _world()
	var armored := _unit(grid, _cavalry_player(9), ARMORED, Vector2i(0, 0))
	assert_eq(V2UnitUpgrade.get_upgrade_target(armored), "")

func test_producing_it_needs_n9_the_order_and_a_free_slot_and_costs_100():
	var player := _cavalry_player(8)
	# Fase 15: o Grifo custa 5 Suprimentos, acima da base de uma cidade sozinha (4).
	var city := _standalone_city_with_supply(player, [C_STABLE, C_ORDER])
	assert_false(city.can_train(GRIFFON), "sem N9")
	player.v2_research.complete_research("v2_doctrine_cavalry_9")
	assert_true(city.can_train(GRIFFON))
	assert_false(_standalone_city(player, [C_STABLE]).can_train(GRIFFON), "sem a Ordem")
	assert_false(_standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER]).can_train(GRIFFON), "nenhum outro prédio de maestria o treina")
	city.set_production(GRIFFON)
	assert_eq(city.production_cost(), 100.0)

func test_the_other_masteries_do_not_train_it_and_the_order_does_not_train_the_others():
	var player := _player(9, 9, 9, 9)
	var order_city := _standalone_city(player, [C_STABLE, C_ORDER])
	for kind in [CHAMPION, HERO, LEGEND_HUNTER]:
		assert_false(order_city.can_train(kind), kind)

# --- Herança das Técnicas ---------------------------------------------------------------------------------------------------------------

func test_it_inherits_both_cavalry_techniques_and_none_of_the_others():
	var grid := _world()
	var me := _player(9, 9, 9, 9)
	var unit := _unit(grid, me, GRIFFON, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [CHARGE, RETREAT])

func test_the_technique_data_and_the_legendary_system_do_not_mention_the_griffon():
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_false(technique.id.contains("griffon"))
	var techniques := FileAccess.get_file_as_string("res://scripts/data/V2DoctrineTechniqueDatabase.gd")
	assert_false(techniques.contains("v2_legendary_griffon_rider"), "nada duplicado no dado do Lendário")
	var legendary := _code_only(FileAccess.get_file_as_string("res://scripts/core/V2LegendarySystem.gd"))
	for word in ["griffon", "cavalry", "Grifo", "Cavalaria"]:
		assert_false(legendary.contains(word), "o sistema do slot não conhece '%s'" % word)

func test_the_griffon_is_recognised_by_the_brace_spears_and_by_no_name():
	var grid := _world()
	var me := _player(0, 9, 0, 9)
	var rival := _cavalry_player(9)
	Diplomacy.declare_war(me, rival)
	var guardian := _unit(grid, me, SHIELD, Vector2i(0, 0))
	var griffon := _unit(grid, rival, GRIFFON, Vector2i(1, 0))
	assert_eq(V2TechniqueRuntime.attack_multiplier(guardian, griffon), 1.0 + _technique(BRACE).basic_attack_bonus)

# --- O slot GLOBAL entre as QUATRO Doutrinas (cenário obrigatório) ----------------------------------------------------------------------------

func test_the_four_doctrines_share_the_single_slot_step_by_step():
	var grid := _world()
	var me := _player(9, 9, 9, 9)
	var rival := _rival_of(me)
	var city := _city_with_everything(me)
	var other := _city_with_everything(me)
	assert_true(city.can_train(CHAMPION) and city.can_train(HERO) and city.can_train(LEGEND_HUNTER) and city.can_train(GRIFFON), "pré-condição: as quatro livres")

	var champion := _unit(grid, me, CHAMPION, Vector2i(0, 0)) # Campeão Guardião ativo
	for kind in [HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(city.can_train(kind), "%s bloqueado com o Campeão" % kind)
	assert_eq(V2LegendarySystem.unavailable_reason(me, city, GRIFFON), V2LegendarySystem.SLOT_TAKEN_REASON)

	champion.hp = 1.0 # matar o Campeão em combate real
	var killer_data := UnitDatabase.create_unit("warrior")
	killer_data.attack = 100.0
	CombatResolver.resolve(grid.spawn_unit(Vector2i(1, 0), killer_data, rival), champion, grid)
	assert_false(V2LegendarySystem.has_active_legendary(me))

	city.set_production(GRIFFON) # iniciar o Grifo na Ordem
	assert_eq(city.production_item, GRIFFON)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER]:
		assert_false(other.can_train(kind), "%s bloqueado com o Grifo em produção" % kind)
	assert_true(city.can_train(GRIFFON), "a cidade produtora não se bloqueia")

	city.set_production("") # cancelar a produção
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_true(other.can_train(kind), "%s liberado: a reserva foi solta" % kind)

	city.set_production(HERO) # iniciar o Herói
	for kind in [CHAMPION, LEGEND_HUNTER, GRIFFON]:
		assert_false(other.can_train(kind), "%s bloqueado com o Herói" % kind)

func test_an_active_griffon_blocks_the_other_three_and_its_death_releases_them():
	var grid := _world()
	var me := _player(9, 9, 9, 9)
	var city := _city_with_everything(me)
	var unit := _unit(grid, me, GRIFFON, Vector2i(0, 0))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER]:
		assert_false(city.can_train(kind), kind)
	assert_false(city.can_train(GRIFFON), "nem um segundo Grifo")
	assert_eq(V2LegendarySystem.slots_used(me), 1)
	grid.remove_unit(unit)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_true(city.can_train(kind), kind)

func test_each_of_the_four_blocks_the_other_three_when_active():
	for active in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		var grid := _world()
		var me := _player(9, 9, 9, 9)
		var city := _city_with_everything(me)
		_unit(grid, me, active, Vector2i(0, 0))
		for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
			assert_false(city.can_train(kind), "%s ativo bloqueia %s" % [active, kind])
		assert_eq(V2LegendarySystem.max_active(), 1, "continua um único slot")

func test_a_rival_griffon_never_blocks_me_and_one_civilization_has_one_slot():
	var grid := _world()
	var me := _player(9, 9, 9, 9)
	var rival := _rival_of(me)
	_unit(grid, rival, GRIFFON, Vector2i(3, 0))
	var city := _city_with_everything(me)
	assert_true(city.can_train(GRIFFON))
	assert_eq(V2LegendarySystem.slots_used(me), 0)
	_unit(grid, me, GRIFFON, Vector2i(0, 0))
	assert_eq(V2LegendarySystem.slots_used(me), 1)

func test_a_debug_reset_does_not_kill_the_griffon_and_the_slot_stays_taken():
	var grid := _world()
	var me := _player(9, 9, 9, 9)
	var city := _city_with_everything(me)
	_unit(grid, me, GRIFFON, Vector2i(0, 0))
	me.v2_research.reset()
	assert_true(V2LegendarySystem.has_active_legendary(me))
	assert_false(city.can_train(CHAMPION))

func test_the_spawn_is_fail_closed_with_any_of_the_four_already_active():
	var grid := _world()
	var me := _player(9, 9, 9, 9)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_true(V2LegendarySystem.spawn_allowed(me, kind))
	_unit(grid, me, GRIFFON, Vector2i(0, 0))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(V2LegendarySystem.spawn_allowed(me, kind), kind)
	var city := _city_with_everything(me)
	city.stored_production = 0.0
	V2LegendarySystem.refuse_spawn(city, GRIFFON, false)
	assert_push_error("não nasceu")
	assert_eq(city.stored_production, UnitDatabase.create_unit(GRIFFON).production_cost)

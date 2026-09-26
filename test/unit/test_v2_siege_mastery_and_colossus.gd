extends "res://test/unit/v2_combat_fixture.gd"

## Grande Arsenal (v2_building_grand_arsenal, N8) e Colosso de Cerco (v2_legendary_siege_colossus, N9) — Aetherlands V2 Fase 11. O Grande Arsenal é
## um prédio NORMAL (BuildingData + requires_building); o Colosso é uma Lendária pelo MESMO V2LegendarySystem do Campeão Guardião, do Herói da
## Lâmina, do Caçador de Lendas, do Cavaleiro de Grifo e do Mestre das Sombras: as SEIS disputam o ÚNICO slot da civilização, sem nenhuma mudança
## no sistema. Números fixos pelo pedido.

func _city_with_everything(player: PlayerData) -> City:
	return _standalone_city_with_supply(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER, ROGUE_GUILD, ROGUE_MASTERY, SIEGE_ARSENAL, GRAND_ARSENAL])

# --- Grande Arsenal: definição -----------------------------------------------------------------------------------------------------

func test_the_grand_arsenal_exists_with_the_canonical_id_name_and_type():
	var building := BuildingDatabase.get_building(GRAND_ARSENAL)
	assert_not_null(building)
	assert_eq(building.display_name, "Grande Arsenal")
	assert_eq(building.display_name, V2ResearchDatabase.node_for_unlock_id(GRAND_ARSENAL).display_name)
	assert_eq(V2ResearchDatabase.node_for_unlock_id(GRAND_ARSENAL).unlock_type, "mastery_building")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == GRAND_ARSENAL).size(), 1)

## Fase 25: o "Grande Arsenal" V1 saiu do catálogo — o nome não é mais ambíguo.
func test_the_display_name_is_no_longer_shared_with_a_v1_building():
	assert_null(BuildingDatabase.get_building("grand_arsenal"))
	var named := BuildingDatabase.all_buildings().filter(func(b): return b.display_name == "Grande Arsenal")
	assert_eq(named.size(), 1)
	assert_eq(named[0].id, GRAND_ARSENAL)

func test_its_only_function_is_to_enable_the_colossus_and_it_has_no_bonuses():
	var building := BuildingDatabase.get_building(GRAND_ARSENAL)
	assert_eq(building.trains_unit, COLOSSUS)
	assert_eq(BuildingDatabase.building_that_trains(COLOSSUS), building)
	assert_false("upkeep" in building.get_property_list().map(func(p): return p.name))

func test_it_requires_the_arsenal_costs_55_and_shares_the_scale_of_the_other_masteries():
	var grand := BuildingDatabase.get_building(GRAND_ARSENAL)
	assert_eq(grand.requires_building, SIEGE_ARSENAL)
	assert_eq(BuildingDatabase.get_building(SIEGE_ARSENAL).trains_unit, CATAPULT, "o Arsenal segue treinando a linha convencional")
	assert_eq(grand.production_cost, 55.0)
	for other in [G_MASTERY, ARENA, R_TOWER, C_ORDER, ROGUE_MASTERY]:
		assert_eq(grand.production_cost, BuildingDatabase.get_building(other).production_cost, other)
	assert_lt(grand.production_cost, UnitDatabase.create_unit(COLOSSUS).production_cost)

func test_it_reuses_a_provisional_v1_model_and_has_no_v1_gate():
	var building := BuildingDatabase.get_building(GRAND_ARSENAL)
	assert_true(ResourceLoader.exists(building.model_scene_path), building.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(GRAND_ARSENAL, race), "Grande Arsenal", race)

# --- Grande Arsenal: construir --------------------------------------------------------------------------------------------------------

func test_it_cannot_be_built_before_n8_and_can_after_in_a_city_with_the_arsenal():
	var player := _siege_player(7)
	var city := _standalone_city(player, [SIEGE_ARSENAL])
	assert_false(city.can_build(GRAND_ARSENAL))
	player.v2_research.complete_research("v2_doctrine_siege_8")
	assert_true(city.can_build(GRAND_ARSENAL))

func test_a_city_without_the_arsenal_cannot_build_it_even_with_n8():
	var player := _siege_player(8)
	var city := _standalone_city(player)
	assert_true(city._research_unlocked_for_building(GRAND_ARSENAL), "a pesquisa está ok...")
	assert_false(city._prerequisite_building_present(GRAND_ARSENAL), "...falta o Arsenal de Cerco")
	assert_false(city.can_build(GRAND_ARSENAL))
	city.buildings[SIEGE_ARSENAL] = true
	assert_true(city.can_build(GRAND_ARSENAL))

func test_no_other_hall_no_v1_building_and_no_v1_tech_stands_in_for_the_arsenal():
	var player := _player(9, 9, 9, 9, 9, 8)
	var city := _standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER, ROGUE_GUILD, ROGUE_MASTERY, "barracks", "siege_workshop"])
	assert_false(city.can_build(GRAND_ARSENAL))

func test_it_uses_one_normal_slot_is_built_once_and_needs_room():
	var player := _siege_player(8)
	var city := _standalone_city(player, [SIEGE_ARSENAL])
	var used := city.used_building_slots()
	city.buildings[GRAND_ARSENAL] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(GRAND_ARSENAL), "não constrói duas vezes")
	var small := _standalone_city(player, [SIEGE_ARSENAL])
	small.city_level = 1 # Fase 13: 4 slots (não é mais população) -- Arsenal + 3 mais enche
	for id in ["granary", "workshop", "market"]:
		small.buildings[id] = true
	assert_false(small.can_build(GRAND_ARSENAL), "regra de slots de sempre")
	small.city_level = 2 # 7 slots
	assert_true(small.can_build(GRAND_ARSENAL))

func test_the_colossus_stays_blocked_with_the_grand_arsenal_but_without_n9():
	var player := _siege_player(8)
	var city := _standalone_city(player, [SIEGE_ARSENAL, GRAND_ARSENAL])
	assert_false(city.can_train(COLOSSUS), "N8 dá o prédio; o Colosso é do N9")
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, COLOSSUS), "Requer pesquisa: Colosso de Cerco.")

# --- Colosso de Cerco: definição -----------------------------------------------------------------------------------------------------

func test_the_colossus_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(COLOSSUS)
	assert_eq(data.unit_name, "Colosso de Cerco")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points, data.attack_range, data.production_cost], [44.0, 9.0, 8.0, 2.0, 3, 110.0])
	assert_eq(data.vision_range, 4)
	assert_eq(data.visual_kind, COLOSSUS, "o SaveManager recria a unidade por ele")
	assert_false(data.can_found_city)

func test_it_carries_the_legendary_and_siege_traits_and_the_ground_movement_profile():
	var data := UnitDatabase.create_unit(COLOSSUS)
	assert_true(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_true(data.has_trait(UnitData.TRAIT_SIEGE))
	assert_false(data.has_trait(UnitData.TRAIT_MOUNTED) or data.has_trait(UnitData.TRAIT_FLYING))
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND, "a singularidade não é o movimento")
	assert_true(data.ignores_technique_stationary_requirement, "Artilharia Andante")

func test_it_is_not_stronger_than_the_other_legendaries_in_the_numbers():
	var colossus := UnitDatabase.create_unit(COLOSSUS)
	var champion := UnitDatabase.create_unit(CHAMPION)
	var hero := UnitDatabase.create_unit(HERO)
	assert_lte(colossus.max_hp, champion.max_hp, "nunca supera — empate é permitido")
	assert_lt(colossus.defense, champion.defense)
	assert_lt(colossus.attack, hero.attack)
	assert_gt(colossus.production_cost, UnitDatabase.create_unit(BOMBARD).production_cost)

func test_the_colossus_is_a_legendary_by_metadata_and_does_not_evolve():
	assert_true(V2LegendarySystem.is_legendary_kind(COLOSSUS))
	assert_eq(V2ResearchDatabase.node_for_unlock_id(COLOSSUS).unlock_type, "legendary_candidate")
	var grid := _world()
	var unit := _unit(grid, _siege_player(9), COLOSSUS, Vector2i(0, 0))
	assert_true(V2LegendarySystem.is_legendary_unit(unit))
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "")

# --- Não é upgrade, não está na cadeia ------------------------------------------------------------------------------------------------

func test_it_is_outside_the_conventional_chain_and_does_not_replace_the_bombard():
	assert_false(V2UnitLine.is_line_unit(COLOSSUS))
	assert_eq(V2UnitLine.unit_ids("siege"), [CATAPULT, TREBUCHET, BOMBARD])
	assert_eq(V2UnitLine.branch_of(COLOSSUS), "")
	assert_eq(V2UnitLine.doctrine_branch_of(COLOSSUS), "siege", "pertence à Doutrina, não à cadeia")
	var player := _siege_player(9)
	assert_eq(V2UnitLine.resolve_trainable_form(player, CATAPULT), BOMBARD, "a produção convencional segue na Bombarda")
	assert_eq(V2UnitLine.resolve_trainable_form(player, COLOSSUS), "")
	# Fase 15: o Colosso de Cerco custa 5 Suprimentos, acima da base de uma cidade sozinha (4).
	var city := _standalone_city_with_supply(player, [SIEGE_ARSENAL, GRAND_ARSENAL])
	assert_true(city.can_train(BOMBARD))
	assert_true(city.can_train(COLOSSUS))
	city.set_production(COLOSSUS)
	assert_true(city.can_train(BOMBARD), "a Bombarda segue treinável mesmo com o Colosso na fila")

func test_the_bombard_does_not_evolve_into_it():
	var grid := _world()
	var bombard := _unit(grid, _siege_player(9), BOMBARD, Vector2i(0, 0))
	assert_eq(V2UnitUpgrade.get_upgrade_target(bombard), "")

func test_producing_it_needs_n9_the_grand_arsenal_and_a_free_slot_and_costs_110():
	var player := _siege_player(8)
	# Fase 15: o Colosso de Cerco custa 5 Suprimentos, acima da base de uma cidade sozinha (4).
	var city := _standalone_city_with_supply(player, [SIEGE_ARSENAL, GRAND_ARSENAL])
	assert_false(city.can_train(COLOSSUS), "sem N9")
	player.v2_research.complete_research("v2_doctrine_siege_9")
	assert_true(city.can_train(COLOSSUS))
	assert_false(_standalone_city(player, [SIEGE_ARSENAL]).can_train(COLOSSUS), "sem o Grande Arsenal")
	assert_false(_standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER, ROGUE_GUILD, ROGUE_MASTERY]).can_train(COLOSSUS), "nenhum outro prédio de maestria o treina")
	city.set_production(COLOSSUS)
	assert_eq(city.production_cost(), 110.0)

func test_the_other_masteries_do_not_train_it_and_the_grand_arsenal_does_not_train_the_others():
	var player := _player(9, 9, 9, 9, 9, 9)
	var arsenal_city := _standalone_city(player, [SIEGE_ARSENAL, GRAND_ARSENAL])
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_false(arsenal_city.can_train(kind), kind)

# --- Herança das Técnicas ---------------------------------------------------------------------------------------------------------------

func test_it_inherits_both_siege_techniques_and_none_of_the_others():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var unit := _unit(grid, me, COLOSSUS, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [DEMOLITION_AMMO, PREPARED_BOMBARDMENT])

func test_the_technique_data_and_the_legendary_system_do_not_mention_the_colossus():
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_false(technique.id.contains("siege_colossus"))
	var techniques := FileAccess.get_file_as_string("res://scripts/data/V2DoctrineTechniqueDatabase.gd")
	assert_false(techniques.contains("v2_legendary_siege_colossus"), "nada duplicado no dado do Lendário")
	var legendary := _code_only(FileAccess.get_file_as_string("res://scripts/core/V2LegendarySystem.gd"))
	for word in ["siege_colossus", "siege", "Cerco", "Colosso"]:
		assert_false(legendary.contains(word), "o sistema do slot não conhece '%s'" % word)

func test_the_colossus_is_recognised_by_demolition_ammo_and_prepared_bombardment_by_data_not_by_name():
	var grid := _world()
	var me := _siege_player(9)
	var rival := _rival_of(me)
	var colossus := _unit(grid, me, COLOSSUS, Vector2i(0, 0))
	var city := _enemy_city(grid, rival, Vector2i(3, 0))
	assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(colossus), 1.4, 0.0001, "Munição Demolidora")
	assert_true(V2TechniqueRuntime.perform_city_strike(colossus, PREPARED_BOMBARDMENT, city, grid), "Bombardeio Preparado herdado")

# --- Desmantelar (siege) e Caçada Lendária (legendary) o counteram por origens DIFERENTES -----------------------------------------------

func test_dismantle_counters_the_colossus_through_the_siege_trait():
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var ladino := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var colossus := _unit(grid, rival, COLOSSUS, Vector2i(1, 0))
	assert_almost_eq(UnitAbilities.attack_multiplier(ladino, colossus), 1.5, 0.0001)

func test_without_dismantle_researched_there_is_no_bonus_against_the_colossus():
	var grid := _world()
	var me := _rogue_player(3) # sem N6
	var rival := _rival_of(me)
	var ladino := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var colossus := _unit(grid, rival, COLOSSUS, Vector2i(1, 0))
	assert_almost_eq(UnitAbilities.attack_multiplier(ladino, colossus), 1.0, 0.0001)

func test_legend_hunt_counters_the_colossus_through_the_legendary_trait():
	var grid := _world()
	var me := _ranger_player(9)
	var rival := _rival_of(me)
	var hunter := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	var colossus := _unit(grid, rival, COLOSSUS, Vector2i(1, 0))
	assert_almost_eq(UnitAbilities.attack_multiplier(hunter, colossus), 1.4, 0.0001)

func test_a_normal_bombard_never_gets_the_legend_hunt_bonus_no_legendary_trait():
	var grid := _world()
	var me := _ranger_player(9)
	var rival := _rival_of(me)
	var hunter := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	var bombard := _unit(grid, rival, BOMBARD, Vector2i(1, 0))
	assert_almost_eq(UnitAbilities.attack_multiplier(hunter, bombard), 1.0, 0.0001, "a Bombarda comum não é Lendária")

## Origens DIFERENTES (siege x legendary) não se anulam nem competem: um atacante hipotético com AMBOS os counters combinaria os dois fatores
## pela regra normal de multiplicadores (nunca deduplicar efeitos de origens diferentes — só a MESMA origem nunca conta duas vezes).
func test_siege_and_legendary_are_different_origins_and_would_combine_not_cancel():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var rival := _rival_of(me)
	var colossus := _unit(grid, rival, COLOSSUS, Vector2i(1, 0))
	var ladino := _unit(grid, me, ROGUE, Vector2i(0, 0)) # só Desmantelar (siege)
	var hunter := _unit(grid, me, LEGEND_HUNTER, Vector2i(2, 0)) # só Caçada (legendary)
	var dismantle_only: float = UnitAbilities.attack_multiplier(ladino, colossus)
	var legend_hunt_only: float = UnitAbilities.attack_multiplier(hunter, colossus)
	assert_almost_eq(dismantle_only, 1.5, 0.0001)
	assert_almost_eq(legend_hunt_only, 1.4, 0.0001)
	assert_ne(dismantle_only, 1.0)
	assert_ne(legend_hunt_only, 1.0)

# --- O slot GLOBAL entre as SEIS Doutrinas (cenário obrigatório) ----------------------------------------------------------------------------

func test_the_six_doctrines_share_the_single_slot_step_by_step():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var rival := _rival_of(me)
	var city := _city_with_everything(me)
	var other := _city_with_everything(me)
	assert_true(city.can_train(CHAMPION) and city.can_train(HERO) and city.can_train(LEGEND_HUNTER) and city.can_train(GRIFFON) and city.can_train(SHADOW_MASTER) and city.can_train(COLOSSUS), "pré-condição: as seis livres")

	var champion := _unit(grid, me, CHAMPION, Vector2i(0, 0)) # Campeão Guardião ativo
	for kind in [HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER, COLOSSUS]:
		assert_false(city.can_train(kind), "%s bloqueado com o Campeão" % kind)
	assert_eq(V2LegendarySystem.unavailable_reason(me, city, COLOSSUS), V2LegendarySystem.SLOT_TAKEN_REASON)

	champion.hp = 1.0 # matar o Campeão em combate real
	var killer_data := UnitDatabase.create_unit("warrior")
	killer_data.attack = 100.0
	CombatResolver.resolve(grid.spawn_unit(Vector2i(1, 0), killer_data, rival), champion, grid)
	assert_false(V2LegendarySystem.has_active_legendary(me))

	city.set_production(COLOSSUS) # iniciar o Colosso no Grande Arsenal
	assert_eq(city.production_item, COLOSSUS)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_false(other.can_train(kind), "%s bloqueado com o Colosso em produção" % kind)
	assert_true(city.can_train(COLOSSUS), "a cidade produtora não se bloqueia")

	city.set_production("") # cancelar a produção
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER, COLOSSUS]:
		assert_true(other.can_train(kind), "%s liberado: a reserva foi solta" % kind)

	city.set_production(SHADOW_MASTER) # iniciar o Mestre das Sombras
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, COLOSSUS]:
		assert_false(other.can_train(kind), "%s bloqueado com o Mestre" % kind)

func test_an_active_colossus_blocks_the_other_five_and_its_death_releases_them():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var city := _city_with_everything(me)
	var unit := _unit(grid, me, COLOSSUS, Vector2i(0, 0))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_false(city.can_train(kind), kind)
	assert_false(city.can_train(COLOSSUS), "nem um segundo Colosso")
	assert_eq(V2LegendarySystem.slots_used(me), 1)
	grid.remove_unit(unit)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER, COLOSSUS]:
		assert_true(city.can_train(kind), kind)

func test_each_of_the_six_blocks_the_other_five_when_active():
	for active in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER, COLOSSUS]:
		var grid := _world()
		var me := _player(9, 9, 9, 9, 9, 9)
		var city := _city_with_everything(me)
		_unit(grid, me, active, Vector2i(0, 0))
		for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER, COLOSSUS]:
			assert_false(city.can_train(kind), "%s ativo bloqueia %s" % [active, kind])
		assert_eq(V2LegendarySystem.max_active(), 1, "continua um único slot")

func test_a_rival_colossus_never_blocks_me_and_one_civilization_has_one_slot():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var rival := _rival_of(me)
	_unit(grid, rival, COLOSSUS, Vector2i(3, 0))
	var city := _city_with_everything(me)
	assert_true(city.can_train(COLOSSUS))
	assert_eq(V2LegendarySystem.slots_used(me), 0)
	_unit(grid, me, COLOSSUS, Vector2i(0, 0))
	assert_eq(V2LegendarySystem.slots_used(me), 1)

func test_a_debug_reset_does_not_kill_the_colossus_and_the_slot_stays_taken():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var city := _city_with_everything(me)
	_unit(grid, me, COLOSSUS, Vector2i(0, 0))
	me.v2_research.reset()
	assert_true(V2LegendarySystem.has_active_legendary(me))
	assert_false(city.can_train(CHAMPION))

func test_the_spawn_is_fail_closed_with_any_of_the_six_already_active():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER, COLOSSUS]:
		assert_true(V2LegendarySystem.spawn_allowed(me, kind))
	_unit(grid, me, COLOSSUS, Vector2i(0, 0))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER, COLOSSUS]:
		assert_false(V2LegendarySystem.spawn_allowed(me, kind), kind)
	var city := _city_with_everything(me)
	city.stored_production = 0.0
	V2LegendarySystem.refuse_spawn(city, COLOSSUS, false)
	assert_push_error("não nasceu")
	assert_eq(city.stored_production, UnitDatabase.create_unit(COLOSSUS).production_cost)

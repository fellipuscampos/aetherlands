extends "res://test/unit/v2_combat_fixture.gd"

## Refúgio das Sombras (v2_building_rogue_mastery, N8) e Mestre das Sombras (v2_legendary_shadow_master, N9) — Aetherlands V2 Fase 10. O Refúgio é
## um prédio NORMAL (BuildingData + requires_building); o Mestre das Sombras é uma Lendária pelo MESMO V2LegendarySystem do Campeão Guardião, do
## Herói da Lâmina, do Caçador de Lendas e do Cavaleiro de Grifo: as CINCO disputam o ÚNICO slot da civilização, sem nenhuma mudança no sistema.
## Números = BALANCE PLACEHOLDER.

func _city_with_everything(player: PlayerData) -> City:
	return _standalone_city_with_supply(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER, ROGUE_GUILD, ROGUE_MASTERY])

# --- Refúgio: definição -----------------------------------------------------------------------------------------------------

func test_the_refuge_exists_with_the_canonical_id_name_and_type():
	var building := BuildingDatabase.get_building(ROGUE_MASTERY)
	assert_not_null(building)
	assert_eq(building.display_name, "Refúgio das Sombras")
	assert_eq(building.display_name, V2ResearchDatabase.node_for_unlock_id(ROGUE_MASTERY).display_name)
	assert_eq(V2ResearchDatabase.node_for_unlock_id(ROGUE_MASTERY).unlock_type, "mastery_building")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == ROGUE_MASTERY).size(), 1)

func test_its_only_function_is_to_enable_the_shadow_master_and_it_has_no_bonuses():
	var building := BuildingDatabase.get_building(ROGUE_MASTERY)
	assert_eq(building.trains_unit, SHADOW_MASTER)
	assert_eq(BuildingDatabase.building_that_trains(SHADOW_MASTER), building)
	assert_false("upkeep" in building.get_property_list().map(func(p): return p.name))

func test_it_requires_the_guild_costs_55_and_shares_the_scale_of_the_other_masteries():
	var refuge := BuildingDatabase.get_building(ROGUE_MASTERY)
	assert_eq(refuge.requires_building, ROGUE_GUILD)
	assert_eq(BuildingDatabase.get_building(ROGUE_GUILD).trains_unit, ROGUE, "a Guilda segue treinando a linha convencional")
	assert_eq(refuge.production_cost, 55.0)
	for other in [G_MASTERY, ARENA, R_TOWER, C_ORDER]:
		assert_eq(refuge.production_cost, BuildingDatabase.get_building(other).production_cost, other)
	assert_lt(refuge.production_cost, UnitDatabase.create_unit(SHADOW_MASTER).production_cost)

func test_it_reuses_a_provisional_v1_model_and_has_no_v1_gate():
	var building := BuildingDatabase.get_building(ROGUE_MASTERY)
	assert_true(ResourceLoader.exists(building.model_scene_path), building.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(ROGUE_MASTERY, race), "Refúgio das Sombras", race)

# --- Refúgio: construir --------------------------------------------------------------------------------------------------------

func test_it_cannot_be_built_before_n8_and_can_after_in_a_city_with_the_guild():
	var player := _rogue_player(7)
	var city := _standalone_city(player, [ROGUE_GUILD])
	assert_false(city.can_build(ROGUE_MASTERY))
	player.v2_research.complete_research("v2_doctrine_rogue_8")
	assert_true(city.can_build(ROGUE_MASTERY))

func test_a_city_without_the_guild_cannot_build_it_even_with_n8():
	var player := _rogue_player(8)
	var city := _standalone_city(player)
	assert_true(city._research_unlocked_for_building(ROGUE_MASTERY), "a pesquisa está ok...")
	assert_false(city._prerequisite_building_present(ROGUE_MASTERY), "...falta a Guilda dos Ladinos")
	assert_false(city.can_build(ROGUE_MASTERY))
	city.buildings[ROGUE_GUILD] = true
	assert_true(city.can_build(ROGUE_MASTERY))

func test_no_other_hall_no_v1_building_and_no_v1_tech_stands_in_for_the_guild():
	var player := _player(9, 9, 9, 9, 8)
	var city := _standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER, "barracks"])
	assert_false(city.can_build(ROGUE_MASTERY))

func test_it_uses_one_normal_slot_is_built_once_and_needs_room():
	var player := _rogue_player(8)
	var city := _standalone_city(player, [ROGUE_GUILD])
	var used := city.used_building_slots()
	city.buildings[ROGUE_MASTERY] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(ROGUE_MASTERY), "não constrói duas vezes")
	var small := _standalone_city(player, [ROGUE_GUILD])
	small.city_level = 1 # Fase 13: 4 slots (não é mais população) -- Guilda + 3 mais enche
	for id in ["granary", "workshop", "market"]:
		small.buildings[id] = true
	assert_false(small.can_build(ROGUE_MASTERY), "regra de slots de sempre")
	small.city_level = 2 # 7 slots
	assert_true(small.can_build(ROGUE_MASTERY))

func test_the_unlock_belongs_to_the_researching_civilization_only_and_goes_through_the_normal_queue():
	assert_true(_standalone_city(_rogue_player(8), [ROGUE_GUILD]).can_build(ROGUE_MASTERY))
	assert_false(_standalone_city(_rogue_player(7), [ROGUE_GUILD]).can_build(ROGUE_MASTERY))
	assert_false(_standalone_city(_player(9, 9, 9, 9, 0), [ROGUE_GUILD]).can_build(ROGUE_MASTERY), "outras Doutrinas não bastam")
	var city := _standalone_city(_rogue_player(8), [ROGUE_GUILD])
	city.set_production(ROGUE_MASTERY)
	assert_eq(city.production_item, ROGUE_MASTERY)
	assert_eq(city.production_cost(), 55.0)

func test_the_shadow_master_stays_blocked_with_the_refuge_but_without_n9():
	var player := _rogue_player(8)
	var city := _standalone_city(player, [ROGUE_GUILD, ROGUE_MASTERY])
	assert_false(city.can_train(SHADOW_MASTER), "N8 dá o prédio; o Mestre das Sombras é do N9")
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, SHADOW_MASTER), "Requer pesquisa: Mestre das Sombras.")

# --- Mestre das Sombras: definição -----------------------------------------------------------------------------------------------------

func test_the_shadow_master_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(SHADOW_MASTER)
	assert_eq(data.unit_name, "Mestre das Sombras")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points, data.production_cost], [30.0, 10.5, 4.5, 4.0, 95.0])
	assert_eq(data.vision_range, 5)
	assert_eq(data.attack_range, 1, "corpo a corpo")
	assert_eq(data.visual_kind, SHADOW_MASTER, "o SaveManager recria a unidade por ele")
	assert_false(data.can_found_city)

func test_it_carries_the_legendary_trait_and_the_infiltrator_movement_profile_by_data():
	var data := UnitDatabase.create_unit(SHADOW_MASTER)
	assert_true(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(data.has_trait(UnitData.TRAIT_MOUNTED) or data.has_trait(UnitData.TRAIT_FLYING), "não é montado nem voa")
	assert_eq(data.movement_profile, UnitData.MovementProfile.INFILTRATOR)
	assert_false(data.is_flying(), "infiltração não é voo")

func test_it_is_not_stronger_than_the_other_legendaries_in_the_numbers():
	var shadow := UnitDatabase.create_unit(SHADOW_MASTER)
	var champion := UnitDatabase.create_unit(CHAMPION)
	var hero := UnitDatabase.create_unit(HERO)
	assert_lt(shadow.max_hp, champion.max_hp)
	assert_lt(shadow.defense, champion.defense)
	assert_lt(shadow.attack, hero.attack)
	assert_gt(shadow.movement_points, UnitDatabase.create_unit(ASSASSIN).movement_points, "o valor dele é atravessar formações, não os números")
	assert_gt(shadow.production_cost, UnitDatabase.create_unit(ASSASSIN).production_cost)

func test_the_shadow_master_is_a_legendary_by_metadata_and_does_not_evolve():
	assert_true(V2LegendarySystem.is_legendary_kind(SHADOW_MASTER))
	assert_eq(V2ResearchDatabase.node_for_unlock_id(SHADOW_MASTER).unlock_type, "legendary_candidate")
	var grid := _world()
	var unit := _unit(grid, _rogue_player(9), SHADOW_MASTER, Vector2i(0, 0))
	assert_true(V2LegendarySystem.is_legendary_unit(unit))
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "")

# --- Não é upgrade, não está na cadeia ------------------------------------------------------------------------------------------------

func test_it_is_outside_the_conventional_chain_and_does_not_replace_the_assassin():
	assert_false(V2UnitLine.is_line_unit(SHADOW_MASTER))
	assert_eq(V2UnitLine.unit_ids("rogue"), [ROGUE, SABOTEUR, ASSASSIN])
	assert_eq(V2UnitLine.branch_of(SHADOW_MASTER), "")
	assert_eq(V2UnitLine.doctrine_branch_of(SHADOW_MASTER), "rogue", "pertence à Doutrina, não à cadeia")
	var player := _rogue_player(9)
	assert_eq(V2UnitLine.resolve_trainable_form(player, ROGUE), ASSASSIN, "a produção convencional segue no Assassino")
	assert_eq(V2UnitLine.resolve_trainable_form(player, SHADOW_MASTER), "")
	# Fase 15: o Mestre das Sombras custa 5 Suprimentos, acima da base de uma cidade sozinha (4).
	var city := _standalone_city_with_supply(player, [ROGUE_GUILD, ROGUE_MASTERY])
	assert_true(city.can_train(ASSASSIN))
	assert_true(city.can_train(SHADOW_MASTER))
	city.set_production(SHADOW_MASTER)
	assert_true(city.can_train(ASSASSIN), "o Assassino segue treinável mesmo com o Mestre na fila")

func test_the_assassin_does_not_evolve_into_it():
	var grid := _world()
	var assassin := _unit(grid, _rogue_player(9), ASSASSIN, Vector2i(0, 0))
	assert_eq(V2UnitUpgrade.get_upgrade_target(assassin), "")

func test_producing_it_needs_n9_the_refuge_and_a_free_slot_and_costs_95():
	var player := _rogue_player(8)
	# Fase 15: o Mestre das Sombras custa 5 Suprimentos, acima da base de uma cidade sozinha (4).
	var city := _standalone_city_with_supply(player, [ROGUE_GUILD, ROGUE_MASTERY])
	assert_false(city.can_train(SHADOW_MASTER), "sem N9")
	player.v2_research.complete_research("v2_doctrine_rogue_9")
	assert_true(city.can_train(SHADOW_MASTER))
	assert_false(_standalone_city(player, [ROGUE_GUILD]).can_train(SHADOW_MASTER), "sem o Refúgio")
	assert_false(_standalone_city(player, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER]).can_train(SHADOW_MASTER), "nenhum outro prédio de maestria o treina")
	city.set_production(SHADOW_MASTER)
	assert_eq(city.production_cost(), 95.0)

func test_the_other_masteries_do_not_train_it_and_the_refuge_does_not_train_the_others():
	var player := _player(9, 9, 9, 9, 9)
	var refuge_city := _standalone_city(player, [ROGUE_GUILD, ROGUE_MASTERY])
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(refuge_city.can_train(kind), kind)

# --- Herança das Técnicas ---------------------------------------------------------------------------------------------------------------

func test_it_inherits_both_rogue_techniques_and_none_of_the_others():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9)
	var unit := _unit(grid, me, SHADOW_MASTER, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [SNEAK_ATTACK, DISMANTLE])

func test_the_technique_data_and_the_legendary_system_do_not_mention_the_shadow_master():
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_false(technique.id.contains("shadow_master"))
	var techniques := FileAccess.get_file_as_string("res://scripts/data/V2DoctrineTechniqueDatabase.gd")
	assert_false(techniques.contains("v2_legendary_shadow_master"), "nada duplicado no dado do Lendário")
	var legendary := _code_only(FileAccess.get_file_as_string("res://scripts/core/V2LegendarySystem.gd"))
	for word in ["shadow_master", "rogue", "Sombras", "Ladino"]:
		assert_false(legendary.contains(word), "o sistema do slot não conhece '%s'" % word)

func test_the_shadow_master_is_recognised_by_the_sneak_attack_and_dismantle_by_data_not_by_name():
	var grid := _world()
	var me := _rogue_player(9)
	var rival := _rival_of(me)
	var shadow := _unit(grid, me, SHADOW_MASTER, Vector2i(0, 0))
	var caster := _traited_foe(grid, rival, Vector2i(1, 0), UnitData.TRAIT_CASTER, 60.0, 3.0)
	assert_almost_eq(UnitAbilities.attack_multiplier(shadow, caster), 1.5, 0.0001, "Desmantelar")
	assert_true(V2TechniqueRuntime.perform_strike(shadow, SNEAK_ATTACK, caster, grid), "Ataque Furtivo herdado")

# --- O slot GLOBAL entre as CINCO Doutrinas (cenário obrigatório) ----------------------------------------------------------------------------

func test_the_five_doctrines_share_the_single_slot_step_by_step():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9)
	var rival := _rival_of(me)
	var city := _city_with_everything(me)
	var other := _city_with_everything(me)
	assert_true(city.can_train(CHAMPION) and city.can_train(HERO) and city.can_train(LEGEND_HUNTER) and city.can_train(GRIFFON) and city.can_train(SHADOW_MASTER), "pré-condição: as cinco livres")

	var champion := _unit(grid, me, CHAMPION, Vector2i(0, 0)) # Campeão Guardião ativo
	for kind in [HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_false(city.can_train(kind), "%s bloqueado com o Campeão" % kind)
	assert_eq(V2LegendarySystem.unavailable_reason(me, city, SHADOW_MASTER), V2LegendarySystem.SLOT_TAKEN_REASON)

	champion.hp = 1.0 # matar o Campeão em combate real
	var killer_data := UnitDatabase.create_unit("warrior")
	killer_data.attack = 100.0
	CombatResolver.resolve(grid.spawn_unit(Vector2i(1, 0), killer_data, rival), champion, grid)
	assert_false(V2LegendarySystem.has_active_legendary(me))

	city.set_production(SHADOW_MASTER) # iniciar o Mestre no Refúgio
	assert_eq(city.production_item, SHADOW_MASTER)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(other.can_train(kind), "%s bloqueado com o Mestre em produção" % kind)
	assert_true(city.can_train(SHADOW_MASTER), "a cidade produtora não se bloqueia")

	city.set_production("") # cancelar a produção
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_true(other.can_train(kind), "%s liberado: a reserva foi solta" % kind)

	city.set_production(HERO) # iniciar o Herói
	for kind in [CHAMPION, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_false(other.can_train(kind), "%s bloqueado com o Herói" % kind)

func test_an_active_shadow_master_blocks_the_other_four_and_its_death_releases_them():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9)
	var city := _city_with_everything(me)
	var unit := _unit(grid, me, SHADOW_MASTER, Vector2i(0, 0))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(city.can_train(kind), kind)
	assert_false(city.can_train(SHADOW_MASTER), "nem um segundo Mestre")
	assert_eq(V2LegendarySystem.slots_used(me), 1)
	grid.remove_unit(unit)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_true(city.can_train(kind), kind)

func test_each_of_the_five_blocks_the_other_four_when_active():
	for active in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		var grid := _world()
		var me := _player(9, 9, 9, 9, 9)
		var city := _city_with_everything(me)
		_unit(grid, me, active, Vector2i(0, 0))
		for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
			assert_false(city.can_train(kind), "%s ativo bloqueia %s" % [active, kind])
		assert_eq(V2LegendarySystem.max_active(), 1, "continua um único slot")

func test_a_rival_shadow_master_never_blocks_me_and_one_civilization_has_one_slot():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9)
	var rival := _rival_of(me)
	_unit(grid, rival, SHADOW_MASTER, Vector2i(3, 0))
	var city := _city_with_everything(me)
	assert_true(city.can_train(SHADOW_MASTER))
	assert_eq(V2LegendarySystem.slots_used(me), 0)
	_unit(grid, me, SHADOW_MASTER, Vector2i(0, 0))
	assert_eq(V2LegendarySystem.slots_used(me), 1)

func test_a_debug_reset_does_not_kill_the_shadow_master_and_the_slot_stays_taken():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9)
	var city := _city_with_everything(me)
	_unit(grid, me, SHADOW_MASTER, Vector2i(0, 0))
	me.v2_research.reset()
	assert_true(V2LegendarySystem.has_active_legendary(me))
	assert_false(city.can_train(CHAMPION))

func test_the_spawn_is_fail_closed_with_any_of_the_five_already_active():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_true(V2LegendarySystem.spawn_allowed(me, kind))
	_unit(grid, me, SHADOW_MASTER, Vector2i(0, 0))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW_MASTER]:
		assert_false(V2LegendarySystem.spawn_allowed(me, kind), kind)
	var city := _city_with_everything(me)
	city.stored_production = 0.0
	V2LegendarySystem.refuse_spawn(city, SHADOW_MASTER, false)
	assert_push_error("não nasceu")
	assert_eq(city.stored_production, UnitDatabase.create_unit(SHADOW_MASTER).production_cost)

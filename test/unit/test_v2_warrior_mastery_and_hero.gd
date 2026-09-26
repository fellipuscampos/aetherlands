extends "res://test/unit/v2_combat_fixture.gd"

## Arena dos Campeões (v2_building_warrior_mastery, N8) e Herói da Lâmina (v2_legendary_blade_hero, N9) — Aetherlands V2
## Fase 7. A Arena é um prédio NORMAL (BuildingData + requires_building) e o Herói é uma Lendária pelo MESMO V2LegendarySystem
## do Campeão Guardião: os dois disputam o ÚNICO slot da civilização. Números = BALANCE PLACEHOLDER.

func _city_with_everything(player: PlayerData) -> City:
	return _standalone_city_with_supply(player, [G_HALL, G_MASTERY, W_HALL, ARENA])

# --- Arena: definição -----------------------------------------------------------------------------------------------

func test_the_arena_exists_with_the_canonical_id_and_name():
	var building := BuildingDatabase.get_building(ARENA)
	assert_not_null(building)
	assert_eq(building.display_name, "Arena dos Campeões")
	assert_eq(building.display_name, V2ResearchDatabase.node_for_unlock_id(ARENA).display_name, "o nome do prédio é o do nó")
	assert_eq(V2ResearchDatabase.node_for_unlock_id(ARENA).unlock_type, "mastery_building")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == ARENA).size(), 1, "registrada uma vez")

func test_its_only_function_is_to_enable_the_hero_and_it_has_no_bonuses():
	var building := BuildingDatabase.get_building(ARENA)
	assert_eq(building.trains_unit, HERO)
	assert_eq(BuildingDatabase.building_that_trains(HERO), building)
	var names: Array = building.get_property_list().map(func(p): return p.name)
	assert_false("upkeep" in names)

func test_it_requires_the_weapons_hall_and_does_not_replace_it():
	var building := BuildingDatabase.get_building(ARENA)
	assert_eq(building.requires_building, W_HALL)
	assert_eq(BuildingDatabase.get_building(W_HALL).trains_unit, WARRIOR, "o Salão de Armas segue treinando a linha convencional")
	assert_ne(building, BuildingDatabase.get_building(W_HALL))

func test_the_cost_is_55_the_same_scale_as_the_guardian_mastery_and_above_the_hall():
	var arena := BuildingDatabase.get_building(ARENA)
	assert_eq(arena.production_cost, 55.0)
	assert_eq(arena.production_cost, BuildingDatabase.get_building(G_MASTERY).production_cost, "mesma escala do Bastião de Maestria")
	assert_gt(arena.production_cost, BuildingDatabase.get_building(W_HALL).production_cost * 2.0)
	assert_lt(arena.production_cost, UnitDatabase.create_unit(HERO).production_cost)

func test_it_reuses_a_provisional_v1_model_and_has_no_v1_tech_gate():
	var building := BuildingDatabase.get_building(ARENA)
	assert_true(ResourceLoader.exists(building.model_scene_path), building.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(ARENA, race), "Arena dos Campeões", race)

# --- Arena: construir -----------------------------------------------------------------------------------------------

func test_it_cannot_be_built_before_n8_and_can_after_in_a_city_with_the_hall():
	var player := _player(7)
	var city := _standalone_city(player, [W_HALL])
	assert_false(city.can_build(ARENA))
	player.v2_research.complete_research("v2_doctrine_warrior_8")
	assert_true(city.can_build(ARENA))

func test_a_city_without_the_weapons_hall_cannot_build_it_even_with_n8():
	var player := _player(8)
	var city := _standalone_city(player)
	assert_true(city._research_unlocked_for_building(ARENA), "a pesquisa está ok...")
	assert_false(city._prerequisite_building_present(ARENA), "...falta o Salão de Armas")
	assert_false(city.can_build(ARENA))
	city.buildings[W_HALL] = true
	assert_true(city.can_build(ARENA))

func test_neither_the_guardian_hall_nor_the_barracks_nor_the_v1_techs_stand_in_for_the_weapons_hall():
	var player := _player(8, 9)
	var city := _standalone_city(player, [G_HALL, G_MASTERY, "barracks"])
	assert_false(city.can_build(ARENA))

func test_it_uses_one_normal_building_slot_and_is_built_only_once():
	var player := _player(8)
	var city := _standalone_city(player, [W_HALL])
	var used := city.used_building_slots()
	city.buildings[ARENA] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(ARENA), "não constrói duas vezes na mesma cidade")

func test_a_full_city_cannot_build_it_even_with_the_research():
	var player := _player(8)
	var city := _standalone_city(player, [W_HALL])
	city.city_level = 1 # Fase 13: 4 slots (não é mais população) -- Salão + 3 mais enche
	for id in ["granary", "workshop", "market"]:
		city.buildings[id] = true
	assert_false(city.can_build(ARENA))
	city.city_level = 2 # 7 slots
	assert_true(city.can_build(ARENA))

func test_the_unlock_belongs_to_the_researching_civilization_only():
	assert_true(_standalone_city(_player(8), [W_HALL]).can_build(ARENA))
	assert_false(_standalone_city(_player(7), [W_HALL]).can_build(ARENA))
	assert_false(_standalone_city(_player(0, 9), [W_HALL]).can_build(ARENA), "só o Guardião não basta")

func test_it_goes_through_the_normal_production_queue():
	var city := _standalone_city(_player(8), [W_HALL])
	city.set_production(ARENA)
	assert_eq(city.production_item, ARENA)
	assert_eq(city.production_cost(), 55.0)

func test_the_hero_stays_blocked_with_the_arena_but_without_n9():
	var player := _player(8)
	var city := _standalone_city(player, [W_HALL, ARENA])
	assert_false(city.can_train(HERO), "N8 dá o prédio; o Herói é do N9")
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, HERO), "Requer pesquisa: Herói da Lâmina.")

# --- Herói: definição -----------------------------------------------------------------------------------------------

func test_the_hero_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(HERO)
	assert_eq(data.unit_name, "Herói da Lâmina")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points], [38.0, 12.0, 7.0, 2.0])
	assert_eq(data.vision_range, 3)
	assert_eq(data.attack_range, 1, "corpo a corpo")
	assert_eq(data.production_cost, 90.0)
	assert_eq(data.visual_kind, HERO)
	assert_true(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(data.has_aura(), "a aura é do Campeão Guardião; o Herói tem a Execução")

func test_the_hero_and_the_champion_have_clearly_opposite_identities():
	var hero := UnitDatabase.create_unit(HERO)
	var champion := UnitDatabase.create_unit(CHAMPION)
	assert_gt(hero.attack, champion.attack * 1.5, "o Herói é o finalizador")
	assert_lt(hero.defense, champion.defense)
	assert_lt(hero.max_hp, champion.max_hp)
	assert_eq(hero.production_cost, champion.production_cost, "custos iguais: só a identidade difere")
	assert_gt(hero.attack, UnitDatabase.create_unit(MASTER).attack, "mais Ataque que o Mestre de Armas")
	assert_gt(hero.max_hp, UnitDatabase.create_unit(MASTER).max_hp)

func test_the_hero_is_a_legendary_by_metadata_and_does_not_evolve():
	assert_true(V2LegendarySystem.is_legendary_kind(HERO))
	assert_eq(V2ResearchDatabase.node_for_unlock_id(HERO).unlock_type, "legendary_candidate")
	var grid := _world()
	var hero := _unit(grid, _player(9), HERO, Vector2i(0, 0))
	assert_true(V2LegendarySystem.is_legendary_unit(hero))
	assert_eq(V2UnitUpgrade.get_upgrade_target(hero), "")

# --- Herói: não é upgrade, não está na cadeia -------------------------------------------------------------------------

func test_the_hero_is_outside_the_conventional_chain():
	assert_false(V2UnitLine.is_line_unit(HERO))
	assert_eq(V2UnitLine.unit_ids("warrior"), [WARRIOR, SWORDSMAN, MASTER])
	assert_eq(V2UnitLine.branch_of(HERO), "", "não é forma da cadeia")
	assert_eq(V2UnitLine.doctrine_branch_of(HERO), "warrior", "mas pertence à Doutrina")
	assert_eq(V2UnitLine.resolve_trainable_form(_player(9), HERO), "")

func test_the_weapon_master_is_not_replaced_and_stays_trainable_normally():
	var player := _player(9)
	var city := _city_with_everything(player)
	assert_eq(V2UnitLine.resolve_trainable_form(player, WARRIOR), MASTER, "a produção convencional segue no Mestre de Armas")
	assert_true(city.can_train(MASTER))
	assert_true(city.can_train(HERO))
	city.set_production(HERO)
	assert_true(city.can_train(MASTER), "o Mestre continua treinável mesmo com o Herói na fila da própria cidade")

func test_the_weapon_master_does_not_evolve_into_the_hero_and_the_hero_does_not_evolve_into_it():
	var grid := _world()
	var me := _player(9)
	var master := _unit(grid, me, MASTER, Vector2i(0, 0))
	assert_eq(V2UnitUpgrade.get_upgrade_target(master), "")
	assert_ne(V2ResearchDatabase.node_for_unlock_id(MASTER).upgrade_to, HERO)

# --- Herói: produção -------------------------------------------------------------------------------------------------

func test_producing_the_hero_needs_n9_the_arena_and_a_free_slot():
	var player := _player(8)
	# Fase 15: o Herói da Lâmina custa 5 Suprimentos, acima da base de uma cidade sozinha (4).
	var city := _standalone_city_with_supply(player, [W_HALL, ARENA])
	assert_false(city.can_train(HERO), "sem N9")
	player.v2_research.complete_research("v2_doctrine_warrior_9")
	assert_true(city.can_train(HERO))
	assert_false(_standalone_city(player, [W_HALL]).can_train(HERO), "sem a Arena")
	assert_false(_standalone_city(player, [G_HALL, G_MASTERY]).can_train(HERO), "o Bastião não treina o Herói")

func test_the_hero_cost_and_production():
	var player := _player(9)
	var city := _city_with_everything(player)
	city.set_production(HERO)
	assert_eq(city.production_item, HERO)
	assert_eq(city.production_cost(), 90.0)

func test_the_champion_is_not_trainable_in_the_arena_and_the_hero_not_in_the_bastion():
	var player := _player(9, 9)
	assert_false(_standalone_city(player, [W_HALL, ARENA]).can_train(CHAMPION))
	assert_false(_standalone_city(player, [G_HALL, G_MASTERY]).can_train(HERO))

# --- Herança das Técnicas e da linha ------------------------------------------------------------------------------------

func test_the_hero_inherits_both_warrior_techniques_and_none_of_the_guardian():
	var grid := _world()
	var me := _player(9, 9)
	var hero := _unit(grid, me, HERO, Vector2i(0, 0))
	var ids: Array = V2TechniqueRuntime.techniques_for_unit(hero).map(func(t): return t.id)
	assert_eq(ids.size(), 2)
	assert_true(POWER in ids and CLEAVE in ids)
	assert_false(WALL in ids)

func test_the_technique_data_does_not_mention_the_hero():
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_false(technique.id.contains("blade_hero"))
		assert_false(technique.doctrine_branch.contains("hero"))
	var source := FileAccess.get_file_as_string("res://scripts/data/V2DoctrineTechniqueDatabase.gd")
	assert_false(source.contains("v2_legendary_blade_hero"), "nada duplicado no dado do Herói")

func test_the_hero_techniques_need_their_research():
	var grid := _world()
	var me := _player(6)
	var hero := _unit(grid, me, HERO, Vector2i(0, 0)) # spawn direto: o dado existe; a pesquisa dos nós de técnica é da civilização
	assert_true(V2TechniqueRuntime.techniques_for_unit(hero).any(func(t): return t.id == CLEAVE))
	var early := _player(3)
	var hero2 := _unit(grid, early, HERO, Vector2i(2, 0))
	assert_true(V2TechniqueRuntime.techniques_for_unit(hero2).is_empty(), "sem N4/N6 o Herói não tem técnica")

# --- O slot GLOBAL: Guardião e Guerreiro disputam o mesmo (cenário obrigatório) ---------------------------------------------

func test_an_active_champion_blocks_the_hero_and_its_death_releases_it():
	var grid := _world()
	var me := _player(9, 9)
	var rival := _rival_of(me)
	var city := _city_with_everything(me)
	assert_true(city.can_train(HERO), "pré-condição: livre")
	var champion := _unit(grid, me, CHAMPION, Vector2i(0, 0))
	assert_false(city.can_train(HERO), "com o Campeão ativo o Herói não pode ser treinado")
	assert_eq(V2LegendarySystem.unavailable_reason(me, city, HERO), V2LegendarySystem.SLOT_TAKEN_REASON)
	assert_eq(V2LegendarySystem.slot_only_reason(me, city, HERO), V2LegendarySystem.SLOT_TAKEN_REASON, "o slot é o ÚNICO impedimento")
	# Morte REAL em combate: um atacante rival derruba o Campeão.
	champion.hp = 1.0
	var killer_data := UnitDatabase.create_unit("warrior")
	killer_data.attack = 100.0
	var killer := grid.spawn_unit(Vector2i(1, 0), killer_data, rival)
	CombatResolver.resolve(killer, champion, grid)
	assert_false(V2LegendarySystem.has_active_legendary(me), "o Campeão morreu")
	assert_true(city.can_train(HERO), "o slot voltou a ficar disponível")

func test_a_hero_in_production_blocks_the_champion_the_reservation_is_global():
	var me := _player(9, 9)
	var city := _city_with_everything(me)
	var other := _city_with_everything(me)
	assert_true(other.can_train(CHAMPION))
	city.set_production(HERO)
	assert_false(other.can_train(CHAMPION), "10. o Campeão passa a ficar bloqueado por causa do Herói em produção")
	assert_false(other.can_train(HERO), "e o próprio Herói em outra cidade")
	assert_true(city.can_train(HERO), "a própria ordem não bloqueia a cidade que a fez")
	assert_true(city.can_train(CHAMPION), "e ela pode trocar a própria ordem por outra Lendária (a reserva é uma só)")
	city.set_production("")
	assert_true(other.can_train(CHAMPION), "cancelar libera a reserva")

func test_the_full_conflict_scenario_of_the_request_step_by_step():
	var grid := _world()
	var me := _player(9, 9) # 1-2. Guardião N9 e Guerreiro N9
	var rival := _rival_of(me)
	var bastion_city := _city_with_everything(me) # 3. Bastião + Arena (e os dois Salões)
	assert_true(bastion_city.buildings.has(G_MASTERY) and bastion_city.buildings.has(ARENA))
	var champion := _unit(grid, me, CHAMPION, Vector2i(0, 0)) # 4. Campeão Guardião ativo
	assert_true(V2LegendarySystem.has_active_legendary(me))
	assert_false(bastion_city.can_train(HERO), "5-6. tentar o Herói: bloqueado")
	# 7. matar o Campeão
	champion.hp = 1.0
	var killer_data := UnitDatabase.create_unit("warrior")
	killer_data.attack = 100.0
	CombatResolver.resolve(grid.spawn_unit(Vector2i(1, 0), killer_data, rival), champion, grid)
	assert_false(V2LegendarySystem.has_active_legendary(me))
	assert_true(bastion_city.can_train(HERO), "8. o Herói fica disponível")
	bastion_city.set_production(HERO) # 9. começar o Herói na Arena
	assert_eq(bastion_city.production_item, HERO)
	var second := _city_with_everything(me)
	assert_false(second.can_train(CHAMPION), "10. o Campeão passa a ficar bloqueado")
	assert_true(bastion_city.can_train(HERO), "a cidade que produz o Herói não se bloqueia")

func test_an_active_hero_blocks_the_champion_and_its_death_releases_it():
	var grid := _world()
	var me := _player(9, 9)
	var city := _city_with_everything(me)
	var hero := _unit(grid, me, HERO, Vector2i(0, 0))
	assert_false(city.can_train(CHAMPION))
	assert_eq(V2LegendarySystem.unavailable_reason(me, city, CHAMPION), V2LegendarySystem.SLOT_TAKEN_REASON)
	grid.remove_unit(hero)
	assert_true(city.can_train(CHAMPION))

func test_the_slot_is_one_per_civilization_across_both_doctrines_and_a_rival_hero_never_blocks_me():
	var grid := _world()
	var me := _player(9, 9)
	var rival := _rival_of(me)
	rival.v2_research.complete_research("v2_doctrine_warrior_1") # só pra existir
	_unit(grid, rival, HERO, Vector2i(3, 0)) # Herói INIMIGO ativo
	var city := _city_with_everything(me)
	assert_true(city.can_train(CHAMPION), "a Lendária rival não ocupa o MEU slot")
	assert_true(city.can_train(HERO))
	assert_eq(V2LegendarySystem.slots_used(me), 0)
	_unit(grid, me, HERO, Vector2i(0, 0))
	assert_eq(V2LegendarySystem.slots_used(me), 1)
	assert_eq(V2LegendarySystem.max_active(), 1)

func test_a_debug_reset_of_the_research_does_not_kill_the_hero_and_the_slot_stays_taken():
	var grid := _world()
	var me := _player(9, 9)
	var city := _city_with_everything(me)
	_unit(grid, me, HERO, Vector2i(0, 0))
	me.v2_research.reset()
	assert_true(V2LegendarySystem.has_active_legendary(me), "a unidade existe")
	assert_eq(V2LegendarySystem.slots_used(me), 1)
	assert_false(city.can_train(CHAMPION))

func test_the_spawn_is_fail_closed_when_a_champion_and_a_hero_would_both_come_out():
	var grid := _world()
	var me := _player(9, 9)
	assert_true(V2LegendarySystem.spawn_allowed(me, HERO))
	_unit(grid, me, CHAMPION, Vector2i(0, 0))
	assert_false(V2LegendarySystem.spawn_allowed(me, HERO), "com o Campeão ativo o Herói não nasce")
	var city := _city_with_everything(me)
	city.stored_production = 0.0
	V2LegendarySystem.refuse_spawn(city, HERO, false)
	assert_push_error("não nasceu")
	assert_eq(city.stored_production, UnitDatabase.create_unit(HERO).production_cost, "o custo volta pra cidade")
	assert_eq(me.units.filter(func(u): return u.unit_data.visual_kind == HERO).size(), 0)

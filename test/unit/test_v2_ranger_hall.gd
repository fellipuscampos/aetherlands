extends "res://test/unit/v2_combat_fixture.gd"

## Doutrina do Patrulheiro N1-N3 (Aetherlands V2 Fase 8): a Doutrina (N1, sem bônus), o Campo dos Patrulheiros (N2, prédio normal de treino),
## o Arqueiro (N3, ranged DPS básico) e o ataque básico à DISTÂNCIA pelo sistema existente (`attack_range`, sem revide fora do melee).
## Os MESMOS mecanismos do Guardião/Guerreiro (V2UnlockSystem, BuildingData.trains_unit, City.can_train). Números = BALANCE PLACEHOLDER.

func _apply_signals(player: PlayerData) -> Array:
	var seen: Array = []
	player.v2_unlocks.unlock_applied.connect(func(node_id, unlock_type, unlock_id): seen.append([node_id, unlock_type, unlock_id]))
	return seen

# --- N1: a Doutrina ---------------------------------------------------------------------------------------------------

func test_n1_only_establishes_the_line_and_opens_n2_with_no_bonus_of_its_own():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	var before := [player.gold, player.mana, player.units.size()]
	var seen := _apply_signals(player)
	player.v2_research.complete_research("v2_doctrine_ranger_1")
	assert_eq(seen, [["v2_doctrine_ranger_1", "doctrine", "v2_doctrine_ranger"]])
	assert_eq(V2UnlockSystem.unlocked_ids(player), ["v2_doctrine_ranger"], "nenhum prédio, unidade ou técnica")
	assert_eq([player.gold, player.mana, player.units.size()], before, "sem bônus global")
	assert_true(player.v2_research.is_available("v2_doctrine_ranger_2"))
	assert_false(player.v2_research.is_available("v2_doctrine_ranger_3"))

func test_every_ranger_node_applies_its_unlock_once_with_the_generic_type_table():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	var seen := _apply_signals(player)
	for n in range(1, 10):
		player.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	assert_eq(seen, [
		["v2_doctrine_ranger_1", "doctrine", "v2_doctrine_ranger"],
		["v2_doctrine_ranger_2", "building", R_CAMP],
		["v2_doctrine_ranger_3", "unit", ARCHER],
		["v2_doctrine_ranger_4", "technique", PRECISE],
		["v2_doctrine_ranger_5", "unit_upgrade", HUNTER],
		["v2_doctrine_ranger_6", "technique", VOLLEY],
		["v2_doctrine_ranger_7", "unit_upgrade", MARKSMAN],
		["v2_doctrine_ranger_8", "mastery_building", R_TOWER],
		["v2_doctrine_ranger_9", "legendary_candidate", LEGEND_HUNTER],
	])
	assert_false(player.v2_unlocks.apply_unlock("v2_doctrine_ranger_3"), "aplicar de novo é inofensivo")

# --- N2: o Campo dos Patrulheiros ----------------------------------------------------------------------------------------

func test_the_camp_is_blocked_before_n2_and_free_after():
	var player := _ranger_player(1)
	var city := _standalone_city(player)
	assert_false(city.can_build(R_CAMP), "antes do N2")
	player.v2_research.complete_research("v2_doctrine_ranger_2")
	assert_true(city.can_build(R_CAMP), "depois do N2")

func test_the_camp_is_a_normal_building_with_the_canonical_name_and_the_other_halls_cost():
	var camp := BuildingDatabase.get_building(R_CAMP)
	assert_not_null(camp)
	assert_eq(camp.display_name, "Campo dos Patrulheiros")
	assert_eq(camp.display_name, V2ResearchDatabase.node_for_unlock_id(R_CAMP).display_name)
	assert_eq(camp.production_cost, 22.0)
	assert_eq(camp.production_cost, BuildingDatabase.get_building(G_HALL).production_cost)
	assert_eq(camp.production_cost, BuildingDatabase.get_building(W_HALL).production_cost)
	assert_eq(camp.trains_unit, ARCHER)
	assert_false("upkeep" in camp.get_property_list().map(func(p): return p.name), "sem upkeep")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == R_CAMP).size(), 1)
	assert_true(ResourceLoader.exists(camp.model_scene_path), camp.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(R_CAMP, race), "Campo dos Patrulheiros", race)

func test_the_camp_needs_no_v1_building_and_no_other_doctrine():
	var camp := BuildingDatabase.get_building(R_CAMP)
	assert_eq(camp.requires_building, "", "nem Campo de Tiro V1, nem Quartel, nem outro Salão")
	var player := _ranger_player(2)
	var city := _standalone_city(player) # sem prédio nenhum
	assert_true(city.can_build(R_CAMP))

func test_v1_techs_and_other_doctrines_never_unlock_the_camp():
	var player := _player(9, 9, 0)
	assert_false(_standalone_city(player).can_build(R_CAMP), "V1 e Guardião/Guerreiro completos não bastam")

func test_the_camp_uses_a_normal_slot_and_is_built_once():
	var player := _ranger_player(2)
	var city := _standalone_city(player)
	var used := city.used_building_slots()
	city.buildings[R_CAMP] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(R_CAMP))

func test_the_camp_belongs_to_the_researching_civilization_only():
	assert_true(_standalone_city(_ranger_player(2)).can_build(R_CAMP))
	assert_false(_standalone_city(_ranger_player(1)).can_build(R_CAMP))

# --- N3: o Arqueiro --------------------------------------------------------------------------------------------------------

func test_the_archer_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(ARCHER)
	assert_eq(data.unit_name, "Arqueiro")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points], [13.0, 4.5, 2.5, 2.0])
	assert_eq(data.vision_range, 3)
	assert_eq(data.attack_range, 2, "ranged: alcance 2")
	assert_eq(data.production_cost, 20.0)
	assert_eq(data.visual_kind, ARCHER, "o SaveManager recria a unidade por ele")
	assert_false(data.can_found_city)
	assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(data.has_low_hp_attack_bonus() or data.has_trait_attack_bonus(), "nenhuma habilidade antes do N4")

func test_the_archer_is_more_fragile_than_the_guardian_and_warrior_bases_but_shoots_from_range():
	var archer := UnitDatabase.create_unit(ARCHER)
	for other_kind in [SHIELD, WARRIOR]:
		var other := UnitDatabase.create_unit(other_kind)
		assert_lt(archer.max_hp, other.max_hp, "menos HP que %s" % other_kind)
		assert_lt(archer.defense, other.defense, "menos Defesa que %s" % other_kind)
		assert_gt(archer.attack_range, other.attack_range, "alcance maior que %s" % other_kind)

func test_the_archer_is_a_v2_kind_distinct_from_the_v1_archer():
	assert_true(UnitDatabase.PLAYER_TRAINABLE_KINDS.has(ARCHER))
	assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(ARCHER), 1)
	assert_ne(ARCHER, "archer")
	var v1 := UnitDatabase.create_unit("archer")
	assert_eq(v1.unit_name, "Arqueiro", "o mesmo nome (dívida transitória V1/V2)")
	assert_eq([v1.max_hp, v1.attack, v1.production_cost], [9.0, 3.0, 18.0], "o Arqueiro V1 não foi tocado")
	assert_true(V2UnitLine.is_line_unit(ARCHER))
	assert_eq(V2UnitLine.base_of(MARKSMAN), ARCHER)

func test_the_archer_needs_n3_and_the_camp():
	var player := _ranger_player(2)
	var city := _standalone_city(player, [R_CAMP])
	assert_false(city.can_train(ARCHER), "sem N3")
	assert_false(player.has_unlocked(ARCHER))
	player.v2_research.complete_research("v2_doctrine_ranger_3")
	assert_true(player.has_unlocked(ARCHER))
	assert_true(city.can_train(ARCHER), "N3 + Campo")
	assert_false(_standalone_city(player).can_train(ARCHER), "sem o Campo")

func test_the_archer_needs_the_ranger_camp_not_a_v1_archery_range_or_barracks_or_other_halls():
	var player := _player(3, 3, 3)
	assert_false(_standalone_city(player, ["archery_range", "barracks"]).can_train(ARCHER))
	assert_false(_standalone_city(player, [G_HALL, W_HALL]).can_train(ARCHER))
	assert_true(_standalone_city(player, [R_CAMP]).can_train(ARCHER))
	assert_false(_standalone_city(player, [R_CAMP]).can_train(SHIELD), "o Campo não treina as outras linhas")

func test_the_archer_goes_through_the_normal_production_queue_at_20_pp():
	var player := _ranger_player(3)
	var city := _standalone_city(player, [R_CAMP])
	city.set_production(ARCHER)
	assert_eq(city.production_item, ARCHER)
	assert_eq(city.production_cost(), 20.0)

func test_two_civilizations_keep_their_own_availability():
	var researcher := _standalone_city(_ranger_player(3), [R_CAMP])
	var novice_player := _ranger_player(2)
	var novice := _standalone_city(novice_player, [R_CAMP])
	assert_true(researcher.can_train(ARCHER))
	assert_false(novice.can_train(ARCHER))
	assert_false(V2UnlockSystem.is_unlocked(novice_player, ARCHER))

func test_a_unit_is_recreated_by_its_kind_the_save_contract():
	for kind in [ARCHER, HUNTER, MARKSMAN, LEGEND_HUNTER]:
		var data := UnitDatabase.create_unit(kind)
		assert_eq(data.visual_kind, kind)
		assert_eq(UnitDatabase.create_unit(data.visual_kind).max_hp, data.max_hp, kind)
		assert_eq(UnitDatabase.create_unit(data.visual_kind).attack_range, data.attack_range, kind)

# --- Ataque básico à distância (sistema existente) ----------------------------------------------------------------------------

func test_the_basic_ranged_attack_at_range_2_takes_no_counterattack():
	var grid := _world()
	var me := _ranger_player(3)
	var rival := _rival_of(me)
	var archer := _unit(grid, me, ARCHER, Vector2i(0, 0))
	var foe := _foe_at(grid, rival, archer, 2, 40.0, 14.0) # Defesa alta: um alvo em melee revidaria
	var prediction: Dictionary = CombatResolver.predict(archer, foe, grid)
	assert_false(prediction.is_melee_range, "a distância 2 não é melee")
	assert_eq(prediction.damage_to_attacker, 0.0, "sem revide fora do alcance de melee")
	assert_eq(prediction.damage_to_defender, _formula_damage(grid, 4.5, 1.0, foe), "Ataque - Defesa/2 (piso 1)")
	var hp := foe.hp
	var my_hp := archer.hp
	CombatResolver.resolve(archer, foe, grid)
	assert_almost_eq(hp - foe.hp, prediction.damage_to_defender, 0.0001, "previsão == resolução")
	assert_eq(archer.hp, my_hp, "o Arqueiro não perdeu vida")
	assert_eq(archer.movement_left, 0.0, "atacar gasta o movimento (regra V1)")

func test_an_archer_attacking_in_melee_range_takes_the_normal_counterattack():
	var grid := _world()
	var me := _ranger_player(3)
	var rival := _rival_of(me)
	var archer := _unit(grid, me, ARCHER, Vector2i(0, 0))
	var foe := _foe_at(grid, rival, archer, 1, 60.0, 14.0)
	var prediction: Dictionary = CombatResolver.predict(archer, foe, grid)
	assert_true(prediction.is_melee_range)
	assert_gt(prediction.damage_to_attacker, 0.0, "revide segundo as regras já existentes")
	var my_hp := archer.hp
	CombatResolver.resolve(archer, foe, grid)
	assert_almost_eq(my_hp - archer.hp, prediction.damage_to_attacker, 0.0001)

func test_a_ranged_kill_counts_xp_once_and_removes_the_target():
	var grid := _world()
	var me := _ranger_player(3)
	var rival := _rival_of(me)
	var archer := _unit(grid, me, ARCHER, Vector2i(0, 0))
	var foe := _foe_at(grid, rival, archer, 2, 3.0, 3.0)
	CombatResolver.resolve(archer, foe, grid)
	assert_eq(archer.kills, 1)
	assert_false(rival.units.has(foe))

func test_the_ranged_attack_uses_the_normal_defense_chain_terrain_wall_and_aura():
	var grid := _world()
	var me := _ranger_player(3)
	var rival := _rival_of(me)
	var archer := _unit(grid, me, ARCHER, Vector2i(0, 0))
	var foe := _foe_at(grid, rival, archer, 2)
	foe.magic_status[WALL] = TurnManager.turn_number + 2
	var wall: float = 1.0 + _technique(WALL).self_defense_bonus
	var expected := _formula_damage(grid, 4.5, 1.0, foe, wall)
	assert_almost_eq(CombatResolver.predict(archer, foe, grid).damage_to_defender, expected, 0.0001)

func test_the_selection_offers_targets_at_range_2_and_not_at_range_3_nor_allies_nor_peaceful():
	var grid := _world()
	var me := _ranger_player(3)
	var rival := _rival_of(me)
	var peaceful := PlayerData.new(CivilizationData.new())
	_players.append(peaceful)
	var archer := _unit(grid, me, ARCHER, Vector2i(0, 0))
	var near := _foe_at(grid, rival, archer, 2)
	var far := _foe(grid, rival, Vector2i(-3, 0))
	var ally := _unit(grid, me, SHIELD, Vector2i(0, 2))
	var neutral := _foe(grid, peaceful, Vector2i(0, -2))
	var original_grid := GameManager.hex_grid
	var original_human := GameManager.human_player
	GameManager.hex_grid = grid
	GameManager.human_player = me
	SelectionManager._select_unit(archer)
	assert_true(near.coord in SelectionManager.attackable, "alvo hostil a 2 tiles")
	assert_false(far.coord in SelectionManager.attackable, "a 3 tiles fica fora do alcance básico")
	assert_false(ally.coord in SelectionManager.attackable)
	assert_false(neutral.coord in SelectionManager.attackable, "civilização em paz")
	SelectionManager.reset()
	GameManager.hex_grid = original_grid
	GameManager.human_player = original_human

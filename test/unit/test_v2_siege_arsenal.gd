extends "res://test/unit/v2_combat_fixture.gd"

## Doutrina de Cerco N1-N3 (Aetherlands V2 Fase 11): a Doutrina (N1, sem bônus), o Arsenal de Cerco (N2, prédio normal de treino) e a Catapulta
## (N3, ranged especializada contra cidades). Os MESMOS mecanismos das outras Doutrinas. Números = BALANCE PLACEHOLDER.

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
	player.v2_research.complete_research("v2_doctrine_siege_1")
	assert_eq(seen, [["v2_doctrine_siege_1", "doctrine", "v2_doctrine_siege"]])
	assert_eq(V2UnlockSystem.unlocked_ids(player), ["v2_doctrine_siege"], "nenhum prédio, unidade ou técnica")
	assert_eq([player.gold, player.mana, player.units.size()], before, "sem bônus global")
	assert_true(player.v2_research.is_available("v2_doctrine_siege_2"))
	assert_false(player.v2_research.is_available("v2_doctrine_siege_3"))

func test_every_siege_node_applies_its_unlock_once_with_the_generic_type_table():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	var seen := _apply_signals(player)
	for n in range(1, 10):
		player.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	assert_eq(seen, [
		["v2_doctrine_siege_1", "doctrine", "v2_doctrine_siege"],
		["v2_doctrine_siege_2", "building", SIEGE_ARSENAL],
		["v2_doctrine_siege_3", "unit", CATAPULT],
		["v2_doctrine_siege_4", "technique", DEMOLITION_AMMO],
		["v2_doctrine_siege_5", "unit_upgrade", TREBUCHET],
		["v2_doctrine_siege_6", "technique", PREPARED_BOMBARDMENT],
		["v2_doctrine_siege_7", "unit_upgrade", BOMBARD],
		["v2_doctrine_siege_8", "mastery_building", GRAND_ARSENAL],
		["v2_doctrine_siege_9", "legendary_candidate", COLOSSUS],
	])
	assert_false(player.v2_unlocks.apply_unlock("v2_doctrine_siege_3"), "aplicar de novo é inofensivo")

# --- N2: o Arsenal de Cerco --------------------------------------------------------------------------------------------

func test_the_arsenal_is_blocked_before_n2_and_free_after():
	var player := _siege_player(1)
	var city := _standalone_city(player)
	assert_false(city.can_build(SIEGE_ARSENAL), "antes do N2")
	player.v2_research.complete_research("v2_doctrine_siege_2")
	assert_true(city.can_build(SIEGE_ARSENAL), "depois do N2")

func test_the_arsenal_is_a_normal_building_with_the_canonical_name_and_the_other_halls_cost():
	var arsenal := BuildingDatabase.get_building(SIEGE_ARSENAL)
	assert_not_null(arsenal)
	assert_eq(arsenal.display_name, "Arsenal de Cerco")
	assert_eq(arsenal.display_name, V2ResearchDatabase.node_for_unlock_id(SIEGE_ARSENAL).display_name)
	assert_eq(arsenal.production_cost, 22.0)
	for other in [G_HALL, W_HALL, R_CAMP, C_STABLE, ROGUE_GUILD]:
		assert_eq(arsenal.production_cost, BuildingDatabase.get_building(other).production_cost, other)
	assert_eq(arsenal.trains_unit, CATAPULT)
	assert_false("upkeep" in arsenal.get_property_list().map(func(p): return p.name), "sem upkeep")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == SIEGE_ARSENAL).size(), 1)
	assert_true(ResourceLoader.exists(arsenal.model_scene_path), arsenal.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(SIEGE_ARSENAL, race), "Arsenal de Cerco", race)

## Fase 25: o "Arsenal de Cerco" V1 (`siege_workshop`) saiu do catálogo — o nome não é mais ambíguo.
func test_the_display_name_is_no_longer_shared_with_a_v1_building():
	assert_null(BuildingDatabase.get_building("siege_workshop"))
	var named := BuildingDatabase.all_buildings().filter(func(b): return b.display_name == "Arsenal de Cerco")
	assert_eq(named.size(), 1)
	assert_eq(named[0].id, SIEGE_ARSENAL)

func test_the_arsenal_needs_no_v1_building_and_no_other_doctrine():
	assert_eq(BuildingDatabase.get_building(SIEGE_ARSENAL).requires_building, "", "nenhum prédio V1 nem outra Doutrina")
	var player := _siege_player(2)
	assert_true(_standalone_city(player).can_build(SIEGE_ARSENAL), "sem nenhum prédio")
	var others_only := _standalone_city(_player(9, 9, 9, 9, 9), ["barracks", "siege_workshop", G_HALL, W_HALL, R_CAMP, C_STABLE, ROGUE_GUILD])
	assert_false(others_only.can_build(SIEGE_ARSENAL), "V1 e as outras Doutrinas completas não bastam")

func test_the_arsenal_uses_a_normal_slot_is_built_once_and_belongs_to_the_researching_civilization():
	var player := _siege_player(2)
	var city := _standalone_city(player)
	var used := city.used_building_slots()
	city.buildings[SIEGE_ARSENAL] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(SIEGE_ARSENAL))
	assert_true(_standalone_city(_siege_player(2)).can_build(SIEGE_ARSENAL))
	assert_false(_standalone_city(_siege_player(1)).can_build(SIEGE_ARSENAL))

# --- N3: a Catapulta ------------------------------------------------------------------------------------------------------

func test_the_catapult_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(CATAPULT)
	assert_eq(data.unit_name, "Catapulta")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points], [16.0, 3.5, 2.5, 2.0])
	assert_eq(data.vision_range, 3)
	assert_eq(data.attack_range, 2)
	assert_eq(data.production_cost, 28.0)
	assert_eq(data.visual_kind, CATAPULT, "o SaveManager recria a unidade por ele")
	assert_true(data.has_trait(UnitData.TRAIT_SIEGE))
	assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY) or data.has_trait(UnitData.TRAIT_MOUNTED) or data.has_trait(UnitData.TRAIT_FLYING))
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_false(data.can_found_city)

func test_the_catapult_has_a_worse_attack_than_the_archer_despite_costing_more():
	var catapult := UnitDatabase.create_unit(CATAPULT)
	var archer := UnitDatabase.create_unit(ARCHER)
	assert_gt(catapult.production_cost, archer.production_cost, "custo maior")
	assert_lt(catapult.attack, archer.attack, "menor desempenho anti-unidade — não aumentado só pra justificar o custo")
	assert_eq(catapult.defense, archer.defense, "mesma Defesa")

func test_the_basic_ranged_attack_uses_the_normal_combat_no_special_anti_unit_formula():
	var grid := _world()
	var me := _siege_player(3)
	var rival := _rival_of(me)
	var catapult := _unit(grid, me, CATAPULT, Vector2i(0, 0))
	var foe := _foe(grid, rival, Vector2i(2, 0))
	var predicted: float = CombatResolver.predict(catapult, foe, grid).damage_to_defender
	assert_almost_eq(predicted, _formula_damage(grid, 3.5, 1.0, foe), 0.0001, "fórmula normal do combate ranged, sem multiplicador especial")
	var before := foe.hp
	CombatResolver.resolve(catapult, foe, grid)
	assert_almost_eq(before - foe.hp, predicted, 0.0001, "predict == resolve")
	assert_eq(CombatResolver.predict(catapult, foe, grid).damage_to_attacker, 0.0, "sem revide a distância 2, como qualquer ranged")

func test_the_catapult_needs_n3_and_the_arsenal_and_goes_through_the_normal_queue():
	var player := _siege_player(2)
	var city := _standalone_city(player, [SIEGE_ARSENAL])
	assert_false(city.can_train(CATAPULT), "sem N3")
	player.v2_research.complete_research("v2_doctrine_siege_3")
	assert_true(player.has_unlocked(CATAPULT))
	assert_true(city.can_train(CATAPULT), "N3 + Arsenal")
	assert_false(_standalone_city(player).can_train(CATAPULT), "sem o Arsenal")
	city.set_production(CATAPULT)
	assert_eq(city.production_item, CATAPULT)
	assert_eq(city.production_cost(), 28.0)

func test_the_catapult_needs_the_arsenal_not_the_other_halls():
	var player := _player(3, 3, 3, 3, 3, 3)
	# Aetherlands V2, Fase 15 — vários prédios com upkeep (§24-30) sem Mercado e sem Ouro em caixa
	# entrariam em Déficit sozinhos, bloqueando o treino por um motivo alheio ao que este teste
	# verifica (qual prédio treina a forma).
	player.gold = 1000.0
	assert_false(_standalone_city(player, ["barracks", "siege_workshop", G_HALL, W_HALL, R_CAMP, C_STABLE, ROGUE_GUILD]).can_train(CATAPULT))
	assert_true(_standalone_city(player, [SIEGE_ARSENAL]).can_train(CATAPULT))
	assert_false(_standalone_city(player, [SIEGE_ARSENAL]).can_train(SHIELD), "o Arsenal não treina as outras linhas")

func test_two_civilizations_keep_their_own_availability_and_the_kind_is_the_save_contract():
	var researcher := _standalone_city(_siege_player(3), [SIEGE_ARSENAL])
	var novice_player := _siege_player(2)
	var novice := _standalone_city(novice_player, [SIEGE_ARSENAL])
	assert_true(researcher.can_train(CATAPULT))
	assert_false(novice.can_train(CATAPULT))
	assert_false(V2UnlockSystem.is_unlocked(novice_player, CATAPULT))
	for kind in [CATAPULT, TREBUCHET, BOMBARD, COLOSSUS]:
		var data := UnitDatabase.create_unit(kind)
		assert_eq(data.visual_kind, kind)
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(kind), 1, kind)

# --- Fonte única do traço `siege` (auditoria da Fase 11) ----------------------------------------------------------------------

func test_all_four_siege_forms_carry_the_trait_a_common_unit_does_not():
	for kind in [CATAPULT, TREBUCHET, BOMBARD, COLOSSUS]:
		assert_true(UnitDatabase.create_unit(kind).has_trait(UnitData.TRAIT_SIEGE), kind)
	assert_false(UnitDatabase.create_unit(WARRIOR).has_trait(UnitData.TRAIT_SIEGE))
	assert_false(UnitDatabase.create_unit(ARCHER).has_trait(UnitData.TRAIT_SIEGE))

func test_the_v1_siege_classification_still_seeds_the_trait_exactly_as_before():
	for kind in UnitAbilities.SIEGE:
		assert_true(UnitDatabase.create_unit(kind).has_trait(UnitData.TRAIT_SIEGE), kind)

func test_dismantle_recognizes_all_four_siege_forms_by_trait():
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var ladino := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var index := 1
	for kind in [CATAPULT, TREBUCHET, BOMBARD, COLOSSUS]:
		var machine := _unit(grid, rival, kind, Vector2i(index, 0))
		index += 1
		assert_almost_eq(UnitAbilities.attack_multiplier(ladino, machine), 1.5, 0.0001, kind)

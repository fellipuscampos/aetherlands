extends "res://test/unit/v2_combat_fixture.gd"

## Doutrina do Guerreiro N1-N3 (Aetherlands V2 Fase 7): a Doutrina (N1, sem bônus próprio), o Salão de Armas (N2, prédio normal de treino)
## e o Guerreiro treinável (N3) — os MESMOS mecanismos do Guardião (V2UnlockSystem, BuildingData.trains_unit, City.can_train).
## Números = BALANCE PLACEHOLDER.

func _apply_signals(player: PlayerData) -> Array:
	var seen: Array = []
	player.v2_unlocks.unlock_applied.connect(func(node_id, unlock_type, unlock_id): seen.append([node_id, unlock_type, unlock_id]))
	return seen

# --- N1: a Doutrina -------------------------------------------------------------------------------------------------

func test_n1_only_establishes_the_line_and_opens_n2_with_no_bonus_of_its_own():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	var gold := player.gold
	var mana := player.mana
	var units_before := player.units.size()
	var seen := _apply_signals(player)
	player.v2_research.complete_research("v2_doctrine_warrior_1")
	assert_eq(seen, [["v2_doctrine_warrior_1", "doctrine", "v2_doctrine_warrior"]])
	assert_eq(V2UnlockSystem.unlocked_ids(player), ["v2_doctrine_warrior"], "nenhum prédio, unidade ou técnica")
	assert_eq([player.gold, player.mana, player.units.size()], [gold, mana, units_before], "sem bônus global")
	assert_true(player.v2_research.is_available("v2_doctrine_warrior_2"))
	assert_false(player.v2_research.is_available("v2_doctrine_warrior_3"))
	assert_eq(V2UnlockSystem.announcement_text("doctrine", "Doutrina do Guerreiro"), "Doutrina desbloqueada: Doutrina do Guerreiro")

func test_every_warrior_node_applies_its_unlock_once_with_the_generic_type_table():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	var seen := _apply_signals(player)
	for n in range(1, 10):
		player.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	assert_eq(seen, [
		["v2_doctrine_warrior_1", "doctrine", "v2_doctrine_warrior"],
		["v2_doctrine_warrior_2", "building", W_HALL],
		["v2_doctrine_warrior_3", "unit", WARRIOR],
		["v2_doctrine_warrior_4", "technique", POWER],
		["v2_doctrine_warrior_5", "unit_upgrade", SWORDSMAN],
		["v2_doctrine_warrior_6", "technique", CLEAVE],
		["v2_doctrine_warrior_7", "unit_upgrade", MASTER],
		["v2_doctrine_warrior_8", "mastery_building", ARENA],
		["v2_doctrine_warrior_9", "legendary_candidate", HERO],
	])
	assert_false(player.v2_unlocks.apply_unlock("v2_doctrine_warrior_3"), "aplicar de novo é inofensivo")

# --- N2: o Salão de Armas --------------------------------------------------------------------------------------------

func test_the_hall_is_blocked_before_n2_and_free_after():
	var player := _player(1)
	var city := _standalone_city(player)
	assert_false(city.can_build(W_HALL), "antes do N2")
	assert_false(city._research_unlocked_for_building(W_HALL))
	player.v2_research.complete_research("v2_doctrine_warrior_2")
	assert_true(city.can_build(W_HALL), "depois do N2")

func test_the_hall_is_a_normal_building_with_the_canonical_name_and_the_guardian_hall_cost():
	var hall := BuildingDatabase.get_building(W_HALL)
	assert_not_null(hall)
	assert_eq(hall.display_name, "Salão de Armas")
	assert_eq(hall.display_name, V2ResearchDatabase.node_for_unlock_id(W_HALL).display_name)
	assert_eq(hall.production_cost, 22.0)
	assert_eq(hall.production_cost, BuildingDatabase.get_building(G_HALL).production_cost, "comparável ao Salão dos Guardiões no playtest")
	assert_eq(hall.trains_unit, WARRIOR)
	assert_false("upkeep" in hall.get_property_list().map(func(p): return p.name), "sem upkeep")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == W_HALL).size(), 1)
	assert_true(ResourceLoader.exists(hall.model_scene_path), hall.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(W_HALL, race), "Salão de Armas", race)

func test_the_hall_needs_neither_a_v1_building_nor_another_doctrine():
	var hall := BuildingDatabase.get_building(W_HALL)
	assert_eq(hall.requires_building, "", "nem Quartel V1, nem Salão dos Guardiões")
	var player := _player(2)
	var city := _standalone_city(player) # sem prédio nenhum
	assert_true(city.can_build(W_HALL))
	assert_true(city.can_build(W_HALL), "a pesquisa V2 basta")

func test_v1_techs_alone_never_unlock_the_hall():
	var player := _player(0)
	assert_false(_standalone_city(player).can_build(W_HALL))

func test_the_hall_uses_a_normal_slot_and_is_built_once():
	var player := _player(2)
	var city := _standalone_city(player)
	var used := city.used_building_slots()
	city.buildings[W_HALL] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(W_HALL))

func test_the_hall_belongs_to_the_researching_civilization_only():
	assert_true(_standalone_city(_player(2)).can_build(W_HALL))
	assert_false(_standalone_city(_player(1)).can_build(W_HALL))
	assert_false(_standalone_city(_player(0, 9)).can_build(W_HALL), "o Guardião completo não libera o Salão de Armas")

func test_v1_buildings_are_not_affected():
	var city := _standalone_city(_player(9))
	assert_false(city.can_build("sages_tower"), "Fase 25: prédio V1 nunca é construível")
	assert_false(city.can_build("barracks"))

# --- N3: o Guerreiro -------------------------------------------------------------------------------------------------

func test_the_warrior_is_blocked_without_n3_and_without_the_hall():
	var player := _player(2)
	var city := _standalone_city(player, [W_HALL])
	assert_false(city.can_train(WARRIOR), "sem N3")
	assert_false(player.has_unlocked(WARRIOR))
	player.v2_research.complete_research("v2_doctrine_warrior_3")
	assert_true(player.has_unlocked(WARRIOR))
	assert_true(city.can_train(WARRIOR), "N3 + Salão")
	assert_false(_standalone_city(player).can_train(WARRIOR), "sem o Salão de Armas")

func test_the_warrior_needs_the_weapons_hall_not_a_v1_barracks_and_not_the_guardian_hall():
	var player := _player(3, 9)
	assert_false(_standalone_city(player, ["barracks"]).can_train(WARRIOR))
	assert_false(_standalone_city(player, [G_HALL]).can_train(WARRIOR))
	assert_true(_standalone_city(player, [W_HALL]).can_train(WARRIOR))

func test_the_warrior_goes_through_the_normal_production_queue_at_20_pp():
	var player := _player(3)
	var city := _standalone_city(player, [W_HALL])
	city.set_production(WARRIOR)
	assert_eq(city.production_item, WARRIOR)
	assert_eq(city.production_cost(), 20.0)

func test_two_civilizations_with_different_research_keep_their_own_availability():
	var researcher := _player(3)
	var novice := _player(2)
	var rival_city := _standalone_city(researcher, [W_HALL])
	var novice_city := _standalone_city(novice, [W_HALL])
	assert_true(rival_city.can_train(WARRIOR))
	assert_false(novice_city.can_train(WARRIOR))
	assert_false(V2UnlockSystem.is_unlocked(novice, WARRIOR))

func test_the_warrior_is_a_v2_kind_distinct_from_the_v1_guard():
	assert_true(UnitDatabase.PLAYER_TRAINABLE_KINDS.has(WARRIOR))
	assert_ne(WARRIOR, "warrior")
	assert_eq(UnitDatabase.create_unit("warrior").unit_name, "Guarda", "o Guarda V1 é outra tropa")
	assert_true(V2UnitLine.is_line_unit(WARRIOR))
	assert_eq(V2UnitLine.base_of(MASTER), WARRIOR)

func test_a_saved_warrior_is_recreated_by_its_kind():
	# O SaveManager recria a unidade por `visual_kind` == id: o Guerreiro e todas as formas do Guerreiro voltam idênticos.
	for kind in [WARRIOR, SWORDSMAN, MASTER, HERO]:
		var data := UnitDatabase.create_unit(kind)
		assert_eq(data.visual_kind, kind)
		assert_eq(UnitDatabase.create_unit(data.visual_kind).max_hp, data.max_hp, kind)

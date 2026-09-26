extends "res://test/unit/v2_combat_fixture.gd"

## Doutrina da Cavalaria N1-N3 (Aetherlands V2 Fase 9): a Doutrina (N1, sem bônus), o Estábulo de Guerra (N2, prédio normal de treino), o Cavaleiro (N3, mobilidade
## + choque, MOVIMENTO 4) e o traço `mounted` de TODA a linha — que o Preparar Lanças do Guardião já consulta, sem integração entre as Doutrinas.
## Os MESMOS mecanismos das outras Doutrinas. Números = BALANCE PLACEHOLDER.

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
	player.v2_research.complete_research("v2_doctrine_cavalry_1")
	assert_eq(seen, [["v2_doctrine_cavalry_1", "doctrine", "v2_doctrine_cavalry"]])
	assert_eq(V2UnlockSystem.unlocked_ids(player), ["v2_doctrine_cavalry"], "nenhum prédio, unidade ou técnica")
	assert_eq([player.gold, player.mana, player.units.size()], before, "sem bônus global")
	assert_true(player.v2_research.is_available("v2_doctrine_cavalry_2"))
	assert_false(player.v2_research.is_available("v2_doctrine_cavalry_3"))

func test_every_cavalry_node_applies_its_unlock_once_with_the_generic_type_table():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	var seen := _apply_signals(player)
	for n in range(1, 10):
		player.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	assert_eq(seen, [
		["v2_doctrine_cavalry_1", "doctrine", "v2_doctrine_cavalry"],
		["v2_doctrine_cavalry_2", "building", C_STABLE],
		["v2_doctrine_cavalry_3", "unit", CAVALIER],
		["v2_doctrine_cavalry_4", "technique", CHARGE],
		["v2_doctrine_cavalry_5", "unit_upgrade", SHOCK],
		["v2_doctrine_cavalry_6", "technique", RETREAT],
		["v2_doctrine_cavalry_7", "unit_upgrade", ARMORED],
		["v2_doctrine_cavalry_8", "mastery_building", C_ORDER],
		["v2_doctrine_cavalry_9", "legendary_candidate", GRIFFON],
	])
	assert_false(player.v2_unlocks.apply_unlock("v2_doctrine_cavalry_3"), "aplicar de novo é inofensivo")

# --- N2: o Estábulo de Guerra ------------------------------------------------------------------------------------------

func test_the_stable_is_blocked_before_n2_and_free_after():
	var player := _cavalry_player(1)
	var city := _standalone_city(player)
	assert_false(city.can_build(C_STABLE), "antes do N2")
	player.v2_research.complete_research("v2_doctrine_cavalry_2")
	assert_true(city.can_build(C_STABLE), "depois do N2")

func test_the_stable_is_a_normal_building_with_the_canonical_name_and_the_other_halls_cost():
	var stable := BuildingDatabase.get_building(C_STABLE)
	assert_not_null(stable)
	assert_eq(stable.display_name, "Estábulo de Guerra")
	assert_eq(stable.display_name, V2ResearchDatabase.node_for_unlock_id(C_STABLE).display_name)
	assert_eq(stable.production_cost, 22.0)
	for other in [G_HALL, W_HALL, R_CAMP]:
		assert_eq(stable.production_cost, BuildingDatabase.get_building(other).production_cost, other)
	assert_eq(stable.trains_unit, CAVALIER)
	assert_false("upkeep" in stable.get_property_list().map(func(p): return p.name), "sem upkeep")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == C_STABLE).size(), 1)
	assert_true(ResourceLoader.exists(stable.model_scene_path), stable.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(C_STABLE, race), "Estábulo de Guerra", race)

func test_the_stable_needs_no_v1_building_and_no_other_doctrine_and_the_v1_stable_does_not_stand_in():
	assert_eq(BuildingDatabase.get_building(C_STABLE).requires_building, "", "nem Quartel V1 nem outro Salão")
	var player := _cavalry_player(2)
	assert_true(_standalone_city(player).can_build(C_STABLE), "sem nenhum prédio")
	var v1_only := _standalone_city(_player(9, 9, 9), ["stable", "barracks"])
	assert_false(v1_only.can_build(C_STABLE), "V1 e as outras Doutrinas completas não bastam")

func test_the_stable_uses_a_normal_slot_is_built_once_and_belongs_to_the_researching_civilization():
	var player := _cavalry_player(2)
	var city := _standalone_city(player)
	var used := city.used_building_slots()
	city.buildings[C_STABLE] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(C_STABLE))
	assert_true(_standalone_city(_cavalry_player(2)).can_build(C_STABLE))
	assert_false(_standalone_city(_cavalry_player(1)).can_build(C_STABLE))

# --- N3: o Cavaleiro ------------------------------------------------------------------------------------------------------------

func test_the_cavalier_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(CAVALIER)
	assert_eq(data.unit_name, "Cavaleiro")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points], [17.0, 5.0, 3.0, 4.0])
	assert_eq(data.vision_range, 4)
	assert_eq(data.attack_range, 1, "melee")
	assert_eq(data.production_cost, 24.0)
	assert_eq(data.visual_kind, CAVALIER, "o SaveManager recria a unidade por ele")
	assert_true(data.has_trait(UnitData.TRAIT_MOUNTED))
	assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY) or data.has_trait(UnitData.TRAIT_FLYING))
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND, "a Cavalaria convencional usa o pathfinding terrestre normal")
	assert_false(data.can_found_city)

func test_the_cavalier_is_mobility_not_raw_stats_compared_with_the_warrior():
	var cavalier := UnitDatabase.create_unit(CAVALIER)
	var warrior := UnitDatabase.create_unit(WARRIOR)
	assert_eq(cavalier.movement_points, warrior.movement_points * 2.0, "o dobro do movimento")
	assert_gt(cavalier.vision_range, warrior.vision_range)
	assert_eq(cavalier.attack, warrior.attack, "ataque semelhante")
	assert_lt(cavalier.defense, warrior.defense, "um pouco menos de Defesa")
	assert_lt(absf(cavalier.max_hp - warrior.max_hp), 3.0, "vida parecida")
	assert_gt(cavalier.production_cost, warrior.production_cost, "mais caro")
	var grid := _world()
	var me := _cavalry_player(3)
	var other := _player(3)
	var rival := _rival_of(me)
	var c := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	var w := _unit(grid, rival, WARRIOR, Vector2i(1, 0))
	assert_lte(CombatResolver.predict(c, w, grid).damage_to_defender, CombatResolver.predict(w, c, grid).damage_to_defender, "não vence o Guerreiro de frente pelos números")
	assert_not_null(other)

func test_the_cavalier_moves_4_tiles_with_the_normal_movement_system():
	var grid := _world()
	var me := _cavalry_player(3)
	var cavalier := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	var reach := grid.unit_reachable(cavalier)
	assert_eq(reach, grid.compute_reachable(cavalier.coord, cavalier.movement_left, me, false, false), "é exatamente o compute_reachable de sempre")
	assert_true(reach.has(Vector2i(4, 0)), "alcança 4 tiles")
	assert_false(reach.has(Vector2i(5, 0)), "e não 5")
	var warrior := _unit(grid, me, WARRIOR, Vector2i(-3, 0))
	assert_false(grid.unit_reachable(warrior).has(Vector2i(-6, 0)), "o Guerreiro (movimento 2) anda metade")
	var before := cavalier.coord
	grid.move_unit(cavalier, Vector2i(4, 0), reach[Vector2i(4, 0)])
	assert_eq(cavalier.coord, Vector2i(4, 0))
	assert_eq(cavalier.movement_left, 0.0)
	assert_ne(before, cavalier.coord)

func test_terrain_blocks_and_occupation_work_for_the_cavalier_as_for_any_ground_unit():
	var grid := _world()
	var me := _cavalry_player(3)
	var cavalier := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	_set_terrain(grid, Vector2i(1, 0), HexTileData.TerrainType.MOUNTAINS)
	_unit(grid, me, SHIELD, Vector2i(0, 1))
	var reach := grid.unit_reachable(cavalier)
	assert_false(reach.has(Vector2i(1, 0)), "montanha bloqueia")
	assert_false(reach.has(Vector2i(0, 1)), "tile ocupado bloqueia")
	assert_true(reach.has(Vector2i(2, 0)) or reach.has(Vector2i(1, 1)), "contorna")

func test_the_cavalier_needs_n3_and_the_stable_and_goes_through_the_normal_queue():
	var player := _cavalry_player(2)
	var city := _standalone_city(player, [C_STABLE])
	assert_false(city.can_train(CAVALIER), "sem N3")
	player.v2_research.complete_research("v2_doctrine_cavalry_3")
	assert_true(player.has_unlocked(CAVALIER))
	assert_true(city.can_train(CAVALIER), "N3 + Estábulo")
	assert_false(_standalone_city(player).can_train(CAVALIER), "sem o Estábulo")
	city.set_production(CAVALIER)
	assert_eq(city.production_item, CAVALIER)
	assert_eq(city.production_cost(), 24.0)

func test_the_cavalier_needs_the_war_stable_not_the_v1_stable_barracks_or_other_halls():
	var player := _player(3, 3, 3, 3)
	assert_false(_standalone_city(player, ["stable", "barracks", G_HALL, W_HALL, R_CAMP]).can_train(CAVALIER))
	assert_true(_standalone_city(player, [C_STABLE]).can_train(CAVALIER))
	assert_false(_standalone_city(player, [C_STABLE]).can_train(SHIELD), "o Estábulo não treina as outras linhas")

func test_two_civilizations_keep_their_own_availability_and_the_kind_is_the_save_contract():
	var researcher := _standalone_city(_cavalry_player(3), [C_STABLE])
	var novice_player := _cavalry_player(2)
	var novice := _standalone_city(novice_player, [C_STABLE])
	assert_true(researcher.can_train(CAVALIER))
	assert_false(novice.can_train(CAVALIER))
	assert_false(V2UnlockSystem.is_unlocked(novice_player, CAVALIER))
	for kind in [CAVALIER, SHOCK, ARMORED, GRIFFON]:
		var data := UnitDatabase.create_unit(kind)
		assert_eq(data.visual_kind, kind)
		assert_eq(UnitDatabase.create_unit(data.visual_kind).movement_points, data.movement_points, kind)
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(kind), 1, kind)

# --- Traço `mounted` em toda a linha e o Preparar Lanças -------------------------------------------------------------------------------

func test_every_form_of_the_line_and_the_legend_is_mounted_and_no_other_doctrine_unit_is():
	for kind in [CAVALIER, SHOCK, ARMORED, GRIFFON]:
		var data := UnitDatabase.create_unit(kind)
		assert_true(data.has_trait(UnitData.TRAIT_MOUNTED), "%s é montado" % kind)
		assert_true(UnitAbilities.is_mounted(data), kind)
	for kind in [SHIELD, SENTINEL, CHAMPION, WARRIOR, MASTER, HERO, ARCHER, MARKSMAN, LEGEND_HUNTER, "archer", "warrior", "men_at_arms"]:
		assert_false(UnitAbilities.is_mounted(UnitDatabase.create_unit(kind)), "%s não é montado" % kind)
	assert_true(UnitAbilities.is_mounted(UnitDatabase.create_unit("cavalry")), "a Cavalaria V1 segue montada")

func test_the_mounted_classification_is_the_trait_not_the_name_or_the_id():
	var grid := _world()
	var me := _player(0, 9, 0, 9)
	var rival := _rival_of(me)
	var impostor_data := UnitDatabase.create_unit("warrior")
	impostor_data.unit_name = "Cavaleiro"
	impostor_data.visual_kind = CAVALIER
	var impostor := grid.spawn_unit(Vector2i(1, 0), impostor_data, rival)
	assert_false(UnitAbilities.is_mounted(impostor.unit_data), "nome/id do Cavaleiro sem o traço não classificam")
	var fake_data := UnitDatabase.create_unit("warrior")
	fake_data.visual_kind = "qualquer_id_xyz"
	fake_data.traits.append(UnitData.TRAIT_MOUNTED)
	var fake := grid.spawn_unit(Vector2i(0, 1), fake_data, rival)
	assert_true(UnitAbilities.is_mounted(fake.unit_data), "o traço basta, mesmo com id desconhecido")
	var guardian := _unit(grid, me, SHIELD, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.attack_multiplier(guardian, impostor), 1.0)
	assert_eq(V2TechniqueRuntime.attack_multiplier(guardian, fake), 1.5, "o Preparar Lanças reconhece o traço")

func test_the_guardians_brace_spears_counters_all_four_forms_without_any_cross_doctrine_code():
	var grid := _world()
	var me := _player(0, 9, 0, 0)
	var rival := _cavalry_player(9)
	Diplomacy.declare_war(me, rival)
	var brace := V2DoctrineTechniqueDatabase.get_technique(BRACE)
	var bonus := 1.0 + brace.basic_attack_bonus
	var guardian := _unit(grid, me, SHIELD, Vector2i(0, 0))
	var index := 1
	for kind in [CAVALIER, SHOCK, ARMORED, GRIFFON]:
		var target := _unit(grid, rival, kind, Vector2i(index, 0))
		index += 1
		assert_eq(V2TechniqueRuntime.attack_multiplier(guardian, target), bonus, "%s é countereado" % kind)
	var warrior := _unit(grid, rival, WARRIOR, Vector2i(0, 2))
	assert_eq(V2TechniqueRuntime.attack_multiplier(guardian, warrior), 1.0, "quem não é montado não")

func test_the_counter_works_in_real_combat_prediction_equals_the_real_hp_loss():
	var grid := _world()
	var me := _player(0, 9, 0, 0)
	var rival := _cavalry_player(9)
	Diplomacy.declare_war(me, rival)
	var guardian := _unit(grid, me, "v2_unit_guardian", Vector2i(0, 0))
	var cavalier := _unit(grid, rival, CAVALIER, Vector2i(1, 0))
	var brace := V2DoctrineTechniqueDatabase.get_technique(BRACE)
	var plain := _formula_damage(grid, 4.0, 1.0, cavalier)
	var countered := _formula_damage(grid, 4.0, 1.0 + brace.basic_attack_bonus, cavalier)
	assert_gt(countered, plain)
	var predicted: float = CombatResolver.predict(guardian, cavalier, grid).damage_to_defender
	assert_almost_eq(predicted, countered, 0.0001)
	var hp := cavalier.hp
	CombatResolver.resolve(guardian, cavalier, grid)
	assert_almost_eq(hp - cavalier.hp, predicted, 0.0001, "predict == resolve")

func test_no_unit_id_or_doctrine_name_appears_in_the_counter_logic():
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/data/V2DoctrineTechniqueData.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["cavalier", "Cavaleiro", "griffon", "Grifo", "Cavalaria", "v2_unit_", "v2_legendary_"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])
	# a lista V1 legada (ids "cavalry", "human_knight"...) é a única definição por id, e ela só semeia o TRAÇO em create_unit — nunca decide combate
	var runtime := _code_only(FileAccess.get_file_as_string("res://scripts/core/V2TechniqueRuntime.gd"))
	assert_false(runtime.contains("cavalry"))
	assert_false(runtime.contains("MOUNTED"))

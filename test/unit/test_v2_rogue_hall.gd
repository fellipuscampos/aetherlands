extends "res://test/unit/v2_combat_fixture.gd"

## Doutrina do Ladino N1-N3 (Aetherlands V2 Fase 10): a Doutrina (N1, sem bônus), a Guilda dos Ladinos (N2, prédio normal de treino) e o Ladino
## (N3, melee frágil e móvel, especializado em alvos prioritários). Os MESMOS mecanismos das outras Doutrinas. Números = BALANCE PLACEHOLDER.

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
	player.v2_research.complete_research("v2_doctrine_rogue_1")
	assert_eq(seen, [["v2_doctrine_rogue_1", "doctrine", "v2_doctrine_rogue"]])
	assert_eq(V2UnlockSystem.unlocked_ids(player), ["v2_doctrine_rogue"], "nenhum prédio, unidade ou técnica")
	assert_eq([player.gold, player.mana, player.units.size()], before, "sem bônus global")
	assert_true(player.v2_research.is_available("v2_doctrine_rogue_2"))
	assert_false(player.v2_research.is_available("v2_doctrine_rogue_3"))

func test_every_rogue_node_applies_its_unlock_once_with_the_generic_type_table():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	var seen := _apply_signals(player)
	for n in range(1, 10):
		player.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	assert_eq(seen, [
		["v2_doctrine_rogue_1", "doctrine", "v2_doctrine_rogue"],
		["v2_doctrine_rogue_2", "building", ROGUE_GUILD],
		["v2_doctrine_rogue_3", "unit", ROGUE],
		["v2_doctrine_rogue_4", "technique", SNEAK_ATTACK],
		["v2_doctrine_rogue_5", "unit_upgrade", SABOTEUR],
		["v2_doctrine_rogue_6", "technique", DISMANTLE],
		["v2_doctrine_rogue_7", "unit_upgrade", ASSASSIN],
		["v2_doctrine_rogue_8", "mastery_building", ROGUE_MASTERY],
		["v2_doctrine_rogue_9", "legendary_candidate", SHADOW_MASTER],
	])
	assert_false(player.v2_unlocks.apply_unlock("v2_doctrine_rogue_3"), "aplicar de novo é inofensivo")

# --- N2: a Guilda dos Ladinos ------------------------------------------------------------------------------------------

func test_the_guild_is_blocked_before_n2_and_free_after():
	var player := _rogue_player(1)
	var city := _standalone_city(player)
	assert_false(city.can_build(ROGUE_GUILD), "antes do N2")
	player.v2_research.complete_research("v2_doctrine_rogue_2")
	assert_true(city.can_build(ROGUE_GUILD), "depois do N2")

func test_the_guild_is_a_normal_building_with_the_canonical_name_and_the_other_halls_cost():
	var guild := BuildingDatabase.get_building(ROGUE_GUILD)
	assert_not_null(guild)
	assert_eq(guild.display_name, "Guilda dos Ladinos")
	assert_eq(guild.display_name, V2ResearchDatabase.node_for_unlock_id(ROGUE_GUILD).display_name)
	assert_eq(guild.production_cost, 22.0)
	for other in [G_HALL, W_HALL, R_CAMP, C_STABLE]:
		assert_eq(guild.production_cost, BuildingDatabase.get_building(other).production_cost, other)
	assert_eq(guild.trains_unit, ROGUE)
	assert_false("upkeep" in guild.get_property_list().map(func(p): return p.name), "sem upkeep")
	assert_eq(BuildingDatabase.all_buildings().filter(func(b): return b.id == ROGUE_GUILD).size(), 1)
	assert_true(ResourceLoader.exists(guild.model_scene_path), guild.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(ROGUE_GUILD, race), "Guilda dos Ladinos", race)

func test_the_guild_needs_no_v1_building_and_no_other_doctrine():
	assert_eq(BuildingDatabase.get_building(ROGUE_GUILD).requires_building, "", "nenhum prédio V1 nem outra Doutrina")
	var player := _rogue_player(2)
	assert_true(_standalone_city(player).can_build(ROGUE_GUILD), "sem nenhum prédio")
	var others_only := _standalone_city(_player(9, 9, 9, 9), ["barracks", G_HALL, W_HALL, R_CAMP, C_STABLE])
	assert_false(others_only.can_build(ROGUE_GUILD), "V1 e as outras Doutrinas completas não bastam")

func test_the_guild_uses_a_normal_slot_is_built_once_and_belongs_to_the_researching_civilization():
	var player := _rogue_player(2)
	var city := _standalone_city(player)
	var used := city.used_building_slots()
	city.buildings[ROGUE_GUILD] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(ROGUE_GUILD))
	assert_true(_standalone_city(_rogue_player(2)).can_build(ROGUE_GUILD))
	assert_false(_standalone_city(_rogue_player(1)).can_build(ROGUE_GUILD))

# --- N3: o Ladino ------------------------------------------------------------------------------------------------------------

func test_the_rogue_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(ROGUE)
	assert_eq(data.unit_name, "Ladino")
	assert_eq([data.max_hp, data.attack, data.defense, data.movement_points], [14.0, 4.5, 2.5, 3.0])
	assert_eq(data.vision_range, 4)
	assert_eq(data.attack_range, 1, "melee")
	assert_eq(data.production_cost, 20.0)
	assert_eq(data.visual_kind, ROGUE, "o SaveManager recria a unidade por ele")
	assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY) or data.has_trait(UnitData.TRAIT_MOUNTED) or data.has_trait(UnitData.TRAIT_FLYING))
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_false(data.can_found_city)

func test_the_rogue_is_fragile_and_mobile_not_frontline_compared_with_the_warrior():
	var rogue := UnitDatabase.create_unit(ROGUE)
	var warrior := UnitDatabase.create_unit(WARRIOR)
	assert_lt(rogue.max_hp, warrior.max_hp, "menos vida")
	assert_lt(rogue.defense, warrior.defense, "menos Defesa")
	assert_lt(rogue.attack, warrior.attack, "não vence pelo ataque básico")
	assert_gt(rogue.vision_range, warrior.vision_range)
	assert_gt(rogue.movement_points, warrior.movement_points, "mais Movimento: mobilidade é a identidade")
	var grid := _world()
	var me := _rogue_player(3)
	var rival := _rival_of(me)
	var r := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var w := _unit(grid, rival, WARRIOR, Vector2i(1, 0))
	assert_lte(CombatResolver.predict(r, w, grid).damage_to_defender, CombatResolver.predict(w, r, grid).damage_to_defender, "não vence o Guerreiro de frente pelos números")

func test_the_rogue_moves_3_tiles_with_the_normal_movement_system():
	var grid := _world()
	var me := _rogue_player(3)
	var rogue := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var reach := grid.unit_reachable(rogue)
	assert_eq(reach, grid.compute_reachable(rogue.coord, rogue.movement_left, me, false, false), "é exatamente o compute_reachable de sempre")
	assert_true(reach.has(Vector2i(3, 0)), "alcança 3 tiles")
	assert_false(reach.has(Vector2i(4, 0)), "e não 4")

func test_terrain_blocks_and_occupation_work_for_the_rogue_as_for_any_ground_unit():
	var grid := _world()
	var me := _rogue_player(3)
	var rogue := _unit(grid, me, ROGUE, Vector2i(0, 0))
	_set_terrain(grid, Vector2i(1, 0), HexTileData.TerrainType.MOUNTAINS)
	_unit(grid, me, WARRIOR, Vector2i(0, 1))
	var reach := grid.unit_reachable(rogue)
	assert_false(reach.has(Vector2i(1, 0)), "montanha bloqueia")
	assert_false(reach.has(Vector2i(0, 1)), "tile ocupado bloqueia")
	assert_true(reach.has(Vector2i(2, 0)) or reach.has(Vector2i(1, 1)), "contorna")

func test_the_rogue_needs_n3_and_the_guild_and_goes_through_the_normal_queue():
	var player := _rogue_player(2)
	var city := _standalone_city(player, [ROGUE_GUILD])
	assert_false(city.can_train(ROGUE), "sem N3")
	player.v2_research.complete_research("v2_doctrine_rogue_3")
	assert_true(player.has_unlocked(ROGUE))
	assert_true(city.can_train(ROGUE), "N3 + Guilda")
	assert_false(_standalone_city(player).can_train(ROGUE), "sem a Guilda")
	city.set_production(ROGUE)
	assert_eq(city.production_item, ROGUE)
	assert_eq(city.production_cost(), 20.0)

func test_the_rogue_needs_the_guild_not_the_other_halls():
	var player := _player(3, 3, 3, 3, 3)
	# Aetherlands V2, Fase 15 — vários prédios com upkeep (§24-30) sem Mercado e sem Ouro em caixa
	# entrariam em Déficit sozinhos, bloqueando o treino por um motivo alheio ao que este teste
	# verifica (qual prédio treina a forma).
	player.gold = 1000.0
	assert_false(_standalone_city(player, ["barracks", G_HALL, W_HALL, R_CAMP, C_STABLE]).can_train(ROGUE))
	assert_true(_standalone_city(player, [ROGUE_GUILD]).can_train(ROGUE))
	assert_false(_standalone_city(player, [ROGUE_GUILD]).can_train(SHIELD), "a Guilda não treina as outras linhas")

func test_two_civilizations_keep_their_own_availability_and_the_kind_is_the_save_contract():
	var researcher := _standalone_city(_rogue_player(3), [ROGUE_GUILD])
	var novice_player := _rogue_player(2)
	var novice := _standalone_city(novice_player, [ROGUE_GUILD])
	assert_true(researcher.can_train(ROGUE))
	assert_false(novice.can_train(ROGUE))
	assert_false(V2UnlockSystem.is_unlocked(novice_player, ROGUE))
	for kind in [ROGUE, SABOTEUR, ASSASSIN, SHADOW_MASTER]:
		var data := UnitDatabase.create_unit(kind)
		assert_eq(data.visual_kind, kind)
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(kind), 1, kind)

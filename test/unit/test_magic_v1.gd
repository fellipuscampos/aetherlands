extends GutTest

var grid: HexGrid
var player: PlayerData
var enemy: PlayerData
var original: Dictionary
var original_rules: int

func before_each():
	original_rules = GameManager.victory_rules_version
	original = {"players": GameManager.players, "human": GameManager.human_player, "rivals": GameManager.rival_players, "grid": GameManager.hex_grid, "turn": TurnManager.turn_number, "state": GameManager.state, "processing": GameManager.is_turn_processing, "race": GameManager.human_race, "name": GameManager.human_kingdom_name, "width": GameManager.map_width, "height": GameManager.map_height, "count": GameManager.rival_count}
	grid = HexGrid.new()
	add_child_autofree(grid)
	grid.map_width = 11
	grid.map_height = 11
	grid.map_seed = 1234
	for q in range(-5, 6):
		for r in range(-5, 6):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	player = PlayerData.new(CivilizationData.new())
	enemy = PlayerData.new(CivilizationData.new())
	GameManager.players = [player, enemy]
	GameManager.human_player = player
	GameManager.rival_players = [enemy]
	GameManager.hex_grid = grid
	GameManager.is_turn_processing = false
	TurnManager.turn_number = 1
	player.mana = 1000
	Diplomacy.declare_war(player, enemy)

func after_each():
	GameManager.victory_rules_version = original_rules
	for p in GameManager.players:
		p.release_relations()
	player.release_relations()
	enemy.release_relations()
	GameManager.players = original.players
	GameManager.human_player = original.human
	GameManager.rival_players = original.rivals
	GameManager.hex_grid = original.grid
	GameManager.state = original.state
	GameManager.is_turn_processing = original.processing
	GameManager.human_race = original.race
	GameManager.human_kingdom_name = original.name
	GameManager.map_width = original.width
	GameManager.map_height = original.height
	GameManager.rival_count = original.count
	TurnManager.turn_number = original.turn
	SaveManager.delete_save("user://magic_v1_test.json")

func test_selected_caster_never_silently_uses_another_units_action():
	learn("sagrada", 4)
	var first := grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("cleric"), player)
	var second := grid.spawn_unit(Vector2i(0, 1), UnitDatabase.create_unit("cleric"), player)
	first.movement_left = 0
	second.hp = 1
	MagicRuntime.cast(player, SpellDatabase.get_spell("Cura Sagrada"), second.coord, grid, first)
	assert_eq(second.hp, 1.0)
	assert_eq(player.mana, 1000.0)

func test_school_damage_and_silence_respect_peace_and_reveal_attacker():
	learn("infernal", 4)
	var caster := grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("cultist"), player)
	var target := grid.spawn_unit(Vector2i(2, 0), UnitDatabase.create_unit("stone_golem"), enemy)
	var other := PlayerData.new(CivilizationData.new())
	var bystander := grid.spawn_unit(Vector2i(2, 1), UnitDatabase.create_unit("warrior"), other)
	var hp := target.hp
	MagicRuntime.cast(player, SpellDatabase.get_spell("Fogo Infernal"), target.coord, grid, caster)
	assert_eq(target.hp, hp - 12.0)
	assert_eq(bystander.hp, bystander.unit_data.max_hp)
	assert_true(MagicRuntime.status_active(caster, "revealed"))
	learn("arcanismo", 5)
	var arcanist := grid.spawn_unit(Vector2i(0, 1), UnitDatabase.create_unit("arcanist"), player)
	var enemy_caster := grid.spawn_unit(Vector2i(1, 1), UnitDatabase.create_unit("cleric"), enemy)
	MagicRuntime.cast(player, SpellDatabase.get_spell("Selo de Mana"), enemy_caster.coord, grid, arcanist)
	assert_false(MagicRuntime.eligible_caster(enemy_caster, SpellDatabase.get_spell("Cura Sagrada")))
	TurnManager.turn_number += 3
	assert_true(MagicRuntime.eligible_caster(enemy_caster, SpellDatabase.get_spell("Cura Sagrada")))

func test_autonomous_boss_waits_for_its_first_turn_and_has_bound_followers():
	var boss := MagicRuntime.summon(player, "elder_lich", Vector2i.ZERO, grid)
	var victim := grid.spawn_unit(Vector2i(2, 0), UnitDatabase.create_unit("stone_golem"), enemy)
	var hp := victim.hp
	MagicRuntime._act_boss(boss, player, grid)
	assert_eq(victim.hp, hp)
	TurnManager.turn_number = 2
	boss.reset_movement()
	MagicRuntime._act_boss(boss, player, grid)
	assert_lt(victim.hp, hp)
	assert_eq(player.units.filter(func(u): return u.summoner_id == boss.serial_id).size(), 1)
	grid.remove_unit(boss)
	MagicRuntime.process_turn(player, grid)
	assert_true(player.units.is_empty())

func test_cataclysm_pillages_empty_land_and_aurora_dispels_hostile_regions():
	var coord := Vector2i(2, 2)
	MagicRuntime.add_region(enemy, "cataclysm", coord, grid)
	MagicRuntime.process_turn(enemy, grid)
	assert_true(grid.is_tile_pillaged(coord, TurnManager.turn_number))
	var spell := prepare_ritual("sagrada")
	MagicRuntime.cast(player, spell, Vector2i.ZERO, grid)
	for turn in range(2, 9):
		TurnManager.turn_number = turn
		MagicRuntime.process_turn(player, grid)
	assert_true(enemy.magic_effects.is_empty())

func test_peace_truce_and_ai_random_state_survive_save_load():
	assert_true(Diplomacy.propose_peace(player, enemy))
	assert_false(Diplomacy.can_declare_war(player, enemy))
	player.ai_rng.seed = 1709
	player.ai_rng.randf()
	assert_true(SaveManager.save_game(grid, "user://magic_v1_test.json"))
	var next_roll := player.ai_rng.randf()
	assert_true(SaveManager.load_game(grid, "user://magic_v1_test.json"))
	var loaded := GameManager.human_player
	assert_eq(loaded.ai_rng.randf(), next_roll)
	assert_eq(Diplomacy.truce_remaining(loaded, GameManager.rival_players[0]), 10)
	TurnManager.turn_number += 10
	assert_true(Diplomacy.can_declare_war(loaded, GameManager.rival_players[0]))

func test_invalid_nested_save_rejected_before_current_match_is_changed():
	prepare_ritual("sagrada")
	assert_true(SaveManager.save_game(grid, "user://magic_v1_test.json"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://magic_v1_test.json"))
	data.human.magic_effects = [{"effect": "forest", "center": [0]}]
	var file := FileAccess.open("user://magic_v1_test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	assert_false(SaveManager.load_game(grid, "user://magic_v1_test.json"))
	assert_same(GameManager.human_player, player)
	assert_eq(player.cities.size(), 1)

func test_ai_reacts_to_announced_transcendence_and_targets_its_seat():
	var city := grid.found_city(Vector2i.ZERO, enemy, "Ritual")
	enemy.arcane_ritual_active = true
	enemy.arcane_ritual_city_coord = city.coord
	player.enemies.clear()
	enemy.enemies.clear()
	grid.spawn_unit(Vector2i(4, 0), UnitDatabase.create_unit("warrior"), player)
	grid.spawn_unit(Vector2i(4, 1), UnitDatabase.create_unit("warrior"), player)
	RivalAI.decide_war(player, grid, enemy)
	assert_true(player.is_at_war_with(enemy))
	assert_eq(MagicAI.counter_ritual_target(player, enemy, grid), city.coord)

func test_malformed_units_and_events_do_not_destroy_current_match():
	grid.found_city(Vector2i.ZERO, player, "Capital")
	assert_true(SaveManager.save_game(grid, "user://magic_v1_test.json"))
	var original_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://magic_v1_test.json"))
	for malformed in [{"units": [42]}, {"world_events": []}, {"world_events": {"events": [{"event_type": "dragon", "origin_region": [0]}]}}]:
		var data := original_data.duplicate(true)
		if malformed.has("units"):
			data.human.units = malformed.units
		else:
			data.world_events = malformed.world_events
		var file := FileAccess.open("user://magic_v1_test.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		assert_false(SaveManager.load_game(grid, "user://magic_v1_test.json"))
		assert_same(GameManager.human_player, player)
		assert_eq(player.cities.size(), 1)

func test_ai_limits_recruitment_but_still_replaces_losses():
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	for coord in grid.get_neighbors(city.coord):
		grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), player)
	assert_lt(StrategicAI.production_score(player, city, "warrior", grid), 0.0)
	for unit in player.units.duplicate().slice(0, 4):
		grid.remove_unit(unit)
	assert_gt(StrategicAI.production_score(player, city, "warrior", grid), 0.0)

func test_transcendence_uses_the_sanctuary_with_prepared_casters():
	var empty_seat := grid.found_city(Vector2i(-5, -5), player, "Distante")
	empty_seat.buildings[VictoryConditions.SANCTUARY_BUILDING_ID] = true
	var prepared := prepare_transcendence()
	assert_same(VictoryCampaign.sanctuary(player), prepared)
	assert_true(VictoryCampaign.start(player, grid))
	assert_eq(player.arcane_ritual_city_coord, prepared.coord)

func test_dragon_contribution_survives_json_and_reward_is_paid_once():
	var event := DragonEvent.new()
	event.participants = {0: {"decision": true}, 1: {"decision": true}}
	event.damage_by_civ = {0: 75.0, 1: 25.0}
	event.result = {"outcome": "defeated"}
	var loaded := DragonEvent.new()
	loaded.from_save_dict(JSON.parse_string(JSON.stringify(event.to_save_dict())))
	var gold := player.gold
	loaded.award_contribution_rewards(GameManager.players)
	assert_eq(player.gold, gold + 250.0)
	assert_true(loaded.participants.has(0))
	var again := DragonEvent.new()
	again.from_save_dict(JSON.parse_string(JSON.stringify(loaded.to_save_dict())))
	again.award_contribution_rewards(GameManager.players)
	assert_eq(player.gold, gold + 250.0)

func test_transformed_forest_updates_props_and_disappears_on_expiry():
	var coord := Vector2i(2, 2)
	MagicRuntime.add_region(player, "forest", coord, grid)
	await get_tree().process_frame
	assert_true(grid._changed_tree_props.has(coord))
	TurnManager.turn_number = 6
	MagicRuntime.process_turn(player, grid)
	await get_tree().process_frame
	assert_false(grid._changed_tree_props.has(coord))
	assert_eq(grid.get_tile(coord).terrain_type, HexTileData.TerrainType.GRASSLAND)

func learn(school: String, level: int) -> void:
	for tier in range(1, level + 1):
		player.researched_magic["%s_%d" % [school, tier]] = true

func prepare_ritual(school: String) -> SpellData:
	learn(school, 9)
	var city := grid.found_city(Vector2i.ZERO, player, "Sede")
	city.buildings[MagicContent.SCHOOLS[school].ritual_building] = true
	var count := 5 if school == "necromancia" else 4
	for coord in grid.get_neighbors(city.coord).slice(0, count):
		grid.spawn_unit(coord, UnitDatabase.create_unit(MagicContent.SCHOOLS[school].caster), player)
	return SpellDatabase.get_spell(MagicContent.SCHOOLS[school].names[8])

func test_six_independent_schools_and_two_masteries_for_transcendence():
	assert_eq(MagicDatabase.all_techs().size(), 55)
	assert_eq(MagicDatabase.available_techs({}).size(), 6)
	learn("necromancia", 9)
	var ids := MagicDatabase.available_techs(player.researched_magic).map(func(t): return t.id)
	assert_false("transcendencia_arcana" in ids)
	learn("druidismo", 9)
	ids = MagicDatabase.available_techs(player.researched_magic).map(func(t): return t.id)
	assert_has(ids, "transcendencia_arcana")
	assert_false("sagrada_2" in ids)

func test_caster_cooldowns_are_independent_and_invalid_target_costs_nothing():
	learn("sagrada", 4)
	var first := grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("cleric"), player)
	var second := grid.spawn_unit(Vector2i(0, 1), UnitDatabase.create_unit("cleric"), player)
	var wounded := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), player)
	wounded.hp = 1
	var spell := SpellDatabase.get_spell("Cura Sagrada")
	var before := player.mana
	MagicRuntime.cast(player, spell, Vector2i(5, 5), grid, first)
	assert_eq(player.mana, before)
	MagicRuntime.cast(player, spell, wounded.coord, grid, first)
	assert_gt(wounded.hp, 1.0)
	assert_false(MagicRuntime.eligible_caster(first, spell))
	assert_true(MagicRuntime.eligible_caster(second, spell))
	assert_eq(first.movement_left, 0.0)

func test_summon_limit_and_loss_of_summoner_are_real():
	learn("necromancia", 5)
	var caster := grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("necromancer"), player)
	var spell := SpellDatabase.get_spell("Erguer os Mortos")
	for i in range(3):
		caster.reset_movement()
		caster.magic_cooldowns.clear()
		MagicRuntime.cast(player, spell, grid.get_neighbors(caster.coord)[i], grid, caster)
	assert_eq(player.units.size(), 4)
	caster.reset_movement()
	caster.magic_cooldowns.clear()
	assert_false(MagicRuntime.valid_target(player, spell, grid.get_neighbors(caster.coord)[4], grid, caster))
	grid.remove_unit(caster)
	MagicRuntime.process_turn(player, grid)
	assert_true(player.units.is_empty())

func test_temporary_mountains_do_not_cover_units_and_restore_resource():
	var coord := Vector2i(1, 0)
	grid.get_tile(coord).resource = "iron"
	var guard := grid.spawn_unit(Vector2i(0, 1), UnitDatabase.create_unit("warrior"), player)
	MagicRuntime.add_region(player, "mountains", coord, grid)
	assert_eq(grid.get_tile(coord).terrain_type, HexTileData.TerrainType.MOUNTAINS)
	assert_eq(grid.get_tile(guard.coord).terrain_type, HexTileData.TerrainType.GRASSLAND)
	TurnManager.turn_number = 5
	MagicRuntime.process_turn(player, grid)
	assert_eq(grid.get_tile(coord).terrain_type, HexTileData.TerrainType.GRASSLAND)
	assert_eq(grid.get_tile(coord).resource, "iron")
	assert_true(player.magic_effects.is_empty())

func test_ritual_commits_units_and_losing_one_interrupts_without_refund():
	var spell := prepare_ritual("sagrada")
	MagicRuntime.cast(player, spell, Vector2i.ZERO, grid)
	assert_eq(player.rituals.size(), 1)
	assert_eq(player.mana, 700.0)
	for unit in player.units:
		unit.reset_movement()
		assert_eq(unit.movement_left, 0.0)
	grid.remove_unit(player.units[0])
	TurnManager.turn_number += 1
	MagicRuntime.process_turn(player, grid)
	assert_eq(player.rituals[0].status, "interrupted")
	assert_false(player.completed_rituals.has("aurora"))
	for unit in player.units:
		assert_eq(unit.ritual_id, "")

func test_ritual_completes_only_after_full_channel_and_creates_persistent_effect():
	var spell := prepare_ritual("sagrada")
	MagicRuntime.cast(player, spell, Vector2i.ZERO, grid)
	MagicRuntime.process_turn(player, grid)
	assert_eq(player.rituals[0].progress, 0)
	for turn in range(2, 9):
		TurnManager.turn_number = turn
		MagicRuntime.process_turn(player, grid)
	assert_eq(player.rituals[0].status, "completed")
	assert_true(player.completed_rituals.has("aurora"))
	assert_eq(player.magic_effects[0].effect, "aurora")

func test_save_load_preserves_channelists_summons_and_temporary_land():
	var spell := prepare_ritual("sagrada")
	MagicRuntime.cast(player, spell, Vector2i.ZERO, grid)
	var invoker := grid.spawn_unit(Vector2i(3, 0), UnitDatabase.create_unit("necromancer"), player)
	var skeleton := MagicRuntime.summon(player, "bound_skeleton", Vector2i(3, 1), grid, invoker.serial_id)
	var invoker_id := invoker.serial_id
	var skeleton_id := skeleton.serial_id
	grid.get_tile(Vector2i(2, 2)).resource = "iron"
	MagicRuntime.add_region(player, "forest", Vector2i(2, 2), grid)
	assert_true(SaveManager.save_game(grid, "user://magic_v1_test.json"))
	assert_true(SaveManager.load_game(grid, "user://magic_v1_test.json"))
	var loaded := GameManager.human_player
	assert_eq(loaded.rituals[0].progress, 0)
	assert_eq(MagicRuntime.unit_by_id(loaded, skeleton_id).summoner_id, invoker_id)
	for id in loaded.rituals[0].units:
		assert_eq(MagicRuntime.unit_by_id(loaded, int(id)).ritual_id, loaded.rituals[0].id)
	assert_eq(grid.get_tile(Vector2i(2, 2)).resource, "iron")
	TurnManager.turn_number = 2
	MagicRuntime.process_turn(loaded, grid)
	assert_eq(loaded.rituals[0].progress, 1)
	TurnManager.turn_number = 6
	MagicRuntime.process_turn(loaded, grid)
	assert_eq(grid.get_tile(Vector2i(2, 2)).terrain_type, HexTileData.TerrainType.GRASSLAND)
	assert_eq(grid.get_tile(Vector2i(2, 2)).resource, "iron")

## MAGIAS, SPAWNS E ARVORES (pedido do usuario: "invocacoes... entidades
## criadas por magia" nao podem ficar visualmente enterradas numa arvore) --
## MagicRuntime.summon() passa por HexGrid.spawn_unit(), que agora limpa a
## decoracao do tile igual found_city/place_building/spawn_monster_at (ver
## HexGrid._clear_tile_decor_at).
func test_summon_clears_tree_prop_on_its_tile():
	var coord := Vector2i(4, 4)
	grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis(), Vector3.ONE))
	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	grid.add_child(mm_instance)
	grid._props_tree_instance = mm_instance
	grid._tree_coord_to_index[coord] = [0]

	var summoned := MagicRuntime.summon(player, "bound_skeleton", coord, grid)

	assert_not_null(summoned, "precondicao: invocacao deveria ter sucedido no tile de Floresta")
	assert_false(grid._tree_coord_to_index.has(coord), "arvore nao deveria continuar registrada no tile da invocacao")

func test_ai_uses_healing_for_a_wounded_ally():
	learn("sagrada", 4)
	grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("cleric"), player)
	var wounded := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), player)
	wounded.hp = 1
	MagicAI.take_turn(player, grid)
	assert_gt(wounded.hp, 1.0)
	assert_lt(player.mana, 1000.0)

func prepare_transcendence() -> City:
	learn("sagrada", 9)
	learn("arcanismo", 9)
	player.researched_magic["transcendencia_arcana"] = true
	player.completed_rituals = {"aurora": true, "convergence": true}
	player.mana_income_per_turn = 30
	var city := grid.found_city(Vector2i.ZERO, player, "Santuário")
	city.buildings["arcane_sanctuary"] = true
	var neighbors := grid.get_neighbors(city.coord)
	for i in range(5):
		grid.spawn_unit(neighbors[i], UnitDatabase.create_unit("cleric" if i < 3 else "arcanist"), player)
	for i in range(3):
		grid.get_tile(neighbors[i]).resource = "mana_node"
	return city

func test_transcendence_needs_executed_rituals_and_commits_two_schools():
	prepare_transcendence()
	player.completed_rituals.clear()
	assert_false(VictoryCampaign.start(player, grid))
	player.completed_rituals = {"aurora": true, "convergence": true}
	assert_true(VictoryCampaign.start(player, grid))
	assert_eq(player.mana, 600.0)
	assert_eq(player.arcane_ritual_units.size(), 5)
	var schools := {}
	for id in player.arcane_ritual_units:
		var caster := MagicRuntime.unit_by_id(player, id)
		schools[caster.unit_data.magic_school] = true
		assert_eq(caster.ritual_id, "transcendence")
	assert_eq(schools.size(), 2)
	VictoryCampaign.advance(player, grid)
	assert_eq(player.arcane_ritual_streak, 0)
	for turn in range(2, 9):
		TurnManager.turn_number = turn
		VictoryCampaign.advance(player, grid)
	assert_eq(player.arcane_ritual_streak, 7)
	assert_eq(player.mana, 320.0)

func test_transcendence_interrupts_when_a_node_is_lost():
	var city := prepare_transcendence()
	assert_true(VictoryCampaign.start(player, grid))
	grid.get_tile(grid.get_neighbors(city.coord)[0]).resource = ""
	TurnManager.turn_number += 1
	VictoryCampaign.advance(player, grid)
	assert_false(player.arcane_ritual_active)
	assert_eq(player.arcane_ritual_streak, 0)
	assert_true(player.units.all(func(u): return u.ritual_id == ""))

func test_supremacy_rejects_undeveloped_colonies_and_requires_two_conquests():
	player.researched_techs["exercito_supremo"] = true
	var capital := grid.found_city(Vector2i(-3, 0), enemy, "Capital")
	var colony := grid.found_city(Vector2i(3, 0), enemy, "Colônia")
	grid.spawn_unit(Vector2i(4, 0), UnitDatabase.create_unit("warrior"), enemy)
	capital.population = 3
	capital.buildings = {"granary": true, "barracks": true}
	grid.capture_city(capital, player)
	grid.capture_city(colony, player)
	assert_true(capital.captured_developed)
	assert_false(colony.captured_developed)
	assert_false(VictoryCampaign.supremacy_achieved(player, GameManager.players))
	colony.population = 3
	colony.buildings = {"granary": true, "barracks": true}
	grid.capture_city(colony, enemy)
	grid.capture_city(colony, player)
	assert_true(VictoryCampaign.supremacy_achieved(player, GameManager.players))
	player.researched_techs.clear()
	assert_false(VictoryCampaign.supremacy_achieved(player, GameManager.players))

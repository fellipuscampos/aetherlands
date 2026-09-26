extends GutTest

const SAVE_PATH := "user://test_v2_ai_strategy.json"

var grid: HexGrid
var original_players: Array[PlayerData]
var original_human: PlayerData
var original_rivals: Array[PlayerData]
var original_grid: HexGrid
var original_turn: int
var players_to_release: Array[PlayerData] = []

func before_each():
	original_players = GameManager.players
	original_human = GameManager.human_player
	original_rivals = GameManager.rival_players
	original_grid = GameManager.hex_grid
	original_turn = TurnManager.turn_number
	TurnManager.turn_number = 1
	grid = HexGrid.new()
	grid._ready()
	for q in range(-10, 11):
		for r in range(-10, 11):
			if absi(q + r) <= 10:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.hex_grid = grid

func after_each():
	SaveManager.delete_save(SAVE_PATH)
	V2AITacticalAI.clear_views()
	for player in players_to_release:
		player.release_relations()
	players_to_release.clear()
	GameManager.players = original_players
	GameManager.human_player = original_human
	GameManager.rival_players = original_rivals
	GameManager.hex_grid = original_grid
	TurnManager.turn_number = original_turn
	if is_instance_valid(grid):
		grid.queue_free()

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	var player := PlayerData.new(civ)
	players_to_release.append(player)
	return player

func _install_world(rival_count: int = 3) -> Array[PlayerData]:
	var human := _player("Human")
	var rivals: Array[PlayerData] = []
	for i in range(rival_count):
		rivals.append(_player("Rival %d" % i))
	GameManager.human_player = human
	GameManager.rival_players = rivals
	GameManager.players = ([human] as Array[PlayerData]) + rivals
	for i in range(rivals.size()):
		V2StrategicAI.initialize_player(rivals[i], i, grid.map_seed, rivals.size())
	return rivals

func _spawn(player: PlayerData, kind: String, coord: Vector2i) -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player)

func _learn_branch(player: PlayerData, tree_prefix: String, branch: String, tier: int) -> void:
	for i in range(1, tier + 1):
		player.v2_research.complete_research("v2_%s_%s_%d" % [tree_prefix, branch, i])

func _ready_transcendence(player: PlayerData, city: City) -> void:
	_learn_branch(player, "magic", "sacred", 9)
	_learn_branch(player, "magic", "infernal", 9)
	assert_true(player.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID))
	city.buildings["v2_building_sacred_ritual"] = true
	_spawn(player, "v2_manifestation_seraph", city.coord + Vector2i(1, 0))
	_spawn(player, "v2_manifestation_archdemon", city.coord + Vector2i(-1, 0))
	player.mana = 300.0

func test_three_rivals_receive_exactly_one_orientation_each():
	grid.map_seed = 24024
	var rivals := _install_world(3)
	var orientations := rivals.map(func(p): return p.v2_ai_strategy.orientation)
	orientations.sort()
	assert_eq(orientations, [V2AIStrategyState.Orientation.MILITARY, V2AIStrategyState.Orientation.ARCANE, V2AIStrategyState.Orientation.BALANCED])

func test_orientation_is_deterministic_without_consuming_global_rng():
	seed(9917)
	var expected := randf()
	seed(9917)
	var state := V2AIStrategyState.new()
	state.initialize(0, 117, 1)
	assert_almost_eq(randf(), expected, 0.000001)
	var same := V2AIStrategyState.new()
	same.initialize(0, 117, 1)
	assert_eq(same.orientation, state.orientation)
	var changed := V2AIStrategyState.new()
	changed.initialize(0, 118, 1)
	assert_ne(changed.orientation, state.orientation)

func test_strategy_state_round_trip_preserves_personality_and_memory():
	var source := V2AIStrategyState.new()
	source.initialize(1, 444, 3)
	source.preferred_doctrine_branches = ["guardian", "siege"]
	source.preferred_magic_branches = ["sacred", "infernal"]
	source.adaptive_doctrine_branch = "rogue"
	source.pressure_by_role_or_trait = {"caster": 2.5}
	var restored := V2AIStrategyState.new()
	restored.load_dict(source.to_dict(), 1, 444, 3)
	assert_eq(restored.to_dict(), source.to_dict())
	assert_true(restored.last_reasons.is_empty(), "transient explanations are not saved")

func test_legacy_state_reconstructs_from_seed():
	var state := V2AIStrategyState.new()
	state.load_dict(null, 2, 771, 3)
	var expected := V2AIStrategyState.new()
	expected.initialize(2, 771, 3)
	assert_eq(state.orientation, expected.orientation)
	assert_eq(state.strategy_seed, expected.strategy_seed)

func test_human_is_never_enabled_or_automatically_mutated():
	var rivals := _install_world(1)
	var human := GameManager.human_player
	grid.found_city(Vector2i.ZERO, human, "Manual", true)
	var before_gold := human.gold
	assert_false(V2StrategicAI.is_enabled_for(human))
	assert_true(V2StrategicAI.plan_turn(human, grid).is_empty())
	assert_eq(human.v2_research.active_id, "")
	assert_eq(human.cities[0].production_item, "")
	assert_eq(human.gold, before_gold)
	assert_true(V2StrategicAI.is_enabled_for(rivals[0]))

func test_world_view_filters_hidden_units_and_never_exposes_enemy_economy():
	var rivals := _install_world(1)
	var observer := rivals[0]
	var enemy := GameManager.human_player
	_spawn(observer, "guard", Vector2i.ZERO)
	var visible := _spawn(enemy, "guard", Vector2i(2, 0))
	var hidden := _spawn(enemy, "cavalry", Vector2i(9, 0))
	grid.found_city(Vector2i(3, 0), enemy, "Visible", true).production_item = "secret_queue"
	var view := V2AIWorldView.capture(observer, grid)
	assert_has(view.visible_enemy_units, visible)
	assert_does_not_have(view.visible_enemy_units, hidden)
	for city_record in view.known_enemy_cities:
		assert_false(city_record.has("city"))
		assert_false(city_record.has("owner_player"))
		assert_false(city_record.has("buildings"))
		assert_false(city_record.has("production_item"))
	assert_eq(view.known_enemy_cities.size(), 1)
	assert_false("gold" in view)
	assert_false("mana" in view)
	assert_false("research" in view)
	assert_false("production" in view)

func test_hidden_mounted_units_do_not_affect_pressure_but_repeated_visible_units_do():
	var rivals := _install_world(1)
	var observer := rivals[0]
	var enemy := GameManager.human_player
	_spawn(observer, "guard", Vector2i.ZERO)
	_spawn(enemy, "cavalry", Vector2i(9, 0))
	for turn in range(1, 5):
		TurnManager.turn_number = turn
		V2StrategicAI.plan_turn(observer, grid)
	assert_eq(float(observer.v2_ai_strategy.pressure_by_role_or_trait.get("mounted", 0.0)), 0.0)
	var mounted := _spawn(enemy, "cavalry", Vector2i(2, 0))
	for turn in range(5, 12):
		TurnManager.turn_number = turn
		V2StrategicAI.plan_turn(observer, grid)
	assert_gt(float(observer.v2_ai_strategy.pressure_by_role_or_trait.get("mounted", 0.0)), 0.75)
	assert_eq(observer.v2_ai_strategy.adaptive_doctrine_branch, "guardian")
	grid.remove_unit(mounted)
	var before := float(observer.v2_ai_strategy.pressure_by_role_or_trait.mounted)
	for turn in range(12, 18):
		TurnManager.turn_number = turn
		V2StrategicAI.plan_turn(observer, grid)
	assert_lt(float(observer.v2_ai_strategy.pressure_by_role_or_trait.mounted), before)

func test_plan_uses_single_research_slot_and_real_runtime_progress():
	var rival := _install_world(1)[0]
	grid.found_city(Vector2i.ZERO, rival, "AI", true)
	var before_overflow := rival.v2_research.research_overflow
	V2StrategicAI.plan_turn(rival, grid)
	assert_ne(rival.v2_research.active_id, "")
	var chosen := rival.v2_research.active_id
	assert_eq(rival.v2_research.get_progress(chosen), 0.0)
	rival.v2_research.add_knowledge(1.0)
	assert_eq(rival.v2_research.get_progress(chosen), 1.0)
	assert_eq(rival.v2_research.research_overflow, before_overflow)
	assert_false("military_research" in rival)
	assert_false("magic_research" in rival)

func test_active_research_with_high_progress_survives_moderate_emergency():
	var rival := _install_world(1)[0]
	grid.found_city(Vector2i.ZERO, rival, "AI", true)
	var active := "v2_doctrine_guardian_1"
	var preserved_progress := V2ResearchDatabase.get_node(active).cost * 0.75
	assert_true(rival.v2_research.select_research(active))
	rival.v2_research.add_knowledge(preserved_progress)
	rival.gold = 0.0
	V2StrategicAI.plan_turn(rival, grid)
	assert_eq(rival.v2_research.active_id, active)
	assert_eq(rival.v2_research.get_progress(active), preserved_progress)

func test_relevant_force_count_excludes_settlers_and_builders_and_has_hard_cap():
	var rival := _install_world(1)[0]
	_spawn(rival, "settler", Vector2i.ZERO)
	var military := _spawn(rival, "guard", Vector2i(1, 0))
	assert_eq(V2StrategicAI.relevant_unit_count(rival), 1)
	assert_true(military.unit_data.attack > 0.0)
	assert_lte(V2AITuning.target_relevant_units(rival), V2AITuning.NORMAL_TOKEN_CAP)

func test_hidden_known_city_is_only_a_normal_campaign_target_until_visible():
	var rival := _install_world(1)[0]
	var enemy := GameManager.human_player
	_spawn(rival, "guard", Vector2i.ZERO)
	var city := grid.found_city(Vector2i(9, 0), enemy, "Hidden IV", true)
	city.city_level = 4
	rival.known_enemy_cities[city.coord] = true
	Diplomacy.declare_war(rival, enemy)
	rival.v2_ai_strategy.victory_focus = V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY
	var hidden_view := V2AIWorldView.capture(rival, grid)
	assert_false(hidden_view.is_enemy_city_visible(city))
	assert_eq(V2StrategicAI.strategic_target_coord(rival, hidden_view), city.coord, "cidade conhecida pode ser alvo normal sem ler seu nível secreto")
	city.city_level = 1
	assert_eq(V2StrategicAI.strategic_target_coord(rival, hidden_view), city.coord, "mudar o nível oculto não altera a decisão")
	_spawn(rival, "scout", Vector2i(6, 0))
	city.city_level = 4
	var visible_view := V2AIWorldView.capture(rival, grid)
	assert_eq(V2StrategicAI.strategic_target_coord(rival, visible_view), city.coord)

func test_ritual_urgency_is_monotonic():
	assert_lt(V2StrategicAI.ritual_urgency(4), V2StrategicAI.ritual_urgency(2))
	assert_lt(V2StrategicAI.ritual_urgency(2), V2StrategicAI.ritual_urgency(1))

func test_arcane_ai_starts_a_real_ritual_and_reaches_the_real_victory_condition():
	var rival := _install_world(1)[0]
	var city := grid.found_city(Vector2i.ZERO, rival, "Conclave", true)
	rival.v2_ai_strategy.victory_focus = V2AIStrategyState.VictoryFocus.TRANSCENDENCE
	_ready_transcendence(rival, city)
	var mana_before := rival.mana
	V2StrategicAI.plan_turn(rival, grid)
	assert_true(V2TranscendenceSystem.has_active_ritual(rival))
	assert_eq(V2TranscendenceSystem.ritual_site_coord(rival), city.coord)
	assert_eq(rival.mana, mana_before - V2TranscendenceSystem.MANA_COST)
	for expected in [3, 2, 1, 0]:
		TurnManager.turn_number += 1
		V2TranscendenceSystem.process_global_round(grid)
		assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(rival), expected)
	assert_true(V2VictoryConditions.transcendence_achieved(rival))

func test_public_enemy_ritual_is_targeted_through_public_info_without_revealing_fog():
	var rival := _install_world(1)[0]
	var human := GameManager.human_player
	var ritual_city := grid.found_city(Vector2i(8, 0), human, "Oculta", true)
	_spawn(rival, "guard", Vector2i.ZERO)
	_ready_transcendence(human, ritual_city)
	assert_true(V2TranscendenceSystem.start_ritual(human, ritual_city))
	var view := V2AIWorldView.capture(rival, grid)
	assert_false(view.is_visible(ritual_city.coord))
	assert_eq(view.public_enemy_rituals().size(), 1)
	assert_eq(V2StrategicAI.strategic_target_coord(rival, view), ritual_city.coord)
	assert_eq(V2StrategicAI.public_ritual_war_pressure(human), V2AITuning.RITUAL_WAR_PRESSURE[4])
	human.v2_transcendence_ritual.remaining_rounds = 1
	assert_gt(V2StrategicAI.public_ritual_war_pressure(human), V2AITuning.RITUAL_WAR_PRESSURE[4])

func test_military_ai_targets_and_satisfies_supremacy_via_real_qualified_capture():
	var rival := _install_world(1)[0]
	var human := GameManager.human_player
	_spawn(rival, "scout", Vector2i(3, 0))
	grid.found_city(Vector2i.ZERO, rival, "Quartel-general", true)
	var target := grid.found_city(Vector2i(6, 0), human, "Metrópole", true)
	target.city_level = 3
	_learn_branch(rival, "doctrine", "guardian", 9)
	_learn_branch(rival, "doctrine", "warrior", 9)
	assert_true(rival.v2_research.complete_research(V2ResearchDatabase.SUPREME_ARMY_ID))
	rival.v2_ai_strategy.victory_focus = V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY
	Diplomacy.declare_war(rival, human)
	var view := V2AIWorldView.capture(rival, grid)
	assert_eq(V2StrategicAI.strategic_target_coord(rival, view), target.coord)
	assert_eq(V2VictoryConditions.military_supremacy_status(rival).satisfied_count, 0)
	grid.capture_city(target, rival)
	assert_eq(V2VictoryConditions.military_supremacy_status(rival).satisfied_count, 1)
	assert_true(V2VictoryConditions.military_supremacy_achieved(rival))

func test_ai_foundations_have_no_content_ids_or_frame_polling():
	for path in [
		"res://scripts/core/V2StrategicAI.gd",
		"res://scripts/core/V2AITacticalAI.gd",
		"res://scripts/core/V2AIWorldView.gd",
		"res://scripts/core/V2AIStrategyState.gd",
		"res://scripts/core/V2AITuning.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("\"v2_doctrine_"), "%s não conhece Doutrina concreta" % path)
		assert_false(source.contains("\"v2_magic_"), "%s não conhece Escola concreta" % path)
		assert_false(source.contains("\"v2_unit_"), "%s não conhece unidade concreta" % path)
		assert_false(source.contains("\"v2_spell_"), "%s não conhece feitiço concreto" % path)
		assert_false(source.contains("func _process("), "%s não faz polling por frame" % path)
		assert_false(source.contains("Timer.new("), "%s não cria timer de decisão" % path)

func test_deficit_city_queues_real_market_recovery_without_free_gold():
	var rival := _install_world(1)[0]
	var city := grid.found_city(Vector2i.ZERO, rival, "Deficit", true)
	city.city_level = 4
	_learn_branch(rival, "infrastructure", "economy", 1)
	_learn_branch(rival, "doctrine", "guardian", 8)
	city.buildings["v2_building_guardian_hall"] = true
	city.buildings["v2_building_guardian_mastery"] = true
	rival.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(rival))
	V2StrategicAI.plan_turn(rival, grid)
	assert_eq(city.production_item, "v2_building_market")
	assert_eq(rival.gold, 0.0, "planning never grants recovery gold")

func test_supply_pressure_queues_farm_and_never_bypasses_capacity_gate():
	var rival := _install_world(1)[0]
	var city := grid.found_city(Vector2i.ZERO, rival, "Supply", true)
	rival.gold = 100.0
	_learn_branch(rival, "infrastructure", "logistics", 1)
	for coord in [Vector2i(2, 0), Vector2i(2, -1), Vector2i(1, -2), Vector2i(0, -2)]:
		_spawn(rival, "v2_unit_shieldbearer", coord)
	assert_gte(float(V2LogisticsRuntime.player_supply_used(rival)) / V2EconomyRuntime.player_supply_capacity(rival), V2AITuning.SUPPLY_WARNING_RATIO)
	V2StrategicAI.plan_turn(rival, grid)
	assert_eq(city.production_item, "v2_building_farm")

func test_nearly_full_city_uses_real_city_level_project_but_sparse_city_does_not():
	var rival := _install_world(1)[0]
	var full := grid.found_city(Vector2i.ZERO, rival, "Full", true)
	var sparse := grid.found_city(Vector2i(6, 0), rival, "Sparse", true)
	rival.gold = 100.0
	_learn_branch(rival, "infrastructure", "urbanization", 1)
	full.buildings["granary"] = true
	full.buildings["workshop"] = true
	full.buildings["barracks"] = true
	V2StrategicAI.plan_turn(rival, grid)
	assert_true(V2CityLevelData.is_city_project(full.production_item))
	assert_false(V2CityLevelData.is_city_project(sparse.production_item))

func test_queued_role_is_counted_and_only_latest_form_is_selected():
	var rival := _install_world(1)[0]
	_learn_branch(rival, "doctrine", "guardian", 7)
	var cities: Array[City] = []
	for pair in [[Vector2i.ZERO, "A"], [Vector2i(6, 0), "B"], [Vector2i(-6, 0), "C"]]:
		var city := grid.found_city(pair[0], rival, pair[1], true)
		city.buildings["v2_building_guardian_hall"] = true
		cities.append(city)
	for coord in [Vector2i(2, 0), Vector2i(2, -1), Vector2i(-2, 0), Vector2i(-2, 1)]:
		_spawn(rival, "v2_unit_shieldbearer", coord)
	V2StrategicAI.plan_turn(rival, grid)
	var queued := cities.filter(func(c): return c.production_item == "v2_unit_sentinel")
	assert_eq(queued.size(), 1, "the first queue fills the one missing role and later cities see it")
	for city in cities:
		assert_ne(city.production_item, "v2_unit_shieldbearer")
		assert_ne(city.production_item, "v2_unit_guardian")

func test_hard_force_cap_stops_unit_spam_without_deleting_existing_units():
	var rival := _install_world(1)[0]
	var city := grid.found_city(Vector2i.ZERO, rival, "Cap", true)
	_learn_branch(rival, "doctrine", "guardian", 7)
	city.buildings["v2_building_guardian_hall"] = true
	var coords := HexMetrics.coords_within(Vector2i.ZERO, 8)
	var spawned := 0
	for coord in coords:
		if coord == city.coord or coord in city.owned_tiles:
			continue
		_spawn(rival, "v2_unit_sentinel", coord)
		spawned += 1
		if spawned >= V2AITuning.HARD_TOKEN_CAP:
			break
	assert_eq(V2StrategicAI.relevant_unit_count(rival), V2AITuning.HARD_TOKEN_CAP)
	V2StrategicAI.plan_turn(rival, grid)
	assert_eq(city.production_item, "")
	assert_eq(V2StrategicAI.relevant_unit_count(rival), V2AITuning.HARD_TOKEN_CAP)

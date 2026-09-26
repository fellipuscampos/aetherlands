extends GutTest

## Fase 24: smoke determinístico do pipeline real. Fase 25: também confere, a cada turno, que nenhum
## prédio/item/tropa V1 aparece e que o save intermediário não grava campos V1. Execução isolada:
## -gconfig= -gtest=res://test/integration/test_v2_ai_long_run.gd
## Fase 26: as quatro raças reais participam da mesma partida; registra métricas por raça sem
## alterar decisões/tuning da IA e prova que o perfil continua derivável depois do save/load.

const SAVE_PATH := "user://test_v2_ai_long_run.json"
const RUN_TURNS := 150

var original := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "debug_mode"]:
		original[key] = GameManager.get(key)
	original["turn"] = TurnManager.turn_number
	original["player_index"] = TurnManager.current_player_index
	original["events"] = WorldEventManager.active_events.duplicate()
	original["event_id"] = WorldEventManager._next_event_id
	GameManager.players = []
	GameManager.rival_players = []
	GameManager.human_player = null
	GameManager.hex_grid = null
	GameManager.stagger_ai_turns = false
	GameManager.debug_mode = false
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0
	SaveManager.delete_save(SAVE_PATH)

func after_each():
	SaveManager.delete_save(SAVE_PATH)
	V2AITacticalAI.clear_views()
	GameManager.end_match()
	for key in original:
		if key not in ["turn", "player_index", "events", "event_id"]:
			GameManager.set(key, original[key])
	TurnManager.turn_number = original.turn
	TurnManager.current_player_index = original.player_index
	WorldEventManager.active_events.assign(original.events)
	WorldEventManager._next_event_id = original.event_id

func test_three_v2_rivals_run_150_real_turns_with_midgame_save_load():
	var grid := HexGrid.new()
	add_child(grid)
	GameManager.map_width = 61
	GameManager.map_height = 61
	GameManager.rival_count = 3
	GameManager.human_race = "human"
	grid.generate_map(61, 61, 24024)
	GameManager.start_new_game(grid)
	# O humano permanece passivo exatamente como no smoke original; por isso suas métricas
	# econômicas controladas pertencem aos testes unitários da Fase 26, não a este long-run.
	var expected_races: Array[String] = ["human", "elf", "dwarf", "orc"]
	var actual_races: Array[String] = []
	for player in GameManager.players:
		actual_races.append(player.civ.race)
	actual_races.sort()
	expected_races.sort()
	assert_eq(actual_races, expected_races, "uma partida cobre exatamente o roster racial real")

	var orientations := GameManager.rival_players.map(func(p): return p.v2_ai_strategy.orientation)
	orientations.sort()
	assert_eq(orientations, [V2AIStrategyState.Orientation.MILITARY, V2AIStrategyState.Orientation.ARCANE, V2AIStrategyState.Orientation.BALANCED])
	var ever_trees: Dictionary = {}
	var ever_v2_building := false
	var ever_city_level_two := false
	var ever_military := false
	var ever_magic := false
	var ever_upgrade := false
	var max_tokens := 0
	var before_save_states: Array[Dictionary] = []
	var racial_metrics: Dictionary = {}
	for race_id in expected_races:
		racial_metrics[race_id] = _new_race_metrics()
	var start_ms := Time.get_ticks_msec()

	for step in range(RUN_TURNS):
		if GameManager.state == GameManager.GameState.GAME_OVER:
			break
		TurnManager.end_turn()
		for player in GameManager.players:
			assert_not_null(V2RaceBonusRuntime.profile_for(player), "perfil racial preservado: %s" % player.civ.race)
			_record_race_metrics(racial_metrics[player.civ.race], player)
		for rival in GameManager.rival_players:
			_assert_runtime_invariants(rival)
			max_tokens = maxi(max_tokens, V2StrategicAI.relevant_unit_count(rival))
			for id in rival.v2_research.get_completed_ids():
				var node := V2ResearchDatabase.get_node(id)
				if node != null:
					ever_trees[node.tree_type] = true
			for city in rival.cities:
				ever_city_level_two = ever_city_level_two or city.city_level >= 2
				for building_id in city.buildings:
					ever_v2_building = ever_v2_building or V2ResearchDatabase.is_v2_id(building_id)
			for unit in rival.units:
				var kind := unit.unit_data.visual_kind
				ever_military = ever_military or V2UnitLine.is_line_unit(kind)
				ever_magic = ever_magic or unit.unit_data.is_v2_caster() or V2ManifestationSystem.is_manifestation_kind(kind)
				var node := V2ResearchDatabase.node_for_unlock_id(kind)
				ever_upgrade = ever_upgrade or (node != null and node.tier in [5, 7])
		if step == 59:
			before_save_states.clear()
			for rival in GameManager.rival_players:
				before_save_states.append(rival.v2_ai_strategy.to_dict())
			assert_true(SaveManager.save_game(grid, SAVE_PATH))
			var save_text := FileAccess.get_file_as_string(SAVE_PATH)
			for legacy_key in ["researched_techs", "researched_magic", "current_research", "stored_food", "worked_tiles", "trade_routes", "victory_rules_version"]:
				assert_false(save_text.contains(legacy_key), "save novo sem campo V1: %s" % legacy_key)
			assert_true(SaveManager.load_game(grid, SAVE_PATH))
			assert_eq(GameManager.rival_players.size(), 3)
			var loaded_races: Array[String] = []
			for loaded_player in GameManager.players:
				loaded_races.append(loaded_player.civ.race)
				assert_not_null(V2RaceBonusRuntime.profile_for(loaded_player))
			loaded_races.sort()
			assert_eq(loaded_races, expected_races, "race id e perfil sobrevivem ao save intermediário")
			for i in range(3):
				var loaded_state := GameManager.rival_players[i].v2_ai_strategy.to_dict()
				var expected_state := before_save_states[i].duplicate(true)
				var loaded_pressure: Dictionary = loaded_state.get("pressure_by_role_or_trait", {})
				var expected_pressure: Dictionary = expected_state.get("pressure_by_role_or_trait", {})
				loaded_state.erase("pressure_by_role_or_trait")
				expected_state.erase("pressure_by_role_or_trait")
				assert_eq(loaded_state, expected_state, "identidade e memória discreta persistem no save intermediário")
				assert_eq(loaded_pressure.keys(), expected_pressure.keys())
				for pressure_key in expected_pressure:
					assert_almost_eq(float(loaded_pressure[pressure_key]), float(expected_pressure[pressure_key]), 0.000001, "pressão serializada preserva precisão útil")
		if step % 10 == 9:
			await get_tree().process_frame

	assert_gte(TurnManager.turn_number, 101, "o smoke deve cobrir pelo menos 100 rodadas salvo game over legítimo")
	assert_gt(ever_trees.size(), 1, "mais de uma árvore V2 foi usada")
	assert_true(ever_v2_building, "algum prédio V2 real foi construído")
	assert_true(ever_city_level_two, "alguma cidade economicamente pronta saiu de Cidade I")
	assert_true(ever_military, "conteúdo militar V2 entrou em jogo")
	assert_true(ever_magic, "conteúdo mágico V2 entrou em jogo")
	assert_true(ever_upgrade, "uma forma evoluída foi produzida ou preservada")
	assert_lte(max_tokens, V2AITuning.HARD_TOKEN_CAP, "hard strategic stop respeitado")
	var finalized_metrics := _finalize_race_metrics(racial_metrics)
	print("[v2-race-long-run] %s" % JSON.stringify(finalized_metrics))
	print("[v2-ai-long-run] turns=%d elapsed_ms=%d max_tokens=%d trees=%s buildings=%s city2=%s military=%s magic=%s upgrade=%s snapshot=%s" % [
		TurnManager.turn_number, Time.get_ticks_msec() - start_ms, max_tokens, ever_trees.keys(), ever_v2_building,
		ever_city_level_two, ever_military, ever_magic, ever_upgrade, _snapshot()])
	grid.queue_free()
	await get_tree().process_frame

func _new_race_metrics() -> Dictionary:
	return {
		"samples": 0,
		"gold_stock_sum": 0.0,
		"gold_income_sum": 0.0,
		"supply_capacity_sum": 0.0,
		"production_per_city_sum": 0.0,
		"knowledge_income_sum": 0.0,
		"mana_income_sum": 0.0,
		"city_level_sum": 0.0,
		"city_samples": 0,
		"seen_units": {},
		"first_n9": -1,
		"first_capstone": -1,
		"manifestation": false,
		"legendary": false,
		"gold_end": 0.0,
		"units_end": 0,
	}

func _record_race_metrics(metric: Dictionary, player: PlayerData) -> void:
	metric.samples += 1
	metric.gold_stock_sum += player.gold
	metric.gold_income_sum += V2EconomyRuntime.player_gold_net_income(player)
	metric.supply_capacity_sum += V2EconomyRuntime.player_supply_capacity(player)
	metric.knowledge_income_sum += V2EconomyRuntime.player_knowledge_income(player)
	metric.mana_income_sum += V2EconomyRuntime.player_mana_income(player)
	metric.gold_end = player.gold
	metric.units_end = player.units.size()
	for city in player.cities:
		metric.production_per_city_sum += V2EconomyRuntime.city_production_income(city)
		metric.city_level_sum += city.city_level
		metric.city_samples += 1
	for unit in player.units:
		metric.seen_units[unit.serial_id] = true
		metric.manifestation = metric.manifestation or V2ManifestationSystem.is_manifestation_kind(unit.unit_data.visual_kind)
		metric.legendary = metric.legendary or V2LegendarySystem.is_legendary_unit(unit)
	for id in player.v2_research.get_completed_ids():
		var node := V2ResearchDatabase.get_node(id)
		if node == null:
			continue
		if node.tier == 9 and metric.first_n9 < 0:
			metric.first_n9 = TurnManager.turn_number
		if node.is_universal and metric.first_capstone < 0:
			metric.first_capstone = TurnManager.turn_number

func _finalize_race_metrics(metrics: Dictionary) -> Dictionary:
	var result := {}
	for race_id in metrics:
		var metric: Dictionary = metrics[race_id]
		var samples: float = maxf(float(metric.samples), 1.0)
		var city_samples: float = maxf(float(metric.city_samples), 1.0)
		result[race_id] = {
			"gold_end": snappedf(metric.gold_end, 0.01),
			"gold_stock_average": snappedf(metric.gold_stock_sum / samples, 0.01),
			"gold_net_income_average": snappedf(metric.gold_income_sum / samples, 0.01),
			"supply_capacity_average": snappedf(metric.supply_capacity_sum / samples, 0.01),
			"production_per_city_average": snappedf(metric.production_per_city_sum / city_samples, 0.01),
			"knowledge_per_turn_average": snappedf(metric.knowledge_income_sum / samples, 0.01),
			"mana_per_turn_average": snappedf(metric.mana_income_sum / samples, 0.01),
			"city_level_average": snappedf(metric.city_level_sum / city_samples, 0.01),
			"units_observed": metric.seen_units.size(),
			"units_end": metric.units_end,
			"first_n9_turn": metric.first_n9,
			"first_capstone_turn": metric.first_capstone,
			"manifestation_observed": metric.manifestation,
			"legendary_observed": metric.legendary,
		}
	return result

func _assert_runtime_invariants(player: PlayerData) -> void:
	assert_true(is_finite(player.gold) and player.gold >= 0.0, "Ouro nunca negativo/NaN")
	assert_true(is_finite(player.mana) and player.mana >= 0.0, "Mana nunca negativa/NaN")
	var used := V2LogisticsRuntime.player_supply_used(player)
	var capacity := V2EconomyRuntime.player_supply_capacity(player)
	assert_true(is_finite(used) and used >= 0.0 and is_finite(capacity) and capacity >= 0.0, "Suprimentos coerentes")
	assert_lte(V2StrategicAI.relevant_unit_count(player), V2AITuning.HARD_TOKEN_CAP)
	var serials: Dictionary = {}
	for unit in player.units:
		assert_false(serials.has(unit.serial_id), "serial de unidade não duplica")
		serials[unit.serial_id] = true
	for city in player.cities:
		if city.production_item != "":
			assert_gt(city.production_cost(), 0.0, "fila ativa sempre aponta para item real")
		# Fase 25: nenhum prédio/item de produção V1 aparece em nenhum turno.
		assert_true(SaveManager._is_valid_production_item(city.production_item), "item de produção V1: %s" % city.production_item)
		for building_id in city.buildings:
			assert_not_null(BuildingDatabase.get_building(building_id), "prédio V1: %s" % building_id)
	for unit in player.units:
		var kind := unit.unit_data.visual_kind
		assert_true(kind == "warrior" or kind in UnitDatabase.PLAYER_TRAINABLE_KINDS or V2ResearchDatabase.is_v2_id(kind), "tropa V1 produzida: %s" % kind)

func _snapshot() -> String:
	var result := []
	for player in GameManager.rival_players:
		var research_by_tree := {"military": 0, "magic": 0, "infrastructure": 0}
		for id in player.v2_research.get_completed_ids():
			var node := V2ResearchDatabase.get_node(id)
			if node == null:
				continue
			var key: String = ["military", "magic", "infrastructure"][node.tree_type]
			research_by_tree[key] += 1
		var building_ids: Dictionary = {}
		for city in player.cities:
			for id in city.buildings:
				if V2ResearchDatabase.is_v2_id(id):
					building_ids[id] = int(building_ids.get(id, 0)) + 1
		result.append({
			"race": player.civ.race,
			"orientation": V2AIStrategyState.orientation_name(player.v2_ai_strategy.orientation),
			"focus": V2AIStrategyState.focus_name(player.v2_ai_strategy.victory_focus),
			"cities": player.cities.size(),
			"units": player.units.size(),
			"research": player.v2_research.get_completed_ids().size(),
			"research_by_tree": research_by_tree,
			"v2_buildings": building_ids,
			"gold": player.gold,
			"mana": player.mana,
			"city_state": player.cities.map(func(c): return {"level": c.city_level, "slots": c.used_building_slots(), "production": c.production_item}),
		})
	return JSON.stringify(result)

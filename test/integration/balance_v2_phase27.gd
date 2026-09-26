extends GutTest

## Fase 27 -- laboratorio de balanceamento, deliberadamente fora da descoberta normal
## do GUT (o arquivo nao comeca com `test_`). Execute isoladamente:
##   -gconfig= -gtest=res://test/integration/balance_v2_phase27.gd
##
## O laboratorio usa o pipeline real de turno/IA e imprime JSON reproduzivel. Nao
## existe telemetria no runtime normal e nenhum resultado estatistico e contrato de
## teste; somente invariantes de integridade podem falhar a execucao.

const SEEDS: Array[int] = [27001, 27002, 27003, 27004, 27005, 27006, 27007, 27008, 27009, 27010, 27011, 27012]
const MAP_SIZE := 61
const RIVAL_COUNT := 3
const MAX_TURNS := 200
const SAVE_STEP := 99
const SAVE_SEEDS: Array[int] = [27001, 27007]
const SAVE_PATH := "user://balance_v2_phase27_midrun.json"

var _original := {}
var _victory_event := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "debug_mode"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.player_index = TurnManager.current_player_index
	_original.events = WorldEventManager.active_events.duplicate()
	_original.event_id = WorldEventManager._next_event_id
	GameManager.players = []
	GameManager.rival_players = []
	GameManager.human_player = null
	GameManager.hex_grid = null
	GameManager.stagger_ai_turns = false
	GameManager.debug_mode = false
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0
	SaveManager.delete_save(SAVE_PATH)
	if not EventBus.victory_achieved.is_connected(_on_victory_achieved):
		EventBus.victory_achieved.connect(_on_victory_achieved)

func after_each():
	SaveManager.delete_save(SAVE_PATH)
	if EventBus.victory_achieved.is_connected(_on_victory_achieved):
		EventBus.victory_achieved.disconnect(_on_victory_achieved)
	V2AITacticalAI.clear_views()
	GameManager.end_match()
	for key in _original:
		if key not in ["turn", "player_index", "events", "event_id"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	TurnManager.current_player_index = _original.player_index
	WorldEventManager.active_events.assign(_original.events)
	WorldEventManager._next_event_id = _original.event_id

func test_phase27_controlled_micro_report():
	var cumulative: Array[float] = []
	var running := 0.0
	for cost in V2ResearchDatabase.BRANCH_TIER_COSTS:
		running += cost
		cumulative.append(running)
	var research := []
	for race in ["human", "elf"]:
		var knowledge_multiplier: float = V2RaceBonusDatabase.get_profile(race).knowledge_income_multiplier
		for cities in [1, 2, 3]:
			for academy_tier in [0, 1, 2, 3]:
				var academy_yield := 0.0 if academy_tier == 0 else V2InfrastructureEconomyData.yield_per_copy("v2_building_academy", academy_tier)
				var per_turn: float = cities * (V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY + academy_yield) * knowledge_multiplier
				research.append({
					"race": race, "cities": cities, "academy_tier": academy_tier,
					"knowledge_per_turn": snappedf(per_turn, 0.01),
					"turns_n3": int(ceil(cumulative[2] / per_turn)),
					"turns_n5": int(ceil(cumulative[4] / per_turn)),
					"turns_n7": int(ceil(cumulative[6] / per_turn)),
					"turns_n9": int(ceil(cumulative[8] / per_turn)),
					"turns_two_n9_capstone": int(ceil((cumulative[8] * 2.0 + V2ResearchDatabase.CAPSTONE_COST) / per_turn)),
				})
	var production_items := {
		"builder": UnitDatabase.create_unit("v2_unit_builder").production_cost,
		"n3": UnitDatabase.create_unit("v2_unit_shieldbearer").production_cost,
		"n5": UnitDatabase.create_unit("v2_unit_guardian").production_cost,
		"n7": UnitDatabase.create_unit("v2_unit_sentinel").production_cost,
		"n2_building": BuildingDatabase.get_building("v2_building_guardian_hall").production_cost,
		"n8_building": BuildingDatabase.get_building("v2_building_guardian_mastery").production_cost,
		"city_ii": V2CityLevelData.upgrade_production_cost(2),
		"fortification_i": V2FortificationData.production_cost(1),
		"manifestation": UnitDatabase.create_unit("v2_manifestation_seraph").production_cost,
	}
	var production := []
	for race in ["human", "dwarf"]:
		var multiplier: float = V2RaceBonusDatabase.get_profile(race).city_production_multiplier
		for workshop_tier in [0, 1, 2, 3]:
			var workshop_yield := 0.0 if workshop_tier == 0 else V2InfrastructureEconomyData.yield_per_copy("v2_building_workshop", workshop_tier)
			var per_turn: float = (V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY + workshop_yield) * multiplier
			var turns := {}
			for item in production_items:
				turns[item] = int(ceil(float(production_items[item]) / per_turn))
			production.append({"race": race, "workshop_tier": workshop_tier, "production_per_turn": snappedf(per_turn, 0.01), "turns": turns})
	var supply := []
	for race in ["human", "orc"]:
		var multiplier: float = V2RaceBonusDatabase.get_profile(race).supply_capacity_multiplier
		for farm_tier in [0, 1, 2, 3]:
			var farm_yield := 0.0 if farm_tier == 0 else V2InfrastructureEconomyData.yield_per_copy("v2_building_farm", farm_tier)
			supply.append({"race": race, "farm_tier": farm_tier, "capacity": snappedf((V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + farm_yield) * multiplier, 0.01)})
	var spells := []
	for spell in V2SpellDatabase.all_spells():
		spells.append({"id": spell.id, "school": spell.school_branch, "mana": spell.mana_cost, "cooldown": spell.cooldown_turns, "damage": spell.damage_amount, "heal": spell.heal_amount, "full_heal": spell.heal_to_full})
	var techniques := []
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		techniques.append({"id": technique.id, "branch": technique.doctrine_branch, "cooldown": technique.cooldown_turns, "strike": technique.strike_multiplier, "passive_attack": technique.basic_attack_bonus, "city_attack": technique.city_attack_bonus})
	print("[v2-balance-controlled] %s" % JSON.stringify({
		"research_cumulative": cumulative,
		"research": research,
		"production": production,
		"supply": supply,
		"gold_one_city": {"base": V2InfrastructureEconomyData.BASE_GOLD_PER_CITY, "market_tiers": V2InfrastructureEconomyData.entry_for_branch("economy").yields},
		"city_hp": V2CityLevelData.MAX_HP_BY_LEVEL,
		"fortifications": V2FortificationData.LEVELS,
		"spells": spells,
		"techniques": techniques,
	}))
	assert_eq(spells.size(), 24)
	assert_eq(techniques.size(), 12)

func test_phase27_multi_seed_balance_report():
	var started_ms := Time.get_ticks_msec()
	var all_rows: Array[Dictionary] = []
	for seed in SEEDS:
		var rows := await _run_seed(seed)
		all_rows.append_array(rows)
	var report := {
		"phase": 27,
		"seeds": SEEDS,
		"map": "%dx%d" % [MAP_SIZE, MAP_SIZE],
		"rivals": RIVAL_COUNT,
		"max_turn": MAX_TURNS,
		"save_load_seeds": SAVE_SEEDS,
		"runs": all_rows,
		"aggregate_by_race": _aggregate(all_rows, "race"),
		"aggregate_by_orientation": _aggregate(all_rows, "orientation"),
		"elapsed_ms": Time.get_ticks_msec() - started_ms,
	}
	var summary_report := report.duplicate()
	summary_report.erase("runs") # Each observation is printed above; keep the aggregate readable in CI logs.
	print("[v2-balance-phase27] %s" % JSON.stringify(summary_report))
	assert_eq(all_rows.size(), SEEDS.size() * RIVAL_COUNT)
	_assert_coverage(all_rows)

func _run_seed(seed: int) -> Array[Dictionary]:
	_victory_event.clear()
	var grid := HexGrid.new()
	add_child(grid)
	GameManager.map_width = MAP_SIZE
	GameManager.map_height = MAP_SIZE
	GameManager.rival_count = RIVAL_COUNT
	GameManager.human_race = "human"
	grid.generate_map(MAP_SIZE, MAP_SIZE, seed)
	GameManager.start_new_game(grid)

	var metrics := {}
	for player in GameManager.rival_players:
		metrics[player.civ.race] = _new_metric(player)
	var saved := false
	for step in range(MAX_TURNS):
		if GameManager.state == GameManager.GameState.GAME_OVER:
			break
		TurnManager.end_turn()
		for player in GameManager.rival_players:
			_assert_runtime_invariants(player)
			_record_metric(metrics[player.civ.race], player)
		if seed in SAVE_SEEDS and step == SAVE_STEP:
			var structural_before := _structural_snapshot()
			assert_true(SaveManager.save_game(grid, SAVE_PATH), "save intermediario da seed %d" % seed)
			assert_true(SaveManager.load_game(grid, SAVE_PATH), "load intermediario da seed %d" % seed)
			assert_eq(_structural_snapshot(), structural_before, "estado estrutural sobrevive ao save/load")
			saved = true
		if step % 20 == 19:
			await get_tree().process_frame

	var rows: Array[Dictionary] = []
	for player in GameManager.rival_players:
		var metric: Dictionary = metrics[player.civ.race]
		var row := _finalize_metric(seed, metric, player, saved)
		rows.append(row)
		print("[v2-balance-run] %s" % JSON.stringify(row))
	GameManager.end_match()
	grid.queue_free()
	await get_tree().process_frame
	return rows

func _new_metric(player: PlayerData) -> Dictionary:
	return {
		"race": player.civ.race,
		"orientation": V2AIStrategyState.orientation_name(player.v2_ai_strategy.orientation),
		"focus": V2AIStrategyState.focus_name(player.v2_ai_strategy.victory_focus),
		"samples": 0,
		"gold_gross_sum": 0.0,
		"gold_upkeep_sum": 0.0,
		"gold_net_sum": 0.0,
		"production_sum": 0.0,
		"city_samples": 0,
		"knowledge_sum": 0.0,
		"mana_sum": 0.0,
		"deficit_turns": 0,
		"max_relevant_tokens": 0,
		"first_n3": -1,
		"first_n5": -1,
		"first_n7": -1,
		"first_n9": -1,
		"second_n9": -1,
		"first_capstone": -1,
		"first_city_2": -1,
		"first_city_3": -1,
		"first_legendary": -1,
		"first_manifestation": -1,
		"ritual_started": 0,
		"ritual_interrupted": 0,
		"ritual_was_active": false,
		"war_turns": 0,
		"max_captures": 0,
	}

func _record_metric(metric: Dictionary, player: PlayerData) -> void:
	metric.samples += 1
	var gross := V2EconomyRuntime.player_gold_gross_income(player)
	var upkeep := V2EconomyRuntime.player_gold_upkeep(player)
	var net := gross - upkeep
	metric.gold_gross_sum += gross
	metric.gold_upkeep_sum += upkeep
	metric.gold_net_sum += net
	metric.knowledge_sum += V2EconomyRuntime.player_knowledge_income(player)
	metric.mana_sum += V2EconomyRuntime.player_mana_income(player)
	metric.deficit_turns += 1 if net < 0.0 else 0
	metric.max_relevant_tokens = maxi(metric.max_relevant_tokens, V2StrategicAI.relevant_unit_count(player))
	metric.war_turns += 1 if not player.enemies.is_empty() else 0
	var captures := 0
	for city in player.cities:
		metric.production_sum += V2EconomyRuntime.city_production_income(city)
		metric.city_samples += 1
		captures += 1 if city.v2_supremacy_captured_from >= 0 else 0
		if city.city_level >= 2 and metric.first_city_2 < 0:
			metric.first_city_2 = TurnManager.turn_number
		if city.city_level >= 3 and metric.first_city_3 < 0:
			metric.first_city_3 = TurnManager.turn_number
	metric.max_captures = maxi(metric.max_captures, captures)

	var n9_branches := {}
	for id in player.v2_research.get_completed_ids():
		var node := V2ResearchDatabase.get_node(id)
		if node == null:
			continue
		if node.tier >= 3 and metric.first_n3 < 0:
			metric.first_n3 = TurnManager.turn_number
		if node.tier >= 5 and metric.first_n5 < 0:
			metric.first_n5 = TurnManager.turn_number
		if node.tier >= 7 and metric.first_n7 < 0:
			metric.first_n7 = TurnManager.turn_number
		if node.tier == 9:
			n9_branches["%d:%s" % [node.tree_type, node.branch]] = true
			if metric.first_n9 < 0:
				metric.first_n9 = TurnManager.turn_number
		if node.is_universal and metric.first_capstone < 0:
			metric.first_capstone = TurnManager.turn_number
	if n9_branches.size() >= 2 and metric.second_n9 < 0:
		metric.second_n9 = TurnManager.turn_number

	for unit in player.units:
		if metric.first_legendary < 0 and V2LegendarySystem.is_legendary_unit(unit):
			metric.first_legendary = TurnManager.turn_number
		if metric.first_manifestation < 0 and V2ManifestationSystem.is_manifestation_kind(unit.unit_data.visual_kind):
			metric.first_manifestation = TurnManager.turn_number
	var ritual_active := V2TranscendenceSystem.has_active_ritual(player)
	if ritual_active and not metric.ritual_was_active:
		metric.ritual_started += 1
	elif not ritual_active and metric.ritual_was_active and not _victory_event.is_empty():
		metric.ritual_interrupted += 0
	elif not ritual_active and metric.ritual_was_active:
		metric.ritual_interrupted += 1
	metric.ritual_was_active = ritual_active

func _finalize_metric(seed: int, metric: Dictionary, player: PlayerData, saved: bool) -> Dictionary:
	var samples := maxf(float(metric.samples), 1.0)
	var city_samples := maxf(float(metric.city_samples), 1.0)
	var research_by_tree := {"military": 0, "magic": 0, "infrastructure": 0}
	var max_tier_by_tree := {"military": 0, "magic": 0, "infrastructure": 0}
	for id in player.v2_research.get_completed_ids():
		var node := V2ResearchDatabase.get_node(id)
		if node == null:
			continue
		var key: String = ["military", "magic", "infrastructure"][node.tree_type]
		research_by_tree[key] += 1
		max_tier_by_tree[key] = maxi(max_tier_by_tree[key], node.tier)
	var city_levels := {"I": 0, "II": 0, "III": 0, "IV": 0}
	for city in player.cities:
		city_levels[["I", "II", "III", "IV"][clampi(city.city_level - 1, 0, 3)]] += 1
	var roles := {}
	var upgrades := 0
	var legendary := 0
	var manifestation := 0
	for unit in player.units:
		var kind := unit.unit_data.visual_kind
		var branch := V2UnitLine.doctrine_branch_of(kind)
		var role := branch if branch != "" else ("caster" if unit.unit_data.is_v2_caster() else "other")
		if V2ManifestationSystem.is_manifestation_kind(kind):
			role = "manifestation"
		roles[role] = int(roles.get(role, 0)) + 1
		var node := V2ResearchDatabase.node_for_unlock_id(kind)
		upgrades += 1 if node != null and node.tier in [5, 7] else 0
		legendary += 1 if V2LegendarySystem.is_legendary_unit(unit) else 0
		manifestation += 1 if V2ManifestationSystem.is_manifestation_kind(kind) else 0
	var victory := _victory_event if int(_victory_event.get("winner_id", -1)) == V2VictoryConditions.stable_id(player) else {}
	return {
		"seed": seed,
		"race": metric.race,
		"orientation": metric.orientation,
		"focus": metric.focus,
		"turns": TurnManager.turn_number,
		"save_load": saved,
		"cities": player.cities.size(),
		"city_levels": city_levels,
		"gold_gross_avg": snappedf(metric.gold_gross_sum / samples, 0.01),
		"gold_upkeep_avg": snappedf(metric.gold_upkeep_sum / samples, 0.01),
		"gold_net_avg": snappedf(metric.gold_net_sum / samples, 0.01),
		"gold_stock": snappedf(player.gold, 0.01),
		"deficit_turn_pct": snappedf(100.0 * metric.deficit_turns / samples, 0.01),
		"supply_capacity": snappedf(V2EconomyRuntime.player_supply_capacity(player), 0.01),
		"supply_used": snappedf(V2LogisticsRuntime.player_supply_used(player), 0.01),
		"production_per_city_avg": snappedf(metric.production_sum / city_samples, 0.01),
		"knowledge_avg": snappedf(metric.knowledge_sum / samples, 0.01),
		"mana_avg": snappedf(metric.mana_sum / samples, 0.01),
		"mana_stock": snappedf(player.mana, 0.01),
		"research_completed": player.v2_research.get_completed_ids().size(),
		"research_by_tree": research_by_tree,
		"max_tier_by_tree": max_tier_by_tree,
		"unit_roles": roles,
		"relevant_tokens": V2StrategicAI.relevant_unit_count(player),
		"max_relevant_tokens": metric.max_relevant_tokens,
		"upgraded_units": upgrades,
		"legendary_units": legendary,
		"manifestations": manifestation,
		"first_n3": metric.first_n3,
		"first_n5": metric.first_n5,
		"first_n7": metric.first_n7,
		"first_n9": metric.first_n9,
		"second_n9": metric.second_n9,
		"first_capstone": metric.first_capstone,
		"first_city_2": metric.first_city_2,
		"first_city_3": metric.first_city_3,
		"first_legendary": metric.first_legendary,
		"first_manifestation": metric.first_manifestation,
		"war_turns": metric.war_turns,
		"captured_city_peak": metric.max_captures,
		"ritual_started": metric.ritual_started,
		"ritual_interrupted": metric.ritual_interrupted,
		"ritual_active": V2TranscendenceSystem.has_active_ritual(player),
		"victory_type": victory.get("type", ""),
		"victory_turn": victory.get("turn", -1),
	}

func _aggregate(rows: Array[Dictionary], field: String) -> Dictionary:
	var groups := {}
	for row in rows:
		var key: String = str(row[field])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(row)
	var result := {}
	var numeric_fields := ["gold_net_avg", "gold_stock", "deficit_turn_pct", "supply_capacity", "supply_used", "production_per_city_avg", "knowledge_avg", "mana_avg", "research_completed", "relevant_tokens", "max_relevant_tokens", "first_n3", "first_n5", "first_n7", "first_n9", "second_n9", "first_capstone", "first_city_2", "first_city_3", "first_legendary", "first_manifestation", "victory_turn"]
	for key in groups:
		var summary := {"n": groups[key].size()}
		for metric_name in numeric_fields:
			var values: Array[float] = []
			for row in groups[key]:
				var value := float(row[metric_name])
				if value >= 0.0:
					values.append(value)
			summary[metric_name] = _distribution(values)
		result[key] = summary
	return result

func _distribution(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"n": 0, "median": -1, "p25": -1, "p75": -1, "min": -1, "max": -1}
	values.sort()
	return {
		"n": values.size(),
		"median": snappedf(_percentile(values, 0.50), 0.01),
		"p25": snappedf(_percentile(values, 0.25), 0.01),
		"p75": snappedf(_percentile(values, 0.75), 0.01),
		"min": snappedf(values.front(), 0.01),
		"max": snappedf(values.back(), 0.01),
	}

func _percentile(values: Array[float], fraction: float) -> float:
	if values.size() == 1:
		return values[0]
	var position := fraction * float(values.size() - 1)
	var low := int(floor(position))
	var high := int(ceil(position))
	return lerpf(values[low], values[high], position - low)

func _assert_coverage(rows: Array[Dictionary]) -> void:
	for race in ["elf", "dwarf", "orc"]:
		var orientations := {}
		for row in rows:
			if row.race == race:
				orientations[row.orientation] = true
		assert_eq(orientations.size(), 3, "%s aparece nas tres orientacoes" % race)
	for orientation in ["MILITARY", "ARCANE", "BALANCED"]:
		assert_true(rows.any(func(row): return row.orientation == orientation), "cobertura %s" % orientation)

func _assert_runtime_invariants(player: PlayerData) -> void:
	assert_true(is_finite(player.gold) and player.gold >= 0.0, "Ouro nunca negativo/NaN")
	assert_true(is_finite(player.mana) and player.mana >= 0.0, "Mana nunca negativa/NaN")
	var used := V2LogisticsRuntime.player_supply_used(player)
	var capacity := V2EconomyRuntime.player_supply_capacity(player)
	assert_true(is_finite(used) and used >= 0.0 and is_finite(capacity) and capacity >= 0.0, "Suprimentos coerentes")
	assert_lte(V2StrategicAI.relevant_unit_count(player), V2AITuning.HARD_TOKEN_CAP)
	var serials := {}
	for unit in player.units:
		assert_false(serials.has(unit.serial_id), "serial de unidade nao duplica")
		serials[unit.serial_id] = true
	for city in player.cities:
		if city.production_item != "":
			assert_gt(city.production_cost(), 0.0, "fila ativa aponta para item real")

func _structural_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in GameManager.rival_players:
		result.append({
			"race": player.civ.race,
			"orientation": player.v2_ai_strategy.orientation,
			"focus": player.v2_ai_strategy.victory_focus,
			"cities": player.cities.size(),
			"units": player.units.size(),
			"research": player.v2_research.get_completed_ids(),
			"ritual": player.v2_transcendence_ritual.duplicate(true),
		})
	return result

func _on_victory_achieved(winner: PlayerData, victory_type: String) -> void:
	_victory_event = {
		"winner_id": V2VictoryConditions.stable_id(winner),
		"race": winner.civ.race if winner != null else "",
		"type": victory_type,
		"turn": TurnManager.turn_number,
	}

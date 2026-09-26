extends GutTest

## Benchmark reproduzível da Fase 26. Fora da suíte unitária de propósito.
## Mede somente os caminhos realmente usados pelo mapeamento racial escolhido.

const MAP_SIZE := 61

var original := {}
var grid: HexGrid

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "debug_mode"]:
		original[key] = GameManager.get(key)
	original.turn = TurnManager.turn_number
	original.player_index = TurnManager.current_player_index
	original.events = WorldEventManager.active_events.duplicate()
	original.event_id = WorldEventManager._next_event_id
	GameManager.stagger_ai_turns = false
	GameManager.debug_mode = false
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0
	grid = HexGrid.new()
	add_child(grid)
	GameManager.map_width = MAP_SIZE
	GameManager.map_height = MAP_SIZE
	GameManager.rival_count = 3
	GameManager.human_race = "human"
	grid.generate_map(MAP_SIZE, MAP_SIZE, 26026)
	GameManager.start_new_game(grid)
	var settler: Unit = GameManager.human_player.units.filter(func(u): return u.unit_data.can_found_city)[0]
	WorldSetup.found_city_from_settler(grid, settler)

func after_each():
	V2AITacticalAI.clear_views()
	GameManager.end_match()
	for key in original:
		if key not in ["turn", "player_index", "events", "event_id"]:
			GameManager.set(key, original[key])
	TurnManager.turn_number = original.turn
	TurnManager.current_player_index = original.player_index
	WorldEventManager.active_events.assign(original.events)
	WorldEventManager._next_event_id = original.event_id
	if is_instance_valid(grid):
		grid.queue_free()

func _measure_us(label: String, iterations: int, operation: Callable) -> float:
	for i in mini(iterations, 10):
		operation.call()
	var started := Time.get_ticks_usec()
	for i in iterations:
		operation.call()
	var per_call := float(Time.get_ticks_usec() - started) / float(iterations)
	print("PHASE26_BENCH %-48s %10.3f us" % [label, per_call])
	return per_call

func _turn_median_ms(runs: int) -> float:
	var samples: Array[float] = []
	for i in runs:
		var started := Time.get_ticks_usec()
		TurnManager.end_turn()
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	return samples[samples.size() / 2]

func _adjacent_free_land_pair() -> Array[Vector2i]:
	for coord in grid.tiles:
		var tile: HexTileData = grid.get_tile(coord)
		if tile == null or tile.blocks_land_units() or grid.get_unit_at(coord) != null or grid.get_city_at(coord) != null:
			continue
		for neighbor in grid.get_neighbors(coord):
			var other: HexTileData = grid.get_tile(neighbor)
			if other != null and not other.blocks_land_units() and grid.get_unit_at(neighbor) == null and grid.get_city_at(neighbor) == null:
				return [coord, neighbor]
	return [] as Array[Vector2i]

func test_phase26_runtime_economy_combat_and_ui_benchmarks():
	var by_race := {}
	for player in GameManager.players:
		by_race[player.civ.race] = player
	var human: PlayerData = by_race.human
	var elf: PlayerData = by_race.elf
	var dwarf: PlayerData = by_race.dwarf
	var orc: PlayerData = by_race.orc
	var city: City = human.cities[0]

	_measure_us("profile lookup O(1)", 200000, func(): V2RaceBonusRuntime.profile_for(orc))
	_measure_us("Gold modifier", 200000, func(): V2RaceBonusRuntime.gold_income_multiplier(dwarf))
	_measure_us("Supply modifier", 200000, func(): V2RaceBonusRuntime.supply_capacity_multiplier(orc))
	_measure_us("Production modifier", 200000, func(): V2RaceBonusRuntime.city_production_multiplier(dwarf))
	_measure_us("Knowledge modifier", 200000, func(): V2RaceBonusRuntime.knowledge_income_multiplier(elf))
	_measure_us("Mana modifier", 200000, func(): V2RaceBonusRuntime.mana_income_multiplier(elf))
	_measure_us("Builder additive", 200000, func(): V2RaceBonusRuntime.builder_charge_bonus(human))
	_measure_us("Annexation additive", 200000, func(): V2RaceBonusRuntime.annexation_point_bonus(human))
	_measure_us("Combat modifier", 200000, func(): V2RaceBonusRuntime.combat_attack_multiplier(orc.units[0]))
	_measure_us("full player income (Gold)", 50000, func(): V2EconomyRuntime.player_gold_income(dwarf))
	_measure_us("Supply capacity", 50000, func(): V2EconomyRuntime.player_supply_capacity(orc))
	_measure_us("city Production", 50000, func(): V2EconomyRuntime.city_production_income(city))

	var pair := _adjacent_free_land_pair()
	assert_eq(pair.size(), 2)
	Diplomacy.declare_war(orc, human)
	var attacker: Unit = grid.spawn_unit(pair[0], UnitDatabase.create_unit("warrior"), orc)
	var defender: Unit = grid.spawn_unit(pair[1], UnitDatabase.create_unit("warrior"), human)
	_measure_us("CombatResolver.predict (racial attack)", 20000, func(): CombatResolver.predict(attacker, defender, grid))

	var hud: Control = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	_measure_us("HUD refresh with race summary", 500, func(): hud._refresh_stats())
	_measure_us("city panel refresh", 200, func(): hud._on_tile_selected(city.coord, grid.get_tile(city.coord)))
	assert_not_null(V2RaceBonusRuntime.profile_for(human))

func test_phase26_ai_plan_turn_and_long_pipeline_benchmarks():
	# Aquecimento suficiente para os rivais fundarem e a IA entrar no caminho estratégico real.
	for i in 10:
		TurnManager.end_turn()
	var first: PlayerData = GameManager.rival_players[0]
	_measure_us("AI strategic plan / 1 rival", 100, func():
		TurnManager.turn_number += 1
		V2StrategicAI.plan_turn(first, grid))
	_measure_us("AI strategic plan / 3 rivals", 50, func():
		TurnManager.turn_number += 1
		for rival in GameManager.rival_players:
			V2StrategicAI.plan_turn(rival, grid))
	var median := _turn_median_ms(21)
	print("PHASE26_BENCH %-48s %10.3f ms" % ["complete real turn / 3 rivals (median)", median])
	assert_lt(median, 1000.0)
	for rival in GameManager.rival_players:
		assert_lte(V2StrategicAI.relevant_unit_count(rival), V2AITuning.HARD_TOKEN_CAP)

extends GutTest

## Benchmark isolado da Fase 27. Mede os caminhos tocados ou auditados pelo
## balanceamento sem entrar na descoberta normal de test/unit.

const SAVE_PATH := "user://benchmark_v2_phase27.json"
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
	grid.generate_map(MAP_SIZE, MAP_SIZE, 27027)
	GameManager.start_new_game(grid)
	var settler: Unit = GameManager.human_player.units.filter(func(u): return u.unit_data.can_found_city)[0]
	WorldSetup.found_city_from_settler(grid, settler)

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
	if is_instance_valid(grid):
		grid.queue_free()

func _measure_us(label: String, iterations: int, operation: Callable) -> float:
	for i in mini(iterations, 10):
		operation.call()
	var started := Time.get_ticks_usec()
	for i in iterations:
		operation.call()
	var per_call := float(Time.get_ticks_usec() - started) / float(iterations)
	print("PHASE27_BENCH %-52s %10.3f us" % [label, per_call])
	return per_call

func _turn_stats_ms(runs: int) -> Dictionary:
	var samples: Array[float] = []
	for i in runs:
		var started := Time.get_ticks_usec()
		TurnManager.end_turn()
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	return {"median": samples[samples.size() / 2], "max": samples[-1]}

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

func test_phase27_economy_supply_combat_magic_and_save_benchmarks():
	var by_race := {}
	for player in GameManager.players:
		by_race[player.civ.race] = player
	var human: PlayerData = by_race.human
	var dwarf: PlayerData = by_race.dwarf
	var orc: PlayerData = by_race.orc
	var city: City = human.cities[0]

	_measure_us("full player income (Gold)", 50000, func(): V2EconomyRuntime.player_gold_income(dwarf))
	_measure_us("Supply capacity", 50000, func(): V2EconomyRuntime.player_supply_capacity(orc))
	_measure_us("city Production", 50000, func(): V2EconomyRuntime.city_production_income(city))
	_measure_us("research availability", 50000, func(): human.v2_research.is_available("v2_doctrine_guardian_1"))

	var pair := _adjacent_free_land_pair()
	assert_eq(pair.size(), 2)
	Diplomacy.declare_war(orc, human)
	var attacker: Unit = grid.spawn_unit(pair[0], UnitDatabase.create_unit("warrior"), orc)
	var defender: Unit = grid.spawn_unit(pair[1], UnitDatabase.create_unit("warrior"), human)
	_measure_us("CombatResolver.predict", 20000, func(): CombatResolver.predict(attacker, defender, grid))

	var spell_ids: Array[String] = []
	for spell in V2SpellDatabase.all_spells():
		spell_ids.append(spell.id)
	var probe: Unit = human.units[0]
	_measure_us("magic validation / 24 spells", 5000, func():
		for spell_id in spell_ids:
			V2MagicRuntime.unavailable_reason(probe, spell_id, grid))
	assert_eq(spell_ids.size(), 24)

	for i in 20:
		TurnManager.end_turn()
	var save_us := _measure_us("save_game / 3 rivals", 5, func(): SaveManager.save_game(grid, SAVE_PATH))
	var load_us := _measure_us("load_game / 3 rivals", 3, func(): SaveManager.load_game(grid, SAVE_PATH))
	assert_lt(save_us, 1000000.0)
	assert_lt(load_us, 5000000.0)

func test_phase27_ai_plan_and_complete_turn_benchmarks():
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
	var stats := _turn_stats_ms(21)
	print("PHASE27_BENCH %-52s median=%8.3f ms max=%8.3f ms" % ["complete real turn / 3 rivals", stats.median, stats.max])
	assert_lt(float(stats.max), 1000.0)
	for rival in GameManager.rival_players:
		assert_lte(V2StrategicAI.relevant_unit_count(rival), V2AITuning.HARD_TOKEN_CAP)

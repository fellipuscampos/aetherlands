extends GutTest

## Benchmark reproduzível da Fase 25 (migração V1→V2). Fora de test/unit de propósito.
## Execução isolada: -gconfig= -gtest=res://test/integration/benchmark_v2_phase25.gd
## Mede o custo do caminho ativo depois da remoção da V1: turno real (humano sozinho, 1 e 3 rivais),
## refresh da HUD, painel de cidade, quadro de pesquisa, save e load.

const SAVE_PATH := "user://benchmark_v2_phase25.json"
const MAP_SIZE := 61

var original := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "debug_mode"]:
		original[key] = GameManager.get(key)
	original["turn"] = TurnManager.turn_number
	original["player_index"] = TurnManager.current_player_index
	original["events"] = WorldEventManager.active_events.duplicate()
	original["event_id"] = WorldEventManager._next_event_id
	GameManager.stagger_ai_turns = false
	GameManager.debug_mode = false
	WorldEventManager.active_events.clear()

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

func _new_game(rivals: int) -> HexGrid:
	var grid := HexGrid.new()
	add_child(grid)
	GameManager.map_width = MAP_SIZE
	GameManager.map_height = MAP_SIZE
	GameManager.rival_count = rivals
	GameManager.human_race = "human"
	grid.generate_map(MAP_SIZE, MAP_SIZE, 25025)
	GameManager.start_new_game(grid)
	var settler: Unit = GameManager.human_player.units.filter(func(u): return u.unit_data.can_found_city)[0]
	WorldSetup.found_city_from_settler(grid, settler)
	return grid

## Mediana de `runs` turnos reais (TurnManager.end_turn -> pipeline completo de GameManager).
func _turn_median_ms(runs: int) -> float:
	var samples: Array[float] = []
	for i in runs:
		var started := Time.get_ticks_usec()
		TurnManager.end_turn()
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	return samples[samples.size() / 2]

func _measure_us(label: String, iterations: int, operation: Callable) -> float:
	for i in mini(iterations, 5):
		operation.call()
	var started := Time.get_ticks_usec()
	for i in iterations:
		operation.call()
	var per_call := float(Time.get_ticks_usec() - started) / float(iterations)
	print("PHASE25_BENCH %-44s %10.3f us" % [label, per_call])
	return per_call

func test_phase25_turn_benchmarks():
	for rivals in [0, 1, 3]:
		var grid := _new_game(rivals)
		_turn_median_ms(5) # aquecimento: primeiros turnos (fundação, primeiras filas)
		var median := _turn_median_ms(21)
		print("PHASE25_BENCH %-44s %10.3f ms" % ["turno real (mediana) / %d rival(is)" % rivals, median])
		assert_lt(median, 1000.0)
		GameManager.end_match()
		grid.queue_free()
		await get_tree().process_frame

func test_phase25_ui_and_save_benchmarks():
	var grid := _new_game(3)
	for i in 30:
		TurnManager.end_turn()
	var hud: Control = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	var city: City = GameManager.human_player.cities[0]
	_measure_us("HUD refresh (_refresh_stats)", 200, func(): hud._refresh_stats())
	_measure_us("painel de cidade (_on_tile_selected)", 100, func(): hud._on_tile_selected(city.coord, grid.get_tile(city.coord)))
	_measure_us("quadro de pesquisa (abrir + fechar)", 50, func():
		hud._on_research_pressed()
		hud.close_topmost_overlay())
	var save_us := _measure_us("save_game (3 rivais, turno 36)", 10, func(): SaveManager.save_game(grid, SAVE_PATH))
	var load_us := _measure_us("load_game (3 rivais, turno 36)", 5, func(): SaveManager.load_game(grid, SAVE_PATH))
	assert_lt(save_us, 1000000.0)
	assert_lt(load_us, 5000000.0)
	GameManager.end_match()
	grid.queue_free()
	await get_tree().process_frame

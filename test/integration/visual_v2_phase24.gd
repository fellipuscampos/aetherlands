extends Node

## Validação visual da Fase 24: Main.tscn real, três rivais, pipeline real de
## turnos e uma captura do estado produzido pela IA (sem recursos/debug).

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const VISUAL_TURNS := 60

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("VISUAL_OK: ", message)
	else:
		failures.append(message)
		push_error("VISUAL_FAIL: " + message)

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png("user://" + file_name) == OK, "captura %s (%dx%d)" % [file_name, image.get_width(), image.get_height()])

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1017))
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: HexGrid = main.get_node("HexGrid")
	var hud = main.get_node("UILayer/HUD")
	main.get_node("UILayer/TitleScreen").visible = false
	main.get_node("UILayer/GameSetupScreen").visible = false
	hud.visible = true
	GameManager.map_width = 61
	GameManager.map_height = 61
	GameManager.rival_count = 3
	GameManager.human_race = "human"
	GameManager.debug_mode = false
	GameManager.stagger_ai_turns = false
	ProjectSettings.set_setting("debug/ai_v2_log", true)
	grid.generate_map(61, 61, 24024)
	GameManager.start_new_game(grid)
	var orientations := GameManager.rival_players.map(func(p): return p.v2_ai_strategy.orientation)
	orientations.sort()
	_check(orientations == [V2AIStrategyState.Orientation.MILITARY, V2AIStrategyState.Orientation.ARCANE, V2AIStrategyState.Orientation.BALANCED], "orientações determinísticas MILITARY/ARCANE/BALANCED")
	for turn in VISUAL_TURNS:
		if GameManager.state == GameManager.GameState.GAME_OVER:
			break
		TurnManager.end_turn()
		if turn % 10 == 9:
			await get_tree().process_frame
	var any_research := false
	var any_v2_building := false
	var max_units := 0
	for rival in GameManager.rival_players:
		any_research = any_research or not rival.v2_research.get_completed_ids().is_empty()
		max_units = maxi(max_units, V2StrategicAI.relevant_unit_count(rival))
		for city in rival.cities:
			for id in city.buildings:
				any_v2_building = any_v2_building or V2ResearchDatabase.is_v2_id(id)
		print("VISUAL_AI_SNAPSHOT: ", rival.civ.civ_name, " ", JSON.stringify(V2StrategicAI.debug_snapshot(rival)))
	_check(any_research, "rivais concluíram pesquisas pelo runtime V2")
	_check(any_v2_building, "ao menos um prédio V2 foi construído pela fila real")
	_check(max_units <= V2AITuning.HARD_TOKEN_CAP, "hard cap militar respeitado (%d)" % max_units)
	var observed := GameManager.rival_players[0]
	if not observed.cities.is_empty():
		var city: City = observed.cities[0]
		main.get_node("CameraRig").reset_view(HexMetrics.axial_to_world(city.coord.x, city.coord.y, grid.hex_size))
		grid.set_debug_fog_disabled(true)
		hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	# A captura documenta a partida, não o modal transitório de evento mundial.
	hud.world_event_panel.visible = false
	hud.dragon_announcement_panel.visible = false
	hud.dragon_resolution_panel.visible = false
	await _capture("phase24_v2_ai_real_game.png")
	ProjectSettings.set_setting("debug/ai_v2_log", false)
	print("VISUAL_SUMMARY: turns=", TurnManager.turn_number, " max_units=", max_units, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

extends Node

## Validação visual final da Fase 23. Instancia Main.tscn, monta um caso
## determinístico do Ritual Final e salva capturas em user://.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const SACRED_RITUAL := "v2_building_sacred_ritual"
const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("VISUAL_OK: ", message)
	else:
		_failures.append(message)
		push_error("VISUAL_FAIL: " + message)

func _free_coord(grid: HexGrid, center: Vector2i, min_distance: int = 0) -> Vector2i:
	for coord in HexMetrics.coords_within(center, 10):
		var tile := grid.get_tile(coord)
		if HexMetrics.axial_distance(center, coord) >= min_distance and tile != null and not tile.blocks_land_units() and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and grid.get_building_at(coord) == null and not grid.lairs_by_coord.has(coord):
			return coord
	return V2TranscendenceSystem.INVALID_COORD

func _learn_branch(player: PlayerData, branch: String) -> void:
	for tier in range(1, 10):
		var research_id := "v2_magic_%s_%d" % [branch, tier]
		if not player.v2_research.is_completed(research_id):
			_check(player.v2_research.complete_research(research_id), research_id)

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("user://" + file_name)
	_check(error == OK, "captura %s (%dx%d)" % [file_name, image.get_width(), image.get_height()])

func _city_action(hud, name: String) -> Node:
	return hud.tile_info_panel.get_node_or_null("TileInfoBox/V2CityActions/" + name)

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
	GameManager.map_width = 25
	GameManager.map_height = 25
	GameManager.rival_count = 1
	GameManager.debug_mode = true
	GameManager.stagger_ai_turns = false
	grid.generate_map(25, 25, 230023)
	GameManager.start_new_game(grid)
	grid.set_debug_fog_disabled(true)

	var human := GameManager.human_player
	var city_coord := _free_coord(grid, Vector2i.ZERO)
	var city := grid.found_city(city_coord, human, "Aetéria", true)
	city.city_level = 4
	_learn_branch(human, "sacred")
	_learn_branch(human, "infernal")
	_check(V2ResearchDatabase.capstone_progress(V2ResearchDatabase.TRANSCENDENCE_ID, human.v2_research.completed_ids) == Vector2i(2, 2), "capstone mostra 2 / 2 Escolas completas")
	_check(human.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID), "Transcendência pesquisada pelo runtime real")
	_check(human.has_unlocked(V2TranscendenceSystem.ACCESS_ID), "acesso ao Ritual Final derivado do capstone")

	# Quadro real, capstone concluído e tooltip real sob o cursor.
	hud._on_debug_v2_trees_pressed()
	hud.v2_research_board.show_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL)
	hud.v2_research_board.select_node(V2ResearchDatabase.TRANSCENDENCE_ID)
	await get_tree().process_frame
	var capstone: Control = hud.v2_research_board.card_for(V2ResearchDatabase.TRANSCENDENCE_ID)
	_check(capstone != null and hud.v2_research_board.card_count() == 55, "aba Magia mantém 54 nós + Transcendência")
	_check(V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID).gameplay_connected, "card canônico conectado, sem placeholder")
	_check(capstone.tooltip_text.contains("Ritual Final") and capstone.tooltip_text.contains("120"), "tooltip explica Ritual Final e custo de 120 Mana")
	var center := capstone.get_global_rect().get_center()
	Input.warp_mouse(center)
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	await get_tree().create_timer(0.8).timeout
	await _capture("phase23_transcendence_board.png")

	# Cidade ritual, duas Manifestações de Escolas distintas e ação da HUD.
	hud._close_overlay_panels()
	var building_coord := _free_coord(grid, city_coord, 1)
	city.buildings[SACRED_RITUAL] = true
	_check(grid.place_building(building_coord, SACRED_RITUAL, human) != null, "Estrutura Ritual N8 existe fisicamente")
	var seraph := grid.spawn_unit(_free_coord(grid, city_coord, 1), UnitDatabase.create_unit(SERAPH), human)
	var archdemon := grid.spawn_unit(_free_coord(grid, city_coord, 1), UnitDatabase.create_unit(ARCHDEMON), human)
	_check(seraph != null and archdemon != null, "Serafim e Arquidemônio vivos no mapa")
	_check(V2ManifestationSystem.active_manifestation_schools(human) == ["infernal", "sacred"], "duas Escolas distintas contam para o Ritual")
	human.mana = 500.0
	main.get_node("CameraRig").reset_view(HexMetrics.axial_to_world(city_coord.x, city_coord.y, grid.hex_size))
	hud._on_tile_selected(city_coord, grid.get_tile(city_coord))
	await get_tree().process_frame
	var start_button: Button = _city_action(hud, "StartTranscendenceRitualButton")
	_check(start_button != null and not start_button.disabled and start_button.text.contains("120 Mana"), "cidade elegível oferece o botão de 120 Mana")
	await _capture("phase23_ritual_ready.png")

	start_button.pressed.emit()
	await get_tree().process_frame
	_check(V2TranscendenceSystem.ritual_rounds_remaining(human) == 4 and human.mana == 380.0, "início cobra uma vez e mostra 4 rodadas")
	_check(grid._v2_transcendence_markers.has(0), "marcador público criado no site")
	grid.visibility[city_coord] = HexGrid.Visibility.UNSEEN
	grid._apply_fog_colors([city_coord])
	grid._apply_fog_to_entities(human)
	_check(grid.visibility[city_coord] == HexGrid.Visibility.UNSEEN, "marcador não revela o tile sob fog")
	_check(grid._v2_transcendence_markers[0].visible, "marcador permanece visível sob fog")
	hud._on_tile_selected(city_coord, grid.get_tile(city_coord))
	await _capture("phase23_ritual_public_marker.png")

	TurnManager.turn_number += 1
	V2TranscendenceSystem.process_global_round(grid)
	_check(V2TranscendenceSystem.ritual_rounds_remaining(human) == 3, "countdown público avançou para 3")
	var mana_after_start := human.mana
	grid.remove_unit(seraph)
	await get_tree().process_frame
	_check(not V2TranscendenceSystem.has_active_ritual(human), "morte que deixa uma Manifestação interrompe imediatamente")
	_check(human.mana == mana_after_start and grid._v2_transcendence_markers.is_empty(), "interrupção não reembolsa e remove marcador")
	hud._on_tile_selected(city_coord, grid.get_tile(city_coord))
	await _capture("phase23_ritual_interrupted.png")

	seraph = grid.spawn_unit(_free_coord(grid, city_coord, 1), UnitDatabase.create_unit(SERAPH), human)
	human.mana = 500.0
	hud._on_tile_selected(city_coord, grid.get_tile(city_coord))
	start_button = _city_action(hud, "StartTranscendenceRitualButton")
	_check(seraph != null and start_button != null and not start_button.disabled, "reconstrução habilita novo Ritual completo")
	start_button.pressed.emit()
	_check(V2TranscendenceSystem.ritual_rounds_remaining(human) == 4, "reinício volta a quatro rodadas")
	for _round in range(4):
		TurnManager.turn_number += 1
		V2TranscendenceSystem.process_global_round(grid)
	_check(V2TranscendenceSystem.victory_ready(human, grid), "quatro rodadas válidas deixam a vitória pronta")
	GameManager.check_victories()
	await get_tree().process_frame
	_check(GameManager.state == GameManager.GameState.GAME_OVER, "check_victories encerra a partida pelo caminho normal")
	_check(hud.game_over_panel.visible, "tela final real está visível")
	_check(hud.game_over_title_label.text.contains("Vitória por Transcendência"), "tela final usa o título próprio da V2")
	_check(hud.game_over_summary_label.text.contains("duas Grandes Manifestações") and hud.game_over_summary_label.text.contains("quatro rodadas"), "resumo final explica a condição cumprida")
	await _capture("phase23_transcendence_victory.png")

	print("VISUAL_SUMMARY: cards=", hud.v2_research_board.card_count(), " manifestations=", V2ManifestationSystem.active_manifestation_count(human), " winner=", hud.game_over_title_label.text, " failures=", _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)

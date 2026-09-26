extends Node

## Validação visual da Fase 27 no Main.tscn real. Não cria UI própria: abre o
## quadro de pesquisa e o painel de cidade que o jogador usa.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

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
	GameManager.stagger_ai_turns = false
	await main._on_new_game_requested(61, 61, "Balanço F27", 3, "normal", "human")
	await get_tree().create_timer(0.5).timeout

	var settler: Unit = GameManager.human_player.units.filter(func(u): return u.unit_data.can_found_city)[0]
	var city: City = WorldSetup.found_city_from_settler(GameManager.hex_grid, settler)
	_check(city != null, "cidade fundada pelo fluxo real")
	var hud: Control = main.get_node("UILayer/HUD")
	hud._refresh_stats()

	# Quadro real: a curva F27 deve aparecer sem texto interno nem recorte.
	hud._on_research_pressed()
	await get_tree().process_frame
	var board: V2ResearchBoard = hud.v2_research_board
	board.show_tree(V2ResearchNode.TreeType.MILITARY_DOCTRINE)
	board.select_node("v2_doctrine_guardian_5")
	await get_tree().process_frame
	var n5_card: Control = board.card_for("v2_doctrine_guardian_5")
	_check(n5_card != null and n5_card.tooltip_text.contains("40 Conhecimento"), "card N5 mostra custo balanceado 40")
	_check(board.footer_text().contains("Guardião") and not board.footer_text().contains("placeholder"), "rodapé canônico e sem texto interno")
	_check(board.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y + 1.0, "quadro cabe verticalmente em 1920x1017")
	await _capture("phase27_research_curve.png")

	board.show_tree(V2ResearchNode.TreeType.INFRASTRUCTURE)
	board.select_node("v2_infrastructure_academy_1")
	await get_tree().process_frame
	var academy_card: Control = board.card_for("v2_infrastructure_academy_1")
	_check(academy_card != null and academy_card.tooltip_text.contains("16 Conhecimento"), "Academia I mostra custo 16")
	await _capture("phase27_infrastructure_curve.png")

	# Painel de cidade real e top bar depois de fechar o overlay.
	hud.close_topmost_overlay()
	hud._on_tile_selected(city.coord, GameManager.hex_grid.get_tile(city.coord))
	hud._refresh_stats()
	await get_tree().process_frame
	_check(hud.v2_knowledge_label.text.contains("+2/turno"), "top bar mostra a renda-base de Conhecimento")
	_check(hud.tile_info_panel.visible, "painel real da cidade está visível")
	_check(not hud.tile_info_panel.get_global_rect().intersects(hud.stats_label.get_global_rect()), "painel da cidade não cobre a barra de recursos")
	await _capture("phase27_city_economy.png")

	print("VISUAL_SUMMARY: main=real map=61x61 rivals=3 captures=3 failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
